import pytest
from unittest.mock import patch, AsyncMock
from app.database_migration import main

pytestmark = pytest.mark.asyncio

class TestDatabaseMigration:
    @patch('app.database_migration.connect_to_mongo', new_callable=AsyncMock)
    @patch('app.database_migration.create_indexes', new_callable=AsyncMock)
    @patch('app.database_migration.close_mongo_connection', new_callable=AsyncMock)
    async def test_main_success(self, mock_close, mock_create, mock_connect):
        await main()
        mock_connect.assert_called_once()
        mock_create.assert_called_once()
        mock_close.assert_called_once()

    @patch('app.database_migration.connect_to_mongo', new_callable=AsyncMock)
    @patch('app.database_migration.create_indexes', side_effect=Exception("Index creation failed"))
    @patch('app.database_migration.close_mongo_connection', new_callable=AsyncMock)
    async def test_main_failure(self, mock_close, mock_create, mock_connect):
        with pytest.raises(Exception, match="Index creation failed"):
            await main()
        mock_connect.assert_called_once()
        mock_create.assert_called_once()
        mock_close.assert_called_once()
