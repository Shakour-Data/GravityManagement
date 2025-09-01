import pytest
import asyncio
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.services.user_service import UserService
from backend.app.models.user import User
from backend.app.services.exceptions import NotFoundError, AuthenticationError

@pytest.mark.asyncio
class TestUserService:
    @pytest.fixture
    async def user_service(self):
        service = UserService()
        service.db = AsyncMock()
        return service

    async def test_create_user(self, user_service):
        from backend.app.models.user import UserCreate
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="Password123"
        )

        from datetime import datetime
        # Mock the database operations
        user_service.db.users.find_one = AsyncMock(return_value=None)
        user_service.db.users.insert_one = AsyncMock(return_value=MagicMock(inserted_id="user123"))
        user_service.db.users.find_one = AsyncMock(return_value={
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "role": "user",
            "disabled": False,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await user_service.create_user(user_data)
        assert result.username == "testuser"
        assert result.email == "test@example.com"

    async def test_get_user(self, user_service):
        from backend.app.models.user import User
        current_user = User(username="testuser")
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "role": "user",
            "disabled": False,
            "created_at": None,
            "updated_at": None
        }
        user_service.db.users.find_one = AsyncMock(return_value=mock_user)

        result = await user_service.get_user("testuser", current_user)
        assert result.username == "testuser"
        assert result.email == "test@example.com"

    async def test_get_user_not_found(self, user_service):
        from backend.app.models.user import User
        current_user = User(username="testuser")
        user_service.db.users.find_one = AsyncMock(return_value=None)

        with pytest.raises(NotFoundError):
            await user_service.get_user("nonexistent", current_user)

    async def test_get_user_by_email(self, user_service):
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "role": "user",
            "disabled": False,
            "created_at": None,
            "updated_at": None
        }
        user_service.db.users.find_one = AsyncMock(return_value=mock_user)

        result = await user_service.get_user_by_email("test@example.com")
        assert result.username == "testuser"
        assert result.email == "test@example.com"

    async def test_get_user_by_email_not_found(self, user_service):
        user_service.db.users.find_one = AsyncMock(return_value=None)

        result = await user_service.get_user_by_email("nonexistent@example.com")
        assert result is None

    async def test_update_user(self, user_service):
        from backend.app.models.user import User, UserUpdate
        current_user = User(username="testuser")
        update_data = UserUpdate(email="newemail@example.com")
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "role": "user",
            "disabled": False,
            "created_at": None,
            "updated_at": None
        }
        user_service.db.users.find_one = AsyncMock(return_value=mock_user)
        user_service.db.users.update_one = AsyncMock()

        result = await user_service.update_user("testuser", update_data, current_user)
        assert result.email == "newemail@example.com"

    async def test_disable_user(self, user_service):
        from backend.app.models.user import User
        current_user = User(username="admin", email="admin@example.com", role="admin")
        from datetime import datetime
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "role": "user",
            "disabled": False,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        user_service.db.users.find_one = AsyncMock(return_value=mock_user)
        user_service.db.users.update_one = AsyncMock()

        result = await user_service.disable_user("testuser", current_user)
        assert result.disabled == True
