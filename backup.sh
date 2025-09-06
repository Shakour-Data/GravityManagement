#!/bin/bash

# GravityPM Automated Backup Script
# This script creates backups of the database, application files, and configurations

# Configuration
BACKUP_DIR="/opt/backup/gravitypm"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gravitypm_backup_$DATE"
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Database backup (MongoDB)
echo "Starting MongoDB backup..."
mongodump --db gravitypm --out $BACKUP_DIR/$BACKUP_NAME/mongodb

# Redis backup (if using persistence)
echo "Starting Redis backup..."
redis-cli SAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/$BACKUP_NAME/redis/

# Application files backup
echo "Starting application files backup..."
tar -czf $BACKUP_DIR/$BACKUP_NAME/app.tar.gz \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='*.log' \
    /opt/gravitypm/

# Configuration files backup
echo "Starting configuration backup..."
tar -czf $BACKUP_DIR/$BACKUP_NAME/config.tar.gz \
    /etc/nginx/sites-available/ \
    /etc/systemd/system/gravitypm* \
    /opt/gravitypm/docker-compose*.yml \
    /opt/gravitypm/.env

# Create backup manifest
cat > $BACKUP_DIR/$BACKUP_NAME/manifest.txt << EOF
Backup Information:
- Date: $(date)
- Hostname: $(hostname)
- Backup Type: Full
- Components:
  - MongoDB Database
  - Redis Cache
  - Application Files
  - Configuration Files

Backup Location: $BACKUP_DIR/$BACKUP_NAME
Backup Size: $(du -sh $BACKUP_DIR/$BACKUP_NAME | cut -f1)
EOF

# Compress the entire backup
echo "Compressing backup..."
tar -czf $BACKUP_DIR/${BACKUP_NAME}.tar.gz -C $BACKUP_DIR $BACKUP_NAME

# Encrypt the backup
echo "Encrypting backup..."
gpg --symmetric --cipher-algo AES256 --output $BACKUP_DIR/${BACKUP_NAME}.tar.gz.gpg $BACKUP_DIR/${BACKUP_NAME}.tar.gz

# Remove unencrypted backup
rm $BACKUP_DIR/${BACKUP_NAME}.tar.gz

# Clean up uncompressed backup
rm -rf $BACKUP_DIR/$BACKUP_NAME

# Clean up old backups (older than RETENTION_DAYS)
echo "Cleaning up old backups..."
find $BACKUP_DIR -name "gravitypm_backup_*.tar.gz.gpg" -mtime +$RETENTION_DAYS -delete

# Upload to cloud storage (optional - uncomment and configure)
# aws s3 cp $BACKUP_DIR/${BACKUP_NAME}.tar.gz.gpg s3://gravitypm-backups/

echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz.gpg"
echo "Backup size: $(du -sh $BACKUP_DIR/${BACKUP_NAME}.tar.gz.gpg | cut -f1)"
