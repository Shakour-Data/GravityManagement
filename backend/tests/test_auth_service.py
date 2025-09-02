import pytest
import asyncio
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from jose import jwt, JWTError

# Import the auth service functions
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.auth_service import (
    verify_password,
    get_password_hash,
    authenticate_user,
    create_access_token,
    SECRET_KEY,
    ALGORITHM
)
from app.models.user import UserInDB

class TestPasswordFunctions:
    """Test password hashing and verification functions"""

    def test_get_password_hash(self):
        """Test password hashing"""
        password = "testpassword123"
        hashed = get_password_hash(password)

        # Hash should be different from plain password
        assert hashed != password
        # Hash should be a string
        assert isinstance(hashed, str)
        # Hash should not be empty
        assert len(hashed) > 0

    def test_verify_password_correct(self):
        """Test password verification with correct password"""
        password = "testpassword123"
        hashed = get_password_hash(password)

        assert verify_password(password, hashed) is True

    def test_verify_password_incorrect(self):
        """Test password verification with incorrect password"""
        password = "testpassword123"
        wrong_password = "wrongpassword123"
        hashed = get_password_hash(password)

        assert verify_password(wrong_password, hashed) is False

    def test_verify_password_empty(self):
        """Test password verification with empty password"""
        password = "testpassword123"
        hashed = get_password_hash(password)

        assert verify_password("", hashed) is False

    def test_verify_password_invalid_hash(self):
        """Test password verification with invalid hash"""
        password = "testpassword123"

        assert verify_password(password, "invalid_hash") is False

class TestAuthenticateUser:
    """Test user authentication function"""

    @pytest.fixture
    def mock_db(self):
        """Mock database"""
        return AsyncMock()

    @pytest.fixture
    def sample_user_data(self):
        """Sample user data for testing"""
        password = "testpassword123"
        return {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "hashed_password": get_password_hash(password),
            "disabled": False,
            "role": "user"
        }

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_success(self, mock_get_database, mock_db, sample_user_data):
        """Test successful user authentication"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.return_value = sample_user_data

        result = await authenticate_user("testuser", "testpassword123")

        assert result is not False
        assert isinstance(result, UserInDB)
        assert result.username == "testuser"
        assert result.email == "test@example.com"
        mock_db.users.find_one.assert_called_once_with({"username": "testuser"})

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_not_found(self, mock_get_database, mock_db):
        """Test authentication with non-existent user"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.return_value = None

        result = await authenticate_user("nonexistent", "password")

        assert result is False
        mock_db.users.find_one.assert_called_once_with({"username": "nonexistent"})

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_wrong_password(self, mock_get_database, mock_db, sample_user_data):
        """Test authentication with wrong password"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.return_value = sample_user_data

        result = await authenticate_user("testuser", "wrongpassword")

        assert result is False
        mock_db.users.find_one.assert_called_once_with({"username": "testuser"})

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_database_error(self, mock_get_database, mock_db):
        """Test authentication with database error"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.side_effect = Exception("Database error")

        with pytest.raises(Exception):
            await authenticate_user("testuser", "password")

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_not_found(self, mock_get_database, mock_db):
        """Test authentication with non-existent user"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.return_value = None

        result = await authenticate_user("nonexistent", "password")

        assert result is False
        mock_db.users.find_one.assert_called_once_with({"username": "nonexistent"})

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_wrong_password(self, mock_get_database, mock_db, sample_user_data):
        """Test authentication with wrong password"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.return_value = sample_user_data

        result = await authenticate_user("testuser", "wrongpassword")

        assert result is False
        mock_db.users.find_one.assert_called_once_with({"username": "testuser"})

    @patch('app.services.auth_service.get_database')
    async def test_authenticate_user_database_error(self, mock_get_database, mock_db):
        """Test authentication with database error"""
        mock_get_database.return_value = mock_db
        mock_db.users.find_one.side_effect = Exception("Database error")

        with pytest.raises(Exception):
            await authenticate_user("testuser", "password")

class TestCreateAccessToken:
    """Test JWT token creation function"""

    def test_create_access_token_default_expiry(self):
        """Test token creation with default expiry"""
        data = {"sub": "testuser", "role": "user"}

        token = create_access_token(data)

        # Token should be a string
        assert isinstance(token, str)
        assert len(token) > 0

        # Decode token to verify contents
        decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert decoded["sub"] == "testuser"
        assert decoded["role"] == "user"
        assert "exp" in decoded

        # Check expiry is approximately 15 minutes from now
        expected_exp = datetime.utcnow() + timedelta(minutes=15)
        actual_exp = datetime.utcfromtimestamp(decoded["exp"])
        time_diff = abs((actual_exp - expected_exp).total_seconds())
        assert time_diff < 10  # Within 10 seconds

    def test_create_access_token_custom_expiry(self):
        """Test token creation with custom expiry"""
        data = {"sub": "testuser"}
        expires_delta = timedelta(hours=1)

        token = create_access_token(data, expires_delta)

        decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert decoded["sub"] == "testuser"

        # Check expiry is approximately 1 hour from now
        expected_exp = datetime.utcnow() + timedelta(hours=1)
        actual_exp = datetime.utcfromtimestamp(decoded["exp"])
        time_diff = abs((actual_exp - expected_exp).total_seconds())
        assert time_diff < 10  # Within 10 seconds

    def test_create_access_token_empty_data(self):
        """Test token creation with empty data"""
        data = {}

        token = create_access_token(data)

        decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert decoded == {"exp": decoded["exp"]}  # Only exp field should be present

    def test_create_access_token_with_special_characters(self):
        """Test token creation with special characters in data"""
        data = {
            "sub": "test@user.com",
            "name": "Test User",
            "role": "admin",
            "permissions": ["read", "write", "delete"]
        }

        token = create_access_token(data)

        decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert decoded["sub"] == "test@user.com"
        assert decoded["name"] == "Test User"
        assert decoded["role"] == "admin"
        assert decoded["permissions"] == ["read", "write", "delete"]

    def test_token_expiry_verification(self):
        """Test that expired tokens are properly handled"""
        data = {"sub": "testuser"}
        # Create token that expires in 1 second
        expires_delta = timedelta(seconds=1)

        token = create_access_token(data, expires_delta)

        # Token should be valid immediately
        decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert decoded["sub"] == "testuser"

        # Wait for token to expire
        import time
        time.sleep(2)

        # Token should now be expired
        with pytest.raises(JWTError):
            jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

    def test_token_with_wrong_secret(self):
        """Test token verification with wrong secret"""
        data = {"sub": "testuser"}

        token = create_access_token(data)

        # Should fail with wrong secret
        with pytest.raises(JWTError):
            jwt.decode(token, "wrong_secret", algorithms=[ALGORITHM])

    def test_token_with_wrong_algorithm(self):
        """Test token verification with wrong algorithm"""
        data = {"sub": "testuser"}

        token = create_access_token(data)

        # Should fail with wrong algorithm
        with pytest.raises(JWTError):
            jwt.decode(token, SECRET_KEY, algorithms=["HS512"])
