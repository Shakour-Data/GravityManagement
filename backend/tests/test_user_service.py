import pytest
import sys
import os
from unittest.mock import AsyncMock, patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.user_service import UserService
from app.models.user import UserCreate, UserUpdate, User
from app.services.exceptions import (
    ValidationError, AuthorizationError, NotFoundError, ConflictError, BusinessLogicError
)

@pytest.mark.asyncio
class TestUserService:
    @pytest.fixture
    def user_service(self):
        return UserService()

    @pytest.fixture
    def user_create_data(self):
        return UserCreate(
            username="testuser",
            email="testuser@example.com",
            password="Password123",
            full_name="Test User"
        )

    @pytest.fixture
    def user_update_data(self):
        return UserUpdate(
            username="testuser",
            email="newemail@example.com",
            full_name="New Name"
        )

    @pytest.mark.asyncio
    async def test_create_user_success(self, user_service, user_create_data):
        # Mock db calls
        user_service.db = MagicMock()
        user_service.db.users.find_one = AsyncMock(side_effect=[
            None,  # First call for checking existing user
            {      # Second call for getting created user
                "_id": "123",
                "username": user_create_data.username,
                "email": user_create_data.email,
                "hashed_password": "hashedpassword",
                "role": "user",
                "disabled": False,
                "created_at": "2023-01-01T00:00:00",
                "updated_at": "2023-01-01T00:00:00"
            }
        ])
        user_service.db.users.insert_one = AsyncMock(return_value=MagicMock(inserted_id="123"))

        created_user = await user_service.create_user(user_create_data)
        assert created_user.username == user_create_data.username
        assert created_user.email == user_create_data.email

    @pytest.mark.asyncio
    async def test_create_user_conflict(self, user_service, user_create_data):
        user_service.db = MagicMock()
        user_service.db.users.find_one = AsyncMock(return_value={"username": "testuser"})

        with pytest.raises(ConflictError):
            await user_service.create_user(user_create_data)

    @pytest.mark.asyncio
    async def test_get_user_not_found(self, user_service):
        user_service.db = MagicMock()
        user_service.db.users.find_one = AsyncMock(return_value=None)

        with pytest.raises(NotFoundError):
            await user_service.get_user("nonexistent")

    @pytest.mark.asyncio
    async def test_get_user_authorization_error(self, user_service):
        user_service.db = MagicMock()
        user_service.db.users.find_one = AsyncMock(return_value={
            "username": "otheruser",
            "email": "other@example.com",
            "role": "user"
        })

        current_user = User(username="testuser", email="test@example.com", role="user")
        with pytest.raises(AuthorizationError):
            await user_service.get_user("otheruser", current_user)

    @pytest.mark.asyncio
    async def test_update_user_success(self, user_service, user_update_data):
        user_service.db = MagicMock()
        existing_user = User(username="testuser", email="old@example.com", role="user")
        current_user = User(username="testuser", email="test@example.com", role="admin")
        user_service.get_user = AsyncMock(return_value=existing_user)
        user_service.db.users.find_one = AsyncMock(side_effect=[
            None,  # First call for checking duplicate email
            {      # Second call for getting updated user
                "username": "testuser",
                "email": user_update_data.email,
                "full_name": user_update_data.full_name
            }
        ])
        user_service.db.users.update_one = AsyncMock()

        updated_user = await user_service.update_user("testuser", user_update_data, current_user)
        assert updated_user.email == user_update_data.email
        assert updated_user.full_name == user_update_data.full_name

    @pytest.mark.asyncio
    async def test_change_password_success(self, user_service):
        user_service.db = MagicMock()
        user_service.pwd_context.verify = MagicMock(return_value=True)
        user_service.db.users.find_one = AsyncMock(return_value={
            "username": "testuser",
            "email": "test@example.com",
            "hashed_password": "hashedpassword"
        })
        user_service.db.users.update_one = AsyncMock()
        current_user = User(username="testuser", email="test@example.com", role="user")

        result = await user_service.change_password("testuser", "oldpass", "Newpass123", current_user)
        assert result is True

    @pytest.mark.asyncio
    async def test_disable_user_admin_only(self, user_service):
        user_service.db = MagicMock()
        user_service.db.users.update_one = AsyncMock()
        user_service.db.users.find_one = AsyncMock(return_value={
            "username": "testuser",
            "email": "test@example.com",
            "disabled": True
        })
        current_user = User(username="adminuser", email="admin@example.com", role="admin")

        updated_user = await user_service.disable_user("testuser", current_user)
        assert updated_user.disabled is True

    @pytest.mark.asyncio
    async def test_disable_user_self_disable_error(self, user_service):
        current_user = User(username="testuser", email="test@example.com", role="admin")
        with pytest.raises(BusinessLogicError):
            await user_service.disable_user("testuser", current_user)

    @pytest.mark.asyncio
    async def test_get_users_admin_only(self, user_service):
        user_service.db = MagicMock()
        user_service.db.users = MagicMock()

        # Create a mock cursor that supports the chain
        mock_cursor = MagicMock()
        mock_cursor.skip.return_value = mock_cursor
        mock_cursor.limit.return_value = mock_cursor
        mock_cursor.to_list = AsyncMock(return_value=[
            {"username": "user1", "email": "user1@example.com"},
            {"username": "user2", "email": "user2@example.com"}
        ])

        user_service.db.users.find = MagicMock(return_value=mock_cursor)
        current_user = User(username="adminuser", email="admin@example.com", role="admin")

        users = await user_service.get_users(current_user)
        assert len(users) == 2

    @pytest.mark.asyncio
    async def test_get_users_not_admin(self, user_service):
        from fastapi import HTTPException
        current_user = User(username="testuser", email="test@example.com", role="user")
        with pytest.raises(HTTPException):
            await user_service.get_users(current_user)
