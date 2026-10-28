import sys
import os
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
import main, security

client = TestClient(main.app)

def test_support_info():
    response = client.get("/api/v1/support/info")
    assert response.status_code == 200
    data = response.json()
    assert "helpline" in data
    assert "whatsapp" in data
    assert data["service_status"] == "All Core Systems Operational"
    print("PASS: test_support_info")

def test_support_faqs():
    response = client.get("/api/v1/support/faqs")
    assert response.status_code == 200
    faqs = response.json()
    assert len(faqs) >= 4
    categories = [f["category"] for f in faqs]
    assert "Thermal Printer & Spooler" in categories
    assert "POS Billing & Cash Desk" in categories
    print(f"PASS: test_support_faqs ({len(faqs)} categories)")

def test_ticket_lifecycle():
    token = security.create_access_token({"sub": "1", "role": "SUPER_ADMIN", "restaurant_id": 1})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create ticket
    payload = {
        "category": "Thermal Printer & Spooler",
        "priority": "HIGH",
        "subject": "ESC/POS cutter jamming on 80mm roll",
        "description": "Paper jams when auto-cut fires during high-volume rush",
        "contact_phone": "+91 98490 00000",
        "metadata_json": '{"printer": "Retsol_POS_80", "paper": "80mm"}'
    }
    create_res = client.post("/api/v1/support/tickets", json=payload, headers=headers)
    assert create_res.status_code == 201
    ticket = create_res.json()
    ticket_id = ticket["ticket_id"]
    assert ticket["ticket_number"].startswith("TKT-2026-")
    assert ticket["status"] == "OPEN"
    assert ticket["priority"] == "HIGH"
    print(f"PASS: test_create_ticket -> {ticket['ticket_number']}")

    # 2. List tickets
    list_res = client.get("/api/v1/support/tickets", headers=headers)
    assert list_res.status_code == 200
    tickets = list_res.json()
    assert any(t["ticket_id"] == ticket_id for t in tickets)
    print(f"PASS: test_list_tickets (found {len(tickets)} tickets)")

    # 3. Update ticket status
    patch_payload = {
        "status": "RESOLVED",
        "resolution_notes": "Cleaned printer cutter blade and adjusted feed margin to 3 lines."
    }
    patch_res = client.patch(f"/api/v1/support/tickets/{ticket_id}/status", json=patch_payload, headers=headers)
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["status"] == "RESOLVED"
    assert "cutter blade" in updated["resolution_notes"]
    print(f"PASS: test_patch_ticket_status -> {updated['status']}")

def test_multi_tenant_ticket_isolation():
    # 1. Login as mgr_madhapur_1 (Restaurant 1, Branch 1)
    r_madhapur = client.post('/api/v1/auth/login', json={'username': 'mgr_madhapur_1', 'password': 'password123'})
    assert r_madhapur.status_code == 200
    token_madhapur = r_madhapur.json()['token']
    headers_madhapur = {'Authorization': f'Bearer {token_madhapur}'}

    # Create a ticket as mgr_madhapur_1
    t_payload = {
        'category': 'Kitchen & KOT',
        'priority': 'HIGH',
        'subject': 'KOT ticket printer ink faint',
        'description': 'Station 1 needs ribbon replacement',
        'contact_phone': '+91 99999 11111'
    }
    t_create = client.post('/api/v1/support/tickets', json=t_payload, headers=headers_madhapur)
    assert t_create.status_code == 201
    created_ticket = t_create.json()
    t_id = created_ticket['ticket_id']
    t_num = created_ticket['ticket_number']

    # 2. Login as admin_nizam (Restaurant 3)
    r_nizam = client.post('/api/v1/auth/login', json={'username': 'admin_nizam', 'password': 'admin123'})
    assert r_nizam.status_code == 200
    token_nizam = r_nizam.json()['token']
    headers_nizam = {'Authorization': f'Bearer {token_nizam}'}

    # Get tickets as admin_nizam: MUST NOT see tickets from Restaurant 1
    res_nizam = client.get('/api/v1/support/tickets', headers=headers_nizam)
    assert res_nizam.status_code == 200
    nizam_tickets = res_nizam.json()
    nizam_ticket_ids = [t['ticket_id'] for t in nizam_tickets]
    assert t_id not in nizam_ticket_ids, f'SECURITY VIOLATION: admin_nizam saw ticket {t_num} from Restaurant 1!'
    print('PASS: test_multi_tenant_ticket_isolation (admin_nizam cannot see mgr_madhapur_1 tickets)')

    # 3. admin_nizam attempts to modify ticket from Restaurant 1: MUST return 403
    patch_res = client.patch(f'/api/v1/support/tickets/{t_id}/status', json={'status': 'RESOLVED'}, headers=headers_nizam)
    assert patch_res.status_code == 403
    print('PASS: test_multi_tenant_ticket_isolation (admin_nizam blocked from modifying other tenant tickets with 403)')

if __name__ == "__main__":
    test_support_info()
    test_support_faqs()
    test_ticket_lifecycle()
    test_multi_tenant_ticket_isolation()
    print("\nALL SUPPORT BACKEND ENDPOINT TESTS PASSED!")

