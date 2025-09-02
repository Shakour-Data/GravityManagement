from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class ResourceType(str, Enum):
    HUMAN = "human"
    MATERIAL = "material"
    FINANCIAL = "financial"

class ResourceAllocation(BaseModel):
    task_id: str
    allocated_quantity: float
    start_date: datetime
    end_date: Optional[datetime] = None
    allocated_by: str  # user_id

class ResourceConflict(BaseModel):
    conflicting_allocation_id: str
    conflict_type: str  # over_allocation, time_overlap, etc.
    severity: str  # low, medium, high
    description: str

class ResourceUtilization(BaseModel):
    period_start: datetime
    period_end: datetime
    utilization_percentage: float
    allocated_quantity: float
    available_quantity: float

class Resource(BaseModel):
    id: Optional[str] = None
    name: str
    type: ResourceType
    description: Optional[str] = None
    project_id: str
    quantity: Optional[float] = None
    cost: Optional[float] = None
    availability: bool = True
    skill_level: Optional[int] = Field(None, ge=1, le=5)  # For human resources
    location: Optional[str] = None
    allocations: List[ResourceAllocation] = []
    utilization_history: List[ResourceUtilization] = []
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

    class Config:
        allow_population_by_field_name = True
        fields = {
            'id': '_id'
        }

class ResourceCreate(BaseModel):
    name: str
    type: ResourceType
    description: Optional[str] = None
    project_id: str
    quantity: Optional[float] = None
    cost: Optional[float] = None

class ResourceUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    quantity: Optional[float] = None
    cost: Optional[float] = None
    availability: Optional[bool] = None
