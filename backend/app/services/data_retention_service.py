import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from motor.motor_asyncio import AsyncIOMotorDatabase
from ..database import get_database
from .notification_service import notification_service


class DataRetentionService:
    def __init__(self):
        self.db: Optional[AsyncIOMotorDatabase] = None
        self.retention_policies = {
            'user_sessions': 30,  # days
            'audit_logs': 90,     # days
            'task_history': 365,  # days
            'notification_logs': 30,  # days
            'temp_files': 7,      # days
            'error_logs': 60,     # days
        }

    async def initialize(self):
        """Initialize the service with database connection"""
        self.db = get_database()

    async def cleanup_expired_data(self) -> Dict[str, int]:
        """
        Clean up expired data based on retention policies
        Returns a dictionary with cleanup statistics
        """
        if not self.db:
            await self.initialize()

        cleanup_stats = {}

        for collection, days in self.retention_policies.items():
            try:
                cutoff_date = datetime.utcnow() - timedelta(days=days)

                # Handle different collection types
                if collection == 'user_sessions':
                    result = await self.db.user_sessions.delete_many({
                        'created_at': {'$lt': cutoff_date}
                    })
                elif collection == 'audit_logs':
                    result = await self.db.audit_logs.delete_many({
                        'timestamp': {'$lt': cutoff_date}
                    })
                elif collection == 'task_history':
                    result = await self.db.task_history.delete_many({
                        'completed_at': {'$lt': cutoff_date}
                    })
                elif collection == 'notification_logs':
                    result = await self.db.notification_logs.delete_many({
                        'sent_at': {'$lt': cutoff_date}
                    })
                elif collection == 'temp_files':
                    result = await self.db.temp_files.delete_many({
                        'uploaded_at': {'$lt': cutoff_date}
                    })
                elif collection == 'error_logs':
                    result = await self.db.error_logs.delete_many({
                        'timestamp': {'$lt': cutoff_date}
                    })

                cleanup_stats[collection] = result.deleted_count

            except Exception as e:
                print(f"Error cleaning up {collection}: {str(e)}")
                cleanup_stats[collection] = 0

        return cleanup_stats

    async def archive_old_data(self) -> Dict[str, int]:
        """
        Archive old data that exceeds retention policies
        Returns archive statistics
        """
        if not self.db:
            await self.initialize()

        archive_stats = {}

        # Archive completed projects older than 2 years
        cutoff_date = datetime.utcnow() - timedelta(days=730)

        try:
            # Move old projects to archive collection
            old_projects = await self.db.projects.find({
                'status': 'completed',
                'completed_at': {'$lt': cutoff_date}
            }).to_list(length=None)

            if old_projects:
                # Insert into archive collection
                await self.db.archived_projects.insert_many(old_projects)

                # Remove from main collection
                project_ids = [p['_id'] for p in old_projects]
                result = await self.db.projects.delete_many({
                    '_id': {'$in': project_ids}
                })

                archive_stats['archived_projects'] = result.deleted_count
            else:
                archive_stats['archived_projects'] = 0

        except Exception as e:
            print(f"Error archiving projects: {str(e)}")
            archive_stats['archived_projects'] = 0

        return archive_stats

    async def get_retention_status(self) -> Dict:
        """
        Get current retention status and upcoming cleanup dates
        """
        if not self.db:
            await self.initialize()

        status = {}

        for collection, days in self.retention_policies.items():
            try:
                # Get oldest record date
                oldest_record = await self.db[collection].find_one(
                    sort=[('created_at', 1)] if 'created_at' in await self._get_collection_fields(collection) else [('timestamp', 1)]
                )

                if oldest_record:
                    oldest_date = oldest_record.get('created_at') or oldest_record.get('timestamp')
                    if oldest_date:
                        status[collection] = {
                            'oldest_record': oldest_date,
                            'retention_days': days,
                            'expires_on': oldest_date + timedelta(days=days),
                            'days_until_expiry': (oldest_date + timedelta(days=days) - datetime.utcnow()).days
                        }
                    else:
                        status[collection] = {'status': 'no_date_field_found'}
                else:
                    status[collection] = {'status': 'no_records'}

            except Exception as e:
                status[collection] = {'error': str(e)}

        return status

    async def _get_collection_fields(self, collection_name: str) -> List[str]:
        """Get field names for a collection"""
        try:
            sample_doc = await self.db[collection_name].find_one()
            return list(sample_doc.keys()) if sample_doc else []
        except:
            return []

    async def run_maintenance(self) -> Dict:
        """
        Run complete maintenance cycle: cleanup + archive
        """
        print("Starting data retention maintenance...")

        cleanup_stats = await self.cleanup_expired_data()
        archive_stats = await self.archive_old_data()

        total_cleaned = sum(cleanup_stats.values())
        total_archived = sum(archive_stats.values())

        # Send notification if significant cleanup occurred
        if total_cleaned > 0 or total_archived > 0:
            await notification_service.send_admin_notification(
                subject="Data Retention Maintenance Completed",
                message=f"Cleaned up {total_cleaned} records and archived {total_archived} items."
            )

        result = {
            'cleanup_stats': cleanup_stats,
            'archive_stats': archive_stats,
            'total_cleaned': total_cleaned,
            'total_archived': total_archived,
            'timestamp': datetime.utcnow()
        }

        print(f"Data retention maintenance completed: {result}")
        return result


# Global instance
data_retention_service = DataRetentionService()


async def scheduled_data_cleanup():
    """
    Scheduled task to run data cleanup periodically
    Call this from a scheduler (e.g., APScheduler)
    """
    while True:
        try:
            await data_retention_service.run_maintenance()
        except Exception as e:
            print(f"Scheduled cleanup failed: {str(e)}")

        # Run daily
        await asyncio.sleep(86400)  # 24 hours
