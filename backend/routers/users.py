from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import json

from database import get_db
from models import User, Branch, UserPermission
import models
import schemas
from security import get_current_user_token, get_password_hash, is_restaurant_admin, get_effective_restaurant_id, is_super_admin
import security

router = APIRouter(prefix="/api/v1/users", tags=["users"])

def _serialize_allowed_tabs(update_data: dict):
    """Convert an 'allowed_tabs' list into a JSON string for storage, if present."""
    if "allowed_tabs" in update_data:
        tabs = update_data["allowed_tabs"]
        update_data["allowed_tabs"] = json.dumps(tabs) if tabs is not None else None
    return update_data

@router.get("/", response_model=List[schemas.UserResponse])
def get_users(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    eff_r_id = get_effective_restaurant_id(current_user, restaurant_id)
    user_role = (current_user.get("role") or "").upper()
    user_branch_id = current_user.get("branch_id")
    
    query = db.query(User)
    if eff_r_id is not None:
        query = query.filter(User.restaurant_id == eff_r_id)
        
    if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
        query = query.filter(User.branch_id == user_branch_id)
        
    return query.order_by(User.user_id).all()

@router.post("/", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if not is_restaurant_admin(current_user):
        raise HTTPException(status_code=403, detail="Only administrators can create users")

    eff_r_id = get_effective_restaurant_id(current_user, user.restaurant_id)

    # Check if username or email already exists
    existing_user = db.query(User).filter(
        (User.username == user.username) | (User.email == user.email)
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Username or email already registered"
        )

    # Validate that branch_id belongs to the restaurant
    if user.branch_id:
        branch = db.query(Branch).filter(Branch.branch_id == user.branch_id).first()
        if not branch:
            raise HTTPException(status_code=400, detail="Specified branch does not exist")
        if eff_r_id is not None and branch.restaurant_id != eff_r_id:
            raise HTTPException(status_code=403, detail="Branch does not belong to your restaurant organization")
        
    hashed_password = get_password_hash(user.password)

    access_level = user.access_level or "FULL"
    allowed_tabs = user.allowed_tabs if access_level == "PARTIAL" else None
    
    db_user = User(
        restaurant_id=eff_r_id,
        username=user.username,
        email=user.email,
        password_hash=hashed_password,
        role=user.role,
        branch_id=user.branch_id,
        is_active=user.is_active,
        access_level=access_level,
        allowed_tabs=json.dumps(allowed_tabs) if allowed_tabs is not None else None,
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.put("/{user_id}", response_model=schemas.UserResponse)
def update_user(
    user_id: int,
    user_update: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if not is_restaurant_admin(current_user):
        raise HTTPException(status_code=403, detail="Only administrators can update users")
        
    eff_r_id = get_effective_restaurant_id(current_user)
    query = db.query(User).filter(User.user_id == user_id)
    if eff_r_id is not None:
        query = query.filter(User.restaurant_id == eff_r_id)

    db_user = query.first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    update_data = user_update.model_dump(exclude_unset=True)

    if "branch_id" in update_data and update_data["branch_id"]:
        branch = db.query(Branch).filter(Branch.branch_id == update_data["branch_id"]).first()
        if not branch or (eff_r_id is not None and branch.restaurant_id != eff_r_id):
            raise HTTPException(status_code=400, detail="Invalid branch assignment for this restaurant")

    if "access_level" in update_data or "allowed_tabs" in update_data:
        if update_data.get("access_level") == "FULL":
            update_data["allowed_tabs"] = None
    
    if "password" in update_data:
        update_data["password_hash"] = get_password_hash(update_data.pop("password"))

    update_data = _serialize_allowed_tabs(update_data)
        
    for key, value in update_data.items():
        setattr(db_user, key, value)
        
    db.commit()
    db.refresh(db_user)
    return db_user

@router.put("/{user_id}/access", response_model=schemas.UserResponse)
def update_user_access(
    user_id: int,
    access_update: schemas.AccessUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if not is_restaurant_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only an ADMIN can update user access/permissions"
        )

    eff_r_id = get_effective_restaurant_id(current_user)
    query = db.query(User).filter(User.user_id == user_id)
    if eff_r_id is not None:
        query = query.filter(User.restaurant_id == eff_r_id)

    db_user = query.first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    target_is_super = (db_user.role or "").upper() == "SUPER_ADMIN"
    if target_is_super:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Super Admins automatically have unrestricted platform access."
        )

    caller_is_super = is_super_admin(current_user)

    # Check whether the target user already had Restaurants tab access
    prev_has_restaurants = False
    if db_user.allowed_tabs:
        try:
            prev_tabs = json.loads(db_user.allowed_tabs) if isinstance(db_user.allowed_tabs, str) else db_user.allowed_tabs
            if "restaurants" in prev_tabs:
                prev_has_restaurants = True
        except Exception:
            pass
    if not prev_has_restaurants:
        has_perm = db.query(UserPermission).filter(
            UserPermission.user_id == user_id,
            UserPermission.permission == "tab:restaurants"
        ).first()
        if has_perm:
            prev_has_restaurants = True

    req_tabs = list(access_update.allowed_tabs or []) if access_update.access_level == "PARTIAL" else []
    req_has_restaurants = access_update.access_level == "PARTIAL" and "restaurants" in req_tabs

    # Only Super Admins can grant or revoke Restaurants tab access
    if not caller_is_super and req_has_restaurants != prev_has_restaurants:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can grant or revoke access to the Restaurants tab."
        )

    db_user.access_level = access_update.access_level
    if access_update.access_level == "FULL":
        db_user.allowed_tabs = None
        # Remove tab:restaurants and tab:branches explicit perms
        db.query(UserPermission).filter(
            UserPermission.user_id == user_id,
            UserPermission.permission.in_(["tab:restaurants", "tab:branches"])
        ).delete(synchronize_session=False)
    else:
        # If caller is not Super Admin, preserve the previous restaurants grant state
        if not caller_is_super and prev_has_restaurants and "restaurants" not in req_tabs:
            req_tabs.append("restaurants")

        db_user.allowed_tabs = json.dumps(req_tabs)

        # Synchronize tab:restaurants in user_permissions
        if "restaurants" in req_tabs:
            perm = db.query(UserPermission).filter(
                UserPermission.user_id == user_id,
                UserPermission.permission == "tab:restaurants"
            ).first()
            if not perm:
                db.add(UserPermission(
                    user_id=user_id,
                    permission="tab:restaurants",
                    restaurant_id=db_user.restaurant_id,
                    granted_by=current_user.get("user_id")
                ))
        else:
            db.query(UserPermission).filter(
                UserPermission.user_id == user_id,
                UserPermission.permission == "tab:restaurants"
            ).delete(synchronize_session=False)

        # Synchronize tab:branches in user_permissions
        if "branches" in req_tabs:
            perm = db.query(UserPermission).filter(
                UserPermission.user_id == user_id,
                UserPermission.permission == "tab:branches"
            ).first()
            if not perm:
                db.add(UserPermission(
                    user_id=user_id,
                    permission="tab:branches",
                    restaurant_id=db_user.restaurant_id,
                    branch_id=db_user.branch_id,
                    granted_by=current_user.get("user_id")
                ))
        else:
            db.query(UserPermission).filter(
                UserPermission.user_id == user_id,
                UserPermission.permission == "tab:branches"
            ).delete(synchronize_session=False)

    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if not is_restaurant_admin(current_user):
        raise HTTPException(status_code=403, detail="Only administrators can delete users")
        
    eff_r_id = get_effective_restaurant_id(current_user)
    query = db.query(User).filter(User.user_id == user_id)
    if eff_r_id is not None:
        query = query.filter(User.restaurant_id == eff_r_id)

    db_user = query.first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    db.delete(db_user)
    db.commit()
