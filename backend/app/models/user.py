from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional
from datetime import datetime

class User(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
    id: Optional[str] = None
    username: str
    email: EmailStr
    full_name: Optional[str] = None
    disabled: Optional[bool] = False
    role: str = "user"  # user, admin, manager
    github_id: Optional[str] = None
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()

    # Removed Config class as deprecated in Pydantic v2

class UserInDB(User):
    hashed_password: str

class UserCreate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    username: str
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class UserUpdate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    disabled: Optional[bool] = None

class Token(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    access_token: str
    token_type: str

class TokenData(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    username: Optional[str] = None
