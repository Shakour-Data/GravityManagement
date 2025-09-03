from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
import jwt
from jwt import ExpiredSignatureError, InvalidTokenError
from passlib.context import CryptContext
from ..database import get_database
from ..models.user import User, UserInDB, UserCreate, Token, TokenData
from ..services.auth_service import (
    authenticate_user,
    create_access_token,
    get_github_oauth_url,
    exchange_github_code_for_token,
    get_github_user_info,
    authenticate_or_create_github_user,
    check_user_role
)

router = APIRouter()

# Security settings
SECRET_KEY = "your-secret-key-here"  # In production, use environment variable
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except (ExpiredSignatureError, InvalidTokenError):
        raise credentials_exception

    db = get_database()
    user = await db.users.find_one({"username": token_data.username})
    if user is None:
        raise credentials_exception
    user_data = {k: v for k, v in user.items() if k != 'hashed_password'}
    return User(**user_data)

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    if current_user.disabled:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

def get_current_user_with_role(required_role: str):
    """
    Dependency to get current user and check role
    """
    async def dependency(current_user: User = Depends(get_current_active_user)):
        if not check_user_role(UserInDB(**current_user.dict()), required_role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required role: {required_role}"
            )
        return current_user
    return dependency

@router.post("/register", response_model=User)
@limiter.limit("5/minute")
async def register(request: Request, user: UserCreate):
    db = get_database()
    # Check if user exists
    existing_user = await db.users.find_one({"$or": [{"username": user.username}, {"email": user.email}]})
    if existing_user:
        raise HTTPException(status_code=400, detail="Username or email already registered")

    hashed_password = pwd_context.hash(user.password)
    user_dict = user.dict()
    user_dict["hashed_password"] = hashed_password
    user_dict["created_at"] = datetime.utcnow()
    user_dict["updated_at"] = datetime.utcnow()
    del user_dict["password"]

    result = await db.users.insert_one(user_dict)
    created_user = await db.users.find_one({"_id": result.inserted_id})
    user_data = {k: v for k, v in created_user.items() if k != 'hashed_password'}
    return User(**user_data)

@router.post("/token", response_model=Token)
@limiter.limit("10/minute")
async def login_for_access_token(request: Request, form_data: OAuth2PasswordRequestForm = Depends()):
    user = await authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.get("/github/login")
async def github_login(state: Optional[str] = None):
    """
    Initiate GitHub OAuth login
    """
    return {"authorization_url": get_github_oauth_url(state)}

@router.get("/github/callback")
async def github_callback(code: str = Query(...), state: str = Query(...)):
    """
    Handle GitHub OAuth callback
    """
    try:
        # Exchange code for token
        token_data = await exchange_github_code_for_token(code)

        if "error" in token_data:
            raise HTTPException(status_code=400, detail=token_data["error_description"])

        access_token = token_data["access_token"]

        # Get user info from GitHub
        github_user_data = await get_github_user_info(access_token)

        # Authenticate or create user
        user = await authenticate_or_create_github_user(github_user_data, access_token)

        # Create JWT token
        jwt_token = create_access_token(
            data={"sub": user.username},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )

        return {
            "access_token": jwt_token,
            "token_type": "bearer",
            "user": User(**user.dict())
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"GitHub authentication failed: {str(e)}")

@router.get("/users", response_model=list[User])
async def get_users(
    current_user: User = Depends(get_current_user_with_role("admin")),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    """
    Get all users (admin only)
    """
    db = get_database()
    users = await db.users.find().skip(skip).limit(limit).to_list(length=None)
    return [User(**user) for user in users]

@router.put("/users/{user_id}/role")
async def update_user_role(
    user_id: str,
    role: str,
    current_user: User = Depends(get_current_user_with_role("admin"))
):
    """
    Update user role (admin only)
    """
    if role not in ["user", "manager", "admin"]:
        raise HTTPException(status_code=400, detail="Invalid role")

    db = get_database()
    result = await db.users.update_one(
        {"_id": user_id},
        {"$set": {"role": role, "updated_at": datetime.utcnow()}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="User not found")

    return {"message": "User role updated successfully"}
