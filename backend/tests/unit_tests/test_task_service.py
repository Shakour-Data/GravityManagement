import pytest
import asyncio
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.task_service import TaskService
from app.models.task import Task
from app.services.exceptions import NotFoundError

@pytest.mark.asyncio
class TestTaskService:
    @pytest.fixture
    async def task_service(self):
        service = TaskService()
        service.db = AsyncMock()
        return service

    async def test_create_task(self, task_service):
        from app.models.user import User
        from app.models.task import TaskCreate
        task_data = TaskCreate(
            title="Test Task",
            description="A test task",
            project_id="project123",
            assignee_id="user123"
        )
        user = User(username="user123", email="user123@example.com")

        # Mock the database operations
        task_service.db.tasks.insert_one = AsyncMock(return_value=MagicMock(inserted_id="task123"))
        task_service.db.tasks.find_one = AsyncMock(return_value={
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "assignee_id": "user123",
            "status": "todo",
            "created_at": None,
            "updated_at": None
        })

        result = await task_service.create_task(task_data, user)
        assert result.id == "task123"
        assert result.title == "Test Task"

    async def test_get_task(self, task_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "assignee_id": "user123",
            "status": "todo",
            "created_at": None,
            "updated_at": None
        }
        task_service.db.tasks.find_one = AsyncMock(return_value=mock_task)
        task_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})

        result = await task_service.get_task("task123", user)
        assert result.id == "task123"
        assert result.title == "Test Task"

    async def test_get_task_not_found(self, task_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        task_service.db.tasks.find_one = AsyncMock(return_value=None)

        with pytest.raises(NotFoundError):
            await task_service.get_task("nonexistent", user)

    async def test_update_task(self, task_service):
        from app.models.user import User
        from app.models.task import TaskUpdate
        user = User(username="user123", email="user123@example.com")
        update_data = TaskUpdate(title="Updated Task")
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "status": "todo",
            "created_at": None,
            "updated_at": None
        }
        task_service.db.tasks.find_one = AsyncMock(return_value=mock_task)
        task_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})
        task_service.db.tasks.update_one = AsyncMock()

        result = await task_service.update_task("task123", update_data, user)
        assert result.title == "Updated Task"

    async def test_delete_task(self, task_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        mock_task = {
            "_id": "task123",
            "title": "Test Task",
            "description": "A test task",
            "project_id": "project123",
            "status": "todo",
            "assignee_id": "user123",
            "created_at": None,
            "updated_at": None
        }
        task_service.db.tasks.find_one = AsyncMock(return_value=mock_task)
        task_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123", "owner_id": "user123"})
        task_service.db.tasks.delete_one = AsyncMock(return_value=MagicMock(deleted_count=1))

        result = await task_service.delete_task("task123", user)
        assert result == True
