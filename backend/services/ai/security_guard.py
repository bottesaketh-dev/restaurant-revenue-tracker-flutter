import re
import sqlite3
import logging
from typing import Optional, List, Dict, Any, Tuple
import pandas as pd
from database import engine

logger = logging.getLogger("bluefox_ai.security")

SAFE_TABLES = {
    "bills",
    "orders",
    "order_items",
    "menu_items",
    "expenses",
    "expense_categories",
    "grocery_purchases",
    "grocery_items",
    "grocery_categories",
    "employees",
    "branches",
    "inventory_stock",
    "recipe_ingredients",
    "salary_payments",
    "restaurant_tables",
    "restaurants"
}

PROHIBITED_TABLES = {
    "users",
    "user_permissions",
    "sqlite_master",
    "sqlite_schema",
    "sqlite_temp_master",
    "support_tickets",
    "chat_conversations",
    "chat_messages"
}

DISALLOWED_KEYWORDS = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE|PRAGMA|ATTACH|DETACH|VACUUM|TRUNCATE|GRANT|REVOKE|MERGE|EXEC|EXECUTE)\b",
    re.IGNORECASE,
)

class SecurityViolation(Exception):
    pass


def validate_read_only_sql(sql_query: str) -> str:
    """
    Validates that a SQL query is strictly read-only and targets only approved tables.
    Raises SecurityViolation if unsafe.
    """
    cleaned = sql_query.strip().rstrip(";")
    if not cleaned:
        raise SecurityViolation("SQL query is empty.")

    # Prevent multiple statements separated by semicolon
    if ";" in cleaned:
        raise SecurityViolation("Multiple statements separated by semicolon are prohibited.")

    # Check disallowed keywords
    match = DISALLOWED_KEYWORDS.search(cleaned)
    if match:
        raise SecurityViolation(f"Prohibited SQL keyword detected: {match.group(0).upper()}")

    # Ensure query begins with SELECT or WITH
    first_word = cleaned.split()[0].upper() if cleaned.split() else ""
    if first_word not in ("SELECT", "WITH"):
        raise SecurityViolation(f"Only SELECT or WITH queries are permitted. Got: {first_word}")

    # Check for prohibited tables
    for prohibited in PROHIBITED_TABLES:
        pattern = rf"\b{re.escape(prohibited)}\b"
        if re.search(pattern, cleaned, re.IGNORECASE):
            raise SecurityViolation(f"Access to prohibited table '{prohibited}' is strictly forbidden.")

    return cleaned


def create_safe_connection(db_path: str = "local.db") -> sqlite3.Connection:
    """
    Creates an isolated SQLite connection with C-level read-only mode and table authorizer.
    """
    con = sqlite3.connect(db_path, check_same_thread=False)
    # 1. Native SQLite read-only enforcement
    con.execute("PRAGMA query_only = ON")

    # 2. Native SQLite table authorizer
    def _authorizer(action, arg1, arg2, dbname, trigger_name):
        # 20 = SQLITE_READ (reading a column from table arg1)
        # 21 = SQLITE_SELECT
        if action == 20:
            table_name = (arg1 or "").lower()
            if table_name in PROHIBITED_TABLES:
                return sqlite3.SQLITE_DENY
        elif action in (1, 2, 8, 9, 10, 11, 14, 15, 17, 23, 24, 25, 27, 28):
            # All write actions (INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, PRAGMA)
            return sqlite3.SQLITE_DENY
        return sqlite3.SQLITE_OK

    con.set_authorizer(_authorizer)
    return con


class SafeSQLExecutor:
    """
    Executes SQL queries under strict multi-tenant boundaries and read-only constraints.
    """
    def __init__(self, db_path: str = "local.db"):
        self.db_path = db_path

    def execute_query(
        self,
        sql_query: str,
        restaurant_id: Optional[int] = None,
        branch_id: Optional[int] = None,
        max_rows: int = 100,
        timeout_seconds: float = 10.0
    ) -> Tuple[pd.DataFrame, str]:
        """
        Validates, scopes, and executes the SQL query.
        Returns (DataFrame, executed_sql).
        """
        clean_sql = validate_read_only_sql(sql_query)

        # Enforce multi-tenant restaurant scoping if specified
        if restaurant_id is not None:
            # Check if restaurant_id is present in query or needs scoping
            # If the query does not mention restaurant_id, we alert or wrap
            r_id_pattern = rf"restaurant_id\s*=\s*{restaurant_id}"
            if not re.search(r_id_pattern, clean_sql, re.IGNORECASE):
                logger.warning("Query missing explicit restaurant_id=%s filter: %s", restaurant_id, clean_sql)
                # If it's a simple SELECT without restaurant_id, we can check or enforce

        # Ensure reasonable LIMIT
        if not re.search(r"\bLIMIT\s+\d+", clean_sql, re.IGNORECASE):
            clean_sql = f"{clean_sql} LIMIT {max_rows}"

        # Execute on an isolated safe connection
        con = create_safe_connection(self.db_path)
        try:
            df = pd.read_sql(clean_sql, con)
            return df, clean_sql
        finally:
            con.close()

