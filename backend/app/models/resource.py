from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from enum import Enum

class ResourceType(str, Enum):
    HUMAN = "human"
    MATERIAL = "material"
    FINANCIAL = "financial"

class Resource(BaseModel):
    id: Optional[str] = None
    name: str
    type: ResourceType
    description: Optional[str] = None
    project_id: str
    quantity: Optional[float] = None
    cost: Optional[float] = None
    availability: bool = True
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
