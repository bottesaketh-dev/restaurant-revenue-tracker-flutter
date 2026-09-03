from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/menu", tags=["menu"])

@router.get("/items", response_model=List[schemas.MenuItemResponse])
def get_menu_items(
    branch_id: Optional[int] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    user_role = token_data.get("role")
    user_branch_id = token_data.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        branch_id = user_branch_id
    b_id = branch_id
    query = db.query(models.MenuItem)
    if b_id:
        query = query.filter(models.MenuItem.branch_id == b_id)
        
    if category:
        query = query.filter(models.MenuItem.category == category)
        
    return query.order_by(models.MenuItem.menu_item_id).all()

@router.post("/items", response_model=schemas.MenuItemResponse)
def create_menu_item(
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id")
    if b_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required to create a menu item")
    db_item = models.MenuItem(**item.model_dump(), branch_id=b_id)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@router.post("/bulk", response_model=List[schemas.MenuItemResponse])
def bulk_create_menu_items(
    items: List[schemas.MenuItemCreate],
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id")
    if b_id is None:
        raise HTTPException(status_code=400, detail="branch_id is required to bulk create menu items")
    db_items = [models.MenuItem(**item.model_dump(), branch_id=b_id) for item in items]
    db.add_all(db_items)
    db.commit()
    for db_item in db_items:
        db.refresh(db_item)
    return db_items

@router.get("/categories", response_model=List[str])
def get_categories(
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    user_role = token_data.get("role")
    user_branch_id = token_data.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        branch_id = user_branch_id
    b_id = branch_id
    query = db.query(models.MenuItem.category).distinct()
    if b_id:
        query = query.filter(models.MenuItem.branch_id == b_id)
        
    categories = [cat[0] for cat in query.all() if cat[0]]
    return categories

@router.put("/items/{item_id}", response_model=schemas.MenuItemResponse)
def update_menu_item(
    item_id: int,
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id")
    query = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == item_id)
    if b_id:
        query = query.filter(models.MenuItem.branch_id == b_id)
        
    db_item = query.first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    for key, value in item.model_dump().items():
        setattr(db_item, key, value)
        
    db.commit()
    db.refresh(db_item)
    return db_item

@router.delete("/items/{item_id}")
def delete_menu_item(
    item_id: int,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id")
    query = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == item_id)
    if b_id:
        query = query.filter(models.MenuItem.branch_id == b_id)
        
    db_item = query.first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    db.delete(db_item)
    db.commit()
    return {"status": "deleted"}
