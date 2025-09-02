from typing import Dict, Any, List
from datetime import datetime
import re
import time
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
            start_time = time.time()
            if self._check_conditions(rule["conditions"], event_data):
                actions = await self._execute_actions(rule["actions"], event_data)
                triggered_actions.extend(actions)
                # Update performance metrics
                await self._update_rule_performance(rule["_id"], True, time.time() - start_time)
            else:
                await self._update_rule_performance(rule["_id"], False, time.time() - start_time)

        return triggered_actions

    async def _update_rule_performance(self, rule_id: str, success: bool, execution_time: float):
        """
        Update rule execution metrics for performance monitoring
        """
        rule = await self.db.rules.find_one({"_id": rule_id})
        if not rule:
            return
        execution_count = rule.get("execution_count", 0) + 1
        success_count = rule.get("success_count", 0) + (1 if success else 0)
        failure_count = rule.get("failure_count", 0) + (0 if success else 1)
        avg_time = rule.get("average_execution_time", 0.0)
        # Calculate new average execution time
        new_avg_time = ((avg_time * (execution_count - 1)) + execution_time) / execution_count

        await self.db.rules.update_one(
            {"_id": rule_id},
            {"$set": {
                "last_executed": datetime.utcnow(),
                "execution_count": execution_count,
                "success_count": success_count,
                "failure_count": failure_count,
                "average_execution_time": new_avg_time
            }}
        )

    async def trigger_rule_manually(self, rule_id: str, event_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Manually trigger a rule by ID with given event data
        """
        rule = await self.db.rules.find_one({"_id": rule_id, "active": True})
        if not rule:
            return [{"error": "Rule not found or inactive"}]

        start_time = time.time()
        triggered_actions = []
        if self._check_conditions(rule["conditions"], event_data):
            actions = await self._execute_actions(rule["actions"], event_data)
            triggered_actions.extend(actions)
            await self._update_rule_performance(rule["_id"], True, time.time() - start_time)
        else:
            await self._update_rule_performance(rule["_id"], False, time.time() - start_time)

        return triggered_actions

    async def get_scheduled_rules(self) -> List[Dict[str, Any]]:
        """
        Retrieve all active scheduled rules
        """
        rules = await self.db.rules.find({"active": True, "type": "scheduled"}).to_list(length=None)
        return rules

    async def execute_scheduled_rule(self, rule_id: str) -> List[Dict[str, Any]]:
        """
        Execute a scheduled rule by ID
        """
        rule = await self.db.rules.find_one({"_id": rule_id, "active": True, "type": "scheduled"})
        if not rule:
            return [{"error": "Scheduled rule not found or inactive"}]

        start_time = time.time()
        triggered_actions = []
        # For scheduled rules, event_data can be empty or predefined
        event_data = {}
        if self._check_conditions(rule["conditions"], event_data):
            actions = await self._execute_actions(rule["actions"], event_data)
            triggered_actions.extend(actions)
            await self._update_rule_performance(rule["_id"], True, time.time() - start_time)
        else:
            await self._update_rule_performance(rule["_id"], False, time.time() - start_time)

        return triggered_actions

    def _check_conditions(self, conditions: Dict[str, Any], event_data: Dict[str, Any]) -> bool:
        """
        Check if event data matches the rule conditions (supports nested $and, $or)
        """
        return self._evaluate_condition_group(conditions, event_data)

    def _evaluate_condition_group(self, conditions: Dict[str, Any], event_data: Dict[str, Any]) -> bool:
        """
        Evaluate a group of conditions, supporting $and, $or, and nested structures
        """
        if "$and" in conditions:
            return all(self._evaluate_condition_group(cond, event_data) for cond in conditions["$and"])
        elif "$or" in conditions:
            return any(self._evaluate_condition_group(cond, event_data) for cond in conditions["$or"])
        else:
            # Base conditions
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
                    elif "$in" in condition:
                        if event_data[key] not in condition["$in"]:
                            return False
                    elif "$nin" in condition:
                        if event_data[key] in condition["$nin"]:
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
        Create a GitHub issue based on rule action
        """
        from ..services.github_service import create_github_issue_from_rule

        repo_full_name = action_data.get("repo_full_name") or event_data.get("repository")
        if not repo_full_name:
            return {"error": "Repository full name not provided"}

        try:
            issue = await create_github_issue_from_rule(repo_full_name, action_data, event_data)
            return {
                "message": "GitHub issue created successfully",
                "issue_number": issue["number"],
                "issue_url": issue["html_url"],
                "title": issue["title"]
            }
        except Exception as e:
            return {"error": f"Failed to create GitHub issue: {str(e)}"}

    async def _send_notification(self, action_data: Dict[str, Any], event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send notification using the notification service
        """
        from ..services.notification_service import notification_service

        recipient = action_data.get("recipient")
        notification_type = action_data.get("notification_type", "email")
        template = action_data.get("template", "default")

        # Prepare notification data
        data = {
            "template": template,
            "message": action_data.get("message", ""),
            **event_data  # Include event data for template substitution
        }

        try:
            result = await notification_service.send_notification(recipient, notification_type, data)
            return result
        except Exception as e:
            return {"error": f"Failed to send notification: {str(e)}"}

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
