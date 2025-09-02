from typing import Optional, List, Dict
from datetime import datetime, timedelta
from ..database import get_database
from ..models.resource import (
    Resource, ResourceCreate, ResourceUpdate,
    ResourceAllocation, ResourceConflict, ResourceUtilization
)

class ResourceService:
    def __init__(self):
        self.db = get_database()

    async def allocate_resource(self, resource_id: str, allocation: ResourceAllocation) -> Optional[ResourceAllocation]:
        """
        Allocate a resource to a task with conflict checking
        """
        # Check for conflicts
        conflicts = await self.check_allocation_conflicts(resource_id, allocation)
        if conflicts:
            return None  # Cannot allocate due to conflicts

        # Add allocation to resource
        result = await self.db.resources.update_one(
            {"_id": resource_id},
            {
                "$push": {"allocations": allocation.dict()},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        if result.modified_count == 0:
            return None

        return allocation

    async def check_allocation_conflicts(self, resource_id: str, new_allocation: ResourceAllocation) -> List[ResourceConflict]:
        """
        Check for conflicts with existing allocations
        """
        resource = await self.db.resources.find_one({"_id": resource_id})
        if not resource:
            return []

        conflicts = []
        existing_allocations = resource.get("allocations", [])
        available_quantity = resource.get("quantity", 0)

        for alloc in existing_allocations:
            alloc_obj = ResourceAllocation(**alloc)

            # Check time overlap
            if (new_allocation.start_date <= alloc_obj.end_date or alloc_obj.end_date is None) and \
               (new_allocation.end_date is None or new_allocation.end_date >= alloc_obj.start_date):

                # Check quantity overlap
                total_allocated = new_allocation.allocated_quantity + alloc_obj.allocated_quantity
                if total_allocated > available_quantity:
                    conflicts.append(ResourceConflict(
                        conflicting_allocation_id=str(alloc_obj.task_id),
                        conflict_type="over_allocation",
                        severity="high",
                        description=f"Allocation exceeds available quantity ({total_allocated} > {available_quantity})"
                    ))

        return conflicts

    async def optimize_resource_allocation(self, project_id: str) -> Dict[str, List[str]]:
        """
        Optimize resource allocation for a project
        """
        # Get all resources and tasks for the project
        resources = await self.db.resources.find({"project_id": project_id}).to_list(length=None)
        tasks = await self.db.tasks.find({"project_id": project_id}).to_list(length=None)

        optimization_suggestions = {}

        # Simple optimization: suggest reallocating over-allocated resources
        for resource in resources:
            resource_obj = Resource(**resource)
            total_allocated = sum(alloc.allocated_quantity for alloc in resource_obj.allocations)
            available = resource_obj.quantity or 0

            if total_allocated > available:
                optimization_suggestions[resource_obj.id] = [
                    f"Over-allocated by {total_allocated - available}",
                    "Consider reducing allocation quantities or extending resource capacity"
                ]

        return optimization_suggestions

    async def calculate_utilization(self, resource_id: str, start_date: datetime, end_date: datetime) -> ResourceUtilization:
        """
        Calculate resource utilization for a given period
        """
        resource = await self.db.resources.find_one({"_id": resource_id})
        if not resource:
            return None

        resource_obj = Resource(**resource)
        available_quantity = resource_obj.quantity or 0

        # Calculate average allocated quantity during the period
        total_allocated = 0
        allocation_count = 0

        for alloc in resource_obj.allocations:
            alloc_obj = ResourceAllocation(**alloc)

            # Check if allocation overlaps with the period
            if (alloc_obj.start_date <= end_date) and \
               (alloc_obj.end_date is None or alloc_obj.end_date >= start_date):
                total_allocated += alloc_obj.allocated_quantity
                allocation_count += 1

        avg_allocated = total_allocated / max(allocation_count, 1)
        utilization_percentage = (avg_allocated / available_quantity * 100) if available_quantity > 0 else 0

        utilization = ResourceUtilization(
            period_start=start_date,
            period_end=end_date,
            utilization_percentage=round(utilization_percentage, 2),
            allocated_quantity=avg_allocated,
            available_quantity=available_quantity
        )

        # Store in history
        await self.db.resources.update_one(
            {"_id": resource_id},
            {
                "$push": {"utilization_history": utilization.dict()},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        return utilization

    async def get_resource_utilization_report(self, project_id: str, days: int = 30) -> Dict[str, List[ResourceUtilization]]:
        """
        Generate utilization report for all resources in a project
        """
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=days)

        resources = await self.db.resources.find({"project_id": project_id}).to_list(length=None)
        report = {}

        for resource in resources:
            resource_obj = Resource(**resource)
            utilization = await self.calculate_utilization(resource_obj.id, start_date, end_date)
            if utilization:
                report[resource_obj.name] = [utilization]

        return report

    async def deallocate_resource(self, resource_id: str, task_id: str) -> bool:
        """
        Remove allocation of a resource from a task
        """
        result = await self.db.resources.update_one(
            {"_id": resource_id},
            {
                "$pull": {"allocations": {"task_id": task_id}},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        return result.modified_count > 0

    async def find_available_resources(self, project_id: str, resource_type: str,
                                    required_quantity: float, start_date: datetime,
                                    end_date: Optional[datetime] = None) -> List[Resource]:
        """
        Find available resources of a specific type that can fulfill requirements
        """
        # Find resources of the specified type
        resources = await self.db.resources.find({
            "project_id": project_id,
            "type": resource_type,
            "availability": True
        }).to_list(length=None)

        available_resources = []

        for resource in resources:
            resource_obj = Resource(**resource)

            # Check if resource has enough quantity
            if resource_obj.quantity and resource_obj.quantity < required_quantity:
                continue

            # Check for conflicts with existing allocations
            conflicts = await self.check_allocation_conflicts(
                resource_obj.id,
                ResourceAllocation(
                    task_id="",  # Placeholder
                    allocated_quantity=required_quantity,
                    start_date=start_date,
                    end_date=end_date,
                    allocated_by=""  # Placeholder
                )
            )

            if not conflicts:
                available_resources.append(resource_obj)

        return available_resources

resource_service = ResourceService()
