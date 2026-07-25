from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, ForeignKey, Date, Numeric, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base

class Branch(Base):
    __tablename__ = "branches"
    branch_id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    address = Column(String)
    phone = Column(String)

class User(Base):
    __tablename__ = "users"
    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    role = Column(String)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))

class MenuItem(Base):
    __tablename__ = "menu_items"
    menu_item_id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)
    category = Column(String)
    price = Column(Numeric(10, 2))
    is_vegetarian = Column(Boolean, default=True)
    is_available = Column(Boolean, default=True)
    image_url = Column(String, nullable=True)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class Employee(Base):
    __tablename__ = "employees"
    employee_id = Column(String, primary_key=True, index=True)
    first_name = Column(String)
    last_name = Column(String)
    email = Column(String)
    phone = Column(String)
    position = Column(String)
    monthly_salary = Column(Numeric(10, 2))
    join_date = Column(Date)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))

class ExpenseCategory(Base):
    __tablename__ = "expense_categories"
    expense_category_id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    description = Column(String)

class Expense(Base):
    __tablename__ = "expenses"
    expense_id = Column(Integer, primary_key=True, index=True)
    expense_date = Column(Date)
    category_id = Column(Integer, ForeignKey("expense_categories.expense_category_id"))
    description = Column(String)
    amount = Column(Numeric(10, 2))
    payment_mode = Column(String)
    vendor_name = Column(String, nullable=True)
    receipt_number = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    recorded_by = Column(Integer, ForeignKey("users.user_id"))
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))

from sqlalchemy import Time

class RestaurantTable(Base):
    __tablename__ = "restaurant_tables"
    table_id = Column(String, primary_key=True, index=True)
    capacity = Column(Integer)
    status = Column(String)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    is_active = Column(Boolean, default=True)

class Order(Base):
    __tablename__ = "orders"
    order_id = Column(String, primary_key=True, index=True)
    table_id = Column(String, ForeignKey("restaurant_tables.table_id"))
    status = Column(String)
    created_by = Column(Integer, ForeignKey("users.user_id"))
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

class OrderItem(Base):
    __tablename__ = "order_items"
    order_item_id = Column(Integer, primary_key=True, index=True)
    order_id = Column(String, ForeignKey("orders.order_id"))
    menu_item_id = Column(Integer, ForeignKey("menu_items.menu_item_id"))
    quantity = Column(Integer)
    unit_price = Column(Numeric(10, 2))
    total_price = Column(Numeric(10, 2))
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime)
    
    order = relationship("Order", back_populates="items")

class Bill(Base):
    __tablename__ = "bills"
    bill_id = Column(String, primary_key=True, index=True)
    order_id = Column(String, ForeignKey("orders.order_id"))
    table_id = Column(String, ForeignKey("restaurant_tables.table_id"))
    subtotal = Column(Numeric(10, 2))
    tax_amount = Column(Numeric(10, 2))
    discount_amount = Column(Numeric(10, 2))
    total_amount = Column(Numeric(10, 2))
    tip_amount = Column(Numeric(10, 2), default=0)
    payment_mode = Column(String)
    cash_amount = Column(Numeric(10, 2), default=0)
    upi_amount = Column(Numeric(10, 2), default=0)
    card_amount = Column(Numeric(10, 2), default=0)
    payment_status = Column(String)
    billed_by = Column(Integer, ForeignKey("users.user_id"))
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    bill_date = Column(Date)
    bill_time = Column(Time)
    created_at = Column(DateTime)
    notes = Column(Text, nullable=True)

class GroceryCategory(Base):
    __tablename__ = "grocery_categories"
    grocery_category_id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)

class GroceryItem(Base):
    __tablename__ = "grocery_items"
    grocery_item_id = Column(String, primary_key=True, index=True)
    product_name = Column(String)
    category_id = Column(Integer, ForeignKey("grocery_categories.grocery_category_id"))
    unit = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime)

class GroceryPurchase(Base):
    __tablename__ = "grocery_purchases"
    grocery_purchase_id = Column(Integer, primary_key=True, index=True)
    purchase_date = Column(Date)
    purchase_time = Column(Time)
    grocery_item_id = Column(String, ForeignKey("grocery_items.grocery_item_id"))
    quantity = Column(Numeric(10, 2))
    unit_price = Column(Numeric(10, 2))
    total_price = Column(Numeric(10, 2))
    vendor_name = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    recorded_by = Column(Integer, ForeignKey("users.user_id"))
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    created_at = Column(DateTime)

class SalaryPayment(Base):
    __tablename__ = "salary_payments"
    salary_payment_id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(String, ForeignKey("employees.employee_id"))
    payment_month = Column(Integer)
    payment_year = Column(Integer)
    base_salary = Column(Numeric(10, 2))
    bonus = Column(Numeric(10, 2))
    deductions = Column(Numeric(10, 2))
    net_salary = Column(Numeric(10, 2))
    payment_date = Column(Date, nullable=True)
    payment_status = Column(String)
    payment_mode = Column(String, nullable=True)
    processed_by = Column(Integer, ForeignKey("users.user_id"))
    branch_id = Column(Integer, ForeignKey("branches.branch_id"))
    created_at = Column(DateTime)
