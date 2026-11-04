import uuid
import json
import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, desc

from database import get_db
import models
import security
from services.ai.engine import (
    get_agent_service,
    ChatRequestContext,
    cancel_active_conversation,
    generate_conversation_title
)

logger = logging.getLogger("bluefox_ai.router")

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])


# -------------------------------------------------------------------------
# Request & Response Schemas
# -------------------------------------------------------------------------
class CreateConversationRequest(BaseModel):
    title: Optional[str] = None
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None


class RenameConversationRequest(BaseModel):
    title: str


class SystemEventRequest(BaseModel):
    event_type: str = "branch_switch"
    branch_id: int
    branch_name: Optional[str] = None


class SendMessageRequest(BaseModel):
    message: str
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None


# -------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------
def _validate_user_and_scope(
    db: Session,
    current_user: dict,
    req_restaurant_id: Optional[int] = None,
    req_branch_id: Optional[int] = None
) -> tuple[int, Optional[int], Optional[str]]:
    """
    Validates authenticated user identity, effective restaurant scope, and branch authorization.
    Returns (user_id, eff_restaurant_id, branch_name).
    """
    user_id = current_user.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required: missing user identity."
        )

    eff_r_id = security.get_effective_restaurant_id(current_user, req_restaurant_id)

    branch_name = None
    if req_branch_id is not None:
        branch = db.query(models.Branch).filter(models.Branch.branch_id == req_branch_id).first()
        if not branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Branch with ID {req_branch_id} does not exist."
            )
        if eff_r_id is not None and branch.restaurant_id != eff_r_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Branch {req_branch_id} does not belong to your restaurant organization."
            )

        user_role = (current_user.get("role") or "").upper()
        user_b_id = current_user.get("branch_id")
        if user_role in ("BRANCH_MANAGER", "MANAGER", "CASHIER", "STAFF") and user_b_id is not None:
            if user_b_id != req_branch_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You are not authorized to query another branch's operational records."
                )
        branch_name = branch.name

    return user_id, eff_r_id, branch_name


def _get_conversation_or_404(
    db: Session,
    conversation_id: str,
    user_id: int,
    eff_r_id: Optional[int]
) -> models.ChatConversation:
    query = db.query(models.ChatConversation).filter(
        models.ChatConversation.conversation_id == conversation_id,
        models.ChatConversation.user_id == user_id,
        models.ChatConversation.is_archived == False
    )
    if eff_r_id is not None:
        query = query.filter(models.ChatConversation.restaurant_id == eff_r_id)

    conv = query.first()
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found or you are not authorized to view it."
        )
    return conv


# -------------------------------------------------------------------------
# Conversation Management Endpoints
# -------------------------------------------------------------------------
@router.get("/conversations")
def list_conversations(
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Lists all active conversations for the authenticated user and restaurant."""
    user_id, eff_r_id, _ = _validate_user_and_scope(db, current_user, restaurant_id)

    query = db.query(models.ChatConversation).filter(
        models.ChatConversation.user_id == user_id,
        models.ChatConversation.is_archived == False
    )
    if eff_r_id is not None:
        query = query.filter(models.ChatConversation.restaurant_id == eff_r_id)

    conversations = query.order_by(desc(models.ChatConversation.last_message_at)).all()

    result = []
    for conv in conversations:
        # Resolve branch name if attached
        branch_name = None
        if conv.branch_id:
            branch = db.query(models.Branch).filter(models.Branch.branch_id == conv.branch_id).first()
            if branch:
                branch_name = branch.name

        msg_count = db.query(func.count(models.ChatMessage.message_id)).filter(
            models.ChatMessage.conversation_id == conv.conversation_id
        ).scalar() or 0

        result.append({
            "conversation_id": conv.conversation_id,
            "title": conv.title,
            "restaurant_id": conv.restaurant_id,
            "branch_id": conv.branch_id,
            "branch_name": branch_name,
            "created_at": conv.created_at.isoformat() if conv.created_at else None,
            "updated_at": conv.updated_at.isoformat() if conv.updated_at else None,
            "last_message_at": conv.last_message_at.isoformat() if conv.last_message_at else None,
            "message_count": msg_count
        })

    return result


@router.post("/conversations")
def create_conversation(
    req: CreateConversationRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Creates a new empty conversation for the authenticated user."""
    user_id, eff_r_id, branch_name = _validate_user_and_scope(db, current_user, req.restaurant_id, req.branch_id)

    conv_id = str(uuid.uuid4())
    conv = models.ChatConversation(
        conversation_id=conv_id,
        user_id=user_id,
        restaurant_id=eff_r_id,
        branch_id=req.branch_id,
        title=req.title or "New Chat",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        last_message_at=datetime.now(timezone.utc)
    )
    db.add(conv)
    db.commit()
    db.refresh(conv)

    return {
        "conversation_id": conv.conversation_id,
        "title": conv.title,
        "restaurant_id": conv.restaurant_id,
        "branch_id": conv.branch_id,
        "branch_name": branch_name,
        "created_at": conv.created_at.isoformat(),
        "updated_at": conv.updated_at.isoformat(),
        "last_message_at": conv.last_message_at.isoformat(),
        "message_count": 0
    }


@router.get("/conversations/{conversation_id}")
def get_conversation_history(
    conversation_id: str,
    restaurant_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Retrieves a conversation and all its persisted messages."""
    user_id, eff_r_id, _ = _validate_user_and_scope(db, current_user, restaurant_id)
    conv = _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    messages = db.query(models.ChatMessage).filter(
        models.ChatMessage.conversation_id == conversation_id
    ).order_by(models.ChatMessage.created_at.asc()).all()

    formatted_messages = []
    for m in messages:
        meta = {}
        if m.metadata_json:
            try:
                meta = json.loads(m.metadata_json)
            except Exception:
                meta = {}

        formatted_messages.append({
            "message_id": m.message_id,
            "role": m.role,
            "content": m.content,
            "restaurant_id": m.restaurant_id,
            "branch_id": m.branch_id,
            "status": m.status,
            "metadata": meta,
            "created_at": m.created_at.isoformat() if m.created_at else None
        })

    branch_name = None
    if conv.branch_id:
        b = db.query(models.Branch).filter(models.Branch.branch_id == conv.branch_id).first()
        if b:
            branch_name = b.name

    return {
        "conversation_id": conv.conversation_id,
        "title": conv.title,
        "restaurant_id": conv.restaurant_id,
        "branch_id": conv.branch_id,
        "branch_name": branch_name,
        "created_at": conv.created_at.isoformat() if conv.created_at else None,
        "updated_at": conv.updated_at.isoformat() if conv.updated_at else None,
        "last_message_at": conv.last_message_at.isoformat() if conv.last_message_at else None,
        "messages": formatted_messages
    }


@router.patch("/conversations/{conversation_id}")
def rename_conversation(
    conversation_id: str,
    req: RenameConversationRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Renames an existing conversation."""
    user_id, eff_r_id, _ = _validate_user_and_scope(db, current_user)
    conv = _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    new_title = req.title.strip()
    if not new_title:
        raise HTTPException(status_code=400, detail="Title cannot be empty.")

    conv.title = new_title
    conv.updated_at = datetime.now(timezone.utc)
    db.commit()

    return {"status": "success", "conversation_id": conversation_id, "title": conv.title}


@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Deletes (or marks archived) a conversation and its messages."""
    user_id, eff_r_id, _ = _validate_user_and_scope(db, current_user)
    conv = _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    # Cancel if actively running
    cancel_active_conversation(conversation_id)

    db.delete(conv)
    db.commit()

    return {"status": "success", "message": f"Conversation {conversation_id} deleted."}


@router.post("/conversations/{conversation_id}/system-event")
def record_system_event(
    conversation_id: str,
    req: SystemEventRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Persists a branch-switch system event in the conversation timeline.
    """
    user_id, eff_r_id, branch_name = _validate_user_and_scope(db, current_user, None, req.branch_id)
    conv = _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    name_to_use = req.branch_name or branch_name or f"Branch #{req.branch_id}"
    event_text = f"Switched to branch: {name_to_use}"

    msg_id = str(uuid.uuid4())
    event_msg = models.ChatMessage(
        message_id=msg_id,
        conversation_id=conversation_id,
        role="system",
        content=event_text,
        restaurant_id=eff_r_id,
        branch_id=req.branch_id,
        status="completed",
        metadata_json=json.dumps({"event_type": req.event_type, "branch_id": req.branch_id, "branch_name": name_to_use}),
        created_at=datetime.now(timezone.utc)
    )
    db.add(event_msg)

    # Update conversation's active branch
    conv.branch_id = req.branch_id
    conv.last_message_at = datetime.now(timezone.utc)
    db.commit()

    return {
        "status": "success",
        "message_id": msg_id,
        "content": event_text,
        "branch_id": req.branch_id,
        "branch_name": name_to_use
    }


@router.post("/conversations/{conversation_id}/stop")
def stop_generation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Cancels active stream generation for the conversation."""
    user_id, eff_r_id, _ = _validate_user_and_scope(db, current_user)
    _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    cancelled = cancel_active_conversation(conversation_id)
    return {"status": "success", "cancelled": cancelled}


# -------------------------------------------------------------------------
# Streaming Chat Message Execution
# -------------------------------------------------------------------------
@router.post("/conversations/{conversation_id}/messages")
def send_conversation_message(
    conversation_id: str,
    req: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """
    Submits a user query into a conversation, streaming tokens and progress events.
    """
    user_id, eff_r_id, branch_name = _validate_user_and_scope(db, current_user, req.restaurant_id, req.branch_id)
    conv = _get_conversation_or_404(db, conversation_id, user_id, eff_r_id)

    # Resolve currency symbol
    currency_symbol = "₹"
    if eff_r_id is not None:
        rest = db.query(models.Restaurant).filter(models.Restaurant.restaurant_id == eff_r_id).first()
        if rest and rest.currency_symbol:
            currency_symbol = rest.currency_symbol

    # Retrieve previous conversation messages for LLM context
    history_records = db.query(models.ChatMessage).filter(
        models.ChatMessage.conversation_id == conversation_id,
        models.ChatMessage.status == "completed"
    ).order_by(models.ChatMessage.created_at.asc()).all()

    conv_history = [
        {"role": m.role, "content": m.content}
        for m in history_records[-10:]
    ]

    context = ChatRequestContext(
        conversation_id=conversation_id,
        user_id=user_id,
        restaurant_id=eff_r_id,
        branch_id=req.branch_id or conv.branch_id,
        branch_name=branch_name,
        currency_symbol=currency_symbol
    )

    agent_service = get_agent_service()

    return StreamingResponse(
        agent_service.stream_process_query(
            context=context,
            user_input=req.message,
            conversation_history=conv_history
        ),
        media_type="application/x-ndjson"
    )


# -------------------------------------------------------------------------
# Legacy Endpoint Compatibility (POST /api/v1/chat)
# -------------------------------------------------------------------------
class LegacyChatRequest(BaseModel):
    message: str
    branch_id: Optional[int] = None
    restaurant_id: Optional[int] = None
    conversation_id: Optional[str] = None


@router.post("")
def legacy_chat_endpoint(
    req: LegacyChatRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)
):
    """Backwards-compatible endpoint for chat queries."""
    user_id, eff_r_id, branch_name = _validate_user_and_scope(db, current_user, req.restaurant_id, req.branch_id)

    conv_id = req.conversation_id
    if not conv_id:
        # Check for existing latest conversation or create one
        latest = db.query(models.ChatConversation).filter(
            models.ChatConversation.user_id == user_id,
            models.ChatConversation.is_archived == False
        ).order_by(desc(models.ChatConversation.last_message_at)).first()

        if latest:
            conv_id = latest.conversation_id
        else:
            conv_id = str(uuid.uuid4())
            new_conv = models.ChatConversation(
                conversation_id=conv_id,
                user_id=user_id,
                restaurant_id=eff_r_id,
                branch_id=req.branch_id,
                title=generate_conversation_title(req.message),
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
                last_message_at=datetime.now(timezone.utc)
            )
            db.add(new_conv)
            db.commit()

    return send_conversation_message(
        conversation_id=conv_id,
        req=SendMessageRequest(message=req.message, branch_id=req.branch_id, restaurant_id=eff_r_id),
        db=db,
        current_user=current_user
    )
