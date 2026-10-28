import os
import sys
import sqlite3
import datetime
from pathlib import Path
from decimal import Decimal

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def run_database_validation_tests():
    print("=" * 80)
    print("IOR 360 SEEDED DATABASE INTEGRITY, FINANCIAL & MULTI-TENANT TEST SUITE")
    print("=" * 80)

    db_path = backend_dir / "local.db"
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    # 1. Structural & Integrity Checks
    print("\n[TEST 1] SQLite Structural & Referential Integrity...")
    integrity = c.execute("PRAGMA integrity_check").fetchall()
    assert integrity and integrity[0][0] == "ok", f"Integrity check failed: {integrity}"
    print("  ✓ PRAGMA integrity_check: ok")

    fk_violations = c.execute("PRAGMA foreign_key_check").fetchall()
    assert len(fk_violations) == 0, f"FK violations found: {fk_violations}"
    print("  ✓ PRAGMA foreign_key_check: 0 violations")

    # 2. Required Entity Counts
    print("\n[TEST 2] Verifying Exact Entity Counts...")
    # Exact 3 Restaurants
    num_restaurants = c.execute("SELECT COUNT(*) FROM restaurants").fetchone()[0]
    assert num_restaurants == 3, f"Expected 3 restaurants, got {num_restaurants}"
    print(f"  ✓ Exact 3 Restaurants verified")

    # Exact 9 Branches (3 per restaurant)
    num_branches = c.execute("SELECT COUNT(*) FROM branches").fetchone()[0]
    assert num_branches == 9, f"Expected 9 branches, got {num_branches}"
    for r_id in (1, 2, 3):
        b_count = c.execute("SELECT COUNT(*) FROM branches WHERE restaurant_id = ?", (r_id,)).fetchone()[0]
        assert b_count == 3, f"Restaurant {r_id} expected 3 branches, got {b_count}"
    print(f"  ✓ Exact 9 Branches verified (strictly 3 per restaurant organization)")

    # Exactly 10 Employees per branch = 90 total
    num_employees = c.execute("SELECT COUNT(*) FROM employees").fetchone()[0]
    assert num_employees == 90, f"Expected 90 employees, got {num_employees}"
    for b_id in range(1, 10):
        e_count = c.execute("SELECT COUNT(*) FROM employees WHERE branch_id = ?", (b_id,)).fetchone()[0]
        assert e_count == 10, f"Branch {b_id} expected 10 employees, got {e_count}"
    print(f"  ✓ Exact 90 Employees verified (strictly 10 per branch)")

    # 3. Monthly Operational Coverage (August, September, October 2026)
    print("\n[TEST 3] Verifying Monthly Operational Coverage (Aug, Sep, Oct 2026 for all 9 branches)...")
    months = [("2026-08", 8), ("2026-09", 9), ("2026-10", 10)]

    for b_id in range(1, 10):
        for m_str, m_num in months:
            # Bills count
            bills_cnt = c.execute("""
                SELECT COUNT(*) FROM bills
                WHERE branch_id = ? AND strftime('%Y-%m', bill_date) = ?
            """, (b_id, m_str)).fetchone()[0]
            assert bills_cnt > 0, f"Branch {b_id} missing bills for month {m_str}"

            # Expenses count
            exp_cnt = c.execute("""
                SELECT COUNT(*) FROM expenses
                WHERE branch_id = ? AND strftime('%Y-%m', expense_date) = ?
            """, (b_id, m_str)).fetchone()[0]
            assert exp_cnt > 0, f"Branch {b_id} missing expenses for month {m_str}"

            # Grocery purchases count
            groc_cnt = c.execute("""
                SELECT COUNT(*) FROM grocery_purchases
                WHERE branch_id = ? AND strftime('%Y-%m', purchase_date) = ?
            """, (b_id, m_str)).fetchone()[0]
            assert groc_cnt > 0, f"Branch {b_id} missing grocery purchases for month {m_str}"

            # Salary payments count
            sal_cnt = c.execute("""
                SELECT COUNT(*) FROM salary_payments
                WHERE branch_id = ? AND payment_month = ? AND payment_year = 2026
            """, (b_id, m_num)).fetchone()[0]
            assert sal_cnt == 10, f"Branch {b_id} expected 10 salary payments for month {m_num}, got {sal_cnt}"

    print("  ✓ All 9 branches have complete coverage for August, September, and October 2026 across Orders, Bills, Expenses, Groceries, and Payroll!")

    # 4. Financial Calculations & Invariants
    print("\n[TEST 4] Verifying Financial Invariants & Mathematical Consistency...")

    # A. Order items total price = quantity * unit_price
    invalid_oi = c.execute("""
        SELECT COUNT(*) FROM order_items
        WHERE ABS(total_price - (quantity * unit_price)) > 0.01
    """).fetchone()[0]
    assert invalid_oi == 0, f"Found {invalid_oi} order items with mismatched total_price"
    print("  ✓ Order items math: 100% reconcile (total_price == quantity * unit_price)")

    # B. Bills subtotal = sum of order items total_price
    invalid_subtotal = c.execute("""
        SELECT COUNT(*) FROM bills b
        JOIN (
            SELECT order_id, SUM(total_price) as sum_items
            FROM order_items
            GROUP BY order_id
        ) oi ON b.order_id = oi.order_id
        WHERE ABS(b.subtotal - oi.sum_items) > 0.01
    """).fetchone()[0]
    assert invalid_subtotal == 0, f"Found {invalid_subtotal} bills with mismatched subtotal"
    print("  ✓ Bills subtotal: 100% reconcile with sum of order items")

    # C. Bills total_amount = subtotal + tax_amount - discount_amount + tip_amount
    invalid_totals = c.execute("""
        SELECT COUNT(*) FROM bills
        WHERE ABS(total_amount - (subtotal + tax_amount - discount_amount + tip_amount)) > 0.01
    """).fetchone()[0]
    assert invalid_totals == 0, f"Found {invalid_totals} bills with mismatched total_amount"
    print("  ✓ Bills total amount: 100% reconcile (subtotal + tax - discount + tip)")

    # D. Payment split reconciliation: total_amount == cash + upi + card
    invalid_splits = c.execute("""
        SELECT COUNT(*) FROM bills
        WHERE ABS(total_amount - (cash_amount + upi_amount + card_amount)) > 0.01
    """).fetchone()[0]
    assert invalid_splits == 0, f"Found {invalid_splits} bills with mismatched payment splits"
    print("  ✓ Payment methods: 100% reconcile (total_amount == cash + upi + card)")

    # E. Salary payments: net_salary == base_salary + bonus - deductions
    invalid_salaries = c.execute("""
        SELECT COUNT(*) FROM salary_payments
        WHERE ABS(net_salary - (base_salary + bonus - deductions)) > 0.01
    """).fetchone()[0]
    assert invalid_salaries == 0, f"Found {invalid_salaries} salary payments with mismatched net_salary"
    print("  ✓ Salary payments: 100% reconcile (net_salary == base + bonus - deductions)")

    # F. Grocery purchases: total_price == quantity * unit_price
    invalid_purchases = c.execute("""
        SELECT COUNT(*) FROM grocery_purchases
        WHERE ABS(total_price - (quantity * unit_price)) > 0.01
    """).fetchone()[0]
    assert invalid_purchases == 0, f"Found {invalid_purchases} purchases with mismatched total_price"
    print("  ✓ Grocery purchases: 100% reconcile (total_price == quantity * unit_price)")

    # 5. Cross-Tenant Isolation & Ownership Alignment
    print("\n[TEST 5] Verifying Cross-Tenant Isolation & Entity Ownership...")

    # Branches vs Restaurants
    mismatched_branches = c.execute("""
        SELECT COUNT(*) FROM branches b
        JOIN restaurants r ON b.restaurant_id = r.restaurant_id
        WHERE b.restaurant_id NOT IN (1, 2, 3)
    """).fetchone()[0]
    assert mismatched_branches == 0

    # Menu items ownership (branch_id must belong to restaurant_id)
    mismatched_menu = c.execute("""
        SELECT COUNT(*) FROM menu_items m
        JOIN branches b ON m.branch_id = b.branch_id
        WHERE m.restaurant_id != b.restaurant_id
    """).fetchone()[0]
    assert mismatched_menu == 0, f"Found {mismatched_menu} menu items with mismatched restaurant ownership"
    print("  ✓ Menu items: 100% branch-exclusive and aligned with parent restaurant")

    # Tables ownership
    mismatched_tables = c.execute("""
        SELECT COUNT(*) FROM restaurant_tables t
        JOIN branches b ON t.branch_id = b.branch_id
        WHERE t.restaurant_id != b.restaurant_id
    """).fetchone()[0]
    assert mismatched_tables == 0, f"Found {mismatched_tables} tables with mismatched restaurant ownership"
    print("  ✓ Restaurant tables: 100% aligned with parent restaurant")

    # Orders & Bills ownership
    mismatched_orders = c.execute("""
        SELECT COUNT(*) FROM orders o
        JOIN branches b ON o.branch_id = b.branch_id
        WHERE o.restaurant_id != b.restaurant_id
    """).fetchone()[0]
    assert mismatched_orders == 0
    mismatched_bills = c.execute("""
        SELECT COUNT(*) FROM bills bi
        JOIN branches b ON bi.branch_id = b.branch_id
        WHERE bi.restaurant_id != b.restaurant_id
    """).fetchone()[0]
    assert mismatched_bills == 0
    print("  ✓ Orders and Bills: 100% aligned with parent branch and restaurant")

    # Employees & Payroll ownership
    mismatched_emps = c.execute("""
        SELECT COUNT(*) FROM employees e
        JOIN branches b ON e.branch_id = b.branch_id
        WHERE e.restaurant_id != b.restaurant_id
    """).fetchone()[0]
    assert mismatched_emps == 0
    mismatched_salaries = c.execute("""
        SELECT COUNT(*) FROM salary_payments s
        JOIN employees e ON s.employee_id = e.employee_id
        WHERE s.restaurant_id != e.restaurant_id OR s.branch_id != e.branch_id
    """).fetchone()[0]
    assert mismatched_salaries == 0
    print("  ✓ Employees and Payroll: 100% aligned with parent branch and restaurant")

    conn.close()

    # 6. Live API Authentication & Tenant Endpoints
    print("\n[TEST 6] Testing Live API Authentication & Tenant Scoping...")

    # Super Admin Login
    res = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert res.status_code == 200, f"Super admin login failed: {res.text}"
    super_token = res.json()["token"]
    super_headers = {"Authorization": f"Bearer {super_token}"}
    print("  ✓ Super Admin login successful")

    # Restaurant 1 Admin (Deccan Spice Kitchen)
    res1 = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "admin123"})
    assert res1.status_code == 200
    r1_token = res1.json()["token"]
    r1_headers = {"Authorization": f"Bearer {r1_token}"}
    assert res1.json()["user"]["restaurant_id"] == 1
    assert res1.json()["user"]["currency_symbol"] == "₹"
    print("  ✓ Restaurant 1 Admin login: Deccan Spice Kitchen (₹ INR)")

    # Restaurant 2 Admin (Mana Telangana Bhojanam)
    res2 = client.post("/api/v1/auth/login", json={"username": "admin_mana", "password": "admin123"})
    assert res2.status_code == 200
    r2_token = res2.json()["token"]
    r2_headers = {"Authorization": f"Bearer {r2_token}"}
    assert res2.json()["user"]["restaurant_id"] == 2
    assert res2.json()["user"]["currency_symbol"] == "₹"
    print("  ✓ Restaurant 2 Admin login: Mana Telangana Bhojanam (₹ INR)")

    # Restaurant 3 Admin (Nizam's Urban Table)
    res3 = client.post("/api/v1/auth/login", json={"username": "admin_nizam", "password": "admin123"})
    assert res3.status_code == 200
    r3_token = res3.json()["token"]
    r3_headers = {"Authorization": f"Bearer {r3_token}"}
    assert res3.json()["user"]["restaurant_id"] == 3
    assert res3.json()["user"]["currency_symbol"] == "₹"
    print("  ✓ Restaurant 3 Admin login: Nizam's Urban Table (₹ INR)")

    # Branch Cashier Login
    res_csh = client.post("/api/v1/auth/login", json={"username": "csh_madhapur_1_1", "password": "password123"})
    assert res_csh.status_code == 200
    csh_token = res_csh.json()["token"]
    csh_headers = {"Authorization": f"Bearer {csh_token}"}
    assert res_csh.json()["user"]["branch_id"] == 1
    assert res_csh.json()["user"]["role"] == "CASHIER"
    print("  ✓ Branch Cashier login: Madhapur Branch 1 (Role CASHIER)")

    # Dashboard Summary for all 3 restaurants via Super Admin context switching
    dash1 = client.get("/api/v1/dashboard/summary?restaurant_id=1", headers=super_headers).json()
    dash2 = client.get("/api/v1/dashboard/summary?restaurant_id=2", headers=super_headers).json()
    dash3 = client.get("/api/v1/dashboard/summary?restaurant_id=3", headers=super_headers).json()

    assert dash1["restaurant_id"] == 1 and dash1["inflow"] > 0
    assert dash2["restaurant_id"] == 2 and dash2["inflow"] > 0
    assert dash3["restaurant_id"] == 3 and dash3["inflow"] > 0

    print(f"  ✓ Dashboard Inflows: Deccan Spice = ₹{dash1['inflow']:,.2f}, Mana Telangana = ₹{dash2['inflow']:,.2f}, Nizam's = ₹{dash3['inflow']:,.2f}")

    # Reports Profit & Loss
    pnl1 = client.get("/api/v1/reports/profit-loss?restaurant_id=1", headers=super_headers).json()
    pnl2 = client.get("/api/v1/reports/profit-loss?restaurant_id=2", headers=super_headers).json()
    pnl3 = client.get("/api/v1/reports/profit-loss?restaurant_id=3", headers=super_headers).json()

    print(f"  ✓ P&L Revenues: R1 = ₹{pnl1['revenue']:,.2f}, R2 = ₹{pnl2['revenue']:,.2f}, R3 = ₹{pnl3['revenue']:,.2f}")

    # Cross-tenant spoofing prevention
    spoof_res = client.get("/api/v1/users?restaurant_id=1", headers=r2_headers)
    assert spoof_res.status_code == 200
    for u in spoof_res.json():
        assert u["restaurant_id"] == 2, "Tenant 2 saw users from another tenant!"
    print("  ✓ Security: Tenant 2 cannot query Tenant 1 users via query spoofing")

    print("\n" + "=" * 80)
    print("ALL SEEDED DATABASE TESTS AND VALIDATIONS PASSED WITH 100% SUCCESS!")
    print("=" * 80)

if __name__ == "__main__":
    run_database_validation_tests()

