from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import models, schemas
from typing import List, Optional
from datetime import datetime

router = APIRouter(prefix="/api/v1/groceries", tags=["groceries"])

@router.get("/purchases")
def get_purchases(branch_id: Optional[int] = None, db: Session = Depends(get_db)):
    # Join GroceryPurchase with GroceryItem to get the product name
    query = db.query(
        models.GroceryPurchase,
        models.GroceryItem.product_name,
        models.GroceryItem.unit
    ).join(
        models.GroceryItem,
        models.GroceryPurchase.grocery_item_id == models.GroceryItem.grocery_item_id
    )
    if branch_id:
        query = query.filter(models.GroceryPurchase.branch_id == branch_id)
        
    purchases = query.order_by(models.GroceryPurchase.purchase_date.desc()).limit(50).all()

    result = []
    for p, name, unit in purchases:
        result.append({
            "grocery_purchase_id": p.grocery_purchase_id,
            "purchase_date": p.purchase_date,
            "product_name": name,
            "quantity": p.quantity,
            "unit": unit,
            "total_price": p.total_price,
            "vendor_name": p.vendor_name,
        })
    return result

@router.post("/purchases")
def add_purchase(data: schemas.GroceryPurchaseCreate, db: Session = Depends(get_db)):
    now = datetime.now()
    new_purchase = models.GroceryPurchase(
        purchase_date=now.date(),
        purchase_time=now.time(),
        grocery_item_id=data.grocery_item_id,
        quantity=data.quantity,
        unit_price=data.unit_price,
        total_price=data.quantity * data.unit_price,
        vendor_name=data.vendor_name,
        notes=data.notes,
        recorded_by=1, # Default user
        branch_id=1,   # Default branch
        created_at=now
    )
    db.add(new_purchase)
    db.commit()
    db.refresh(new_purchase)
    return new_purchase
