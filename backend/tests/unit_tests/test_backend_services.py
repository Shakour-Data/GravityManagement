import pytest
import asyncio
import sys
import os
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.main import app

client = TestClient(app)

@pytest.mark.asyncio
async def test_cache_service_basic():
    # Example test for cache service
    from app.services.cache_service import CacheService
    cache = CacheService()
    await cache.set("test_key", "test_value")
    value = await cache.get("test_key")
    assert value == "test_value"

def test_main_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    assert "Welcome" in response.text

# Add more tests for other services and endpoints as needed
