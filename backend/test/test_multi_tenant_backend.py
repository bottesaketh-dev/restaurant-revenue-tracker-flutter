import os
import sys
from pathlib import Path

# Add backend directory to path
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

def test_suite():
    print("=" * 70)
    print("STARTING COMPREHENSIVE MULTI-TENANT BACKEND TEST SUITE")
    print("=" * 70)

    # 1. Root health check
    print("\n[TEST 1] Testing Root Endpoint...")
    res = client.get("/")
    assert res.status_code == 200, f"Root failed: {res.text}"
    assert res.json() == {"message": "Welcome to IOR 360 API"}
    print("  ✓ Root endpoint passed: IOR 360 API")

    # 2. Auth Flow & Tenant Identifiers
    print("\n[TEST 2] Testing Authentication & Token Tenant Scoping...")
    
    # Super Admin Login
    res = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert res.status_code == 200, f"Super admin login failed: {res.text}"
    super_body = res.json()
    super_user = super_body["user"]
    assert super_user["role"] == "SUPER_ADMIN"
    assert super_user["restaurant_id"] is None
    super_token = super_body["token"]
    super_headers = {"Authorization": f"Bearer {super_token}"}
    print("  ✓ Super admin login successful: role=SUPER_ADMIN, restaurant_id=None")

    # Spice Symphony (Restaurant 1) Admin Login
    res = client.post("/api/v1/auth/login", json={"username": "admin_spice", "password": "admin123"})
    assert res.status_code == 200, f"Spice admin login failed: {res.text}"
    spice_body = res.json()
    spice_user = spice_body["user"]
    assert spice_user["role"] == "RESTAURANT_ADMIN"
    assert spice_user["restaurant_id"] == 1
    assert spice_user["currency_symbol"] == "₹"
    assert spice_user["restaurant_name"] == "Spice Symphony Dining"
    spice_token = spice_body["token"]
    spice_headers = {"Authorization": f"Bearer {spice_token}"}
    print("  ✓ Spice Symphony admin login successful: restaurant_id=1, currency=₹, name='Spice Symphony Dining'")

    # Bella Italia (Restaurant 2) Admin Login
    res = client.post("/api/v1/auth/login", json={"username": "admin_bella", "password": "admin123"})
    assert res.status_code == 200, f"Bella admin login failed: {res.text}"
    bella_body = res.json()
    bella_user = bella_body["user"]
    assert bella_user["role"] == "RESTAURANT_ADMIN"
    assert bella_user["restaurant_id"] == 2
    assert bella_user["currency_symbol"] == "€"
    assert bella_user["restaurant_name"] == "Bella Italia Trattoria"
    bella_token = bella_body["token"]
    bella_headers = {"Authorization": f"Bearer {bella_token}"}
    print("  ✓ Bella Italia admin login successful: restaurant_id=2, currency=€, name='Bella Italia Trattoria'")

    # Session endpoints
    res = client.get("/api/v1/auth/me", headers=bella_headers)
    assert res.status_code == 200
    assert res.json()["restaurant_id"] == 2
    assert res.json()["restaurant_name"] == "Bella Italia Trattoria"
    print("  ✓ GET /api/v1/auth/me returns active tenant profile")

    # 3. Restaurant Tenant Management Endpoints
    print("\n[TEST 3] Testing /api/v1/restaurants Multi-Tenant Management...")
    
    # Super admin lists all restaurants
    res = client.get("/api/v1/restaurants", headers=super_headers)
    assert res.status_code == 200
    all_rests = res.json()
    assert len(all_rests) >= 2
    rest_ids = [r["restaurant_id"] for r in all_rests]
    assert 1 in rest_ids and 2 in rest_ids
    print(f"  ✓ Super Admin can view all {len(all_rests)} registered restaurant tenants")

    # Bella admin lists restaurants -> only sees their own organization
    res = client.get("/api/v1/restaurants", headers=bella_headers)
    assert res.status_code == 200
    bella_rests = res.json()
    assert len(bella_rests) == 1
    assert bella_rests[0]["restaurant_id"] == 2
    print("  ✓ Bella Admin only sees Restaurant 2 (No leakage of Restaurant 1)")

    # Bella admin gets current restaurant
    res = client.get("/api/v1/restaurants/current", headers=bella_headers)
    assert res.status_code == 200
    assert res.json()["restaurant_id"] == 2
    assert res.json()["currency_code"] == "EUR"
    print("  ✓ GET /api/v1/restaurants/current returns EUR profile")

    # Bella admin updates receipt configuration
    res = client.put(
        "/api/v1/restaurants/2",
        headers=bella_headers,
        json={"receipt_header": "Benvenuti da Bella Italia", "receipt_footer": "Arrivederci e grazie!"}
    )
    assert res.status_code == 200
    assert res.json()["receipt_header"] == "Benvenuti da Bella Italia"
    assert res.json()["receipt_footer"] == "Arrivederci e grazie!"
    print("  ✓ Bella Admin successfully updated receipt header/footer configuration")

    # Bella admin tries to update Restaurant 1 -> Forbidden 403
    res = client.put(
        "/api/v1/restaurants/1",
        headers=bella_headers,
        json={"name": "Hacked Restaurant"}
    )
    assert res.status_code == 403, f"Expected 403, got: {res.status_code}"
    print("  ✓ Cross-tenant update blocked with 403 Forbidden")

    # 4. Multi-Tenant Branch Isolation
    print("\n[TEST 4] Testing Multi-Tenant Branch Isolation...")
    
    # Spice admin gets branches -> only Restaurant 1 branches
    res = client.get("/api/v1/branches", headers=spice_headers)
    assert res.status_code == 200
    spice_branches = res.json()
    assert len(spice_branches) == 15
    for b in spice_branches:
        assert b["restaurant_id"] == 1
    print(f"  ✓ Spice Admin retrieved {len(spice_branches)} branches strictly scoped to restaurant_id=1")

    # Bella admin gets branches -> only Bella branches
    res = client.get("/api/v1/branches", headers=bella_headers)
    assert res.status_code == 200
    bella_branches = res.json()
    assert len(bella_branches) >= 1
    assert all(b["restaurant_id"] == 2 for b in bella_branches)
    assert any(b["branch_id"] == 16 for b in bella_branches)
    print(f"  ✓ Bella Admin retrieved strictly {len(bella_branches)} branches for restaurant_id=2 (0 cross-contamination with Restaurant 1)")

    # Bella admin attempts to access Branch 1 -> 404 Not Found
    res = client.get("/api/v1/branches/1", headers=bella_headers)
    assert res.status_code == 404
    print("  ✓ Cross-tenant branch access /branches/1 by Bella blocked with 404 Not Found")

    # Check or create 2nd branch under Bella Italia
    existing_b2 = next((b for b in bella_branches if b["name"] == "Bella Milan North"), None)
    if existing_b2:
        bella_branch_2_id = existing_b2["branch_id"]
    else:
        res = client.post(
            "/api/v1/branches",
            headers=bella_headers,
            json={"name": "Bella Milan North", "address": "Corso Buenos Aires 12, Milan", "phone": "+39 02 123456"}
        )
        assert res.status_code == 201
        bella_branch_2 = res.json()
        assert bella_branch_2["restaurant_id"] == 2
        bella_branch_2_id = bella_branch_2["branch_id"]
    print(f"  ✓ Bella Admin second branch active (id={bella_branch_2_id}) under restaurant_id=2")

    # Verify Spice Admin still only sees 15 branches
    res = client.get("/api/v1/branches", headers=spice_headers)
    assert len(res.json()) == 15
    print("  ✓ Spice Admin branch count unchanged (15 branches)")

    # 5. Branch-Exclusive Menu Isolation
    print("\n[TEST 5] Testing Branch-Exclusive Menu Isolation...")
    
    # Query menu items for Branch 16 (Bella Rome)
    res = client.get("/api/v1/menu/items?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    branch_16_items = res.json()
    assert len(branch_16_items) >= 1
    item_names = [it["name"] for it in branch_16_items]
    assert "Truffle Tagliolini" in item_names
    print(f"  ✓ Branch 16 has exclusive menu: {item_names}")

    # Query menu items for newly created Branch 2 of Bella -> should be empty initially or only its own items
    res = client.get(f"/api/v1/menu/items?branch_id={bella_branch_2_id}", headers=bella_headers)
    assert res.status_code == 200
    branch_2_items = res.json()
    # Confirm it does NOT have Truffle Tagliolini from Branch 16
    assert "Truffle Tagliolini" not in [it["name"] for it in branch_2_items]
    print("  ✓ Branch 2 does not share Branch 16's menu (Verifies menus are strictly branch-exclusive, NOT shared)")

    # Bella admin creates "Margherita DOC Pizza" in Branch 16 if not exists
    existing_pizza = next((it for it in branch_16_items if it["name"] == "Margherita DOC Pizza"), None)
    if existing_pizza:
        pizza_id = existing_pizza["menu_item_id"]
    else:
        res = client.post(
            "/api/v1/menu/items",
            headers=bella_headers,
            json={
                "branch_id": 16,
                "name": "Margherita DOC Pizza",
                "category": "Main Course",
                "price": 14.50,
                "is_vegetarian": True,
                "is_available": True
            }
        )
        assert res.status_code == 201
        new_pizza = res.json()
        assert new_pizza["restaurant_id"] == 2
        assert new_pizza["branch_id"] == 16
        pizza_id = new_pizza["menu_item_id"]
    print(f"  ✓ 'Margherita DOC Pizza' (id={pizza_id}) strictly in branch_id=16, restaurant_id=2")

    # Bella admin attempts to create an item in Branch 1 (Spice Symphony's branch) -> blocked!
    res = client.post(
        "/api/v1/menu/items",
        headers=bella_headers,
        json={
            "branch_id": 1,
            "name": "Illegal Item",
            "category": "Dessert",
            "price": 9.99
        }
    )
    assert res.status_code in [403, 404]
    print(f"  ✓ Cross-tenant menu creation on Branch 1 by Bella blocked ({res.status_code})")

    # Spice Admin queries Branch 1 items -> 301 items, neither Truffle Tagliolini nor Margherita DOC Pizza is present
    res = client.get("/api/v1/menu/items?branch_id=1", headers=spice_headers)
    assert res.status_code == 200
    spice_menu = res.json()
    spice_item_names = {it["name"] for it in spice_menu}
    assert "Truffle Tagliolini" not in spice_item_names
    assert "Margherita DOC Pizza" not in spice_item_names
    print(f"  ✓ Spice Symphony Branch 1 ({len(spice_menu)} items) has zero leakage of Bella Italia items")

    # 6. Table & POS Billing Flow on local.db
    print("\n[TEST 6] Testing Multi-Tenant POS Billing & Table Isolation...")
    
    # List tables in Branch 16
    res = client.get("/api/v1/billing/tables?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    tables = res.json()
    if not tables or not any(t["table_id"] == "RM-T01" for t in tables):
        # Create Table T1 in Branch 16
        res = client.post(
            "/api/v1/billing/tables?branch_id=16",
            headers=bella_headers,
            json={"branch_id": 16, "table_id": "RM-T01", "capacity": 4, "status": "AVAILABLE"}
        )
        assert res.status_code == 201
        print("  ✓ Created Table 'RM-T01' in Branch 16")
    else:
        print(f"  ✓ Branch 16 tables: {[t['table_id'] for t in tables]}")

    # Submit KOT Order on Branch 16 for Table RM-T01
    res = client.post(
        "/api/v1/billing/tables/RM-T01/kot?branch_id=16",
        headers=bella_headers,
        json={
            "items": [
                {"menu_item_id": pizza_id, "quantity": 2, "price": 14.50}
            ],
            "order_type": "dine_in"
        }
    )
    assert res.status_code == 200, f"KOT failed: {res.text}"
    order_data = res.json()
    order_id = order_data["order_id"]
    print(f"  ✓ KOT order created: id={order_id} on Table RM-T01 in Branch 16")

    # Complete Checkout for Table RM-T01
    res = client.post(
        "/api/v1/billing/tables/RM-T01/checkout?branch_id=16",
        headers=bella_headers,
        json={
            "payment_mode": "CARD",
            "card_amount": 31.90,
            "tip_amount": 2.00,
            "auto_print": False
        }
    )
    assert res.status_code == 200, f"Checkout failed: {res.text}"
    checkout_res = res.json()
    bill_id = checkout_res["bill_id"]
    print(f"  ✓ Bill {bill_id} generated for Branch 16 via POS Checkout")

    # Fetch bills for Branch 16 and verify tenant data
    res = client.get("/api/v1/billing/bills?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    bella_bills = res.json()
    bill_data = next((b for b in bella_bills if b["bill_id"] == bill_id), None)
    assert bill_data is not None
    assert bill_data["restaurant_id"] == 2
    assert bill_data["branch_id"] == 16
    print(f"  ✓ Verified Bill {bill_id} in Branch 16: restaurant_id=2, branch_id=16")

    # Verify Spice admin query for bills on Branch 1 does NOT see bill_id
    res = client.get("/api/v1/billing/bills?branch_id=1", headers=spice_headers)
    assert res.status_code == 200
    spice_bill_ids = [b["bill_id"] for b in res.json()]
    assert bill_id not in spice_bill_ids
    print("  ✓ Spice Symphony bills do NOT contain Bella Italia bill (Complete isolation)")

    # 7. Groceries & Branch Inventory
    print("\n[TEST 7] Testing Groceries & Branch Inventory Scoping...")
    
    # Get or create grocery category
    res = client.get("/api/v1/groceries/categories", headers=bella_headers)
    assert res.status_code == 200
    bella_cats = res.json()
    existing_cat = next((c for c in bella_cats if c["name"] == "Latticini Italiani"), None)
    if existing_cat:
        cat_id = existing_cat["grocery_category_id"]
    else:
        res = client.post(
            "/api/v1/groceries/categories",
            headers=bella_headers,
            json={"name": "Latticini Italiani"}
        )
        assert res.status_code == 201
        bella_cat = res.json()
        assert bella_cat["restaurant_id"] == 2
        cat_id = bella_cat["grocery_category_id"]

    # Get or create grocery item
    res = client.get("/api/v1/groceries/items", headers=bella_headers)
    assert res.status_code == 200
    bella_items = res.json()
    existing_item = next((i for i in bella_items if i["product_name"] == "Mozzarella di Bufala Campana"), None)
    if existing_item:
        groc_item_id = existing_item["grocery_item_id"]
    else:
        res = client.post(
            "/api/v1/groceries/items",
            headers=bella_headers,
            json={"grocery_category_id": cat_id, "product_name": "Mozzarella di Bufala Campana", "unit": "kg"}
        )
        assert res.status_code == 201
        bella_item = res.json()
        assert bella_item["restaurant_id"] == 2
        groc_item_id = bella_item["grocery_item_id"]
    print("  ✓ Created grocery category & item under restaurant_id=2")

    # Bella records purchase in Branch 16
    res = client.post(
        "/api/v1/groceries/purchases",
        headers=bella_headers,
        json={
            "branch_id": 16,
            "grocery_item_id": groc_item_id,
            "vendor_name": "Napoli Dairy SpA",
            "quantity": 25.0,
            "unit_price": 8.0,
            "total_price": 200.0,
            "payment_mode": "BANK_TRANSFER"
        }
    )
    assert res.status_code == 201
    purchase_data = res.json()
    assert purchase_data["restaurant_id"] == 2
    assert purchase_data["branch_id"] == 16
    print("  ✓ Recorded purchase of 25 kg Mozzarella for Branch 16 (Auto-upserted branch inventory)")

    # Verify inventory stock for Branch 16
    res = client.get("/api/v1/groceries/stock?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    stocks = res.json()
    assert len(stocks) >= 1
    stock_items = [s["product_name"] for s in stocks]
    assert "Mozzarella di Bufala Campana" in stock_items
    print(f"  ✓ Branch 16 Inventory Stock correctly updated: {stock_items}")

    # Verify Spice Admin listing groceries does NOT see Mozzarella di Bufala
    res = client.get("/api/v1/groceries/items", headers=spice_headers)
    assert res.status_code == 200
    spice_groc = [i["product_name"] for i in res.json()]
    assert "Mozzarella di Bufala Campana" not in spice_groc
    print("  ✓ Spice Symphony grocery inventory does NOT contain Bella Italia items")

    # 8. Staff & HR Isolation
    print("\n[TEST 8] Testing Staff Directory & HR Isolation...")
    
    # Check or create employee
    res = client.get("/api/v1/employees", headers=bella_headers)
    assert res.status_code == 200
    bella_emps = res.json()
    existing_emp = next((e for e in bella_emps if e["first_name"] == "Marco" and e["last_name"] == "Rossi"), None)
    if existing_emp:
        emp_id = existing_emp["employee_id"]
    else:
        res = client.post(
            "/api/v1/employees",
            headers=bella_headers,
            json={
                "branch_id": 16,
                "first_name": "Marco",
                "last_name": "Rossi",
                "position": "Executive Chef",
                "phone": "+39 06 998877",
                "monthly_salary": 3200.00
            }
        )
        assert res.status_code == 201
        emp_data = res.json()
        assert emp_data["restaurant_id"] == 2
        assert emp_data["branch_id"] == 16
        emp_id = emp_data["employee_id"]
    print(f"  ✓ Employee 'Marco Rossi' (id={emp_id}) active in Branch 16, restaurant_id=2")

    # Bella records salary payment if not already processed
    res = client.get(f"/api/v1/employees/salary/all?month=10&year=2026&branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    existing_salaries = res.json()
    if not any(s["employee_id"] == emp_id for s in existing_salaries):
        res = client.post(
            "/api/v1/employees/salary",
            headers=bella_headers,
            json={
                "employee_id": emp_id,
                "branch_id": 16,
                "payment_month": 10,
                "payment_year": 2026,
                "base_salary": 3200.00,
                "deductions": 200.00,
                "net_salary": 3000.00,
                "payment_mode": "BANK_TRANSFER",
                "payment_status": "PAID"
            }
        )
        assert res.status_code == 201
        sal_data = res.json()
        assert sal_data["restaurant_id"] == 2
        print("  ✓ Recorded salary payment for Marco Rossi")
    else:
        print("  ✓ Verified existing salary payment for Marco Rossi")

    # Verify Spice Admin listing employees does NOT see Marco Rossi
    res = client.get("/api/v1/employees", headers=spice_headers)
    assert res.status_code == 200
    spice_emps = [f"{e['first_name']} {e['last_name']}" for e in res.json()]
    assert "Marco Rossi" not in spice_emps
    print("  ✓ Spice Symphony employee directory does NOT contain Marco Rossi")

    # 9. Dashboard Summary Isolation
    print("\n[TEST 9] Testing Dashboard Summary Multi-Tenant Scoping...")
    
    # Bella dashboard
    res = client.get("/api/v1/dashboard/summary?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    bella_dash = res.json()
    assert bella_dash["restaurant_id"] == 2
    assert bella_dash["currency_symbol"] == "€"
    assert len(bella_dash["recent_bills"]) >= 1
    assert any(b["bill_id"] == bill_id for b in bella_dash["recent_bills"])
    print(f"  ✓ Bella Dashboard: currency=€, recent bill {bill_id} present")

    # Bella attempting to access Branch 1 dashboard -> 404
    res = client.get("/api/v1/dashboard/summary?branch_id=1", headers=bella_headers)
    assert res.status_code == 404
    print("  ✓ Bella accessing Branch 1 dashboard blocked with 404 Not Found")

    # Spice dashboard
    res = client.get("/api/v1/dashboard/summary?branch_id=1", headers=spice_headers)
    assert res.status_code == 200
    spice_dash = res.json()
    assert spice_dash["restaurant_id"] == 1
    assert spice_dash["currency_symbol"] == "₹"
    for b in spice_dash["recent_bills"]:
        assert b["bill_id"] != bill_id
    print("  ✓ Spice Dashboard: currency=₹, 0 leakage of Bella data")

    # 10. Reports & Analytics Scoping
    print("\n[TEST 10] Testing Reports & Analytics Scoping...")
    
    # Profit & Loss for Bella
    res = client.get("/api/v1/reports/profit-loss?branch_id=16", headers=bella_headers)
    assert res.status_code == 200
    pl = res.json()
    assert "revenue" in pl and "cogs" in pl and "net_profit" in pl
    print(f"  ✓ Bella P&L: revenue={pl['revenue']}, cogs={pl['cogs']}, net_profit={pl['net_profit']}")

    # Branch comparison for Bella -> should ONLY have Branch 16 and Branch 2, NO Spice branches
    res = client.get("/api/v1/reports/branch-comparison", headers=bella_headers)
    assert res.status_code == 200
    bella_branch_comp = res.json()
    bella_comp_names = [b["branch_name"] for b in bella_branch_comp]
    for b in spice_branches:
        assert b["name"] not in bella_comp_names, f"Leakage! {b['name']} in Bella branch comparison"
    print(f"  ✓ Bella Branch Comparison: {bella_comp_names} (No Spice Symphony branches!)")

    # Branch comparison for Spice -> should NOT have 'Bella Rome Central'
    res = client.get("/api/v1/reports/branch-comparison", headers=spice_headers)
    assert res.status_code == 200
    spice_branch_comp = res.json()
    spice_comp_names = [b["branch_name"] for b in spice_branch_comp]
    assert "Bella Rome Central" not in spice_comp_names
    assert "Bella Milan North" not in spice_comp_names
    print(f"  ✓ Spice Branch Comparison ({len(spice_comp_names)} branches): 0 leakage of Bella branches")

    # Report PDF export for Bella
    res = client.get(f"/api/v1/reports/export?format=pdf&branch_id=16&token={bella_token}")
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"
    assert "bella_italia_trattoria" in res.headers["content-disposition"].lower()
    print("  ✓ Bella PDF report exported with custom filename and headers")

    # Report CSV export for Bella
    res = client.get(f"/api/v1/reports/export?format=csv&branch_id=16&token={bella_token}")
    assert res.status_code == 200
    assert "Bella Italia Trattoria" in res.text
    print("  ✓ Bella CSV report exported with restaurant header and currency")

    # 11. User Management & Authorization
    print("\n[TEST 11] Testing User Management & Privilege Enforcement...")
    
    # Spice admin lists users -> only Restaurant 1 users
    res = client.get("/api/v1/users", headers=spice_headers)
    assert res.status_code == 200
    spice_users = res.json()
    for u in spice_users:
        assert u["restaurant_id"] == 1
    print(f"  ✓ Spice Admin listing users returns {len(spice_users)} users strictly in restaurant_id=1")

    # Bella admin creates Cashier for Branch 16 if not exists
    res = client.get("/api/v1/users", headers=bella_headers)
    assert res.status_code == 200
    bella_users = res.json()
    existing_cashier = next((u for u in bella_users if u["username"] == "cashier_rome"), None)
    if not existing_cashier:
        res = client.post(
            "/api/v1/users",
            headers=bella_headers,
            json={
                "username": "cashier_rome",
                "email": "cashier_rome@bellaitalia.com",
                "password": "password123",
                "role": "CASHIER",
                "branch_id": 16
            }
        )
        assert res.status_code == 201, f"Create user failed: {res.text}"
        cashier_user = res.json()
        assert cashier_user["restaurant_id"] == 2
        assert cashier_user["branch_id"] == 16
        print("  ✓ Created cashier 'cashier_rome' bound to Branch 16 in Restaurant 2")
    else:
        print("  ✓ Cashier 'cashier_rome' verified in Branch 16")

    # Cashier logs in
    res = client.post("/api/v1/auth/login", json={"username": "cashier_rome", "password": "password123"})
    assert res.status_code == 200, f"Cashier login failed: {res.text}"
    cashier_token = res.json()["token"]
    cashier_headers = {"Authorization": f"Bearer {cashier_token}"}

    # Cashier tries to create a user -> 403 Forbidden!
    res = client.post(
        "/api/v1/users",
        headers=cashier_headers,
        json={"username": "hack_admin", "password": "123", "role": "SUPER_ADMIN"}
    )
    assert res.status_code == 403
    print("  ✓ Cashier forbidden from creating users (403 Forbidden)")

    print("\n" + "=" * 70)
    print("ALL 11 TEST SUITES PASSED FLAWLESSLY WITH 100% TENANT ISOLATION!")
    print("=" * 70)

if __name__ == "__main__":
    test_suite()
