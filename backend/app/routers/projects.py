from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from ..database import get_database
from ..models.project import Project, ProjectCreate, ProjectUpdate
from ..models.user import User
from ..routers.auth import get_current_user

router = APIRouter()

@router.post("/", response_model=Project)
async def create_project(project: ProjectCreate, current_user: User = Depends(get_current_user)):
    db = get_database()
    project_dict = project.dict()
    project_dict["owner_id"] = current_user.username
    project_dict["team_members"] = [current_user.username]
    result = await db.projects.insert_one(project_dict)
    created_project = await db.projects.find_one({"_id": result.inserted_id})
    return Project(**created_project)

@router.get("/", response_model=List[Project])
async def get_projects(current_user: User = Depends(get_current_user)):
    db = get_database()
    projects = await db.projects.find({"$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]}).to_list(length=None)
    return [Project(**project) for project in projects]

@router.get("/{project_id}", response_model=Project)
async def get_project(project_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return Project(**project)

@router.put("/{project_id}", response_model=Project)
async def update_project(project_id: str, project_update: ProjectUpdate, current_user: User = Depends(get_current_user)):
    db = get_database()
    # Check if user owns the project
    project = await db.projects.find_one({"_id": project_id, "owner_id": current_user.username})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")
    
    update_data = {k: v for k, v in project_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    
    await db.projects.update_one({"_id": project_id}, {"$set": update_data})
    updated_project = await db.projects.find_one({"_id": project_id})
    return Project(**updated_project)

@router.delete("/{project_id}")
async def delete_project(project_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    # Check if user owns the project
    project = await db.projects.find_one({"_id": project_id, "owner_id": current_user.username})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")

    await db.projects.delete_one({"_id": project_id})
    return {"message": "Project deleted successfully"}

@router.post("/{project_id}/budget/spend")
async def update_spent_amount(project_id: str, amount: float, current_user: User = Depends(get_current_user)):
    from ..services.project_service import project_service

    # Check if user has access to the project
    db = get_database()
    project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")

    try:
        updated_project = await project_service.update_spent_amount(project_id, amount)
        return {"message": "Spent amount updated", "project": updated_project}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{project_id}/budget/report")
async def get_budget_report(project_id: str, current_user: User = Depends(get_current_user)):
    from ..services.project_service import project_service

    # Check if user has access to the project
    db = get_database()
    project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")

    report = await project_service.get_budget_report(project_id)
    return report

@router.get("/{project_id}/budget/alert")
async def check_budget_alert(project_id: str, current_user: User = Depends(get_current_user)):
    from ..services.project_service import project_service

    # Check if user has access to the project
    db = get_database()
    project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")

    alert = await project_service.check_budget_alert(project_id)
    return alert
