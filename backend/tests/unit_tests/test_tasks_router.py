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
from app.models.task import TaskCreate, TaskUpdate
from app.models.user import User
from app.services.auth_service import get_password_hash


class TestTasksRouter:
    @pytest.fixture
    def mock_db(self):
        """Mock database for testing"""
        return AsyncMock()

    @pytest.fixture
    def client(self, mock_db):
        """Create a test client with mocked database"""
        with patch('app.routers.tasks.get_database', return_value=mock_db):
            with patch('app.routers.auth.get_database', return_value=mock_db):
                with patch('app.services.auth_service.get_database', return_value=mock_db):
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

    def test_create_task_success(self, client, mock_db, mock_user):
        """Test successful task creation"""
        # Mock project access
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "owner_id": "testuser",
            "team_members": ["testuser"]
        }

        # Mock task creation
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.tasks.insert_one = AsyncMock()
        mock_db.tasks.insert_one.return_value = MagicMock(inserted_id="task123")

        mock_task_doc = {
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "assignee": "testuser",
            "status": "todo",
            "priority": "medium",
            "estimated_hours": 8.0,
            "actual_hours": 0.0,
            "due_date": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        mock_db.tasks.find_one = AsyncMock(return_value=mock_task_doc)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            task_data = {
                "title": "Test Task",
                "description": "A test task",
                "project_id": "project123",
                "assignee": "testuser",
                "priority": "medium",
                "estimated_hours": 8.0
            }

            response = client.post("/tasks/", json=task_data)

            assert response.status_code == 200
            data = response.json()
            assert data["title"] == "Test Task"
            assert data["project_id"] == "project123"
            assert data["assignee"] == "testuser"
            assert data["status"] == "todo"

    def test_create_task_project_not_found(self, client, mock_db, mock_user):
        """Test creating task for non-existent project"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            task_data = {
                "title": "Test Task",
                "description": "A test task",
                "project_id": "nonexistent",
                "assignee": "testuser"
            }

            response = client.post("/tasks/", json=task_data)

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_get_tasks_all_user_projects(self, client, mock_db, mock_user):
        """Test getting all tasks from user's projects"""
        # Mock user projects
        mock_projects = [
            {"_id": "project123", "owner_id": "testuser"},
            {"_id": "project456", "team_members": ["testuser"]}
        ]

        # Mock tasks
        mock_tasks = [
            {
                "_id": "task123",
                "title": "Task 1",
                "project_id": "project123",
                "assignee": "testuser",
                "status": "todo",
                "priority": "high",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            },
            {
                "_id": "task456",
                "title": "Task 2",
                "project_id": "project456",
                "assignee": "testuser",
                "status": "in_progress",
                "priority": "medium",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        ]

        mock_db.projects.find = AsyncMock()
        mock_db.projects.find.return_value.to_list = AsyncMock(return_value=mock_projects)
        mock_db.tasks.find = AsyncMock()
        mock_db.tasks.find.return_value.to_list = AsyncMock(return_value=mock_tasks)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/tasks/")

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
            assert data[0]["title"] == "Task 1"
            assert data[1]["title"] == "Task 2"

    def test_get_tasks_specific_project(self, client, mock_db, mock_user):
        """Test getting tasks for a specific project"""
        # Mock project access
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "owner_id": "testuser"
        }

        # Mock tasks
        mock_tasks = [
            {
                "_id": "task123",
                "title": "Task 1",
                "project_id": "project123",
                "assignee": "testuser",
                "status": "todo",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        ]

        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.tasks.find = AsyncMock()
        mock_db.tasks.find.return_value.to_list = AsyncMock(return_value=mock_tasks)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/tasks/?project_id=project123")

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 1
            assert data[0]["project_id"] == "project123"

    def test_get_tasks_project_not_authorized(self, client, mock_db, mock_user):
        """Test getting tasks for unauthorized project"""
        mock_db.projects.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/tasks/?project_id=unauthorized")

            assert response.status_code == 404
            data = response.json()
            assert "Project not found or not authorized" in data["detail"]

    def test_get_task_success(self, client, mock_db, mock_user):
        """Test getting a specific task"""
        # Mock task and project
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "assignee": "testuser",
            "status": "todo",
            "priority": "medium",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        mock_db.tasks.find_one = AsyncMock(return_value=mock_task)
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)

        # Mock user for authentication
        mock_db.users.find_one = AsyncMock(return_value={
            "_id": "user123",
            "username": "testuser",
            "email": "test@example.com",
            "hashed_password": get_password_hash("Password123"),
            "full_name": "Test User",
            "disabled": False
        })

        # First get a token
        login_data = {
            "username": "testuser",
            "password": "Password123"
        }

        token_response = client.post("/auth/token", data=login_data)
        token = token_response.json()["access_token"]

        # Now test the protected endpoint
        headers = {"Authorization": f"Bearer {token}"}
        response = client.get("/tasks/task123", headers=headers)

        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Test Task"
        assert data["_id"] == "task123"

    def test_get_task_not_found(self, client, mock_db, mock_user):
        """Test getting a non-existent task"""
        mock_db.tasks.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/tasks/nonexistent")

            assert response.status_code == 404
            data = response.json()
            assert "Task not found" in data["detail"]

    def test_get_task_not_authorized(self, client, mock_db, mock_user):
        """Test getting a task from unauthorized project"""
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "project_id": "project123"
        }

        mock_db.tasks.find_one = AsyncMock(return_value=mock_task)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.get("/tasks/task123")

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_update_task_success(self, client, mock_db, mock_user):
        """Test successful task update"""
        # Mock existing task and project
        mock_task = {
            "_id": "task123",
            "title": "Old Task",
            "description": "Old description",
            "project_id": "project123",
            "assignee": "testuser",
            "status": "todo",
            "priority": "low",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        # Mock updated task
        mock_updated_task = {
            "_id": "task123",
            "title": "Updated Task",
            "description": "Updated description",
            "project_id": "project123",
            "assignee": "testuser",
            "status": "in_progress",
            "priority": "high",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        mock_db.tasks.find_one = AsyncMock(side_effect=[mock_task, mock_updated_task])
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.tasks.update_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "title": "Updated Task",
                "description": "Updated description",
                "status": "in_progress",
                "priority": "high"
            }

            response = client.put("/tasks/task123", json=update_data)

            assert response.status_code == 200
            data = response.json()
            assert data["title"] == "Updated Task"
            assert data["status"] == "in_progress"
            assert data["priority"] == "high"

    def test_update_task_not_found(self, client, mock_db, mock_user):
        """Test updating a non-existent task"""
        mock_db.tasks.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "title": "Updated Task",
                "status": "in_progress"
            }

            response = client.put("/tasks/nonexistent", json=update_data)

            assert response.status_code == 404
            data = response.json()
            assert "Task not found" in data["detail"]

    def test_update_task_not_authorized(self, client, mock_db, mock_user):
        """Test updating a task from unauthorized project"""
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "project_id": "project123"
        }

        mock_db.tasks.find_one = AsyncMock(return_value=mock_task)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            update_data = {
                "title": "Updated Task",
                "status": "in_progress"
            }

            response = client.put("/tasks/task123", json=update_data)

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_delete_task_success(self, client, mock_db, mock_user):
        """Test successful task deletion"""
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "project_id": "project123"
        }

        mock_project = {
            "_id": "project123",
            "owner_id": "testuser"
        }

        mock_db.tasks.find_one = AsyncMock(return_value=mock_task)
        mock_db.projects.find_one = AsyncMock(return_value=mock_project)
        mock_db.tasks.delete_one = AsyncMock()

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/tasks/task123")

            assert response.status_code == 200
            data = response.json()
            assert "Task deleted successfully" in data["message"]

    def test_delete_task_not_found(self, client, mock_db, mock_user):
        """Test deleting a non-existent task"""
        mock_db.tasks.find_one = AsyncMock(return_value=None)

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/tasks/nonexistent")

            assert response.status_code == 404
            data = response.json()
            assert "Task not found" in data["detail"]

    def test_delete_task_not_authorized(self, client, mock_db, mock_user):
        """Test deleting a task from unauthorized project"""
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "project_id": "project123"
        }

        mock_db.tasks.find_one = AsyncMock(return_value=mock_task)
        mock_db.projects.find_one = AsyncMock(return_value=None)  # No access to project

        # Mock authentication
        with patch('app.routers.auth.get_current_user', return_value=mock_user):
            response = client.delete("/tasks/task123")

            assert response.status_code == 404
            data = response.json()
            assert "Not authorized" in data["detail"]

    def test_create_task_unauthenticated(self, client):
        """Test creating task without authentication"""
        task_data = {
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123"
        }

        response = client.post("/tasks/", json=task_data)

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_get_tasks_unauthenticated(self, client):
        """Test getting tasks without authentication"""
        response = client.get("/tasks/")

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]
