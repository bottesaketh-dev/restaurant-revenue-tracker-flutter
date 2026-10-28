from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import json
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/branches", tags=["branches"])

@router.get("/", response_model=List[schemas.BranchResponse])
def get_branches(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    
    # Enforce tab access permission
    if not security.has_branches_tab_access(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access the Branches tab."
        )

    query = db.query(models.Branch)
    
    if security.is_super_admin(current_user):
        if restaurant_id is not None:
            query = query.filter(models.Branch.restaurant_id == restaurant_id)
    else:
        eff_r_id = security.get_effective_restaurant_id(current_user)
        if eff_r_id is not None:
            query = query.filter(models.Branch.restaurant_id == eff_r_id)
        
        # If user is branch-bound (e.g. manager or staff), restrict to their branch
        user_role = role.upper()
        user_branch_id = current_user.get("branch_id")
        if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
            query = query.filter(models.Branch.branch_id == user_branch_id)
        
    return query.order_by(models.Branch.branch_id).all()

@router.get("/access/users", response_model=List[schemas.UserTabAccessResponse])
def get_branch_tab_users(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Authorized Super Admins and Branch/Restaurant Admins:
    Retrieve list of users within authorized scope and their Branches tab access status.
    """
    if not security.is_branch_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators and managers can manage Branches tab access."
        )

    user_role = (current_user.get("role") or "").upper()
    user_r_id = current_user.get("restaurant_id")
    user_b_id = current_user.get("branch_id")

    query = db.query(models.User)

    if user_role == "SUPER_ADMIN":
        if restaurant_id is not None:
            query = query.filter(models.User.restaurant_id == restaurant_id)
    elif user_role in ("RESTAURANT_ADMIN", "ADMIN"):
        query = query.filter(models.User.restaurant_id == user_r_id)
    else:  # BRANCH_MANAGER, MANAGER
        query = query.filter(
            models.User.restaurant_id == user_r_id,
            models.User.branch_id == user_b_id
        )

    users = query.order_by(models.User.user_id).all()
    
    explicit_grants = {
        p.user_id for p in db.query(models.UserPermission).filter(
            models.UserPermission.permission == "tab:branches"
        ).all()
    }

    restaurants_map = {r.restaurant_id: r.name for r in db.query(models.Restaurant).all()}
    branches_map = {b.branch_id: b.name for b in db.query(models.Branch).all()}

    results = []
    for u in users:
        u_role = (u.role or "").upper()
        default_access = u_role in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN", "BRANCH_MANAGER", "MANAGER")
        has_explicit = u.user_id in explicit_grants
        has_allowed = False
        if u.allowed_tabs:
            try:
                tabs = json.loads(u.allowed_tabs) if isinstance(u.allowed_tabs, str) else u.allowed_tabs
                if "branches" in tabs:
                    has_allowed = True
            except Exception:
                pass

        results.append(schemas.UserTabAccessResponse(
            user_id=u.user_id,
            username=u.username,
            email=u.email,
            role=u.role,
            restaurant_id=u.restaurant_id,
            restaurant_name=restaurants_map.get(u.restaurant_id),
            branch_id=u.branch_id,
            branch_name=branches_map.get(u.branch_id),
            has_access=default_access or has_explicit or has_allowed,
        ))

    return results

@router.post("/access/grant")
def grant_branch_tab_access(
    req: schemas.PermissionGrantRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Authorized Super Admins and Branch Admins: Grant or revoke Branches tab access within their scope.
    """
    if not security.is_branch_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators and managers can grant or revoke Branches tab access."
        )

    target_user = db.query(models.User).filter(models.User.user_id == req.user_id).first()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target user not found."
        )

    # Validate that caller has scope authority over target user
    caller_role = (current_user.get("role") or "").upper()
    caller_r_id = current_user.get("restaurant_id")
    caller_b_id = current_user.get("branch_id")

    if caller_role != "SUPER_ADMIN":
        if target_user.restaurant_id != caller_r_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot manage permissions for users in another restaurant organization."
            )
        if caller_role in ("BRANCH_MANAGER", "MANAGER") and target_user.branch_id != caller_b_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot manage permissions for users outside your assigned branch."
            )

    target_role = (target_user.role or "").upper()
    if target_role in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "BRANCH_MANAGER"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Administrators and Branch Managers already have access to the Branches tab by default."
        )

    existing_perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == req.user_id,
        models.UserPermission.permission == "tab:branches"
    ).first()

    if req.granted:
        if not existing_perm:
            new_perm = models.UserPermission(
                user_id=req.user_id,
                permission="tab:branches",
                restaurant_id=target_user.restaurant_id,
                branch_id=target_user.branch_id,
                granted_by=current_user.get("user_id"),
            )
            db.add(new_perm)
        if target_user.allowed_tabs:
            try:
                tabs = json.loads(target_user.allowed_tabs) if isinstance(target_user.allowed_tabs, str) else target_user.allowed_tabs
                if "branches" not in tabs:
                    tabs.append("branches")
                    target_user.allowed_tabs = json.dumps(tabs)
            except Exception:
                pass
    else:
        if existing_perm:
            db.delete(existing_perm)
        if target_user.allowed_tabs:
            try:
                tabs = json.loads(target_user.allowed_tabs) if isinstance(target_user.allowed_tabs, str) else target_user.allowed_tabs
                if "branches" in tabs:
                    tabs.remove("branches")
                    target_user.allowed_tabs = json.dumps(tabs)
            except Exception:
                pass

    db.commit()
    return {
        "status": "success",
        "message": f"Branches tab access {'granted to' if req.granted else 'revoked from'} {target_user.username}."
    }

@router.get("/{branch_id}", response_model=schemas.BranchResponse)
def get_branch(
    branch_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    if not security.has_branches_tab_access(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access the Branches tab."
        )

    query = db.query(models.Branch).filter(models.Branch.branch_id == branch_id)
    
    if not security.is_super_admin(current_user):
        eff_r_id = security.get_effective_restaurant_id(current_user)
        if eff_r_id is not None:
            query = query.filter(models.Branch.restaurant_id == eff_r_id)
        
        user_role = role.upper()
        user_branch_id = current_user.get("branch_id")
        if user_role not in ("SUPER_ADMIN", "RESTAURANT_ADMIN", "ADMIN") and user_branch_id is not None:
            query = query.filter(models.Branch.branch_id == user_branch_id)
        
    db_branch = query.first()
    if not db_branch:
        raise HTTPException(status_code=404, detail="Branch not found or outside authorized scope.")
    return db_branch

@router.post("/", response_model=schemas.BranchResponse, status_code=status.HTTP_201_CREATED)
def create_branch(
    branch_data: schemas.BranchCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    caller_r_id = current_user.get("restaurant_id")
    caller_b_id = current_user.get("branch_id")

    # Determine target restaurant_id
    target_r_id = branch_data.restaurant_id
    if target_r_id is None:
        target_r_id = caller_r_id
        
    if target_r_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parent restaurant_id is required to create a branch."
        )

    # Check parent restaurant exists
    restaurant = db.query(models.Restaurant).filter(models.Restaurant.restaurant_id == target_r_id).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Parent restaurant #{target_r_id} does not exist."
        )

    # Validate authorization to create branches under this restaurant
    if not security.can_manage_branches(user_id, role, caller_r_id, caller_b_id, target_r_id, None, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to create branches under this restaurant organization."
        )

    new_branch = models.Branch(
        restaurant_id=target_r_id,
        name=branch_data.name,
        address=branch_data.address,
        phone=branch_data.phone,
        is_active=branch_data.is_active,
    )
    db.add(new_branch)
    db.commit()
    db.refresh(new_branch)
    return new_branch

@router.put("/{branch_id}", response_model=schemas.BranchResponse)
def update_branch(
    branch_id: int,
    branch_data: schemas.BranchCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    caller_r_id = current_user.get("restaurant_id")
    caller_b_id = current_user.get("branch_id")

    db_branch = db.query(models.Branch).filter(models.Branch.branch_id == branch_id).first()
    if not db_branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    if not security.can_manage_branches(user_id, role, caller_r_id, caller_b_id, db_branch.restaurant_id, branch_id, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this branch."
        )

    update_dict = branch_data.model_dump(exclude_unset=True)

    # If updating restaurant_id, only Super Admin can reassign parent restaurant
    if "restaurant_id" in update_dict and update_dict["restaurant_id"] is not None:
        new_r_id = update_dict["restaurant_id"]
        if new_r_id != db_branch.restaurant_id:
            if not security.is_super_admin(current_user):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only Super Admins can reassign a branch to another parent restaurant."
                )
            target_rest = db.query(models.Restaurant).filter(models.Restaurant.restaurant_id == new_r_id).first()
            if not target_rest:
                raise HTTPException(status_code=404, detail=f"Target restaurant #{new_r_id} does not exist.")

    for key, val in update_dict.items():
        if val is not None or key in ("address", "phone"):
            setattr(db_branch, key, val)
        
    db.commit()
    db.refresh(db_branch)
    return db_branch

@router.delete("/{branch_id}", status_code=status.HTTP_200_OK)
def delete_or_deactivate_branch(
    branch_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Deactivates or deletes a branch.
    Checks operational dependencies (orders, bills, tables, employees).
    Soft-deactivates if data exists to preserve historical records.
    """
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    caller_r_id = current_user.get("restaurant_id")
    caller_b_id = current_user.get("branch_id")

    db_branch = db.query(models.Branch).filter(models.Branch.branch_id == branch_id).first()
    if not db_branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    if not security.can_manage_branches(user_id, role, caller_r_id, caller_b_id, db_branch.restaurant_id, branch_id, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete or deactivate this branch."
        )

    # Check operational dependencies
    order_count = db.query(models.Order).filter(models.Order.branch_id == branch_id).count()
    employee_count = db.query(models.Employee).filter(models.Employee.branch_id == branch_id).count()
    table_count = db.query(models.RestaurantTable).filter(models.RestaurantTable.branch_id == branch_id).count()

    if order_count > 0 or employee_count > 0 or table_count > 0:
        db_branch.is_active = False
        db.commit()
        return {
            "status": "deactivated",
            "message": f"Branch '{db_branch.name}' has been deactivated to preserve {order_count} order(s), {employee_count} employee(s), and {table_count} table(s)."
        }
    else:
        db.delete(db_branch)
        db.commit()
        return {
            "status": "deleted",
            "message": f"Branch '{db_branch.name}' was permanently removed."
        }
