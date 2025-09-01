from typing import Dict, Any, List
from datetime import datetime
import re
from ..database import get_database
from ..models.rule import Rule
from ..models.task import Task, TaskStatus
from ..models.project import Project

class RuleEngine:
    def __init__(self):
        self.db = get_database()

    async def evaluate_rules(self, event_type: str, event_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Evaluate all active rules against the given event
        """
        rules = await self.db.rules.find({"active": True, "type": event_type}).to_list(length=None)
        triggered_actions = []

        for rule in rules:
            if self._check_conditions(rule["conditions"], event_data):
                actions = await self._execute_actions(rule["actions"], event_data)
                triggered_actions.extend(actions)

        return triggered_actions

    def _check_conditions(self, conditions: Dict[str, Any], event_data: Dict[str, Any]) -> bool:
        """
        Check if event data matches the rule conditions
        """
        for key, condition in conditions.items():
            if key not in event_data:
                return False

            if isinstance(condition, dict):
                # Handle complex conditions like {"$regex": "pattern"}
                if "$regex" in condition:
                    if not re.match(condition["$regex"], str(event_data[key])):
                        return False
                elif "$eq" in condition:
                    if event_data[key] != condition["$eq"]:
                        return False
                elif "$ne" in condition:
                    if event_data[key] == condition["$ne"]:
                        return False
                elif "$gt" in condition:
                    if not isinstance(event_data[key], (int, float)) or event_data[key] <= condition["$gt"]:
                        return False
                elif "$lt" in condition:
                    if not isinstance(event_data[key], (int, float)) or event_data[key] >= condition["$lt"]:
                        return False
            else:
                # Simple equality check
                if event_data[key] != condition:
                    return False

        return True

    async def _execute_actions(self, actions: List[Dict[str, Any]], event_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Execute the actions defined in the rule
        """
        executed_actions = []

        for action in actions:
            action_type = action.get("type")
            action_data = action.get("data", {})

            try:
                if action_type == "create_task":
                    result = await self._create_task_from_event(action_data, event_data)
                    executed_actions.append({"action": "create_task", "result": result})
                elif action_type == "update_task_status":
                    result = await self._update_task_status(action_data, event_data)
                    executed_actions.append({"action": "update_task_status", "result": result})
                elif action_type == "create_issue":
                    result = await self._create_github_issue(action_data, event_data)
                    executed_actions.append({"action": "create_issue", "result": result})
                elif action_type == "send_notification":
                    result = await self._send_notification(action_data, event_data)
                    executed_actions.append({"action": "send_notification", "result": result})
                else:
                    executed_actions.append({"action": action_type, "error": "Unknown action type"})
            except Exception as e:
                executed_actions.append({"action": action_type, "error": str(e)})

        return executed_actions

    async def _create_task_from_event(self, action_data: Dict[str, Any], event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a task based on event data
        """
        task_data = {
            "title": action_data.get("title", "Auto-generated task"),
            "description": action_data.get("description", ""),
            "project_id": action_data.get("project_id"),
            "assignee_id": action_data.get("assignee_id"),
            "status": TaskStatus.TODO,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        # Replace placeholders in title and description
        task_data["title"] = self._replace_placeholders(task_data["title"], event_data)
        task_data["description"] = self._replace_placeholders(task_data["description"], event_data)

        result = await self.db.tasks.insert_one(task_data)
        return {"task_id": str(result.inserted_id), "message": "Task created successfully"}

    async def _update_task_status(self, action_data: Dict[str, Any], event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update task status based on event data
        """
        task_id = action_data.get("task_id")
        new_status = action_data.get("status", "in_progress")

        if not task_id:
            return {"error": "Task ID not provided"}

        # Find task by ID or by pattern matching
        if task_id.startswith("pattern:"):
            pattern = task_id.replace("pattern:", "")
            # Find task that matches the pattern in title or description
            task = await self.db.tasks.find_one({"title": {"$regex": pattern}})
            if not task:
                return {"error": "No task found matching pattern"}
            task_id = task["_id"]

        await self.db.tasks.update_one(
            {"_id": task_id},
            {"$set": {"status": new_status, "updated_at": datetime.utcnow()}}
        )

        return {"task_id": task_id, "new_status": new_status, "message": "Task status updated"}

    async def _create_github_issue(self, action_data: Dict[str, Any], event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a GitHub issue (placeholder - would integrate with GitHub API)
        """
        # This would integrate with GitHub API to create issues
        # For now, just return a placeholder response
        return {
            "message": "GitHub issue creation would be implemented here",
            "title": action_data.get("title", "Auto-generated issue"),
            "body": action_data.get("body", "")
        }

    async def _send_notification(self, action_data: Dict[str, Any], event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send notification (placeholder - would integrate with notification service)
        """
        # This would integrate with email/SMS/push notification services
        return {
            "message": "Notification sent",
            "recipient": action_data.get("recipient"),
            "type": action_data.get("notification_type", "email")
        }

    def _replace_placeholders(self, text: str, event_data: Dict[str, Any]) -> str:
        """
        Replace placeholders in text with event data
        """
        if not text:
            return text

        # Replace common placeholders
        replacements = {
            "{commit_message}": event_data.get("commit_message", ""),
            "{branch}": event_data.get("branch", "main"),
            "{author}": event_data.get("author", ""),
            "{repository}": event_data.get("repository", ""),
            "{pull_request_title}": event_data.get("pull_request_title", ""),
            "{issue_title}": event_data.get("issue_title", ""),
        }

        for placeholder, value in replacements.items():
            text = text.replace(placeholder, str(value))

        return text

# Global rule engine instance
rule_engine = RuleEngine()
