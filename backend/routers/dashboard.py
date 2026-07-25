from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from database import get_db
import models, schemas, security
from datetime import datetime, date, timedelta
from decimal import Decimal
import calendar

from typing import Optional

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])

def get_cashflow_summary(db: Session, branch_id: Optional[int], start_date: date, end_date: date):
    # Inflow
    inflow_q = db.query(func.sum(models.Bill.total_amount)).filter(
        models.Bill.bill_date >= start_date,
        models.Bill.bill_date <= end_date
    )
    if branch_id:
        inflow_q = inflow_q.filter(models.Bill.branch_id == branch_id)
    total_inflow = inflow_q.scalar() or Decimal('0.00')

    # Outflow: Groceries
    groceries_q = db.query(func.sum(models.GroceryPurchase.total_price)).filter(
        models.GroceryPurchase.purchase_date >= start_date,
        models.GroceryPurchase.purchase_date <= end_date
    )
    if branch_id:
        groceries_q = groceries_q.filter(models.GroceryPurchase.branch_id == branch_id)
    grocery_outflow = groceries_q.scalar() or Decimal('0.00')

    # Outflow: Expenses
    expenses_q = db.query(func.sum(models.Expense.amount)).filter(
        models.Expense.expense_date >= start_date,
        models.Expense.expense_date <= end_date
    )
    if branch_id:
        expenses_q = expenses_q.filter(models.Expense.branch_id == branch_id)
    expense_outflow = expenses_q.scalar() or Decimal('0.00')

    # Outflow: Salaries
    salaries_q = db.query(func.sum(models.SalaryPayment.net_salary)).filter(
        models.SalaryPayment.payment_status == 'paid',
        models.SalaryPayment.payment_date >= start_date,
        models.SalaryPayment.payment_date <= end_date
    )
    if branch_id:
        salaries_q = salaries_q.filter(models.SalaryPayment.branch_id == branch_id)
    salary_outflow = salaries_q.scalar() or Decimal('0.00')

    total_outflow = grocery_outflow + expense_outflow + salary_outflow
    return {
        "inflow": total_inflow,
        "outflow": total_outflow,
        "net": total_inflow - total_outflow
    }

def calc_pct(curr, prior):
    curr_v = float(curr)
    prior_v = float(prior)
    if prior_v > 0:
        return round(((curr_v - prior_v) / prior_v) * 100, 1)
    elif curr_v > 0:
        return 100.0
    return 0.0

@router.get("/summary")
def get_dashboard_summary(branch_id: Optional[int] = None, db: Session = Depends(get_db)):
    today = date.today()
    # Today's stats
    start_curr = today
    end_curr = today

    # Yesterday's stats for percentage comparison
    start_prior = today - timedelta(days=1)
    end_prior = start_prior

    curr_summary = get_cashflow_summary(db, branch_id, start_curr, end_curr)
    prior_summary = get_cashflow_summary(db, branch_id, start_prior, end_prior)

    # Latest 10 bills
    bills_q = db.query(models.Bill).order_by(models.Bill.created_at.desc())
    if branch_id:
        bills_q = bills_q.filter(models.Bill.branch_id == branch_id)
    recent_bills = bills_q.limit(10).all()

    # Latest 10 general expenses
    expenses_q = db.query(models.Expense).order_by(models.Expense.expense_date.desc())
    if branch_id:
        expenses_q = expenses_q.filter(models.Expense.branch_id == branch_id)
    recent_expenses = expenses_q.limit(10).all()

    # Latest 10 grocery expenses
    groceries_q = db.query(models.GroceryPurchase).order_by(models.GroceryPurchase.created_at.desc())
    if branch_id:
        groceries_q = groceries_q.filter(models.GroceryPurchase.branch_id == branch_id)
    recent_groceries = groceries_q.limit(10).all()

    return {
        "inflow": float(curr_summary["inflow"]),
        "inflow_pct": calc_pct(curr_summary["inflow"], prior_summary["inflow"]),
        "outflow": float(curr_summary["outflow"]),
        "outflow_pct": calc_pct(curr_summary["outflow"], prior_summary["outflow"]),
        "net": float(curr_summary["net"]),
        "net_pct": calc_pct(curr_summary["net"], prior_summary["net"]),
        "recent_bills": [
            {
                "date": str(b.bill_date),
                "time": str(b.bill_time),
                "table_id": b.table_id,
                "bill_id": b.bill_id,
                "amount": float(b.total_amount),
                "status": b.payment_status
            } for b in recent_bills
        ],
        "recent_expenses": [
            {
                "date": str(e.expense_date),
                "description": e.description,
                "amount": float(e.amount),
                "payment_mode": e.payment_mode
            } for e in recent_expenses
        ],
        "recent_groceries": [
            {
                "date": str(g.purchase_date),
                "item_id": g.grocery_item_id,
                "quantity": float(g.quantity),
                "amount": float(g.total_price)
            } for g in recent_groceries
        ]
    }
