"""
Migration: add access_level and allowed_tabs columns to the users table.

Usage:
    cd backend
    python migrations/add_user_access_control.py

Safe to run multiple times (checks for existing columns before altering).
"""
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import inspect, text
from database import engine


def column_exists(inspector, table_name, column_name) -> bool:
    columns = [col["name"] for col in inspector.get_columns(table_name)]
    return column_name in columns


def main():
    inspector = inspect(engine)

    with engine.begin() as conn:
        if not column_exists(inspector, "users", "access_level"):
            print("Adding 'access_level' column to users table...")
            conn.execute(text(
                "ALTER TABLE users ADD COLUMN access_level VARCHAR NOT NULL DEFAULT 'FULL'"
            ))
        else:
            print("'access_level' column already exists, skipping.")

        if not column_exists(inspector, "users", "allowed_tabs"):
            print("Adding 'allowed_tabs' column to users table...")
            conn.execute(text(
                "ALTER TABLE users ADD COLUMN allowed_tabs TEXT"
            ))
        else:
            print("'allowed_tabs' column already exists, skipping.")

    print("Migration completed successfully!")


if __name__ == "__main__":
    main()
