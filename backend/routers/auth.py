from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from database import get_db
import models, schemas, security
import json

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

def _user_access_payload(user: models.User, db: Session) -> dict:
    allowed_tabs = None
    if user.allowed_tabs:
        try:
            allowed_tabs = json.loads(user.allowed_tabs)
        except (json.JSONDecodeError, TypeError):
            allowed_tabs = None

    restaurant = None
    if user.restaurant_id:
        restaurant = db.query(models.Restaurant).filter(models.Restaurant.restaurant_id == user.restaurant_id).first()

    perms = db.query(models.UserPermission).filter(models.UserPermission.user_id == user.user_id).all()
    permissions_list = [p.permission for p in perms]

    return {
        "id": user.user_id,
        "username": user.username,
        "email": user.email,
        "role": user.role,
        "restaurant_id": user.restaurant_id,
        "restaurant_name": restaurant.name if restaurant else None,
        "currency_code": restaurant.currency_code if restaurant else "INR",
        "currency_symbol": restaurant.currency_symbol if restaurant else "₹",
        "tax_rate": float(restaurant.tax_rate) if restaurant else 0.05,
        "branch_id": user.branch_id,
        "access_level": user.access_level or "FULL",
        "allowed_tabs": allowed_tabs,
        "permissions": permissions_list,
    }

@router.post("/login", response_model=schemas.TokenResponse)
def login(request: schemas.LoginRequest, db: Session = Depends(get_db)):
    ident = (request.email or request.username or "").strip()
    if not ident:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or username is required.",
        )
    user = db.query(models.User).filter(
        (models.User.email == ident) | (models.User.username == ident)
    ).first()
    
    if not user or not security.verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your user account is deactivated.",
        )

    # If associated with a restaurant, check that restaurant is active
    if user.restaurant_id:
        restaurant = db.query(models.Restaurant).filter(models.Restaurant.restaurant_id == user.restaurant_id).first()
        if restaurant and not restaurant.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Restaurant organization '{restaurant.name}' is currently inactive.",
            )

    access_token = security.create_access_token(
        data={
            "sub": str(user.user_id),
            "role": user.role,
            "restaurant_id": user.restaurant_id,
            "branch_id": user.branch_id,
        }
    )
    
    return {
        "message": "Login successful",
        "token": access_token,
        "user": _user_access_payload(user, db)
    }

@router.get("/session")
@router.get("/me")
def get_session(token_data: dict = Depends(security.get_current_user_token), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.user_id == token_data["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _user_access_payload(user, db)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

@router.post("/change-password")
def change_password(
    req: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not security.verify_password(req.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password does not match.")

    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters long.")

    user.password_hash = security.get_password_hash(req.new_password)
    db.commit()
    return {"message": "Password changed successfully."}


class RegisterRestaurantRequest(BaseModel):
    restaurant_name: str
    slug: str
    admin_username: str
    admin_email: str
    admin_password: str
    currency_code: str = "INR"
    currency_symbol: str = "₹"
    tax_rate: float = 0.05
    initial_branch_name: str = "Main Branch"
    phone: Optional[str] = None

@router.post("/register-restaurant", status_code=status.HTTP_201_CREATED)
def register_restaurant(req: RegisterRestaurantRequest, db: Session = Depends(get_db)):
    """Creates a new restaurant tenant with its default branch and initial restaurant admin account."""
    existing_slug = db.query(models.Restaurant).filter(models.Restaurant.slug == req.slug).first()
    if existing_slug:
        raise HTTPException(status_code=400, detail=f"Restaurant slug '{req.slug}' is already registered.")

    existing_user = db.query(models.User).filter(
        (models.User.username == req.admin_username) | (models.User.email == req.admin_email)
    ).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Admin username or email already registered.")

    # 1. Create Restaurant
    restaurant = models.Restaurant(
        name=req.restaurant_name,
        slug=req.slug,
        contact_email=req.admin_email,
        contact_phone=req.phone,
        currency_code=req.currency_code,
        currency_symbol=req.currency_symbol,
        tax_rate=req.tax_rate,
        is_active=True
    )
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)

    # 2. Create Initial Branch
    branch = models.Branch(
        restaurant_id=restaurant.restaurant_id,
        name=req.initial_branch_name,
        phone=req.phone,
        is_active=True
    )
    db.add(branch)
    db.commit()
    db.refresh(branch)

    # 3. Create Restaurant Admin User
    admin_user = models.User(
        restaurant_id=restaurant.restaurant_id,
        username=req.admin_username,
        email=req.admin_email,
        password_hash=security.get_password_hash(req.admin_password),
        role="RESTAURANT_ADMIN",
        branch_id=None,
        is_active=True,
        access_level="FULL"
    )
    db.add(admin_user)
    db.commit()
    db.refresh(admin_user)

    return {
        "message": "Restaurant successfully registered",
        "restaurant_id": restaurant.restaurant_id,
        "restaurant_name": restaurant.name,
        "branch_id": branch.branch_id,
        "admin_username": admin_user.username,
    }
