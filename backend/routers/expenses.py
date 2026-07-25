from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/expenses", tags=["expenses"])

@router.get("/", response_model=List[schemas.ExpenseResponse])
def get_expenses(
    branch_id: Optional[int] = None,
    category_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = branch_id or token_data.get("branch_id")
    
    query = db.query(models.Expense)
    if b_id:
        query = query.filter(models.Expense.branch_id == b_id)
        
    if category_id:
        query = query.filter(models.Expense.category_id == category_id)
        
    return query.order_by(models.Expense.expense_date.desc()).all()

@router.post("/", response_model=schemas.ExpenseResponse)
def create_expense(
    expense: schemas.ExpenseCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    u_id = int(token_data.get("sub"))
    
    db_expense = models.Expense(**expense.model_dump(), branch_id=b_id, recorded_by=u_id)
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
    
    db_expenses = [models.Expense(**exp.model_dump(), branch_id=b_id, recorded_by=u_id) for exp in expenses]
    db.add_all(db_expenses)
    db.commit()
    for db_exp in db_expenses:
        db.refresh(db_exp)
    return db_expenses
