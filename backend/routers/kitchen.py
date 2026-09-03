from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, security
from typing import List
from datetime import datetime

router = APIRouter(prefix="/api/v1/kitchen", tags=["kitchen"])

@router.get("/inventory", response_model=List[schemas.InventoryStockResponse])
def get_inventory(db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    # InventoryStock is global across branches
    return db.query(models.InventoryStock).all()

@router.get("/recipes/{menu_item_id}", response_model=List[schemas.RecipeIngredientResponse])
def get_recipe(menu_item_id: int, db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    return db.query(models.RecipeIngredient).filter(models.RecipeIngredient.menu_item_id == menu_item_id).all()

@router.post("/recipes/{menu_item_id}")
def update_recipe(menu_item_id: int, ingredients: List[schemas.RecipeIngredientCreate], db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        branch_id = user_branch_id
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
