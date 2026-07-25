from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas
from typing import List, Optional
from pydantic import BaseModel

router = APIRouter(prefix="/api/v1/billing", tags=["billing"])

@router.get("/tables", response_model=List[schemas.TableResponse])
def get_tables(branch_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(models.RestaurantTable).filter(models.RestaurantTable.is_active == True)
    if branch_id:
        query = query.filter(models.RestaurantTable.branch_id == branch_id)
    return query.all()

@router.get("/tables/{table_id}/order", response_model=Optional[schemas.OrderResponse])
def get_active_order(table_id: str, db: Session = Depends(get_db)):
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
def submit_kot(table_id: str, request: KotRequest, db: Session = Depends(get_db)):
    from datetime import datetime
    from decimal import Decimal
    from uuid import uuid4
    
    # Find active order
    order = db.query(models.Order).filter(
        models.Order.table_id == table_id,
        models.Order.status == 'active'
    ).first()
    
    # Handle order cancellation when cart is completely empty
    if not request.items:
        if order:
            # Delete order items
            db.query(models.OrderItem).filter(models.OrderItem.order_id == order.order_id).delete()
            # Delete the order itself
            db.delete(order)
            
            # Revert table status to available if dine_in
            if request.order_type == "dine_in" and table_id != "TAKEAWAY":
                table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
                if table:
                    table.status = "available"
            
            db.commit()
        return {"status": "deleted"}
    
    if not order:
        # Create new order
        # Ensure TAKEAWAY table exists if order_type is takeaway
        if request.order_type == "takeaway":
            takeaway_table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == "TAKEAWAY").first()
            if not takeaway_table:
                takeaway_table = models.RestaurantTable(
                    table_id="TAKEAWAY",
                    capacity=0,
                    status="available",
                    branch_id=1,
                    is_active=False # Keep it hidden from the UI
                )
                db.add(takeaway_table)
                db.flush()

        order = models.Order(
            order_id=f"ORD-{uuid4().hex[:6].upper()}",
            table_id=table_id if request.order_type == "dine_in" else "TAKEAWAY",
            status="active",
            created_by=1,
            branch_id=1,
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
        db.add(order)
        db.flush()
    else:
        order.updated_at = datetime.now()
    
    # Sync items completely
    
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
        
    # Mark table as occupied for dine in regardless of new or existing order
    if request.order_type == "dine_in" and table_id != "TAKEAWAY":
        table = db.query(models.RestaurantTable).filter(models.RestaurantTable.table_id == table_id).first()
        if table:
            table.status = "occupied"
            
    db.commit()
    return {"status": "success", "order_id": order.order_id}


class CheckoutRequest(BaseModel):
    payment_mode: str
    tip_amount: float = 0.0
    cash_amount: float = 0.0
    upi_amount: float = 0.0
    card_amount: float = 0.0

@router.post("/tables/{table_id}/checkout")
def checkout(table_id: str, request: CheckoutRequest, db: Session = Depends(get_db)):
    from datetime import datetime
    from decimal import Decimal
    from uuid import uuid4
    
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
    tax_amount = subtotal * Decimal('0.05')  # Hardcoded 5% tax based on flutter app
    
    total = subtotal + tax_amount + Decimal(str(request.tip_amount))
    
    # 3. Create Bill
    bill = models.Bill(
        bill_id=f"BILL-{uuid4().hex[:6].upper()}",
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
        billed_by=1,
        branch_id=1,
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
            
    db.commit()
    return {"status": "success", "bill_id": bill.bill_id}
