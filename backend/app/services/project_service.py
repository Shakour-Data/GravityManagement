from typing import Optional, List
from datetime import datetime
from ..database import get_database
from ..models.project import Project, ProjectCreate, ProjectUpdate, ProjectTimeline, TimelineMilestone

class ProjectService:
    def __init__(self):
        self.db = get_database()

    async def create_project(self, project_create: ProjectCreate) -> Project:
        project_dict = project_create.dict()
        project_dict["created_at"] = datetime.utcnow()
        project_dict["updated_at"] = datetime.utcnow()
        project_dict["status"] = "planning"
        project_dict["timeline"] = ProjectTimeline().dict()
        result = await self.db.projects.insert_one(project_dict)
        created_project = await self.db.projects.find_one({"_id": result.inserted_id})
        return Project(**created_project)

    async def update_project(self, project_id: str, project_update: ProjectUpdate) -> Optional[Project]:
        update_data = project_update.dict(exclude_unset=True)
        update_data["updated_at"] = datetime.utcnow()
        result = await self.db.projects.update_one({"_id": project_id}, {"$set": update_data})
        if result.modified_count == 0:
            return None
        updated_project = await self.db.projects.find_one({"_id": project_id})
        return Project(**updated_project)

    async def get_project(self, project_id: str) -> Optional[Project]:
        project = await self.db.projects.find_one({"_id": project_id})
        if project:
            return Project(**project)
        return None

    async def calculate_timeline_progress(self, project_id: str) -> float:
        project = await self.get_project(project_id)
        if not project or not project.timeline or not project.timeline.milestones:
            return 0.0
        total = len(project.timeline.milestones)
        completed = sum(1 for m in project.timeline.milestones if m.completed)
        progress = (completed / total) * 100 if total > 0 else 0.0
        # Update progress in DB
        await self.db.projects.update_one(
            {"_id": project_id},
            {"$set": {"timeline.progress_percentage": progress, "updated_at": datetime.utcnow()}}
        )
        return progress

    async def add_milestone(self, project_id: str, milestone: TimelineMilestone) -> Optional[ProjectTimeline]:
        project = await self.get_project(project_id)
        if not project:
            return None
        timeline = project.timeline or ProjectTimeline()
        timeline.milestones.append(milestone)
        await self.db.projects.update_one(
            {"_id": project_id},
            {"$set": {"timeline": timeline.dict(), "updated_at": datetime.utcnow()}}
        )
        return timeline

    # Additional methods for timeline management, critical path calculation, budget alerts etc. can be added here

project_service = ProjectService()
