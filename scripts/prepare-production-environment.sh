#!/bin/bash

# Production Environment Preparation Script for GravityPM
# This script prepares the production environment for deployment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
DOMAIN="gravitypm.com"

echo "Preparing production environment for ${PROJECT_NAME}..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "Creating production environment directory..."
    sudo mkdir -p "$PROD_DIR"
    sudo chown -R $(whoami):$(whoami) "$PROD_DIR"
fi

# Create production directory structure
echo "Creating production directory structure..."
mkdir -p "$PROD_DIR"/{app,config,logs,backups,ssl,certs,monitoring}

# Create production environment configuration
echo "Creating production environment configuration..."

cat > "$PROD_DIR/production-config.json" << EOF
{
  "environment": "${ENVIRONMENT}",
  "domain": "${DOMAIN}",
  "ssl": {
    "enabled": true,
    "certificate_path": "/opt/gravitypm/production/ssl/certificate.crt",
    "key_path": "/opt/gravitypm/production/ssl/private.key",
    "ca_bundle_path": "/opt/gravitypm/production/ssl/ca-bundle.crt"
  },
  "database": {
    "host": "mongodb-production",
    "port": 27017,
    "name": "${PROJECT_NAME}_production",
    "replica_set": "rs0",
    "read_preference": "secondaryPreferred"
  },
  "redis": {
    "host": "redis-production",
    "port": 6379,
    "cluster": true,
    "sentinel": true
  },
  "monitoring": {
    "prometheus": {
      "retention": "30d",
      "scrape_interval": "15s"
    },
    "grafana": {
      "admin_user": "admin",
      "admin_password": "production_grafana_password_123"
    },
    "alertmanager": {
      "smtp_host": "smtp.gravitypm.com",
      "smtp_port": 587,
      "notification_email": "alerts@gravitypm.com"
    }
  },
  "security": {
    "waf_enabled": true,
    "rate_limiting": {
      "requests_per_minute": 1000,
      "burst_limit": 2000
    },
    "ip_whitelist": ["gravitypm.com", "api.gravitypm.com"],
    "encryption": {
      "at_rest": true,
      "in_transit": true,
      "key_rotation_days": 90
    }
  },
  "scaling": {
    "min_instances": 3,
    "max_instances": 10,
    "cpu_threshold": 70,
    "memory_threshold": 80
  },
  "backup": {
    "schedule": "0 2 * * *",
    "retention_days": 30,
    "encryption": true,
    "cross_region": true
  }
}
EOF

# Create production docker-compose file
echo "Creating production docker-compose configuration..."

cat > "$PROD_DIR/docker-compose.production.yml" << EOF
version: '3.8'

services:
  # Web Application
  gravitypm-app:
    image: gravitypm/app:latest
    container_name: gravitypm-production-app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=3000
      - MONGODB_URI=mongodb://app_user:production_app_password_123@mongodb-production:27017/gravitypm_production?replicaSet=rs0
      - REDIS_URL=redis://redis-production:6379
      - JWT_SECRET=production_jwt_secret_123
      - GOOGLE_CLIENT_ID=\${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=\${GOOGLE_CLIENT_SECRET}
    ports:
      - "3000:3000"
    volumes:
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    depends_on:
      - mongodb-production
      - redis-production
    networks:
      - gravitypm-production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Backend API
  gravitypm-api:
    image: gravitypm/api:latest
    container_name: gravitypm-production-api
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=5000
      - MONGODB_URI=mongodb://app_user:production_app_password_123@mongodb-production:27017/gravitypm_production?replicaSet=rs0
      - REDIS_URL=redis://redis-production:6379
      - JWT_SECRET=production_jwt_secret_123
    ports:
      - "5000:5000"
    volumes:
      - ./logs:/app/logs
    depends_on:
      - mongodb-production
      - redis-production
    networks:
      - gravitypm-production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MongoDB Production
  mongodb-production:
    image: mongo:5.0
    container_name: gravitypm-production-mongodb
    restart: unless-stopped
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=production_mongo_admin_password_123
      - MONGO_INITDB_DATABASE=gravitypm_production
    volumes:
      - mongodb_data:/data/db
      - ./config/mongodb:/etc/mongo
      - ./backups:/backups
    ports:
      - "27017:27017"
    command: --replSet rs0 --bind_ip_all
    networks:
      - gravitypm-production
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis Production
  redis-production:
    image: redis:7.0-alpine
    container_name: gravitypm-production-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --cluster-enabled yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - gravitypm-production
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx Load Balancer
  nginx:
    image: nginx:1.21-alpine
    container_name: gravitypm-production-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./config/nginx/sites-enabled:/etc/nginx/sites-enabled
      - ./ssl:/etc/ssl/certs
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - gravitypm-app
      - gravitypm-api
    networks:
      - gravitypm-production
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Prometheus Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: gravitypm-production-prometheus
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - gravitypm-production

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: gravitypm-production-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=production_grafana_password_123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
    networks:
      - gravitypm-production

  # Alertmanager
  alertmanager:
    image: prom/alertmanager:latest
    container_name: gravitypm-production-alertmanager
    restart: unless-stopped
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    ports:
      - "9093:9093"
    networks:
      - gravitypm-production

  # Node Exporter
  node-exporter:
    image: prom/node-exporter:latest
    container_name: gravitypm-production-node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - gravitypm-production

  # MongoDB Exporter
  mongodb-exporter:
    image: bitnami/mongodb-exporter:latest
    container_name: gravitypm-production-mongodb-exporter
    restart: unless-stopped
    environment:
      - MONGODB_URI=mongodb://admin:production_mongo_admin_password_123@mongodb-production:27017/admin
    ports:
      - "9216:9216"
    depends_on:
      - mongodb-production
    networks:
      - gravitypm-production

  # Redis Exporter
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: gravitypm-production-redis-exporter
    restart: unless-stopped
    environment:
      - REDIS_ADDR=redis://redis-production:6379
      - REDIS_PASSWORD=
    ports:
      - "9121:9121"
    depends_on:
      - redis-production
    networks:
      - gravitypm-production

volumes:
  mongodb_data:
    driver: local
  redis_data:
    driver: local
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

networks:
  gravitypm-production:
    driver: bridge
EOF

# Create production nginx configuration
echo "Creating production nginx configuration..."

mkdir -p "$PROD_DIR/config/nginx/sites-enabled"

cat > "$PROD_DIR/config/nginx/nginx.conf" << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=web:10m rate=100r/m;

    # Upstream servers
    upstream gravitypm_app {
        least_conn;
        server gravitypm-app:3000;
        server gravitypm-app:3000 backup;
    }

    upstream gravitypm_api {
        least_conn;
        server gravitypm-api:5000;
        server gravitypm-api:5000 backup;
    }

    # Include site configurations
    include /etc/nginx/sites-enabled/*.conf;
}
EOF

# Create site configuration
cat > "$PROD_DIR/config/nginx/sites-enabled/gravitypm.conf" << EOF
# Upstream backend
upstream backend {
    server gravitypm-api:5000;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name gravitypm.com www.gravitypm.com api.gravitypm.com;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name gravitypm.com www.gravitypm.com;

    # SSL configuration
    ssl_certificate /etc/ssl/certs/certificate.crt;
    ssl_certificate_key /etc/ssl/certs/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting
    limit_req zone=web burst=20 nodelay;

    # Static files
    location /_next/static/ {
        proxy_pass http://gravitypm_app;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /static/ {
        proxy_pass http://gravitypm_app;
        expires 30d;
        add_header Cache-Control "public";
    }

    # API proxy
    location /api/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # Rate limiting for API
        limit_req zone=api burst=10 nodelay;
    }

    # Main application
    location / {
        proxy_pass http://gravitypm_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# API subdomain
server {
    listen 443 ssl http2;
    server_name api.gravitypm.com;

    # SSL configuration
    ssl_certificate /etc/ssl/certs/certificate.crt;
    ssl_certificate_key /etc/ssl/certs/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Rate limiting
    limit_req zone=api burst=50 nodelay;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create environment file template
echo "Creating production environment template..."

cat > "$PROD_DIR/.env.production.template" << EOF
# Production Environment Variables Template
# Copy this file to .env.production and fill in the actual values

# Application
NODE_ENV=production
PORT=3000
API_PORT=5000

# Database
MONGODB_URI=mongodb://app_user:PRODUCTION_APP_PASSWORD@mongodb-production:27017/gravitypm_production?replicaSet=rs0
MONGODB_TEST_URI=mongodb://app_user:PRODUCTION_APP_PASSWORD@mongodb-production:27017/gravitypm_test?replicaSet=rs0

# Redis
REDIS_URL=redis://redis-production:6379
REDIS_CLUSTER_ENABLED=true

# Authentication
JWT_SECRET=PRODUCTION_JWT_SECRET
JWT_EXPIRES_IN=24h
BCRYPT_ROUNDS=12

# OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
MICROSOFT_CLIENT_ID=your_microsoft_client_id
MICROSOFT_CLIENT_SECRET=your_microsoft_client_secret

# Email
SMTP_HOST=smtp.gravitypm.com
SMTP_PORT=587
SMTP_USER=noreply@gravitypm.com
SMTP_PASS=your_smtp_password
FROM_EMAIL=noreply@gravitypm.com

# File Upload
UPLOAD_PATH=/opt/gravitypm/production/uploads
MAX_FILE_SIZE=100MB
ALLOWED_FILE_TYPES=jpg,jpeg,png,pdf,doc,docx,xls,xlsx

# Monitoring
SENTRY_DSN=your_sentry_dsn
PROMETHEUS_ENABLED=true
GRAFANA_URL=http://grafana:3000

# Security
SESSION_SECRET=PRODUCTION_SESSION_SECRET
CSRF_SECRET=PRODUCTION_CSRF_SECRET
ENCRYPTION_KEY=PRODUCTION_ENCRYPTION_KEY

# CDN
CDN_URL=https://cdn.gravitypm.com
CDN_ENABLED=true

# Logging
LOG_LEVEL=info
LOG_FILE=/opt/gravitypm/production/logs/app.log

# Backup
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=30
BACKUP_ENCRYPTION_KEY=PRODUCTION_BACKUP_ENCRYPTION_KEY
EOF

# Create SSL certificate placeholder
echo "Creating SSL certificate placeholders..."
mkdir -p "$PROD_DIR/ssl"
cat > "$PROD_DIR/ssl/README.md" << EOF
# SSL Certificates

Place your SSL certificates here:

- certificate.crt - Your domain certificate
- private.key - Your private key
- ca-bundle.crt - Certificate authority bundle (if applicable)

## Certificate Generation

You can generate self-signed certificates for testing:

\`\`\`bash
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 365 -nodes -subj "/CN=gravitypm.com"
\`\`\`

For production, obtain certificates from:
- Let's Encrypt (free)
- DigiCert
- GlobalSign
- Comodo
EOF

# Create production health check script
echo "Creating production health check script..."

cat > "$PROD_DIR/health-check.sh" << EOF
#!/bin/bash

# Production Health Check Script
LOG_FILE="/opt/gravitypm/production/logs/health-check.log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

check_service() {
    local service=\$1
    local url=\$2
    local timeout=\${3:-10}

    if curl -f -s --max-time \$timeout "\$url" > /dev/null 2>&1; then
        log "✓ \$service is healthy"
        return 0
    else
        log "✗ \$service is unhealthy"
        return 1
    fi
}

log "Starting production health checks..."

# Check web application
check_service "Web Application" "http://localhost:3000/health"

# Check API
check_service "Backend API" "http://localhost:5000/health"

# Check database
if docker-compose -f docker-compose.production.yml exec -T mongodb-production mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    log "✓ MongoDB is healthy"
else
    log "✗ MongoDB is unhealthy"
fi

# Check Redis
if docker-compose -f docker-compose.production.yml exec -T redis-production redis-cli ping | grep -q PONG; then
    log "✓ Redis is healthy"
else
    log "✗ Redis is unhealthy"
fi

# Check nginx
if docker-compose -f docker-compose.production.yml exec -T nginx nginx -t > /dev/null 2>&1; then
    log "✓ Nginx configuration is valid"
else
    log "✗ Nginx configuration is invalid"
fi

log "Health checks completed"
EOF

sudo chmod +x "$PROD_DIR/health-check.sh"

# Create production monitoring configuration
echo "Creating production monitoring configuration..."

mkdir -p "$PROD_DIR/monitoring/prometheus"
mkdir -p "$PROD_DIR/monitoring/grafana/provisioning/datasources"
mkdir -p "$PROD_DIR/monitoring/grafana/provisioning/dashboards"

cat > "$PROD_DIR/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: production
    project: gravitypm

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'gravitypm-production-app'
    static_configs:
      - targets: ['gravitypm-app:3000']
        labels:
          service: 'web-app'
    scrape_interval: 5s
    metrics_path: '/metrics'

  - job_name: 'gravitypm-production-api'
    static_configs:
      - targets: ['gravitypm-api:5000']
        labels:
          service: 'backend-api'
    scrape_interval: 5s
    metrics_path: '/metrics'

  - job_name: 'mongodb-production'
    static_configs:
      - targets: ['mongodb-exporter:9216']
        labels:
          service: 'database'
    scrape_interval: 30s

  - job_name: 'redis-production'
    static_configs:
      - targets: ['redis-exporter:9121']
        labels:
          service: 'cache'
    scrape_interval: 30s

  - job_name: 'nginx-production'
    static_configs:
      - targets: ['nginx:80']
        labels:
          service: 'web-server'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'system'
    scrape_interval: 30s
EOF

# Create Grafana datasource configuration
cat > "$PROD_DIR/monitoring/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

# Create production documentation
echo "Creating production documentation..."

cat > "$PROD_DIR/PRODUCTION_README.md" << EOF
# Production Environment Setup

## Overview
This directory contains the production environment configuration for GravityPM.

## Directory Structure
\`\`\`
production/
├── app/              # Application files
├── config/           # Configuration files
├── logs/             # Log files
├── backups/          # Backup files
├── ssl/              # SSL certificates
├── certs/            # Additional certificates
├── monitoring/       # Monitoring configuration
└── docker-compose.production.yml
\`\`\`

## Setup Steps

### 1. Environment Configuration
1. Copy \`.env.production.template\` to \`.env.production\`
2. Fill in all required environment variables
3. Set secure passwords and secrets

### 2. SSL Certificates
1. Obtain SSL certificates for gravitypm.com and api.gravitypm.com
2. Place certificates in the \`ssl/\` directory
3. Update nginx configuration if needed

### 3. Database Setup
1. Configure MongoDB replica set
2. Set up database users and permissions
3. Configure backup procedures

### 4. Deployment
1. Build and push Docker images
2. Run database migrations
3. Start services with docker-compose
4. Configure load balancer and DNS

### 5. Monitoring
1. Set up Prometheus and Grafana
2. Configure alerting rules
3. Set up log aggregation

## Commands

### Start Production Environment
\`\`\`bash
cd /opt/gravitypm/production
docker-compose -f docker-compose.production.yml up -d
\`\`\`

### Health Check
\`\`\`bash
./health-check.sh
\`\`\`

### View Logs
\`\`\`bash
docker-compose -f docker-compose.production.yml logs -f
\`\`\`

### Backup
\`\`\`bash
docker-compose -f docker-compose.production.yml exec mongodb-production mongodump --out /backups/\$(date +%Y%m%d_%H%M%S)
\`\`\`

## Security Considerations
- All services run with minimal privileges
- Network isolation between services
- Encrypted communication (HTTPS/TLS)
- Regular security updates
- Access logging and monitoring

## Monitoring
- Prometheus for metrics collection
- Grafana for visualization
- Alertmanager for notifications
- ELK stack for log aggregation

## Backup Strategy
- Daily automated backups
- 30-day retention period
- Encrypted backups
- Cross-region replication (recommended)

## Scaling
- Horizontal scaling with load balancer
- Auto-scaling based on CPU/memory usage
- Database read replicas for performance

## Troubleshooting
- Check service logs: \`docker-compose logs <service>\`
- Health checks: \`./health-check.sh\`
- Monitoring dashboards: http://your-domain:3001
- Database connections: Check MongoDB logs

## Emergency Procedures
1. Check monitoring alerts
2. Review recent deployments
3. Check system resources
4. Scale services if needed
5. Rollback if necessary
EOF

echo "Production environment preparation completed!"
echo "Configuration files created:"
echo "- $PROD_DIR/production-config.json"
echo "- $PROD_DIR/docker-compose.production.yml"
echo "- $PROD_DIR/config/nginx/nginx.conf"
echo "- $PROD_DIR/config/nginx/sites-enabled/gravitypm.conf"
echo "- $PROD_DIR/.env.production.template"
echo "- $PROD_DIR/PRODUCTION_README.md"
echo ""
echo "Next steps:"
echo "1. Review and customize configuration files"
echo "2. Set up SSL certificates"
echo "3. Configure environment variables"
echo "4. Test the configuration locally"
echo "5. Deploy to production infrastructure"
echo "6. Configure DNS and load balancer"
echo "7. Set up monitoring and alerting"
echo "8. Perform security audit"
echo "9. Document runbooks and procedures"
