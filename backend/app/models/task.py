from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"
    BLOCKED = "blocked"

class Task(BaseModel):
    id: Optional[str] = None
    title: str
    description: Optional[str] = None
    project_id: str
    assignee_id: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO
    due_date: Optional[datetime] = None
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

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    assignee_id: Optional[str] = None
    status: Optional[TaskStatus] = None
    due_date: Optional[datetime] = None
