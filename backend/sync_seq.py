import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv(override=True)
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

def sync_sequences():
    with engine.connect() as conn:
        tables = [
            ("branches", "branch_id"),
            ("users", "user_id"),
            ("staff", "employee_id"),
            ("menu_categories", "category_id"),
            ("menu_items", "menu_item_id"),
            ("restaurant_tables", "table_id"),
            ("orders", "order_id"), # If order_id is integer sequence, wait, order_id is varchar. Let's look at models
            ("order_items", "order_item_id"),
            ("transactions", "transaction_id"),
            ("inventory_categories", "category_id"),
            ("inventory_items", "item_id"),
            ("inventory_stock", "stock_id"),
            ("grocery_categories", "grocery_category_id"),
            ("grocery_items", "grocery_item_id"),
            ("grocery_purchases", "grocery_purchase_id"),
            ("expenses_categories", "expense_category_id"),
            ("expenses", "expense_id"),
        ]

        for table, pk in tables:
            try:
                query = text(f"SELECT setval('{table}_{pk}_seq', COALESCE((SELECT MAX({pk})+1 FROM {table}), 1), false);")
                conn.execute(query)
                conn.commit()
                print(f"Synced sequence for {table}")
            except Exception as e:
                conn.rollback()
                print(f"Skipping {table}: {e}")
        
if __name__ == "__main__":
    sync_sequences()
