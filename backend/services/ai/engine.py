import os
import sys
import json
import logging
import threading
import queue
import pandas as pd
from langchain_core.callbacks import BaseCallbackHandler
from langchain_community.agent_toolkits import create_sql_agent
from langchain_community.utilities import SQLDatabase
from database import engine
from .prompts import RESTAURANT_SYSTEM_PROMPT
from .chart_tool import get_generate_chart_tool
from .llm_instances import LLM_INSTANCES

# -- Logger for AI Assistant terminal output --
logger = logging.getLogger("bluefox_ai")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    import io
    _stream = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
    handler = logging.StreamHandler(_stream)
    handler.setLevel(logging.DEBUG)
    fmt = logging.Formatter("[BlueFox AI] %(asctime)s  %(message)s", datefmt="%H:%M:%S")
    handler.setFormatter(fmt)
    logger.addHandler(handler)


class RestaurantAgent:
    def __init__(self):
        self.sql_db = SQLDatabase(engine)

        if "GPT_4O_MINI" not in LLM_INSTANCES:
            raise ValueError("GPT_4O_MINI model configuration is missing in LLM_INSTANCES.")

        self.llm = LLM_INSTANCES["GPT_4O_MINI"]["MODEL"]
        self.current_charts = []

        generate_chart = get_generate_chart_tool(self)

        self.agent = create_sql_agent(
            llm=self.llm,
            db=self.sql_db,
            agent_type="openai-tools",
            verbose=True,
            prefix=RESTAURANT_SYSTEM_PROMPT,
            extra_tools=[generate_chart],
            agent_executor_kwargs={"return_intermediate_steps": True},
        )
        logger.info("Agent initialised successfully.")

    def generate_plan(self, user_input: str) -> list:
        prompt = (
            f"User query: '{user_input}'. "
            "List 2 to 4 logical execution steps to fulfill this using a SQL database "
            "(and chart tool if a graph is requested). "
            "Return ONLY a JSON array of short strings, nothing else. "
            "E.g. [\"Analyze schema\", \"Query sales data\", \"Generate chart\"]"
        )
        try:
            response = self.llm.invoke([{"role": "user", "content": prompt}])
            text = response.content.replace("```json", "").replace("```", "").strip()
            plan = json.loads(text)
            logger.info("Plan generated: %s", plan)
            return plan
        except Exception as exc:
            logger.warning("Plan generation failed (%s), using defaults.", exc)
            return ["Analyze request", "Execute database query", "Format results"]

    def stream_process_query(self, user_input: str, branch_id: int = None):
        if branch_id:
            user_input = f"[Context: The user is currently viewing branch_id={branch_id}. Please filter your SQL queries for this branch unless specified otherwise.] {user_input}"
            
        logger.info("--- New query: %s", user_input)

        plan = self.generate_plan(user_input)
        yield json.dumps({"type": "plan", "steps": plan}, default=str) + "\n"

        q = queue.Queue()

        class _Callback(BaseCallbackHandler):
            def on_tool_end(self, output, **kwargs):
                tool_name = kwargs.get("name", "unknown")
                logger.info("  [OK] Tool finished: %s", tool_name)
                q.put({"type": "step_complete", "tool": tool_name})

        def _run_agent():
            try:
                self.current_charts = []
                logger.info("  Agent invoke started ...")
                response = self.agent.invoke(
                    {"input": user_input},
                    config={"callbacks": [_Callback()]},
                )
                logger.info("  Agent invoke finished.")

                raw_df = pd.DataFrame()
                if "intermediate_steps" in response:
                    for step in response["intermediate_steps"]:
                        action, observation = step
                        if action.tool == "sql_db_query":
                            sql_query = action.tool_input
                            if isinstance(sql_query, dict) and "query" in sql_query:
                                sql_query = sql_query["query"]
                            try:
                                raw_df = pd.read_sql(sql_query, self.sql_db._engine)
                            except Exception:
                                pass

                data_records = []
                if not raw_df.empty:
                    data_records = raw_df.fillna("").to_dict(orient="records")

                output_text = response.get("output", "")
                q.put({
                    "type": "final",
                    "text": output_text,
                    "data": data_records,
                    "charts": list(self.current_charts),
                })
            except Exception as exc:
                logger.error("  Agent error: %s", exc, exc_info=True)
                q.put({"type": "error", "message": str(exc)})

        thread = threading.Thread(target=_run_agent, daemon=True)
        thread.start()

        while True:
            try:
                item = q.get(timeout=120)
            except queue.Empty:
                logger.error("  Timeout: agent did not respond within 120 s.")
                yield json.dumps({"type": "error", "message": "Agent timed out."}, default=str) + "\n"
                break
            yield json.dumps(item, default=str) + "\n"
            if item["type"] in ("final", "error"):
                break

        logger.info("--- Query complete.\\n")
