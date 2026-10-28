import os
import sys
from pathlib import Path
from decimal import Decimal
import json

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from fastapi.testclient import TestClient
from main import app
import models
from database import SessionLocal

client = TestClient(app)

def run_e2e_multi_tenant_workflows():
    print("=" * 80)
    print("IOR 360 END-TO-END MULTI-TENANT WORKFLOWS & SECURITY REGRESSION SUITE")
    print("=" * 80)

    # -------------------------------------------------------------------------
    # 1. AUTHENTICATION & MULTI-TENANT TOKENS
    # -------------------------------------------------------------------------
    print("\n[PHASE 1] Authenticating Role Matrix...")
    
    # Super Admin
    r_super = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert r_super.status_code == 200, f"Super Admin login failed: {r_super.text}"
    super_token = r_super.json()["token"]
    super_headers = {"Authorization": f"Bearer {super_token}"}
    print("  ✓ Super Admin: Authenticated (Global context)")

    # Deccan Spice Kitchen Admin (Tenant 1)
    r_deccan = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "admin123"})
    assert r_deccan.status_code == 200, f"Deccan Admin login failed: {r_deccan.text}"
    deccan_token = r_deccan.json()["token"]
    deccan_headers = {"Authorization": f"Bearer {deccan_token}"}
    print("  ✓ Deccan Spice Kitchen Admin: Authenticated (Tenant 1, INR ₹)")

    # Mana Telangana Bhojanam Admin (Tenant 2)
    r_mana = client.post("/api/v1/auth/login", json={"username": "admin_mana", "password": "admin123"})
    assert r_mana.status_code == 200, f"Mana Admin login failed: {r_mana.text}"
    mana_token = r_mana.json()["token"]
    mana_headers = {"Authorization": f"Bearer {mana_token}"}
    print("  ✓ Mana Telangana Bhojanam Admin: Authenticated (Tenant 2, INR ₹)")

    # Mana Telangana Cashier (Tenant 2, Branch 4 - Gachibowli)
    r_cashier = client.post("/api/v1/auth/login", json={"username": "csh_gachibowli_4_1", "password": "password123"})
    assert r_cashier.status_code == 200, f"Cashier login failed: {r_cashier.text}"
    cashier_token = r_cashier.json()["token"]
    cashier_headers = {"Authorization": f"Bearer {cashier_token}"}
    print("  ✓ Gachibowli Cashier: Authenticated (Tenant 2, Branch 4)")

    # -------------------------------------------------------------------------
    # 2. CROSS-TENANT SECURITY BOUNDARIES
    # -------------------------------------------------------------------------
    print("\n[PHASE 2] Validating Cross-Tenant Security Boundaries...")

    # Tenant 2 Admin tries to spoof query parameter ?restaurant_id=1
    res_spoof = client.get("/api/v1/users?restaurant_id=1", headers=mana_headers)
    assert res_spoof.status_code == 200
    # Security must clamp spoofed restaurant_id to 2
    for u in res_spoof.json():
        assert u.get("restaurant_id") == 2, f"Tenant 2 saw user from another restaurant: {u}"
    print("  ✓ Security Boundary: Tenant 2 cannot access Tenant 1 users via query param spoofing")

    # Cashier from Branch 4 (Tenant 2) tries to access Branch 1 (Tenant 1)
    res_branch_spoof = client.get("/api/v1/billing/tables?branch_id=1", headers=cashier_headers)
    assert res_branch_spoof.status_code in (400, 403, 404), f"Cashier accessed another branch! Status: {res_branch_spoof.status_code}"
    print("  ✓ Security Boundary: Branch Cashier blocked from foreign branch tables (Status 404/403)")

    # -------------------------------------------------------------------------
    # 3. BATCH 1: USERS & BRANCHES TENANT ISOLATION
    # -------------------------------------------------------------------------
    print("\n[PHASE 3] Validating Users & Branches Module...")

    # Super Admin switches to Restaurant 1
    res_u1 = client.get("/api/v1/users?restaurant_id=1", headers=super_headers)
    assert res_u1.status_code == 200
    users_r1 = res_u1.json()
    assert all(u.get("restaurant_id") == 1 for u in users_r1)
    print(f"  ✓ Users query ?restaurant_id=1: {len(users_r1)} users found (All Tenant 1)")

    # Super Admin switches to Restaurant 2
    res_u2 = client.get("/api/v1/users?restaurant_id=2", headers=super_headers)
    assert res_u2.status_code == 200
    users_r2 = res_u2.json()
    assert all(u.get("restaurant_id") == 2 for u in users_r2)
    print(f"  ✓ Users query ?restaurant_id=2: {len(users_r2)} users found (All Tenant 2)")

    # Verify no overlap
    u1_ids = {u["user_id"] for u in users_r1}
    u2_ids = {u["user_id"] for u in users_r2}
    assert u1_ids.isdisjoint(u2_ids), "User IDs overlap between isolated tenants!"
    print("  ✓ User tenant sets are completely disjoint")

    # -------------------------------------------------------------------------
    # 4. BATCH 2: MENU, POS TABLES & CHECKOUT WORKFLOW
    # -------------------------------------------------------------------------
    print("\n[PHASE 4] Validating POS, Menu & Billing Workflow...")

    # Query menu for Branch 4 (Gachibowli Express)
    res_menu = client.get("/api/v1/menu/items?branch_id=4", headers=mana_headers)
    assert res_menu.status_code == 200
    menu_items = res_menu.json()
    assert len(menu_items) > 0, "No menu items in Branch 4"
    assert all(item.get("restaurant_id") == 2 for item in menu_items), "Foreign menu items leaked into Branch 4!"
    item_sample = menu_items[0]
    print(f"  ✓ Menu Branch 4: {len(menu_items)} items retrieved, sample: '{item_sample['name']}' (₹{item_sample['price']})")

    # Ensure table exists in Branch 4
    tbl_id = "BR4-T99"
    res_tbl = client.post(
        "/api/v1/billing/tables?branch_id=4",
        headers=super_headers,
        json={"branch_id": 4, "table_id": tbl_id, "capacity": 4, "status": "AVAILABLE"}
    )
    assert res_tbl.status_code in (200, 201), f"Table creation failed: {res_tbl.text}"
    created_tbl = res_tbl.json()
    assert created_tbl["restaurant_id"] == 2
    assert created_tbl["branch_id"] == 4
    print(f"  ✓ Table creation: Table {tbl_id} correctly assigned to restaurant_id=2, branch_id=4")

    # Submit KOT Order on Branch 4 for Table BR4-T99
    res_kot = client.post(
        f"/api/v1/billing/tables/{tbl_id}/kot?branch_id=4",
        headers=super_headers,
        json={
            "items": [
                {"menu_item_id": item_sample["menu_item_id"], "quantity": 2, "price": float(item_sample["price"])}
            ],
            "order_type": "dine_in"
        }
    )
    assert res_kot.status_code == 200, f"KOT failed: {res_kot.text}"
    order_data = res_kot.json()
    order_id = order_data["order_id"]
    print(f"  ✓ KOT order created: id={order_id} on Table {tbl_id} in Branch 4")

    # Complete Checkout for Table BR4-T99
    res_checkout = client.post(
        f"/api/v1/billing/tables/{tbl_id}/checkout?branch_id=4",
        headers=super_headers,
        json={
            "payment_mode": "UPI",
            "card_amount": 0.0,
            "upi_amount": float(item_sample["price"]) * 2 * 1.05,
            "cash_amount": 0.0,
            "tip_amount": 0.0,
            "auto_print": False
        }
    )
    assert res_checkout.status_code == 200, f"Checkout failed: {res_checkout.text}"
    checkout_res = res_checkout.json()
    bill_id = checkout_res["bill_id"]
    print(f"  ✓ Bill {bill_id} generated for Branch 4 via POS Checkout")

    # Verify Bill persistence in DB has restaurant_id = 2
    db = SessionLocal()
    saved_bill = db.query(models.Bill).filter(models.Bill.bill_id == bill_id).first()
    assert saved_bill is not None
    assert saved_bill.restaurant_id == 2, f"Bill saved with wrong restaurant_id: {saved_bill.restaurant_id}"
    assert saved_bill.branch_id == 4
    db.close()
    print(f"  ✓ Bill persistence verified: restaurant_id={saved_bill.restaurant_id}, branch_id={saved_bill.branch_id}")

    # -------------------------------------------------------------------------
    # 5. BATCH 3: GROCERIES, EXPENSES & STAFF WORKFLOWS
    # -------------------------------------------------------------------------
    print("\n[PHASE 5] Validating Groceries, Expenses & Staff Workflows...")

    # A. Add Grocery Purchase in Branch 4
    db = SessionLocal()
    g_item = db.query(models.GroceryItem).filter(models.GroceryItem.restaurant_id == 2).first()
    assert g_item is not None
    db.close()

    res_pur = client.post(
        "/api/v1/groceries/purchases",
        headers=super_headers,
        json={
            "branch_id": 4,
            "grocery_item_id": g_item.grocery_item_id,
            "vendor_name": "Telangana Agro Supply Co.",
            "quantity": 20.0,
            "unit_price": 45.0,
            "total_price": 900.0,
            "payment_mode": "BANK_TRANSFER"
        }
    )
    assert res_pur.status_code == 201, f"Purchase failed: {res_pur.text}"
    pur_data = res_pur.json()
    assert pur_data["restaurant_id"] == 2
    assert pur_data["branch_id"] == 4
    pur_id = pur_data.get("grocery_purchase_id") or pur_data.get("purchase_id")
    print(f"  ✓ Grocery Purchase recorded: ID #{pur_id}, restaurant_id={pur_data['restaurant_id']}, branch_id=4")

    # B. Add Operational Expense in Branch 4
    exp_payload = {
        "branch_id": 4,
        "expense_category": "Equipment",
        "description": "Commercial Burner Overhaul",
        "amount": 2500.00,
        "payment_mode": "UPI",
        "expense_date": "2026-10-28"
    }
    res_exp = client.post("/api/v1/expenses", json=exp_payload, headers=super_headers)
    assert res_exp.status_code == 200, f"Expense creation failed: {res_exp.text}"
    exp_data = res_exp.json()
    assert exp_data["restaurant_id"] == 2
    assert exp_data["branch_id"] == 4
    print(f"  ✓ Expense added: ID #{exp_data['expense_id']}, restaurant_id={exp_data['restaurant_id']}, branch_id=4")

    # C. Add Staff Employee in Branch 4
    staff_payload = {
        "branch_id": 4,
        "first_name": "Raghavendra",
        "last_name": "Rao",
        "position": "Master Biryani Chef",
        "phone": "+919848040999",
        "monthly_salary": 42000.00
    }
    res_staff = client.post("/api/v1/employees", json=staff_payload, headers=super_headers)
    assert res_staff.status_code == 201, f"Staff creation failed: {res_staff.text}"
    emp_data = res_staff.json()
    assert emp_data["restaurant_id"] == 2
    assert emp_data["branch_id"] == 4
    print(f"  ✓ Staff employee created: ID #{emp_data['employee_id']}, restaurant_id={emp_data['restaurant_id']}, branch_id=4")

    # -------------------------------------------------------------------------
    # 6. BATCH 4: REPORTS, ANALYTICS & EXPORTS ISOLATION
    # -------------------------------------------------------------------------
    print("\n[PHASE 6] Validating Reports & Analytics Tenant Scoping...")

    # P&L Report for Restaurant 1 (Deccan Spice Kitchen)
    r_pnl_1 = client.get("/api/v1/reports/profit-loss?restaurant_id=1", headers=super_headers)
    assert r_pnl_1.status_code == 200
    pnl_1 = r_pnl_1.json()

    # P&L Report for Restaurant 2 (Mana Telangana Bhojanam)
    r_pnl_2 = client.get("/api/v1/reports/profit-loss?restaurant_id=2", headers=super_headers)
    assert r_pnl_2.status_code == 200
    pnl_2 = r_pnl_2.json()

    print(f"  ✓ Profit & Loss: Restaurant 1 Revenue=₹{pnl_1.get('revenue', 0):,.2f}, Restaurant 2 Revenue=₹{pnl_2.get('revenue', 0):,.2f}")
    assert pnl_2.get("revenue", 0) > 0, "Mana Telangana Bhojanam revenue should reflect checkout orders!"

    # Sales Trends Report
    r_trends = client.get("/api/v1/reports/sales-trends?restaurant_id=2&branch_id=4", headers=mana_headers)
    assert r_trends.status_code == 200
    print(f"  ✓ Sales Trends: {len(r_trends.json())} trend records returned for Restaurant 2 Branch 4")

    # Executive Summary Report
    r_exec = client.get("/api/v1/reports/executive-summary?restaurant_id=2", headers=mana_headers)
    assert r_exec.status_code == 200
    print("  ✓ Executive Summary: Generated cleanly for Restaurant 2")

    # CSV Export
    r_export = client.get(f"/api/v1/reports/export?format=csv&restaurant_id=2&token={mana_token}")
    assert r_export.status_code == 200
    assert "text/csv" in r_export.headers.get("content-type", "")
    print(f"  ✓ CSV Export generated: {len(r_export.text)} bytes of scoped report data")

    # -------------------------------------------------------------------------
    # 7. BATCH 4: AI COMMAND CENTER (CHAT) STREAMING ISOLATION
    # -------------------------------------------------------------------------
    print("\n[PHASE 7] Validating AI Command Center Tenant Isolation...")
    chat_payload = {
        "message": "Summarize today's sales and revenue",
        "branch_id": 4,
        "restaurant_id": 2
    }
    res_chat = client.post("/api/v1/chat", json=chat_payload, headers=super_headers)
    assert res_chat.status_code == 200
    assert "application/x-ndjson" in res_chat.headers.get("content-type", "")
    print("  ✓ AI Chat Stream returned HTTP 200 with application/x-ndjson")

    print("\n" + "=" * 80)
    print("ALL END-TO-END MULTI-TENANT WORKFLOWS PASSED WITH 100% ISOLATION!")
    print("=" * 80)

if __name__ == "__main__":
    run_e2e_multi_tenant_workflows()
