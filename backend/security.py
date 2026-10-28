import os
from datetime import datetime, timedelta, timezone
from typing import Optional, List
import bcrypt
import jwt
import json
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
import models

security = HTTPBearer()

SECRET_KEY = os.getenv("SECRET_KEY", "fastapi_restaurant_tracker_super_secret_jwt_key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 1 day

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        role = payload.get("role")
        restaurant_id = payload.get("restaurant_id")
        branch_id = payload.get("branch_id")
        if user_id is None or role is None:
            raise HTTPException(status_code=401, detail="Invalid token: missing claims")
        return {
            "user_id": int(user_id),
            "role": role,
            "restaurant_id": int(restaurant_id) if restaurant_id is not None else None,
            "branch_id": int(branch_id) if branch_id is not None else None,
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_user_token(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    data = decode_token(credentials.credentials)
    header_r_id = request.headers.get("x-restaurant-id")
    if header_r_id:
        try:
            data["requested_restaurant_id"] = int(header_r_id)
        except ValueError:
            pass
    return data

def is_super_admin(token_data: dict) -> bool:
    return (token_data.get("role") or "").upper() == "SUPER_ADMIN"

def is_restaurant_admin(token_data: dict) -> bool:
    role = (token_data.get("role") or "").upper()
    return role in ("RESTAURANT_ADMIN", "ADMIN", "SUPER_ADMIN")

def is_branch_admin(token_data: dict) -> bool:
    role = (token_data.get("role") or "").upper()
    return role in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN", "BRANCH_MANAGER", "MANAGER")

def has_restaurants_tab_access(user_id: int, role: str, db: Session) -> bool:
    """
    Super Admins have access to the Restaurants tab by default.
    Other users must have an explicit 'tab:restaurants' grant or 'restaurants' in allowed_tabs.
    """
    if role.upper() == "SUPER_ADMIN":
        return True
        
    # Check user_permissions table
    perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == user_id,
        models.UserPermission.permission == "tab:restaurants"
    ).first()
    if perm:
        return True

    # Fallback to User.allowed_tabs
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if user and user.allowed_tabs:
        try:
            tabs = json.loads(user.allowed_tabs) if isinstance(user.allowed_tabs, str) else user.allowed_tabs
            if "restaurants" in tabs:
                return True
        except Exception:
            pass
            
    return False

def can_manage_restaurants(user_id: int, role: str, db: Session) -> bool:
    """
    Tab access is not the same as management permission.
    Only Super Admins (or users with explicit 'manage:restaurants' permission) can create/update/delete restaurants.
    """
    if role.upper() == "SUPER_ADMIN":
        return True
    perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == user_id,
        models.UserPermission.permission == "manage:restaurants"
    ).first()
    return perm is not None

def has_branches_tab_access(user_id: int, role: str, db: Session) -> bool:
    """
    Super Admins, Restaurant Admins, and Branch Managers have access to Branches tab by default.
    Ordinary users (Cashiers, Staff) must have an explicit 'tab:branches' grant.
    """
    if role.upper() in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN", "BRANCH_MANAGER", "MANAGER"):
        return True
        
    perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == user_id,
        models.UserPermission.permission == "tab:branches"
    ).first()
    if perm:
        return True

    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if user and user.allowed_tabs:
        try:
            tabs = json.loads(user.allowed_tabs) if isinstance(user.allowed_tabs, str) else user.allowed_tabs
            if "branches" in tabs:
                return True
        except Exception:
            pass
            
    return False

def can_manage_branches(
    user_id: int,
    role: str,
    user_restaurant_id: Optional[int],
    user_branch_id: Optional[int],
    target_restaurant_id: int,
    target_branch_id: Optional[int],
    db: Session
) -> bool:
    """
    Validates branch management privileges (create/update/delete/access-grant):
    - Super Admins can manage branches across any restaurant.
    - Restaurant Admins can manage branches within their own restaurant.
    - Branch Managers can manage their own assigned branch within their restaurant.
    - Other users cannot manage branches unless they have explicit 'manage:branches' permission.
    """
    role_upper = role.upper()
    if role_upper == "SUPER_ADMIN":
        return True
        
    if role_upper in ("RESTAURANT_ADMIN", "ADMIN"):
        return user_restaurant_id == target_restaurant_id
        
    if role_upper in ("BRANCH_MANAGER", "MANAGER"):
        if user_restaurant_id != target_restaurant_id:
            return False
        if target_branch_id is not None and user_branch_id is not None:
            return user_branch_id == target_branch_id
        return True

    perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == user_id,
        models.UserPermission.permission == "manage:branches",
        models.UserPermission.restaurant_id == target_restaurant_id
    ).first()
    return perm is not None

def get_effective_restaurant_id(token_data: dict, requested_restaurant_id: Optional[int] = None) -> Optional[int]:
    """
    Enforces tenant boundaries:
    - Super Admins can query any restaurant or none.
    - Restaurant Admins, Managers, and Staff are strictly restricted to their own restaurant_id.
    """
    if is_super_admin(token_data):
        return requested_restaurant_id or token_data.get("requested_restaurant_id") or token_data.get("restaurant_id")
    r_id = token_data.get("restaurant_id")
    if r_id is None:
        raise HTTPException(status_code=403, detail="User is not associated with any restaurant organization.")
    return r_id
