from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import json
from database import get_db
import models, schemas, security

router = APIRouter(prefix="/api/v1/restaurants", tags=["restaurants"])

@router.get("/current", response_model=Optional[schemas.RestaurantResponse])
def get_current_restaurant(
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    eff_r_id = security.get_effective_restaurant_id(current_user)
    if not eff_r_id:
        # Super admin with no specific restaurant context
        return None
        
    restaurant = db.query(models.Restaurant).filter(
        models.Restaurant.restaurant_id == eff_r_id
    ).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant organization not found."
        )
    return restaurant

@router.get("", response_model=List[schemas.RestaurantResponse])
def list_restaurants(
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    # Verify tab access
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    if not security.has_restaurants_tab_access(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access the Restaurants tab."
        )

    if security.is_super_admin(current_user):
        return db.query(models.Restaurant).order_by(models.Restaurant.restaurant_id).all()
        
    eff_r_id = security.get_effective_restaurant_id(current_user)
    if eff_r_id:
        restaurant = db.query(models.Restaurant).filter(
            models.Restaurant.restaurant_id == eff_r_id
        ).first()
        return [restaurant] if restaurant else []
    return []

@router.get("/access/users", response_model=List[schemas.UserTabAccessResponse])
def get_restaurant_tab_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Super Admins only: Retrieve list of users and their Restaurants tab access status.
    """
    if not security.is_super_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can manage Restaurants tab access."
        )

    users = db.query(models.User).order_by(models.User.user_id).all()
    results = []
    
    # Query all explicit tab:restaurants grants
    explicit_grants = {
        p.user_id for p in db.query(models.UserPermission).filter(
            models.UserPermission.permission == "tab:restaurants"
        ).all()
    }

    restaurants_map = {r.restaurant_id: r.name for r in db.query(models.Restaurant).all()}
    branches_map = {b.branch_id: b.name for b in db.query(models.Branch).all()}

    for u in users:
        is_super = (u.role or "").upper() == "SUPER_ADMIN"
        has_explicit = u.user_id in explicit_grants
        # Also check allowed_tabs
        has_allowed = False
        if u.allowed_tabs:
            try:
                tabs = json.loads(u.allowed_tabs) if isinstance(u.allowed_tabs, str) else u.allowed_tabs
                if "restaurants" in tabs:
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
            has_access=is_super or has_explicit or has_allowed,
        ))

    return results

@router.post("/access/grant")
def grant_restaurant_tab_access(
    req: schemas.PermissionGrantRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Super Admins only: Grant or revoke Restaurants tab access for a user.
    """
    if not security.is_super_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can grant or revoke Restaurants tab access."
        )

    target_user = db.query(models.User).filter(models.User.user_id == req.user_id).first()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target user not found."
        )

    if (target_user.role or "").upper() == "SUPER_ADMIN":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Super Admins automatically have unrestricted platform access."
        )

    existing_perm = db.query(models.UserPermission).filter(
        models.UserPermission.user_id == req.user_id,
        models.UserPermission.permission == "tab:restaurants"
    ).first()

    if req.granted:
        if not existing_perm:
            new_perm = models.UserPermission(
                user_id=req.user_id,
                permission="tab:restaurants",
                restaurant_id=target_user.restaurant_id,
                granted_by=current_user.get("user_id"),
            )
            db.add(new_perm)
        # Also ensure target_user.allowed_tabs contains 'restaurants' if PARTIAL
        if target_user.allowed_tabs:
            try:
                tabs = json.loads(target_user.allowed_tabs) if isinstance(target_user.allowed_tabs, str) else target_user.allowed_tabs
                if "restaurants" not in tabs:
                    tabs.append("restaurants")
                    target_user.allowed_tabs = json.dumps(tabs)
            except Exception:
                pass
    else:
        if existing_perm:
            db.delete(existing_perm)
        if target_user.allowed_tabs:
            try:
                tabs = json.loads(target_user.allowed_tabs) if isinstance(target_user.allowed_tabs, str) else target_user.allowed_tabs
                if "restaurants" in tabs:
                    tabs.remove("restaurants")
                    target_user.allowed_tabs = json.dumps(tabs)
            except Exception:
                pass

    db.commit()
    return {
        "status": "success",
        "message": f"Restaurants tab access {'granted to' if req.granted else 'revoked from'} {target_user.username}."
    }

@router.get("/{restaurant_id}", response_model=schemas.RestaurantResponse)
def get_restaurant(
    restaurant_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    if not security.has_restaurants_tab_access(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access the Restaurants tab."
        )

    if not security.is_super_admin(current_user):
        user_r_id = current_user.get("restaurant_id")
        if user_r_id != restaurant_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to access details for this restaurant."
            )
            
    restaurant = db.query(models.Restaurant).filter(
        models.Restaurant.restaurant_id == restaurant_id
    ).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant organization not found."
        )
    return restaurant

@router.post("", response_model=schemas.RestaurantResponse, status_code=status.HTTP_201_CREATED)
def create_restaurant(
    req: schemas.RestaurantCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    if not security.can_manage_restaurants(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can create new restaurant organizations."
        )
        
    existing_slug = db.query(models.Restaurant).filter(models.Restaurant.slug == req.slug).first()
    if existing_slug:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Restaurant with slug '{req.slug}' already exists."
        )
        
    restaurant = models.Restaurant(**req.model_dump())
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)
    return restaurant

@router.put("/{restaurant_id}", response_model=schemas.RestaurantResponse)
def update_restaurant(
    restaurant_id: int,
    req: schemas.RestaurantUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    is_super = security.is_super_admin(current_user)
    is_r_admin = security.is_restaurant_admin(current_user)
    user_r_id = current_user.get("restaurant_id")
    
    if not is_super and not (is_r_admin and user_r_id == restaurant_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have administrative permissions to update this restaurant."
        )
        
    restaurant = db.query(models.Restaurant).filter(
        models.Restaurant.restaurant_id == restaurant_id
    ).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant not found."
        )
        
    update_data = req.model_dump(exclude_unset=True)
    if "slug" in update_data and update_data["slug"] != restaurant.slug:
        existing = db.query(models.Restaurant).filter(
            models.Restaurant.slug == update_data["slug"],
            models.Restaurant.restaurant_id != restaurant_id
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Slug is already taken by another restaurant."
            )
            
    for key, value in update_data.items():
        setattr(restaurant, key, value)
        
    db.commit()
    db.refresh(restaurant)
    return restaurant

@router.delete("/{restaurant_id}", status_code=status.HTTP_200_OK)
def delete_or_deactivate_restaurant(
    restaurant_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Deactivates or deletes a restaurant organization.
    Only Super Admins can perform this action.
    To preserve operational data integrity, if the restaurant has branches, orders,
    or employees, it is soft-deactivated (is_active = False).
    """
    user_id = current_user.get("user_id")
    role = current_user.get("role") or ""
    if not security.can_manage_restaurants(user_id, role, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can delete or deactivate restaurant organizations."
        )

    restaurant = db.query(models.Restaurant).filter(
        models.Restaurant.restaurant_id == restaurant_id
    ).first()
    if not restaurant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant organization not found."
        )

    # Check for operational data dependencies
    branch_count = db.query(models.Branch).filter(models.Branch.restaurant_id == restaurant_id).count()
    
    if branch_count > 0:
        # Soft-deactivate to protect relational and financial integrity
        restaurant.is_active = False
        # Also deactivate child branches
        db.query(models.Branch).filter(models.Branch.restaurant_id == restaurant_id).update({"is_active": False})
        db.commit()
        return {
            "status": "deactivated",
            "message": f"Restaurant '{restaurant.name}' and its {branch_count} branch(es) have been deactivated to preserve historical operational data."
        }
    else:
        # No branches or operational data, safe to physically delete
        db.delete(restaurant)
        db.commit()
        return {
            "status": "deleted",
            "message": f"Restaurant '{restaurant.name}' was permanently removed."
        }
