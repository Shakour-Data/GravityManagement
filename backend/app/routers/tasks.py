from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from ..database import get_database
from ..models.task import Task, TaskCreate, TaskUpdate
from ..models.user import User
from ..routers.auth import get_current_user

router = APIRouter()

@router.post("/", response_model=Task)
async def create_task(task: TaskCreate, current_user: User = Depends(get_current_user)):
    db = get_database()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection not available")
    # Check if project exists and user has access
    project = await db.projects.find_one({"_id": task.project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")

    task_dict = task.dict()
    result = await db.tasks.insert_one(task_dict)
    created_task = await db.tasks.find_one({"_id": result.inserted_id})
    return Task(**created_task)

@router.get("/", response_model=List[Task])
async def get_tasks(project_id: str = None, current_user: User = Depends(get_current_user)):
    db = get_database()
    query = {}
    if project_id:
        # Check project access
        project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
        if not project:
            raise HTTPException(status_code=404, detail="Project not found or not authorized")
        query["project_id"] = project_id
    else:
        # Get tasks from user's projects
        user_projects = await db.projects.find({"$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]}).to_list(length=None)
        project_ids = [p["_id"] for p in user_projects]
        query["project_id"] = {"$in": project_ids}
    
    tasks = await db.tasks.find(query).to_list(length=None)
    return [Task(**task) for task in tasks]

@router.get("/{task_id}", response_model=Task)
async def get_task(task_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    task = await db.tasks.find_one({"_id": task_id})
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": task["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    return Task(**task)

@router.put("/{task_id}", response_model=Task)
async def update_task(task_id: str, task_update: TaskUpdate, current_user: User = Depends(get_current_user)):
    db = get_database()
    task = await db.tasks.find_one({"_id": task_id})
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": task["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    update_data = {k: v for k, v in task_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    
    await db.tasks.update_one({"_id": task_id}, {"$set": update_data})
    updated_task = await db.tasks.find_one({"_id": task_id})
    return Task(**updated_task)

@router.delete("/{task_id}")
async def delete_task(task_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    task = await db.tasks.find_one({"_id": task_id})
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": task["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    await db.tasks.delete_one({"_id": task_id})
    return {"message": "Task deleted successfully"}
