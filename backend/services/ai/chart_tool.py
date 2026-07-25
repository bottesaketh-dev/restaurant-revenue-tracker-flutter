import os
import pandas as pd
import altair as alt
from openai import OpenAI
from langchain.tools import tool
from .llm_instances import LLM_INSTANCES

def generate_altair_code(user_query: str, df: pd.DataFrame) -> str:
    """Requests GPT-4 to generate Altair charting code."""
    if df.empty:
        raise ValueError("Cannot generate chart: DataFrame is empty.")

    if "GPT_4O_MINI" not in LLM_INSTANCES:
        raise ValueError("GPT_4O_MINI model configuration is missing in LLM_INSTANCES.")
        
    llm = LLM_INSTANCES["GPT_4O_MINI"]["MODEL"]

    prompt = f"""
    You are an expert Altair data visualization developer.
    User goal: "{user_query}"
    Data schema: {list(df.columns)}
    Data sample: {df.head(3).to_dict(orient='records')}
    
    Write Python code using `alt` to visualize this data.
    - Assign the final chart to a variable named `chart`.
    - Do NOT import any libraries.
    - Do NOT create a dataframe or hardcode data. 
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
        Use this tool ONLY when the user explicitly asks for a graph, chart, or plot.
        First determine the correct SQL query using SQL tools, then pass it here.
        """
        try:
            # Execute SQL to get data
            df = pd.read_sql(sql_query, agent_instance.sql_db._engine)
            if df.empty:
                return "Error: SQL query returned no data. Cannot generate chart."
            
            # Generate and execute chart code
            code = generate_altair_code(user_goal, df)
            chart = execute_chart_code(code, df)
            
            # Store the generated chart in the class instance as a Vega-Lite dict
            agent_instance.current_charts.append(chart.to_dict())
            return "Chart generated successfully. Inform the user that the chart has been displayed."
        except Exception as e:
            return f"Failed to generate chart: {str(e)}"
            
    return generate_chart
