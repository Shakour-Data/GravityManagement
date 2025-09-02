from typing import Optional, List, Dict
from datetime import datetime
from ..database import get_database
from ..models.task import Task, TaskCreate, TaskUpdate, TaskDependency, TaskProgress, TaskStatus

class TaskService:
    def __init__(self):
        self.db = get_database()

    async def create_task(self, task_create: TaskCreate) -> Task:
        task_dict = task_create.dict()
        task_dict["created_at"] = datetime.utcnow()
        task_dict["updated_at"] = datetime.utcnow()
        task_dict["status"] = TaskStatus.TODO
        task_dict["progress"] = TaskProgress(
            estimated_hours=task_create.estimated_hours
        ).dict()
        result = await self.db.tasks.insert_one(task_dict)
        created_task = await self.db.tasks.find_one({"_id": result.inserted_id})
        return Task(**created_task)

    async def update_task(self, task_id: str, task_update: TaskUpdate) -> Optional[Task]:
        update_data = task_update.dict(exclude_unset=True)
        update_data["updated_at"] = datetime.utcnow()

        # Handle progress updates
        if task_update.progress_percentage is not None:
            progress_update = {
                "percentage": task_update.progress_percentage,
                "last_updated": datetime.utcnow()
            }
            if task_update.actual_hours is not None:
                progress_update["actual_hours"] = task_update.actual_hours
            update_data["progress"] = progress_update

        result = await self.db.tasks.update_one({"_id": task_id}, {"$set": update_data})
        if result.modified_count == 0:
            return None
        updated_task = await self.db.tasks.find_one({"_id": task_id})
        return Task(**updated_task)

    async def get_task(self, task_id: str) -> Optional[Task]:
        task = await self.db.tasks.find_one({"_id": task_id})
        if task:
            return Task(**task)
        return None

    async def validate_dependencies(self, task_id: str, dependencies: List[TaskDependency]) -> bool:
        """
        Validate that all dependencies exist and don't create circular dependencies
        """
        for dep in dependencies:
            # Check if dependency task exists
            dep_task = await self.db.tasks.find_one({"_id": dep.task_id})
            if not dep_task:
                return False

            # Check for circular dependency
            if await self._has_circular_dependency(task_id, dep.task_id):
                return False

        return True

    async def _has_circular_dependency(self, task_id: str, dep_task_id: str) -> bool:
        """
        Check if adding this dependency would create a circular reference
        """
        # Get all tasks that depend on the current task
        dependent_tasks = await self.db.tasks.find({"dependencies.task_id": task_id}).to_list(length=None)

        for task in dependent_tasks:
            if task["_id"] == dep_task_id:
                return True
            # Recursively check
            if await self._has_circular_dependency(task["_id"], dep_task_id):
                return True

        return False

    async def can_start_task(self, task_id: str) -> bool:
        """
        Check if a task can be started based on its dependencies
        """
        task = await self.get_task(task_id)
        if not task or not task.dependencies:
            return True

        for dep in task.dependencies:
            dep_task = await self.get_task(dep.task_id)
            if not dep_task or dep_task.status != TaskStatus.DONE:
                return False

        return True

    async def assign_task_smart(self, task_id: str, project_id: str) -> Optional[str]:
        """
        Smart task assignment based on workload balancing
        """
        # Get all team members for the project
        project = await self.db.projects.find_one({"_id": project_id})
        if not project:
            return None

        team_members = project.get("team_members", [])

        # Calculate current workload for each team member
        workloads = {}
        for member_id in team_members:
            # Count active tasks assigned to this member
            active_tasks = await self.db.tasks.count_documents({
                "assignee_id": member_id,
                "status": {"$in": ["todo", "in_progress"]},
                "project_id": project_id
            })
            workloads[member_id] = active_tasks

        # Find member with least workload
        if workloads:
            assignee_id = min(workloads, key=workloads.get)
            await self.db.tasks.update_one(
                {"_id": task_id},
                {"$set": {"assignee_id": assignee_id, "updated_at": datetime.utcnow()}}
            )
            return assignee_id

        return None

    async def get_project_progress(self, project_id: str) -> Dict:
        """
        Calculate overall project progress
        """
        tasks = await self.db.tasks.find({"project_id": project_id}).to_list(length=None)

        if not tasks:
            return {"total_tasks": 0, "completed_tasks": 0, "progress_percentage": 0.0}

        total_tasks = len(tasks)
        completed_tasks = sum(1 for task in tasks if task["status"] == TaskStatus.DONE)

        # Calculate weighted progress based on task priorities
        total_weight = sum(task.get("priority", 1) for task in tasks)
        completed_weight = sum(
            task.get("priority", 1) for task in tasks
            if task["status"] == TaskStatus.DONE
        )

        progress_percentage = (completed_weight / total_weight * 100) if total_weight > 0 else 0.0

        return {
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "progress_percentage": round(progress_percentage, 2)
        }

    async def get_overdue_tasks(self, project_id: Optional[str] = None) -> List[Task]:
        """
        Get all overdue tasks
        """
        query = {
            "due_date": {"$lt": datetime.utcnow()},
            "status": {"$ne": TaskStatus.DONE}
        }
        if project_id:
            query["project_id"] = project_id

        overdue_tasks = await self.db.tasks.find(query).to_list(length=None)
        return [Task(**task) for task in overdue_tasks]

task_service = TaskService()
