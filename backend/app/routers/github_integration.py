from typing import Dict, Any, List
from fastapi import APIRouter, Request, Depends, HTTPException
from pydantic import BaseModel
from ..database import get_database
from ..models.user import User
from ..routers.auth import get_current_user
from ..services.github_service import process_github_webhook, get_github_repos

class GitHubConnectRequest(BaseModel):
    github_token: str

router = APIRouter()

@router.post("/webhook")
async def github_webhook(request: Request):
    try:
        payload = await request.json()
        event_type = request.headers.get("X-GitHub-Event")
        signature = request.headers.get("X-Hub-Signature-256")

        if not event_type:
            raise HTTPException(status_code=400, detail="Missing GitHub event type")

        # Process the webhook with signature verification
        result = await process_github_webhook(event_type, payload, signature)

        return result
    except HTTPException:
        # Re-raise HTTP exceptions as they are already properly formatted
        raise
    except Exception as e:
        # Log the error and return a 500 response
        print(f"Error processing GitHub webhook: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error processing webhook")

from fastapi import Form

@router.post("/sync")
async def sync_repository(
    repo_full_name: str = Form(...),
    project_id: str = Form(...)
):
    try:
        from ..services.github_service import sync_repository_data
        result = await sync_repository_data(repo_full_name, project_id)
        return result
    except Exception as e:
        print(f"Error syncing repository: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error syncing repository")

@router.get("/repos", response_model=List[Dict[str, Any]])
async def get_user_repos(current_user: User = Depends(get_current_user)):
    if not current_user.github_id:
        raise HTTPException(status_code=400, detail="GitHub not connected")

    try:
        repos = await get_github_repos(current_user.github_id)
        return repos
    except Exception as e:
        print(f"Error getting GitHub repos: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error getting repositories")

@router.post("/connect")
async def connect_github(request: GitHubConnectRequest, current_user: User = Depends(get_current_user)):
    # In a real implementation, you'd validate the token and get user info
    # For now, just store the token (encrypted)
    try:
        db = get_database()
        await db.users.update_one(
            {"username": current_user.username},
            {"$set": {"github_token": request.github_token}}  # In production, encrypt this
        )
        return {"message": "GitHub connected successfully"}
    except Exception as e:
        print(f"Error connecting GitHub: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error connecting GitHub")
