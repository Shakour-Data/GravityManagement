from typing import List, Optional, Dict, Any
from datetime import datetime
from passlib.context import CryptContext
from ..database import get_database
from ..models.user import User, UserCreate, UserUpdate, UserInDB
from ..services.auth_service import get_password_hash
from .exceptions import (
    ValidationError, AuthorizationError, NotFoundError, ConflictError,
    BusinessLogicError, raise_validation_error, raise_authorization_error,
    raise_not_found_error, raise_conflict_error, raise_business_logic_error
)

class UserService:
    def __init__(self):
        self.db = get_database()
        self.pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    async def create_user(self, user_data: UserCreate) -> User:
        """
        Create a new user with validation and business logic
        """
        # Validate user data
        await self._validate_user_data(user_data)

        # Check if user already exists
        existing_user = await self.db.users.find_one({
            "$or": [
                {"username": user_data.username},
                {"email": user_data.email}
            ]
        })
        if existing_user:
            raise_conflict_error("Username or email already exists", "user")

        # Hash password
        hashed_password = get_password_hash(user_data.password)

        # Create user document
        user_dict = user_data.dict()
        user_dict["hashed_password"] = hashed_password
        user_dict["role"] = "user"  # Default role
        user_dict["disabled"] = False
        user_dict["created_at"] = datetime.utcnow()
        user_dict["updated_at"] = datetime.utcnow()
        del user_dict["password"]  # Remove plain password

        result = await self.db.users.insert_one(user_dict)
        created_user = await self.db.users.find_one({"_id": result.inserted_id})

        return User(**created_user)

    async def get_user(self, username: str, current_user: User = None) -> User:
        """
        Get a user by username with access control
        """
        user = await self.db.users.find_one({"username": username})
        if not user:
            raise_not_found_error("User", username)

        # Users can only see their own profile or admins can see all
        if current_user and current_user.username != username and current_user.role != "admin":
            raise_authorization_error("Not authorized to view this user")

        return User(**user)

    async def get_user_by_email(self, email: str) -> Optional[User]:
        """
        Get a user by email (used for password reset, etc.)
        """
        user = await self.db.users.find_one({"email": email})
        if user:
            return User(**user)
        return None

    async def update_user(self, username: str, update_data: UserUpdate, current_user: User) -> User:
        """
        Update a user with validation and business logic
        """
        # Check permissions
        if current_user.username != username and current_user.role != "admin":
            raise_authorization_error("Not authorized to update this user")

        # Get existing user
        existing_user = await self.get_user(username, current_user)

        # Validate update data
        await self._validate_user_update(update_data, existing_user, current_user)

        # Prepare update document
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()

        await self.db.users.update_one({"username": username}, {"$set": update_dict})

        # Get updated user
        updated_user = await self.db.users.find_one({"username": username})
        return User(**updated_user)

    async def change_password(self, username: str, old_password: str, new_password: str, current_user: User) -> bool:
        """
        Change user password with validation
        """
        # Check permissions
        if current_user.username != username and current_user.role != "admin":
            raise_authorization_error("Not authorized to change this password")

        # Get user with password
        user = await self.db.users.find_one({"username": username})
        if not user:
            raise_not_found_error("User", username)

        # Verify old password (unless admin is changing)
        if current_user.username == username:
            if not self.pwd_context.verify(old_password, user["hashed_password"]):
                raise_validation_error("Incorrect old password", "old_password")

        # Validate new password
        await self._validate_password(new_password)

        # Hash new password
        hashed_password = get_password_hash(new_password)

        # Update password
        await self.db.users.update_one(
            {"username": username},
            {
                "$set": {
                    "hashed_password": hashed_password,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        return True

    async def disable_user(self, username: str, current_user: User) -> User:
        """
        Disable a user account (admin only)
        """
        if current_user.role != "admin":
            raise_authorization_error("Admin access required")

        if username == current_user.username:
            raise_business_logic_error("Cannot disable your own account", "self_disable")

        await self.db.users.update_one(
            {"username": username},
            {
                "$set": {
                    "disabled": True,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        updated_user = await self.db.users.find_one({"username": username})
        return User(**updated_user)

    async def enable_user(self, username: str, current_user: User) -> User:
        """
        Enable a user account (admin only)
        """
        if current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Admin access required")

        await self.db.users.update_one(
            {"username": username},
            {
                "$set": {
                    "disabled": False,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        updated_user = await self.db.users.find_one({"username": username})
        return User(**updated_user)

    async def get_users(self, current_user: User, skip: int = 0, limit: int = 100) -> List[User]:
        """
        Get list of users (admin only)
        """
        if current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Admin access required")

        users = await self.db.users.find({}).skip(skip).limit(limit).to_list(length=None)
        return [User(**user) for user in users]

    async def get_user_stats(self, username: str, current_user: User) -> Dict[str, Any]:
        """
        Get user statistics
        """
        user = await self.get_user(username, current_user)

        # Count user's projects
        owned_projects = await self.db.projects.count_documents({"owner_id": username})
        member_projects = await self.db.projects.count_documents({"team_members": username})

        # Count user's tasks
        total_tasks = await self.db.tasks.count_documents({"assignee_id": username})
        completed_tasks = await self.db.tasks.count_documents({
            "assignee_id": username,
            "status": "done"
        })

        # Count overdue tasks
        overdue_tasks = await self.db.tasks.count_documents({
            "assignee_id": username,
            "due_date": {"$lt": datetime.utcnow()},
            "status": {"$ne": "done"}
        })

        return {
            "username": username,
            "owned_projects": owned_projects,
            "member_projects": member_projects,
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "overdue_tasks": overdue_tasks,
            "completion_rate": round((completed_tasks / total_tasks * 100) if total_tasks > 0 else 0, 2)
        }

    async def _validate_user_data(self, user_data: UserCreate):
        """
        Validate user creation data
        """
        if not user_data.username or len(user_data.username.strip()) < 3:
            raise_validation_error("Username must be at least 3 characters", "username")

        if not user_data.email or "@" not in user_data.email:
            raise_validation_error("Invalid email format", "email")

        await self._validate_password(user_data.password)

        if user_data.full_name and len(user_data.full_name.strip()) < 2:
            raise_validation_error("Full name must be at least 2 characters", "full_name")

    async def _validate_user_update(self, update_data: UserUpdate, existing_user: User, current_user: User):
        """
        Validate user update data
        """
        if update_data.username and len(update_data.username.strip()) < 3:
            raise_validation_error("Username must be at least 3 characters", "username")

        if update_data.email:
            if "@" not in update_data.email:
                raise_validation_error("Invalid email format", "email")

            # Check email uniqueness
            duplicate = await self.db.users.find_one({
                "email": update_data.email,
                "username": {"$ne": existing_user.username}
            })
            if duplicate:
                raise_conflict_error("Email already exists", "email")

        if update_data.full_name and len(update_data.full_name.strip()) < 2:
            raise_validation_error("Full name must be at least 2 characters", "full_name")

        # Only admins can change roles
        if update_data.role and current_user.role != "admin":
            raise_authorization_error("Admin access required to change roles")

    async def _validate_password(self, password: str):
        """
        Validate password strength
        """
        if not password or len(password) < 8:
            raise_validation_error("Password must be at least 8 characters", "password")

        # Check for at least one uppercase, one lowercase, one digit
        has_upper = any(c.isupper() for c in password)
        has_lower = any(c.islower() for c in password)
        has_digit = any(c.isdigit() for c in password)

        if not (has_upper and has_lower and has_digit):
            raise_validation_error(
                "Password must contain at least one uppercase letter, one lowercase letter, and one digit",
                "password"
            )

# Global user service instance
user_service = UserService()
