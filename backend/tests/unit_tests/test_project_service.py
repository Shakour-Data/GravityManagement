import pytest
import asyncio
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.project_service import ProjectService
from app.models.project import Project
from app.services.exceptions import NotFoundError

@pytest.mark.asyncio
class TestProjectService:
    @pytest.fixture
    async def project_service(self):
        service = ProjectService()
        service.db = AsyncMock()
        return service

    async def test_create_project(self, project_service):
        from app.models.user import User
        from app.models.project import ProjectCreate
        project_data = ProjectCreate(
            name="Test Project",
            description="A test project"
        )
        owner = User(username="user123", email="user123@example.com")

        from datetime import datetime
        # Mock the database insert
        project_service.db.projects.find_one = AsyncMock(return_value=None)
        project_service.db.projects.insert_one = AsyncMock(return_value=MagicMock(inserted_id="project123"))
        project_service.db.projects.find_one = AsyncMock(return_value={
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "user123",
            "team_members": ["user123"],
            "status": "planning",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await project_service.create_project(project_data, owner)
        assert result.id == "project123"
        assert result.name == "Test Project"

    async def test_get_project(self, project_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        from datetime import datetime
        mock_project = {
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "user123",
            "team_members": ["user123"],
            "status": "planning",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        project_service.db.projects.find_one = AsyncMock(return_value=mock_project)

        result = await project_service.get_project("project123", user)
        assert result.id == "project123"
        assert result.name == "Test Project"

    async def test_get_project_not_found(self, project_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        project_service.db.projects.find_one = AsyncMock(return_value=None)

        with pytest.raises(NotFoundError):
            await project_service.get_project("nonexistent", user)

    async def test_update_project(self, project_service):
        from app.models.user import User
        from app.models.project import ProjectUpdate
        user = User(username="user123", email="user123@example.com")
        update_data = ProjectUpdate(name="Updated Project")
        from datetime import datetime
        project_service.db.projects.find_one = AsyncMock(return_value={
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "user123",
            "team_members": ["user123"],
            "status": "planning",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })
        project_service.db.projects.update_one = AsyncMock(return_value=MagicMock(modified_count=1))
        project_service.db.projects.find_one = AsyncMock(return_value={
            "_id": "project123",
            "name": "Updated Project",
            "description": "A test project",
            "owner_id": "user123",
            "team_members": ["user123"],
            "status": "planning",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await project_service.update_project("project123", update_data, user)
        assert result.name == "Updated Project"

    async def test_delete_project(self, project_service):
        from app.models.user import User
        user = User(username="user123", email="user123@example.com")
        from datetime import datetime
        project_service.db.projects.find_one = AsyncMock(return_value={
            "_id": "project123",
            "name": "Test Project",
            "description": "A test project",
            "owner_id": "user123",
            "team_members": ["user123"],
            "status": "planning",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })
        project_service.db.projects.delete_one = AsyncMock(return_value=MagicMock(deleted_count=1))

        result = await project_service.delete_project("project123", user)
        assert result == True
