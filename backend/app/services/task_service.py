from typing import List, Optional, Dict, Any
from datetime import datetime
from ..database import get_database
from ..models.task import Task, TaskCreate, TaskUpdate, TaskStatus
from ..models.user import User
from .exceptions import (
    ValidationError, AuthorizationError, NotFoundError, ConflictError,
    BusinessLogicError, raise_validation_error, raise_authorization_error,
    raise_not_found_error, raise_conflict_error, raise_business_logic_error
)

class TaskService:
    def __init__(self):
        self.db = get_database()

    async def create_task(self, task_data: TaskCreate, user: User) -> Task:
        """
        Create a new task with validation and business logic
        """
        # Validate task data
        await self._validate_task_data(task_data, user)

        # Create task document
        task_dict = task_data.dict()
        task_dict.update({
            "status": TaskStatus.TODO,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await self.db.tasks.insert_one(task_dict)
        created_task = await self.db.tasks.find_one({"_id": result.inserted_id})

        return Task(**created_task)

    async def get_task(self, task_id: str, user: User) -> Task:
        """
        Get a task with access control
        """
        task = await self.db.tasks.find_one({"_id": task_id})
        if not task:
            raise_not_found_error("Task", task_id)

        # Check project access
        await self._check_project_access(task["project_id"], user)

        return Task(**task)

    async def get_project_tasks(self, project_id: str, user: User, status_filter: Optional[TaskStatus] = None) -> List[Task]:
        """
        Get all tasks for a project with optional status filter
        """
        # Check project access
        await self._check_project_access(project_id, user)

        query = {"project_id": project_id}
        if status_filter:
            query["status"] = status_filter

        tasks = await self.db.tasks.find(query).sort("created_at", -1).to_list(length=None)
        return [Task(**task) for task in tasks]

    async def get_user_assigned_tasks(self, user: User, status_filter: Optional[TaskStatus] = None) -> List[Task]:
        """
        Get all tasks assigned to a user
        """
        query = {"assignee_id": user.username}
        if status_filter:
            query["status"] = status_filter

        tasks = await self.db.tasks.find(query).sort("due_date", 1).to_list(length=None)
        return [Task(**task) for task in tasks]

    async def update_task(self, task_id: str, update_data: TaskUpdate, user: User) -> Task:
        """
        Update a task with validation and business logic
        """
        # Get existing task
        task = await self.get_task(task_id, user)

        # Validate update data
        await self._validate_task_update(update_data, task, user)

        # Prepare update document
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()

        await self.db.tasks.update_one({"_id": task_id}, {"$set": update_dict})

        # Get updated task
        updated_task = await self.db.tasks.find_one({"_id": task_id})
        return Task(**updated_task)

    async def update_task_status(self, task_id: str, new_status: TaskStatus, user: User) -> Task:
        """
        Update task status with business logic validation
        """
        task = await self.get_task(task_id, user)

        # Validate status transition
        await self._validate_status_transition(task.status, new_status, user, task)

        await self.db.tasks.update_one(
            {"_id": task_id},
            {
                "$set": {
                    "status": new_status,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        updated_task = await self.db.tasks.find_one({"_id": task_id})
        return Task(**updated_task)

    async def assign_task(self, task_id: str, assignee_username: str, user: User) -> Task:
        """
        Assign a task to a user
        """
        task = await self.get_task(task_id, user)

        # Check if assignee exists and has project access
        await self._check_project_access(task.project_id, User(username=assignee_username))

        await self.db.tasks.update_one(
            {"_id": task_id},
            {
                "$set": {
                    "assignee_id": assignee_username,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        updated_task = await self.db.tasks.find_one({"_id": task_id})
        return Task(**updated_task)

    async def delete_task(self, task_id: str, user: User) -> bool:
        """
        Delete a task
        """
        task = await self.get_task(task_id, user)

        # Only assignee or project owner can delete
        project = await self.db.projects.find_one({"_id": task.project_id})
        if user.username != task.assignee_id and user.username != project["owner_id"]:
            raise_authorization_error("Not authorized to delete this task")

        result = await self.db.tasks.delete_one({"_id": task_id})
        return result.deleted_count > 0

    async def get_overdue_tasks(self, user: User) -> List[Task]:
        """
        Get overdue tasks for user's projects
        """
        # Get user's projects
        user_projects = await self.db.projects.find({
            "$or": [
                {"owner_id": user.username},
                {"team_members": user.username}
            ]
        }).to_list(length=None)

        project_ids = [p["_id"] for p in user_projects]

        # Find overdue tasks
        overdue_tasks = await self.db.tasks.find({
            "project_id": {"$in": project_ids},
            "due_date": {"$lt": datetime.utcnow()},
            "status": {"$ne": TaskStatus.DONE}
        }).sort("due_date", 1).to_list(length=None)

        return [Task(**task) for task in overdue_tasks]

    async def get_task_stats(self, project_id: str, user: User) -> Dict[str, Any]:
        """
        Get task statistics for a project
        """
        await self._check_project_access(project_id, user)

        # Count tasks by status
        task_stats = await self.db.tasks.aggregate([
            {"$match": {"project_id": project_id}},
            {"$group": {"_id": "$status", "count": {"$sum": 1}}}
        ]).to_list(length=None)

        # Count tasks by assignee
        assignee_stats = await self.db.tasks.aggregate([
            {"$match": {"project_id": project_id, "assignee_id": {"$ne": None}}},
            {"$group": {"_id": "$assignee_id", "count": {"$sum": 1}}}
        ]).to_list(length=None)

        # Count overdue tasks
        overdue_count = await self.db.tasks.count_documents({
            "project_id": project_id,
            "due_date": {"$lt": datetime.utcnow()},
            "status": {"$ne": TaskStatus.DONE}
        })

        return {
            "project_id": project_id,
            "status_breakdown": {stat["_id"]: stat["count"] for stat in task_stats},
            "assignee_breakdown": {stat["_id"]: stat["count"] for stat in assignee_stats},
            "overdue_count": overdue_count,
            "total_tasks": sum(stat["count"] for stat in task_stats)
        }

    async def _validate_task_data(self, task_data: TaskCreate, user: User):
        """
        Validate task creation data
        """
        if not task_data.title or len(task_data.title.strip()) < 3:
            raise_validation_error("Task title must be at least 3 characters", "title")

        # Check project access
        await self._check_project_access(task_data.project_id, user)

        # Validate due date
        if task_data.due_date and task_data.due_date <= datetime.utcnow():
            raise_business_logic_error("Due date must be in the future", "due_date")

        # Validate assignee if provided
        if task_data.assignee_id:
            await self._check_project_access(task_data.project_id, User(username=task_data.assignee_id))

    async def _validate_task_update(self, update_data: TaskUpdate, existing_task: Task, user: User):
        """
        Validate task update data
        """
        if update_data.title and len(update_data.title.strip()) < 3:
            raise_validation_error("Task title must be at least 3 characters", "title")

        if update_data.due_date and update_data.due_date <= datetime.utcnow():
            raise_business_logic_error("Due date must be in the future", "due_date")

        if update_data.assignee_id:
            await self._check_project_access(existing_task.project_id, User(username=update_data.assignee_id))

    async def _validate_status_transition(self, current_status: TaskStatus, new_status: TaskStatus, user: User, task: Task):
        """
        Validate task status transitions
        """
        # Business rules for status transitions
        invalid_transitions = [
            (TaskStatus.DONE, TaskStatus.TODO),  # Can't go back to TODO from DONE
            (TaskStatus.DONE, TaskStatus.IN_PROGRESS),  # Can't go back to IN_PROGRESS from DONE
        ]

        if (current_status, new_status) in invalid_transitions:
            raise_business_logic_error(f"Invalid status transition from {current_status} to {new_status}", "status_transition")

        # Only assignee or project owner can change status to DONE
        if new_status == TaskStatus.DONE:
            project = await self.db.projects.find_one({"_id": task.project_id})
            if user.username != task.assignee_id and user.username != project["owner_id"]:
                raise_authorization_error("Only assignee or project owner can mark task as done")

    async def _check_project_access(self, project_id: str, user: User):
        """
        Check if user has access to a project
        """
        project = await self.db.projects.find_one({
            "_id": project_id,
            "$or": [
                {"owner_id": user.username},
                {"team_members": user.username}
            ]
        })

        if not project:
            raise HTTPException(status_code=404, detail="Project not found or access denied")

# Global task service instance
task_service = TaskService()
