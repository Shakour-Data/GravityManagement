import pytest
import asyncio
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
import json

# Import the cache service
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.cache_service import CacheService, CacheKeys, cached, invalidate_cache

class TestCacheService:
    """Test CacheService class"""

    @pytest.fixture
    def cache_service(self):
        """Create a fresh cache service instance"""
        return CacheService()

    @pytest.fixture
    def sample_data(self):
        """Sample data for testing"""
        return {
            "user": {"id": "123", "name": "Test User"},
            "project": {"id": "456", "title": "Test Project"},
            "list": [1, 2, 3, 4, 5]
        }

    def test_cache_service_initialization(self, cache_service):
        """Test cache service initialization"""
        assert cache_service.redis_client is None
        assert cache_service.memory_cache == {}
        assert cache_service.use_redis is False

    @pytest.mark.asyncio
    @patch('redis.asyncio.Redis')
    async def test_initialize_with_redis_success(self, mock_redis_class, cache_service):
        """Test successful Redis initialization"""
        mock_redis_instance = AsyncMock()
        mock_redis_class.return_value = mock_redis_instance
        mock_redis_instance.ping.return_value = True

        await cache_service.initialize()

        assert cache_service.use_redis is True
        assert cache_service.redis_client is not None
        mock_redis_instance.ping.assert_called_once()

    @pytest.mark.asyncio
    @patch('redis.asyncio.Redis')
    async def test_initialize_with_redis_failure(self, mock_redis_class, cache_service):
        """Test Redis initialization failure fallback to memory"""
        mock_redis_class.side_effect = Exception("Redis connection failed")

        await cache_service.initialize()

        assert cache_service.use_redis is False
        assert cache_service.redis_client is None

    @pytest.mark.asyncio
    async def test_memory_cache_set_and_get(self, cache_service, sample_data):
        """Test memory cache set and get operations"""
        cache_service.use_redis = False

        # Test set
        result = await cache_service.set("test_key", sample_data["user"])
        assert result is True

        # Test get
        value = await cache_service.get("test_key")
        assert value == sample_data["user"]

    @pytest.mark.asyncio
    async def test_memory_cache_get_nonexistent(self, cache_service):
        """Test memory cache get for nonexistent key"""
        cache_service.use_redis = False

        value = await cache_service.get("nonexistent_key")
        assert value is None

    @pytest.mark.asyncio
    async def test_memory_cache_expiration(self, cache_service, sample_data):
        """Test memory cache expiration"""
        cache_service.use_redis = False

        # Set with short TTL
        await cache_service.set("test_key", sample_data["user"], ttl_seconds=1)

        # Should exist immediately
        value = await cache_service.get("test_key")
        assert value == sample_data["user"]

        # Wait for expiration
        await asyncio.sleep(1.1)

        # Should be expired
        value = await cache_service.get("test_key")
        assert value is None

    @pytest.mark.asyncio
    async def test_memory_cache_delete(self, cache_service, sample_data):
        """Test memory cache delete operation"""
        cache_service.use_redis = False

        await cache_service.set("test_key", sample_data["user"])
        assert await cache_service.exists("test_key") is True

        result = await cache_service.delete("test_key")
        assert result is True
        assert await cache_service.exists("test_key") is False

    @pytest.mark.asyncio
    async def test_memory_cache_delete_nonexistent(self, cache_service):
        """Test memory cache delete for nonexistent key"""
        cache_service.use_redis = False

        result = await cache_service.delete("nonexistent_key")
        assert result is False

    @pytest.mark.asyncio
    async def test_memory_cache_exists(self, cache_service, sample_data):
        """Test memory cache exists operation"""
        cache_service.use_redis = False

        assert await cache_service.exists("test_key") is False

        await cache_service.set("test_key", sample_data["user"])
        assert await cache_service.exists("test_key") is True

    @pytest.mark.asyncio
    async def test_memory_cache_clear_pattern(self, cache_service, sample_data):
        """Test memory cache clear pattern operation"""
        cache_service.use_redis = False

        # Set multiple keys
        await cache_service.set("user:1", sample_data["user"])
        await cache_service.set("user:2", sample_data["user"])
        await cache_service.set("project:1", sample_data["project"])

        # Clear user pattern
        deleted_count = await cache_service.clear_pattern("user:*")
        assert deleted_count == 2

        # Check remaining keys
        assert await cache_service.exists("user:1") is False
        assert await cache_service.exists("user:2") is False
        assert await cache_service.exists("project:1") is True

    @pytest.mark.asyncio
    async def test_memory_cache_clear_all(self, cache_service, sample_data):
        """Test memory cache clear all operation"""
        cache_service.use_redis = False

        await cache_service.set("key1", sample_data["user"])
        await cache_service.set("key2", sample_data["project"])

        result = await cache_service.clear_all()
        assert result is True

        assert await cache_service.exists("key1") is False
        assert await cache_service.exists("key2") is False

    @pytest.mark.asyncio
    @patch('redis.asyncio.Redis')
    async def test_redis_cache_operations(self, mock_redis_class, cache_service, sample_data):
        """Test Redis cache operations"""
        mock_redis_instance = AsyncMock()
        mock_redis_class.return_value = mock_redis_instance
        cache_service.redis_client = mock_redis_instance
        cache_service.use_redis = True

        # Test set
        mock_redis_instance.setex.return_value = True
        result = await cache_service.set("test_key", sample_data["user"])
        assert result is True
        mock_redis_instance.setex.assert_called_once()

        # Test get
        mock_redis_instance.get.return_value = json.dumps(sample_data["user"])
        value = await cache_service.get("test_key")
        assert value == sample_data["user"]
        mock_redis_instance.get.assert_called_once_with("test_key")

        # Test get None
        mock_redis_instance.get.return_value = None
        value = await cache_service.get("test_key")
        assert value is None

        # Test delete
        mock_redis_instance.delete.return_value = 1
        result = await cache_service.delete("test_key")
        assert result is True

        # Test exists
        mock_redis_instance.exists.return_value = 1
        result = await cache_service.exists("test_key")
        assert result is True

        # Test clear pattern
        mock_redis_instance.keys.return_value = ["key1", "key2"]
        mock_redis_instance.delete.return_value = 2
        result = await cache_service.clear_pattern("pattern:*")
        assert result == 2

        # Test clear all
        mock_redis_instance.flushdb.return_value = True
        result = await cache_service.clear_all()
        assert result is True

    @pytest.mark.asyncio
    @patch('redis.asyncio.Redis')
    async def test_redis_error_handling(self, mock_redis_class, cache_service, sample_data):
        """Test Redis error handling fallback"""
        mock_redis_instance = AsyncMock()
        mock_redis_class.return_value = mock_redis_instance
        cache_service.redis_client = mock_redis_instance
        cache_service.use_redis = True

        # Test get error
        mock_redis_instance.get.side_effect = Exception("Redis error")
        value = await cache_service.get("test_key")
        assert value is None

        # Test set error
        mock_redis_instance.setex.side_effect = Exception("Redis error")
        result = await cache_service.set("test_key", sample_data["user"])
        assert result is False

        # Test delete error
        mock_redis_instance.delete.side_effect = Exception("Redis error")
        result = await cache_service.delete("test_key")
        assert result is False

        # Test exists error
        mock_redis_instance.exists.side_effect = Exception("Redis error")
        result = await cache_service.exists("test_key")
        assert result is False

        # Test clear pattern error
        mock_redis_instance.keys.side_effect = Exception("Redis error")
        result = await cache_service.clear_pattern("pattern:*")
        assert result == 0

        # Test clear all error
        mock_redis_instance.flushdb.side_effect = Exception("Redis error")
        result = await cache_service.clear_all()
        assert result is False

    def test_generate_key(self, cache_service):
        """Test cache key generation"""
        # Test with positional args
        key1 = cache_service.generate_key("arg1", "arg2")
        key2 = cache_service.generate_key("arg1", "arg2")
        assert key1 == key2  # Same args should generate same key

        key3 = cache_service.generate_key("arg1", "arg3")
        assert key1 != key3  # Different args should generate different key

        # Test with keyword args
        key4 = cache_service.generate_key("arg1", param1="value1", param2="value2")
        key5 = cache_service.generate_key("arg1", param1="value1", param2="value2")
        assert key4 == key5

        key6 = cache_service.generate_key("arg1", param1="value1", param2="value3")
        assert key4 != key6

    def test_cache_keys_static_methods(self):
        """Test CacheKeys static methods"""
        assert CacheKeys.user("testuser") == "user:testuser"
        assert CacheKeys.project("123") == "project:123"
        assert CacheKeys.task("456") == "task:456"
        assert CacheKeys.resource("789") == "resource:789"
        assert CacheKeys.rule("101") == "rule:101"
        assert CacheKeys.user_projects("testuser") == "user_projects:testuser"
        assert CacheKeys.project_tasks("123") == "project_tasks:123"
        assert CacheKeys.project_resources("123") == "project_resources:123"
        assert CacheKeys.user_tasks("testuser") == "user_tasks:testuser"

class TestCacheDecorators:
    """Test cache decorators"""

    @pytest.fixture
    def cache_service(self):
        """Create a fresh cache service instance"""
        return CacheService()

    @pytest.mark.asyncio
    async def test_cached_decorator(self, cache_service):
        """Test cached decorator"""
        cache_service.use_redis = False

        call_count = 0

        @cached(ttl_seconds=60, key_prefix="test")
        async def test_function(x, y):
            nonlocal call_count
            call_count += 1
            return x + y

        # First call should execute function
        result1 = await test_function(2, 3)
        assert result1 == 5
        assert call_count == 1

        # Second call with same args should use cache
        result2 = await test_function(2, 3)
        assert result2 == 5
        assert call_count == 1  # Function not called again

        # Call with different args should execute function
        result3 = await test_function(3, 4)
        assert result3 == 7
        assert call_count == 2

    @pytest.mark.asyncio
    async def test_invalidate_cache_decorator(self, cache_service):
        """Test invalidate cache decorator"""
        cache_service.use_redis = False

        call_count = 0

        @cached(ttl_seconds=60, key_prefix="test")
        async def get_data():
            nonlocal call_count
            call_count += 1
            return {"data": "test"}

        @invalidate_cache("test:*")
        async def update_data():
            return {"status": "updated"}

        # Cache data
        result1 = await get_data()
        assert result1 == {"data": "test"}
        assert call_count == 1

        # Call cached again (should use cache)
        result2 = await get_data()
        assert result2 == {"data": "test"}
        assert call_count == 1

        # Update data (should invalidate cache)
        await update_data()

        # Call get_data again (should execute function)
        result3 = await get_data()
        assert result3 == {"data": "test"}
        assert call_count == 2
