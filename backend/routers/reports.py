from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, extract, desc
from typing import Optional
from database import get_db
import models
from datetime import datetime, date, timedelta
from decimal import Decimal
from fastapi.responses import StreamingResponse, Response
import io
import csv
from fpdf import FPDF

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])

def get_date_range(start_date: Optional[str], end_date: Optional[str]):
    today = date.today()
    if end_date:
        try:
            end_d = datetime.strptime(end_date, "%Y-%m-%d").date()
        except:
            end_d = today
    else:
        end_d = today
        
    if start_date:
        try:
            start_d = datetime.strptime(start_date, "%Y-%m-%d").date()
        except:
            start_d = end_d - timedelta(days=30)
    else:
        start_d = end_d - timedelta(days=30)
        
    return start_d, end_d

@router.get("/profit-loss")
def get_profit_loss(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    start_d, end_d = get_date_range(start_date, end_date)

    revenue_q = db.query(func.sum(models.Bill.total_amount)).filter(
        models.Bill.bill_date >= start_d,
        models.Bill.bill_date <= end_d,
        models.Bill.branch_id == b_id
    )
    revenue = revenue_q.scalar() or Decimal('0.00')

    cogs_q = db.query(func.sum(models.GroceryPurchase.total_price)).filter(
        models.GroceryPurchase.purchase_date >= start_d,
        models.GroceryPurchase.purchase_date <= end_d,
        models.GroceryPurchase.branch_id == b_id
    )
    cogs = cogs_q.scalar() or Decimal('0.00')

    opex_exp_q = db.query(func.sum(models.Expense.amount)).filter(
        models.Expense.expense_date >= start_d,
        models.Expense.expense_date <= end_d,
        models.Expense.branch_id == b_id
    )
    opex_exp = opex_exp_q.scalar() or Decimal('0.00')

    # Salary is stored by month/year. We will approximate by using the end_date's month/year
    opex_sal_q = db.query(func.sum(models.SalaryPayment.net_salary)).filter(
        models.SalaryPayment.payment_year == end_d.year,
        models.SalaryPayment.payment_month == end_d.month,
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
def get_sales_trends(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    start_d, end_d = get_date_range(start_date, end_date)
    
    query = db.query(
        models.Bill.bill_date,
        models.Branch.name,
        func.sum(models.Bill.total_amount)
    ).join(
        models.Branch, models.Bill.branch_id == models.Branch.branch_id
    ).filter(
        models.Bill.bill_date >= start_d,
        models.Bill.bill_date <= end_d
    )
    if branch_id:
        query = query.filter(models.Bill.branch_id == branch_id)
        
    sales_q = query.group_by(models.Bill.bill_date, models.Branch.name).all()
    
    result_map = {}
    for d, b_name, amt in sales_q:
        if d not in result_map:
            result_map[d] = {"amount": 0.0, "branches": {}}
        result_map[d]["amount"] += float(amt)
        result_map[d]["branches"][b_name] = float(amt)
        
    result = []
    current_date = start_d
    while current_date <= end_d:
        data = result_map.get(current_date, {"amount": 0.0, "branches": {}})
        result.append({
            "date": current_date.strftime("%Y-%m-%d"),
            "amount": data["amount"],
            "branches": data["branches"]
        })
        current_date += timedelta(days=1)
        
    return result


@router.get("/metrics-summary")
def get_metrics_summary(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    start_d, end_d = get_date_range(start_date, end_date)

    revenue_q = db.query(func.sum(models.Bill.total_amount)).filter(
        models.Bill.bill_date >= start_d,
        models.Bill.bill_date <= end_d,
        models.Bill.branch_id == b_id
    )
    revenue = revenue_q.scalar() or Decimal('0.00')

    cogs_q = db.query(func.sum(models.GroceryPurchase.total_price)).filter(
        models.GroceryPurchase.purchase_date >= start_d,
        models.GroceryPurchase.purchase_date <= end_d,
        models.GroceryPurchase.branch_id == b_id
    )
    cogs = cogs_q.scalar() or Decimal('0.00')

    opex_exp_q = db.query(func.sum(models.Expense.amount)).filter(
        models.Expense.expense_date >= start_d,
        models.Expense.expense_date <= end_d,
        models.Expense.branch_id == b_id
    )
    opex_exp = opex_exp_q.scalar() or Decimal('0.00')

    opex_sal_q = db.query(func.sum(models.SalaryPayment.net_salary)).filter(
        models.SalaryPayment.payment_year == end_d.year,
        models.SalaryPayment.payment_month == end_d.month,
        models.SalaryPayment.payment_status == 'paid',
        models.SalaryPayment.branch_id == b_id
    )
    opex_sal = opex_sal_q.scalar() or Decimal('0.00')

    opex_total = opex_exp + opex_sal
    net_profit = revenue - cogs - opex_total

    total_bills = db.query(func.count(models.Bill.bill_id)).filter(
        models.Bill.bill_date >= start_d,
        models.Bill.bill_date <= end_d,
        models.Bill.branch_id == b_id
    ).scalar() or 0

    avg_order_value = float(revenue) / total_bills if total_bills > 0 else 0.0

    return {
        "revenue": float(revenue),
        "expenses": float(cogs + opex_total),
        "net_profit": float(net_profit),
        "total_bills": total_bills,
        "avg_order_value": float(avg_order_value)
    }

@router.get("/category-revenue")
def get_category_revenue(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    start_d, end_d = get_date_range(start_date, end_date)
    
    q = db.query(
        models.MenuItem.category, 
        func.sum(models.OrderItem.total_price)
    ).join(
        models.OrderItem, models.MenuItem.menu_item_id == models.OrderItem.menu_item_id
    ).join(
        models.Order, models.OrderItem.order_id == models.Order.order_id
    ).filter(
        models.Order.branch_id == b_id,
        func.date(models.Order.created_at) >= start_d,
        func.date(models.Order.created_at) <= end_d
    ).group_by(models.MenuItem.category).all()
    
    return [{"category": c, "revenue": float(r or 0)} for c, r in q]

@router.get("/top-items")
def get_top_items(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    start_d, end_d = get_date_range(start_date, end_date)
    
    q = db.query(
        models.MenuItem.name, 
        func.sum(models.OrderItem.quantity).label("qty")
    ).join(
        models.OrderItem, models.MenuItem.menu_item_id == models.OrderItem.menu_item_id
    ).join(
        models.Order, models.OrderItem.order_id == models.Order.order_id
    ).filter(
        models.Order.branch_id == b_id,
        func.date(models.Order.created_at) >= start_d,
        func.date(models.Order.created_at) <= end_d
    ).group_by(models.MenuItem.name).order_by(desc("qty")).limit(5).all()
    
    return [{"name": n, "quantity": int(q or 0)} for n, q in q]

@router.get("/expense-breakdown")
def get_expense_breakdown(branch_id: Optional[int] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    b_id = branch_id or 1
    start_d, end_d = get_date_range(start_date, end_date)
    
    q = db.query(
        models.ExpenseCategory.name, 
        func.sum(models.Expense.amount)
    ).join(
        models.Expense, models.ExpenseCategory.expense_category_id == models.Expense.category_id
    ).filter(
        models.Expense.expense_date >= start_d,
        models.Expense.expense_date <= end_d,
        models.Expense.branch_id == b_id
    ).group_by(models.ExpenseCategory.name).all()
    
    return [{"category": c, "amount": float(a or 0)} for c, a in q]

@router.get("/branch-comparison")
def get_branch_comparison(start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    start_d, end_d = get_date_range(start_date, end_date)
    
    q = db.query(
        models.Branch.name, 
        func.sum(models.Bill.total_amount)
    ).join(
        models.Bill, models.Branch.branch_id == models.Bill.branch_id
    ).filter(
        models.Bill.bill_date >= start_d,
        models.Bill.bill_date <= end_d
    ).group_by(models.Branch.name).all()
    
    return [{"branch_name": name, "revenue": float(rev or 0)} for name, rev in q]

@router.get("/export")
def export_report(format: str = "csv", branch_id: Optional[int] = 0, start_date: Optional[str] = None, end_date: Optional[str] = None, db: Session = Depends(get_db)):
    summary = get_metrics_summary(branch_id, start_date, end_date, db)
    trends = get_sales_trends(branch_id, start_date, end_date, db)
    categories = get_category_revenue(branch_id, start_date, end_date, db)
    expenses = get_expense_breakdown(branch_id, start_date, end_date, db)

    if format == "pdf":
        pdf = FPDF()
        pdf.add_page()
        pdf.set_font("helvetica", size=16)
        pdf.cell(0, 10, text="Restaurant Report", ln=1, align='C')
        pdf.set_font("helvetica", size=12)
        pdf.cell(0, 10, text=f"Date Range: {start_date or '30 Days Ago'} to {end_date or 'Today'}", ln=1, align='C')
        
        pdf.ln(10)
        pdf.set_font("helvetica", 'B', 14)
        pdf.cell(0, 10, text="Summary", ln=1)
        pdf.set_font("helvetica", size=12)
        pdf.cell(0, 10, text=f"Total Revenue: {summary['revenue']}", ln=1)
        pdf.cell(0, 10, text=f"Net Profit: {summary['net_profit']}", ln=1)
        pdf.cell(0, 10, text=f"Total Expenses: {summary['expenses']}", ln=1)
        pdf.cell(0, 10, text=f"Avg Order Value: {summary['avg_order_value']}", ln=1)
        
        pdf.ln(10)
        pdf.set_font("helvetica", 'B', 14)
        pdf.cell(0, 10, text="Category Revenue", ln=1)
        pdf.set_font("helvetica", size=12)
        for cat in categories:
            pdf.cell(0, 10, text=f"{cat['category']}: {cat['revenue']}", ln=1)
            
        pdf.ln(10)
        pdf.set_font("helvetica", 'B', 14)
        pdf.cell(0, 10, text="Expense Breakdown", ln=1)
        pdf.set_font("helvetica", size=12)
        for exp in expenses:
            pdf.cell(0, 10, text=f"{exp['category']}: {exp['amount']}", ln=1)
            
        pdf_bytes = bytes(pdf.output())
        return Response(content=pdf_bytes, media_type="application/pdf", headers={"Content-Disposition": "attachment; filename=restaurant_report.pdf"})

    stream = io.StringIO()
    writer = csv.writer(stream)
    
    writer.writerow(["Report Date Range:", start_date or "30 Days Ago", "to", end_date or "Today"])
    writer.writerow([])
    
    writer.writerow(["--- SUMMARY ---"])
    writer.writerow(["Total Revenue", "Net Profit", "Total Expenses", "Avg Order Value"])
    writer.writerow([summary["revenue"], summary["net_profit"], summary["expenses"], summary["avg_order_value"]])
    writer.writerow([])
    
    writer.writerow(["--- SALES TRENDS ---"])
    writer.writerow(["Date", "Total Sales", "Branch Breakdown"])
    for day in trends:
        branch_strs = []
        for b_name, b_amt in day.get("branches", {}).items():
            branch_strs.append(f"{b_name}: {b_amt}")
        writer.writerow([day["date"], day["amount"], " | ".join(branch_strs)])
    writer.writerow([])
    
    writer.writerow(["--- CATEGORY REVENUE ---"])
    writer.writerow(["Category", "Revenue"])
    for cat in categories:
        writer.writerow([cat["category"], cat["revenue"]])
    writer.writerow([])
    
    writer.writerow(["--- EXPENSE BREAKDOWN ---"])
    writer.writerow(["Category", "Amount"])
    for exp in expenses:
        writer.writerow([exp["category"], exp["amount"]])
        
    response = StreamingResponse(iter([stream.getvalue()]), media_type="text/csv")
    response.headers["Content-Disposition"] = f"attachment; filename=restaurant_report.csv"
    return response
