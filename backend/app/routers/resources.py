from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from ..database import get_database
from ..models.resource import Resource, ResourceCreate, ResourceUpdate
from ..models.user import User
from ..routers.auth import get_current_user

router = APIRouter()

@router.post("/", response_model=Resource)
async def create_resource(resource: ResourceCreate, current_user: User = Depends(get_current_user)):
    db = get_database()
    # Check if project exists and user has access
    project = await db.projects.find_one({"_id": resource.project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Project not found or not authorized")
    
    resource_dict = resource.dict()
    result = await db.resources.insert_one(resource_dict)
    created_resource = await db.resources.find_one({"_id": result.inserted_id})
    return Resource(**created_resource)

@router.get("/", response_model=List[Resource])
async def get_resources(project_id: str = None, current_user: User = Depends(get_current_user)):
    db = get_database()
    query = {}
    if project_id:
        # Check project access
        project = await db.projects.find_one({"_id": project_id, "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
        if not project:
            raise HTTPException(status_code=404, detail="Project not found or not authorized")
        query["project_id"] = project_id
    else:
        # Get resources from user's projects
        user_projects = await db.projects.find({"$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]}).to_list(length=None)
        project_ids = [p["_id"] for p in user_projects]
        query["project_id"] = {"$in": project_ids}
    
    resources = await db.resources.find(query).to_list(length=None)
    return [Resource(**resource) for resource in resources]

@router.get("/{resource_id}", response_model=Resource)
async def get_resource(resource_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    resource = await db.resources.find_one({"_id": resource_id})
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": resource["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    return Resource(**resource)

@router.put("/{resource_id}", response_model=Resource)
async def update_resource(resource_id: str, resource_update: ResourceUpdate, current_user: User = Depends(get_current_user)):
    db = get_database()
    resource = await db.resources.find_one({"_id": resource_id})
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": resource["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    update_data = {k: v for k, v in resource_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    
    await db.resources.update_one({"_id": resource_id}, {"$set": update_data})
    updated_resource = await db.resources.find_one({"_id": resource_id})
    return Resource(**updated_resource)

@router.delete("/{resource_id}")
async def delete_resource(resource_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    resource = await db.resources.find_one({"_id": resource_id})
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    # Check project access
    project = await db.projects.find_one({"_id": resource["project_id"], "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]})
    if not project:
        raise HTTPException(status_code=404, detail="Not authorized")
    
    await db.resources.delete_one({"_id": resource_id})
    return {"message": "Resource deleted successfully"}
