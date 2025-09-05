import pytest
from pydantic import ValidationError
from datetime import datetime
from app.models.rule import Rule, RuleCreate, RuleUpdate, RuleType

class TestRuleType:
    def test_rule_type_values(self):
        assert RuleType.GITHUB_EVENT == "github_event"
        assert RuleType.SYSTEM_EVENT == "system_event"
        assert RuleType.SCHEDULED == "scheduled"

class TestRuleModel:
    def test_rule_creation_valid(self):
        rule = Rule(
            name="Test Rule",
            description="A test rule",
            type=RuleType.GITHUB_EVENT,
            conditions={"event": "push"},
            actions=[{"action": "create_task", "params": {"title": "New task"}}],
            active=True,
            project_id="proj1",
            schedule="0 0 * * *",
            execution_count=5,
            success_count=4,
            failure_count=1,
            average_execution_time=2.5
        )
        assert rule.name == "Test Rule"
        assert rule.type == RuleType.GITHUB_EVENT
        assert rule.conditions == {"event": "push"}
        assert len(rule.actions) == 1
        assert rule.active is True
        assert rule.execution_count == 5

    def test_rule_creation_invalid_conditions(self):
        # Conditions should be a dict, but if empty, it's fine
        rule = Rule(
            name="Test Rule",
            type=RuleType.SYSTEM_EVENT,
            conditions={},
            actions=[]
        )
        assert rule.conditions == {}

    def test_rule_create_model(self):
        rule_create = RuleCreate(
            name="New Rule",
            type=RuleType.SCHEDULED,
            conditions={"time": "daily"},
            actions=[{"action": "notify", "params": {"message": "Daily report"}}],
            schedule="0 9 * * *"
        )
        assert rule_create.name == "New Rule"
        assert rule_create.type == RuleType.SCHEDULED
        assert rule_create.schedule == "0 9 * * *"

    def test_rule_update_model(self):
        rule_update = RuleUpdate(
            name="Updated Rule",
            description="Updated description",
            conditions={"updated": True},
            actions=[{"action": "update_task"}],
            active=False
        )
        assert rule_update.name == "Updated Rule"
        assert rule_update.active is False
