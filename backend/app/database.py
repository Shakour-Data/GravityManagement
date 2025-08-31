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
