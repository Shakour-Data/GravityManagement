from pydantic import BaseModel, EmailStr, ConfigDict, Field, field_validator
from typing import Optional
from datetime import datetime, timezone

class User(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
    id: Optional[str] = None
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    disabled: Optional[bool] = False
    role: str = Field("user", pattern="^(user|admin|manager)$")  # user, admin, manager
    github_id: Optional[str] = None
    github_access_token: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    # Removed Config class as deprecated in Pydantic v2

    @field_validator('username')
    @classmethod
    def username_alphanumeric(cls, v):
        if not v.replace('_', '').replace('-', '').isalnum():
            raise ValueError('Username must be alphanumeric with optional underscores or hyphens')
        return v

    @field_validator('role')
    @classmethod
    def role_valid(cls, v):
        if v not in ['user', 'admin', 'manager']:
            raise ValueError('Role must be one of: user, admin, manager')
        return v

class UserInDB(User):
    hashed_password: str

class UserCreate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    username: str
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)

    @field_validator('password')
    @classmethod
    def password_strength(cls, v):
        has_upper = any(c.isupper() for c in v)
        has_lower = any(c.islower() for c in v)
        has_digit = any(c.isdigit() for c in v)
        if not (has_upper and has_lower and has_digit):
            raise ValueError('Password must contain at least one uppercase, one lowercase, and one digit')
        return v

class UserUpdate(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    disabled: Optional[bool] = None

class Token(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    access_token: str
    token_type: str

class TokenData(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    username: Optional[str] = None
