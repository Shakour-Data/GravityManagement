import pytest
import sys
import os
from unittest.mock import patch, MagicMock, AsyncMock
import hmac
import hashlib

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app")))

from backend.app.services.github_service import (
    verify_github_signature,
    process_github_webhook,
    extract_event_data,
    get_github_repos,
    create_github_issue,
    get_github_commits
)


class TestGitHubService:
    def test_verify_github_signature_valid(self):
        """Test signature verification with valid signature"""
        payload = b'{"test": "data"}'
        secret = "test-secret"
        expected_signature = hmac.new(
            secret.encode(),
            payload,
            hashlib.sha256
        ).hexdigest()
        signature = f"sha256={expected_signature}"

        with patch('backend.app.services.github_service.GITHUB_WEBHOOK_SECRET', secret):
            assert verify_github_signature(payload, signature) == True

    def test_verify_github_signature_invalid(self):
        """Test signature verification with invalid signature"""
        payload = b'{"test": "data"}'
        signature = "sha256=invalid"

        with patch('backend.app.services.github_service.GITHUB_WEBHOOK_SECRET', "test-secret"):
            assert verify_github_signature(payload, signature) == False

    def test_verify_github_signature_no_secret(self):
        """Test signature verification when no secret is set"""
        payload = b'{"test": "data"}'
        signature = "sha256=any"

        with patch('backend.app.services.github_service.GITHUB_WEBHOOK_SECRET', ""):
            assert verify_github_signature(payload, signature) == True

    @pytest.mark.asyncio
    async def test_process_github_webhook_push_event(self):
        """Test processing push event webhook"""
        event_type = "push"
        payload = {
            "repository": {"full_name": "user/repo"},
            "sender": {"login": "user"},
            "ref": "refs/heads/main",
            "commits": [{"message": "Test commit", "author": {"name": "Test Author"}}],
            "head_commit": {"message": "Test commit", "author": {"name": "Test Author"}}
        }

        with patch('backend.app.services.github_service.rule_engine') as mock_rule_engine:
            mock_rule_engine.evaluate_rules = AsyncMock(return_value=[{"action": "test"}])

            result = await process_github_webhook(event_type, payload)

            assert result["event_type"] == "push"
            assert result["processed"] == True
            assert "triggered_actions" in result
            assert "event_data" in result
            mock_rule_engine.evaluate_rules.assert_called_once()

    @pytest.mark.asyncio
    async def test_process_github_webhook_invalid_signature(self):
        """Test processing webhook with invalid signature"""
        event_type = "push"
        payload = {"test": "data"}
        signature = "sha256=invalid"

        with patch('backend.app.services.github_service.GITHUB_WEBHOOK_SECRET', "test-secret"):
            with pytest.raises(Exception):  # HTTPException
                await process_github_webhook(event_type, payload, signature)

    def test_extract_event_data_push(self):
        """Test extracting data from push event"""
        event_type = "push"
        payload = {
            "repository": {"full_name": "user/repo"},
            "sender": {"login": "user"},
            "ref": "refs/heads/feature-branch",
            "commits": [{"message": "Test commit", "author": {"name": "Test Author"}}],
            "head_commit": {"message": "Test commit", "author": {"name": "Test Author"}}
        }

        result = extract_event_data(event_type, payload)

        assert result["event_type"] == "push"
        assert result["repository"] == "user/repo"
        assert result["sender"] == "user"
        assert result["branch"] == "feature-branch"
        assert result["commits"] == 1
        assert result["commit_message"] == "Test commit"
        assert result["author"] == "Test Author"

    def test_extract_event_data_pull_request(self):
        """Test extracting data from pull request event"""
        event_type = "pull_request"
        payload = {
            "repository": {"full_name": "user/repo"},
            "sender": {"login": "user"},
            "action": "opened",
            "pull_request": {
                "title": "Test PR",
                "number": 123,
                "state": "open",
                "body": "Test description",
                "base": {"ref": "main"},
                "head": {"ref": "feature-branch"}
            }
        }

        result = extract_event_data(event_type, payload)

        assert result["event_type"] == "pull_request"
        assert result["pull_request_title"] == "Test PR"
        assert result["pull_request_number"] == 123
        assert result["base_branch"] == "main"
        assert result["head_branch"] == "feature-branch"

    def test_extract_event_data_issues(self):
        """Test extracting data from issues event"""
        event_type = "issues"
        payload = {
            "repository": {"full_name": "user/repo"},
            "sender": {"login": "user"},
            "action": "opened",
            "issue": {
                "title": "Test Issue",
                "number": 456,
                "state": "open",
                "body": "Issue description",
                "labels": [{"name": "bug"}, {"name": "high-priority"}]
            }
        }

        result = extract_event_data(event_type, payload)

        assert result["event_type"] == "issues"
        assert result["issue_title"] == "Test Issue"
        assert result["issue_number"] == 456
        assert result["issue_labels"] == ["bug", "high-priority"]

    def test_extract_event_data_release(self):
        """Test extracting data from release event"""
        event_type = "release"
        payload = {
            "repository": {"full_name": "user/repo"},
            "sender": {"login": "user"},
            "action": "published",
            "release": {
                "tag_name": "v1.0.0",
                "name": "Release v1.0.0",
                "body": "Release notes",
                "prerelease": False
            }
        }

        result = extract_event_data(event_type, payload)

        assert result["event_type"] == "release"
        assert result["release_tag"] == "v1.0.0"
        assert result["release_name"] == "Release v1.0.0"
        assert result["release_prerelease"] == False

    @pytest.mark.asyncio
    async def test_get_github_repos(self):
        """Test getting GitHub repositories (stub implementation)"""
        result = await get_github_repos("user123")

        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0]["name"] == "example-repo"
        assert result[0]["full_name"] == "user/example-repo"

    @pytest.mark.asyncio
    async def test_create_github_issue(self):
        """Test creating GitHub issue (stub implementation)"""
        result = await create_github_issue("user/repo", "Test Issue", "Issue body", ["bug"])

        assert result["title"] == "Test Issue"
        assert result["body"] == "Issue body"
        assert result["state"] == "open"
        assert result["labels"] == ["bug"]
        assert "html_url" in result

    @pytest.mark.asyncio
    async def test_get_github_commits(self):
        """Test getting GitHub commits (stub implementation)"""
        result = await get_github_commits("user/repo", "main")

        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0]["message"] == "Example commit message"
        assert result[0]["author"] == "example-user"
