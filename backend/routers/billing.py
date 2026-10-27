import os
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, security
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from decimal import Decimal
from uuid import uuid4

router = APIRouter(prefix="/api/v1/billing", tags=["billing"])

TAX_RATE = Decimal(os.getenv("TAX_RATE", "0.05"))

def _resolve_branch(current_user: dict, branch_id: Optional[int] = None, require_branch: bool = False) -> Optional[int]:
    """Cleanly resolve the effective branch_id from JWT claims."""
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        return user_branch_id
    b_id = branch_id or user_branch_id
    if require_branch and b_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required for this operation")
    return b_id

@router.get("/tables", response_model=List[schemas.TableResponse])
def get_tables(branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id)
    query = db.query(models.RestaurantTable).filter(models.RestaurantTable.is_active == True)
    if b_id:
        query = query.filter(models.RestaurantTable.branch_id == b_id)
    return query.all()

@router.post("/tables/bulk", response_model=List[schemas.TableResponse])
def create_tables(tables: List[schemas.TableCreate], branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id, require_branch=True)
    created = []
    for t in tables:
        existing = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == t.table_id).first()
        if existing:
            existing.capacity = t.capacity
            existing.is_active = True
            if existing.status == None:
                existing.status = "available"
            created.append(existing)
        else:
            new_table = models.RestaurantTable(
                table_id=t.table_id,
                capacity=t.capacity,
                status="available",
                branch_id=b_id,
                is_active=True
            )
            db.add(new_table)
            created.append(new_table)
    db.commit()
    for c in created:
        db.refresh(c)
    return created

@router.put("/tables/{table_id}", response_model=schemas.TableResponse)
def update_table(table_id: str, table_update: schemas.TableUpdate, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
    if not db_table:
        raise HTTPException(status_code=404, detail="Table not found")
    
    update_data = table_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        if key != 'table_id':
            setattr(db_table, key, value)
            
    db.commit()
    db.refresh(db_table)
    return db_table

@router.delete("/tables/{table_id}")
def delete_table(table_id: str, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
    if not db_table:
        raise HTTPException(status_code=404, detail="Table not found")
    
    db_table.is_active = False
    db.commit()
    return {"status": "deleted"}

@router.get("/tables/{table_id}/order", response_model=Optional[schemas.OrderResponse])
def get_active_order(table_id: str, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    order = db.query(models.Order).filter(
        models.Order.table_id == table_id,
        models.Order.status == 'active'
    ).first()
    if not order:
        return None
    return order

class KotItem(BaseModel):
    menu_item_id: int
    quantity: int
    notes: Optional[str] = None
    price: float

class KotRequest(BaseModel):
    items: List[KotItem]
    order_type: str = "dine_in" # dine_in or takeaway

@router.post("/tables/{table_id}/kot")
def submit_kot(table_id: str, request: KotRequest, branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id, require_branch=True)
    
    # Find active order
    order = db.query(models.Order).filter(
        models.Order.table_id == table_id,
        models.Order.status == 'active'
    ).first()
    
    # Handle order cancellation when cart is completely empty
    if not request.items:
        if order:
            db.query(models.OrderItem).filter(models.OrderItem.order_id == order.order_id).delete()
            db.delete(order)
            
            if request.order_type == "dine_in" and table_id != "TAKEAWAY":
                table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
                if table:
                    table.status = "available"
            
            db.commit()
        return {"status": "deleted"}
    
    if not order:
        # Ensure TAKEAWAY table exists if order_type is takeaway
        if request.order_type == "takeaway":
            takeaway_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == "TAKEAWAY").first()
            if not takeaway_table:
                takeaway_table = models.RestaurantTable(
                    table_id="TAKEAWAY",
                    capacity=0,
                    status="available",
                    branch_id=1,
                    is_active=False
                )
                db.add(takeaway_table)
                db.flush()

        order = models.Order(
            order_id=f"ORD-{uuid4().hex[:12].upper()}",
            table_id=table_id if request.order_type == "dine_in" else "TAKEAWAY",
            status="active",
            created_by=current_user["user_id"],
            branch_id=b_id,
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
        db.add(order)
        db.flush()
    else:
        order.updated_at = datetime.now()
    
    # Remove existing items to do a full sync with the frontend cart
    db.query(models.OrderItem).filter(models.OrderItem.order_id == order.order_id).delete()
    
    for item in request.items:
        order_item = models.OrderItem(
            order_id=order.order_id,
            menu_item_id=item.menu_item_id,
            quantity=item.quantity,
            unit_price=Decimal(str(item.price)),
            total_price=Decimal(str(item.price * item.quantity)),
            notes=item.notes,
            created_at=datetime.now()
        )
        db.add(order_item)
        
    # Mark table as occupied for dine in
    if request.order_type == "dine_in" and table_id != "TAKEAWAY":
        table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
        if table:
            table.status = "occupied"
            
    db.commit()
    
    # Auto-print KOT if items were submitted
    kot_print_status = None
    if request.items:
        try:
            from services.thermal_printer import generate_kot_receipt_bytes, send_raw_to_printer
            kot_items_data = []
            for item in request.items:
                m_item = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == item.menu_item_id).first()
                kot_items_data.append({
                    "name": m_item.name if m_item else f"Item #{item.menu_item_id}",
                    "quantity": item.quantity,
                    "notes": item.notes,
                })
            kot_bytes = generate_kot_receipt_bytes(
                table_id=table_id,
                order_type=request.order_type,
                time_str=datetime.now().strftime("%I:%M %p"),
                items=kot_items_data
            )
            success, msg = send_raw_to_printer(kot_bytes)
            kot_print_status = msg if success else f"KOT Print failed: {msg}"
        except Exception as pe:
            kot_print_status = f"Printer error: {str(pe)}"

    return {"status": "success", "order_id": order.order_id, "kot_print_status": kot_print_status}


class CheckoutRequest(BaseModel):
    payment_mode: str
    tip_amount: float = 0.0
    cash_amount: float = 0.0
    upi_amount: float = 0.0
    card_amount: float = 0.0
    auto_print: bool = True

@router.post("/tables/{table_id}/checkout")
def checkout(table_id: str, request: CheckoutRequest, branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id, require_branch=True)
    
    # 1. Fetch active order
    order = db.query(models.Order).filter(
        models.Order.table_id == table_id,
        models.Order.status == 'active'
    ).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="No active order for this table")
    
    # 2. Calculate subtotal from order items
    order_items = db.query(models.OrderItem).filter(models.OrderItem.order_id == order.order_id).all()
    subtotal = sum(item.total_price for item in order_items) if order_items else Decimal(0)
    tax_amount = subtotal * TAX_RATE
    
    total = subtotal + tax_amount + Decimal(str(request.tip_amount))
    
    # 3. Create Bill (L-06: use 12-char hex for collision resistance)
    bill = models.Bill(
        bill_id=f"BILL-{uuid4().hex[:12].upper()}",
        order_id=order.order_id,
        table_id=order.table_id,
        subtotal=subtotal,
        tax_amount=tax_amount,
        discount_amount=Decimal(0),
        total_amount=total,
        tip_amount=Decimal(str(request.tip_amount)),
        payment_mode=request.payment_mode,
        cash_amount=Decimal(str(request.cash_amount)),
        upi_amount=Decimal(str(request.upi_amount)),
        card_amount=Decimal(str(request.card_amount)),
        payment_status="completed",
        billed_by=current_user["user_id"],
        branch_id=b_id,
        bill_date=datetime.now().date(),
        bill_time=datetime.now().time(),
        created_at=datetime.now()
    )
    db.add(bill)
    
    # 4. Update Order
    order.status = "completed"
    order.updated_at = datetime.now()
    
    # 5. Update Table (only for dine_in)
    if table_id != "TAKEAWAY":
        table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
        if table:
            table.status = "available"
            
    # 6. Deduct Inventory Stock (H-01: with row locking + floor check; L-02: no float roundtrip)
    for item in order_items:
        recipes = db.query(models.RecipeIngredient).filter(models.RecipeIngredient.menu_item_id == item.menu_item_id).all()
        for recipe in recipes:
            stock = db.query(models.InventoryStock).filter(
                models.InventoryStock.grocery_item_id == recipe.grocery_item_id
            ).with_for_update().first()
            if stock:
                total_required = recipe.quantity_required * item.quantity
                if stock.current_stock >= total_required:
                    stock.current_stock -= total_required
                else:
                    stock.current_stock = Decimal(0)  # Floor at zero instead of going negative
            
    db.commit()

    # 7. Auto-print Bill Receipt if requested
    print_message = None
    if request.auto_print:
        try:
            from services.thermal_printer import generate_bill_receipt_bytes, send_raw_to_printer
            branch = db.query(models.Branch).filter(models.Branch.branch_id == b_id).first()
            cashier = db.query(models.User).filter(models.User.user_id == current_user["user_id"]).first()

            items_data = []
            for oi in order_items:
                m_item = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == oi.menu_item_id).first()
                items_data.append({
                    "name": m_item.name if m_item else f"Item #{oi.menu_item_id}",
                    "quantity": oi.quantity,
                    "price": float(oi.unit_price),
                    "total_price": float(oi.total_price),
                })

            receipt_bytes = generate_bill_receipt_bytes(
                restaurant_name="Flavors Ledger",
                branch_name=branch.name if branch else "",
                branch_phone=branch.phone if branch else "",
                bill_id=bill.bill_id,
                table_id=table_id,
                order_type="takeaway" if table_id == "TAKEAWAY" else "dine_in",
                cashier_name=cashier.username if cashier else "Staff",
                date_str=str(bill.bill_date),
                time_str=bill.bill_time.strftime("%I:%M %p") if bill.bill_time else "",
                items=items_data,
                subtotal=float(subtotal),
                tax_amount=float(tax_amount),
                discount_amount=0.0,
                tip_amount=float(request.tip_amount),
                grand_total=float(total),
                payment_mode=request.payment_mode,
            )
            success, msg = send_raw_to_printer(receipt_bytes)
            print_message = msg if success else f"Print warning: {msg}"
        except Exception as pe:
            print_message = f"Printer error: {str(pe)}"

    return {"status": "success", "bill_id": bill.bill_id, "print_status": print_message}


@router.post("/bills/{bill_id}/print")
def print_bill(bill_id: str, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    """Reprint an existing bill receipt on the Retsol thermal printer."""
    bill = db.query(models.Bill).filter(models.Bill.bill_id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    order = db.query(models.Order).filter(models.Order.order_id == bill.order_id).first()
    items_data = []
    if order:
        order_items = db.query(models.OrderItem).filter(models.OrderItem.order_id == order.order_id).all()
        for oi in order_items:
            m_item = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == oi.menu_item_id).first()
            items_data.append({
                "name": m_item.name if m_item else f"Item #{oi.menu_item_id}",
                "quantity": oi.quantity,
                "price": float(oi.unit_price),
                "total_price": float(oi.total_price),
            })

    branch = db.query(models.Branch).filter(models.Branch.branch_id == bill.branch_id).first()
    cashier = db.query(models.User).filter(models.User.user_id == bill.billed_by).first()

    from services.thermal_printer import generate_bill_receipt_bytes, send_raw_to_printer
    receipt_bytes = generate_bill_receipt_bytes(
        restaurant_name="Flavors Ledger",
        branch_name=branch.name if branch else "",
        branch_phone=branch.phone if branch else "",
        bill_id=bill.bill_id,
        table_id=bill.table_id,
        order_type="takeaway" if bill.table_id == "TAKEAWAY" else "dine_in",
        cashier_name=cashier.username if cashier else "Staff",
        date_str=str(bill.bill_date or datetime.now().date()),
        time_str=bill.bill_time.strftime("%I:%M %p") if bill.bill_time else datetime.now().strftime("%I:%M %p"),
        items=items_data,
        subtotal=float(bill.subtotal),
        tax_amount=float(bill.tax_amount),
        discount_amount=float(bill.discount_amount or 0),
        tip_amount=float(bill.tip_amount or 0),
        grand_total=float(bill.total_amount),
        payment_mode=bill.payment_mode or "CASH",
    )

    success, msg = send_raw_to_printer(receipt_bytes)
    return {"status": "success" if success else "error", "message": msg, "printed": success}


@router.post("/printer/test")
def test_printer(current_user: dict = Depends(security.get_current_user_token)):
    """Send a test slip to the Retsol thermal printer."""
    from services.thermal_printer import (
        INIT, ALIGN_CENTER, ALIGN_LEFT, BOLD_ON, BOLD_OFF,
        DOUBLE_SIZE_ON, NORMAL_SIZE, CUT_PAPER, LINE_FEED,
        PAPER_WIDTH_CHARS, _format_two_column, send_raw_to_printer
    )

    buf = bytearray()
    buf += INIT
    buf += ALIGN_CENTER + BOLD_ON + DOUBLE_SIZE_ON
    buf += b"FLAVORS LEDGER\n"
    buf += NORMAL_SIZE + BOLD_OFF
    buf += b"Retsol RTP-82 Thermal Printer\n"
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED
    buf += ALIGN_LEFT
    buf += _format_two_column("Status:", "CONNECTED & READY").encode("utf-8")
    buf += _format_two_column("Port:", "USB001 (Retsol_POS_80)").encode("utf-8")
    buf += _format_two_column("Paper Width:", "80mm (48 Columns)").encode("utf-8")
    buf += _format_two_column("Test Time:", datetime.now().strftime("%Y-%m-%d %I:%M %p")).encode("utf-8")
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED
    buf += ALIGN_CENTER
    buf += b"Printer Ready for Bills & KOTs!\n"
    buf += LINE_FEED * 4
    buf += CUT_PAPER

    success, msg = send_raw_to_printer(bytes(buf))
    return {"status": "success" if success else "error", "message": msg, "printed": success}

