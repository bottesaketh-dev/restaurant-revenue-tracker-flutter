from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from typing import Optional
from database import get_db
import models
from datetime import datetime, date, timedelta
from decimal import Decimal

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])

@router.get("/profit-loss")
def get_profit_loss(branch_id: Optional[int] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    today = date.today()
    year = today.year
    month = today.month

    revenue_q = db.query(func.sum(models.Bill.total_amount)).filter(
        extract('year', models.Bill.bill_date) == year,
        extract('month', models.Bill.bill_date) == month,
        models.Bill.branch_id == b_id
    )
    revenue = revenue_q.scalar() or Decimal('0.00')

    cogs_q = db.query(func.sum(models.GroceryPurchase.total_price)).filter(
        extract('year', models.GroceryPurchase.purchase_date) == year,
        extract('month', models.GroceryPurchase.purchase_date) == month,
        models.GroceryPurchase.branch_id == b_id
    )
    cogs = cogs_q.scalar() or Decimal('0.00')

    opex_exp_q = db.query(func.sum(models.Expense.amount)).filter(
        extract('year', models.Expense.expense_date) == year,
        extract('month', models.Expense.expense_date) == month,
        models.Expense.branch_id == b_id
    )
    opex_exp = opex_exp_q.scalar() or Decimal('0.00')

    opex_sal_q = db.query(func.sum(models.SalaryPayment.net_salary)).filter(
        models.SalaryPayment.payment_year == year,
        models.SalaryPayment.payment_month == month,
        models.SalaryPayment.payment_status == 'paid',
        models.SalaryPayment.branch_id == b_id
    )
    opex_sal = opex_sal_q.scalar() or Decimal('0.00')

    opex_total = opex_exp + opex_sal
    gross_profit = revenue - cogs
    net_profit = gross_profit - opex_total

    return {
        "revenue": float(revenue),
        "cogs": float(cogs),
        "opex_total": float(opex_total),
        "gross_profit": float(gross_profit),
        "net_profit": float(net_profit)
    }

@router.get("/sales-trends")
def get_sales_trends(branch_id: Optional[int] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    today = date.today()
    start_date = today - timedelta(days=30)
    
    sales_q = db.query(models.Bill.bill_date, func.sum(models.Bill.total_amount)).filter(
        models.Bill.branch_id == b_id,
        models.Bill.bill_date >= start_date,
        models.Bill.bill_date <= today
    ).group_by(models.Bill.bill_date).order_by(models.Bill.bill_date).all()
    
    result = []
    for d, amt in sales_q:
        result.append({
            "date": d.strftime("%Y-%m-%d"),
            "amount": float(amt)
        })
    return result
