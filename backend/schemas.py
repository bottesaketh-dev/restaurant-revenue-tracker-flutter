import json
from pydantic import BaseModel, field_validator
from typing import Optional, List
from datetime import date, datetime, time
from decimal import Decimal

# --- Restaurants (Tenants) ---
class RestaurantBase(BaseModel):
    name: str
    slug: str
    contact_email: str
    contact_phone: Optional[str] = None
    currency_code: str = "INR"
    currency_symbol: str = "₹"
    tax_rate: Decimal = Decimal("0.0500")
    receipt_header: Optional[str] = None
    receipt_footer: Optional[str] = None
    is_active: bool = True

class RestaurantCreate(RestaurantBase):
    pass

class RestaurantUpdate(BaseModel):
    name: Optional[str] = None
    slug: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    currency_code: Optional[str] = None
    currency_symbol: Optional[str] = None
    tax_rate: Optional[Decimal] = None
    receipt_header: Optional[str] = None
    receipt_footer: Optional[str] = None
    is_active: Optional[bool] = None

class RestaurantResponse(RestaurantBase):
    restaurant_id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    class Config:
        from_attributes = True


# --- Branches ---
class BranchBase(BaseModel):
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None
    is_active: bool = True

class BranchCreate(BranchBase):
    restaurant_id: Optional[int] = None

class BranchResponse(BranchBase):
    branch_id: int
    restaurant_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Auth ---
class LoginRequest(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None
    password: str

class TokenResponse(BaseModel):
    token: str
    message: str
    user: dict


# --- Users & Roles ---
VALID_TABS = ["home", "users", "pos", "menu", "staff", "groceries", "kitchen", "expenses", "reports", "ai", "restaurants", "branches"]
VALID_ROLES = ["SUPER_ADMIN", "RESTAURANT_ADMIN", "BRANCH_MANAGER", "STAFF", "ADMIN", "MANAGER", "CASHIER"]

class PermissionGrantRequest(BaseModel):
    user_id: int
    granted: bool
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None

class UserTabAccessResponse(BaseModel):
    user_id: int
    username: str
    email: str
    role: str
    restaurant_id: Optional[int] = None
    restaurant_name: Optional[str] = None
    branch_id: Optional[int] = None
    branch_name: Optional[str] = None
    has_access: bool

class UserBase(BaseModel):
    username: str
    email: Optional[str] = None
    role: str
    restaurant_id: Optional[int] = None
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
    restaurant_id: Optional[int] = None
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
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

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


# --- Menu (Branch-Exclusive) ---
class MenuItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: str
    price: Decimal
    is_vegetarian: bool = True
    is_available: bool = True
    image_url: Optional[str] = None

class MenuItemCreate(MenuItemBase):
    branch_id: Optional[int] = None  # Injected from path/query/context if missing

class MenuItemResponse(MenuItemBase):
    menu_item_id: int
    restaurant_id: Optional[int] = None
    branch_id: int
    class Config:
        from_attributes = True


# --- Employees & Staff ---
class EmployeeBase(BaseModel):
    employee_id: Optional[str] = None
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
    restaurant_id: Optional[int] = None

class EmployeeResponse(EmployeeBase):
    join_date: Optional[date] = None
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Expenses ---
class ExpenseCategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class ExpenseCategoryCreate(ExpenseCategoryBase):
    restaurant_id: Optional[int] = None

class ExpenseCategoryResponse(ExpenseCategoryBase):
    expense_category_id: int
    restaurant_id: Optional[int] = None
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
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None

class ExpenseResponse(ExpenseBase):
    expense_id: int
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- POS Billing & Tables ---
class TableCreate(BaseModel):
    table_id: str
    capacity: int
    branch_id: Optional[int] = None
    status: Optional[str] = "available"

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
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None
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
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None
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
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Groceries ---
class GroceryCategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class GroceryCategoryCreate(GroceryCategoryBase):
    restaurant_id: Optional[int] = None

class GroceryCategoryResponse(GroceryCategoryBase):
    grocery_category_id: int
    restaurant_id: Optional[int] = None
    class Config:
        from_attributes = True

class GroceryItemBase(BaseModel):
    product_name: str
    category_id: Optional[int] = None
    grocery_category_id: Optional[int] = None
    unit: str

    @property
    def effective_category_id(self) -> Optional[int]:
        return self.category_id or self.grocery_category_id

class GroceryItemCreate(GroceryItemBase):
    restaurant_id: Optional[int] = None

class GroceryItemResponse(BaseModel):
    grocery_item_id: str
    product_name: str
    category_id: Optional[int] = None
    unit: str
    restaurant_id: Optional[int] = None
    class Config:
        from_attributes = True

class GroceryPurchaseCreate(BaseModel):
    purchase_date: Optional[date] = None
    grocery_item_id: str
    quantity: Decimal
    unit_price: Decimal
    total_price: Optional[Decimal] = None
    payment_mode: Optional[str] = "CASH"
    vendor_name: Optional[str] = None
    notes: Optional[str] = None
    branch_id: Optional[int] = None

class GroceryPurchaseResponse(GroceryPurchaseCreate):
    grocery_purchase_id: int
    total_price: Decimal
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Payroll ---
class SalaryPaymentCreate(BaseModel):
    employee_id: str
    payment_month: int
    payment_year: int
    bonus: Decimal = Decimal('0')
    deductions: Decimal = Decimal('0')
    payment_mode: Optional[str] = "BANK_TRANSFER"
    branch_id: Optional[int] = None

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
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Inventory ---
class InventoryStockResponse(BaseModel):
    inventory_id: int
    grocery_item_id: str
    current_stock: Decimal
    last_updated: datetime
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    class Config:
        from_attributes = True


# --- Recipes ---
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


# --- Support Tickets ---
class SupportTicketCreate(BaseModel):
    category: str
    priority: str = "MEDIUM"
    subject: str
    description: str
    contact_phone: Optional[str] = None
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    metadata_json: Optional[str] = None

class SupportTicketUpdateStatus(BaseModel):
    status: str
    resolution_notes: Optional[str] = None

class SupportTicketResponse(BaseModel):
    ticket_id: int
    ticket_number: str
    restaurant_id: Optional[int] = None
    branch_id: Optional[int] = None
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    category: str
    priority: str
    subject: str
    description: str
    contact_phone: Optional[str] = None
    status: str
    resolution_notes: Optional[str] = None
    metadata_json: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

