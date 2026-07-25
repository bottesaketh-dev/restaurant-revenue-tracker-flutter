from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional
from services.ai.engine import RestaurantAgent

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])

class ChatRequest(BaseModel):
    message: str
    branch_id: Optional[int] = None

# Use a singleton agent to keep the DB connection and LLM ready
_agent = None

def get_agent():
    global _agent
    if _agent is None:
        _agent = RestaurantAgent()
    return _agent

@router.post("")
def chat_endpoint(req: ChatRequest):
    agent = get_agent()
    # stream_process_query yields NDJSON strings ending with newline
    return StreamingResponse(
        agent.stream_process_query(req.message, req.branch_id),
        media_type="application/x-ndjson"
    )
