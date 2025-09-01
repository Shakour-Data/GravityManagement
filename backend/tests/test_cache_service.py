import pytest
import asyncio
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.services.cache_service import CacheService

@pytest.mark.asyncio
class TestCacheService:
    @pytest.fixture
    async def cache_service(self):
        cache = CacheService()
        yield cache
        # Cleanup if needed

    async def test_set_and_get(self, cache_service):
        await cache_service.set("test_key", "test_value")
        value = await cache_service.get("test_key")
        assert value == "test_value"

    async def test_get_nonexistent_key(self, cache_service):
        value = await cache_service.get("nonexistent_key")
        assert value is None

    async def test_delete_key(self, cache_service):
        await cache_service.set("delete_key", "delete_value")
        await cache_service.delete("delete_key")
        value = await cache_service.get("delete_key")
        assert value is None

    async def test_exists(self, cache_service):
        await cache_service.set("exists_key", "exists_value")
        assert await cache_service.exists("exists_key") == True
        assert await cache_service.exists("nonexistent_key") == False
