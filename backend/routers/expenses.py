from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security
from datetime import datetime

router = APIRouter(prefix="/api/v1/expenses", tags=["expenses"])

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

def _resolve_category(db: Session, category_id: Optional[int], new_category_name: Optional[str], restaurant_id: int) -> int:
    if new_category_name:
        existing = db.query(models.ExpenseCategory).filter(
            models.ExpenseCategory.name.ilike(new_category_name),
            models.ExpenseCategory.restaurant_id == restaurant_id
        ).first()
        if existing:
            return existing.expense_category_id
        new_cat = models.ExpenseCategory(
            restaurant_id=restaurant_id,
            name=new_category_name,
            description="Created from expense entry",
            is_active=True
        )
        db.add(new_cat)
        db.commit()
        db.refresh(new_cat)
        return new_cat.expense_category_id
        
    if category_id:
        existing = db.query(models.ExpenseCategory).filter(
            models.ExpenseCategory.expense_category_id == category_id,
            models.ExpenseCategory.restaurant_id == restaurant_id
        ).first()
        if existing:
            return existing.expense_category_id
            
    # Tenant-scoped fallback
    fallback = db.query(models.ExpenseCategory).filter(
        models.ExpenseCategory.restaurant_id == restaurant_id
    ).first()
    if fallback:
        return fallback.expense_category_id
        
    default_cat = models.ExpenseCategory(
        restaurant_id=restaurant_id,
        name="General Expenses",
        description="Default general category",
        is_active=True
    )
    db.add(default_cat)
    db.commit()
    db.refresh(default_cat)
    return default_cat.expense_category_id

@router.get("/", response_model=List[schemas.ExpenseResponse])
def get_expenses(
    branch_id: Optional[int] = None,
    category_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data, restaurant_id)
    b_id = _resolve_branch(token_data, db, branch_id)
    
    query = db.query(models.Expense)
    if eff_r_id is not None:
        query = query.filter(models.Expense.restaurant_id == eff_r_id)
    if b_id:
        query = query.filter(models.Expense.branch_id == b_id)
    if category_id:
        query = query.filter(models.Expense.category_id == category_id)
    if start_date:
        query = query.filter(models.Expense.expense_date >= start_date)
    if end_date:
        query = query.filter(models.Expense.expense_date <= end_date)
        
    return query.order_by(models.Expense.expense_date.desc()).all()

@router.post("/", response_model=schemas.ExpenseResponse)
def create_expense(
    expense: schemas.ExpenseCreate,
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id, eff_r_id = _resolve_branch_and_restaurant(token_data, db, expense.branch_id or branch_id, require_branch=True)
    u_id = token_data["user_id"]
    
    cat_id = _resolve_category(db, expense.category_id, expense.new_category_name, eff_r_id)
    exp_dict = expense.model_dump(exclude={"new_category_name", "branch_id", "restaurant_id"})
    exp_dict["category_id"] = cat_id
    exp_dict["expense_time"] = datetime.now().time()
    
    db_expense = models.Expense(
        **exp_dict,
        restaurant_id=eff_r_id,
        branch_id=b_id,
        recorded_by=u_id
    )
    db.add(db_expense)
    db.commit()
    db.refresh(db_expense)
    return db_expense

@router.post("/bulk", response_model=List[schemas.ExpenseResponse])
def bulk_create_expenses(
    expenses: List[schemas.ExpenseCreate],
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id, eff_r_id = _resolve_branch_and_restaurant(token_data, db, branch_id, require_branch=True)
    u_id = token_data["user_id"]
    
    current_time = datetime.now().time()
    db_expenses = []
    for exp in expenses:
        cat_id = _resolve_category(db, exp.category_id, exp.new_category_name, eff_r_id)
        exp_dict = exp.model_dump(exclude={"new_category_name", "branch_id", "restaurant_id"})
        exp_dict["category_id"] = cat_id
        exp_dict["expense_time"] = current_time
        db_expenses.append(models.Expense(
            **exp_dict,
            restaurant_id=eff_r_id,
            branch_id=b_id,
            recorded_by=u_id
        ))
        
    db.add_all(db_expenses)
    db.commit()
    for e in db_expenses:
        db.refresh(e)
    return db_expenses

@router.get("/categories", response_model=List[schemas.ExpenseCategoryResponse])
def get_categories(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data, restaurant_id)
    query = db.query(models.ExpenseCategory).filter(models.ExpenseCategory.is_active == True)
    if eff_r_id is not None:
        query = query.filter(models.ExpenseCategory.restaurant_id == eff_r_id)
    return query.all()

@router.post("/categories", response_model=schemas.ExpenseCategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    category: schemas.ExpenseCategoryCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(token_data, category.restaurant_id)
    new_cat = models.ExpenseCategory(
        restaurant_id=eff_r_id or 1,
        name=category.name,
        description=category.description,
        is_active=True
    )
    db.add(new_cat)
    db.commit()
    db.refresh(new_cat)
    return new_cat
