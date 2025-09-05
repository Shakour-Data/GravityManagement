from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import secrets
import httpx
import jwt
from jwt import ExpiredSignatureError, InvalidTokenError
from passlib.context import CryptContext
from ..database import get_database
from ..models.user import UserInDB

# Security settings
SECRET_KEY = "your-secret-key-here"  # In production, use environment variable
ALGORITHM = "HS256"

# GitHub OAuth settings - should be set via environment variables
GITHUB_CLIENT_ID = "your-github-client-id"
GITHUB_CLIENT_SECRET = "your-github-client-secret"
GITHUB_REDIRECT_URI = "http://localhost:8000/auth/github/callback"

# Google OAuth settings - should be set via environment variables
GOOGLE_CLIENT_ID = "your-google-client-id"
GOOGLE_CLIENT_SECRET = "your-google-client-secret"
GOOGLE_REDIRECT_URI = "http://localhost:8000/auth/google/callback"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False

def get_password_hash(password):
    return pwd_context.hash(password)

async def authenticate_user(username: str, password: str):
    db = get_database()
    user = await db.users.find_one({"username": username})
    if not user:
        return False
    if not verify_password(password, user["hashed_password"]):
        return False
    return UserInDB(**user)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# GitHub OAuth functions
def get_github_oauth_url(state: str = None) -> str:
    """
    Generate GitHub OAuth authorization URL
    """
    if not state:
        state = secrets.token_urlsafe(32)

    params = {
        "client_id": GITHUB_CLIENT_ID,
        "redirect_uri": GITHUB_REDIRECT_URI,
        "scope": "user:email,repo",
        "state": state
    }

    query_string = "&".join([f"{k}={v}" for k, v in params.items()])
    return f"https://github.com/login/oauth/authorize?{query_string}"

async def exchange_github_code_for_token(code: str) -> Dict[str, Any]:
    """
    Exchange GitHub authorization code for access token
    """
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://github.com/login/oauth/access_token",
            data={
                "client_id": GITHUB_CLIENT_ID,
                "client_secret": GITHUB_CLIENT_SECRET,
                "code": code,
                "redirect_uri": GITHUB_REDIRECT_URI
            },
            headers={"Accept": "application/json"}
        )

    if response.status_code != 200:
        raise Exception("Failed to exchange code for token")

    return response.json()

async def get_github_user_info(access_token: str) -> Dict[str, Any]:
    """
    Get user information from GitHub API
    """
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.github.com/user",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/vnd.github.v3+json"
            }
        )

    if response.status_code != 200:
        raise Exception("Failed to get user info from GitHub")

    user_data = response.json()

    # Get user emails
    email_response = await client.get(
        "https://api.github.com/user/emails",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github.v3+json"
        }
    )

    if email_response.status_code == 200:
        emails = email_response.json()
        primary_email = next((email for email in emails if email["primary"]), None)
        if primary_email:
            user_data["email"] = primary_email["email"]

    return user_data

async def authenticate_or_create_github_user(github_user_data: Dict[str, Any], access_token: str) -> UserInDB:
    """
    Authenticate existing user or create new user from GitHub data
    """
    db = get_database()

    # Try to find existing user by GitHub ID
    existing_user = await db.users.find_one({"github_id": github_user_data["id"]})

    if existing_user:
        # Update access token
        await db.users.update_one(
            {"_id": existing_user["_id"]},
            {"$set": {"github_access_token": access_token, "updated_at": datetime.now(timezone.utc)}}
        )
        return UserInDB(**existing_user)

    # Try to find by email
    existing_user = await db.users.find_one({"email": github_user_data.get("email")})

    if existing_user:
        # Link GitHub account
        await db.users.update_one(
            {"_id": existing_user["_id"]},
            {"$set": {
                "github_id": github_user_data["id"],
                "github_access_token": access_token,
                "updated_at": datetime.now(timezone.utc)
            }}
        )
        return UserInDB(**existing_user)

    # Create new user
    username = github_user_data["login"]
    # Ensure username is unique
    counter = 1
    original_username = username
    while await db.users.find_one({"username": username}):
        username = f"{original_username}_{counter}"
        counter += 1

    user_dict = {
        "username": username,
        "email": github_user_data.get("email", ""),
        "full_name": github_user_data.get("name", ""),
        "github_id": github_user_data["id"],
        "github_access_token": access_token,
        "role": "user",
        "disabled": False,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    }

    result = await db.users.insert_one(user_dict)
    created_user = await db.users.find_one({"_id": result.inserted_id})
    return UserInDB(**created_user)

# Google OAuth functions
def get_google_oauth_url(state: str = None) -> str:
    """
    Generate Google OAuth authorization URL
    """
    if not state:
        state = secrets.token_urlsafe(32)

    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "redirect_uri": GOOGLE_REDIRECT_URI,
        "scope": "openid email profile",
        "response_type": "code",
        "state": state,
        "access_type": "offline",
        "prompt": "consent"
    }

    query_string = "&".join([f"{k}={v}" for k, v in params.items()])
    return f"https://accounts.google.com/o/oauth2/v2/auth?{query_string}"

async def exchange_google_code_for_token(code: str) -> Dict[str, Any]:
    """
    Exchange Google authorization code for access token
    """
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": GOOGLE_REDIRECT_URI
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )

    if response.status_code != 200:
        raise Exception("Failed to exchange code for token")

    return response.json()

async def get_google_user_info(access_token: str) -> Dict[str, Any]:
    """
    Get user information from Google API
    """
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={
                "Authorization": f"Bearer {access_token}"
            }
        )

    if response.status_code != 200:
        raise Exception("Failed to get user info from Google")

    return response.json()

async def authenticate_or_create_google_user(google_user_data: Dict[str, Any], access_token: str) -> UserInDB:
    """
    Authenticate existing user or create new user from Google data
    """
    db = get_database()

    # Try to find existing user by Google ID
    existing_user = await db.users.find_one({"google_id": google_user_data["id"]})

    if existing_user:
        # Update access token
        await db.users.update_one(
            {"_id": existing_user["_id"]},
            {"$set": {"google_access_token": access_token, "updated_at": datetime.now(timezone.utc)}}
        )
        return UserInDB(**existing_user)

    # Try to find by email
    existing_user = await db.users.find_one({"email": google_user_data.get("email")})

    if existing_user:
        # Link Google account
        await db.users.update_one(
            {"_id": existing_user["_id"]},
            {"$set": {
                "google_id": google_user_data["id"],
                "google_access_token": access_token,
                "updated_at": datetime.now(timezone.utc)
            }}
        )
        return UserInDB(**existing_user)

    # Create new user
    username = google_user_data.get("email", "").split("@")[0]
    # Ensure username is unique
    counter = 1
    original_username = username
    while await db.users.find_one({"username": username}):
        username = f"{original_username}_{counter}"
        counter += 1

    user_dict = {
        "username": username,
        "email": google_user_data.get("email", ""),
        "full_name": google_user_data.get("name", ""),
        "google_id": google_user_data["id"],
        "google_access_token": access_token,
        "role": "user",
        "disabled": False,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    }

    result = await db.users.insert_one(user_dict)
    created_user = await db.users.find_one({"_id": result.inserted_id})
    return UserInDB(**created_user)

# Role-based access control functions
def check_user_role(user: UserInDB, required_role: str) -> bool:
    """
    Check if user has required role
    """
    role_hierarchy = {
        "user": 1,
        "manager": 2,
        "admin": 3
    }

    user_level = role_hierarchy.get(user.role, 0)
    required_level = role_hierarchy.get(required_role, 999)

    return user_level >= required_level

def require_role(required_role: str):
    """
    Decorator to require specific role for endpoint access
    """
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # This would be used in FastAPI dependencies
            # Implementation depends on how it's integrated with FastAPI
            return await func(*args, **kwargs)
        return wrapper
    return decorator
