import pytest
from pydantic import ValidationError
from datetime import datetime, timedelta
from app.models.resource import Resource, ResourceCreate, ResourceUpdate, ResourceType, ResourceAllocation, ResourceConflict, ResourceUtilization

class TestResourceType:
    def test_resource_type_values(self):
        assert ResourceType.HUMAN == "human"
        assert ResourceType.MATERIAL == "material"
        assert ResourceType.FINANCIAL == "financial"

class TestResourceAllocation:
    def test_resource_allocation_creation(self):
        alloc = ResourceAllocation(
            task_id="task1",
            allocated_quantity=5.0,
            start_date=datetime.utcnow(),
            end_date=datetime.utcnow() + timedelta(days=7),
            allocated_by="user1"
        )
        assert alloc.task_id == "task1"
        assert alloc.allocated_quantity == 5.0
        assert alloc.allocated_by == "user1"

class TestResourceConflict:
    def test_resource_conflict_creation(self):
        conflict = ResourceConflict(
            conflicting_allocation_id="alloc1",
            conflict_type="over_allocation",
            severity="high",
            description="Resource over-allocated"
        )
        assert conflict.conflicting_allocation_id == "alloc1"
        assert conflict.conflict_type == "over_allocation"
        assert conflict.severity == "high"

class TestResourceUtilization:
    def test_resource_utilization_creation(self):
        util = ResourceUtilization(
            period_start=datetime.utcnow(),
            period_end=datetime.utcnow() + timedelta(days=30),
            utilization_percentage=75.0,
            allocated_quantity=10.0,
            available_quantity=15.0
        )
        assert util.utilization_percentage == 75.0
        assert util.allocated_quantity == 10.0
        assert util.available_quantity == 15.0

class TestResourceModel:
    def test_resource_creation_valid(self):
        resource = Resource(
            name="Test Resource",
            type=ResourceType.HUMAN,
            project_id="proj1",
            quantity=10.0,
            cost=100.0,
            skill_level=3,
            location="Office"
        )
        assert resource.name == "Test Resource"
        assert resource.type == ResourceType.HUMAN
        assert resource.project_id == "proj1"
        assert resource.quantity == 10.0
        assert resource.cost == 100.0
        assert resource.skill_level == 3

    def test_resource_creation_invalid_skill_level(self):
        with pytest.raises(ValidationError):
            Resource(
                name="Test Resource",
                type=ResourceType.HUMAN,
                project_id="proj1",
                skill_level=6  # invalid, greater than 5
            )

    def test_resource_create_model(self):
        resource_create = ResourceCreate(
            name="New Resource",
            type=ResourceType.MATERIAL,
            project_id="proj1",
            quantity=20.0,
            cost=200.0
        )
        assert resource_create.name == "New Resource"
        assert resource_create.type == ResourceType.MATERIAL
        assert resource_create.quantity == 20.0

    def test_resource_update_model(self):
        resource_update = ResourceUpdate(
            name="Updated Resource",
            quantity=15.0,
            availability=False
        )
        assert resource_update.name == "Updated Resource"
        assert resource_update.quantity == 15.0
        assert resource_update.availability is False
