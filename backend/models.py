from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, ForeignKey, Date, Numeric, Text, Time, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base

class Restaurant(Base):
    __tablename__ = "restaurants"
    restaurant_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    slug = Column(String(100), unique=True, index=True, nullable=False)
    contact_email = Column(String(255), nullable=False)
    contact_phone = Column(String(50), nullable=True)
    currency_code = Column(String(10), default="INR")
    currency_symbol = Column(String(10), default="₹")
    tax_rate = Column(Numeric(5, 4), default=0.0500)
    receipt_header = Column(Text, nullable=True)
    receipt_footer = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    branches = relationship("Branch", back_populates="restaurant", cascade="all, delete-orphan")


class Branch(Base):
    __tablename__ = "branches"
    branch_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    name = Column(String, nullable=False)
    address = Column(Text, nullable=True)
    phone = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())

    restaurant = relationship("Restaurant", back_populates="branches")


class GroceryCategory(Base):
    __tablename__ = "grocery_categories"
    grocery_category_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)


class ExpenseCategory(Base):
    __tablename__ = "expense_categories"
    expense_category_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)


class User(Base):
    __tablename__ = "users"
    user_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=True) # None for SUPER_ADMIN
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(String, nullable=False) # SUPER_ADMIN, RESTAURANT_ADMIN, BRANCH_MANAGER, STAFF
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=True)
    is_active = Column(Boolean, default=True)
    access_level = Column(String, default="FULL", nullable=False)
    allowed_tabs = Column(Text, nullable=True)  # JSON-encoded list of tab keys, used when access_level is PARTIAL
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class UserPermission(Base):
    __tablename__ = "user_permissions"
    permission_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    permission = Column(String(100), nullable=False) # e.g. "tab:restaurants", "tab:branches", "manage:restaurants", "manage:branches"
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=True)
    branch_id = Column(Integer, ForeignKey("branches.branch_id", ondelete="CASCADE"), nullable=True)
    granted_by = Column(Integer, ForeignKey("users.user_id"), nullable=True)
    created_at = Column(DateTime, default=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "permission", "restaurant_id", "branch_id", name="uq_user_permission_scope"),
    )


class MenuItem(Base):
    __tablename__ = "menu_items"
    menu_item_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False) # Branch-Exclusive Menu
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String, nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    is_vegetarian = Column(Boolean, default=True)
    is_available = Column(Boolean, default=True)
    image_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class RestaurantTable(Base):
    __tablename__ = "restaurant_tables"
    table_id = Column(String, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    capacity = Column(Integer, nullable=False)
    status = Column(String, default="available")
    is_active = Column(Boolean, default=True)


class GroceryItem(Base):
    __tablename__ = "grocery_items"
    grocery_item_id = Column(String, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    product_name = Column(String, nullable=False)
    category_id = Column(Integer, ForeignKey("grocery_categories.grocery_category_id"))
    unit = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())


class Employee(Base):
    __tablename__ = "employees"
    employee_id = Column(String, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, nullable=True)
    phone = Column(String, nullable=False)
    position = Column(String, nullable=False)
    monthly_salary = Column(Numeric(10, 2), nullable=False)
    join_date = Column(Date, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class Order(Base):
    __tablename__ = "orders"
    order_id = Column(String, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    table_id = Column(String, ForeignKey("restaurant_tables.table_id"))
    status = Column(String, nullable=False)
    created_by = Column(Integer, ForeignKey("users.user_id"))
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")


class GroceryPurchase(Base):
    __tablename__ = "grocery_purchases"
    grocery_purchase_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    purchase_date = Column(Date, nullable=False)
    purchase_time = Column(Time, nullable=False)
    grocery_item_id = Column(String, ForeignKey("grocery_items.grocery_item_id"))
    quantity = Column(Numeric(10, 2), nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    total_price = Column(Numeric(10, 2), nullable=False)
    vendor_name = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    recorded_by = Column(Integer, ForeignKey("users.user_id"))
    created_at = Column(DateTime, default=func.now())


class Expense(Base):
    __tablename__ = "expenses"
    expense_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    expense_date = Column(Date, nullable=False)
    expense_time = Column(Time, nullable=False)
    category_id = Column(Integer, ForeignKey("expense_categories.expense_category_id"))
    description = Column(String, nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    payment_mode = Column(String, nullable=False)
    vendor_name = Column(String, nullable=True)
    receipt_number = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    recorded_by = Column(Integer, ForeignKey("users.user_id"))
    created_at = Column(DateTime, default=func.now())


class SalaryPayment(Base):
    __tablename__ = "salary_payments"
    salary_payment_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    employee_id = Column(String, ForeignKey("employees.employee_id"))
    payment_month = Column(Integer, nullable=False)
    payment_year = Column(Integer, nullable=False)
    base_salary = Column(Numeric(10, 2), nullable=False)
    bonus = Column(Numeric(10, 2), default=0.00)
    deductions = Column(Numeric(10, 2), default=0.00)
    net_salary = Column(Numeric(10, 2), nullable=False)
    payment_date = Column(Date, nullable=True)
    payment_status = Column(String, nullable=False)
    payment_mode = Column(String, nullable=True)
    processed_by = Column(Integer, ForeignKey("users.user_id"))
    created_at = Column(DateTime, default=func.now())


class OrderItem(Base):
    __tablename__ = "order_items"
    order_item_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=True)
    order_id = Column(String, ForeignKey("orders.order_id"))
    menu_item_id = Column(Integer, ForeignKey("menu_items.menu_item_id"))
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    total_price = Column(Numeric(10, 2), nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now())
    
    order = relationship("Order", back_populates="items")


class Bill(Base):
    __tablename__ = "bills"
    bill_id = Column(String, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False)
    order_id = Column(String, ForeignKey("orders.order_id"))
    table_id = Column(String, ForeignKey("restaurant_tables.table_id"))
    subtotal = Column(Numeric(10, 2), nullable=False)
    tax_amount = Column(Numeric(10, 2), nullable=False)
    discount_amount = Column(Numeric(10, 2), default=0.00)
    total_amount = Column(Numeric(10, 2), nullable=False)
    payment_mode = Column(String, nullable=False)
    payment_status = Column(String, nullable=False)
    billed_by = Column(Integer, ForeignKey("users.user_id"))
    bill_date = Column(Date, nullable=False)
    bill_time = Column(Time, nullable=False)
    created_at = Column(DateTime)
    notes = Column(Text, nullable=True)
    tip_amount = Column(Numeric(10, 2), nullable=True, default=0.00)
    cash_amount = Column(Numeric(10, 2), nullable=True, default=0.00)
    upi_amount = Column(Numeric(10, 2), nullable=True, default=0.00)
    card_amount = Column(Numeric(10, 2), nullable=True, default=0.00)


class InventoryStock(Base):
    __tablename__ = "inventory_stock"
    inventory_id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="CASCADE"), nullable=False, default=1)
    branch_id = Column(Integer, ForeignKey("branches.branch_id"), nullable=False, default=1)
    grocery_item_id = Column(String, ForeignKey("grocery_items.grocery_item_id"))
    current_stock = Column(Numeric(10, 3), default=0.000)
    last_updated = Column(DateTime, default=func.now(), onupdate=func.now())


class RecipeIngredient(Base):
    __tablename__ = "recipe_ingredients"
    recipe_ingredient_id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.menu_item_id"))
    grocery_item_id = Column(String, ForeignKey("grocery_items.grocery_item_id"))
    quantity_required = Column(Numeric(10, 3), nullable=False)
    created_at = Column(DateTime, default=func.now())


class SupportTicket(Base):
    __tablename__ = "support_tickets"
    ticket_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    ticket_number = Column(String(50), unique=True, index=True, nullable=False)
    restaurant_id = Column(Integer, ForeignKey("restaurants.restaurant_id", ondelete="SET NULL"), nullable=True, index=True)
    branch_id = Column(Integer, ForeignKey("branches.branch_id", ondelete="SET NULL"), nullable=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True, index=True)
    user_name = Column(String(255), nullable=True)
    category = Column(String(100), nullable=False)
    priority = Column(String(50), nullable=False, default="MEDIUM")
    subject = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    contact_phone = Column(String(50), nullable=True)
    status = Column(String(50), nullable=False, default="OPEN")
    resolution_notes = Column(Text, nullable=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

