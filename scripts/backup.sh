#!/bin/bash

# GravityPM Comprehensive Backup Script
# This script performs full backups of all critical data

BACKUP_DIR="/backups/$(date +%Y-%m-%d)"
LOG_FILE="/backups/backup_$(date +%F_%H-%M-%S).log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "$(date +%Y-%m-%d_%H-%M-%S): $1" | tee -a "$LOG_FILE"
}

log "Starting GravityPM backup process..."

# MongoDB backup
log "Starting MongoDB backup..."
if [ -n "$MONGODB_URL" ]; then
    mongodump --uri="$MONGODB_URL" --out="$BACKUP_DIR/mongodb_backup_$(date +%F_%H-%M-%S)" --gzip
    if [ $? -eq 0 ]; then
        log "MongoDB backup successful."
    else
        log "ERROR: MongoDB backup failed!"
        exit 1
    fi
else
    log "WARNING: MONGODB_URL not set, skipping MongoDB backup"
fi

# Redis backup
log "Starting Redis backup..."
REDIS_HOST=${REDIS_HOST:-localhost}
REDIS_PORT=${REDIS_PORT:-6379}

redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SAVE
if [ $? -eq 0 ]; then
    log "Redis snapshot saved."
    # Copy Redis dump.rdb to backup folder
    cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_backup_$(date +%F_%H-%M-%S).rdb"
    if [ $? -eq 0 ]; then
        log "Redis backup file copied."
    else
        log "ERROR: Failed to copy Redis backup file!"
        exit 1
    fi
else
    log "ERROR: Redis backup failed!"
    exit 1
fi

# Application configuration backup
log "Backing up application configuration..."
cp -r /app/config "$BACKUP_DIR/config_backup_$(date +%F_%H-%M-%S)" 2>/dev/null || log "WARNING: No config directory found"

# SSL certificates backup
log "Backing up SSL certificates..."
cp -r /app/ssl "$BACKUP_DIR/ssl_backup_$(date +%F_%H-%M-%S)" 2>/dev/null || log "WARNING: No SSL directory found"

# Environment variables backup (excluding sensitive data)
log "Backing up environment configuration..."
env | grep -v -E "(PASSWORD|SECRET|KEY)" > "$BACKUP_DIR/env_backup_$(date +%F_%H-%M-%S).txt"

# Compress the entire backup
log "Compressing backup..."
cd /backups
tar -czf "$(basename $BACKUP_DIR).tar.gz" "$(basename $BACKUP_DIR)"
if [ $? -eq 0 ]; then
    log "Backup compression successful."
    # Remove uncompressed backup to save space
    rm -rf "$BACKUP_DIR"
else
    log "ERROR: Backup compression failed!"
fi

# Cleanup old backups (keep last 30 days)
log "Cleaning up old backups..."
find /backups -name "*.tar.gz" -mtime +30 -delete
find /backups -name "*.gz" -mtime +30 -delete
find /backups -name "*.rdb" -mtime +30 -delete

log "Backup process completed successfully."
log "Backup location: /backups/$(basename $BACKUP_DIR).tar.gz"
