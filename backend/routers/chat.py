from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse, HTMLResponse
from pydantic import BaseModel
from typing import Optional
from services.ai.engine import RestaurantAgent
import security

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
def chat_endpoint(req: ChatRequest, current_user: dict = Depends(security.get_current_user_token)):
    agent = get_agent()
    # stream_process_query yields NDJSON strings ending with newline
    return StreamingResponse(
        agent.stream_process_query(req.message, req.branch_id),
        media_type="application/x-ndjson"
    )

@router.get("/chart/{chart_id}")
def get_chart_html(chart_id: str):
    agent = get_agent()
    html = getattr(agent, "chart_htmls", {}).get(chart_id)
    if not html:
        return HTMLResponse("<h1>Chart not found or expired</h1>", status_code=404)
    return HTMLResponse(html)
