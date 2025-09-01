import pytest
import asyncio
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.services.resource_service import ResourceService
from backend.app.models.resource import Resource
from backend.app.services.exceptions import NotFoundError

@pytest.mark.asyncio
class TestResourceService:
    @pytest.fixture
    async def resource_service(self):
        service = ResourceService()
        service.db = AsyncMock()
        return service

    async def test_create_resource(self, resource_service):
        from backend.app.models.user import User
        from backend.app.models.resource import ResourceCreate, ResourceType
        resource_data = ResourceCreate(
            name="Test Resource",
            type=ResourceType.MATERIAL,
            quantity=100,
            project_id="project123"
        )
        user = User(username="user123", email="user123@example.com")

        from datetime import datetime
        # Mock the database operations
        resource_service.db.resources.find_one = AsyncMock(return_value=None)
        resource_service.db.resources.insert_one = AsyncMock(return_value=MagicMock(inserted_id="resource123"))
        resource_service.db.resources.find_one = AsyncMock(return_value={
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 100,
            "project_id": "project123",
            "availability": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await resource_service.create_resource(resource_data, user)
        assert result.id == "resource123"
        assert result.name == "Test Resource"

    async def test_get_resource(self, resource_service):
        from backend.app.models.user import User
        user = User(username="user123", email="user123@example.com")
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 100,
            "project_id": "project123",
            "availability": True,
            "created_at": None,
            "updated_at": None
        }
        resource_service.db.resources.find_one = AsyncMock(return_value=mock_resource)
        resource_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})

        result = await resource_service.get_resource("resource123", user)
        assert result.id == "resource123"
        assert result.name == "Test Resource"

    async def test_get_resource_not_found(self, resource_service):
        from backend.app.models.user import User
        user = User(username="user123", email="user123@example.com")
        resource_service.db.resources.find_one = AsyncMock(return_value=None)

        with pytest.raises(NotFoundError):
            await resource_service.get_resource("nonexistent", user)

    async def test_allocate_resource(self, resource_service):
        from backend.app.models.user import User
        user = User(username="user123", email="user123@example.com")
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 100,
            "project_id": "project123",
            "availability": True,
            "created_at": None,
            "updated_at": None
        }
        resource_service.db.resources.find_one = AsyncMock(return_value=mock_resource)
        resource_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})
        resource_service.db.resources.update_one = AsyncMock()

        result = await resource_service.allocate_resource("resource123", 25, user)
        assert result.quantity == 75

    async def test_allocate_resource_insufficient_capacity(self, resource_service):
        from backend.app.models.user import User
        from backend.app.services.exceptions import BusinessLogicError
        user = User(username="user123", email="user123@example.com")
        from datetime import datetime
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 10,
            "project_id": "project123",
            "availability": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        resource_service.db.resources.find_one = AsyncMock(return_value=mock_resource)
        resource_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})

        with pytest.raises(BusinessLogicError):
            await resource_service.allocate_resource("resource123", 20, user)

    async def test_update_resource(self, resource_service):
        from backend.app.models.user import User
        from backend.app.models.resource import ResourceUpdate
        user = User(username="user123", email="user123@example.com")
        update_data = ResourceUpdate(name="Updated Resource")
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 100,
            "project_id": "project123",
            "availability": True,
            "created_at": None,
            "updated_at": None
        }
        resource_service.db.resources.find_one = AsyncMock(return_value=mock_resource)
        resource_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})
        resource_service.db.resources.update_one = AsyncMock()

        result = await resource_service.update_resource("resource123", update_data, user)
        assert result.name == "Updated Resource"

    async def test_delete_resource(self, resource_service):
        from backend.app.models.user import User
        user = User(username="user123", email="user123@example.com")
        mock_resource = {
            "_id": "resource123",
            "name": "Test Resource",
            "type": "material",
            "quantity": 100,
            "project_id": "project123",
            "availability": True,
            "created_at": None,
            "updated_at": None
        }
        resource_service.db.resources.find_one = AsyncMock(return_value=mock_resource)
        resource_service.db.projects.find_one = AsyncMock(return_value={"_id": "project123"})
        resource_service.db.resources.delete_one = AsyncMock(return_value=MagicMock(deleted_count=1))

        result = await resource_service.delete_resource("resource123", user)
        assert result == True
