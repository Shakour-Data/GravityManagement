import pytest
import sys
import os
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient
from fastapi import HTTPException
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app")))

from app.database import get_database
from app.models.user import User
from app.routers.github_integration import router as github_router
from fastapi import FastAPI


class TestGitHubIntegrationRouter:
    @pytest.fixture
    def mock_db(self):
        """Mock database for testing"""
        return AsyncMock()

    @pytest.fixture
    def client(self, mock_db, mock_user):
        """Create a test client with mocked database"""
        # Create a test app with only the GitHub router
        test_app = FastAPI()
        test_app.include_router(github_router, prefix="/github")

        with patch('app.routers.github_integration.get_database', return_value=mock_db):
            # Override the router's dependencies to bypass authentication
            from app.routers.github_integration import get_current_user
            test_app.dependency_overrides[get_current_user] = lambda: mock_user
            client = TestClient(test_app)
            yield client

    @pytest.fixture
    def unauthenticated_client(self, mock_db):
        """Create a test client without authentication"""
        # Create a test app with only the GitHub router
        test_app = FastAPI()
        test_app.include_router(github_router, prefix="/github")

        with patch('app.routers.github_integration.get_database', return_value=mock_db):
            client = TestClient(test_app)
            yield client

    @pytest.fixture
    def mock_user(self):
        """Mock user for testing"""
        return User(
            id="user123",
            username="testuser",
            email="test@example.com",
            full_name="Test User",
            disabled=False,
            role="user",
            github_id="github123",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

    @pytest.fixture
    def mock_user_no_github(self):
        """Mock user without GitHub connection"""
        return User(
            id="user456",
            username="testuser2",
            email="test2@example.com",
            full_name="Test User 2",
            disabled=False,
            role="user",
            github_id=None,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

    def test_github_webhook_success(self, client):
        """Test successful GitHub webhook processing"""
        webhook_payload = {
            "action": "push",
            "repository": {
                "full_name": "test/repo",
                "name": "repo",
                "owner": {"login": "test"}
            },
            "commits": [
                {
                    "id": "abc123",
                    "message": "Test commit",
                    "author": {"name": "Test User", "email": "test@example.com"}
                }
            ]
        }

        mock_result = {
            "status": "processed",
            "event_type": "push",
            "repository": "test/repo",
            "commits_processed": 1
        }

        with patch('app.routers.github_integration.process_github_webhook', new_callable=AsyncMock) as mock_process:
            mock_process.return_value = mock_result

            response = client.post(
                "/github/webhook",
                json=webhook_payload,
                headers={
                    "X-GitHub-Event": "push",
                    "X-Hub-Signature-256": "sha256=test_signature"
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "processed"
            assert data["event_type"] == "push"
            mock_process.assert_called_once_with("push", webhook_payload, "sha256=test_signature")

    def test_github_webhook_missing_event_type(self, client):
        """Test GitHub webhook with missing event type"""
        webhook_payload = {"action": "push"}

        response = client.post("/github/webhook", json=webhook_payload)

        assert response.status_code == 400
        data = response.json()
        assert "Missing GitHub event type" in data["detail"]

    def test_github_webhook_processing_error(self, client):
        """Test GitHub webhook processing error"""
        webhook_payload = {"action": "push"}

        with patch('app.routers.github_integration.process_github_webhook', new_callable=AsyncMock) as mock_process:
            mock_process.side_effect = Exception("Processing failed")

            response = client.post(
                "/github/webhook",
                json=webhook_payload,
                headers={
                    "X-GitHub-Event": "push",
                    "X-Hub-Signature-256": "sha256=test_signature"
                }
            )

            assert response.status_code == 500

    def test_sync_repository_success(self, client):
        """Test successful repository synchronization"""
        mock_result = {
            "status": "synced",
            "repository": "test/repo",
            "project_id": "project123",
            "commits_synced": 5,
            "issues_synced": 2
        }

        # Patch the correct service function
        with patch('app.services.github_service.sync_repository_data', new_callable=AsyncMock) as mock_sync:
            mock_sync.return_value = mock_result

            # Send form data instead of JSON
            response = client.post(
                "/github/sync",
                data={"repo_full_name": "test/repo", "project_id": "project123"}
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "synced"
            assert data["repository"] == "test/repo"
            mock_sync.assert_called_once_with("test/repo", "project123")

    def test_sync_repository_error(self, client):
        """Test repository synchronization error"""
        # Patch the correct service function
        with patch('app.services.github_service.sync_repository_data', new_callable=AsyncMock) as mock_sync:
            mock_sync.side_effect = Exception("Sync failed")

            # Send form data instead of JSON
            response = client.post(
                "/github/sync",
                data={"repo_full_name": "test/repo", "project_id": "project123"}
            )

            assert response.status_code == 500

    def test_get_user_repos_success(self, client, mock_db, mock_user):
        """Test getting user repositories successfully"""
        mock_repos = [
            {
                "id": 123,
                "name": "repo1",
                "full_name": "testuser/repo1",
                "private": False,
                "html_url": "https://github.com/testuser/repo1",
                "description": "Test repository 1"
            },
            {
                "id": 456,
                "name": "repo2",
                "full_name": "testuser/repo2",
                "private": True,
                "html_url": "https://github.com/testuser/repo2",
                "description": "Test repository 2"
            }
        ]

        mock_db.users.find_one = AsyncMock(return_value={"github_id": "github123"})

        with patch('app.routers.github_integration.get_github_repos', new_callable=AsyncMock) as mock_get_repos:
            mock_get_repos.return_value = mock_repos

            # Mock authentication by patching the dependency in the GitHub router
            with patch('app.routers.github_integration.get_current_user', return_value=mock_user):
                    response = client.get("/github/repos")

                    assert response.status_code == 200
                    data = response.json()
                    assert len(data) == 2
                    assert data[0]["name"] == "repo1"
                    assert data[1]["name"] == "repo2"
                    mock_get_repos.assert_called_once_with("github123")

    def test_get_user_repos_not_connected(self, unauthenticated_client, mock_user_no_github):
        """Test getting repositories when GitHub is not connected"""
        # Create a test app with the user override
        test_app = FastAPI()
        test_app.include_router(github_router, prefix="/github")

        with patch('app.routers.github_integration.get_database', return_value=AsyncMock()):
            from app.routers.github_integration import get_current_user
            test_app.dependency_overrides[get_current_user] = lambda: mock_user_no_github
            client = TestClient(test_app)

            response = client.get("/github/repos")

            assert response.status_code == 400
            data = response.json()
            assert "GitHub not connected" in data["detail"]

    def test_get_user_repos_github_error(self, client, mock_user):
        """Test getting repositories with GitHub API error"""
        with patch('app.routers.github_integration.get_github_repos', new_callable=AsyncMock) as mock_get_repos:
            mock_get_repos.side_effect = Exception("GitHub API error")

            # Mock authentication by patching the dependency in the GitHub router
            with patch('app.routers.github_integration.get_current_user', return_value=mock_user):
                response = client.get("/github/repos")

                assert response.status_code == 500

    def test_connect_github_success(self, client, mock_db, mock_user):
        """Test successful GitHub connection"""
        mock_db.users.update_one = AsyncMock()

        # Mock authentication by patching the dependency in the GitHub router
        with patch('app.routers.github_integration.get_current_user', return_value=mock_user):
            response = client.post(
                "/github/connect",
                json={"github_token": "test_token_123"}
            )

            assert response.status_code == 200
            data = response.json()
            assert "GitHub connected successfully" in data["message"]

            # Verify database update was called
            mock_db.users.update_one.assert_called_once_with(
                {"username": "testuser"},
                {"$set": {"github_token": "test_token_123"}}
            )

    def test_connect_github_database_error(self, client, mock_db, mock_user):
        """Test GitHub connection with database error"""
        mock_db.users.update_one = AsyncMock(side_effect=Exception("Database error"))

        # Mock authentication by patching the dependency in the GitHub router
        with patch('app.routers.github_integration.get_current_user', return_value=mock_user):
            response = client.post(
                "/github/connect",
                json={"github_token": "test_token_123"}
            )

            assert response.status_code == 500

    def test_github_webhook_unauthenticated_request(self, client):
        """Test that webhook endpoint doesn't require authentication"""
        webhook_payload = {"action": "push"}

        response = client.post("/github/webhook", json=webhook_payload)

        # Should fail due to missing event type, not authentication
        assert response.status_code == 400
        data = response.json()
        assert "Missing GitHub event type" in data["detail"]

    def test_sync_repository_unauthenticated(self, client):
        """Test sync repository without authentication - should work without auth"""
        mock_result = {
            "status": "synced",
            "repository": "test/repo",
            "project_id": "project123",
            "commits_synced": 5,
            "issues_synced": 2
        }

        # Patch the correct service function
        with patch('app.services.github_service.sync_repository_data', new_callable=AsyncMock) as mock_sync:
            mock_sync.return_value = mock_result

            # Send form data instead of JSON
            response = client.post(
                "/github/sync",
                data={"repo_full_name": "test/repo", "project_id": "project123"}
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "synced"
            mock_sync.assert_called_once_with("test/repo", "project123")

    def test_get_user_repos_unauthenticated(self, unauthenticated_client):
        """Test getting repositories without authentication"""
        response = unauthenticated_client.get("/github/repos")

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_connect_github_unauthenticated(self, unauthenticated_client):
        """Test connecting GitHub without authentication"""
        response = unauthenticated_client.post(
            "/github/connect",
            json={"github_token": "test_token_123"}
        )

        assert response.status_code == 401
        data = response.json()
        assert "Not authenticated" in data["detail"]

    def test_github_webhook_pull_request_event(self, client):
        """Test GitHub webhook with pull request event"""
        webhook_payload = {
            "action": "opened",
            "pull_request": {
                "id": 123,
                "number": 1,
                "title": "Test PR",
                "body": "Test pull request",
                "state": "open",
                "user": {"login": "testuser"}
            },
            "repository": {
                "full_name": "test/repo",
                "name": "repo"
            }
        }

        mock_result = {
            "status": "processed",
            "event_type": "pull_request",
            "action": "opened",
            "pull_request_number": 1
        }

        with patch('app.routers.github_integration.process_github_webhook', new_callable=AsyncMock) as mock_process:
            mock_process.return_value = mock_result

            response = client.post(
                "/github/webhook",
                json=webhook_payload,
                headers={
                    "X-GitHub-Event": "pull_request",
                    "X-Hub-Signature-256": "sha256=test_signature"
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert data["event_type"] == "pull_request"
            assert data["action"] == "opened"

    def test_github_webhook_issues_event(self, client):
        """Test GitHub webhook with issues event"""
        webhook_payload = {
            "action": "opened",
            "issue": {
                "id": 456,
                "number": 1,
                "title": "Test Issue",
                "body": "Test issue description",
                "state": "open",
                "user": {"login": "testuser"}
            },
            "repository": {
                "full_name": "test/repo",
                "name": "repo"
            }
        }

        mock_result = {
            "status": "processed",
            "event_type": "issues",
            "action": "opened",
            "issue_number": 1
        }

        with patch('app.routers.github_integration.process_github_webhook', new_callable=AsyncMock) as mock_process:
            mock_process.return_value = mock_result

            response = client.post(
                "/github/webhook",
                json=webhook_payload,
                headers={
                    "X-GitHub-Event": "issues",
                    "X-Hub-Signature-256": "sha256=test_signature"
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert data["event_type"] == "issues"
            assert data["issue_number"] == 1
