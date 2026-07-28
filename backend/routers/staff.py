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

    emp_data = emp.model_dump(exclude_unset=True)
    if 'join_date' not in emp_data or not emp_data['join_date']:
        from datetime import datetime
        emp_data['join_date'] = datetime.now().date()
    if 'branch_id' not in emp_data or not emp_data['branch_id']:
        emp_data['branch_id'] = b_id

    db_emp = models.Employee(**emp_data)
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
    from datetime import datetime
    b_id = token_data.get("branch_id") or 1
    db_emps = []
    today = datetime.now().date()
    for emp in emps:
        if not db.query(models.Employee).filter(models.Employee.employee_id == emp.employee_id).first():
            emp_data = emp.model_dump(exclude_unset=True)
            if 'join_date' not in emp_data or not emp_data['join_date']:
                emp_data['join_date'] = today
            if 'branch_id' not in emp_data or not emp_data['branch_id']:
                emp_data['branch_id'] = b_id
            db_emps.append(models.Employee(**emp_data))
    
    db.add_all(db_emps)
    db.commit()
    for db_emp in db_emps:
        db.refresh(db_emp)
    return db_emps
@router.put("/{employee_id}", response_model=schemas.EmployeeResponse)
def update_employee(
    employee_id: str,
    emp: schemas.EmployeeCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    db_emp = db.query(models.Employee).filter(
        models.Employee.employee_id == employee_id,
        models.Employee.branch_id == b_id
    ).first()
    if not db_emp:
        raise HTTPException(status_code=404, detail="Employee not found")

    for key, value in emp.model_dump().items():
        setattr(db_emp, key, value)
    
    db.commit()
    db.refresh(db_emp)
    return db_emp

@router.delete("/{employee_id}")
def delete_employee(
    employee_id: str,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    db_emp = db.query(models.Employee).filter(
        models.Employee.employee_id == employee_id,
        models.Employee.branch_id == b_id
    ).first()
    if not db_emp:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    db_emp.is_active = False
    db.commit()
    return {"message": "Employee deactivated successfully"}

@router.get("/salary/all", response_model=List[schemas.SalaryPaymentResponse])
def get_salary_payments(
    month: Optional[int] = None,
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    b_id = token_data.get("branch_id") or 1
    query = db.query(models.SalaryPayment).filter(models.SalaryPayment.branch_id == b_id)
    if month:
        query = query.filter(models.SalaryPayment.payment_month == month)
    if year:
        query = query.filter(models.SalaryPayment.payment_year == year)
    return query.all()

@router.post("/salary", response_model=schemas.SalaryPaymentResponse)
def process_salary_payment(
    payment: schemas.SalaryPaymentCreate,
    db: Session = Depends(get_db),
    token_data: dict = Depends(security.get_current_user_token)
):
    from datetime import datetime
    b_id = token_data.get("branch_id") or 1
    user_id = token_data.get("user_id") or 1

    # Get employee base salary
    emp = db.query(models.Employee).filter(
        models.Employee.employee_id == payment.employee_id,
        models.Employee.branch_id == b_id
    ).first()
    if not emp:
        raise HTTPException(status_code=404, detail="Employee not found")

    base_salary = emp.monthly_salary
    net_salary = base_salary + payment.bonus - payment.deductions

    # Check if already paid
    existing = db.query(models.SalaryPayment).filter(
        models.SalaryPayment.employee_id == payment.employee_id,
        models.SalaryPayment.payment_month == payment.payment_month,
        models.SalaryPayment.payment_year == payment.payment_year
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="Salary already processed for this month")

    db_payment = models.SalaryPayment(
        employee_id=payment.employee_id,
        payment_month=payment.payment_month,
        payment_year=payment.payment_year,
        base_salary=base_salary,
        bonus=payment.bonus,
        deductions=payment.deductions,
        net_salary=net_salary,
        payment_date=datetime.now().date(),
        payment_status="Paid",
        payment_mode=payment.payment_mode,
        processed_by=user_id,
        branch_id=b_id
    )
    db.add(db_payment)
    db.commit()
    db.refresh(db_payment)
    return db_payment
