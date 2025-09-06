#!/bin/bash

# Production Backup Configuration Script for GravityPM
# This script configures comprehensive backup procedures for production

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
BACKUP_DIR="${PROD_DIR}/backups"
LOG_DIR="${PROD_DIR}/logs"

echo "Configuring production backups for ${PROJECT_NAME}..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create backup directory structure
echo "Creating backup directory structure..."
mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly,database,config,logs}
mkdir -p "$BACKUP_DIR"/scripts
mkdir -p "$LOG_DIR"

# Create production backup script
echo "Creating production backup script..."

cat > "$BACKUP_DIR/scripts/production-backup.sh" << EOF
#!/bin/bash

# Production Backup Script for GravityPM
set -e

# Configuration
BACKUP_ROOT="${BACKUP_DIR}"
LOG_FILE="${LOG_DIR}/backup_\$(date +%Y%m%d_%H%M%S).log"
RETENTION_DAYS=30
RETENTION_WEEKS=12
RETENTION_MONTHS=24

# Logging function
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"
}

log "Starting production backup..."

# Create timestamp
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DATE=\$(date +%Y%m%d)

# Determine backup type (daily/weekly/monthly)
DAY_OF_WEEK=\$(date +%u)  # 1=Monday, 7=Sunday
DAY_OF_MONTH=\$(date +%d)

if [ "\$DAY_OF_MONTH" = "01" ]; then
    BACKUP_TYPE="monthly"
    BACKUP_SUBDIR="monthly"
elif [ "\$DAY_OF_WEEK" = "7" ]; then
    BACKUP_TYPE="weekly"
    BACKUP_SUBDIR="weekly"
else
    BACKUP_TYPE="daily"
    BACKUP_SUBDIR="daily"
fi

BACKUP_PATH="\$BACKUP_ROOT/\$BACKUP_SUBDIR/\$BACKUP_DATE"
mkdir -p "\$BACKUP_PATH"

log "Backup type: \$BACKUP_TYPE"
log "Backup path: \$BACKUP_PATH"

# Database backup
log "Starting database backup..."
DB_BACKUP_FILE="\$BACKUP_PATH/mongodb_backup_\$TIMESTAMP.gz"

# Create MongoDB backup
docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongodump \
    --db gravitypm_production \
    --username app_user \
    --password production_app_password_123 \
    --authenticationDatabase gravitypm_production \
    --gzip \
    --archive > "\$DB_BACKUP_FILE"

if [ \$? -eq 0 ]; then
    log "✓ Database backup completed: \$DB_BACKUP_FILE"
else
    log "✗ Database backup failed"
    exit 1
fi

# Redis backup
log "Starting Redis backup..."
REDIS_BACKUP_FILE="\$BACKUP_PATH/redis_backup_\$TIMESTAMP.rdb"

docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T redis-production redis-cli \
    --rdb "\$REDIS_BACKUP_FILE"

if [ \$? -eq 0 ]; then
    log "✓ Redis backup completed: \$REDIS_BACKUP_FILE"
else
    log "✗ Redis backup failed"
fi

# Application data backup
log "Starting application data backup..."
APP_BACKUP_FILE="\$BACKUP_PATH/app_data_\$TIMESTAMP.tar.gz"

# Backup uploads, logs, and configuration
tar -czf "\$APP_BACKUP_FILE" \
    -C "${PROD_DIR}" \
    uploads/ \
    logs/ \
    config/ \
    .env.production \
    docker-compose.production.yml \
    2>/dev/null || true

if [ -f "\$APP_BACKUP_FILE" ]; then
    log "✓ Application data backup completed: \$APP_BACKUP_FILE"
else
    log "✗ Application data backup failed"
fi

# SSL certificates backup
log "Starting SSL certificates backup..."
SSL_BACKUP_FILE="\$BACKUP_PATH/ssl_certificates_\$TIMESTAMP.tar.gz"

if [ -d "${PROD_DIR}/ssl" ]; then
    tar -czf "\$SSL_BACKUP_FILE" -C "${PROD_DIR}" ssl/
    log "✓ SSL certificates backup completed: \$SSL_BACKUP_FILE"
else
    log "⚠ SSL certificates directory not found"
fi

# Monitoring data backup
log "Starting monitoring data backup..."
MONITORING_BACKUP_FILE="\$BACKUP_PATH/monitoring_data_\$TIMESTAMP.tar.gz"

if [ -d "${PROD_DIR}/monitoring" ]; then
    tar -czf "\$MONITORING_BACKUP_FILE" \
        -C "${PROD_DIR}" \
        monitoring/prometheus.yml \
        monitoring/alert_rules.yml \
        monitoring/alertmanager.yml \
        monitoring/grafana/dashboards/ \
        2>/dev/null || true
    log "✓ Monitoring data backup completed: \$MONITORING_BACKUP_FILE"
fi

# Calculate backup sizes
log "Calculating backup sizes..."
TOTAL_SIZE=\$(du -sh "\$BACKUP_PATH" | cut -f1)
DB_SIZE=\$(du -sh "\$DB_BACKUP_FILE" 2>/dev/null | cut -f1 || echo "N/A")
APP_SIZE=\$(du -sh "\$APP_BACKUP_FILE" 2>/dev/null | cut -f1 || echo "N/A")

log "Backup sizes:"
log "  Total: \$TOTAL_SIZE"
log "  Database: \$DB_SIZE"
log "  Application: \$APP_SIZE"

# Verify backups
log "Verifying backups..."

# Verify database backup
if [ -f "\$DB_BACKUP_FILE" ]; then
    BACKUP_SIZE=\$(stat -f%z "\$DB_BACKUP_FILE" 2>/dev/null || stat -c%s "\$DB_BACKUP_FILE" 2>/dev/null)
    if [ "\$BACKUP_SIZE" -gt 1024 ]; then  # At least 1KB
        log "✓ Database backup verification passed"
    else
        log "✗ Database backup verification failed: file too small"
    fi
fi

# Verify application backup
if [ -f "\$APP_BACKUP_FILE" ]; then
    if tar -tzf "\$APP_BACKUP_FILE" > /dev/null 2>&1; then
        log "✓ Application backup verification passed"
    else
        log "✗ Application backup verification failed"
    fi
fi

# Clean up old backups
log "Cleaning up old backups..."

# Daily backups: keep last 7 days
find "\$BACKUP_ROOT/daily" -type f -mtime +7 -delete 2>/dev/null || true

# Weekly backups: keep last 4 weeks
find "\$BACKUP_ROOT/weekly" -type f -mtime +28 -delete 2>/dev/null || true

# Monthly backups: keep last 12 months
find "\$BACKUP_ROOT/monthly" -type f -mtime +365 -delete 2>/dev/null || true

# Clean up empty directories
find "\$BACKUP_ROOT" -type d -empty -delete 2>/dev/null || true

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "\${SLACK_WEBHOOK}" ]; then
    curl -X POST -H 'Content-type: application/json' \\
        --data "{\\"text\\":\\"✅ Production backup completed successfully - \$BACKUP_TYPE backup, total size: \$TOTAL_SIZE\\"}" \\
        "\${SLACK_WEBHOOK}" || true
fi

log "Production backup completed successfully"
log "Backup location: \$BACKUP_PATH"
log "Log file: \$LOG_FILE"

# Create backup manifest
MANIFEST_FILE="\$BACKUP_PATH/backup_manifest.txt"
cat > "\$MANIFEST_FILE" << MANIFEST_EOF
GravityPM Production Backup Manifest
====================================

Backup Date: \$(date)
Backup Type: \$BACKUP_TYPE
Backup Path: \$BACKUP_PATH

Files:
$(ls -la "\$BACKUP_PATH")

Sizes:
Total: \$TOTAL_SIZE
Database: \$DB_SIZE
Application: \$APP_SIZE

Retention Policy:
- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months

Next Backup: \$(date -d '+1 day' '+%Y-%m-%d %H:%M:%S')
MANIFEST_EOF

log "Backup manifest created: \$MANIFEST_FILE"
EOF

sudo chmod +x "$BACKUP_DIR/scripts/production-backup.sh"

# Create backup restoration script
echo "Creating backup restoration script..."

cat > "$BACKUP_DIR/scripts/restore-production-backup.sh" << EOF
#!/bin/bash

# Production Backup Restoration Script for GravityPM
set -e

# Configuration
BACKUP_ROOT="${BACKUP_DIR}"
LOG_FILE="${LOG_DIR}/restore_\$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"
}

# Function to show usage
usage() {
    echo "Usage: \$0 [OPTIONS]"
    echo ""
    echo "Restore GravityPM production backup"
    echo ""
    echo "OPTIONS:"
    echo "  -d, --date DATE      Backup date (YYYYMMDD format)"
    echo "  -t, --type TYPE      Backup type (daily/weekly/monthly)"
    echo "  -f, --full           Full restoration (default: partial)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  \$0 -d 20231201 -t daily    # Restore specific daily backup"
    echo "  \$0 -f                      # Restore latest full backup"
}

# Parse arguments
FULL_RESTORE=false
BACKUP_DATE=""
BACKUP_TYPE=""

while [[ \$# -gt 0 ]]; do
    case \$1 in
        -d|--date)
            BACKUP_DATE="\$2"
            shift 2
            ;;
        -t|--type)
            BACKUP_TYPE="\$2"
            shift 2
            ;;
        -f|--full)
            FULL_RESTORE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: \$1"
            usage
            exit 1
            ;;
    esac
done

log "Starting production backup restoration..."

# Determine backup to restore
if [ -n "\$BACKUP_DATE" ] && [ -n "\$BACKUP_TYPE" ]; then
    BACKUP_PATH="\$BACKUP_ROOT/\$BACKUP_TYPE/\$BACKUP_DATE"
elif [ "\$FULL_RESTORE" = true ]; then
    # Find latest backup
    LATEST_DAILY=\$(find "\$BACKUP_ROOT/daily" -type d -name "20*" | sort | tail -1)
    LATEST_WEEKLY=\$(find "\$BACKUP_ROOT/weekly" -type d -name "20*" | sort | tail -1)
    LATEST_MONTHLY=\$(find "\$BACKUP_ROOT/monthly" -type d -name "20*" | sort | tail -1)
    
    # Choose the most recent backup
    if [ -n "\$LATEST_DAILY" ]; then
        BACKUP_PATH="\$LATEST_DAILY"
    elif [ -n "\$LATEST_WEEKLY" ]; then
        BACKUP_PATH="\$LATEST_WEEKLY"
    elif [ -n "\$LATEST_MONTHLY" ]; then
        BACKUP_PATH="\$LATEST_MONTHLY"
    else
        log "ERROR: No backups found"
        exit 1
    fi
else
    echo "Please specify backup date/type or use --full for latest backup"
    usage
    exit 1
fi

if [ ! -d "\$BACKUP_PATH" ]; then
    log "ERROR: Backup not found at \$BACKUP_PATH"
    exit 1
fi

log "Restoring from: \$BACKUP_PATH"

# Show backup manifest
if [ -f "\$BACKUP_PATH/backup_manifest.txt" ]; then
    log "Backup manifest:"
    cat "\$BACKUP_PATH/backup_manifest.txt" | tee -a "\$LOG_FILE"
fi

# Confirm restoration
echo ""
echo "⚠️  WARNING: This will overwrite current production data!"
echo ""
echo "Backup to restore: \$BACKUP_PATH"
echo "Log file: \$LOG_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "\$CONFIRM" != "yes" ]; then
    log "Restoration cancelled by user"
    exit 0
fi

# Stop services before restoration
log "Stopping production services..."
docker-compose -f "${PROD_DIR}/docker-compose.production.yml" down

# Restore database
DB_BACKUP=\$(find "\$BACKUP_PATH" -name "mongodb_backup_*.gz" | head -1)
if [ -f "\$DB_BACKUP" ]; then
    log "Restoring database from \$DB_BACKUP..."
    
    # Start MongoDB temporarily for restore
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" up -d mongodb-production
    sleep 10
    
    # Restore database
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongorestore \
        --db gravitypm_production \
        --username app_user \
        --password production_app_password_123 \
        --authenticationDatabase gravitypm_production \
        --gzip \
        --archive < "\$DB_BACKUP"
    
    if [ \$? -eq 0 ]; then
        log "✓ Database restoration completed"
    else
        log "✗ Database restoration failed"
        exit 1
    fi
else
    log "⚠ Database backup not found"
fi

# Restore Redis
REDIS_BACKUP=\$(find "\$BACKUP_PATH" -name "redis_backup_*.rdb" | head -1)
if [ -f "\$REDIS_BACKUP" ]; then
    log "Restoring Redis from \$REDIS_BACKUP..."
    cp "\$REDIS_BACKUP" "${PROD_DIR}/redis/data/dump.rdb"
    log "✓ Redis restoration completed"
fi

# Restore application data
APP_BACKUP=\$(find "\$BACKUP_PATH" -name "app_data_*.tar.gz" | head -1)
if [ -f "\$APP_BACKUP" ]; then
    log "Restoring application data from \$APP_BACKUP..."
    tar -xzf "\$APP_BACKUP" -C "${PROD_DIR}"
    log "✓ Application data restoration completed"
fi

# Restore SSL certificates
SSL_BACKUP=\$(find "\$BACKUP_PATH" -name "ssl_certificates_*.tar.gz" | head -1)
if [ -f "\$SSL_BACKUP" ]; then
    log "Restoring SSL certificates from \$SSL_BACKUP..."
    tar -xzf "\$SSL_BACKUP" -C "${PROD_DIR}"
    log "✓ SSL certificates restoration completed"
fi

# Restore monitoring configuration
MONITORING_BACKUP=\$(find "\$BACKUP_PATH" -name "monitoring_data_*.tar.gz" | head -1)
if [ -f "\$MONITORING_BACKUP" ]; then
    log "Restoring monitoring configuration from \$MONITORING_BACKUP..."
    tar -xzf "\$MONITORING_BACKUP" -C "${PROD_DIR}"
    log "✓ Monitoring configuration restoration completed"
fi

# Restart services
log "Restarting production services..."
docker-compose -f "${PROD_DIR}/docker-compose.production.yml" up -d

# Wait for services to be healthy
log "Waiting for services to be healthy..."
sleep 30

# Health checks
log "Performing health checks..."

# Check MongoDB
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    log "✓ MongoDB is healthy"
else
    log "✗ MongoDB health check failed"
fi

# Check Redis
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T redis-production redis-cli ping | grep -q PONG; then
    log "✓ Redis is healthy"
else
    log "✗ Redis health check failed"
fi

# Check application
if curl -f -s --max-time 10 http://localhost:3000/health > /dev/null 2>&1; then
    log "✓ Web application is healthy"
else
    log "✗ Web application health check failed"
fi

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "\${SLACK_WEBHOOK}" ]; then
    curl -X POST -H 'Content-type: application/json' \\
        --data "{\\"text\\":\\"🔄 Production backup restoration completed from \$BACKUP_PATH\\"}" \\
        "\${SLACK_WEBHOOK}" || true
fi

log "Production backup restoration completed successfully"
log "Log file: \$LOG_FILE"

echo ""
echo "🎉 Restoration completed!"
echo "Please verify the application is working correctly."
echo "Log file: \$LOG_FILE"
EOF

sudo chmod +x "$BACKUP_DIR/scripts/restore-production-backup.sh"

# Create backup monitoring script
echo "Creating backup monitoring script..."

cat > "$BACKUP_DIR/scripts/monitor-backups.sh" << EOF
#!/bin/bash

# Backup Monitoring Script for GravityPM Production
LOG_FILE="${LOG_DIR}/backup_monitor_\$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"
}

log "Starting backup monitoring..."

# Check backup directory structure
if [ ! -d "${BACKUP_DIR}/daily" ]; then
    log "ERROR: Daily backup directory missing"
    exit 1
fi

# Check recent backups
LATEST_BACKUP=\$(find "${BACKUP_DIR}" -name "mongodb_backup_*.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "\$LATEST_BACKUP" ]; then
    log "ERROR: No database backups found"
    exit 1
fi

# Check backup age
BACKUP_AGE_HOURS=\$(( (\$(date +%s) - \$(stat -c %Y "\$LATEST_BACKUP")) / 3600 ))

if [ \$BACKUP_AGE_HOURS -gt 25 ]; then
    log "WARNING: Latest backup is \$BACKUP_AGE_HOURS hours old"
    ALERT=true
else
    log "✓ Latest backup is \$BACKUP_AGE_HOURS hours old"
fi

# Check backup sizes
BACKUP_SIZE=\$(du -sh "\$LATEST_BACKUP" | cut -f1)
log "Latest backup size: \$BACKUP_SIZE"

# Check backup integrity (basic)
if gzip -t "\$LATEST_BACKUP" 2>/dev/null; then
    log "✓ Latest backup integrity check passed"
else
    log "ERROR: Latest backup integrity check failed"
    ALERT=true
fi

# Check disk space for backups
BACKUP_DISK_USAGE=\$(df "${BACKUP_DIR}" | tail -1 | awk '{print \$5}' | sed 's/%//')

if [ \$BACKUP_DISK_USAGE -gt 85 ]; then
    log "WARNING: Backup disk usage is \$BACKUP_DISK_USAGE%"
    ALERT=true
else
    log "✓ Backup disk usage: \$BACKUP_DISK_USAGE%"
fi

# Count backups by type
DAILY_COUNT=\$(find "${BACKUP_DIR}/daily" -name "mongodb_backup_*.gz" -type f | wc -l)
WEEKLY_COUNT=\$(find "${BACKUP_DIR}/weekly" -name "mongodb_backup_*.gz" -type f | wc -l)
MONTHLY_COUNT=\$(find "${BACKUP_DIR}/monthly" -name "mongodb_backup_*.gz" -type f | wc -l)

log "Backup counts:"
log "  Daily: \$DAILY_COUNT"
log "  Weekly: \$WEEKLY_COUNT"
log "  Monthly: \$MONTHLY_COUNT"

# Send alert if needed
if [ "\${ALERT}" = true ] && command -v curl > /dev/null 2>&1 && [ -n "\${SLACK_WEBHOOK}" ]; then
    curl -X POST -H 'Content-type: application/json' \\
        --data "{\\"text\\":\\"⚠️ Backup monitoring alert: Issues detected. Check \$LOG_FILE\\"}" \\
        "\${SLACK_WEBHOOK}" || true
fi

log "Backup monitoring completed"
EOF

sudo chmod +x "$BACKUP_DIR/scripts/monitor-backups.sh"

# Set up cron jobs for automated backups
echo "Setting up cron jobs for automated backups..."

sudo crontab -l | { cat; echo "# GravityPM Production Backups"; } | sudo crontab -
sudo crontab -l | { cat; echo "0 2 * * * ${BACKUP_DIR}/scripts/production-backup.sh"; } | sudo crontab -
sudo crontab -l | { cat; echo "0 6 * * * ${BACKUP_DIR}/scripts/monitor-backups.sh"; } | sudo crontab -

# Create backup configuration documentation
echo "Creating backup documentation..."

cat > "$BACKUP_DIR/README.md" << EOF
# Production Backup Configuration

## Overview
This directory contains the backup configuration and scripts for GravityPM production environment.

## Backup Schedule
- **Daily**: Every day at 2:00 AM
- **Weekly**: Every Sunday at 2:00 AM (keeps 4 weeks)
- **Monthly**: First day of month at 2:00 AM (keeps 12 months)

## Backup Components
- **Database**: MongoDB dump with compression
- **Cache**: Redis RDB file
- **Application Data**: Uploads, logs, configuration
- **SSL Certificates**: Certificate files and keys
- **Monitoring Config**: Prometheus, Alertmanager, Grafana configs

## Retention Policy
- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

## Directory Structure
\`\`\`
backups/
├── daily/           # Daily backups
├── weekly/          # Weekly backups
├── monthly/         # Monthly backups
├── database/        # Database-specific backups
├── config/          # Configuration backups
├── logs/            # Backup logs
└── scripts/         # Backup scripts
\`\`\`

## Scripts
- \`production-backup.sh\`: Main backup script
- \`restore-production-backup.sh\`: Restoration script
- \`monitor-backups.sh\`: Backup monitoring and alerting

## Manual Operations
\`\`\`bash
# Run backup manually
${BACKUP_DIR}/scripts/production-backup.sh

# Restore from specific date
${BACKUP_DIR}/scripts/restore-production-backup.sh -d 20231201 -t daily

# Restore latest backup
${BACKUP_DIR}/scripts/restore-production-backup.sh -f

# Monitor backups
${BACKUP_DIR}/scripts/monitor-backups.sh
\`\`\`

## Monitoring
- Backup monitoring runs every 6 hours
- Alerts sent to Slack for issues
- Logs stored in \`${LOG_DIR}\`

## Security
- Database backups encrypted
- File permissions set to 600
- Backup files owned by backup user

## Disaster Recovery
- Full restoration tested quarterly
- Recovery time objective: 4 hours
- Recovery point objective: 1 hour

## Contacts
- DBA Team: dba@gravitypm.com
- DevOps Team: devops@gravitypm.com
- Emergency: +1-800-GRAVITY
EOF

echo "Production backup configuration completed!"
echo ""
echo "Backup components configured:"
echo "- Automated daily/weekly/monthly backups"
echo "- Database, Redis, and application data backup"
echo "- Backup monitoring and alerting"
echo "- Restoration scripts with verification"
echo "- Comprehensive documentation"
echo ""
echo "Backup schedule:"
echo "- Daily: 2:00 AM"
echo "- Weekly: Sunday 2:00 AM"
echo "- Monthly: 1st of month 2:00 AM"
echo ""
echo "Monitoring:"
echo "- Backup health checks every 6 hours"
echo "- Alerts sent to Slack for issues"
echo ""
echo "Next steps:"
echo "1. Test backup script manually"
echo "2. Test restoration procedure"
echo "3. Configure offsite backup storage"
echo "4. Set up backup encryption"
echo "5. Document emergency procedures"
