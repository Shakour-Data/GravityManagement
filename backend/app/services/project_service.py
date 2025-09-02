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
        project_dict["spent_amount"] = 0.0
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

    async def update_spent_amount(self, project_id: str, amount: float) -> Optional[Project]:
        """Update the spent amount for a project."""
        if amount < 0:
            raise ValueError("Amount must be non-negative")
        project = await self.get_project(project_id)
        if not project:
            return None
        new_spent = project.spent_amount + amount
        if new_spent < 0:
            raise ValueError("Spent amount cannot be negative")
        await self.db.projects.update_one(
            {"_id": project_id},
            {"$set": {"spent_amount": new_spent, "updated_at": datetime.utcnow()}}
        )
        return await self.get_project(project_id)

    async def check_budget_alert(self, project_id: str) -> dict:
        """Check if project budget is nearing or exceeding the alert threshold."""
        project = await self.get_project(project_id)
        if not project or not project.budget:
            return {"alert": False, "message": "No budget set"}
        spent_percentage = project.spent_amount / project.budget
        alert_triggered = spent_percentage >= project.budget_alert_threshold
        return {
            "alert": alert_triggered,
            "spent_percentage": spent_percentage,
            "threshold": project.budget_alert_threshold,
            "budget": project.budget,
            "spent": project.spent_amount,
            "remaining": project.budget - project.spent_amount
        }

    async def get_budget_report(self, project_id: str) -> dict:
        """Get a detailed budget report for the project."""
        project = await self.get_project(project_id)
        if not project:
            return {"error": "Project not found"}
        if not project.budget:
            return {"budget_set": False, "message": "No budget configured"}
        spent_percentage = (project.spent_amount / project.budget) * 100
        remaining = project.budget - project.spent_amount
        alert_status = await self.check_budget_alert(project_id)
        return {
            "project_id": project_id,
            "budget": project.budget,
            "spent": project.spent_amount,
            "remaining": remaining,
            "spent_percentage": spent_percentage,
            "alert_threshold": project.budget_alert_threshold,
            "alert_triggered": alert_status["alert"],
            "status": "over_budget" if project.spent_amount > project.budget else "on_track"
        }

    # Additional methods for timeline management, critical path calculation, budget alerts etc. can be added here

project_service = ProjectService()
