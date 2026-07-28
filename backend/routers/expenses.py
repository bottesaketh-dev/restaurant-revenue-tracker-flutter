from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security
from datetime import datetime

router = APIRouter(prefix="/api/v1/expenses", tags=["expenses"])

@router.get("/", response_model=List[schemas.ExpenseResponse])
def get_expenses(
    branch_id: Optional[int] = None,
    category_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = branch_id or token_data.get("branch_id")
    
    query = db.query(models.Expense)
    if b_id:
        query = query.filter(models.Expense.branch_id == b_id)
        
    if category_id:
        query = query.filter(models.Expense.category_id == category_id)

    if start_date:
        query = query.filter(models.Expense.expense_date >= start_date)
    
    if end_date:
        query = query.filter(models.Expense.expense_date <= end_date)
        
    return query.order_by(models.Expense.expense_date.desc()).all()

def _resolve_category(db: Session, category_id: Optional[int], new_category_name: Optional[str]) -> int:
    if new_category_name:
        existing = db.query(models.ExpenseCategory).filter(models.ExpenseCategory.name.ilike(new_category_name)).first()
        if existing:
            return existing.expense_category_id
        new_cat = models.ExpenseCategory(name=new_category_name, description="Created from expense entry", is_active=True)
        db.add(new_cat)
        db.commit()
        db.refresh(new_cat)
        return new_cat.expense_category_id
    elif category_id:
        return category_id
    return 1

@router.post("/", response_model=schemas.ExpenseResponse)
def create_expense(
    expense: schemas.ExpenseCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    u_id = int(token_data.get("sub"))
    
    cat_id = _resolve_category(db, expense.category_id, expense.new_category_name)
    exp_dict = expense.model_dump(exclude={"new_category_name"})
    exp_dict["category_id"] = cat_id
    
    from datetime import datetime
    exp_dict["expense_time"] = datetime.now().time()
    
    db_expense = models.Expense(**exp_dict, branch_id=b_id, recorded_by=u_id)
    db.add(db_expense)
    db.commit()
    db.refresh(db_expense)
    return db_expense

@router.post("/bulk", response_model=List[schemas.ExpenseResponse])
def bulk_create_expenses(
    expenses: List[schemas.ExpenseCreate],
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    u_id = int(token_data.get("sub"))
    
    from datetime import datetime
    current_time = datetime.now().time()
    db_expenses = []
    for exp in expenses:
        cat_id = _resolve_category(db, exp.category_id, exp.new_category_name)
        exp_dict = exp.model_dump(exclude={"new_category_name"})
        exp_dict["category_id"] = cat_id
        exp_dict["expense_time"] = current_time
        db_expenses.append(models.Expense(**exp_dict, branch_id=b_id, recorded_by=u_id))
        
    db.add_all(db_expenses)
    db.commit()
    for db_exp in db_expenses:
        db.refresh(db_exp)
    return db_expenses

@router.get("/categories", response_model=List[schemas.ExpenseCategoryResponse])
def get_expense_categories(db: Session = Depends(get_db)):
    return db.query(models.ExpenseCategory).all()

@router.post("/categories", response_model=schemas.ExpenseCategoryResponse)
def create_expense_category(
    category: schemas.ExpenseCategoryCreate,
    db: Session = Depends(get_db)
):
    db_category = models.ExpenseCategory(**category.model_dump())
    db.add(db_category)
    db.commit()
    db.refresh(db_category)
    return db_category

@router.put("/{expense_id}", response_model=schemas.ExpenseResponse)
def update_expense(
    expense_id: int,
    expense: schemas.ExpenseCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    db_expense = db.query(models.Expense).filter(models.Expense.expense_id == expense_id, models.Expense.branch_id == b_id).first()
    
    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")
        
    cat_id = _resolve_category(db, expense.category_id, expense.new_category_name)
    exp_dict = expense.model_dump(exclude={"new_category_name"})
    exp_dict["category_id"] = cat_id
    
    for key, value in exp_dict.items():
        setattr(db_expense, key, value)
        
    db.commit()
    db.refresh(db_expense)
    return db_expense

@router.delete("/{expense_id}")
def delete_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    db_expense = db.query(models.Expense).filter(models.Expense.expense_id == expense_id, models.Expense.branch_id == b_id).first()
    
    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")
        
    db.delete(db_expense)
    db.commit()
    return {"message": "Expense deleted successfully"}
