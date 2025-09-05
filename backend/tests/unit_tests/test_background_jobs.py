import pytest
from unittest.mock import AsyncMock, MagicMock
from datetime import datetime, timedelta
from app.services.background_jobs import Job, BackgroundJobProcessor

pytestmark = pytest.mark.asyncio

class TestJob:
    def test_job_creation(self):
        def sample_func():
            return "done"

        job = Job(func=sample_func, args=(1, 2), kwargs={"key": "value"}, run_at=datetime.utcnow() + timedelta(seconds=10))
        assert job.id is not None
        assert job.func == sample_func
        assert job.args == (1, 2)
        assert job.kwargs == {"key": "value"}
        assert job.status == "pending"
        assert job.result is None
        assert job.error is None

    def test_job_lt(self):
        job1 = Job(func=lambda: None, run_at=datetime.utcnow())
        job2 = Job(func=lambda: None, run_at=datetime.utcnow() + timedelta(seconds=1))
        assert job1 < job2

class TestBackgroundJobProcessor:
    def test_add_job(self):
        processor = BackgroundJobProcessor()
        job = Job(func=lambda: None)
        processor.add_job(job)
        assert len(processor.job_queue) == 1

    def test_run_job_sync(self):
        import asyncio
        processor = BackgroundJobProcessor()
        def sync_func():
            return "sync result"

        job = Job(func=sync_func)
        # Use asyncio.run to run the async function in a sync test
        asyncio.run(processor.run_job(job))
        assert job.status == "completed"
        assert job.result == "sync result"

    async def test_run_job_async(self):
        processor = BackgroundJobProcessor()
        async def async_func():
            return "async result"

        job = Job(func=async_func)
        await processor.run_job(job)
        assert job.status == "completed"
        assert job.result == "async result"

    async def test_run_job_failure(self):
        processor = BackgroundJobProcessor()
        def failing_func():
            raise ValueError("Test error")

        job = Job(func=failing_func)
        await processor.run_job(job)
        assert job.status == "failed"
        assert "Test error" in job.error

    async def test_process_jobs(self):
        processor = BackgroundJobProcessor()
        executed = []

        def job_func():
            executed.append(True)

        job = Job(func=job_func, run_at=datetime.utcnow() - timedelta(seconds=1))
        processor.add_job(job)

        # Mock asyncio.sleep to avoid hanging
        import unittest.mock
        with unittest.mock.patch('asyncio.sleep', side_effect=Exception("Stop loop")):
            processor.running = True
            with pytest.raises(Exception, match="Stop loop"):
                await processor.process_jobs()

        # Check that job was processed
        assert len(executed) == 1
        assert job.status == "completed"

    def test_stop(self):
        processor = BackgroundJobProcessor()
        processor.running = True
        processor.stop()
        assert processor.running is False
