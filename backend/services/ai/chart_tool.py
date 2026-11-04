import uuid
import logging
from typing import Any, Dict, List, Optional
import pandas as pd
import numpy as np
from langchain.tools import tool

logger = logging.getLogger("bluefox_ai.chart_tool")

SUPPORTED_CHART_TYPES = {"bar", "line", "pie", "donut", "area"}

def build_declarative_chart_spec(
    df: pd.DataFrame,
    chart_type: str,
    title: str,
    x_field: Optional[str] = None,
    y_field: Optional[str] = None,
    description: str = "",
    currency_symbol: str = "₹"
) -> Dict[str, Any]:
    """
    Transforms a Pandas DataFrame into a validated, declarative chart specification.
    No arbitrary Python or JavaScript code execution.
    """
    if df.empty:
        raise ValueError("Cannot generate chart: query returned no data.")

    norm_chart_type = (chart_type or "bar").lower().strip()
    if norm_chart_type not in SUPPORTED_CHART_TYPES:
        norm_chart_type = "bar"

    # 0. Auto-pivot if DataFrame is in long-form comparison format
    # e.g., [date, type: ('Sales', 'Expenses'), amount] -> [date, Sales, Expenses, Net Margin]
    if len(df.columns) == 3:
        cat_cols = [c for c in df.columns if not pd.api.types.is_numeric_dtype(df[c])]
        num_cols = [c for c in df.columns if pd.api.types.is_numeric_dtype(df[c])]
        if len(cat_cols) == 2 and len(num_cols) == 1:
            c0_unq = df[cat_cols[0]].nunique()
            c1_unq = df[cat_cols[1]].nunique()
            idx_c, piv_c = None, None
            if 2 <= c1_unq <= 8 and c0_unq > c1_unq:
                idx_c, piv_c = cat_cols[0], cat_cols[1]
            elif 2 <= c0_unq <= 8 and c1_unq > c0_unq:
                idx_c, piv_c = cat_cols[1], cat_cols[0]

            if idx_c and piv_c:
                try:
                    piv = df.pivot_table(index=idx_c, columns=piv_c, values=num_cols[0], aggfunc="sum").reset_index().fillna(0.0)
                    piv.columns.name = None
                    df = piv
                    x_field = idx_c
                except Exception as ex:
                    logger.debug("Auto-pivot bypassed: %s", ex)

    columns = list(df.columns)
    col_lookup = {c.lower().strip(): c for c in columns}

    # Normalize x_field
    selected_x = None
    if x_field and x_field.lower().strip() in col_lookup:
        selected_x = col_lookup[x_field.lower().strip()]
    elif columns:
        # Find first non-numeric or date column, otherwise first column
        for c in columns:
            if not pd.api.types.is_numeric_dtype(df[c]):
                selected_x = c
                break
        if not selected_x:
            selected_x = columns[0]

    # Detect all numeric series
    numeric_cols = [c for c in columns if c != selected_x and pd.api.types.is_numeric_dtype(df[c])]

    # Compute Net Margin if both Sales and Expenses exist
    sales_col = next((c for c in numeric_cols if any(k in c.lower() for k in ["sale", "revenue", "inflow"])), None)
    exp_col = next((c for c in numeric_cols if any(k in c.lower() for k in ["expense", "cost", "outflow"])), None)
    if sales_col and exp_col and "Net Margin" not in df.columns and "net_profit" not in df.columns:
        df["Net Margin"] = df[sales_col] - df[exp_col]
        numeric_cols.append("Net Margin")

    # Normalize primary y_field
    selected_y = None
    if y_field and y_field.lower().strip() in col_lookup:
        selected_y = col_lookup[y_field.lower().strip()]
    elif numeric_cols:
        selected_y = numeric_cols[0]
    else:
        rem = [c for c in columns if c != selected_x]
        selected_y = rem[0] if rem else selected_x

    # Sanitize and convert DataFrame to clean records (max 60 rows for charts)
    chart_df = df.head(60).copy()

    # Format dates to clean ISO strings
    for col in chart_df.columns:
        if pd.api.types.is_datetime64_any_dtype(chart_df[col]):
            chart_df[col] = chart_df[col].dt.strftime("%Y-%m-%d")
        elif pd.api.types.is_numeric_dtype(chart_df[col]):
            # Replace NaNs/Infs with 0.0
            chart_df[col] = chart_df[col].replace([np.inf, -np.inf], np.nan).fillna(0.0)

    # Convert to serializable records
    records = chart_df.fillna("").to_dict(orient="records")

    # Format axis labels nicely (e.g. total_revenue -> Total Revenue (₹))
    def _format_label(name: str, is_numeric: bool = False) -> str:
        clean = name.replace("_", " ").title()
        if is_numeric and any(k in name.lower() for k in ["amount", "revenue", "price", "sale", "cost", "salary", "expense", "margin", "profit"]):
            return f"{clean} ({currency_symbol})"
        return clean

    x_label = _format_label(selected_x, is_numeric=pd.api.types.is_numeric_dtype(df[selected_x]))
    y_label = _format_label(selected_y, is_numeric=True)

    DEFAULT_PALETTE = ["#059669", "#DC2626", "#2563EB", "#D97706", "#7C3AED", "#0D9488"]
    series_list = []
    for i, col_name in enumerate(numeric_cols):
        c_lower = col_name.lower()
        if any(k in c_lower for k in ["sale", "revenue", "inflow", "income"]):
            color = "#059669"  # Emerald Green for Sales
        elif any(k in c_lower for k in ["expense", "cost", "outflow", "spend", "loss"]):
            color = "#DC2626"  # Crimson Red for Expenses
        elif any(k in c_lower for k in ["net", "margin", "profit", "balance"]):
            color = "#2563EB"  # Royal Blue for Margin
        else:
            color = DEFAULT_PALETTE[i % len(DEFAULT_PALETTE)]

        series_list.append({
            "name": _format_label(col_name, is_numeric=True),
            "field": col_name,
            "color": color
        })

    if not series_list:
        series_list = [{
            "name": y_label,
            "field": selected_y,
            "color": "#012D1D"
        }]

    spec = {
        "chart_id": str(uuid.uuid4()),
        "chart_type": norm_chart_type,
        "title": title or f"{y_label} by {x_label}",
        "x_field": selected_x,
        "y_field": selected_y,
        "x_label": x_label,
        "y_label": y_label,
        "series": series_list,
        "data": records,
        "description": description or f"Visual analysis of {y_label} across {x_label}."
    }

    return spec


def get_generate_chart_tool(context):
    """
    Returns a declarative generate_chart tool bound to the isolated request context.
    """
    @tool
    def generate_chart(
        sql_query: str,
        chart_type: str = "bar",
        title: str = "Operational Metric Chart",
        x_field: str = "",
        y_field: str = "",
        description: str = ""
    ) -> str:
        """Generates a structured visualization chart based on a SQL query and presentation parameters.
        Parameters:
        - sql_query: The SQL SELECT query to retrieve the data to plot. Must follow restaurant_id scoping.
        - chart_type: 'bar', 'line', 'pie', 'donut', or 'area'.
        - title: Concise, descriptive title for the chart (e.g. 'Daily Revenue Trend (October)').
        - x_field: Column name for the X-axis (or category for pie chart, e.g. 'bill_date' or 'dish_name').
        - y_field: Column name for the Y-axis (or numeric metric, e.g. 'total_revenue' or 'order_count').
        - description: Short takeaway or summary of what is plotted.
        """
        try:
            # 1. Execute SQL safely using context's safe executor
            df, executed_sql = context.safe_executor.execute_query(
                sql_query,
                restaurant_id=context.restaurant_id,
                branch_id=context.branch_id
            )

            if df.empty:
                return "Notice: The SQL query executed successfully but returned 0 rows. No chart could be plotted."

            # 2. Build declarative chart specification
            chart_spec = build_declarative_chart_spec(
                df=df,
                chart_type=chart_type,
                title=title,
                x_field=x_field,
                y_field=y_field,
                description=description,
                currency_symbol=context.currency_symbol
            )

            # 3. Store in the request's isolated context
            context.charts.append(chart_spec)

            # Also store table records in context if not yet populated
            if not context.data_records:
                context.data_records = df.head(50).fillna("").to_dict(orient="records")

            logger.info("Generated declarative chart spec: %s (type=%s, rows=%d)", title, chart_type, len(df))

            # Format data preview from chart_spec so LLM has the exact side-by-side data points
            pivoted_df = pd.DataFrame(chart_spec["data"])
            data_preview = pivoted_df.head(20).to_string(index=False)

            return (
                f"Chart '{title}' of type '{chart_type}' was successfully created with {len(pivoted_df)} data points.\n\n"
                f"Retrieved Chart Data:\n{data_preview}\n\n"
                "The chart will be rendered natively inside the conversation interface for the user with an interactive 'View Data' table. "
                "Now provide a clear, concise narrative analysis highlighting the key metrics, top performers, and business takeaways using the EXACT values and item names from the Retrieved Chart Data above.\n"
                "CRITICAL PRESENTATION RULES:\n"
                "- When presenting a comparative breakdown (e.g. Sales vs Expenses), present your markdown table with metrics SIDE-BY-SIDE in distinct columns (e.g. | Date | Sales (₹) | Expenses (₹) | Net Margin (₹) | Status |). NEVER present comparative metrics in separate stacked rows with a 'Type' column.\n"
                "- Never output placeholder text like '*Data point 1*' or '*value*'. Always use the real numbers and names from the data above.\n"
                "- NEVER disclose or output raw SQL queries, table schemas, or query syntax in your response."
            )
        except Exception as exc:
            logger.error("Failed to generate declarative chart: %s", exc, exc_info=True)
            return f"Failed to generate chart due to error: {str(exc)}. Please answer with textual and tabular data instead."

    return generate_chart
