from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/employees", tags=["employees"])

@router.get("/", response_model=List[schemas.EmployeeResponse])
def get_employees(
    branch_id: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = branch_id or token_data.get("branch_id") or 1
    return db.query(models.Employee).filter(models.Employee.branch_id == b_id).all()

@router.post("/", response_model=schemas.EmployeeResponse)
def create_employee(
    emp: schemas.EmployeeCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    
    # Check if exists
    exists = db.query(models.Employee).filter(models.Employee.employee_id == emp.employee_id).first()
    if exists:
        raise HTTPException(status_code=400, detail="Employee ID already exists")

    db_emp = models.Employee(**emp.model_dump(), branch_id=b_id)
    db.add(db_emp)
    db.commit()
    db.refresh(db_emp)
    return db_emp

@router.post("/bulk", response_model=List[schemas.EmployeeResponse])
def bulk_create_employees(
    emps: List[schemas.EmployeeCreate],
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    db_emps = []
    for emp in emps:
        if not db.query(models.Employee).filter(models.Employee.employee_id == emp.employee_id).first():
            db_emps.append(models.Employee(**emp.model_dump(), branch_id=b_id))
    
    db.add_all(db_emps)
    db.commit()
    for db_emp in db_emps:
        db.refresh(db_emp)
    return db_emps
