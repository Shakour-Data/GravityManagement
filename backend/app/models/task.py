from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from datetime import datetime, timezone
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
    last_updated: datetime = datetime.now(timezone.utc)

class Task(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
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
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    # Removed Config class as deprecated in Pydantic v2

class TaskCreate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
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
    model_config = ConfigDict(arbitrary_types_allowed=True)
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
