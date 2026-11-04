import sys
import os
import unittest
import json
from fastapi.testclient import TestClient

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from database import SessionLocal
import models
import security
from services.ai.security_guard import validate_read_only_sql, SecurityViolation, SafeSQLExecutor
from services.ai.chart_tool import build_declarative_chart_spec
import pandas as pd

class TestAIConversationsAndSecurity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.db = SessionLocal()

        # Generate tokens for testing
        # 1. Super Admin
        cls.super_admin_token = security.create_access_token({
            "sub": "1",
            "role": "SUPER_ADMIN",
            "restaurant_id": None,
            "branch_id": None
        })

        # 2. Deccan Spice Admin (restaurant_id=1)
        cls.admin_deccan_token = security.create_access_token({
            "sub": "2",
            "role": "RESTAURANT_ADMIN",
            "restaurant_id": 1,
            "branch_id": None
        })

        # 3. Nizam Heritage Admin (restaurant_id=2)
        cls.admin_nizam_token = security.create_access_token({
            "sub": "3",
            "role": "RESTAURANT_ADMIN",
            "restaurant_id": 2,
            "branch_id": None
        })

        # 4. Branch Manager (branch_id=1, restaurant_id=1)
        cls.mgr_madhapur_token = security.create_access_token({
            "sub": "4",
            "role": "BRANCH_MANAGER",
            "restaurant_id": 1,
            "branch_id": 1
        })

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def test_01_sql_security_guard_blocks_modifications(self):
        """Verifies that all destructive or modifying SQL queries are strictly blocked."""
        disallowed = [
            "DELETE FROM bills WHERE 1=1",
            "INSERT INTO bills (bill_id) VALUES ('evil')",
            "UPDATE bills SET total_amount = 0",
            "DROP TABLE menu_items",
            "ALTER TABLE bills ADD COLUMN evil TEXT",
            "SELECT * FROM bills; DELETE FROM bills",
            "SELECT * FROM users",  # Prohibited credentials table
            "SELECT * FROM user_permissions",  # Prohibited security table
            "PRAGMA table_info(bills)",
        ]
        for query in disallowed:
            with self.assertRaises(SecurityViolation, msg=f"Failed to block: {query}"):
                validate_read_only_sql(query)

    def test_02_sql_security_guard_allows_safe_selects(self):
        """Verifies that valid analytical SELECT queries pass validation."""
        allowed = [
            "SELECT * FROM bills WHERE restaurant_id = 1",
            "SELECT category, SUM(price) FROM menu_items GROUP BY category",
            "WITH monthly_sales AS (SELECT * FROM bills) SELECT * FROM monthly_sales",
        ]
        for query in allowed:
            validated = validate_read_only_sql(query)
            self.assertTrue(validated.startswith("SELECT") or validated.startswith("WITH"))

    def test_03_declarative_chart_generation(self):
        """Verifies declarative chart spec generation without exec() or HTML."""
        df = pd.DataFrame({
            "dish_name": ["Dum Biryani", "Mirchi Ka Salan", "Paneer Tikka"],
            "total_sales": [45000.5, 12000.0, 23500.0]
        })
        spec = build_declarative_chart_spec(
            df=df,
            chart_type="bar",
            title="Top Dishes",
            x_field="dish_name",
            y_field="total_sales",
            currency_symbol="₹"
        )
        self.assertEqual(spec["chart_type"], "bar")
        self.assertEqual(spec["title"], "Top Dishes")
        self.assertEqual(spec["x_field"], "dish_name")
        self.assertEqual(spec["y_field"], "total_sales")
        self.assertEqual(len(spec["data"]), 3)
        self.assertIn("chart_id", spec)

    def test_04_create_and_list_conversations(self):
        """Tests creating a conversation and retrieving user's conversation list."""
        headers = {"Authorization": f"Bearer {self.admin_deccan_token}"}

        # Create conversation
        res = self.client.post("/api/v1/chat/conversations", json={
            "title": "Revenue Audit Q3",
            "branch_id": 1
        }, headers=headers)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        conv_id = data["conversation_id"]
        self.assertEqual(data["title"], "Revenue Audit Q3")

        # List conversations
        list_res = self.client.get("/api/v1/chat/conversations", headers=headers)
        self.assertEqual(list_res.status_code, 200)
        convs = list_res.json()
        self.assertTrue(any(c["conversation_id"] == conv_id for c in convs))

    def test_05_multi_tenant_conversation_isolation(self):
        """Verifies that admin_nizam cannot access or modify admin_deccan's conversation."""
        headers_deccan = {"Authorization": f"Bearer {self.admin_deccan_token}"}
        headers_nizam = {"Authorization": f"Bearer {self.admin_nizam_token}"}

        # 1. Deccan creates conversation
        res = self.client.post("/api/v1/chat/conversations", json={
            "title": "Deccan Secret Discussion"
        }, headers=headers_deccan)
        conv_id = res.json()["conversation_id"]

        # 2. Nizam attempts to read it -> 404
        nizam_res = self.client.get(f"/api/v1/chat/conversations/{conv_id}", headers=headers_nizam)
        self.assertEqual(nizam_res.status_code, 404)

        # 3. Nizam attempts to rename it -> 404
        rename_res = self.client.patch(f"/api/v1/chat/conversations/{conv_id}", json={
            "title": "Hacked Title"
        }, headers=headers_nizam)
        self.assertEqual(rename_res.status_code, 404)

        # 4. Nizam attempts to delete it -> 404
        delete_res = self.client.delete(f"/api/v1/chat/conversations/{conv_id}", headers=headers_nizam)
        self.assertEqual(delete_res.status_code, 404)

    def test_06_branch_switch_system_event(self):
        """Verifies recording a branch-switch system event in the conversation."""
        headers = {"Authorization": f"Bearer {self.admin_deccan_token}"}

        # Create conversation
        res = self.client.post("/api/v1/chat/conversations", json={"title": "Branch Test"}, headers=headers)
        conv_id = res.json()["conversation_id"]

        # Post branch switch event to branch_id=2 (Jubilee Hills, restaurant_id=1)
        event_res = self.client.post(f"/api/v1/chat/conversations/{conv_id}/system-event", json={
            "branch_id": 2,
            "branch_name": "Jubilee Hills Luxe"
        }, headers=headers)
        self.assertEqual(event_res.status_code, 200)
        self.assertIn("Switched to branch: Jubilee Hills Luxe", event_res.json()["content"])

        # Fetch history to verify system message was saved
        history_res = self.client.get(f"/api/v1/chat/conversations/{conv_id}", headers=headers)
        self.assertEqual(history_res.status_code, 200)
        messages = history_res.json()["messages"]
        self.assertTrue(any(m["role"] == "system" and "Jubilee Hills Luxe" in m["content"] for m in messages))

    def test_07_unauthorized_branch_rejection(self):
        """Verifies that a branch manager cannot record or query another branch."""
        headers = {"Authorization": f"Bearer {self.mgr_madhapur_token}"} # Pinned to branch_id=1

        # Manager creates conversation
        res = self.client.post("/api/v1/chat/conversations", json={"title": "Manager Chat"}, headers=headers)
        conv_id = res.json()["conversation_id"]

        # Attempt to switch to branch 2 (unauthorized) -> 403
        event_res = self.client.post(f"/api/v1/chat/conversations/{conv_id}/system-event", json={
            "branch_id": 2
        }, headers=headers)
        self.assertEqual(event_res.status_code, 403)

    def test_08_rename_and_delete_conversation(self):
        """Verifies renaming and deleting a conversation."""
        headers = {"Authorization": f"Bearer {self.admin_deccan_token}"}

        res = self.client.post("/api/v1/chat/conversations", json={"title": "Original Title"}, headers=headers)
        conv_id = res.json()["conversation_id"]

        # Rename
        rename_res = self.client.patch(f"/api/v1/chat/conversations/{conv_id}", json={
            "title": "Renamed Title"
        }, headers=headers)
        self.assertEqual(rename_res.status_code, 200)
        self.assertEqual(rename_res.json()["title"], "Renamed Title")

        # Delete
        del_res = self.client.delete(f"/api/v1/chat/conversations/{conv_id}", headers=headers)
        self.assertEqual(del_res.status_code, 200)

        # Verify not found
        get_res = self.client.get(f"/api/v1/chat/conversations/{conv_id}", headers=headers)
        self.assertEqual(get_res.status_code, 404)


if __name__ == "__main__":
    unittest.main()

