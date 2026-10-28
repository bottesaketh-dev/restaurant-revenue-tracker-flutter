from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, security
from typing import List, Optional
from datetime import datetime, date
import uuid
from decimal import Decimal

router = APIRouter(prefix="/api/v1/groceries", tags=["groceries"])

def _resolve_branch_and_restaurant(current_user: dict, db: Session, branch_id: Optional[int] = None, require_branch: bool = False):
    """Cleanly resolve the effective branch_id and restaurant_id from JWT claims, enforcing tenant isolation."""
    eff_r_id = security.get_effective_restaurant_id(current_user)
    user_role = (current_user.get("role") or "").upper()
    user_branch_id = current_user.get("branch_id")
    
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        if branch_id is not None and branch_id != user_branch_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Cannot access data from a different branch")
        b_id = user_branch_id
    else:
        b_id = branch_id or user_branch_id

    if require_branch and b_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required for this operation")

    if b_id is not None:
        branch = db.query(models.Branch).filter(models.Branch.branch_id == b_id).first()
        if not branch:
            raise HTTPException(status_code=404, detail="Branch not found")
        if eff_r_id is not None and branch.restaurant_id != eff_r_id:
            raise HTTPException(status_code=403, detail="Branch does not belong to your restaurant organization")
        if eff_r_id is None:
            eff_r_id = branch.restaurant_id

    return b_id, eff_r_id

def _resolve_branch(current_user: dict, db: Session, branch_id: Optional[int] = None, require_branch: bool = False) -> Optional[int]:
    b_id, _ = _resolve_branch_and_restaurant(current_user, db, branch_id, require_branch)
    return b_id

def _upsert_inventory_stock(db: Session, grocery_item_id: str, branch_id: int, restaurant_id: int, quantity: Decimal):
    """Upserts branch-specific inventory stock with database neutrality."""
    stock = db.query(models.InventoryStock).filter(
        models.InventoryStock.grocery_item_id == grocery_item_id,
        models.InventoryStock.branch_id == branch_id
    ).first()
    
    if stock:
        stock.current_stock += quantity
        stock.last_updated = datetime.now()
    else:
        new_stock = models.InventoryStock(
            grocery_item_id=grocery_item_id,
            branch_id=branch_id,
            restaurant_id=restaurant_id,
            current_stock=quantity,
            last_updated=datetime.now()
        )
        db.add(new_stock)

# --- Categories ---

@router.get("/categories", response_model=List[schemas.GroceryCategoryResponse])
def get_categories(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, restaurant_id)
    query = db.query(models.GroceryCategory).filter(models.GroceryCategory.is_active == True)
    if eff_r_id is not None:
        query = query.filter(models.GroceryCategory.restaurant_id == eff_r_id)
    return query.all()

@router.post("/categories", response_model=schemas.GroceryCategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    category: schemas.GroceryCategoryCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, category.restaurant_id)
    db_cat = models.GroceryCategory(
        restaurant_id=eff_r_id or 1,
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
def get_items(
    category_id: Optional[int] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, restaurant_id)
    query = db.query(models.GroceryItem).filter(models.GroceryItem.is_active == True)
    if eff_r_id is not None:
        query = query.filter(models.GroceryItem.restaurant_id == eff_r_id)
    if category_id:
        query = query.filter(models.GroceryItem.category_id == category_id)
    return query.all()

@router.post("/items", response_model=schemas.GroceryItemResponse, status_code=status.HTTP_201_CREATED)
def create_item(
    item: schemas.GroceryItemCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, item.restaurant_id)
    cat_id = item.category_id or item.grocery_category_id
    db_item = models.GroceryItem(
        grocery_item_id=uuid.uuid4().hex[:12].upper(),
        restaurant_id=eff_r_id or 1,
        product_name=item.product_name,
        category_id=cat_id,
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
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, restaurant_id)
    b_id = _resolve_branch(current_user, db, branch_id)
    
    query = db.query(
        models.GroceryPurchase,
        models.GroceryItem.product_name,
        models.GroceryItem.unit
    ).join(
        models.GroceryItem,
        models.GroceryPurchase.grocery_item_id == models.GroceryItem.grocery_item_id
    )
    
    if eff_r_id is not None:
        query = query.filter(models.GroceryPurchase.restaurant_id == eff_r_id)
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
            "branch_id": p.branch_id,
        })
    return result

@router.post("/purchases", status_code=status.HTTP_201_CREATED)
def add_purchase(
    data: schemas.GroceryPurchaseCreate,
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    b_id, eff_r_id = _resolve_branch_and_restaurant(current_user, db, data.branch_id or branch_id, require_branch=True)
    now = datetime.now()
    
    new_purchase = models.GroceryPurchase(
        restaurant_id=eff_r_id,
        branch_id=b_id,
        purchase_date=data.purchase_date or now.date(),
        purchase_time=now.time(),
        grocery_item_id=data.grocery_item_id,
        quantity=data.quantity,
        unit_price=data.unit_price,
        total_price=data.total_price or (data.quantity * data.unit_price),
        vendor_name=data.vendor_name,
        notes=data.notes,
        recorded_by=current_user["user_id"],
        created_at=now
    )
    db.add(new_purchase)
    
    # Upsert branch inventory stock
    _upsert_inventory_stock(db, data.grocery_item_id, b_id, eff_r_id, data.quantity)
        
    db.commit()
    db.refresh(new_purchase)
    return new_purchase

@router.post("/purchases/bulk")
def add_purchase_bulk(
    purchases: List[schemas.GroceryPurchaseCreate],
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    b_id, eff_r_id = _resolve_branch_and_restaurant(current_user, db, branch_id, require_branch=True)
    now = datetime.now()
    db_purchases = []
    
    for p in purchases:
        db_purchases.append(models.GroceryPurchase(
            restaurant_id=eff_r_id,
            branch_id=b_id,
            purchase_date=p.purchase_date or now.date(),
            purchase_time=now.time(),
            grocery_item_id=p.grocery_item_id,
            quantity=p.quantity,
            unit_price=p.unit_price,
            total_price=p.total_price or (p.quantity * p.unit_price),
            vendor_name=p.vendor_name,
            notes=p.notes,
            recorded_by=current_user["user_id"],
            created_at=now
        ))
        _upsert_inventory_stock(db, p.grocery_item_id, b_id, eff_r_id, p.quantity)
            
    db.add_all(db_purchases)
    db.commit()
    return {"message": f"Successfully added {len(db_purchases)} groceries"}

@router.delete("/purchases/{purchase_id}")
def delete_purchase(
    purchase_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user)
    query = db.query(models.GroceryPurchase).filter(models.GroceryPurchase.grocery_purchase_id == purchase_id)
    if eff_r_id is not None:
        query = query.filter(models.GroceryPurchase.restaurant_id == eff_r_id)
        
    db_purchase = query.first()
    if not db_purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")
    
    db.delete(db_purchase)
    db.commit()
    return {"message": "Purchase deleted"}

@router.get("/stock")
def get_grocery_stock(
    branch_id: Optional[int] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, restaurant_id)
    b_id = _resolve_branch(current_user, db, branch_id)
    
    query = db.query(
        models.InventoryStock,
        models.GroceryItem.product_name,
        models.GroceryItem.unit
    ).join(
        models.GroceryItem,
        models.InventoryStock.grocery_item_id == models.GroceryItem.grocery_item_id
    )
    if eff_r_id is not None:
        query = query.filter(models.InventoryStock.restaurant_id == eff_r_id)
    if b_id:
        query = query.filter(models.InventoryStock.branch_id == b_id)
        
    stocks = query.all()
    return [{
        "grocery_item_id": s.InventoryStock.grocery_item_id,
        "product_name": s.product_name,
        "unit": s.unit,
        "current_stock": float(s.InventoryStock.current_stock or 0),
        "branch_id": s.InventoryStock.branch_id,
        "restaurant_id": s.InventoryStock.restaurant_id
    } for s in stocks]
