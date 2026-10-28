import os
import sys
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_home_switching_and_tenant_isolation():
    print("=" * 70)
    print("RUNNING HOME DASHBOARD RESTAURANT SWITCHING & ISOLATION TESTS")
    print("=" * 70)

    # 1. Login as Super Admin
    res = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert res.status_code == 200, f"Super admin login failed: {res.text}"
    token = res.json()["token"]
    super_headers = {"Authorization": f"Bearer {token}"}
    print("✓ Super Admin authenticated")

    # 2. Query dashboard with restaurant_id=1 (Spice Symphony Dining)
    res_spice = client.get("/api/v1/dashboard/summary?restaurant_id=1", headers=super_headers)
    assert res_spice.status_code == 200
    spice_data = res_spice.json()
    assert spice_data["currency_symbol"] == "₹", f"Expected ₹, got {spice_data['currency_symbol']}"
    assert spice_data["currency_code"] == "INR"
    assert spice_data["restaurant_id"] == 1
    assert spice_data["inflow"] == 0.0
    assert spice_data["outflow"] == 0.0
    assert len(spice_data["recent_bills"]) == 0
    print(f"✓ Super Admin query ?restaurant_id=1: Spice Symphony ({spice_data['currency_symbol']} {spice_data['currency_code']}, inflow={spice_data['inflow']}, bills={len(spice_data['recent_bills'])})")

    # 3. Query dashboard with restaurant_id=2 (Bella Italia Trattoria)
    res_bella = client.get("/api/v1/dashboard/summary?restaurant_id=2", headers=super_headers)
    assert res_bella.status_code == 200
    bella_data = res_bella.json()
    assert bella_data["currency_symbol"] == "€", f"Expected €, got {bella_data['currency_symbol']}"
    assert bella_data["currency_code"] == "EUR"
    assert bella_data["restaurant_id"] == 2
    assert bella_data["inflow"] > 0, "Expected non-zero inflow for Bella Italia"
    assert bella_data["outflow"] > 0, "Expected non-zero outflow for Bella Italia"
    assert len(bella_data["recent_bills"]) > 0
    print(f"✓ Super Admin query ?restaurant_id=2: Bella Italia ({bella_data['currency_symbol']} {bella_data['currency_code']}, inflow={bella_data['inflow']}, bills={len(bella_data['recent_bills'])})")

    # 4. Header-based Switching via X-Restaurant-ID: 1
    res_h1 = client.get("/api/v1/dashboard/summary", headers={**super_headers, "X-Restaurant-ID": "1"})
    assert res_h1.status_code == 200
    h1_data = res_h1.json()
    assert h1_data["currency_symbol"] == spice_data["currency_symbol"]
    assert h1_data["restaurant_id"] == 1
    assert h1_data["inflow"] == spice_data["inflow"]
    print("✓ Super Admin header X-Restaurant-ID: 1 exactly matches query param ?restaurant_id=1")

    # 5. Header-based Switching via X-Restaurant-ID: 2
    res_h2 = client.get("/api/v1/dashboard/summary", headers={**super_headers, "X-Restaurant-ID": "2"})
    assert res_h2.status_code == 200
    h2_data = res_h2.json()
    assert h2_data["currency_symbol"] == bella_data["currency_symbol"]
    assert h2_data["restaurant_id"] == 2
    assert h2_data["inflow"] == bella_data["inflow"]
    assert h2_data["outflow"] == bella_data["outflow"]
    print("✓ Super Admin header X-Restaurant-ID: 2 exactly matches query param ?restaurant_id=2")

    # 6. Rapid Back-and-Forth Alternation (Zero cross-tenant state pollution)
    for i in range(5):
        r1 = client.get("/api/v1/dashboard/summary?restaurant_id=1", headers=super_headers).json()
        r2 = client.get("/api/v1/dashboard/summary?restaurant_id=2", headers=super_headers).json()
        assert r1["currency_symbol"] == "₹" and r1["inflow"] == spice_data["inflow"] and r1["restaurant_id"] == 1
        assert r2["currency_symbol"] == "€" and r2["inflow"] == bella_data["inflow"] and r2["restaurant_id"] == 2
    print("✓ Rapid alternating switching (1 <-> 2 repeated 5 times) preserves 100% data integrity")

    # 7. Non-Super Admin Security Boundary Test
    # Login as Bella Italia Admin (restaurant_id=2)
    res_bella_login = client.post("/api/v1/auth/login", json={"username": "admin_bella", "password": "admin123"})
    bella_admin_token = res_bella_login.json()["token"]
    bella_admin_headers = {"Authorization": f"Bearer {bella_admin_token}"}

    # Attempt to access Spice Symphony (restaurant_id=1) by query or header
    res_spoof = client.get("/api/v1/dashboard/summary?restaurant_id=1", headers=bella_admin_headers)
    assert res_spoof.status_code == 200
    spoof_data = res_spoof.json()
    assert spoof_data["restaurant_id"] == 2
    assert spoof_data["currency_symbol"] == "€"
    assert spoof_data["inflow"] == bella_data["inflow"]
    print("✓ Security enforcement: Non-Super Admin cannot escape tenant boundary via query param")

    res_spoof_h = client.get("/api/v1/dashboard/summary", headers={**bella_admin_headers, "X-Restaurant-ID": "1"})
    assert res_spoof_h.status_code == 200
    spoof_h_data = res_spoof_h.json()
    assert spoof_h_data["restaurant_id"] == 2
    assert spoof_h_data["currency_symbol"] == "€"
    assert spoof_h_data["inflow"] == bella_data["inflow"]
    print("✓ Security enforcement: Non-Super Admin cannot escape tenant boundary via X-Restaurant-ID header")

    print("\n" + "=" * 70)
    print("ALL HOME DASHBOARD SWITCHING & DATA ISOLATION TESTS PASSED PERFECTLY!")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    test_home_switching_and_tenant_isolation()

