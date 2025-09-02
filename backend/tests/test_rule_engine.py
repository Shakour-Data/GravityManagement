import pytest
import sys
import os
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app")))

from backend.app.services.rule_engine import RuleEngine
from backend.app.models.task import TaskStatus


class TestRuleEngine:
    @pytest.fixture
    def rule_engine(self):
        engine = RuleEngine()
        engine.db = AsyncMock()
        return engine

    @pytest.mark.asyncio
    async def test_evaluate_rules_no_matching_rules(self, rule_engine):
        """Test evaluating rules when no rules match"""
        event_type = "github_event"
        event_data = {"repository": "user/repo", "action": "push"}

        rule_engine.db.rules.find = MagicMock()
        rule_engine.db.rules.find.return_value.to_list = AsyncMock(return_value=[])

        result = await rule_engine.evaluate_rules(event_type, event_data)

        assert result == []
        rule_engine.db.rules.find.assert_called_once_with({"active": True, "type": event_type})

    @pytest.mark.asyncio
    async def test_evaluate_rules_with_matching_rules(self, rule_engine):
        """Test evaluating rules with matching conditions"""
        event_type = "github_event"
        event_data = {"repository": "user/repo", "action": "push", "branch": "main"}

        mock_rule = {
            "active": True,
            "type": "github_event",
            "conditions": {"action": "push", "branch": "main"},
            "actions": [{"type": "create_task", "data": {"title": "Test task"}}]
        }

        rule_engine.db.rules.find = MagicMock()
        rule_engine.db.rules.find.return_value.to_list = AsyncMock(return_value=[mock_rule])

        with patch.object(rule_engine, '_execute_actions', new_callable=AsyncMock) as mock_execute:
            mock_execute.return_value = [{"action": "create_task", "result": {"task_id": "123"}}]

            result = await rule_engine.evaluate_rules(event_type, event_data)

            assert len(result) == 1
            assert result[0]["action"] == "create_task"
            mock_execute.assert_called_once()

    def test_check_conditions_simple_equality(self, rule_engine):
        """Test checking simple equality conditions"""
        conditions = {"action": "push", "branch": "main"}
        event_data = {"action": "push", "branch": "main", "repository": "user/repo"}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == True

    def test_check_conditions_simple_inequality(self, rule_engine):
        """Test checking conditions that don't match"""
        conditions = {"action": "push", "branch": "develop"}
        event_data = {"action": "push", "branch": "main"}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == False

    def test_check_conditions_regex(self, rule_engine):
        """Test checking regex conditions"""
        conditions = {"commit_message": {"$regex": "fix.*bug"}}
        event_data = {"commit_message": "fix critical bug"}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == True

    def test_check_conditions_regex_no_match(self, rule_engine):
        """Test checking regex conditions that don't match"""
        conditions = {"commit_message": {"$regex": "fix.*bug"}}
        event_data = {"commit_message": "add new feature"}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == False

    def test_check_conditions_numeric_comparison(self, rule_engine):
        """Test checking numeric comparison conditions"""
        conditions = {"commits": {"$gt": 5}}
        event_data = {"commits": 10}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == True

    def test_check_conditions_numeric_comparison_false(self, rule_engine):
        """Test checking numeric comparison conditions that fail"""
        conditions = {"commits": {"$gt": 5}}
        event_data = {"commits": 3}

        result = rule_engine._check_conditions(conditions, event_data)
        assert result == False

    @pytest.mark.asyncio
    async def test_execute_actions_create_task(self, rule_engine):
        """Test executing create_task action"""
        actions = [{"type": "create_task", "data": {"title": "Test task", "project_id": "proj123"}}]
        event_data = {"repository": "user/repo"}

        rule_engine.db.tasks.insert_one = AsyncMock()
        rule_engine.db.tasks.insert_one.return_value = MagicMock(inserted_id="task123")

        result = await rule_engine._execute_actions(actions, event_data)

        assert len(result) == 1
        assert result[0]["action"] == "create_task"
        assert "task_id" in result[0]["result"]
        rule_engine.db.tasks.insert_one.assert_called_once()

    @pytest.mark.asyncio
    async def test_execute_actions_update_task_status(self, rule_engine):
        """Test executing update_task_status action"""
        actions = [{"type": "update_task_status", "data": {"task_id": "task123", "status": "in_progress"}}]
        event_data = {}

        rule_engine.db.tasks.update_one = AsyncMock()

        result = await rule_engine._execute_actions(actions, event_data)

        assert len(result) == 1
        assert result[0]["action"] == "update_task_status"
        rule_engine.db.tasks.update_one.assert_called_once()

    @pytest.mark.asyncio
    async def test_execute_actions_create_github_issue(self, rule_engine):
        """Test executing create_github_issue action"""
        actions = [{"type": "create_issue", "data": {"title": "Test issue"}}]
        event_data = {}

        result = await rule_engine._execute_actions(actions, event_data)

        assert len(result) == 1
        assert result[0]["action"] == "create_issue"
        assert result[0]["result"]["title"] == "Test issue"

    @pytest.mark.asyncio
    async def test_execute_actions_send_notification(self, rule_engine):
        """Test executing send_notification action"""
        actions = [{"type": "send_notification", "data": {"recipient": "user@example.com"}}]
        event_data = {}

        result = await rule_engine._execute_actions(actions, event_data)

        assert len(result) == 1
        assert result[0]["action"] == "send_notification"
        assert result[0]["result"]["recipient"] == "user@example.com"

    @pytest.mark.asyncio
    async def test_execute_actions_unknown_type(self, rule_engine):
        """Test executing unknown action type"""
        actions = [{"type": "unknown_action", "data": {}}]
        event_data = {}

        result = await rule_engine._execute_actions(actions, event_data)

        assert len(result) == 1
        assert result[0]["action"] == "unknown_action"
        assert "error" in result[0]

    @pytest.mark.asyncio
    async def test_create_task_from_event(self, rule_engine):
        """Test creating task from event data"""
        action_data = {
            "title": "Task for {repository}",
            "description": "Commit: {commit_message}",
            "project_id": "proj123"
        }
        event_data = {
            "repository": "user/repo",
            "commit_message": "Fix bug",
            "author": "testuser"
        }

        rule_engine.db.tasks.insert_one = AsyncMock()
        rule_engine.db.tasks.insert_one.return_value = MagicMock(inserted_id="task123")

        result = await rule_engine._create_task_from_event(action_data, event_data)

        assert result["task_id"] == "task123"
        assert result["message"] == "Task created successfully"

        # Check that placeholders were replaced
        call_args = rule_engine.db.tasks.insert_one.call_args[0][0]
        assert call_args["title"] == "Task for user/repo"
        assert call_args["description"] == "Commit: Fix bug"

    @pytest.mark.asyncio
    async def test_update_task_status_by_id(self, rule_engine):
        """Test updating task status by ID"""
        action_data = {"task_id": "task123", "status": "completed"}
        event_data = {}

        rule_engine.db.tasks.update_one = AsyncMock()

        result = await rule_engine._update_task_status(action_data, event_data)

        assert result["task_id"] == "task123"
        assert result["new_status"] == "completed"
        rule_engine.db.tasks.update_one.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_task_status_by_pattern(self, rule_engine):
        """Test updating task status by pattern matching"""
        action_data = {"task_id": "pattern:bug fix", "status": "in_progress"}
        event_data = {}

        mock_task = {"_id": "task123", "title": "Fix critical bug"}
        rule_engine.db.tasks.find_one = AsyncMock(return_value=mock_task)
        rule_engine.db.tasks.update_one = AsyncMock()

        result = await rule_engine._update_task_status(action_data, event_data)

        assert result["task_id"] == "task123"
        rule_engine.db.tasks.find_one.assert_called_once_with({"title": {"$regex": "bug fix"}})

    def test_replace_placeholders(self, rule_engine):
        """Test replacing placeholders in text"""
        text = "Commit: {commit_message} by {author} on {branch}"
        event_data = {
            "commit_message": "Fix bug",
            "author": "testuser",
            "branch": "main",
            "repository": "user/repo"
        }

        result = rule_engine._replace_placeholders(text, event_data)

        assert result == "Commit: Fix bug by testuser on main"

    def test_replace_placeholders_no_text(self, rule_engine):
        """Test replacing placeholders when text is None"""
        result = rule_engine._replace_placeholders(None, {})
        assert result is None

    def test_replace_placeholders_empty_text(self, rule_engine):
        """Test replacing placeholders when text is empty"""
        result = rule_engine._replace_placeholders("", {})
        assert result == ""
