from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import json

from database import get_db
from models import User
import schemas
from security import get_current_user_token, get_password_hash

router = APIRouter(prefix="/api/v1/users", tags=["users"])

def _serialize_allowed_tabs(update_data: dict):
    """Convert an 'allowed_tabs' list into a JSON string for storage, if present."""
    if "allowed_tabs" in update_data:
        tabs = update_data["allowed_tabs"]
        update_data["allowed_tabs"] = json.dumps(tabs) if tabs is not None else None
    return update_data

@router.get("/", response_model=List[schemas.UserResponse])
def get_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    
    query = db.query(User)
    if (user_role or "").upper() != "ADMIN" and user_branch_id is not None:
        query = query.filter(User.branch_id == user_branch_id)
        
    return query.all()

@router.post("/", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if current_user.get("role") != "ADMIN":
        raise HTTPException(status_code=403, detail="Only administrators can create users")
    # Check if username or email already exists
    existing_user = db.query(User).filter(
        (User.username == user.username) | (User.email == user.email)
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Username or email already registered"
        )
        
    hashed_password = get_password_hash(user.password)

    # Only an ADMIN may set access_level/allowed_tabs on another user; others default to FULL access.
    is_admin = (current_user.get("role") or "").upper() == "ADMIN"
    access_level = user.access_level if is_admin else "FULL"
    allowed_tabs = user.allowed_tabs if (is_admin and access_level == "PARTIAL") else None
    
    db_user = User(
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
    if current_user.get("role") != "ADMIN":
        raise HTTPException(status_code=403, detail="Only administrators can update users")
    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    update_data = user_update.model_dump(exclude_unset=True)

    # Only an ADMIN can change access_level/allowed_tabs, and only for other users.
    if "access_level" in update_data or "allowed_tabs" in update_data:
        if (current_user.get("role") or "").upper() != "ADMIN":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only an ADMIN can update user access/permissions"
            )
        # Partial access without any tabs selected is treated as no tabs
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
    """Dedicated endpoint for updating just a user's access level and tab permissions.
    Only an ADMIN is allowed to perform this action."""
    if (current_user.get("role") or "").upper() != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only an ADMIN can update user access/permissions"
        )

    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    db_user.access_level = access_update.access_level
    if access_update.access_level == "FULL":
        db_user.allowed_tabs = None
    else:
        db_user.allowed_tabs = json.dumps(access_update.allowed_tabs or [])

    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if current_user.get("role") != "ADMIN":
        raise HTTPException(status_code=403, detail="Only administrators can delete users")
    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    db.delete(db_user)
    db.commit()
