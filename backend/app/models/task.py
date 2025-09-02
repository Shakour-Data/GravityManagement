from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"
    BLOCKED = "blocked"

class TaskDependency(BaseModel):
    task_id: str
    dependency_type: str = "finish_to_start"  # finish_to_start, start_to_start, etc.

class TaskProgress(BaseModel):
    percentage: float = 0.0
    estimated_hours: Optional[float] = None
    actual_hours: Optional[float] = None
    last_updated: datetime = datetime.utcnow()

class Task(BaseModel):
    id: Optional[str] = None
    title: str
    description: Optional[str] = None
    project_id: str
    assignee_id: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO
    due_date: Optional[datetime] = None
    dependencies: List[TaskDependency] = []
    progress: TaskProgress = TaskProgress()
    priority: int = Field(default=1, ge=1, le=5)  # 1=low, 5=critical
    tags: List[str] = []
    created_at: datetime = datetime.utcnow()
    updated_at: datetime.utcnow()

    class Config:
        allow_population_by_field_name = True
        fields = {
            'id': '_id'
        }

class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    project_id: str
    assignee_id: Optional[str] = None
    due_date: Optional[datetime] = None
    dependencies: Optional[List[TaskDependency]] = None
    estimated_hours: Optional[float] = None
    priority: Optional[int] = Field(default=1, ge=1, le=5)
    tags: Optional[List[str]] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    assignee_id: Optional[str] = None
    status: Optional[TaskStatus] = None
    due_date: Optional[datetime] = None
    dependencies: Optional[List[TaskDependency]] = None
    progress_percentage: Optional[float] = Field(None, ge=0, le=100)
    actual_hours: Optional[float] = None
    priority: Optional[int] = Field(None, ge=1, le=5)
    tags: Optional[List[str]] = None
