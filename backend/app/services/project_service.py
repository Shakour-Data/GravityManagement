from typing import List, Optional, Dict, Any
from datetime import datetime
from ..database import get_database
from ..models.project import Project, ProjectCreate, ProjectUpdate, ProjectStatus
from ..models.user import User
from .exceptions import (
    ValidationError, AuthorizationError, NotFoundError, ConflictError,
    BusinessLogicError, raise_validation_error, raise_authorization_error,
    raise_not_found_error, raise_conflict_error, raise_business_logic_error
)
from .cache_service import cache_service, cached, invalidate_cache, CacheKeys
from .cache_service import cache_service, cached, invalidate_cache, CacheKeys

class ProjectService:
    def __init__(self):
        self.db = get_database()

    async def create_project(self, project_data: ProjectCreate, owner: User) -> Project:
        """
        Create a new project with validation and business logic
        """
        # Validate project data
        await self._validate_project_data(project_data)

        # Check if project name is unique for the user
        existing_project = await self.db.projects.find_one({
            "name": project_data.name,
            "owner_id": owner.username
        })
        if existing_project:
            raise_conflict_error("Project name already exists", "project")

        # Create project document
        project_dict = project_data.dict()
        project_dict.update({
            "owner_id": owner.username,
            "team_members": [owner.username],
            "status": ProjectStatus.PLANNING,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await self.db.projects.insert_one(project_dict)
        created_project = await self.db.projects.find_one({"_id": result.inserted_id})

        return Project(**created_project)

    @cached(ttl_seconds=300, key_prefix="project")
    async def get_project(self, project_id: str, user: User) -> Project:
        """
        Get a project with access control
        """
        project = await self.db.projects.find_one({
            "_id": project_id,
            "$or": [
                {"owner_id": user.username},
                {"team_members": user.username}
            ]
        })

        if not project:
            raise_not_found_error("Project", project_id)

        return Project(**project)

    @cached(ttl_seconds=300, key_prefix="user_projects")
    async def get_user_projects(self, user: User, status_filter: Optional[ProjectStatus] = None) -> List[Project]:
        """
        Get all projects for a user with optional status filter
        """
        query = {
            "$or": [
                {"owner_id": user.username},
                {"team_members": user.username}
            ]
        }

        if status_filter:
            query["status"] = status_filter

        projects = await self.db.projects.find(query).sort("updated_at", -1).to_list(length=None)
        return [Project(**project) for project in projects]

    @invalidate_cache("project:*")
    @invalidate_cache("user_projects:*")
    async def update_project(self, project_id: str, update_data: ProjectUpdate, user: User) -> Project:
        """
        Update a project with validation and business logic
        """
        # Get existing project
        project = await self.get_project(project_id, user)

        # Check if user is owner for certain updates
        if update_data.status and user.username != project.owner_id:
            raise_authorization_error("Only project owner can change status")

        # Validate update data
        await self._validate_project_update(update_data, project)

        # Prepare update document
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()

        await self.db.projects.update_one({"_id": project_id}, {"$set": update_dict})

        # Get updated project
        updated_project = await self.db.projects.find_one({"_id": project_id})
        return Project(**updated_project)

    @invalidate_cache("project:*")
    @invalidate_cache("user_projects:*")
    async def add_team_member(self, project_id: str, member_username: str, user: User) -> Project:
        """
        Add a team member to a project
        """
        project = await self.get_project(project_id, user)

        # Check if user is owner
        if user.username != project.owner_id:
            raise_authorization_error("Only project owner can manage team members")

        # Check if member exists
        member = await self.db.users.find_one({"username": member_username})
        if not member:
            raise_not_found_error("User", member_username)

        # Check if already a member
        if member_username in project.team_members:
            raise_conflict_error("User is already a team member", "team_member")

        # Add member
        await self.db.projects.update_one(
            {"_id": project_id},
            {
                "$addToSet": {"team_members": member_username},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        updated_project = await self.db.projects.find_one({"_id": project_id})
        return Project(**updated_project)

    @invalidate_cache("project:*")
    @invalidate_cache("user_projects:*")
    async def remove_team_member(self, project_id: str, member_username: str, user: User) -> Project:
        """
        Remove a team member from a project
        """
        project = await self.get_project(project_id, user)

        # Check if user is owner
        if user.username != project.owner_id:
            raise_authorization_error("Only project owner can manage team members")

        # Cannot remove owner
        if member_username == project.owner_id:
            raise_business_logic_error("Cannot remove project owner", "owner_removal")

        # Remove member
        await self.db.projects.update_one(
            {"_id": project_id},
            {
                "$pull": {"team_members": member_username},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        updated_project = await self.db.projects.find_one({"_id": project_id})
        return Project(**updated_project)

    @invalidate_cache("project:*")
    @invalidate_cache("user_projects:*")
    @invalidate_cache("task:*")
    @invalidate_cache("resource:*")
    @invalidate_cache("rule:*")
    async def delete_project(self, project_id: str, user: User) -> bool:
        """
        Delete a project and all associated data
        """
        project = await self.get_project(project_id, user)

        # Check if user is owner
        if user.username != project.owner_id:
            raise_authorization_error("Only project owner can delete project")

        # Delete associated tasks and resources
        await self.db.tasks.delete_many({"project_id": project_id})
        await self.db.resources.delete_many({"project_id": project_id})
        await self.db.rules.delete_many({"project_id": project_id})

        # Delete project
        result = await self.db.projects.delete_one({"_id": project_id})
        return result.deleted_count > 0

    async def get_project_stats(self, project_id: str, user: User) -> Dict[str, Any]:
        """
        Get project statistics
        """
        project = await self.get_project(project_id, user)

        # Count tasks by status
        task_stats = await self.db.tasks.aggregate([
            {"$match": {"project_id": project_id}},
            {"$group": {"_id": "$status", "count": {"$sum": 1}}}
        ]).to_list(length=None)

        # Count resources
        resource_count = await self.db.resources.count_documents({"project_id": project_id})

        # Count team members
        team_count = len(project.team_members)

        return {
            "project_id": project_id,
            "task_stats": {stat["_id"]: stat["count"] for stat in task_stats},
            "resource_count": resource_count,
            "team_count": team_count,
            "status": project.status,
            "progress_percentage": self._calculate_progress_percentage(task_stats)
        }

    async def _validate_project_data(self, project_data: ProjectCreate):
        """
        Validate project creation data
        """
        if not project_data.name or len(project_data.name.strip()) < 3:
            raise_validation_error("Project name must be at least 3 characters", "name")

        if project_data.start_date and project_data.end_date:
            if project_data.start_date >= project_data.end_date:
                raise_business_logic_error("End date must be after start date", "date_validation")

        if project_data.budget and project_data.budget < 0:
            raise_validation_error("Budget cannot be negative", "budget")

    async def _validate_project_update(self, update_data: ProjectUpdate, existing_project: Project):
        """
        Validate project update data
        """
        if update_data.name:
            if len(update_data.name.strip()) < 3:
                raise_validation_error("Project name must be at least 3 characters", "name")

            # Check name uniqueness
            duplicate = await self.db.projects.find_one({
                "name": update_data.name,
                "owner_id": existing_project.owner_id,
                "_id": {"$ne": existing_project.id}
            })
            if duplicate:
                raise_conflict_error("Project name already exists", "project")

        if update_data.start_date and update_data.end_date:
            if update_data.start_date >= update_data.end_date:
                raise_business_logic_error("End date must be after start date", "date_validation")

        if update_data.budget and update_data.budget < 0:
            raise_validation_error("Budget cannot be negative", "budget")

    def _calculate_progress_percentage(self, task_stats: List[Dict]) -> float:
        """
        Calculate project progress based on task completion
        """
        total_tasks = sum(stat["count"] for stat in task_stats)
        if total_tasks == 0:
            return 0.0

        completed_tasks = 0
        for stat in task_stats:
            if stat["_id"] == "done":
                completed_tasks = stat["count"]
                break

        return round((completed_tasks / total_tasks) * 100, 2)

# Global project service instance
project_service = ProjectService()
