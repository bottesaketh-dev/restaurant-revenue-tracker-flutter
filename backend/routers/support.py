from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import datetime
import random
import models, schemas, security
from database import get_db

router = APIRouter(prefix="/api/v1/support", tags=["support"])

@router.get("/info")
def get_support_info():
    """Returns official IOR 360 restaurant support desk details and status."""
    return {
        "helpline": "+91 40 4000 3600",
        "toll_free": "1800-IOR-360",
        "whatsapp": "+91 98490 12345",
        "email": "ops-emergency@ior360.com",
        "hours": "24/7 Operations Support Desk (Priority rush-hour coverage 12:00-15:30 & 19:00-23:30)",
        "sla": "Under 5 minutes during active rush hours, < 30 mins off-peak",
        "service_status": "All Core Systems Operational",
        "uptime": "99.98%",
        "version": "IOR 360 v2.4.0 (Build 2026.10)"
    }

@router.get("/faqs")
def get_faqs():
    """Categorized knowledge base articles for restaurant operators and cashiers."""
    return [
        {
            "category": "Thermal Printer & Spooler",
            "icon": "print",
            "items": [
                {
                    "question": "Printer shows 'Device Not Found' or fails to print receipts.",
                    "answer": "1. Ensure the Windows printer name in Settings > Printer matches Windows Control Panel exactly (e.g. 'Retsol_POS_80' or 'POS-80').\n2. Open Windows Services (services.msc) and restart the 'Print Spooler' service.\n3. Verify USB or Ethernet cable connection and that the printer paper roll is loaded thermal-side facing the print head.\n4. Click 'Test Print' under Settings > Printer to confirm byte transmission."
                },
                {
                    "question": "How to change the paper roll width (80mm vs 58mm)?",
                    "answer": "Navigate to Settings > Printer & Hardware. Select 58mm (approx 32 characters per line) or 80mm (approx 48 characters per line). The receipt layout preview adapts automatically to the selected width."
                },
                {
                    "question": "How to customize the header and footer on customer receipts?",
                    "answer": "Navigate to Settings > Receipt & Branding. Enter your custom header text (e.g., GSTIN, FSSAI License Number, restaurant address) and footer message (e.g., 'Thank you for dining with us! Please visit again.'). Click Save Receipt Template."
                }
            ]
        },
        {
            "category": "POS Billing & Cash Desk",
            "icon": "point_of_sale",
            "items": [
                {
                    "question": "How do I split a bill between Cash and UPI?",
                    "answer": "In the POS Billing screen, click the 'Split Payment' button. Enter the Cash portion and the UPI/Card portion. The sum must match the total bill amount. Once balanced, tap 'Complete Split Payment'."
                },
                {
                    "question": "How to handle a customer return or cancel an unpaid order?",
                    "answer": "Active orders before billing can be modified or cleared by pressing 'Clear Cart' or 'Esc'. For already settled bills, users with Manager/Admin privileges can navigate to Reports > Bills to view the bill log and mark it void with authorization."
                },
                {
                    "question": "What if internet connectivity drops during billing?",
                    "answer": "IOR 360 local instances run on local server hardware or desktop SQLite cache. Local billing operations continue uninterrupted. Once internet connectivity is restored, cloud sync resumes automatically."
                }
            ]
        },
        {
            "category": "Kitchen Display & KOT Workflow",
            "icon": "kitchen",
            "items": [
                {
                    "question": "How do kitchen staff see new orders?",
                    "answer": "When the cashier presses 'Submit Order' or 'KOT', tickets appear instantly on the Kitchen & Recipes tab sorted by timestamp. Kitchen staff can change item status from 'Pending' to 'Cooking' and finally 'Ready'."
                },
                {
                    "question": "Why is an ingredient not deducting from grocery inventory?",
                    "answer": "Ensure the menu item has a linked recipe configured in Kitchen > Recipe Ingredients. If an ingredient link is missing or unit conversion is unset, stock will not automatically decrement upon billing."
                }
            ]
        },
        {
            "category": "User Access & Multi-Tenant Security",
            "icon": "security",
            "items": [
                {
                    "question": "How do I grant a staff member access to specific tabs?",
                    "answer": "Restaurant Admins or Super Admins can go to the Users tab, select the user, and check the allowed tabs (e.g. POS Billing, Kitchen, Reports). Changes take effect on the user's next login or route refresh."
                },
                {
                    "question": "How to change my login password?",
                    "answer": "Click your Profile avatar at the top right of any screen to open Settings > My Profile. Fill in your current password, new password, and confirmation, then click 'Update Password'."
                }
            ]
        }
    ]

@router.get("/tickets", response_model=List[schemas.SupportTicketResponse])
def get_tickets(
    restaurant_id: Optional[int] = None,
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Retrieve support tickets scoped to current tenant/user."""
    query = db.query(models.SupportTicket)
    
    if not security.is_super_admin(current_user):
        eff_r_id = security.get_effective_restaurant_id(current_user)
        if eff_r_id is not None:
            query = query.filter(models.SupportTicket.restaurant_id == eff_r_id)
        else:
            user_id = current_user.get("user_id")
            query = query.filter(models.SupportTicket.user_id == user_id)

        # Branch-level isolation:
        # Branch Managers and Staff only see tickets for their branch or created by them
        user_role = (current_user.get("role") or "").upper()
        user_branch_id = current_user.get("branch_id")
        if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
            query = query.filter(
                (models.SupportTicket.branch_id == user_branch_id) | 
                (models.SupportTicket.user_id == current_user.get("user_id"))
            )
    else:
        req_r_id = restaurant_id or current_user.get("requested_restaurant_id")
        if req_r_id is not None:
            query = query.filter(models.SupportTicket.restaurant_id == req_r_id)
            
    if status_filter:
        query = query.filter(models.SupportTicket.status == status_filter.upper())
        
    return query.order_by(models.SupportTicket.ticket_id.desc()).all()

@router.post("/tickets", response_model=schemas.SupportTicketResponse, status_code=status.HTTP_201_CREATED)
def create_ticket(
    ticket_data: schemas.SupportTicketCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Raise a new priority support ticket."""
    user_id = current_user.get("user_id")
    
    # Strictly enforce tenant and branch boundaries from authenticated token
    if security.is_super_admin(current_user):
        eff_r_id = ticket_data.restaurant_id or current_user.get("requested_restaurant_id") or current_user.get("restaurant_id")
        eff_b_id = ticket_data.branch_id or current_user.get("branch_id")
    else:
        eff_r_id = security.get_effective_restaurant_id(current_user)
        user_branch_id = current_user.get("branch_id")
        eff_b_id = user_branch_id or ticket_data.branch_id
    
    # Generate unique ticket number: TKT-2026-XXXXX
    rand_suffix = random.randint(10000, 99999)
    ticket_num = f"TKT-2026-{rand_suffix}"
    
    # User display name if available
    user_obj = db.query(models.User).filter(models.User.user_id == user_id).first() if user_id else None
    user_name = user_obj.username if user_obj else (current_user.get("username") or "Operator")

    new_ticket = models.SupportTicket(
        ticket_number=ticket_num,
        restaurant_id=eff_r_id,
        branch_id=eff_b_id,
        user_id=user_id,
        user_name=user_name,
        category=ticket_data.category,
        priority=ticket_data.priority.upper(),
        subject=ticket_data.subject,
        description=ticket_data.description,
        contact_phone=ticket_data.contact_phone,
        status="OPEN",
        metadata_json=ticket_data.metadata_json
    )
    
    db.add(new_ticket)
    db.commit()
    db.refresh(new_ticket)
    return new_ticket

@router.patch("/tickets/{ticket_id}/status", response_model=schemas.SupportTicketResponse)
def update_ticket_status(
    ticket_id: int,
    update_data: schemas.SupportTicketUpdateStatus,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Update status or resolution notes of a support ticket."""
    ticket = db.query(models.SupportTicket).filter(models.SupportTicket.ticket_id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Support ticket not found")
        
    # Tenant boundary enforcement
    if not security.is_super_admin(current_user):
        eff_r_id = security.get_effective_restaurant_id(current_user)
        if ticket.restaurant_id != eff_r_id:
            raise HTTPException(status_code=403, detail="Access denied: Cannot modify ticket from another organization.")

    ticket.status = update_data.status.upper()
    if update_data.resolution_notes is not None:
        ticket.resolution_notes = update_data.resolution_notes
        
    db.commit()
    db.refresh(ticket)
    return ticket
