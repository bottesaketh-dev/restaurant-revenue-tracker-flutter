from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from database import get_db
import models, schemas

from security import get_current_user_token

router = APIRouter(prefix="/api/v1/branches", tags=["branches"])

@router.get("/", response_model=List[schemas.BranchResponse])
def get_branches(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    
    query = db.query(models.Branch)
    if user_role != "ADMIN" and user_branch_id is not None:
        query = query.filter(models.Branch.branch_id == user_branch_id)
        
    return query.all()
