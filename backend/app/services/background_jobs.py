import asyncio
from typing import Callable, Any, Dict
from datetime import datetime, timedelta
import heapq
import uuid

class Job:
    def __init__(self, func: Callable, args: tuple = (), kwargs: dict = {}, run_at: datetime = None):
        self.id = str(uuid.uuid4())
        self.func = func
        self.args = args
        self.kwargs = kwargs
        self.run_at = run_at or datetime.utcnow()
        self.created_at = datetime.utcnow()
        self.status = "pending"  # pending, running, completed, failed
        self.result = None
        self.error = None

    def __lt__(self, other):
        return self.run_at < other.run_at

class BackgroundJobProcessor:
    def __init__(self):
        self.job_queue = []
        self.running = False

    def add_job(self, job: Job):
        heapq.heappush(self.job_queue, job)

    async def run_job(self, job: Job):
        job.status = "running"
        try:
            if asyncio.iscoroutinefunction(job.func):
                job.result = await job.func(*job.args, **job.kwargs)
            else:
                job.result = job.func(*job.args, **job.kwargs)
            job.status = "completed"
        except Exception as e:
            job.status = "failed"
            job.error = str(e)

    async def process_jobs(self):
        self.running = True
        while self.running:
            now = datetime.utcnow()
            if self.job_queue and self.job_queue[0].run_at <= now:
                job = heapq.heappop(self.job_queue)
                await self.run_job(job)
            else:
                await asyncio.sleep(1)

    def stop(self):
        self.running = False

background_job_processor = BackgroundJobProcessor()
