from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from enum import Enum

class RuleType(str, Enum):
    GITHUB_EVENT = "github_event"
    SYSTEM_EVENT = "system_event"
    SCHEDULED = "scheduled"

class Rule(BaseModel):
    name: str
    description: Optional[str] = None
    type: RuleType
    conditions: Dict[str, Any]  # JSON conditions (supports nested with $and, $or, etc.)
    actions: List[Dict[str, Any]]  # List of actions to perform
    active: bool = True
    project_id: Optional[str] = None  # If specific to a project
    schedule: Optional[str] = None  # Cron expression for scheduled rules
    last_executed: Optional[datetime] = None
    execution_count: int = 0
    success_count: int = 0
    failure_count: int = 0
    average_execution_time: float = 0.0  # in seconds
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

class RuleCreate(BaseModel):
    name: str
    description: Optional[str] = None
    type: RuleType
    conditions: Dict[str, Any]
    actions: List[Dict[str, Any]]
    project_id: Optional[str] = None
    schedule: Optional[str] = None

class RuleUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    conditions: Optional[Dict[str, Any]] = None
    actions: Optional[List[Dict[str, Any]]] = None
    active: Optional[bool] = None
    schedule: Optional[str] = None
