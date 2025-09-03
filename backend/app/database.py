from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ConnectionFailure
import os

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DATABASE_NAME = "gravitypm"

client: AsyncIOMotorClient = None
database = None

async def connect_to_mongo():
    global client, database
    try:
        client = AsyncIOMotorClient(MONGO_URL)
        database = client[DATABASE_NAME]
        # Test the connection
        await client.admin.command('ping')
        print("Connected to MongoDB")
    except ConnectionFailure:
        print("Failed to connect to MongoDB")
        raise

async def close_mongo_connection():
    global client
    if client:
        client.close()
        print("Disconnected from MongoDB")

def get_database():
    return database

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

    # Projects collection indexes
    await db.projects.create_index("owner_id")
    await db.projects.create_index("status")

    # Tasks collection indexes
    await db.tasks.create_index("assignee_id")
    await db.tasks.create_index("status")
    await db.tasks.create_index("due_date")

    # Resources collection indexes
    await db.resources.create_index("project_id")

    # Rules collection indexes
    await db.rules.create_index("project_id")

    print("Indexes created successfully")
