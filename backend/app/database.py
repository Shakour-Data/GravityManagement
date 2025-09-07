from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ConnectionFailure
import os
from contextlib import asynccontextmanager

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "gravitypm")

# Connection pool settings
MAX_POOL_SIZE = int(os.getenv("MONGO_MAX_POOL_SIZE", "10"))
MIN_POOL_SIZE = int(os.getenv("MONGO_MIN_POOL_SIZE", "2"))
MAX_IDLE_TIME_MS = int(os.getenv("MONGO_MAX_IDLE_TIME_MS", "30000"))

client: AsyncIOMotorClient | None = None
database = None

async def connect_to_mongo():
    global client, database
    try:
        client = AsyncIOMotorClient(
            MONGO_URL,
            maxPoolSize=MAX_POOL_SIZE,
            minPoolSize=MIN_POOL_SIZE,
            maxIdleTimeMS=MAX_IDLE_TIME_MS,
            # Connection monitoring
            heartbeatFrequencyMS=10000,
            serverSelectionTimeoutMS=5000,
            # Retry settings
            retryWrites=True,
            retryReads=True
        )
        database = client[DATABASE_NAME]
        # Test the connection
        await client.admin.command('ping')
        print(f"Connected to MongoDB with pool size: {MAX_POOL_SIZE}")
    except ConnectionFailure as e:
        print(f"Failed to connect to MongoDB: {e}")
        raise

async def close_mongo_connection():
    global client
    if client:
        client.close()
        print("Disconnected from MongoDB")

def get_database():
    return database

@asynccontextmanager
async def get_database_session():
    """Context manager for database sessions with transaction support"""
    session = await client.start_session()
    try:
        yield session
    finally:
        await session.end_session()

async def create_indexes():
    """
    Create necessary indexes for collections to improve query performance.
    """
    db = get_database()
    if db is None:
        raise Exception("Database connection is not established")

    # Users collection indexes
    await db.users.create_index("username", unique=True)
    await db.users.create_index("email", unique=True)
    await db.users.create_index("created_at")
    await db.users.create_index("last_login")

    # Projects collection indexes
    await db.projects.create_index("owner_id")
    await db.projects.create_index("status")
    await db.projects.create_index("created_at")
    await db.projects.create_index("updated_at")
    await db.projects.create_index([("name", 1), ("status", 1)])

    # Tasks collection indexes
    await db.tasks.create_index("assignee_id")
    await db.tasks.create_index("status")
    await db.tasks.create_index("due_date")
    await db.tasks.create_index("project_id")
    await db.tasks.create_index("priority")
    await db.tasks.create_index([("status", 1), ("due_date", 1)])
    await db.tasks.create_index([("assignee_id", 1), ("status", 1)])

    # Resources collection indexes
    await db.resources.create_index("project_id")
    await db.resources.create_index("type")
    await db.resources.create_index("status")
    await db.resources.create_index([("project_id", 1), ("type", 1)])

    # Rules collection indexes
    await db.rules.create_index("project_id")
    await db.rules.create_index("type")
    await db.rules.create_index("active")
    await db.rules.create_index([("project_id", 1), ("active", 1)])

    print("Database indexes created successfully")

async def get_connection_stats():
    """Get database connection pool statistics"""
    if client:
        return {
            "pool_size": len(client._topology._servers),
            "active_connections": sum(len(server._pool._pending) for server in client._topology._servers.values()),
            "available_connections": sum(server._pool._size for server in client._topology._servers.values())
        }
    return {}

async def health_check():
    """Database health check"""
    try:
        db = get_database()
        if db is None:
            return False

        # Simple ping
        await client.admin.command('ping')

        # Get server status
        status = await client.admin.command('serverStatus')

        return {
            "status": "healthy",
            "connections": status.get("connections", {}),
            "opcounters": status.get("opcounters", {}),
            "mem": status.get("mem", {})
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }
