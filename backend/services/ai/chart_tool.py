import os
import pandas as pd
import altair as alt
from openai import OpenAI
from langchain.tools import tool
from .llm_instances import LLM_INSTANCES

def generate_altair_code(user_query: str, df: pd.DataFrame, model_key: str = None) -> str:
    """Requests LLM to generate Altair charting code."""
    if df.empty:
        raise ValueError("Cannot generate chart: DataFrame is empty.")

    selected_key = model_key or os.environ.get("AI_MODEL", "GROQ_GPT_OSS_120B")
    if selected_key not in LLM_INSTANCES:
        if "GROQ_GPT_OSS_120B" in LLM_INSTANCES:
            selected_key = "GROQ_GPT_OSS_120B"
        elif LLM_INSTANCES:
            selected_key = next(iter(LLM_INSTANCES.keys()))
        else:
            raise ValueError("No model configuration found in LLM_INSTANCES.")
        
    llm = LLM_INSTANCES[selected_key]["MODEL"]

    prompt = f"""
    You are an expert Altair data visualization developer.
    User goal: "{user_query}"
    Data schema: {list(df.columns)}
    Data sample: {df.head(3).to_dict(orient='records')}
    
    Write Python code using `alt` to visualize this data.
    - Assign the final chart to a variable named `chart`.
    - Do NOT import any libraries.
    - Do NOT create a dataframe or hardcode data. 
    - Do NOT use backslashes (`\\`) for line continuations. Use parentheses `()` for multi-line chaining instead.
    - You MUST use the existing `df` variable directly (e.g., `alt.Chart(df)`).
    - If the data contains dates as strings, use `pd.to_datetime()` on the dataframe column FIRST, or use Altair's temporal type casting (e.g., `x='date:T'`).
    - Only output the raw python code. No markdown formatting.
    """
    
    response = llm.invoke([{"role": "user", "content": prompt}])
    code = response.content
    return code.replace("```python", "").replace("```", "").strip()

def execute_chart_code(code: str, df: pd.DataFrame):
    """
    Executes the generated code in a highly restricted scope.
    """
    import json
    import numpy as np
    restricted_globals = {"__builtins__": {}}
    local_scope = {"pd": pd, "alt": alt, "df": df, "json": json, "np": np}
    
    try:
        exec(code, restricted_globals, local_scope)
        chart = local_scope.get("chart")
        if not chart:
            raise ValueError("The generated code did not produce a 'chart' object.")
        return chart
    except Exception as e:
        raise RuntimeError(f"Chart rendering failed: {str(e)}\n\nCode attempted:\n{code}")

def get_generate_chart_tool(agent_instance):
    """
    Returns the generate_chart tool bound to the agent instance so it can append to current_charts.
    """
    @tool
    def generate_chart(sql_query: str, user_goal: str) -> str:
        """Generates a visualization chart based on a SQL query and user goal.
        Use your judgment to decide if a chart is needed. Call this tool whenever a visualization (like a trend line, bar chart comparison, or distribution) would best help the user understand the data.
        First determine the correct SQL query using SQL tools, then pass it here.
        """
        try:
            # Execute SQL to get data
            df = pd.read_sql(sql_query, agent_instance.sql_db._engine)
            if df.empty:
                return "Error: SQL query returned no data. Cannot generate chart."
            
            # Generate and execute chart code
            model_key = getattr(agent_instance, "model_key", None)
            code = generate_altair_code(user_goal, df, model_key=model_key)
            chart = execute_chart_code(code, df)
            
            # Save the chart as HTML and store it
            import uuid
            chart_id = str(uuid.uuid4())
            agent_instance.chart_htmls[chart_id] = chart.to_html()
            agent_instance.current_charts.append({"chart_id": chart_id})
            
            return "Chart generated successfully. Inform the user that the chart has been displayed, AND provide a detailed written analysis of the trends, outliers, or key takeaways from the data you plotted."
        except Exception as e:
            return f"Failed to generate chart: {str(e)}"
            
    return generate_chart
