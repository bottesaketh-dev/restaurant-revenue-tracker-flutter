import os
import sys

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

import json
import uuid
import logging
import threading
import queue
import re
from typing import Any, Dict, List, Optional, Generator
from datetime import datetime, timezone

import pandas as pd
from sqlalchemy.orm import Session
from sqlalchemy import func
from langchain_core.callbacks import BaseCallbackHandler
from langchain_community.agent_toolkits import create_sql_agent
from langchain_community.utilities import SQLDatabase
from langchain.tools import tool

from database import engine as db_engine, SessionLocal
import models
from .prompts import RESTAURANT_SYSTEM_PROMPT
from .chart_tool import get_generate_chart_tool
from .llm_instances import LLM_INSTANCES
from .security_guard import SafeSQLExecutor, SAFE_TABLES

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

# Global registry of active requests for cancellation support
ACTIVE_REQUESTS: Dict[str, "ChatRequestContext"] = {}
_REQUESTS_LOCK = threading.Lock()


def cancel_active_conversation(conversation_id: str) -> bool:
    """Stops the active LLM generation for a conversation if one is running."""
    with _REQUESTS_LOCK:
        ctx = ACTIVE_REQUESTS.get(conversation_id)
        if ctx:
            ctx.is_cancelled = True
            ctx.cancel_event.set()
            logger.info("Cancelled active generation for conversation_id=%s", conversation_id)
            return True
    return False


def generate_conversation_title(query: str) -> str:
    """Derives a concise, professional title from the user's initial inquiry."""
    clean = re.sub(r"^(show\s+me|please\s+show|give\s+me|tell\s+me|what\s+is|what\s+was|can\s+you\s+show|can\s+you\s+find)\s+", "", query.strip(), flags=re.IGNORECASE)
    clean = re.sub(r"[?!.,'\"]", "", clean).strip()
    words = clean.split()
    if not words:
        return "Operational Inquiry"
    title = " ".join(words[:6]).title()
    if len(title) > 40:
        title = title[:37].rsplit(" ", 1)[0] + "..."
    return title


def sanitize_user_facing_content(text: str) -> str:
    """Strips any raw SQL statements, code blocks, or internal query mechanics from user-facing text."""
    if not text:
        return ""
    # 1. Remove ```sql ... ``` code blocks
    text = re.sub(r"```sql[\s\S]*?```", "", text, flags=re.IGNORECASE)
    # 2. Remove generic code blocks containing SQL queries
    text = re.sub(r"```[\s\S]*?(?:SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)\s+[\s\S]*?```", "", text, flags=re.IGNORECASE)
    # 3. Remove standalone SQL lines: SELECT ... FROM ...
    text = re.sub(r"(?im)^\s*SELECT\s+[\s\S]*?;\s*$", "", text)
    # 4. Remove 'SQL Query:' / 'Executed SQL:' labels and following line
    text = re.sub(r"(?i)\*?\*?(?:generated\s+sql|sql\s+query|executed\s+sql|underlying\s+query)\*?\*?:?.*", "", text)
    return text.strip()


class ChatRequestContext:
    """Isolated, thread-safe request context for each user message turn."""
    def __init__(
        self,
        conversation_id: str,
        user_id: int,
        restaurant_id: Optional[int],
        branch_id: Optional[int],
        branch_name: Optional[str] = None,
        currency_symbol: str = "₹"
    ):
        self.conversation_id = conversation_id
        self.user_id = user_id
        self.restaurant_id = restaurant_id
        self.branch_id = branch_id
        self.branch_name = branch_name
        self.currency_symbol = currency_symbol
        self.safe_executor = SafeSQLExecutor()
        self.charts: List[Dict[str, Any]] = []
        self.data_records: List[Dict[str, Any]] = []
        self.plan_steps: List[Dict[str, Any]] = []
        self.is_cancelled: bool = False
        self.cancel_event = threading.Event()
        self.event_queue: queue.Queue = queue.Queue()
        self.assistant_message_id = str(uuid.uuid4())
        self.user_message_id = str(uuid.uuid4())


class RestaurantAgentService:
    """Service that manages SQL agent execution with strict multi-tenant boundaries."""

    def __init__(self, model_key: str = None):
        selected_key = model_key or os.environ.get("AI_MODEL", "GROQ_GPT_OSS_120B")
        if selected_key not in LLM_INSTANCES:
            if "GROQ_GPT_OSS_120B" in LLM_INSTANCES:
                selected_key = "GROQ_GPT_OSS_120B"
            elif LLM_INSTANCES:
                selected_key = next(iter(LLM_INSTANCES.keys()))
            else:
                raise ValueError("No model configuration found in LLM_INSTANCES.")

        self.model_key = selected_key
        self.llm = LLM_INSTANCES[selected_key]["MODEL"]
        self.sql_db = SQLDatabase(db_engine, include_tables=list(SAFE_TABLES))
        logger.info("RestaurantAgentService initialised with model: %s", selected_key)

    def generate_plan(self, user_input: str) -> List[Dict[str, Any]]:
        """Generates dynamic execution plan steps with unique IDs."""
        steps = [
            {"id": "step_understand", "text": "Understand inquiry and tenant scope", "status": "pending"},
            {"id": "step_query", "text": "Retrieve operational business records", "status": "pending"},
            {"id": "step_analyze", "text": "Synthesize metrics and takeaways", "status": "pending"},
        ]
        lower_q = user_input.lower()
        if any(k in lower_q for k in ["chart", "plot", "graph", "visual", "trend", "distribution", "breakdown", "compare"]):
            steps.insert(2, {"id": "step_chart", "text": "Generate interactive visual chart", "status": "pending"})
        return steps

    def stream_process_query(
        self,
        context: ChatRequestContext,
        user_input: str,
        conversation_history: Optional[List[Dict[str, str]]] = None
    ) -> Generator[str, None, None]:
        """
        Executes query under isolated context and yields NDJSON progress and message events.
        """
        with _REQUESTS_LOCK:
            ACTIVE_REQUESTS[context.conversation_id] = context

        # 1. Persist User Message in DB
        db = SessionLocal()
        try:
            # Check or create conversation
            conv = db.query(models.ChatConversation).filter(
                models.ChatConversation.conversation_id == context.conversation_id
            ).first()

            if not conv:
                conv = models.ChatConversation(
                    conversation_id=context.conversation_id,
                    user_id=context.user_id,
                    restaurant_id=context.restaurant_id,
                    branch_id=context.branch_id,
                    title=generate_conversation_title(user_input),
                    created_at=datetime.now(timezone.utc),
                    updated_at=datetime.now(timezone.utc),
                    last_message_at=datetime.now(timezone.utc)
                )
                db.add(conv)
                db.commit()

            # Record user message
            user_msg = models.ChatMessage(
                message_id=context.user_message_id,
                conversation_id=context.conversation_id,
                role="user",
                content=user_input,
                restaurant_id=context.restaurant_id,
                branch_id=context.branch_id,
                status="completed",
                created_at=datetime.now(timezone.utc)
            )
            db.add(user_msg)

            # Record pending assistant message
            assistant_msg = models.ChatMessage(
                message_id=context.assistant_message_id,
                conversation_id=context.conversation_id,
                role="assistant",
                content="",
                restaurant_id=context.restaurant_id,
                branch_id=context.branch_id,
                status="pending",
                created_at=datetime.now(timezone.utc)
            )
            db.add(assistant_msg)
            db.commit()
        except Exception as e:
            logger.error("DB error saving initial messages: %s", e)
            db.rollback()
        finally:
            db.close()

        # 2. Prepare Context Notes and History
        context_notes = []
        if context.restaurant_id is not None:
            context_notes.append(
                f"Multi-Tenant Requirement: Active restaurant_id={context.restaurant_id} (Currency: {context.currency_symbol}). "
                f"You MUST scope all SQL queries with 'WHERE restaurant_id = {context.restaurant_id}'. Never leak or aggregate data across restaurants."
            )
        if context.branch_id is not None:
            branch_label = f"branch_id={context.branch_id}"
            if context.branch_name:
                branch_label += f" ({context.branch_name})"
            context_notes.append(f"Active Branch Focus: {branch_label}. Filter your queries by this branch unless asked for multi-branch comparison.")

        # Build conversation history prefix
        history_prompts = []
        if conversation_history:
            for item in conversation_history[-8:]:
                role = item.get("role", "user").capitalize()
                content = item.get("content", "")
                if role == "System":
                    history_prompts.append(f"[System Event: {content}]")
                else:
                    history_prompts.append(f"{role}: {content}")

        full_prompt = user_input
        prefix_parts = []
        if context_notes:
            prefix_parts.append(f"[{' | '.join(context_notes)}]")
        if history_prompts:
            prefix_parts.append("Previous Conversation History:\n" + "\n".join(history_prompts))

        if prefix_parts:
            full_prompt = "\n\n".join(prefix_parts) + f"\n\nCurrent User Query: {user_input}"

        logger.info("Executing AI Turn for conv=%s, user=%s, branch=%s", context.conversation_id, context.user_id, context.branch_id)

        # 3. Emit Plan
        plan_steps = self.generate_plan(user_input)
        context.plan_steps = plan_steps
        yield json.dumps({"type": "plan", "steps": plan_steps}, default=str) + "\n"

        # Emit step 1 started
        if plan_steps:
            yield json.dumps({"type": "step_started", "id": plan_steps[0]["id"], "text": plan_steps[0]["text"]}, default=str) + "\n"

        # 4. Create Isolated Tools
        generate_chart_tool = get_generate_chart_tool(context)

        # Safe SQL querying tool
        @tool
        def execute_safe_sql(query: str) -> str:
            """Executes a read-only SQL query against the restaurant database.
            Ensure query is strictly scoped by the active restaurant_id.
            """
            if context.is_cancelled:
                return "Execution was cancelled by the user."
            try:
                df, executed_sql = context.safe_executor.execute_query(
                    query,
                    restaurant_id=context.restaurant_id,
                    branch_id=context.branch_id
                )
                if df.empty:
                    return "Query returned 0 rows."
                # Keep data records in context
                if not context.data_records:
                    context.data_records = df.head(50).fillna("").to_dict(orient="records")
                return df.head(20).to_string(index=False)
            except Exception as ex:
                return f"SQL Error: {str(ex)}"

        # 5. Build Agent with Isolated Tools
        agent_executor = create_sql_agent(
            llm=self.llm,
            db=self.sql_db,
            agent_type="openai-tools",
            verbose=True,
            prefix=RESTAURANT_SYSTEM_PROMPT,
            extra_tools=[generate_chart_tool, execute_safe_sql],
            agent_executor_kwargs={"return_intermediate_steps": True},
        )

        q = context.event_queue
        step_idx = 0

        FRIENDLY_TOOL_LABELS = {
            "execute_safe_sql": "Querying operational database securely...",
            "generate_chart": "Constructing visual comparison...",
            "sql_db_list_tables": "Auditing business data availability...",
            "sql_db_schema": "Reviewing data structure...",
            "sql_db_query_checker": "Validating parameters...",
        }

        class AgentStreamCallback(BaseCallbackHandler):
            def __init__(self):
                self.has_streamed_token = False
                self.is_tool_running = False

            def on_tool_start(self, serialized, input_str, **kwargs):
                nonlocal step_idx
                self.is_tool_running = True
                if context.is_cancelled:
                    return
                tool_name = serialized.get("name") if isinstance(serialized, dict) else kwargs.get("name", "tool")
                friendly = FRIENDLY_TOOL_LABELS.get(tool_name, "Retrieving business data...")
                if step_idx < len(plan_steps):
                    q.put({
                        "type": "step_started",
                        "id": plan_steps[step_idx]["id"],
                        "text": friendly
                    })

            def on_tool_end(self, output, **kwargs):
                nonlocal step_idx
                self.is_tool_running = False
                if context.is_cancelled:
                    return
                tool_name = kwargs.get("name", "Tool")
                friendly = FRIENDLY_TOOL_LABELS.get(tool_name, "Completed data retrieval")
                friendly = friendly.replace("...", "")
                if not friendly.startswith("Completed"):
                    friendly = f"Completed {friendly.lower()}"
                if step_idx < len(plan_steps):
                    q.put({
                        "type": "step_completed",
                        "id": plan_steps[step_idx]["id"],
                        "text": friendly
                    })
                    step_idx += 1
                    if step_idx < len(plan_steps):
                        q.put({
                            "type": "step_started",
                            "id": plan_steps[step_idx]["id"],
                            "text": plan_steps[step_idx]["text"]
                        })

            def on_llm_new_token(self, token: str, **kwargs):
                if context.is_cancelled or not token:
                    return

                # Suppress tokens if a tool is executing or chunk is part of tool call arguments
                if self.is_tool_running:
                    return

                chunk = kwargs.get("chunk")
                if chunk and hasattr(chunk, "message"):
                    msg = chunk.message
                    if getattr(msg, "tool_call_chunks", None) or getattr(msg, "additional_kwargs", {}).get("tool_calls"):
                        return
                    if not getattr(msg, "content", ""):
                        return

                # Hard security check: NEVER stream SQL syntax or statements to the user
                if any(sql_kw in token.upper() for sql_kw in ["SELECT ", "FROM ", "WHERE ", "JOIN ", "GROUP BY ", "ORDER BY "]):
                    return

                self.has_streamed_token = True
                q.put({"type": "message_chunk", "delta": token})

        final_response_holder = {}

        def _run_worker():
            try:
                if context.is_cancelled:
                    q.put({"type": "cancelled"})
                    return

                cb = AgentStreamCallback()
                response = agent_executor.invoke(
                    {"input": full_prompt},
                    config={"callbacks": [cb]}
                )

                if context.is_cancelled:
                    q.put({"type": "cancelled"})
                    return

                raw_output = response.get("output", "")
                output_text = sanitize_user_facing_content(raw_output)
                final_response_holder["text"] = output_text

                # Extract intermediate SQL data if data_records still empty
                if not context.data_records and "intermediate_steps" in response:
                    for step in response["intermediate_steps"]:
                        action, observation = step
                        tool_input = getattr(action, "tool_input", None)
                        if isinstance(tool_input, dict) and "query" in tool_input:
                            try:
                                df, _ = context.safe_executor.execute_query(tool_input["query"], context.restaurant_id, context.branch_id)
                                if not df.empty:
                                    context.data_records = df.head(50).fillna("").to_dict(orient="records")
                                    break
                            except Exception:
                                pass

                q.put({
                    "type": "final",
                    "content": output_text,
                    "charts": context.charts,
                    "data": context.data_records,
                    "message_id": context.assistant_message_id,
                })
            except Exception as exc:
                logger.error("Error executing agent: %s", exc, exc_info=True)
                q.put({"type": "error", "message": str(exc)})

        worker_thread = threading.Thread(target=_run_worker, daemon=True)
        worker_thread.start()

        # 6. Stream events from queue to HTTP response
        accumulated_text = ""
        while True:
            try:
                event = q.get(timeout=120)
            except queue.Empty:
                logger.error("Agent timeout after 120s for conv=%s", context.conversation_id)
                event = {"type": "error", "message": "Query processing timed out. Please try again with a narrower date or branch filter."}
                yield json.dumps(event) + "\n"
                break

            ev_type = event.get("type")
            if ev_type == "message_chunk":
                accumulated_text += event.get("delta", "")
            elif ev_type == "final":
                accumulated_text = event.get("content", accumulated_text)

            yield json.dumps(event, default=str) + "\n"

            if ev_type in ("final", "error", "cancelled"):
                break

        # 7. Persist completed state to database
        db = SessionLocal()
        try:
            asst_msg = db.query(models.ChatMessage).filter(
                models.ChatMessage.message_id == context.assistant_message_id
            ).first()

            if asst_msg:
                if context.is_cancelled:
                    asst_msg.status = "cancelled"
                    asst_msg.content = accumulated_text or "Generation was stopped."
                elif ev_type == "error":
                    asst_msg.status = "failed"
                    asst_msg.content = accumulated_text or f"Error: {event.get('message')}"
                    asst_msg.metadata_json = json.dumps({"error": event.get("message")})
                else:
                    asst_msg.status = "completed"
                    asst_msg.content = accumulated_text
                    # Mark all plan steps as completed for clean collapsed display
                    final_steps = [
                        {"id": s["id"], "text": s["text"], "status": "completed"}
                        for s in plan_steps
                    ]
                    meta = {
                        "plan": final_steps,
                        "charts": context.charts,
                        "data": context.data_records,
                        "branch_id": context.branch_id,
                        "branch_name": context.branch_name,
                    }
                    asst_msg.metadata_json = json.dumps(meta, default=str)

                # Update conversation timestamp & auto-generate title if default
                conv = db.query(models.ChatConversation).filter(
                    models.ChatConversation.conversation_id == context.conversation_id
                ).first()
                if conv:
                    conv.last_message_at = datetime.now(timezone.utc)
                    conv.updated_at = datetime.now(timezone.utc)
                    if conv.title == "New Chat":
                        conv.title = generate_conversation_title(user_input)

                db.commit()
        except Exception as e:
            logger.error("DB error saving final assistant message: %s", e)
            db.rollback()
        finally:
            db.close()
            with _REQUESTS_LOCK:
                ACTIVE_REQUESTS.pop(context.conversation_id, None)

        logger.info("AI Turn completed for conv=%s (final status=%s, charts=%d)", context.conversation_id, ev_type, len(context.charts))


_agent_service: Optional[RestaurantAgentService] = None

def get_agent_service() -> RestaurantAgentService:
    global _agent_service
    if _agent_service is None:
        _agent_service = RestaurantAgentService()
    return _agent_service
