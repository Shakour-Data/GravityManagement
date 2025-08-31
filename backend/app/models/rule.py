from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

class RuleType(str, Enum):
    GITHUB_EVENT = "github_event"
    SYSTEM_EVENT = "system_event"
    SCHEDULED = "scheduled"

class Rule(BaseModel):
    name: str
    description: Optional[str] = None
    type: RuleType
    conditions: Dict[str, Any]  # JSON conditions
    actions: List[Dict[str, Any]]  # List of actions to perform
    active: bool = True
    project_id: Optional[str] = None  # If specific to a project
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

class RuleCreate(BaseModel):
    name: str
    description: Optional[str] = None
    type: RuleType
    conditions: Dict[str, Any]
    actions: List[Dict[str, Any]]
    project_id: Optional[str] = None

class RuleUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    conditions: Optional[Dict[str, Any]] = None
    actions: Optional[List[Dict[str, Any]]] = None
    active: Optional[bool] = None
