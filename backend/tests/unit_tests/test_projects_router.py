import pytest
import sys
import os
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient
from fastapi import HTTPException
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app")))

from app.main import app
from app.database import get_database
from app.models.project import ProjectCreate, ProjectUpdate
from app.models.user import User


class TestProjectsRouter:
    @pytest.fixture
    def mock_db(self):
        """Mock database for testing"""
        return AsyncMock()

    @pytest.fixture
    def mock_project_service(self):
        """Mock project service for testing"""
        return AsyncMock()

    @pytest.fixture
    def client(self, mock_db, mock_project_service):
        """Create a test client with mocked database and services"""
        with patch('app.routers.projects.get_database', return_value=mock_db):
            with patch('app.routers.projects.project_service', mock_project_service):
                with patch('app.services.project_service.project_service', mock_project_service):
                    client = TestClient(app)
                    yield client

    @pytest.fixture
    def mock_user(self):
        """Mock user for testing"""
        return User(
            id="user123",
            username="testuser",
            email="test@example.com",
            full_name="Test User",
            disabled=False,
            role="user",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

    def test_create_project_success(self, client, mock_db, mock_user):
        """Test successful project creation"""
        # Mock database responses
        mock_db.projects.insert_one = AsyncMock()
        mock_db.projects.insert_one.return_value = MagicMock(inserted_id="project123")

        mock_project_doc = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        mock_db.projects.find_one = AsyncMock(return_value=mock_project_doc)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            project_data = {
                "name": "Test Project",
                "description": "A test project",
                "budget": 10000.0,
                "github_repo": None
            }

            response = client.post("/projects/", json=project_data)

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Test Project"
            assert data["description"] == "A test project"
            assert data["owner_id"] == "testuser"
            assert data["team_members"] == ["testuser"]

    def test_get_projects_success(self, client, mock_db, mock_user):
        """Test getting user's projects"""
        mock_projects = [
            {
                "_id": "project123",
                "name": "Test Project 1",
                "description": "First test project",
                "owner_id": "testuser",
                "team_members": ["testuser"],
                "budget": 10000.0,
                "spent_amount": 0.0,
                "status": "active",
                "github_repo": None,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            },
            {
                "_id": "project456",
                "name": "Test Project 2",
                "description": "Second test project",
                "owner_id": "testuser",
                "team_members": ["testuser"],
                "budget": 20000.0,
                "spent_amount": 5000.0,
                "status": "active",
                "github_repo": None,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        ]

        mock_db.projects.find = AsyncMock()
        mock_db.projects.find.return_value.to_list = AsyncMock(return_value=mock_projects)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/projects/")

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
            assert data[0]["name"] == "Test Project 1"
            assert data[1]["name"] == "Test Project 2"

    def test_get_project_success(self, client, mock_db, mock_user):
        """Test getting a specific project"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/projects/project123")

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Test Project"
            assert data["_id"] == "project123"

    def test_get_project_not_found(self, client, mock_db, mock_user):
        """Test getting a non-existent project"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/projects/nonexistent")

            assert response.status_code == 404
            data = response.json()
            assert "Project not found" in data["detail"]

    def test_update_project_success(self, client, mock_db, mock_user):
        """Test successful project update"""
        # Mock existing project
        mock_existing_project = {
            "_id": "project123",
            "name": "Old Project",
            "description": "Old description",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 5000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        # Mock updated project
        mock_updated_project = {
            "_id": "project123",
            "name": "Updated Project",
            "description": "Updated description",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 15000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.projects.find_one = AsyncMock(side_effect=[mock_existing_project, mock_updated_project])
        mock_db.projects.update_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "name": "Updated Project",
                "description": "Updated description",
                "budget": 15000.0
            }

            response = client.put("/projects/project123", json=update_data)

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Updated Project"
            assert data["budget"] == 15000.0

    def test_update_project_not_authorized(self, client, mock_db, mock_user):
        """Test updating a project without authorization"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "name": "Updated Project",
                "description": "Updated description"
            }

            response = client.put("/projects/project123", json=update_data)

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_delete_project_success(self, client, mock_db, mock_user):
        """Test successful project deletion"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.projects.delete_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/projects/project123")

            assert response.status_code == 200
            data = response.json()
            assert "Project deleted successfully" in data["message"]

    def test_delete_project_not_authorized(self, client, mock_db, mock_user):
        """Test deleting a project without authorization"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/projects/project123")

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_update_spent_amount_success(self, client, mock_db, mock_user, mock_project_service):
        """Test updating spent amount successfully"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_updated_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 2500.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_project_service.update_spent_amount = AsyncMock(return_value=mock_updated_project)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.post("/projects/project123/budget/spend", json=2500.0)

            assert response.status_code == 200
            data = response.json()
            assert "Spent amount updated" in data["message"]
            assert data["project"]["spent_amount"] == 2500.0

    def test_update_spent_amount_invalid_value(self, client, mock_db, mock_user, mock_project_service):
        """Test updating spent amount with invalid value"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 0.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_project_service.update_spent_amount = AsyncMock(side_effect=ValueError("Invalid amount"))

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.post("/projects/project123/budget/spend", json=-100.0)

            assert response.status_code == 400
            data = response.json()
            assert "Invalid amount" in data["detail"]

    def test_get_budget_report_success(self, client, mock_db, mock_user, mock_project_service):
        """Test getting budget report successfully"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 2500.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_report = {
            "project_id": "project123",
            "budget": 10000.0,
            "spent_amount": 2500.0,
            "remaining_budget": 7500.0,
            "budget_utilization": 25.0
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_project_service.get_budget_report = AsyncMock(return_value=mock_report)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/projects/project123/budget/report")

            assert response.status_code == 200
            data = response.json()
            assert data["budget"] == 10000.0
            assert data["spent_amount"] == 2500.0
            assert data["remaining_budget"] == 7500.0
            assert data["budget_utilization"] == 25.0

    def test_check_budget_alert_success(self, client, mock_db, mock_user, mock_project_service):
        """Test checking budget alert successfully"""
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "testuser",
            "team_members": ["testuser"],
            "budget": 10000.0,
            "spent_amount": 9500.0,
            "status": "active",
            "github_repo": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_alert = {
            "alert": True,
            "message": "Budget utilization is 95.0%. Consider reviewing expenses.",
            "budget_utilization": 95.0
        }

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_project_service.check_budget_alert = AsyncMock(return_value=mock_alert)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/projects/project123/budget/alert")

            assert response.status_code == 200
            data = response.json()
            assert data["alert"] == True
            assert "95.0%" in data["message"]

    def test_create_project_unauthenticated(self, client):
        """Test creating project without authentication"""
        project_data = {
            "name": "Test Project",
            "description": "A test project",
            "budget": 10000.0
        }

        response = client.post("/projects/", json=project_data)

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_get_projects_unauthenticated(self, client):
        """Test getting projects without authentication"""
        response = client.get("/projects/")

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]
