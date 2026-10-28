import sys
import os
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_settings_backend():
    print("=" * 80)
    print("TESTING SETTINGS ENDPOINTS: HEALTH, PRINTER TEST & PASSWORD CHANGE")
    print("=" * 80)

    # 1. Health Endpoints (both /health and /api/v1/health)
    res = client.get("/health")
    assert res.status_code == 200, f"Health endpoint failed: {res.text}"
    health_data = res.json()
    assert health_data["status"] == "healthy"
    assert "version" in health_data
    print(f"✓ Health endpoint (/health) OK: {health_data}")

    res_api = client.get("/api/v1/health")
    assert res_api.status_code == 200, f"API v1 health endpoint failed: {res_api.text}"
    assert res_api.json()["status"] == "healthy"
    print("✓ Health endpoint (/api/v1/health) OK: 200 OK")

    # 2. Login as admin_deccan
    res = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "admin123"})
    assert res.status_code == 200, f"Login failed: {res.text}"
    token = res.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✓ admin_deccan authenticated successfully")

    # 3. Test Printer Slip Endpoint (Default & Custom Printer Name)
    res = client.post("/api/v1/billing/printer/test", json={"printer_name": "Retsol_POS_80"}, headers=headers)
    assert res.status_code == 200, f"Printer test failed: {res.text}"
    print(f"✓ Printer test response: {res.json()}")

    # 4. Test Password Change - Wrong Current Password (Should Fail with 400)
    wrong_pw_payload = {
        "current_password": "wrong_password",
        "new_password": "new_password_123"
    }
    res = client.post("/api/v1/auth/change-password", json=wrong_pw_payload, headers=headers)
    assert res.status_code == 400, f"Expected 400 for wrong password, got {res.status_code}"
    print("✓ Wrong current password rejected with 400")

    # 5. Test Password Change - Too Short New Password (Should Fail with 400)
    short_pw_payload = {
        "current_password": "admin123",
        "new_password": "123"
    }
    res = client.post("/api/v1/auth/change-password", json=short_pw_payload, headers=headers)
    assert res.status_code == 400
    print("✓ Short new password rejected with 400")

    # 6. Test Password Change - Success and Revert Back
    success_pw_payload = {
        "current_password": "admin123",
        "new_password": "new_admin_pass_123"
    }
    res = client.post("/api/v1/auth/change-password", json=success_pw_payload, headers=headers)
    assert res.status_code == 200, f"Password change failed: {res.text}"
    print("✓ Password successfully updated")

    # Verify login with new password
    res = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "new_admin_pass_123"})
    assert res.status_code == 200
    new_token = res.json()["token"]
    new_headers = {"Authorization": f"Bearer {new_token}"}
    print("✓ Login with new password succeeded")

    # Revert password back to admin123 so local seed remains pristine
    revert_payload = {
        "current_password": "new_admin_pass_123",
        "new_password": "admin123"
    }
    res = client.post("/api/v1/auth/change-password", json=revert_payload, headers=new_headers)
    assert res.status_code == 200
    print("✓ Password reverted back to admin123 baseline")

    print("=" * 80)
    print("ALL SETTINGS BACKEND TESTS PASSED 100%!")
    print("=" * 80)

if __name__ == "__main__":
    test_settings_backend()

