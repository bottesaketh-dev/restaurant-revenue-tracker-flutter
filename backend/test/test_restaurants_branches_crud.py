import sys
import os
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from fastapi.testclient import TestClient
from main import app
from database import SessionLocal
import models

client = TestClient(app)

def run_tests():
    print("=" * 80)
    print("TESTING RESTAURANTS & BRANCHES CRUD AND ROLE-BASED ACCESS CONTROL")
    print("=" * 80)

    # 1. Login Super Admin
    res = client.post("/api/v1/auth/login", json={"username": "super_admin", "password": "admin123"})
    assert res.status_code == 200, f"Super admin login failed: {res.text}"
    super_token = res.json()["token"]
    super_headers = {"Authorization": f"Bearer {super_token}"}
    print("✓ Super Admin authenticated")

    # 2. Super Admin: List Restaurants
    res = client.get("/api/v1/restaurants", headers=super_headers)
    assert res.status_code == 200, f"List restaurants failed: {res.text}"
    restaurants = res.json()
    assert len(restaurants) >= 3, f"Expected at least 3 restaurants, got {len(restaurants)}"
    print(f"✓ Super Admin listed {len(restaurants)} restaurants")

    # 3. Super Admin: Create Restaurant
    new_rest_payload = {
        "name": "Kakatiya Royal Kitchen",
        "slug": "kakatiya-royal-kitchen",
        "contact_email": "info@kakatiyakitchen.com",
        "contact_phone": "+91 98480 99999",
        "currency_code": "INR",
        "currency_symbol": "₹",
        "tax_rate": "0.0500",
        "receipt_header": "Kakatiya Royal Kitchen - Warangal Heritage",
        "receipt_footer": "Thank you for dining with us!",
        "is_active": True
    }
    res = client.post("/api/v1/restaurants", json=new_rest_payload, headers=super_headers)
    assert res.status_code == 201, f"Create restaurant failed: {res.text}"
    created_rest = res.json()
    created_rest_id = created_rest["restaurant_id"]
    assert created_rest["name"] == "Kakatiya Royal Kitchen"
    print(f"✓ Super Admin created Restaurant #{created_rest_id} ({created_rest['name']})")

    # 4. Super Admin: Validate Duplicate Slug Rejection
    res = client.post("/api/v1/restaurants", json=new_rest_payload, headers=super_headers)
    assert res.status_code == 400, "Duplicate slug should be rejected with 400"
    print("✓ Duplicate restaurant slug rejected with 400")

    # 5. Super Admin: Update Restaurant
    update_payload = {"contact_phone": "+91 98480 88888", "is_active": True}
    res = client.put(f"/api/v1/restaurants/{created_rest_id}", json=update_payload, headers=super_headers)
    assert res.status_code == 200
    assert res.json()["contact_phone"] == "+91 98480 88888"
    print("✓ Super Admin updated Restaurant details")

    # 6. Super Admin: Create Branch under New Restaurant
    new_branch_payload = {
        "restaurant_id": created_rest_id,
        "name": "Hanamkonda Central",
        "address": "Opp. Public Gardens, Hanamkonda, Warangal, Telangana 506001",
        "phone": "+91 870 244 5555",
        "is_active": True
    }
    res = client.post("/api/v1/branches/", json=new_branch_payload, headers=super_headers)
    assert res.status_code == 201, f"Create branch failed: {res.text}"
    created_branch = res.json()
    created_branch_id = created_branch["branch_id"]
    assert created_branch["name"] == "Hanamkonda Central"
    assert created_branch["restaurant_id"] == created_rest_id
    print(f"✓ Super Admin created Branch #{created_branch_id} under Restaurant #{created_rest_id}")

    # 7. Super Admin: Update Branch
    res = client.put(f"/api/v1/branches/{created_branch_id}", json={"name": "Hanamkonda Grand Flagship"}, headers=super_headers)
    assert res.status_code == 200
    assert res.json()["name"] == "Hanamkonda Grand Flagship"
    print("✓ Super Admin updated Branch details")

    # 8. Super Admin: Soft-Deactivate or Delete Branch
    res = client.delete(f"/api/v1/branches/{created_branch_id}", headers=super_headers)
    assert res.status_code == 200
    print(f"✓ Super Admin deleted/deactivated Branch: {res.json()['message']}")

    # 9. Super Admin: Soft-Deactivate or Delete Restaurant
    res = client.delete(f"/api/v1/restaurants/{created_rest_id}", headers=super_headers)
    assert res.status_code == 200
    print(f"✓ Super Admin deleted/deactivated Restaurant: {res.json()['message']}")

    # 10. Role Test: Restaurant Admin (admin_deccan)
    res = client.post("/api/v1/auth/login", json={"username": "admin_deccan", "password": "admin123"})
    assert res.status_code == 200, f"admin_deccan login failed: {res.text}"
    deccan_headers = {"Authorization": f"Bearer {res.json()['token']}"}
    
    # 10a. Restaurant Admin cannot view Restaurants tab by default (403)
    res = client.get("/api/v1/restaurants", headers=deccan_headers)
    assert res.status_code == 403, f"Non-super admin should get 403 without grant, got {res.status_code}"
    print("✓ Restaurant Admin cannot access Restaurants tab by default (403 Forbidden)")

    # 10b. Restaurant Admin cannot create a restaurant (403)
    res = client.post("/api/v1/restaurants", json=new_rest_payload, headers=deccan_headers)
    assert res.status_code == 403
    print("✓ Restaurant Admin cannot create restaurants (403 Forbidden)")

    # 10c. Restaurant Admin CAN access Branches tab for their restaurant
    res = client.get("/api/v1/branches/", headers=deccan_headers)
    assert res.status_code == 200
    deccan_branches = res.json()
    assert len(deccan_branches) == 3, f"Expected Deccan to have 3 branches, got {len(deccan_branches)}"
    print(f"✓ Restaurant Admin accessed Branches tab for Deccan Spice ({len(deccan_branches)} branches)")

    # 10d. Restaurant Admin cannot create a branch under another restaurant (Restaurant 2)
    cross_branch_payload = {
        "restaurant_id": 2,
        "name": "Illegitimate Branch",
        "address": "Nowhere",
        "is_active": True
    }
    res = client.post("/api/v1/branches/", json=cross_branch_payload, headers=deccan_headers)
    assert res.status_code == 403
    print("✓ Cross-restaurant branch creation by Restaurant Admin rejected (403 Forbidden)")

    # 11. Role Test: Branch Manager (mgr_madhapur_1)
    res = client.post("/api/v1/auth/login", json={"username": "mgr_madhapur_1", "password": "password123"})
    assert res.status_code == 200, f"mgr_madhapur_1 login failed: {res.text}"
    mgr_headers = {"Authorization": f"Bearer {res.json()['token']}"}

    # 11a. Manager cannot view Restaurants tab
    res = client.get("/api/v1/restaurants", headers=mgr_headers)
    assert res.status_code == 403
    print("✓ Branch Manager cannot access Restaurants tab (403 Forbidden)")

    # 11b. Super Admin grants Restaurants tab access to mgr_madhapur_1 (User ID: 5)
    grant_payload = {"user_id": 5, "granted": True}
    res = client.post("/api/v1/restaurants/access/grant", json=grant_payload, headers=super_headers)
    assert res.status_code == 200
    print("✓ Super Admin granted Restaurants tab access to mgr_madhapur_1")

    # 11c. Now mgr_madhapur_1 CAN access Restaurants tab
    res = client.get("/api/v1/restaurants", headers=mgr_headers)
    assert res.status_code == 200, f"Expected 200 after grant, got {res.status_code}: {res.text}"
    print("✓ mgr_madhapur_1 can now view Restaurants tab after explicit grant")

    # 11d. However, mgr_madhapur_1 CANNOT create a restaurant (view != manage)
    res = client.post("/api/v1/restaurants", json=new_rest_payload, headers=mgr_headers)
    assert res.status_code == 403
    print("✓ mgr_madhapur_1 has view-only access and cannot create restaurants (403 Forbidden)")

    # 11e. Super Admin revokes Restaurants tab access
    revoke_payload = {"user_id": 5, "granted": False}
    res = client.post("/api/v1/restaurants/access/grant", json=revoke_payload, headers=super_headers)
    assert res.status_code == 200
    res = client.get("/api/v1/restaurants", headers=mgr_headers)
    assert res.status_code == 403
    print("✓ mgr_madhapur_1 access revoked: immediately blocked with 403 Forbidden")

    # 12. Ordinary Staff Role Test (staff_madhapur_1, User ID: 8)
    res = client.post("/api/v1/auth/login", json={"username": "staff_madhapur_1", "password": "password123"})
    assert res.status_code == 200, f"staff_madhapur_1 login failed: {res.text}"
    staff_headers = {"Authorization": f"Bearer {res.json()['token']}"}

    # 12a. Staff cannot access Branches tab by default
    res = client.get("/api/v1/branches/", headers=staff_headers)
    assert res.status_code == 403
    print("✓ Ordinary Staff cannot access Branches tab by default (403 Forbidden)")

    # 12b. Branch Manager (mgr_madhapur_1) grants Branches tab access to staff_madhapur_1 (User ID: 8)
    grant_branch_payload = {"user_id": 8, "granted": True}
    res = client.post("/api/v1/branches/access/grant", json=grant_branch_payload, headers=mgr_headers)
    assert res.status_code == 200
    print("✓ Branch Manager granted Branches tab access to staff_madhapur_1")

    # 12c. Now staff can view branches
    res = client.get("/api/v1/branches/", headers=staff_headers)
    assert res.status_code == 200
    print("✓ staff_madhapur_1 can now view Branches tab after grant")

    # 12d. Staff CANNOT create or delete branches
    res = client.post("/api/v1/branches/", json={"name": "Hacked Branch", "restaurant_id": 1}, headers=staff_headers)
    assert res.status_code == 403
    print("✓ staff_madhapur_1 cannot create branches (403 Forbidden)")

    # 12e. Branch Manager revokes Branches tab access
    revoke_branch_payload = {"user_id": 8, "granted": False}
    res = client.post("/api/v1/branches/access/grant", json=revoke_branch_payload, headers=mgr_headers)
    assert res.status_code == 200
    res = client.get("/api/v1/branches/", headers=staff_headers)
    assert res.status_code == 403
    print("✓ staff_madhapur_1 access revoked: immediately blocked with 403 Forbidden")

    # 12f. Branch Manager cannot grant access to a user in another branch/restaurant
    # User 12 is in Branch 2
    res = client.post("/api/v1/branches/access/grant", json={"user_id": 12, "granted": True}, headers=mgr_headers)
    assert res.status_code == 403
    print("✓ Branch Manager cannot grant access to out-of-scope user (403 Forbidden)")

    # 13. Centralized Users Tab Access Management Tests (PUT /api/v1/users/{user_id}/access)
    print("-" * 50)
    print("TESTING CENTRALIZED ACCESS MANAGEMENT VIA USERS TAB")
    print("-" * 50)

    # 13a. Restaurant Admin attempts to grant 'restaurants' tab access to User 8 -> MUST FAIL (403)
    unauthorized_tab_payload = {
        "access_level": "PARTIAL",
        "allowed_tabs": ["home", "pos", "restaurants"]
    }
    res = client.put("/api/v1/users/8/access", json=unauthorized_tab_payload, headers=deccan_headers)
    assert res.status_code == 403, f"Expected 403 when non-superadmin grants restaurants tab, got {res.status_code}"
    print("✓ Non-superadmin cannot grant 'restaurants' tab access via Users tab (403 Forbidden)")

    # 13b. Super Admin grants 'restaurants' tab access to User 8 via Users tab -> SUCCEEDS (200)
    super_tab_payload = {
        "access_level": "PARTIAL",
        "allowed_tabs": ["home", "pos", "restaurants", "branches"]
    }
    res = client.put("/api/v1/users/8/access", json=super_tab_payload, headers=super_headers)
    assert res.status_code == 200, f"Expected 200 when Super Admin grants restaurants tab, got {res.status_code}: {res.text}"
    user8_data = res.json()
    assert "restaurants" in user8_data["allowed_tabs"]
    assert "branches" in user8_data["allowed_tabs"]
    print("✓ Super Admin successfully granted 'restaurants' and 'branches' via Users tab")

    # 13c. Verify User 8 can now access Restaurants tab
    res = client.get("/api/v1/restaurants", headers=staff_headers)
    assert res.status_code == 200, f"Expected 200 for user 8 after grant, got {res.status_code}"
    print("✓ User 8 can now access Restaurants tab after grant via Users tab")

    # 13d. Super Admin revokes 'restaurants' tab access via Users tab
    revoke_tab_payload = {
        "access_level": "PARTIAL",
        "allowed_tabs": ["home", "pos", "branches"]
    }
    res = client.put("/api/v1/users/8/access", json=revoke_tab_payload, headers=super_headers)
    assert res.status_code == 200
    user8_revoked = res.json()
    assert "restaurants" not in user8_revoked["allowed_tabs"]
    print("✓ Super Admin revoked 'restaurants' tab via Users tab")

    # 13e. Verify User 8 is now blocked from Restaurants tab
    res = client.get("/api/v1/restaurants", headers=staff_headers)
    assert res.status_code == 403
    print("✓ User 8 immediately blocked from Restaurants tab (403 Forbidden)")

    # Reset User 8 back to clean state
    reset_payload = {"access_level": "FULL"}
    res = client.put("/api/v1/users/8/access", json=reset_payload, headers=super_headers)
    assert res.status_code == 200
    print("✓ User 8 access reset to FULL")

    print("=" * 80)
    print("ALL RESTAURANTS & BRANCHES CRUD AND CENTRALIZED ACCESS TESTS PASSED 100%!")
    print("=" * 80)

if __name__ == "__main__":
    run_tests()
