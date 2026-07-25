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
