from pydantic import BaseModel, field_validator, Field, ConfigDict
from typing import List, Optional
from datetime import datetime, timezone
from enum import Enum

class ProjectStatus(str, Enum):
    PLANNING = "planning"
    ACTIVE = "active"
    ON_HOLD = "on_hold"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class TimelineMilestone(BaseModel):
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    due_date: datetime
    completed: bool = False
    completed_at: Optional[datetime] = None
    dependencies: List[str] = []  # IDs of milestones this depends on

class ProjectTimeline(BaseModel):
    milestones: List[TimelineMilestone] = []
    critical_path: List[str] = []  # IDs of critical path milestones
    estimated_duration_days: Optional[int] = None
    actual_duration_days: Optional[int] = None
    progress_percentage: float = 0.0

class Project(BaseModel):
    id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: ProjectStatus = ProjectStatus.PLANNING
    owner_id: str
    github_repo: Optional[str] = Field(None, pattern=r'^https://github\.com/[\w.-]+/[\w.-]+$')  # GitHub repo URL
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)  # Must be non-negative
    spent_amount: float = Field(default=0.0, ge=0)  # Amount spent so far
    budget_alert_threshold: float = Field(default=0.8, ge=0, le=1)  # Alert when spent > threshold * budget
    timeline: ProjectTimeline = ProjectTimeline()  # Project timeline with milestones
    team_members: List[str] = []  # List of user IDs
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    model_config = ConfigDict(populate_by_name=True)

    @field_validator('end_date')
    @classmethod
    def end_date_after_start(cls, v, info):
        if v and info.data.get('start_date') and v <= info.data['start_date']:
            raise ValueError('End date must be after start date')
        return v

    @field_validator('budget')
    @classmethod
    def budget_positive(cls, v):
        if v is not None and v < 0:
            raise ValueError('Budget must be non-negative')
        return v

class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    github_repo: Optional[str] = Field(None, pattern=r'^https://github\.com/[\w.-]+/[\w.-]+$')
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)
    budget_alert_threshold: float = Field(default=0.8, ge=0, le=1)

    @field_validator('end_date')
    @classmethod
    def end_date_after_start(cls, v, info):
        if v and info.data.get('start_date') and v <= info.data['start_date']:
            raise ValueError('End date must be after start date')
        return v

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: Optional[ProjectStatus] = None
    github_repo: Optional[str] = Field(None, pattern=r'^https://github\.com/[\w.-]+/[\w.-]+$')
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    budget: Optional[float] = Field(None, ge=0)
    spent_amount: Optional[float] = Field(None, ge=0)
    budget_alert_threshold: Optional[float] = Field(None, ge=0, le=1)
    team_members: Optional[List[str]] = None

    @field_validator('end_date')
    @classmethod
    def end_date_after_start(cls, v, info):
        if v and info.data.get('start_date') and v <= info.data['start_date']:
            raise ValueError('End date must be after start date')
        return v
