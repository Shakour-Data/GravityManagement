from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

class User(BaseModel):
    id: Optional[str] = None
    username: str
    email: EmailStr
    full_name: Optional[str] = None
    disabled: Optional[bool] = False
    role: str = "user"  # user, admin, manager
    github_id: Optional[str] = None
    created_at: datetime = datetime.utcnow()
    updated_at: datetime.utcnow()

    class Config:
        allow_population_by_field_name = True
        fields = {
            'id': '_id'
        }

class UserInDB(User):
    hashed_password: str

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    disabled: Optional[bool] = None

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
