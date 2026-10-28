from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, security
from typing import List, Optional
from datetime import datetime

router = APIRouter(prefix="/api/v1/kitchen", tags=["kitchen"])

@router.get("/inventory", response_model=List[schemas.InventoryStockResponse])
def get_inventory(
    branch_id: Optional[int] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user, restaurant_id)
    user_role = (current_user.get("role") or "").upper()
    user_branch_id = current_user.get("branch_id")
    
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        branch_id = user_branch_id

    query = db.query(models.InventoryStock)
    if eff_r_id is not None:
        query = query.filter(models.InventoryStock.restaurant_id == eff_r_id)
    if branch_id:
        query = query.filter(models.InventoryStock.branch_id == branch_id)
        
    return query.all()

@router.get("/recipes/{menu_item_id}", response_model=List[schemas.RecipeIngredientResponse])
def get_recipe(
    menu_item_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user)
    
    # Verify that the menu item belongs to the caller's restaurant
    menu_item = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == menu_item_id)
    if eff_r_id is not None:
        menu_item = menu_item.filter(models.MenuItem.restaurant_id == eff_r_id)
    if not menu_item.first():
        raise HTTPException(status_code=404, detail="Menu item not found in your restaurant")

    return db.query(models.RecipeIngredient).filter(models.RecipeIngredient.menu_item_id == menu_item_id).all()

@router.post("/recipes/{menu_item_id}")
def update_recipe(
    menu_item_id: int,
    ingredients: List[schemas.RecipeIngredientCreate],
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user)
    
    # Ownership verification
    menu_query = db.query(models.MenuItem).filter(models.MenuItem.menu_item_id == menu_item_id)
    if eff_r_id is not None:
        menu_query = menu_query.filter(models.MenuItem.restaurant_id == eff_r_id)
    menu_item = menu_query.first()
    if not menu_item:
        raise HTTPException(status_code=404, detail="Menu item not found in your restaurant")
        
    # Delete existing recipe ingredients for this menu item
    db.query(models.RecipeIngredient).filter(models.RecipeIngredient.menu_item_id == menu_item_id).delete()
    
    # Add new ingredients
    db_ingredients = []
    now = datetime.now()
    for ing in ingredients:
        db_ingredients.append(models.RecipeIngredient(
            menu_item_id=menu_item_id,
            grocery_item_id=ing.grocery_item_id,
            quantity_required=ing.quantity_required,
            created_at=now
        ))
        
    if db_ingredients:
        db.add_all(db_ingredients)
        
    db.commit()
    return {"message": "Recipe updated successfully"}
