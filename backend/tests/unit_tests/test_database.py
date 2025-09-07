import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from app.database import connect_to_mongo, close_mongo_connection, get_database, create_indexes

pytestmark = pytest.mark.asyncio

class TestDatabase:
    @patch('app.database.AsyncIOMotorClient')
    async def test_connect_to_mongo_success(self, mock_client_class):
        mock_client = MagicMock()
        mock_client.admin.command = AsyncMock()
        mock_client_class.return_value = mock_client

        await connect_to_mongo()

        # Check that AsyncIOMotorClient was called with the expected parameters
        mock_client_class.assert_called_once_with(
            "mongodb://localhost:27017",
            maxPoolSize=10,
            minPoolSize=2,
            maxIdleTimeMS=30000,
            heartbeatFrequencyMS=10000,
            serverSelectionTimeoutMS=5000,
            retryWrites=True,
            retryReads=True
        )
        mock_client.admin.command.assert_called_once_with('ping')

    @patch('app.database.AsyncIOMotorClient')
    async def test_connect_to_mongo_failure(self, mock_client_class):
        from pymongo.errors import ConnectionFailure
        mock_client_class.side_effect = ConnectionFailure("Connection failed")

        with pytest.raises(ConnectionFailure):
            await connect_to_mongo()

    async def test_close_mongo_connection(self):
        # Set up a mock client
        from app.database import client
        mock_client = MagicMock()
        # Assuming client is set
        # This is tricky because it's global
        # Better to patch the global
        with patch('app.database.client', mock_client):
            await close_mongo_connection()
            mock_client.close.assert_called_once()

    def test_get_database(self):
        with patch('app.database.database', 'mock_db'):
            db = get_database()
            assert db == 'mock_db'

    @patch('app.database.get_database')
    async def test_create_indexes_success(self, mock_get_db):
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        # Mock collections with async create_index methods
        mock_users = AsyncMock()
        mock_projects = AsyncMock()
        mock_tasks = AsyncMock()
        mock_resources = AsyncMock()
        mock_rules = AsyncMock()

        mock_db.users = mock_users
        mock_db.projects = mock_projects
        mock_db.tasks = mock_tasks
        mock_db.resources = mock_resources
        mock_db.rules = mock_rules

        await create_indexes()

        mock_users.create_index.assert_called()
        mock_projects.create_index.assert_called()
        mock_tasks.create_index.assert_called()
        mock_resources.create_index.assert_called()
        mock_rules.create_index.assert_called()

    @patch('app.database.get_database')
    async def test_create_indexes_no_db(self, mock_get_db):
        mock_get_db.return_value = None

        with pytest.raises(Exception, match="Database connection is not established"):
            await create_indexes()
