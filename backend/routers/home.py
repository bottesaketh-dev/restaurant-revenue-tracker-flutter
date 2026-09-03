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

    split_q = db.query(
        func.sum(models.Bill.cash_amount),
        func.sum(models.Bill.upi_amount),
        func.sum(models.Bill.card_amount)
    ).filter(
        models.Bill.bill_date >= start_date,
        models.Bill.bill_date <= end_date
    )
    if branch_id:
        split_q = split_q.filter(models.Bill.branch_id == branch_id)
    cash_val, upi_val, card_val = split_q.first()

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
        models.SalaryPayment.payment_status.ilike('paid'),
        models.SalaryPayment.payment_date >= start_date,
        models.SalaryPayment.payment_date <= end_date
    )
    if branch_id:
        salaries_q = salaries_q.filter(models.SalaryPayment.branch_id == branch_id)
    salary_outflow = salaries_q.scalar() or Decimal('0.00')

    total_outflow = grocery_outflow + expense_outflow + salary_outflow
    return {
        "inflow": total_inflow,
        "cash_inflow": cash_val or Decimal('0.00'),
        "upi_inflow": upi_val or Decimal('0.00'),
        "card_inflow": card_val or Decimal('0.00'),
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
def get_dashboard_summary(
    branch_id: Optional[int] = None, 
    tables_start_date: Optional[date] = None,
    tables_end_date: Optional[date] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        branch_id = user_branch_id
    today = date.today()
    if not tables_start_date:
        tables_start_date = today
    if not tables_end_date:
        tables_end_date = today

    start_curr = tables_start_date
    end_curr = tables_end_date

    duration = (end_curr - start_curr).days + 1
    start_prior = start_curr - timedelta(days=duration)
    end_prior = end_curr - timedelta(days=duration)

    curr_summary = get_cashflow_summary(db, branch_id, start_curr, end_curr)
    prior_summary = get_cashflow_summary(db, branch_id, start_prior, end_prior)

    # Latest 10 bills (filtered by date)
    bills_q = db.query(models.Bill).filter(
        models.Bill.bill_date >= tables_start_date,
        models.Bill.bill_date <= tables_end_date
    ).order_by(models.Bill.created_at.desc())
    if branch_id:
        bills_q = bills_q.filter(models.Bill.branch_id == branch_id)
    recent_bills = bills_q.all()

    # Latest 10 general expenses
    expenses_q = db.query(models.Expense).filter(
        models.Expense.expense_date >= tables_start_date,
        models.Expense.expense_date <= tables_end_date
    ).order_by(models.Expense.expense_date.desc())
    if branch_id:
        expenses_q = expenses_q.filter(models.Expense.branch_id == branch_id)
    recent_expenses = expenses_q.all()

    # Latest 10 grocery expenses
    groceries_q = db.query(models.GroceryPurchase, models.GroceryItem).join(
        models.GroceryItem, models.GroceryPurchase.grocery_item_id == models.GroceryItem.grocery_item_id
    ).filter(
        models.GroceryPurchase.purchase_date >= tables_start_date,
        models.GroceryPurchase.purchase_date <= tables_end_date
    ).order_by(models.GroceryPurchase.created_at.desc())
    if branch_id:
        groceries_q = groceries_q.filter(models.GroceryPurchase.branch_id == branch_id)
    recent_groceries = groceries_q.all()

    bills_data = []
    
    # Fetch ordered items in a single query to avoid N+1 problem (M-06)
    order_ids = [b.order_id for b in recent_bills]
    items_by_order = {}
    if order_ids:
        bill_items = db.query(models.OrderItem, models.MenuItem).join(
            models.MenuItem, models.OrderItem.menu_item_id == models.MenuItem.menu_item_id
        ).filter(models.OrderItem.order_id.in_(order_ids)).all()
        
        for item, menu_item in bill_items:
            if item.order_id not in items_by_order:
                items_by_order[item.order_id] = []
            items_by_order[item.order_id].append({
                "name": menu_item.name,
                "quantity": item.quantity,
                "price": float(item.unit_price),
                "total": float(item.total_price)
            })

    for b in recent_bills:
        items_list = items_by_order.get(b.order_id, [])
        bills_data.append({
            "date": str(b.bill_date),
            "time": str(b.bill_time),
            "table_id": b.table_id,
            "bill_id": b.bill_id,
            "amount": float(b.total_amount),
            "status": b.payment_status,
            "payment_mode": b.payment_mode,
            "tip_amount": float(b.tip_amount or 0),
            "cash_amount": float(b.cash_amount or 0),
            "upi_amount": float(b.upi_amount or 0),
            "card_amount": float(b.card_amount or 0),
            "items": items_list
        })

    return {
        "inflow": float(curr_summary["inflow"]),
        "inflow_pct": calc_pct(curr_summary["inflow"], prior_summary["inflow"]),
        "cash_inflow": float(curr_summary["cash_inflow"]),
        "upi_inflow": float(curr_summary["upi_inflow"]),
        "card_inflow": float(curr_summary["card_inflow"]),
        "outflow": float(curr_summary["outflow"]),
        "outflow_pct": calc_pct(curr_summary["outflow"], prior_summary["outflow"]),
        "net": float(curr_summary["net"]),
        "net_pct": calc_pct(curr_summary["net"], prior_summary["net"]),
        "recent_bills": bills_data,
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
                "date": str(g.GroceryPurchase.purchase_date),
                "item_name": g.GroceryItem.product_name,
                "quantity": float(g.GroceryPurchase.quantity),
                "amount": float(g.GroceryPurchase.total_price)
            } for g in recent_groceries
        ]
    }
