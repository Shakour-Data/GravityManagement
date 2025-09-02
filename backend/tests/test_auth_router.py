import pytest
import sys
import os
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient
from fastapi import HTTPException
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app")))

from backend.app.main import app
from backend.app.database import get_database
from backend.app.models.user import UserCreate


class TestAuthRouter:
    @pytest.fixture
    def mock_db(self):
        """Mock database for testing"""
        return AsyncMock()

    @pytest.fixture
    def client(self, mock_db):
        """Create a test client with mocked database"""
        with patch('backend.app.routers.auth.get_database', return_value=mock_db):
            with patch('backend.app.services.auth_service.get_database', return_value=mock_db):
                client = TestClient(app)
                yield client

    def test_register_user_success(self, client, mock_db):
        """Test successful user registration"""
        # Mock database responses
        mock_db.users.find_one = AsyncMock(return_value=None)
        mock_db.users.insert_one = AsyncMock()
        mock_db.users.insert_one.return_value = MagicMock(inserted_id="user123")

        mock_user_doc = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "hashed_password": "hashed_password",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "disabled": False
        }
        mock_db.users.find_one = AsyncMock(side_effect=[None, mock_user_doc])

        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "password": "testpassword123"
        }

        response = client.post("/auth/register", json=user_data)

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
        assert data["full_name"] == "Test User"
        assert "hashed_password" not in data  # Should not return password

    def test_register_user_duplicate_username(self, client, mock_db):
        """Test registration with duplicate username"""
        existing_user = {
            "_id": "existing123",
            "username": "testuser",
            "email": "other@example.com"
        }

        mock_db.users.find_one = AsyncMock(return_value=existing_user)

        user_data = {
            "username": "testuser",
            "email": "new@example.com",
            "full_name": "Test User",
            "password": "testpassword123"
        }

        response = client.post("/auth/register", json=user_data)

        assert response.status_code == 400
        data = response.json()
        assert "Username or email already registered" in data["detail"]

    def test_register_user_duplicate_email(self, client, mock_db):
        """Test registration with duplicate email"""
        existing_user = {
            "_id": "existing123",
            "username": "otheruser",
            "email": "test@example.com"
        }

        mock_db.users.find_one = AsyncMock(return_value=existing_user)

        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "password": "testpassword123"
        }

        response = client.post("/auth/register", json=user_data)

        assert response.status_code == 400
        data = response.json()
        assert "Username or email already registered" in data["detail"]

    def test_login_success(self, client, mock_db):
        """Test successful login"""
        # Mock user data
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "hashed_password": "$2b$12$DWTkm6a6U8.bCrYARCfkPOx1hcMWtruEteEarTqi2BJWEZM5trTtC",  # bcrypt hash for "password"
            "full_name": "Test User",
            "disabled": False
        }

        mock_db.users.find_one = AsyncMock(return_value=mock_user)

        login_data = {
            "username": "testuser",
            "password": "password"
        }

        response = client.post("/auth/token", data=login_data)

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert isinstance(data["access_token"], str)

    def test_login_invalid_credentials(self, client, mock_db):
        """Test login with invalid credentials"""
        mock_db.users.find_one = AsyncMock(return_value=None)

        login_data = {
            "username": "nonexistent",
            "password": "wrongpassword"
        }

        response = client.post("/auth/token", data=login_data)

        assert response.status_code == 401
        data = response.json()
        assert "Incorrect username or password" in data["detail"]

    def test_get_current_user_success(self, client, mock_db):
        """Test getting current user information"""
        # Mock user data
        mock_user = {
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "hashed_password": "hashed_password",
            "disabled": False,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.users.find_one = AsyncMock(return_value=mock_user)

        # First get a token
        login_data = {
            "username": "testuser",
            "password": "password"
        }

        # Mock successful authentication for token generation
        mock_db.users.find_one = AsyncMock(return_value={
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "hashed_password": "$2b$12$DWTkm6a6U8.bCrYARCfkPOx1hcMWtruEteEarTqi2BJWEZM5trTtC",
            "full_name": "Test User",
            "disabled": False
        })

        token_response = client.post("/auth/token", data=login_data)
        token = token_response.json()["access_token"]

        # Now test the protected endpoint
        headers = {"Authorization": f"Bearer {token}"}
        response = client.get("/auth/me", headers=headers)

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
        assert data["full_name"] == "Test User"

    def test_get_current_user_invalid_token(self, client, mock_db):
        """Test accessing protected endpoint with invalid token"""
        headers = {"Authorization": "Bearer invalid_token"}
        response = client.get("/auth/me", headers=headers)

        assert response.status_code == 401
        data = response.json()
        assert "Could not validate credentials" in data["detail"]

    def test_get_current_user_no_token(self, client, mock_db):
        """Test accessing protected endpoint without token"""
        response = client.get("/auth/me")

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_register_user_missing_fields(self, client, mock_db):
        """Test registration with missing required fields"""
        incomplete_data = {
            "username": "testuser",
            "email": "test@example.com"
            # Missing password and full_name
        }

        response = client.post("/auth/register", json=incomplete_data)

        assert response.status_code == 422  # Validation error

    def test_register_user_invalid_email(self, client, mock_db):
        """Test registration with invalid email format"""
        invalid_data = {
            "username": "testuser",
            "email": "invalid-email",
            "full_name": "Test User",
            "password": "testpassword123"
        }

        response = client.post("/auth/register", json=invalid_data)

        assert response.status_code == 422  # Validation error

    def test_login_missing_credentials(self, client, mock_db):
        """Test login with missing credentials"""
        incomplete_data = {
            "username": "testuser"
            # Missing password
        }

        response = client.post("/auth/token", data=incomplete_data)

        assert response.status_code == 422  # Validation error
