from typing import List, Optional, Dict, Any
from datetime import datetime
from fastapi import HTTPException
from ..database import get_database
from ..models.resource import Resource, ResourceCreate, ResourceUpdate, ResourceType
from ..models.user import User
from .exceptions import (
    ValidationError, AuthorizationError, NotFoundError, ConflictError,
    BusinessLogicError, raise_validation_error, raise_authorization_error,
    raise_not_found_error, raise_conflict_error, raise_business_logic_error
)

class ResourceService:
    def __init__(self):
        self.db = get_database()

    async def create_resource(self, resource_data: ResourceCreate, user: User) -> Resource:
        """
        Create a new resource with validation and business logic
        """
        # Validate resource data
        await self._validate_resource_data(resource_data, user)

        # Check for duplicate resource names in the same project
        existing_resource = await self.db.resources.find_one({
            "name": resource_data.name,
            "project_id": resource_data.project_id
        })
        if existing_resource:
            raise HTTPException(status_code=400, detail="Resource name already exists in this project")

        # Create resource document
        resource_dict = resource_data.dict()
        resource_dict.update({
            "availability": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        })

        result = await self.db.resources.insert_one(resource_dict)
        created_resource = await self.db.resources.find_one({"_id": result.inserted_id})

        return Resource(**created_resource)

    async def get_resource(self, resource_id: str, user: User) -> Resource:
        """
        Get a resource with access control
        """
        resource = await self.db.resources.find_one({"_id": resource_id})
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")

        # Check project access
        await self._check_project_access(resource["project_id"], user)

        return Resource(**resource)

    async def get_project_resources(self, project_id: str, user: User, type_filter: Optional[ResourceType] = None) -> List[Resource]:
        """
        Get all resources for a project with optional type filter
        """
        # Check project access
        await self._check_project_access(project_id, user)

        query = {"project_id": project_id}
        if type_filter:
            query["type"] = type_filter

        resources = await self.db.resources.find(query).sort("created_at", -1).to_list(length=None)
        return [Resource(**resource) for resource in resources]

    async def update_resource(self, resource_id: str, update_data: ResourceUpdate, user: User) -> Resource:
        """
        Update a resource with validation and business logic
        """
        # Get existing resource
        resource = await self.get_resource(resource_id, user)

        # Validate update data
        await self._validate_resource_update(update_data, resource)

        # Prepare update document
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()

        await self.db.resources.update_one({"_id": resource_id}, {"$set": update_dict})

        # Get updated resource
        updated_resource = await self.db.resources.find_one({"_id": resource_id})
        return Resource(**updated_resource)

    async def allocate_resource(self, resource_id: str, quantity: float, user: User) -> Resource:
        """
        Allocate a quantity of a resource
        """
        resource = await self.get_resource(resource_id, user)

        if not resource.availability:
            raise HTTPException(status_code=400, detail="Resource is not available")

        if resource.quantity is not None and quantity > resource.quantity:
            raise HTTPException(status_code=400, detail="Insufficient resource quantity")

        # Update quantity if applicable
        if resource.quantity is not None:
            new_quantity = resource.quantity - quantity
            if new_quantity <= 0:
                # Mark as unavailable if fully allocated
                await self.db.resources.update_one(
                    {"_id": resource_id},
                    {
                        "$set": {
                            "quantity": 0,
                            "availability": False,
                            "updated_at": datetime.utcnow()
                        }
                    }
                )
            else:
                await self.db.resources.update_one(
                    {"_id": resource_id},
                    {
                        "$set": {
                            "quantity": new_quantity,
                            "updated_at": datetime.utcnow()
                        }
                    }
                )

        updated_resource = await self.db.resources.find_one({"_id": resource_id})
        return Resource(**updated_resource)

    async def release_resource(self, resource_id: str, quantity: Optional[float] = None, user: User = None) -> Resource:
        """
        Release a resource allocation
        """
        resource = await self.get_resource(resource_id, user)

        if resource.availability:
            raise HTTPException(status_code=400, detail="Resource is already available")

        # If quantity is specified, add it back
        if quantity and resource.quantity is not None:
            new_quantity = resource.quantity + quantity
            await self.db.resources.update_one(
                {"_id": resource_id},
                {
                    "$set": {
                        "quantity": new_quantity,
                        "availability": True,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
        else:
            # Mark as available without quantity change
            await self.db.resources.update_one(
                {"_id": resource_id},
                {
                    "$set": {
                        "availability": True,
                        "updated_at": datetime.utcnow()
                    }
                }
            )

        updated_resource = await self.db.resources.find_one({"_id": resource_id})
        return Resource(**updated_resource)

    async def delete_resource(self, resource_id: str, user: User) -> bool:
        """
        Delete a resource
        """
        resource = await self.get_resource(resource_id, user)

        # Check if resource is currently allocated
        if not resource.availability:
            raise HTTPException(status_code=400, detail="Cannot delete allocated resource")

        result = await self.db.resources.delete_one({"_id": resource_id})
        return result.deleted_count > 0

    async def get_resource_utilization(self, project_id: str, user: User) -> Dict[str, Any]:
        """
        Get resource utilization statistics for a project
        """
        await self._check_project_access(project_id, user)

        # Count resources by type
        type_stats = await self.db.resources.aggregate([
            {"$match": {"project_id": project_id}},
            {"$group": {"_id": "$type", "count": {"$sum": 1}}}
        ]).to_list(length=None)

        # Count available vs unavailable resources
        availability_stats = await self.db.resources.aggregate([
            {"$match": {"project_id": project_id}},
            {"$group": {"_id": "$availability", "count": {"$sum": 1}}}
        ]).to_list(length=None)

        # Calculate total cost
        cost_pipeline = [
            {"$match": {"project_id": project_id, "cost": {"$ne": None}}},
            {"$group": {"_id": None, "total_cost": {"$sum": "$cost"}}}
        ]
        cost_result = await self.db.resources.aggregate(cost_pipeline).to_list(length=1)

        total_cost = cost_result[0]["total_cost"] if cost_result else 0

        return {
            "project_id": project_id,
            "type_breakdown": {stat["_id"]: stat["count"] for stat in type_stats},
            "availability_breakdown": {stat["_id"]: stat["count"] for stat in availability_stats},
            "total_cost": total_cost,
            "total_resources": sum(stat["count"] for stat in type_stats)
        }

    async def get_available_resources(self, project_id: str, resource_type: Optional[ResourceType], user: User) -> List[Resource]:
        """
        Get available resources for a project, optionally filtered by type
        """
        await self._check_project_access(project_id, user)

        query = {"project_id": project_id, "availability": True}
        if resource_type:
            query["type"] = resource_type

        resources = await self.db.resources.find(query).sort("name", 1).to_list(length=None)
        return [Resource(**resource) for resource in resources]

    async def _validate_resource_data(self, resource_data: ResourceCreate, user: User):
        """
        Validate resource creation data
        """
        if not resource_data.name or len(resource_data.name.strip()) < 2:
            raise HTTPException(status_code=400, detail="Resource name must be at least 2 characters")

        # Check project access
        await self._check_project_access(resource_data.project_id, user)

        # Validate quantity and cost
        if resource_data.quantity is not None and resource_data.quantity < 0:
            raise HTTPException(status_code=400, detail="Quantity cannot be negative")

        if resource_data.cost is not None and resource_data.cost < 0:
            raise HTTPException(status_code=400, detail="Cost cannot be negative")

        # Business rules based on resource type
        if resource_data.type == ResourceType.FINANCIAL and resource_data.quantity is not None:
            raise HTTPException(status_code=400, detail="Financial resources should not have quantity")

        if resource_data.type == ResourceType.MATERIAL and resource_data.quantity is None:
            raise HTTPException(status_code=400, detail="Material resources must have quantity")

    async def _validate_resource_update(self, update_data: ResourceUpdate, existing_resource: Resource):
        """
        Validate resource update data
        """
        if update_data.name and len(update_data.name.strip()) < 2:
            raise HTTPException(status_code=400, detail="Resource name must be at least 2 characters")

        if update_data.quantity is not None and update_data.quantity < 0:
            raise HTTPException(status_code=400, detail="Quantity cannot be negative")

        if update_data.cost is not None and update_data.cost < 0:
            raise HTTPException(status_code=400, detail="Cost cannot be negative")

        # Check for duplicate names if name is being updated
        if update_data.name:
            duplicate = await self.db.resources.find_one({
                "name": update_data.name,
                "project_id": existing_resource.project_id,
                "_id": {"$ne": existing_resource.id}
            })
            if duplicate:
                raise HTTPException(status_code=400, detail="Resource name already exists in this project")

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

# Global resource service instance
resource_service = ResourceService()
