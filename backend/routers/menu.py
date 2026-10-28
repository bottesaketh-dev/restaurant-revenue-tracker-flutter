from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/menu", tags=["menu"])

@router.get("/items", response_model=List[schemas.MenuItemResponse])
def get_menu_items(
    branch_id: Optional[int] = None,
    category: Optional[str] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data, restaurant_id)
    user_role = (token_data.get("role") or "").upper()
    user_branch_id = token_data.get("branch_id")
    
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        branch_id = user_branch_id
        
    query = db.query(models.MenuItem)
    if eff_r_id is not None:
        query = query.filter(models.MenuItem.restaurant_id == eff_r_id)
        
    if branch_id:
        query = query.filter(models.MenuItem.branch_id == branch_id)
        
    if category:
        query = query.filter(models.MenuItem.category == category)
        
    return query.order_by(models.MenuItem.menu_item_id).all()

@router.post("/items", response_model=schemas.MenuItemResponse, status_code=status.HTTP_201_CREATED)
def create_menu_item(
    item: schemas.MenuItemCreate,
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data)
    target_branch_id = item.branch_id or branch_id or token_data.get("branch_id")
    
    if target_branch_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required to create a branch-exclusive menu item")
        
    # Verify branch belongs to caller's restaurant
    branch = db.query(models.Branch).filter(models.Branch.branch_id == target_branch_id).first()
    if not branch:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Branch not found.")
    if eff_r_id is not None and branch.restaurant_id != eff_r_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Branch belongs to another restaurant organization.")

    item_data = item.model_dump(exclude={"branch_id"})
    db_item = models.MenuItem(
        **item_data,
        restaurant_id=eff_r_id,
        branch_id=target_branch_id
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@router.post("/bulk", response_model=List[schemas.MenuItemResponse])
def bulk_create_menu_items(
    items: List[schemas.MenuItemCreate],
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data)
    target_branch_id = branch_id or token_data.get("branch_id")
    
    if target_branch_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required to bulk create menu items")
        
    branch = db.query(models.Branch).filter(models.Branch.branch_id == target_branch_id).first()
    if not branch:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Branch not found.")
    if eff_r_id is not None and branch.restaurant_id != eff_r_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Branch belongs to another restaurant organization.")

    db_items = []
    for item in items:
        item_data = item.model_dump(exclude={"branch_id"})
        db_items.append(models.MenuItem(
            **item_data,
            restaurant_id=eff_r_id,
            branch_id=target_branch_id
        ))
        
    db.add_all(db_items)
    db.commit()
    for db_item in db_items:
        db.refresh(db_item)
    return db_items

@router.get("/categories", response_model=List[str])
def get_categories(
    branch_id: Optional[int] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data, restaurant_id)
    user_role = (token_data.get("role") or "").upper()
    user_branch_id = token_data.get("branch_id")
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        branch_id = user_branch_id

    query = db.query(models.MenuItem.category).distinct()
    if eff_r_id is not None:
        query = query.filter(models.MenuItem.restaurant_id == eff_r_id)
    if branch_id:
        query = query.filter(models.MenuItem.branch_id == branch_id)
        
    categories = [cat[0] for cat in query.all() if cat[0]]
    return sorted(categories)

@router.put("/items/{item_id}", response_model=schemas.MenuItemResponse)
def update_menu_item(
    item_id: int,
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data)
    query = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == item_id)
    if eff_r_id is not None:
        query = query.filter(models.MenuItem.restaurant_id == eff_r_id)
        
    user_branch_id = token_data.get("branch_id")
    user_role = (token_data.get("role") or "").upper()
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        query = query.filter(models.MenuItem.branch_id == user_branch_id)
        
    db_item = query.first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    update_data = item.model_dump(exclude_unset=True)
    if "branch_id" in update_data and update_data["branch_id"] is None:
        update_data.pop("branch_id") # Preserve existing branch_id
        
    for key, value in update_data.items():
        setattr(db_item, key, value)
        
    db.commit()
    db.refresh(db_item)
    return db_item

@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_menu_item(
    item_id: int,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data)
    query = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == item_id)
    if eff_r_id is not None:
        query = query.filter(models.MenuItem.restaurant_id == eff_r_id)
        
    db_item = query.first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    db.delete(db_item)
    db.commit()
