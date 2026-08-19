from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import User
import schemas
from security import get_current_user_token, get_password_hash

router = APIRouter(prefix="/api/v1/users", tags=["users"])

@router.get("/", response_model=List[schemas.UserResponse])
def get_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    
    query = db.query(User)
    if user_role != "ADMIN" and user_branch_id is not None:
        query = query.filter(User.branch_id == user_branch_id)
        
    return query.all()

@router.post("/", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
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
    
    db_user = User(
        username=user.username,
        email=user.email,
        password_hash=hashed_password,
        role=user.role,
        branch_id=user.branch_id,
        is_active=user.is_active
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
    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    update_data = user_update.model_dump(exclude_unset=True)
    
    if "password" in update_data:
        update_data["password_hash"] = get_password_hash(update_data.pop("password"))
        
    for key, value in update_data.items():
        setattr(db_user, key, value)
        
    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    db.delete(db_user)
    db.commit()
