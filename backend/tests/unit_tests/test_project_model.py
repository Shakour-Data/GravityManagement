import pytest
from pydantic import ValidationError
from datetime import datetime, timedelta
from app.models.project import Project, ProjectCreate, ProjectUpdate, ProjectStatus, TimelineMilestone, ProjectTimeline

class TestProjectStatus:
    def test_project_status_values(self):
        assert ProjectStatus.PLANNING == "planning"
        assert ProjectStatus.ACTIVE == "active"
        assert ProjectStatus.ON_HOLD == "on_hold"
        assert ProjectStatus.COMPLETED == "completed"
        assert ProjectStatus.CANCELLED == "cancelled"

class TestTimelineMilestone:
    def test_timeline_milestone_creation(self):
        milestone = TimelineMilestone(
            name="Milestone 1",
            description="First milestone",
            due_date=datetime.utcnow() + timedelta(days=30),
            completed=False,
            dependencies=["dep1"]
        )
        assert milestone.name == "Milestone 1"
        assert milestone.description == "First milestone"
        assert milestone.completed is False
        assert milestone.dependencies == ["dep1"]

class TestProjectTimeline:
    def test_project_timeline_creation(self):
        timeline = ProjectTimeline(
            milestones=[],
            critical_path=["m1"],
            estimated_duration_days=100,
            actual_duration_days=90,
            progress_percentage=90.0
        )
        assert timeline.milestones == []
        assert timeline.critical_path == ["m1"]
        assert timeline.estimated_duration_days == 100
        assert timeline.actual_duration_days == 90
        assert timeline.progress_percentage == 90.0

class TestProjectModel:
    def test_project_creation_valid(self):
        project = Project(
            name="Test Project",
            description="A test project",
            status=ProjectStatus.ACTIVE,
            owner_id="user123",
            github_repo="https://github.com/user/repo",
            start_date=datetime.utcnow(),
            end_date=datetime.utcnow() + timedelta(days=30),
            budget=10000.0,
            spent_amount=5000.0,
            budget_alert_threshold=0.8,
            team_members=["user1", "user2"]
        )
        assert project.name == "Test Project"
        assert project.status == ProjectStatus.ACTIVE
        assert project.owner_id == "user123"
        assert project.budget == 10000.0
        assert project.spent_amount == 5000.0

    def test_project_creation_invalid_name(self):
        with pytest.raises(ValidationError):
            Project(
                name="",  # empty name
                owner_id="user123"
            )

    def test_project_creation_invalid_github_repo(self):
        with pytest.raises(ValidationError):
            Project(
                name="Test Project",
                owner_id="user123",
                github_repo="invalid-url"
            )

    def test_project_creation_negative_budget(self):
        with pytest.raises(ValidationError):
            Project(
                name="Test Project",
                owner_id="user123",
                budget=-100.0
            )

    def test_project_end_date_before_start(self):
        start_date = datetime.utcnow()
        end_date = start_date - timedelta(days=1)
        with pytest.raises(ValidationError):
            Project(
                name="Test Project",
                owner_id="user123",
                start_date=start_date,
                end_date=end_date
            )

    def test_project_budget_validator(self):
        project = Project(
            name="Test Project",
            owner_id="user123",
            budget=0.0
        )
        assert project.budget == 0.0

    def test_project_budget_negative_error(self):
        with pytest.raises(ValidationError):
            Project(
                name="Test Project",
                owner_id="user123",
                budget=-1.0
            )

class TestProjectCreateModel:
    def test_project_create_valid(self):
        project_create = ProjectCreate(
            name="New Project",
            description="New project description",
            github_repo="https://github.com/user/repo",
            start_date=datetime.utcnow(),
            end_date=datetime.utcnow() + timedelta(days=30),
            budget=5000.0,
            budget_alert_threshold=0.9
        )
        assert project_create.name == "New Project"
        assert project_create.budget == 5000.0

    def test_project_create_end_date_before_start(self):
        start_date = datetime.utcnow()
        end_date = start_date - timedelta(days=1)
        with pytest.raises(ValidationError):
            ProjectCreate(
                name="New Project",
                start_date=start_date,
                end_date=end_date
            )

class TestProjectUpdateModel:
    def test_project_update_valid(self):
        project_update = ProjectUpdate(
            name="Updated Project",
            description="Updated description",
            status=ProjectStatus.COMPLETED,
            budget=20000.0,
            spent_amount=15000.0,
            team_members=["user1"]
        )
        assert project_update.name == "Updated Project"
        assert project_update.status == ProjectStatus.COMPLETED
        assert project_update.budget == 20000.0

    def test_project_update_end_date_before_start(self):
        start_date = datetime.utcnow()
        end_date = start_date - timedelta(days=1)
        with pytest.raises(ValidationError):
            ProjectUpdate(
                start_date=start_date,
                end_date=end_date
            )
