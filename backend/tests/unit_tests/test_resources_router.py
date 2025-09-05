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
from app.models.resource import ResourceCreate, ResourceUpdate
from app.models.user import User


class TestResourcesRouter:
    @pytest.fixture
    def mock_db(self):
        """Mock database for testing"""
        return AsyncMock()

    @pytest.fixture
    def client(self, mock_db):
        """Create a test client with mocked database"""
        with patch('app.routers.resources.get_database', return_value=mock_db):
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

    def test_create_resource_success(self, client, mock_db, mock_user):
        """Test successful resource creation"""
        # Mock project access
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "owner_id": "testuser",
            "team_members": ["testuser"]
        }

        # Mock resource creation
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.resources.insert_one = AsyncMock()
        mock_db.resources.insert_one.return_value = MagicMock(inserted_id="resource123")

        mock_resource_doc = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "human",
            "description": "A test resource",
            "project_id": "project123",
            "capacity": 40.0,
            "allocated_hours": 0.0,
            "cost_per_hour": 50.0,
            "availability_start": None,
            "availability_end": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        mock_db.resources.find_one = AsyncMock(return_value=mock_resource_doc)

        # Mock authentication
        with patch('app.routers.resources.get_current_user', return_value=mock_user):
            resource_data = {
                "name": "Test Resource",
                "type": "human",
                "description": "A test resource",
                "project_id": "project123",
                "capacity": 40.0,
                "cost_per_hour": 50.0
            }

            response = client.post("/resources/", json=resource_data)

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Test Resource"
            assert data["project_id"] == "project123"
            assert data["type"] == "human"
            assert data["capacity"] == 40.0

    def test_create_resource_project_not_found(self, client, mock_db, mock_user):
        """Test creating resource for non-existent project"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.resources.get_current_user', return_value=mock_user):
            resource_data = {
                "name": "Test Resource",
                "type": "human",
                "description": "A test resource",
                "project_id": "nonexistent",
                "capacity": 40.0
            }

            response = client.post("/resources/", json=resource_data)

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_get_resources_all_user_projects(self, client, mock_db, mock_user):
        """Test getting all resources from user's projects"""
        # Mock user projects
        mock_projects = [
            {"_id": "project123", "owner_id": "testuser"},
            {"_id": "project456", "team_members": ["testuser"]}
        ]

        # Mock resources
        mock_resources = [
            {
                "_id": "resource123",
                "name": "Resource 1",
                "type": "human",
                "project_id": "project123",
                "capacity": 40.0,
                "allocated_hours": 20.0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            },
            {
                "_id": "resource456",
                "name": "Resource 2",
                "type": "equipment",
                "project_id": "project456",
                "capacity": 100.0,
                "allocated_hours": 0.0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        ]

        mock_db.projects.find = AsyncMock()
        mock_db.projects.find.return_value.to_list = AsyncMock(return_value=mock_projects)
        mock_db.resources.find = AsyncMock()
        mock_db.resources.find.return_value.to_list = AsyncMock(return_value=mock_resources)

        # Mock authentication
        with patch('app.routers.resources.get_current_user', return_value=mock_user):
            response = client.get("/resources/")

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
            assert data[0]["name"] == "Resource 1"
            assert data[1]["name"] == "Resource 2"

    def test_get_resources_specific_project(self, client, mock_db, mock_user):
        """Test getting resources for a specific project"""
        # Mock project access
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "owner_id": "testuser"
        }

        # Mock resources
        mock_resources = [
            {
                "_id": "resource123",
                "name": "Resource 1",
                "type": "human",
                "project_id": "project123",
                "capacity": 40.0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        ]

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.resources.find = AsyncMock()
        mock_db.resources.find.return_value.to_list = AsyncMock(return_value=mock_resources)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/resources/?project_id=project123")

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 1
            assert data[0]["project_id"] == "project123"

    def test_get_resources_project_not_authorized(self, client, mock_db, mock_user):
        """Test getting resources for unauthorized project"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/resources/?project_id=unauthorized")

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_get_resource_success(self, client, mock_db, mock_user):
        """Test getting a specific resource"""
        # Mock resource and project
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "human",
            "description": "A test resource",
            "project_id": "project123",
            "capacity": 40.0,
            "allocated_hours": 20.0,
            "cost_per_hour": 50.0,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        mock_db.resources.find_one = AsyncMock(return_value=mock_resource)
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/resources/resource123")

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Test Resource"
            assert data["_id"] == "resource123"
            assert data["capacity"] == 40.0

    def test_get_resource_not_found(self, client, mock_db, mock_user):
        """Test getting a non-existent resource"""
        mock_db.resources.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/resources/nonexistent")

            assert response.status_code == 404
            data = response.json()
            assert "Resource not found" in data["detail"]

    def test_get_resource_not_authorized(self, client, mock_db, mock_user):
        """Test getting a resource from unauthorized project"""
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "project_id": "project123"
        }

        mock_db.resources.find_one = AsyncMock(return_value=mock_resource)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/resources/resource123")

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_update_resource_success(self, client, mock_db, mock_user):
        """Test successful resource update"""
        # Mock existing resource and project
        mock_resource = {
            "_id": "resource123",
            "name": "Old Resource",
            "type": "human",
            "description": "Old description",
            "project_id": "project123",
            "capacity": 20.0,
            "allocated_hours": 10.0,
            "cost_per_hour": 30.0,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        # Mock updated resource
        mock_updated_resource = {
            "_id": "resource123",
            "name": "Updated Resource",
            "type": "human",
            "description": "Updated description",
            "project_id": "project123",
            "capacity": 40.0,
            "allocated_hours": 10.0,
            "cost_per_hour": 50.0,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.resources.find_one = AsyncMock(side_effect=[mock_resource, mock_updated_resource])
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.resources.update_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "name": "Updated Resource",
                "description": "Updated description",
                "capacity": 40.0,
                "cost_per_hour": 50.0
            }

            response = client.put("/resources/resource123", json=update_data)

            assert response.status_code == 200
            data = response.json()
            assert data["name"] == "Updated Resource"
            assert data["capacity"] == 40.0
            assert data["cost_per_hour"] == 50.0

    def test_update_resource_not_found(self, client, mock_db, mock_user):
        """Test updating a non-existent resource"""
        mock_db.resources.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "name": "Updated Resource",
                "capacity": 40.0
            }

            response = client.put("/resources/nonexistent", json=update_data)

            assert response.status_code == 404
            data = response.json()
            assert "Resource not found" in data["detail"]

    def test_update_resource_not_authorized(self, client, mock_db, mock_user):
        """Test updating a resource from unauthorized project"""
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "project_id": "project123"
        }

        mock_db.resources.find_one = AsyncMock(return_value=mock_resource)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "name": "Updated Resource",
                "capacity": 40.0
            }

            response = client.put("/resources/resource123", json=update_data)

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_delete_resource_success(self, client, mock_db, mock_user):
        """Test successful resource deletion"""
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "project_id": "project123"
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        mock_db.resources.find_one = AsyncMock(return_value=mock_resource)
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.resources.delete_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/resources/resource123")

            assert response.status_code == 200
            data = response.json()
            assert "Resource deleted successfully" in data["message"]

    def test_delete_resource_not_found(self, client, mock_db, mock_user):
        """Test deleting a non-existent resource"""
        mock_db.resources.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/resources/nonexistent")

            assert response.status_code == 404
            data = response.json()
            assert "Resource not found" in data["detail"]

    def test_delete_resource_not_authorized(self, client, mock_db, mock_user):
        """Test deleting a resource from unauthorized project"""
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "project_id": "project123"
        }

        mock_db.resources.find_one = AsyncMock(return_value=mock_resource)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/resources/resource123")

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_create_resource_unauthenticated(self, client):
        """Test creating resource without authentication"""
        resource_data = {
            "name": "Test Resource",
            "type": "human",
            "description": "A test resource",
            "project_id": "project123",
            "capacity": 40.0
        }

        response = client.post("/resources/", json=resource_data)

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_get_resources_unauthenticated(self, client):
        """Test getting resources without authentication"""
        response = client.get("/resources/")

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]
