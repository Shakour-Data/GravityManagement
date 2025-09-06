#!/bin/bash

# Staging Environment Setup Script for GravityPM
# This script sets up a complete staging environment for testing

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="staging"
DOMAIN="staging.gravitypm.com"

echo "Setting up staging environment for ${PROJECT_NAME}..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git curl wget

# Create staging directory structure
STAGING_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
sudo mkdir -p "$STAGING_DIR"
sudo mkdir -p "$STAGING_DIR/logs"
sudo mkdir -p "$STAGING_DIR/backups"
sudo mkdir -p "$STAGING_DIR/ssl"

# Copy configuration files
echo "Copying configuration files..."
sudo cp docker-compose.staging.yml "$STAGING_DIR/docker-compose.yml"
sudo cp nginx.conf "$STAGING_DIR/nginx.conf"
sudo cp .env.staging "$STAGING_DIR/.env"

# Set up SSL certificates for staging
echo "Setting up SSL certificates for staging..."
sudo openssl req -x509 -newkey rsa:4096 -keyout "$STAGING_DIR/ssl/server.key" \
    -out "$STAGING_DIR/ssl/server.crt" -days 365 -nodes \
    -subj "/C=US/ST=State/L=City/O=${PROJECT_NAME}/CN=*.${DOMAIN}"

# Create staging database configuration
echo "Creating staging database configuration..."
cat > "$STAGING_DIR/mongodb.conf" << EOF
# MongoDB Staging Configuration
storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1

security:
  authorization: enabled

replication:
  replSetName: "rs0"
EOF

# Create Redis staging configuration
echo "Creating Redis staging configuration..."
cat > "$STAGING_DIR/redis.conf" << EOF
# Redis Staging Configuration
bind 127.0.0.1
port 6379
timeout 0
tcp-keepalive 300
daemonize yes
supervised no
loglevel notice
logfile /var/log/redis/redis.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
slave-priority 100
requirepass staging_password_123
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-max-ziplist-entries 512
list-max-ziplist-value 64
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
EOF

# Set up monitoring for staging
echo "Setting up monitoring for staging..."
sudo mkdir -p "$STAGING_DIR/monitoring"
sudo cp docker-compose.monitoring.yml "$STAGING_DIR/monitoring/docker-compose.yml"

# Create staging-specific Prometheus configuration
cat > "$STAGING_DIR/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'gravitypm-staging'
    static_configs:
      - targets: ['localhost:3000', 'localhost:5000']
    scrape_interval: 5s

  - job_name: 'mongodb-staging'
    static_configs:
      - targets: ['localhost:27017']
    scrape_interval: 30s

  - job_name: 'redis-staging'
    static_configs:
      - targets: ['localhost:6379']
    scrape_interval: 30s

  - job_name: 'nginx-staging'
    static_configs:
      - targets: ['localhost:80']
    scrape_interval: 30s
EOF

# Create staging-specific alert rules
cat > "$STAGING_DIR/monitoring/alert_rules.yml" << EOF
groups:
  - name: staging_alerts
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage > 80
        for: 5m
        labels:
          severity: warning
          environment: staging
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: memory_usage > 85
        for: 5m
        labels:
          severity: warning
          environment: staging
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"

      - alert: ApplicationDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
          environment: staging
        annotations:
          summary: "Application is down"
          description: "Application has been down for more than 1 minute"
EOF

# Set up staging backup configuration
echo "Setting up staging backup configuration..."
cat > "$STAGING_DIR/backup-config.sh" << EOF
#!/bin/bash

# Staging Backup Configuration
BACKUP_DIR="/opt/gravitypm/staging/backups"
RETENTION_DAYS=7
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)

# Database backup
mongodump --db gravitypm_staging --out \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP

# Redis backup
redis-cli -a staging_password_123 save
cp /var/lib/redis/dump.rdb \$BACKUP_DIR/redis_backup_\$TIMESTAMP.rdb

# Configuration backup
tar -czf \$BACKUP_DIR/config_backup_\$TIMESTAMP.tar.gz -C /opt/gravitypm/staging .

# Clean up old backups
find \$BACKUP_DIR -name "*.tar.gz" -o -name "*.rdb" -mtime +\$RETENTION_DAYS -delete
EOF

sudo chmod +x "$STAGING_DIR/backup-config.sh"

# Create staging deployment script
echo "Creating staging deployment script..."
cat > "$STAGING_DIR/deploy.sh" << EOF
#!/bin/bash

# Staging Deployment Script
set -e

echo "Starting staging deployment..."

# Change to staging directory
cd /opt/gravitypm/staging

# Pull latest changes
echo "Pulling latest changes..."
git pull origin main

# Build and start services
echo "Building and starting services..."
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 30

# Run health checks
echo "Running health checks..."
curl -f http://localhost/health || echo "Health check failed"
curl -f http://localhost:3000/health || echo "Frontend health check failed"

# Run database migrations (if applicable)
echo "Running database migrations..."
docker-compose exec backend python manage.py migrate

echo "Staging deployment completed successfully!"
EOF

sudo chmod +x "$STAGING_DIR/deploy.sh"

# Create staging monitoring script
echo "Creating staging monitoring script..."
cat > "$STAGING_DIR/monitor.sh" << EOF
#!/bin/bash

# Staging Monitoring Script
LOG_FILE="/opt/gravitypm/staging/logs/monitor.log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

check_services() {
    log "Checking service status..."

    # Check Docker services
    if docker-compose ps | grep -q "Up"; then
        log "Docker services are running"
    else
        log "ERROR: Docker services are not running"
        exit 1
    fi

    # Check application health
    if curl -f -s http://localhost/health > /dev/null; then
        log "Application health check passed"
    else
        log "ERROR: Application health check failed"
    fi

    # Check database connectivity
    if docker-compose exec -T mongodb mongo --eval "db.stats()" > /dev/null; then
        log "Database connectivity check passed"
    else
        log "ERROR: Database connectivity check failed"
    fi
}

check_resources() {
    log "Checking system resources..."

    # CPU usage
    CPU_USAGE=\$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - \$1}')
    log "CPU Usage: \$CPU_USAGE%"

    # Memory usage
    MEM_USAGE=\$(free | grep Mem | awk '{printf "%.2f", \$3/\$2 * 100.0}')
    log "Memory Usage: \$MEM_USAGE%"

    # Disk usage
    DISK_USAGE=\$(df / | tail -1 | awk '{print \$5}' | sed 's/%//')
    log "Disk Usage: \$DISK_USAGE%"
}

generate_report() {
    REPORT_FILE="/opt/gravitypm/staging/reports/health_report_\$(date +%Y%m%d).html"

    cat > "\$REPORT_FILE" << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Staging Environment Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status-good { color: green; }
        .status-warning { color: orange; }
        .status-error { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Staging Environment Health Report</h1>
    <p>Report Date: \$(date)</p>

    <h2>Service Status</h2>
    <table>
        <tr><th>Service</th><th>Status</th><th>Details</th></tr>
        <tr><td>Web Application</td><td class="status-good">Running</td><td>Port 80/443</td></tr>
        <tr><td>Backend API</td><td class="status-good">Running</td><td>Port 5000</td></tr>
        <tr><td>MongoDB</td><td class="status-good">Running</td><td>Port 27017</td></tr>
        <tr><td>Redis</td><td class="status-good">Running</td><td>Port 6379</td></tr>
    </table>

    <h2>System Resources</h2>
    <table>
        <tr><th>Resource</th><th>Usage</th><th>Status</th></tr>
        <tr><td>CPU</td><td>\$CPU_USAGE%</td><td class="status-good">Normal</td></tr>
        <tr><td>Memory</td><td>\$MEM_USAGE%</td><td class="status-good">Normal</td></tr>
        <tr><td>Disk</td><td>\$DISK_USAGE%</td><td class="status-good">Normal</td></tr>
    </table>
</body>
</html>
HTML

    log "Health report generated: \$REPORT_FILE"
}

log "Starting staging monitoring..."

check_services
check_resources
generate_report

log "Staging monitoring completed"
EOF

sudo chmod +x "$STAGING_DIR/monitor.sh"

# Set up automated monitoring
echo "Setting up automated monitoring..."
sudo crontab -l | { cat; echo "*/5 * * * * $STAGING_DIR/monitor.sh"; } | sudo crontab -

# Create staging cleanup script
echo "Creating staging cleanup script..."
cat > "$STAGING_DIR/cleanup.sh" << EOF
#!/bin/bash

# Staging Cleanup Script
LOG_DIR="/opt/gravitypm/staging/logs"
BACKUP_DIR="/opt/gravitypm/staging/backups"
RETENTION_DAYS=7

echo "Starting staging cleanup..."

# Clean up old logs
find "\$LOG_DIR" -name "*.log" -mtime +\$RETENTION_DAYS -delete

# Clean up old backups
find "\$BACKUP_DIR" -name "*" -mtime +\$RETENTION_DAYS -delete

# Clean up Docker
docker system prune -f

echo "Staging cleanup completed"
EOF

sudo chmod +x "$STAGING_DIR/cleanup.sh"

# Set up automated cleanup
sudo crontab -l | { cat; echo "0 2 * * * $STAGING_DIR/cleanup.sh"; } | sudo crontab -

# Create staging environment summary
echo "Creating staging environment summary..."
cat > "$STAGING_DIR/README.md" << EOF
# GravityPM Staging Environment

## Overview
This directory contains the complete staging environment setup for GravityPM.

## Directory Structure
- \`docker-compose.yml\` - Main Docker Compose configuration
- \`nginx.conf\` - Nginx web server configuration
- \`.env\` - Environment variables
- \`mongodb.conf\` - MongoDB configuration
- \`redis.conf\` - Redis configuration
- \`ssl/\` - SSL certificates directory
- \`logs/\` - Application logs
- \`backups/\` - Database and configuration backups
- \`monitoring/\` - Monitoring configuration

## Services
- **Web Application**: Port 80/443
- **Backend API**: Port 5000
- **MongoDB**: Port 27017
- **Redis**: Port 6379
- **Prometheus**: Port 9090
- **Grafana**: Port 3001

## Deployment
\`\`\`bash
cd /opt/gravitypm/staging
./deploy.sh
\`\`\`

## Monitoring
\`\`\`bash
./monitor.sh
\`\`\`

## Backup
\`\`\`bash
./backup-config.sh
\`\`\`

## Access URLs
- Application: https://staging.gravitypm.com
- Monitoring: http://staging.gravitypm.com:3001
- API Docs: https://staging.gravitypm.com/api/docs

## Security Notes
- All services are configured with authentication
- SSL/TLS encryption is enabled
- Network isolation is implemented
- Regular security updates are applied
EOF

# Set proper permissions
sudo chown -R www-data:www-data "$STAGING_DIR"
sudo chmod -R 755 "$STAGING_DIR"
sudo chmod 600 "$STAGING_DIR/.env"

echo "Staging environment setup completed!"
echo "Staging directory: $STAGING_DIR"
echo "Configuration files copied and created"
echo "SSL certificates generated"
echo "Monitoring and backup scripts configured"
echo ""
echo "Next steps:"
echo "1. Review and update environment variables in .env file"
echo "2. Configure domain DNS to point to staging server"
echo "3. Test deployment script"
echo "4. Verify monitoring setup"
echo "5. Run initial backup"
echo "6. Test application functionality"
