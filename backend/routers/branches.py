from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from database import get_db
import models, schemas

router = APIRouter(prefix="/api/v1/branches", tags=["branches"])

@router.get("/", response_model=List[schemas.BranchResponse])
def get_branches(db: Session = Depends(get_db)):
    branches = db.query(models.Branch).all()
    return branches
