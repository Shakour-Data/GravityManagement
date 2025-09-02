from pydantic import BaseModel, validator, Field
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
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: ProjectStatus = ProjectStatus.PLANNING
    owner_id: str
    github_repo: Optional[str] = Field(None, regex=r'^https://github\.com/[\w.-]+/[\w.-]+$')  # GitHub repo URL
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)  # Must be non-negative
    team_members: List[str] = []  # List of user IDs
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

    class Config:
        allow_population_by_field_name = True
        fields = {
            'id': '_id'
        }

    @validator('end_date')
    def end_date_after_start(cls, v, values):
        if v and values.get('start_date') and v <= values['start_date']:
            raise ValueError('End date must be after start date')
        return v

    @validator('budget')
    def budget_positive(cls, v):
        if v is not None and v < 0:
            raise ValueError('Budget must be non-negative')
        return v

class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    github_repo: Optional[str] = Field(None, regex=r'^https://github\.com/[\w.-]+/[\w.-]+$')
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)

    @validator('end_date')
    def end_date_after_start(cls, v, values):
        if v and values.get('start_date') and v <= values['start_date']:
            raise ValueError('End date must be after start date')
        return v

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: Optional[ProjectStatus] = None
    github_repo: Optional[str] = Field(None, regex=r'^https://github\.com/[\w.-]+/[\w.-]+$')
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)
    team_members: Optional[List[str]] = None

    @validator('end_date')
    def end_date_after_start(cls, v, values):
        if v and values.get('start_date') and v <= values['start_date']:
            raise ValueError('End date must be after start date')
        return v
