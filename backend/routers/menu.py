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
    b_id = branch_id or token_data.get("branch_id")
    
    query = db.query(models.MenuItem)
    if b_id:
        query = query.filter(models.MenuItem.branch_id == b_id)
        
    if category:
        query = query.filter(models.MenuItem.category == category)
        
    return query.all()

@router.post("/items", response_model=schemas.MenuItemResponse)
def create_menu_item(
    item: schemas.MenuItemCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1 # Default to branch 1 for owner
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
    b_id = token_data.get("branch_id") or 1
    db_items = [models.MenuItem(**item.model_dump(), branch_id=b_id) for item in items]
    db.add_all(db_items)
    db.commit()
    for db_item in db_items:
        db.refresh(db_item)
    return db_items
