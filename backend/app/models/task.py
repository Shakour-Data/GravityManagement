from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"
    BLOCKED = "blocked"

class Task(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
    id: Optional[str] = None
    title: str
    description: Optional[str] = None
    project_id: str
    assignee_id: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO
    due_date: Optional[datetime] = None
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

    # Removed Config class as deprecated in Pydantic v2

class TaskCreate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    title: str
    description: Optional[str] = None
    project_id: str
    assignee_id: Optional[str] = None
    due_date: Optional[datetime] = None

class TaskUpdate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    title: Optional[str] = None
    description: Optional[str] = None
    assignee_id: Optional[str] = None
    status: Optional[TaskStatus] = None
    due_date: Optional[datetime] = None
