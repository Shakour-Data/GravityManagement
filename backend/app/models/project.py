from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from enum import Enum

class ProjectStatus(str, Enum):
    PLANNING = "planning"
    ACTIVE = "active"
    ON_HOLD = "on_hold"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class Project(BaseModel):
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    status: ProjectStatus = ProjectStatus.PLANNING
    owner_id: str
    github_repo: Optional[str] = None  # GitHub repo URL
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = None
    team_members: List[str] = []  # List of user IDs
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

    class Config:
        allow_population_by_field_name = True
        fields = {
            'id': '_id'
        }

class ProjectCreate(BaseModel):
    name: str
    description: Optional[str] = None
    github_repo: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = None

class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    status: Optional[ProjectStatus] = None
    github_repo: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = None
    team_members: Optional[List[str]] = None
