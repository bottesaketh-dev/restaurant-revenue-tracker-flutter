import sys
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_dashboard_outflow_breakdown():
    print("=" * 80)
    print("TESTING DASHBOARD OUTFLOW BREAKDOWN & CATEGORY INTEGRITY")
    print("=" * 80)

    # 1. Login as admin_deccan
    res = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "admin123"})
    assert res.status_code == 200, f"Login failed: {res.text}"
    token = res.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Get dashboard summary
    res_summary = client.get("/api/v1/dashboard/summary", headers=headers)
    assert res_summary.status_code == 200, f"Dashboard summary failed: {res_summary.text}"
    data = res_summary.json()

    # 3. Assert all outflow breakdown fields are present and numeric
    assert "outflow" in data, "Missing 'outflow' key"
    assert "grocery_outflow" in data, "Missing 'grocery_outflow' key"
    assert "expense_outflow" in data, "Missing 'expense_outflow' key"
    assert "salary_outflow" in data, "Missing 'salary_outflow' key"

    outflow = data["outflow"]
    grocery = data["grocery_outflow"]
    expense = data["expense_outflow"]
    salary = data["salary_outflow"]

    print(f"Total Outflow:   Rs {outflow:,.2f}")
    print(f"  - Groceries:   Rs {grocery:,.2f}")
    print(f"  - Expenses:    Rs {expense:,.2f}")
    print(f"  - Salaries:    Rs {salary:,.2f}")

    # Mathematical integrity: sum of components equals total outflow
    component_sum = round(grocery + expense + salary, 2)
    assert round(outflow, 2) == component_sum, f"Sum mismatch: {outflow} != {component_sum}"
    print(f"✓ Outflow mathematical integrity verified: {outflow} == {grocery} + {expense} + {salary}")

    # 4. Super Admin Global query
    res_super = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert res_super.status_code == 200
    super_headers = {"Authorization": f"Bearer {res_super.json()['token']}"}

    res_global = client.get("/api/v1/dashboard/summary", headers=super_headers)
    assert res_global.status_code == 200
    g_data = res_global.json()

    assert "grocery_outflow" in g_data
    assert "expense_outflow" in g_data
    assert "salary_outflow" in g_data
    g_tot = round(g_data["grocery_outflow"] + g_data["expense_outflow"] + g_data["salary_outflow"], 2)
    assert round(g_data["outflow"], 2) == g_tot
    print(f"✓ Super Admin global outflow breakdown verified: {g_data['outflow']} == {g_tot}")

    # 5. Branch Manager query (Madhapur Flagship, branch_id=1)
    res_mgr = client.post("/api/v1/auth/login", json={"username": "mgr_madhapur_1", "password": "password123"})
    assert res_mgr.status_code == 200
    mgr_headers = {"Authorization": f"Bearer {res_mgr.json()['token']}"}

    res_branch = client.get("/api/v1/dashboard/summary", headers=mgr_headers)
    assert res_branch.status_code == 200
    b_data = res_branch.json()

    assert "grocery_outflow" in b_data
    assert "expense_outflow" in b_data
    assert "salary_outflow" in b_data
    b_tot = round(b_data["grocery_outflow"] + b_data["expense_outflow"] + b_data["salary_outflow"], 2)
    assert round(b_data["outflow"], 2) == b_tot
    print(f"✓ Branch Manager scoped outflow breakdown verified: {b_data['outflow']} == {b_tot}")

    print("=" * 80)
    print("ALL DASHBOARD OUTFLOW BREAKDOWN TESTS PASSED 100%!")
    print("=" * 80)

if __name__ == "__main__":
    test_dashboard_outflow_breakdown()
