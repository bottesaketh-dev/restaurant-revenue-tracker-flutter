import json
from pydantic import BaseModel, field_validator
from typing import Optional, List
from datetime import date, datetime, time
from decimal import Decimal

# Branches
class BranchResponse(BaseModel):
    branch_id: int
    name: str
    address: str
    phone: str
    class Config:
        from_attributes = True

# Auth
class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    token: str
    message: str
    user: dict

# Users
VALID_TABS = ["home", "users", "pos", "menu", "staff", "groceries", "kitchen", "expenses", "reports", "ai"]

class UserBase(BaseModel):
    username: str
    email: str
    role: str
    branch_id: Optional[int] = None
    is_active: bool = True
    access_level: str = "FULL"
    allowed_tabs: Optional[List[str]] = None

    @field_validator("access_level")
    @classmethod
    def validate_access_level(cls, v):
        if v not in ("FULL", "PARTIAL"):
            raise ValueError("access_level must be 'FULL' or 'PARTIAL'")
        return v

    @field_validator("allowed_tabs")
    @classmethod
    def validate_allowed_tabs(cls, v):
        if v is None:
            return v
        invalid = [t for t in v if t not in VALID_TABS]
        if invalid:
            raise ValueError(f"Invalid tab(s): {invalid}. Valid tabs: {VALID_TABS}")
        return v

class UserCreate(UserBase):
    password: str

class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    branch_id: Optional[int] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None
    access_level: Optional[str] = None
    allowed_tabs: Optional[List[str]] = None

    @field_validator("access_level")
    @classmethod
    def validate_access_level(cls, v):
        if v is not None and v not in ("FULL", "PARTIAL"):
            raise ValueError("access_level must be 'FULL' or 'PARTIAL'")
        return v

    @field_validator("allowed_tabs")
    @classmethod
    def validate_allowed_tabs(cls, v):
        if v is None:
            return v
        invalid = [t for t in v if t not in VALID_TABS]
        if invalid:
            raise ValueError(f"Invalid tab(s): {invalid}. Valid tabs: {VALID_TABS}")
        return v

class AccessUpdate(BaseModel):
    access_level: str
    allowed_tabs: Optional[List[str]] = None

    @field_validator("access_level")
    @classmethod
    def validate_access_level(cls, v):
        if v not in ("FULL", "PARTIAL"):
            raise ValueError("access_level must be 'FULL' or 'PARTIAL'")
        return v

    @field_validator("allowed_tabs")
    @classmethod
    def validate_allowed_tabs(cls, v):
        if v is None:
            return v
        invalid = [t for t in v if t not in VALID_TABS]
        if invalid:
            raise ValueError(f"Invalid tab(s): {invalid}. Valid tabs: {VALID_TABS}")
        return v

class UserResponse(UserBase):
    user_id: int
    created_at: datetime
    updated_at: datetime

    @field_validator("allowed_tabs", mode="before")
    @classmethod
    def parse_allowed_tabs(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except (json.JSONDecodeError, TypeError):
                return None
        return v

    class Config:
        from_attributes = True

# Menu
class MenuItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: str
    price: Decimal
    is_vegetarian: bool = True
    is_available: bool = True
    image_url: Optional[str] = None

class MenuItemCreate(MenuItemBase):
    pass

class MenuItemResponse(MenuItemBase):
    menu_item_id: int
    class Config:
        from_attributes = True

# Employee
class EmployeeBase(BaseModel):
    employee_id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: str
    position: str
    monthly_salary: Decimal
    is_active: bool = True

class EmployeeCreate(EmployeeBase):
    join_date: Optional[date] = None
    branch_id: Optional[int] = None

class EmployeeResponse(EmployeeBase):
    join_date: Optional[date] = None
    class Config:
        from_attributes = True

# Expenses
class ExpenseCategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class ExpenseCategoryCreate(ExpenseCategoryBase):
    pass

class ExpenseCategoryResponse(ExpenseCategoryBase):
    expense_category_id: int
    class Config:
        from_attributes = True

class ExpenseBase(BaseModel):
    expense_date: date
    category_id: Optional[int] = None
    new_category_name: Optional[str] = None
    description: str
    amount: Decimal
    payment_mode: str
    vendor_name: Optional[str] = None
    receipt_number: Optional[str] = None

class ExpenseCreate(ExpenseBase):
    pass

class ExpenseResponse(ExpenseBase):
    expense_id: int
    class Config:
        from_attributes = True

from datetime import datetime, time

# POS Billing
class TableCreate(BaseModel):
    table_id: str
    capacity: int

class TableUpdate(BaseModel):
    table_id: Optional[str] = None
    capacity: Optional[int] = None
    status: Optional[str] = None
    is_active: Optional[bool] = None

class TableResponse(BaseModel):
    table_id: str
    capacity: int
    status: str
    is_active: bool
    class Config:
        from_attributes = True

class OrderItemCreate(BaseModel):
    menu_item_id: int
    quantity: int
    notes: Optional[str] = None

class OrderItemResponse(BaseModel):
    order_item_id: int
    menu_item_id: int
    quantity: int
    unit_price: Decimal
    total_price: Decimal
    notes: Optional[str] = None
    class Config:
        from_attributes = True

class OrderResponse(BaseModel):
    order_id: str
    table_id: str
    status: str
    items: List[OrderItemResponse] = []
    class Config:
        from_attributes = True

class BillCreate(BaseModel):
    order_id: str
    discount_amount: Decimal = Decimal('0')
    payment_mode: str
    notes: Optional[str] = None

class BillResponse(BaseModel):
    bill_id: str
    order_id: str
    table_id: str
    subtotal: Decimal
    tax_amount: Decimal
    discount_amount: Decimal
    total_amount: Decimal
    payment_mode: str
    payment_status: str
    bill_date: date
    class Config:
        from_attributes = True

# Groceries
class GroceryCategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class GroceryCategoryCreate(GroceryCategoryBase):
    pass

class GroceryCategoryResponse(GroceryCategoryBase):
    grocery_category_id: int
    class Config:
        from_attributes = True

class GroceryItemBase(BaseModel):
    product_name: str
    category_id: int
    unit: str

class GroceryItemCreate(GroceryItemBase):
    pass

class GroceryItemResponse(GroceryItemBase):
    grocery_item_id: str
    class Config:
        from_attributes = True

class GroceryPurchaseCreate(BaseModel):
    purchase_date: date
    grocery_item_id: str
    quantity: Decimal
    unit_price: Decimal
    vendor_name: Optional[str] = None
    notes: Optional[str] = None

class GroceryPurchaseResponse(GroceryPurchaseCreate):
    grocery_purchase_id: int
    total_price: Decimal
    class Config:
        from_attributes = True

# Payroll
class SalaryPaymentCreate(BaseModel):
    employee_id: str
    payment_month: int
    payment_year: int
    bonus: Decimal = Decimal('0')
    deductions: Decimal = Decimal('0')
    payment_mode: str

class SalaryPaymentResponse(BaseModel):
    salary_payment_id: int
    employee_id: str
    payment_month: int
    payment_year: int
    base_salary: Decimal
    bonus: Decimal
    deductions: Decimal
    net_salary: Decimal
    payment_date: Optional[date]
    payment_status: str
    payment_mode: Optional[str]
    class Config:
        from_attributes = True

# Inventory
class InventoryStockResponse(BaseModel):
    inventory_id: int
    grocery_item_id: str
    current_stock: Decimal
    last_updated: datetime
    class Config:
        from_attributes = True

# Recipes
class RecipeIngredientBase(BaseModel):
    grocery_item_id: str
    quantity_required: Decimal

class RecipeIngredientCreate(RecipeIngredientBase):
    pass

class RecipeIngredientResponse(RecipeIngredientBase):
    recipe_ingredient_id: int
    menu_item_id: int
    created_at: datetime
    class Config:
        from_attributes = True
