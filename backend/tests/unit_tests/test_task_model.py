import pytest
from pydantic import ValidationError
from datetime import datetime, timedelta
from app.models.task import Task, TaskCreate, TaskUpdate, TaskStatus, TaskDependency, TaskProgress

class TestTaskStatus:
    def test_task_status_values(self):
        assert TaskStatus.TODO == "todo"
        assert TaskStatus.IN_PROGRESS == "in_progress"
        assert TaskStatus.DONE == "done"
        assert TaskStatus.BLOCKED == "blocked"

class TestTaskDependency:
    def test_task_dependency_creation(self):
        dep = TaskDependency(task_id="task1", dependency_type="finish_to_start")
        assert dep.task_id == "task1"
        assert dep.dependency_type == "finish_to_start"

class TestTaskProgress:
    def test_task_progress_creation(self):
        progress = TaskProgress(percentage=50.0, estimated_hours=10.0, actual_hours=5.0)
        assert progress.percentage == 50.0
        assert progress.estimated_hours == 10.0
        assert progress.actual_hours == 5.0

class TestTaskModel:
    def test_task_creation_valid(self):
        task = Task(
            title="Test Task",
            project_id="proj1",
            status=TaskStatus.TODO,
            priority=3,
            tags=["tag1", "tag2"]
        )
        assert task.title == "Test Task"
        assert task.project_id == "proj1"
        assert task.status == TaskStatus.TODO
        assert task.priority == 3
        assert "tag1" in task.tags

    def test_task_creation_invalid_priority(self):
        with pytest.raises(ValidationError):
            Task(
                title="Test Task",
                project_id="proj1",
                priority=0  # invalid, less than 1
            )

    def test_task_create_model(self):
        task_create = TaskCreate(
            title="New Task",
            project_id="proj1",
            priority=2
        )
        assert task_create.title == "New Task"
        assert task_create.project_id == "proj1"
        assert task_create.priority == 2

    def test_task_update_model(self):
        task_update = TaskUpdate(
            title="Updated Task",
            status=TaskStatus.IN_PROGRESS,
            priority=4
        )
        assert task_update.title == "Updated Task"
        assert task_update.status == TaskStatus.IN_PROGRESS
        assert task_update.priority == 4
