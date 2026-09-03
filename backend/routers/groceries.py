from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert as pg_insert
from database import get_db
import models, schemas, security
from typing import List, Optional
from datetime import datetime, date
import uuid
from decimal import Decimal

router = APIRouter(prefix="/api/v1/groceries", tags=["groceries"])

def _resolve_branch(current_user: dict, branch_id: Optional[int] = None, require_branch: bool = False) -> Optional[int]:
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        return user_branch_id
    b_id = branch_id or user_branch_id
    if require_branch and b_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required for this operation")
    return b_id

def _upsert_inventory_stock(db: Session, grocery_item_id: str, quantity: Decimal):
    """H-02: Upsert inventory stock to prevent duplicate key errors on concurrent inserts."""
    stmt = pg_insert(models.InventoryStock).values(
        grocery_item_id=grocery_item_id,
        current_stock=quantity
    ).on_conflict_do_update(
        index_elements=['grocery_item_id'],
        set_={'current_stock': models.InventoryStock.current_stock + quantity,
              'last_updated': datetime.now()}
    )
    db.execute(stmt)

# --- Categories ---

@router.get("/categories", response_model=List[schemas.GroceryCategoryResponse])
def get_categories(db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    return db.query(models.GroceryCategory).filter(models.GroceryCategory.is_active == True).all()

@router.post("/categories", response_model=schemas.GroceryCategoryResponse)
def create_category(category: schemas.GroceryCategoryCreate, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_cat = models.GroceryCategory(
        name=category.name,
        description=category.description,
        is_active=True
    )
    db.add(db_cat)
    db.commit()
    db.refresh(db_cat)
    return db_cat

# --- Items ---

@router.get("/items", response_model=List[schemas.GroceryItemResponse])
def get_items(category_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    query = db.query(models.GroceryItem).filter(models.GroceryItem.is_active == True)
    if category_id:
        query = query.filter(models.GroceryItem.category_id == category_id)
    return query.all()

@router.post("/items", response_model=schemas.GroceryItemResponse)
def create_item(item: schemas.GroceryItemCreate, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_item = models.GroceryItem(
        grocery_item_id=uuid.uuid4().hex,
        product_name=item.product_name,
        category_id=item.category_id,
        unit=item.unit,
        is_active=True,
        created_at=datetime.now()
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

# --- Purchases ---

@router.get("/purchases")
def get_purchases(
    branch_id: Optional[int] = None, 
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    category_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)  # H-05: Added auth
):
    b_id = _resolve_branch(current_user, branch_id)
    query = db.query(
        models.GroceryPurchase,
        models.GroceryItem.product_name,
        models.GroceryItem.unit
    ).join(
        models.GroceryItem,
        models.GroceryPurchase.grocery_item_id == models.GroceryItem.grocery_item_id
    )
    if b_id:
        query = query.filter(models.GroceryPurchase.branch_id == b_id)
        
    if start_date:
        query = query.filter(models.GroceryPurchase.purchase_date >= start_date)
    if end_date:
        query = query.filter(models.GroceryPurchase.purchase_date <= end_date)
        
    if category_id:
        query = query.filter(models.GroceryItem.category_id == category_id)
        
    purchases = query.order_by(models.GroceryPurchase.purchase_date.desc()).all()

    result = []
    for p, name, unit in purchases:
        result.append({
            "grocery_purchase_id": p.grocery_purchase_id,
            "purchase_date": p.purchase_date,
            "grocery_item_id": p.grocery_item_id,
            "product_name": name,
            "quantity": p.quantity,
            "unit_price": p.unit_price,
            "unit": unit,
            "total_price": p.total_price,
            "vendor_name": p.vendor_name,
            "notes": p.notes,
        })
    return result

@router.post("/purchases")
def add_purchase(data: schemas.GroceryPurchaseCreate, branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id, require_branch=True)
    now = datetime.now()
    new_purchase = models.GroceryPurchase(
        purchase_date=data.purchase_date,
        purchase_time=now.time(),
        grocery_item_id=data.grocery_item_id,
        quantity=data.quantity,
        unit_price=data.unit_price,
        total_price=data.quantity * data.unit_price,
        vendor_name=data.vendor_name,
        notes=data.notes,
        recorded_by=current_user["user_id"],  # L-03: Use JWT user_id
        branch_id=b_id,                        # L-03: Use JWT branch
        created_at=now
    )
    db.add(new_purchase)
    
    # H-02: Upsert inventory stock
    _upsert_inventory_stock(db, data.grocery_item_id, data.quantity)
        
    db.commit()
    db.refresh(new_purchase)
    return new_purchase

@router.post("/purchases/bulk")
def add_purchase_bulk(purchases: List[schemas.GroceryPurchaseCreate], branch_id: Optional[int] = None, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    b_id = _resolve_branch(current_user, branch_id, require_branch=True)
    now = datetime.now()
    db_purchases = []
    
    for p in purchases:
        db_purchases.append(models.GroceryPurchase(
            purchase_date=p.purchase_date,
            purchase_time=now.time(),
            grocery_item_id=p.grocery_item_id,
            quantity=p.quantity,
            unit_price=p.unit_price,
            total_price=p.quantity * p.unit_price,
            vendor_name=p.vendor_name,
            notes=p.notes,
            recorded_by=current_user["user_id"],  # L-03: Use JWT user_id
            branch_id=b_id,                        # L-03: Use JWT branch
            created_at=now
        ))
        
        # H-02: Upsert inventory stock (prevents duplicate key errors)
        _upsert_inventory_stock(db, p.grocery_item_id, p.quantity)
            
    db.add_all(db_purchases)
    db.commit()
    return {"message": f"Successfully added {len(db_purchases)} groceries"}

@router.put("/purchases/{purchase_id}")
def update_purchase(purchase_id: int, data: schemas.GroceryPurchaseCreate, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_purchase = db.query(models.GroceryPurchase).filter(models.GroceryPurchase.grocery_purchase_id == purchase_id).first()
    if not db_purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")
    
    # L-05: Adjust inventory for quantity change
    old_quantity = db_purchase.quantity
    old_item_id = db_purchase.grocery_item_id
    new_quantity = data.quantity
    
    # Reverse old stock addition
    if old_item_id:
        old_stock = db.query(models.InventoryStock).filter(
            models.InventoryStock.grocery_item_id == old_item_id
        ).with_for_update().first()
        if old_stock:
            old_stock.current_stock = max(old_stock.current_stock - old_quantity, Decimal(0))
    
    # Apply new stock addition
    _upsert_inventory_stock(db, data.grocery_item_id, new_quantity)
        
    db_purchase.purchase_date = data.purchase_date
    db_purchase.grocery_item_id = data.grocery_item_id
    db_purchase.quantity = data.quantity
    db_purchase.unit_price = data.unit_price
    db_purchase.total_price = data.quantity * data.unit_price
    db_purchase.vendor_name = data.vendor_name
    db_purchase.notes = data.notes
    
    db.commit()
    db.refresh(db_purchase)
    return db_purchase

@router.delete("/purchases/{purchase_id}")
def delete_purchase(purchase_id: int, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    db_purchase = db.query(models.GroceryPurchase).filter(models.GroceryPurchase.grocery_purchase_id == purchase_id).first()
    if not db_purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")
    
    db.delete(db_purchase)
    db.commit()
    return {"message": "Purchase deleted"}
