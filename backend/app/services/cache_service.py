from typing import Any, Dict, Optional, Callable, Union
import asyncio
import json
import hashlib
from datetime import datetime, timedelta
from functools import wraps
import redis.asyncio as redis
from ..database import get_database

class CacheService:
    def __init__(self):
        self.redis_client = None
        self.memory_cache: Dict[str, Dict[str, Any]] = {}
        self.use_redis = False  # Set to True when Redis is available

    async def initialize(self):
        """
        Initialize cache service with Redis if available, otherwise use memory cache
        """
        try:
            # Try to connect to Redis
            self.redis_client = redis.Redis(
                host="localhost",
                port=6379,
                db=0,
                decode_responses=True
            )
            # Test connection
            await self.redis_client.ping()
            self.use_redis = True
            print("Redis cache initialized successfully")
        except Exception as e:
            print(f"Redis not available, using memory cache: {e}")
            self.use_redis = False

    async def get(self, key: str) -> Optional[Any]:
        """
        Get value from cache
        """
        if self.use_redis and self.redis_client:
            try:
                value = await self.redis_client.get(key)
                return json.loads(value) if value else None
            except Exception as e:
                print(f"Redis get error: {e}")
                return None
        else:
            # Use memory cache
            cache_entry = self.memory_cache.get(key)
            if cache_entry:
                if datetime.utcnow() < cache_entry['expires_at']:
                    return cache_entry['value']
                else:
                    # Remove expired entry
                    del self.memory_cache[key]
            return None

    async def set(self, key: str, value: Any, ttl_seconds: int = 300) -> bool:
        """
        Set value in cache with TTL
        """
        expires_at = datetime.utcnow() + timedelta(seconds=ttl_seconds)

        if self.use_redis and self.redis_client:
            try:
                await self.redis_client.setex(key, ttl_seconds, json.dumps(value))
                return True
            except Exception as e:
                print(f"Redis set error: {e}")
                return False
        else:
            # Use memory cache
            self.memory_cache[key] = {
                'value': value,
                'expires_at': expires_at
            }
            return True

    async def delete(self, key: str) -> bool:
        """
        Delete value from cache
        """
        if self.use_redis and self.redis_client:
            try:
                await self.redis_client.delete(key)
                return True
            except Exception as e:
                print(f"Redis delete error: {e}")
                return False
        else:
            # Use memory cache
            if key in self.memory_cache:
                del self.memory_cache[key]
                return True
            return False

    async def clear_pattern(self, pattern: str) -> int:
        """
        Clear all keys matching a pattern
        """
        if self.use_redis and self.redis_client:
            try:
                keys = await self.redis_client.keys(pattern)
                if keys:
                    await self.redis_client.delete(*keys)
                return len(keys)
            except Exception as e:
                print(f"Redis clear pattern error: {e}")
                return 0
        else:
            # Use memory cache - simple implementation
            deleted_count = 0
            keys_to_delete = [k for k in self.memory_cache.keys() if pattern.replace('*', '') in k]
            for key in keys_to_delete:
                del self.memory_cache[key]
                deleted_count += 1
            return deleted_count

    async def clear_all(self) -> bool:
        """
        Clear all cache entries
        """
        if self.use_redis and self.redis_client:
            try:
                await self.redis_client.flushdb()
                return True
            except Exception as e:
                print(f"Redis clear all error: {e}")
                return False
        else:
            # Use memory cache
            self.memory_cache.clear()
            return True

    def generate_key(self, *args, **kwargs) -> str:
        """
        Generate a cache key from function arguments
        """
        key_parts = [str(arg) for arg in args]
        key_parts.extend([f"{k}:{v}" for k, v in sorted(kwargs.items())])
        key_string = "|".join(key_parts)
        return hashlib.md5(key_string.encode()).hexdigest()

# Global cache service instance
cache_service = CacheService()

def cached(ttl_seconds: int = 300, key_prefix: str = ""):
    """
    Decorator to cache function results
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = f"{key_prefix}:{func.__name__}:{cache_service.generate_key(*args, **kwargs)}"

            # Try to get from cache first
            cached_result = await cache_service.get(cache_key)
            if cached_result is not None:
                return cached_result

            # Execute function
            result = await func(*args, **kwargs)

            # Cache the result
            await cache_service.set(cache_key, result, ttl_seconds)

            return result

        return wrapper
    return decorator

def invalidate_cache(pattern: str):
    """
    Decorator to invalidate cache after function execution
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            result = await func(*args, **kwargs)

            # Invalidate cache
            await cache_service.clear_pattern(pattern)

            return result

        return wrapper
    return decorator

# Cache key patterns for different entities
class CacheKeys:
    USER = "user:*"
    PROJECT = "project:*"
    TASK = "task:*"
    RESOURCE = "resource:*"
    RULE = "rule:*"

    @staticmethod
    def user(username: str) -> str:
        return f"user:{username}"

    @staticmethod
    def project(project_id: str) -> str:
        return f"project:{project_id}"

    @staticmethod
    def task(task_id: str) -> str:
        return f"task:{task_id}"

    @staticmethod
    def resource(resource_id: str) -> str:
        return f"resource:{resource_id}"

    @staticmethod
    def rule(rule_id: str) -> str:
        return f"rule:{rule_id}"

    @staticmethod
    def user_projects(username: str) -> str:
        return f"user_projects:{username}"

    @staticmethod
    def project_tasks(project_id: str) -> str:
        return f"project_tasks:{project_id}"

    @staticmethod
    def project_resources(project_id: str) -> str:
        return f"project_resources:{project_id}"

    @staticmethod
    def user_tasks(username: str) -> str:
        return f"user_tasks:{username}"
