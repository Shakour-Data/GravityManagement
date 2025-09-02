from typing import Dict, Any, List
from fastapi import APIRouter, Request, Depends, HTTPException
from ..database import get_database
from ..models.user import User
from ..routers.auth import get_current_user
from ..services.github_service import process_github_webhook, get_github_repos

router = APIRouter()

@router.post("/webhook")
async def github_webhook(request: Request):
    payload = await request.json()
    event_type = request.headers.get("X-GitHub-Event")
    signature = request.headers.get("X-Hub-Signature-256")

    if not event_type:
        raise HTTPException(status_code=400, detail="Missing GitHub event type")

    # Process the webhook with signature verification
    result = await process_github_webhook(event_type, payload, signature)

    return result

@router.post("/sync")
async def sync_repository(repo_full_name: str, project_id: str):
    from ..services.github_service import sync_repository_data
    result = await sync_repository_data(repo_full_name, project_id)
    return result

@router.get("/repos", response_model=List[Dict[str, Any]])
async def get_user_repos(current_user: User = Depends(get_current_user)):
    if not current_user.github_id:
        raise HTTPException(status_code=400, detail="GitHub not connected")
    
    repos = await get_github_repos(current_user.github_id)
    return repos

@router.post("/connect")
async def connect_github(github_token: str, current_user: User = Depends(get_current_user)):
    # In a real implementation, you'd validate the token and get user info
    # For now, just store the token (encrypted)
    db = get_database()
    await db.users.update_one(
        {"username": current_user.username},
        {"$set": {"github_token": github_token}}  # In production, encrypt this
    )
    return {"message": "GitHub connected successfully"}
