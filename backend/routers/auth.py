from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, security
import json

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

def _user_access_payload(user: models.User) -> dict:
    allowed_tabs = None
    if user.allowed_tabs:
        try:
            allowed_tabs = json.loads(user.allowed_tabs)
        except (json.JSONDecodeError, TypeError):
            allowed_tabs = None
    return {
        "id": user.user_id,
        "username": user.username,
        "email": user.email,
        "role": user.role,
        "branch_id": user.branch_id,
        "access_level": user.access_level or "FULL",
        "allowed_tabs": allowed_tabs,
    }

@router.post("/login", response_model=schemas.TokenResponse)
def login(request: schemas.LoginRequest, db: Session = Depends(get_db)):
    email_input = request.email.strip()
    user = db.query(models.User).filter(
        (models.User.email == email_input) | (models.User.username == email_input)
    ).first()
    
    if not user:
        print("User not found!")
    else:
        if not security.verify_password(request.password, user.password_hash):
            print("Password verification failed!")
            
    if not user or not security.verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
        
    access_token = security.create_access_token(
        data={"sub": str(user.user_id), "role": user.role, "branch_id": user.branch_id}
    )
    
    return {
        "message": "Login successful",
        "token": access_token,
        "user": _user_access_payload(user)
    }

@router.get("/session")
def get_session(token_data: dict = Depends(security.get_current_user_token), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.user_id == int(token_data["sub"])).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _user_access_payload(user)
