#!/bin/bash

# Automated Backup Setup Script for GravityPM
# This script sets up automated daily backups for MongoDB and Redis

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
BACKUP_DIR="/opt/backup/${PROJECT_NAME}/${ENVIRONMENT}"
LOG_DIR="/var/log/${PROJECT_NAME}"
RETENTION_DAYS=30

# Create backup directories
echo "Creating backup directories..."
sudo mkdir -p "$BACKUP_DIR/mongodb"
sudo mkdir -p "$BACKUP_DIR/redis"
sudo mkdir -p "$BACKUP_DIR/config"
sudo mkdir -p "$LOG_DIR"

# Set permissions
sudo chown -R $USER:$USER "$BACKUP_DIR"
sudo chown -R $USER:$USER "$LOG_DIR"

# MongoDB backup function
setup_mongodb_backup() {
    echo "Setting up MongoDB backup..."

    cat > "$BACKUP_DIR/mongodb/backup.sh" << 'EOF'
#!/bin/bash

# MongoDB Backup Script
BACKUP_DIR="/opt/backup/gravitypm/production/mongodb"
LOG_FILE="/var/log/gravitypm/mongodb_backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting MongoDB backup..."

# Create backup
if mongodump --uri="$MONGODB_URL" --out="$BACKUP_DIR/backup_$DATE" --gzip; then
    log "MongoDB backup completed successfully: backup_$DATE"

    # Create archive
    cd "$BACKUP_DIR"
    tar -czf "backup_$DATE.tar.gz" "backup_$DATE"
    rm -rf "backup_$DATE"

    # Clean up old backups
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

    log "Backup archive created and old backups cleaned up"
else
    log "ERROR: MongoDB backup failed"
    exit 1
fi

log "MongoDB backup process completed"
EOF

    chmod +x "$BACKUP_DIR/mongodb/backup.sh"
}

# Redis backup function
setup_redis_backup() {
    echo "Setting up Redis backup..."

    cat > "$BACKUP_DIR/redis/backup.sh" << 'EOF'
#!/bin/bash

# Redis Backup Script
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
BACKUP_DIR="/opt/backup/gravitypm/production/redis"
LOG_FILE="/var/log/gravitypm/redis_backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting Redis backup..."

# Create backup using BGSAVE
if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" BGSAVE; then
    log "Redis BGSAVE initiated"

    # Wait for save to complete
    sleep 10

    # Copy dump file
    sudo cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_backup_$DATE.rdb"

    # Create archive
    cd "$BACKUP_DIR"
    gzip "redis_backup_$DATE.rdb"

    # Clean up old backups
    find "$BACKUP_DIR" -name "redis_backup_*.rdb.gz" -mtime +$RETENTION_DAYS -delete

    log "Redis backup completed: redis_backup_$DATE.rdb.gz"
else
    log "ERROR: Redis backup failed"
    exit 1
fi

log "Redis backup process completed"
EOF

    chmod +x "$BACKUP_DIR/redis/backup.sh"
}

# Configuration backup function
setup_config_backup() {
    echo "Setting up configuration backup..."

    cat > "$BACKUP_DIR/config/backup.sh" << 'EOF'
#!/bin/bash

# Configuration Backup Script
BACKUP_DIR="/opt/backup/gravitypm/production/config"
LOG_FILE="/var/log/gravitypm/config_backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting configuration backup..."

# Backup environment files
tar -czf "$BACKUP_DIR/env_backup_$DATE.tar.gz" \
    /opt/gravitypm/.env* \
    /opt/gravitypm/docker-compose*.yml \
    /opt/gravitypm/nginx.conf \
    /etc/nginx/sites-available/gravitypm* \
    2>/dev/null || true

# Backup SSL certificates
tar -czf "$BACKUP_DIR/ssl_backup_$DATE.tar.gz" \
    /opt/gravitypm/ssl/ \
    2>/dev/null || true

# Clean up old backups
find "$BACKUP_DIR" -name "*_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

log "Configuration backup completed: config_backup_$DATE.tar.gz"
EOF

    chmod +x "$BACKUP_DIR/config/backup.sh"
}

# Set up cron jobs
setup_cron_jobs() {
    echo "Setting up cron jobs..."

    # MongoDB backup - daily at 2 AM
    (crontab -l ; echo "0 2 * * * $BACKUP_DIR/mongodb/backup.sh") | crontab -

    # Redis backup - daily at 3 AM
    (crontab -l ; echo "0 3 * * * $BACKUP_DIR/redis/backup.sh") | crontab -

    # Configuration backup - daily at 4 AM
    (crontab -l ; echo "0 4 * * * $BACKUP_DIR/config/backup.sh") | crontab -

    echo "Cron jobs configured successfully"
}

# Set up monitoring and alerts
setup_monitoring() {
    echo "Setting up backup monitoring..."

    cat > "$BACKUP_DIR/monitor.sh" << 'EOF'
#!/bin/bash

# Backup Monitoring Script
LOG_FILE="/var/log/gravitypm/backup_monitor.log"
ALERT_EMAIL="admin@gravitypm.com"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check backup age
check_backup_age() {
    local backup_type=$1
    local backup_dir=$2
    local max_age=25 # hours

    local latest_backup=$(find "$backup_dir" -name "*backup*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -z "$latest_backup" ]; then
        log "ERROR: No $backup_type backups found"
        echo "ALERT: No $backup_type backups found" | mail -s "Backup Alert" "$ALERT_EMAIL"
        return 1
    fi

    local backup_age=$(($(date +%s) - $(stat -c %Y "$latest_backup")))

    if [ $backup_age -gt $(($max_age * 3600)) ]; then
        log "WARNING: Latest $backup_type backup is older than $max_age hours: $latest_backup"
        echo "WARNING: Latest $backup_type backup is old" | mail -s "Backup Warning" "$ALERT_EMAIL"
    else
        log "OK: Latest $backup_type backup is recent: $(basename "$latest_backup")"
    fi
}

log "Starting backup monitoring..."

check_backup_age "MongoDB" "/opt/backup/gravitypm/production/mongodb"
check_backup_age "Redis" "/opt/backup/gravitypm/production/redis"
check_backup_age "Config" "/opt/backup/gravitypm/production/config"

log "Backup monitoring completed"
EOF

    chmod +x "$BACKUP_DIR/monitor.sh"

    # Add monitoring to cron (every 6 hours)
    (crontab -l ; echo "0 */6 * * * $BACKUP_DIR/monitor.sh") | crontab -
}

# Main setup
echo "Setting up automated backups for ${ENVIRONMENT} environment..."

setup_mongodb_backup
setup_redis_backup
setup_config_backup
setup_cron_jobs
setup_monitoring

echo "Automated backup setup completed!"
echo "Backup directory: $BACKUP_DIR"
echo "Log directory: $LOG_DIR"
echo ""
echo "Backup schedule:"
echo "- MongoDB: Daily at 2:00 AM"
echo "- Redis: Daily at 3:00 AM"
echo "- Configuration: Daily at 4:00 AM"
echo "- Monitoring: Every 6 hours"
echo ""
echo "Retention policy: $RETENTION_DAYS days"
