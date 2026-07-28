from pydantic import BaseModel
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

# Menu
class MenuItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: str
    price: Decimal
    is_vegetarian: bool = True
    is_available: bool = True

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
