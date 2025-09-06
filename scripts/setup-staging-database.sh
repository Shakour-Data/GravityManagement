#!/bin/bash

# Staging Database Setup Script for GravityPM
# This script configures MongoDB and Redis for staging environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="staging"
DB_NAME="${PROJECT_NAME}_${ENVIRONMENT}"
MONGO_PORT=27017
REDIS_PORT=6379

echo "Setting up staging database for ${PROJECT_NAME}..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y mongodb redis-server python3-pip

# Configure MongoDB for staging
echo "Configuring MongoDB for staging..."

# Stop existing MongoDB service
sudo systemctl stop mongod || true

# Create MongoDB data directory
sudo mkdir -p /data/db
sudo chown mongodb:mongodb /data/db

# Create MongoDB configuration
cat > /etc/mongod.conf << EOF
# MongoDB Staging Configuration
storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

net:
  port: ${MONGO_PORT}
  bindIp: 127.0.0.1

security:
  authorization: enabled
  javascriptEnabled: false

replication:
  replSetName: "rs0"

operationProfiling:
  slowOpThresholdMs: 100
  mode: slowOp

setParameter:
  wiredTigerMaxCacheOverflowSizeGB: 0.1
EOF

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# Wait for MongoDB to start
sleep 10

# Create admin user
echo "Creating MongoDB admin user..."
mongosh --eval "
db.getSiblingDB('admin').createUser({
  user: 'admin',
  pwd: 'staging_admin_password_123',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' }
  ]
})
"

# Create application database and user
echo "Creating application database and user..."
mongosh -u admin -p staging_admin_password_123 --authenticationDatabase admin --eval "
db.getSiblingDB('${DB_NAME}').createUser({
  user: 'app_user',
  pwd: 'staging_app_password_123',
  roles: [
    { role: 'readWrite', db: '${DB_NAME}' }
  ]
})
"

# Create database collections with indexes
echo "Creating database collections and indexes..."
mongosh -u app_user -p staging_app_password_123 --authenticationDatabase ${DB_NAME} ${DB_NAME} << 'EOF'
db.createCollection('users')
db.users.createIndex({ "email": 1 }, { unique: true })
db.users.createIndex({ "username": 1 }, { unique: true })
db.users.createIndex({ "created_at": 1 })
db.users.createIndex({ "last_login": 1 })

db.createCollection('projects')
db.projects.createIndex({ "owner_id": 1 })
db.projects.createIndex({ "created_at": 1 })
db.projects.createIndex({ "status": 1 })

db.createCollection('tasks')
db.tasks.createIndex({ "project_id": 1 })
db.tasks.createIndex({ "assignee_id": 1 })
db.tasks.createIndex({ "status": 1 })
db.tasks.createIndex({ "priority": 1 })
db.tasks.createIndex({ "due_date": 1 })

db.createCollection('teams')
db.teams.createIndex({ "owner_id": 1 })
db.teams.createIndex({ "created_at": 1 })

db.createCollection('audit_logs')
db.audit_logs.createIndex({ "timestamp": 1 })
db.audit_logs.createIndex({ "user_id": 1 })
db.audit_logs.createIndex({ "event_type": 1 })
db.audit_logs.createIndex({ "ip_address": 1 })

db.createCollection('sessions')
db.sessions.createIndex({ "user_id": 1 })
db.sessions.createIndex({ "expires_at": 1 })
db.sessions.createIndex({ "created_at": 1 })

db.createCollection('notifications')
db.notifications.createIndex({ "user_id": 1 })
db.notifications.createIndex({ "created_at": 1 })
db.notifications.createIndex({ "read": 1 })

db.createCollection('files')
db.files.createIndex({ "project_id": 1 })
db.files.createIndex({ "uploaded_by": 1 })
db.files.createIndex({ "uploaded_at": 1 })

db.createCollection('comments')
db.comments.createIndex({ "task_id": 1 })
db.comments.createIndex({ "author_id": 1 })
db.comments.createIndex({ "created_at": 1 })

db.createCollection('time_entries')
db.time_entries.createIndex({ "user_id": 1 })
db.time_entries.createIndex({ "task_id": 1 })
db.time_entries.createIndex({ "date": 1 })

db.createCollection('reports')
db.reports.createIndex({ "user_id": 1 })
db.reports.createIndex({ "created_at": 1 })
db.reports.createIndex({ "type": 1 })
EOF

# Configure Redis for staging
echo "Configuring Redis for staging..."

# Stop existing Redis service
sudo systemctl stop redis-server || true

# Create Redis configuration
cat > /etc/redis/redis.conf << EOF
# Redis Staging Configuration
bind 127.0.0.1
port ${REDIS_PORT}
timeout 0
tcp-keepalive 300
daemonize yes
supervised systemd
loglevel notice
logfile /var/log/redis/redis.log
databases 16

# Security
requirepass staging_redis_password_123
protected-mode yes

# Persistence
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Append only file
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Disable dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command SHUTDOWN SHUTDOWN_REDIS
rename-command CONFIG CONFIG_REDIS
EOF

# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test Redis connection
echo "Testing Redis connection..."
redis-cli -a staging_redis_password_123 ping

# Create Redis data structure initialization script
echo "Creating Redis initialization script..."
cat > /opt/${PROJECT_NAME}/scripts/init-redis-staging.sh << 'EOF'
#!/bin/bash

# Redis Staging Initialization Script
REDIS_CLI="redis-cli -a staging_redis_password_123"

echo "Initializing Redis data structures for staging..."

# Session store
$REDIS_CLI SADD sessions:active "init"

# Rate limiting
$REDIS_CLI SET rate_limit:global:count 0
$REDIS_CLI EXPIRE rate_limit:global:count 60

# Cache configuration
$REDIS_CLI SET cache:config:ttl 3600
$REDIS_CLI SET cache:config:max_size 1000000

# User sessions
$REDIS_CLI SET user_sessions:ttl 86400

# Application settings
$REDIS_CLI HMSET app:settings \
    environment "staging" \
    version "1.0.0" \
    debug "false" \
    maintenance "false"

# Feature flags
$REDIS_CLI SADD features:enabled "oauth" "mfa" "audit_logging"
$REDIS_CLI SADD features:disabled "beta_features"

echo "Redis initialization completed"
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/init-redis-staging.sh

# Run Redis initialization
echo "Running Redis initialization..."
/opt/${PROJECT_NAME}/scripts/init-redis-staging.sh

# Create database backup script for staging
echo "Creating database backup script..."
cat > /opt/${PROJECT_NAME}/scripts/backup-staging-db.sh << EOF
#!/bin/bash

# Staging Database Backup Script
BACKUP_DIR="/opt/gravitypm/staging/backups"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

echo "Starting staging database backup..."

# Create backup directory
mkdir -p \$BACKUP_DIR

# MongoDB backup
echo "Backing up MongoDB..."
mongodump \
    --db ${DB_NAME} \
    --username app_user \
    --password staging_app_password_123 \
    --authenticationDatabase ${DB_NAME} \
    --out \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP

# Compress MongoDB backup
tar -czf \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP.tar.gz -C \$BACKUP_DIR mongodb_backup_\$TIMESTAMP
rm -rf \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP

# Redis backup
echo "Backing up Redis..."
redis-cli -a staging_redis_password_123 SAVE
cp /var/lib/redis/dump.rdb \$BACKUP_DIR/redis_backup_\$TIMESTAMP.rdb

# Backup configuration files
echo "Backing up configuration files..."
tar -czf \$BACKUP_DIR/config_backup_\$TIMESTAMP.tar.gz \
    /etc/mongod.conf \
    /etc/redis/redis.conf \
    /opt/gravitypm/staging/.env

# Clean up old backups
echo "Cleaning up old backups..."
find \$BACKUP_DIR -name "*.tar.gz" -o -name "*.rdb" -mtime +\$RETENTION_DAYS -delete

echo "Staging database backup completed: \$BACKUP_DIR"
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/backup-staging-db.sh

# Set up automated backup
echo "Setting up automated backup..."
sudo crontab -l | { cat; echo "0 2 * * * /opt/gravitypm/scripts/backup-staging-db.sh"; } | sudo crontab -

# Create database monitoring script
echo "Creating database monitoring script..."
cat > /opt/${PROJECT_NAME}/scripts/monitor-staging-db.sh << 'EOF'
#!/bin/bash

# Staging Database Monitoring Script
LOG_FILE="/var/log/gravitypm/staging-db-monitor.log"
ALERT_EMAIL="admin@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_mongodb() {
    log "Checking MongoDB status..."

    # Check if MongoDB is running
    if ! pgrep mongod > /dev/null; then
        log "ERROR: MongoDB is not running"
        echo "CRITICAL: MongoDB is down" | mail -s "Staging DB Alert" "$ALERT_EMAIL"
        return 1
    fi

    # Check MongoDB connectivity
    if mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "db.stats()" > /dev/null 2>&1; then
        log "MongoDB connectivity OK"
    else
        log "ERROR: MongoDB connectivity failed"
        echo "ERROR: MongoDB connectivity failed" | mail -s "Staging DB Alert" "$ALERT_EMAIL"
        return 1
    fi

    # Check database size
    DB_SIZE=$(mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "db.stats().dataSize" --quiet)
    log "MongoDB data size: $DB_SIZE bytes"

    # Check connection count
    CONN_COUNT=$(mongosh -u admin -p staging_admin_password_123 --authenticationDatabase admin admin --eval "db.serverStatus().connections.current" --quiet)
    log "MongoDB connections: $CONN_COUNT"

    if [ "$CONN_COUNT" -gt 100 ]; then
        log "WARNING: High connection count: $CONN_COUNT"
        echo "WARNING: High MongoDB connection count: $CONN_COUNT" | mail -s "Staging DB Warning" "$ALERT_EMAIL"
    fi
}

check_redis() {
    log "Checking Redis status..."

    # Check if Redis is running
    if ! pgrep redis-server > /dev/null; then
        log "ERROR: Redis is not running"
        echo "CRITICAL: Redis is down" | mail -s "Staging DB Alert" "$ALERT_EMAIL"
        return 1
    fi

    # Check Redis connectivity
    if redis-cli -a staging_redis_password_123 ping | grep -q PONG; then
        log "Redis connectivity OK"
    else
        log "ERROR: Redis connectivity failed"
        echo "ERROR: Redis connectivity failed" | mail -s "Staging DB Alert" "$ALERT_EMAIL"
        return 1
    fi

    # Check Redis memory usage
    MEM_USAGE=$(redis-cli -a staging_redis_password_123 info memory | grep used_memory: | cut -d: -f2)
    MEM_USAGE_MB=$((MEM_USAGE / 1024 / 1024))
    log "Redis memory usage: ${MEM_USAGE_MB}MB"

    # Check Redis connections
    CONN_COUNT=$(redis-cli -a staging_redis_password_123 info clients | grep connected_clients: | cut -d: -f2)
    log "Redis connections: $CONN_COUNT"

    if [ "$CONN_COUNT" -gt 50 ]; then
        log "WARNING: High Redis connection count: $CONN_COUNT"
        echo "WARNING: High Redis connection count: $CONN_COUNT" | mail -s "Staging DB Warning" "$ALERT_EMAIL"
    fi
}

check_disk_space() {
    log "Checking disk space..."

    # Check MongoDB data directory
    MONGO_DISK=$(df /data/db | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$MONGO_DISK" -gt 80 ]; then
        log "WARNING: MongoDB disk usage high: ${MONGO_DISK}%"
        echo "WARNING: MongoDB disk usage high: ${MONGO_DISK}%" | mail -s "Staging DB Warning" "$ALERT_EMAIL"
    fi

    # Check Redis data directory
    REDIS_DISK=$(df /var/lib/redis | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$REDIS_DISK" -gt 80 ]; then
        log "WARNING: Redis disk usage high: ${REDIS_DISK}%"
        echo "WARNING: Redis disk usage high: ${REDIS_DISK}%" | mail -s "Staging DB Warning" "$ALERT_EMAIL"
    fi
}

log "Starting staging database monitoring..."

check_mongodb
check_redis
check_disk_space

log "Staging database monitoring completed"
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/monitor-staging-db.sh

# Set up database monitoring
echo "Setting up database monitoring..."
sudo crontab -l | { cat; echo "*/5 * * * * /opt/gravitypm/scripts/monitor-staging-db.sh"; } | sudo crontab -

# Create database performance tuning script
echo "Creating database performance tuning script..."
cat > /opt/${PROJECT_NAME}/scripts/tune-staging-db.sh << 'EOF'
#!/bin/bash

# Staging Database Performance Tuning Script
LOG_FILE="/var/log/gravitypm/staging-db-tuning.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

tune_mongodb() {
    log "Tuning MongoDB performance..."

    # Enable WiredTiger cache
    mongosh -u admin -p staging_admin_password_123 --authenticationDatabase admin admin --eval "
        db.adminCommand({
            setParameter: 1,
            wiredTigerMaxCacheOverflowSizeGB: 0.5
        })
    "

    # Create indexes for common queries
    mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "
        db.users.createIndex({ 'last_login': 1, 'status': 1 });
        db.tasks.createIndex({ 'status': 1, 'priority': 1, 'due_date': 1 });
        db.projects.createIndex({ 'status': 1, 'updated_at': 1 });
    "

    log "MongoDB tuning completed"
}

tune_redis() {
    log "Tuning Redis performance..."

    # Configure Redis memory policy
    redis-cli -a staging_redis_password_123 config set maxmemory-policy allkeys-lru
    redis-cli -a staging_redis_password_123 config set maxmemory 512mb

    # Enable AOF
    redis-cli -a staging_redis_password_123 config set appendonly yes
    redis-cli -a staging_redis_password_123 config set appendfsync everysec

    log "Redis tuning completed"
}

log "Starting staging database tuning..."

tune_mongodb
tune_redis

log "Staging database tuning completed"
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/tune-staging-db.sh

# Run initial database tuning
echo "Running initial database tuning..."
/opt/${PROJECT_NAME}/scripts/tune-staging-db.sh

# Create database migration script
echo "Creating database migration script..."
cat > /opt/${PROJECT_NAME}/scripts/migrate-staging-db.sh << 'EOF'
#!/bin/bash

# Staging Database Migration Script
LOG_FILE="/var/log/gravitypm/staging-db-migration.log"
BACKUP_DIR="/opt/gravitypm/staging/backups"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

create_backup() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    log "Creating pre-migration backup..."

    # MongoDB backup
    mongodump --db gravitypm_staging --username app_user --password staging_app_password_123 --authenticationDatabase gravitypm_staging --out $BACKUP_DIR/pre_migration_mongo_$TIMESTAMP

    # Redis backup
    redis-cli -a staging_redis_password_123 SAVE
    cp /var/lib/redis/dump.rdb $BACKUP_DIR/pre_migration_redis_$TIMESTAMP.rdb

    log "Pre-migration backup completed"
}

run_migrations() {
    log "Running database migrations..."

    # Add new fields to existing collections
    mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "
        // Add new fields to users collection
        db.users.updateMany(
            { mfa_enabled: { \$exists: false } },
            { \$set: { mfa_enabled: false, mfa_secret: null } }
        );

        // Add new fields to projects collection
        db.projects.updateMany(
            { archived: { \$exists: false } },
            { \$set: { archived: false } }
        );

        // Add new fields to tasks collection
        db.tasks.updateMany(
            { time_estimate: { \$exists: false } },
            { \$set: { time_estimate: 0 } }
        );
    "

    log "Database migrations completed"
}

validate_migration() {
    log "Validating migration..."

    # Check data integrity
    USER_COUNT=$(mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "db.users.countDocuments()" --quiet)
    PROJECT_COUNT=$(mongosh -u app_user -p staging_app_password_123 --authenticationDatabase gravitypm_staging gravitypm_staging --eval "db.projects.countDocuments()" --quiet)

    log "Migration validation: $USER_COUNT users, $PROJECT_COUNT projects"

    if [ "$USER_COUNT" -eq 0 ]; then
        log "ERROR: No users found after migration"
        return 1
    fi

    log "Migration validation passed"
}

log "Starting staging database migration..."

create_backup
run_migrations

if validate_migration; then
    log "Staging database migration completed successfully"
else
    log "ERROR: Migration validation failed"
    exit 1
fi
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/migrate-staging-db.sh

# Update environment configuration
echo "Updating environment configuration..."

cat >> .env.staging << EOF

# Staging Database Configuration
MONGODB_URI=mongodb://app_user:staging_app_password_123@localhost:27017/gravitypm_staging?authSource=gravitypm_staging
REDIS_URL=redis://:staging_redis_password_123@localhost:6379/0

# Database Settings
DB_NAME=gravitypm_staging
DB_HOST=localhost
DB_PORT=27017
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=staging_redis_password_123

# Database Monitoring
DB_MONITORING_ENABLED=true
DB_SLOW_QUERY_THRESHOLD=100
DB_CONNECTION_POOL_SIZE=10
REDIS_MAX_CONNECTIONS=20
EOF

echo "Staging database setup completed!"
echo "MongoDB configured with authentication and replication"
echo "Redis configured with persistence and security"
echo "Database collections and indexes created"
echo "Backup and monitoring scripts configured"
echo "Performance tuning applied"
echo ""
echo "Database Details:"
echo "- MongoDB: localhost:${MONGO_PORT}"
echo "- Database: ${DB_NAME}"
echo "- Redis: localhost:${REDIS_PORT}"
echo ""
echo "Next steps:"
echo "1. Test database connectivity"
echo "2. Run initial data seeding"
echo "3. Configure connection pooling"
echo "4. Set up database replication (if needed)"
echo "5. Test backup and restore procedures"
echo "6. Configure database monitoring alerts"
echo "7. Optimize query performance"
echo "8. Set up database maintenance schedules"
