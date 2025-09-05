#!/bin/bash

# MongoDB backup
echo "Starting MongoDB backup..."
mongodump --uri="$MONGODB_URL" --archive=/backups/mongo_backup_$(date +%F_%H-%M-%S).gz --gzip
if [ $? -eq 0 ]; then
  echo "MongoDB backup successful."
else
  echo "MongoDB backup failed!"
  exit 1
fi

# Redis backup
echo "Starting Redis backup..."
redis-cli -h ${REDIS_HOST:-localhost} -p ${REDIS_PORT:-6379} SAVE
if [ $? -eq 0 ]; then
  echo "Redis snapshot saved."
else
  echo "Redis backup failed!"
  exit 1
fi

# Copy Redis dump.rdb to backup folder
cp /var/lib/redis/dump.rdb /backups/redis_backup_$(date +%F_%H-%M-%S).rdb
if [ $? -eq 0 ]; then
  echo "Redis backup file copied."
else
  echo "Failed to copy Redis backup file!"
  exit 1
fi

echo "Backup completed successfully."
