#!/bin/bash

# Production Monitoring Setup Script for GravityPM
# This script sets up comprehensive monitoring for the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"

echo "Setting up production monitoring for ${PROJECT_NAME}..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create monitoring directory structure
echo "Creating monitoring directory structure..."
mkdir -p "$PROD_DIR/monitoring"/{prometheus,grafana,alertmanager,exporters}

# Create Prometheus configuration for production
echo "Creating Prometheus configuration..."

cat > "$PROD_DIR/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: production
    project: gravitypm
    region: us-east-1

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Application Services
  - job_name: 'gravitypm-production-app'
    static_configs:
      - targets: ['gravitypm-app:3000']
        labels:
          service: 'web-app'
          environment: 'production'
    scrape_interval: 10s
    scrape_timeout: 5s
    metrics_path: '/metrics'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  - job_name: 'gravitypm-production-api'
    static_configs:
      - targets: ['gravitypm-api:5000']
        labels:
          service: 'backend-api'
          environment: 'production'
    scrape_interval: 10s
    scrape_timeout: 5s
    metrics_path: '/metrics'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  # Database Services
  - job_name: 'mongodb-production'
    static_configs:
      - targets: ['mongodb-exporter:9216']
        labels:
          service: 'database'
          environment: 'production'
          db_type: 'mongodb'
    scrape_interval: 30s
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  - job_name: 'redis-production'
    static_configs:
      - targets: ['redis-exporter:9121']
        labels:
          service: 'cache'
          environment: 'production'
          cache_type: 'redis'
    scrape_interval: 30s
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  # Infrastructure Services
  - job_name: 'nginx-production'
    static_configs:
      - targets: ['nginx:80']
        labels:
          service: 'web-server'
          environment: 'production'
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'system'
          environment: 'production'
    scrape_interval: 30s
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '\${1}'

  # Monitoring Services
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'monitoring'
          environment: 'production'
    scrape_interval: 60s

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']
        labels:
          service: 'alerting'
          environment: 'production'
    scrape_interval: 60s

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
        labels:
          service: 'dashboard'
          environment: 'production'
    scrape_interval: 60s
EOF

# Create alert rules
echo "Creating alert rules..."

cat > "$PROD_DIR/monitoring/alert_rules.yml" << EOF
groups:
  - name: gravitypm-production-alerts
    rules:
      # Application Health Alerts
      - alert: WebApplicationDown
        expr: up{job="gravitypm-production-app"} == 0
        for: 5m
        labels:
          severity: critical
          service: web-app
        annotations:
          summary: "Web Application is down"
          description: "GravityPM web application has been down for more than 5 minutes"
          runbook_url: "https://gravitypm.com/runbooks/web-app-down"

      - alert: ApiApplicationDown
        expr: up{job="gravitypm-production-api"} == 0
        for: 5m
        labels:
          severity: critical
          service: backend-api
        annotations:
          summary: "API Application is down"
          description: "GravityPM API has been down for more than 5 minutes"
          runbook_url: "https://gravitypm.com/runbooks/api-down"

      # Database Alerts
      - alert: DatabaseDown
        expr: up{job="mongodb-production"} == 0
        for: 2m
        labels:
          severity: critical
          service: database
        annotations:
          summary: "MongoDB Database is down"
          description: "MongoDB database is not responding"
          runbook_url: "https://gravitypm.com/runbooks/database-down"

      - alert: DatabaseHighConnections
        expr: mongodb_connections_current > 800
        for: 5m
        labels:
          severity: warning
          service: database
        annotations:
          summary: "High database connections"
          description: "MongoDB has {{ \$value }} connections (threshold: 800)"

      # Cache Alerts
      - alert: RedisDown
        expr: up{job="redis-production"} == 0
        for: 2m
        labels:
          severity: critical
          service: cache
        annotations:
          summary: "Redis Cache is down"
          description: "Redis cache is not responding"
          runbook_url: "https://gravitypm.com/runbooks/redis-down"

      # System Resource Alerts
      - alert: HighCpuUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
          description: "CPU usage is {{ \$value }}%"

      - alert: HighMemoryUsage
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High memory usage on {{ \$labels.instance }}"
          description: "Memory usage is {{ \$value }}%"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Low disk space on {{ \$labels.instance }}"
          description: "Disk space is below 10%"

      # Network Alerts
      - alert: HighNetworkTraffic
        expr: rate(node_network_receive_bytes_total[5m]) > 100000000
        for: 10m
        labels:
          severity: info
          service: network
        annotations:
          summary: "High network traffic detected"
          description: "Network receive rate is {{ \$value }} bytes/sec"

      # Application Performance Alerts
      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
          service: application
        annotations:
          summary: "Slow response times detected"
          description: "95th percentile response time is {{ \$value }}s"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
          service: application
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ \$value | humanizePercentage }}"

      # Monitoring System Alerts
      - alert: PrometheusDown
        expr: up{job="prometheus"} == 0
        for: 2m
        labels:
          severity: critical
          service: monitoring
        annotations:
          summary: "Prometheus is down"
          description: "Prometheus monitoring system is not responding"

      - alert: AlertmanagerDown
        expr: up{job="alertmanager"} == 0
        for: 2m
        labels:
          severity: critical
          service: alerting
        annotations:
          summary: "Alertmanager is down"
          description: "Alertmanager is not responding"
EOF

# Create Alertmanager configuration
echo "Creating Alertmanager configuration..."

cat > "$PROD_DIR/monitoring/alertmanager.yml" << EOF
global:
  smtp_smarthost: 'smtp.gravitypm.com:587'
  smtp_from: 'alerts@gravitypm.com'
  smtp_auth_username: 'alerts@gravitypm.com'
  smtp_auth_password: 'production_smtp_password_123'

route:
  group_by: ['alertname', 'service', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'gravitypm-team'
  routes:
    - match:
        severity: critical
      receiver: 'gravitypm-critical'
      continue: true
    - match:
        service: database
      receiver: 'gravitypm-database'
      continue: true

receivers:
  - name: 'gravitypm-team'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        send_resolved: true
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ .CommonAnnotations.description }}'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
    email_configs:
      - to: 'team@gravitypm.com'
        send_resolved: true
        headers:
          subject: '[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.alertname }}'
        html: |
          {{ range .Alerts }}
          <p><strong>{{ .Annotations.summary }}</strong></p>
          <p>{{ .Annotations.description }}</p>
          <p>Labels: {{ .Labels | toJson }}</p>
          <p>Started: {{ .StartsAt.Format "2006-01-02 15:04:05" }}</p>
          {{ end }}

  - name: 'gravitypm-critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#critical-alerts'
        send_resolved: true
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ .CommonAnnotations.description }}'
        color: 'danger'
    pagerduty_configs:
      - service_key: 'your_pagerduty_integration_key'
        description: '{{ .CommonAnnotations.description }}'
        severity: 'critical'

  - name: 'gravitypm-database'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#database-alerts'
        send_resolved: true
        title: '🗄️ DB: {{ .GroupLabels.alertname }}'
        text: '{{ .CommonAnnotations.description }}'
    email_configs:
      - to: 'dba@gravitypm.com'
        send_resolved: true
EOF

# Create Grafana datasource configuration
echo "Creating Grafana datasource configuration..."

mkdir -p "$PROD_DIR/monitoring/grafana/provisioning/datasources"

cat > "$PROD_DIR/monitoring/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s
      httpMethod: POST
EOF

# Create Grafana dashboard provisioning
echo "Creating Grafana dashboard provisioning..."

mkdir -p "$PROD_DIR/monitoring/grafana/provisioning/dashboards"

cat > "$PROD_DIR/monitoring/grafana/provisioning/dashboards/dashboard.yml" << EOF
apiVersion: 1

providers:
  - name: 'gravitypm-production'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create production monitoring dashboard JSON
echo "Creating production monitoring dashboard..."

mkdir -p "$PROD_DIR/monitoring/grafana/dashboards"

cat > "$PROD_DIR/monitoring/grafana/dashboards/gravitypm-production.json" << EOF
{
  "dashboard": {
    "id": null,
    "title": "GravityPM Production Overview",
    "tags": ["production", "gravitypm"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{environment=\"production\"}",
            "legendFormat": "{{ service }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {
                    "text": "DOWN",
                    "color": "red"
                  },
                  "1": {
                    "text": "UP",
                    "color": "green"
                  }
                },
                "type": "value"
              }
            ]
          }
        }
      },
      {
        "id": 2,
        "title": "System Resources",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          },
          {
            "expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",
            "legendFormat": "Memory Usage %"
          },
          {
            "expr": "(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100",
            "legendFormat": "Disk Usage %"
          }
        ]
      },
      {
        "id": 3,
        "title": "Application Metrics",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{environment=\"production\"}[5m])",
            "legendFormat": "Request Rate"
          },
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{environment=\"production\"}[5m]))",
            "legendFormat": "95th Percentile Response Time"
          }
        ]
      },
      {
        "id": 4,
        "title": "Database Metrics",
        "type": "graph",
        "targets": [
          {
            "expr": "mongodb_connections_current",
            "legendFormat": "Active Connections"
          },
          {
            "expr": "rate(mongodb_op_counters_total[5m])",
            "legendFormat": "{{ type }} Operations/sec"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {},
    "templating": {
      "list": []
    },
    "annotations": {
      "list": []
    },
    "refresh": "30s",
    "schemaVersion": 27,
    "version": 0,
    "links": []
  }
}
EOF

# Create monitoring health check script
echo "Creating monitoring health check script..."

cat > "$PROD_DIR/monitoring/health-check.sh" << EOF
#!/bin/bash

# Production Monitoring Health Check Script
LOG_FILE="${PROD_DIR}/logs/monitoring-health-check.log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

check_monitoring_service() {
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

log "Starting monitoring health checks..."

# Check Prometheus
check_monitoring_service "Prometheus" "http://localhost:9090/-/healthy"

# Check Alertmanager
check_monitoring_service "Alertmanager" "http://localhost:9093/-/healthy"

# Check Grafana
check_monitoring_service "Grafana" "http://localhost:3001/api/health"

# Check exporters
check_monitoring_service "Node Exporter" "http://localhost:9100/metrics"
check_monitoring_service "MongoDB Exporter" "http://localhost:9216/metrics"
check_monitoring_service "Redis Exporter" "http://localhost:9121/metrics"

log "Monitoring health checks completed"
EOF

sudo chmod +x "$PROD_DIR/monitoring/health-check.sh"

# Create monitoring startup script
echo "Creating monitoring startup script..."

cat > "$PROD_DIR/start-monitoring.sh" << EOF
#!/bin/bash

# Production Monitoring Startup Script
set -e

echo "Starting production monitoring services..."

# Start monitoring stack
cd "${PROD_DIR}"
docker-compose -f docker-compose.production.yml up -d prometheus alertmanager grafana node-exporter mongodb-exporter redis-exporter

# Wait for services to be ready
echo "Waiting for monitoring services to be ready..."
sleep 30

# Check services
echo "Checking monitoring services..."
./monitoring/health-check.sh

# Set up monitoring cron jobs
echo "Setting up monitoring cron jobs..."
sudo crontab -l | { cat; echo "*/5 * * * * ${PROD_DIR}/monitoring/health-check.sh"; } | sudo crontab -

echo "Production monitoring setup completed!"
echo ""
echo "Monitoring URLs:"
echo "- Prometheus: http://your-server:9090"
echo "- Alertmanager: http://your-server:9093"
echo "- Grafana: http://your-server:3001 (admin/production_grafana_password_123)"
echo ""
echo "Grafana Dashboards:"
echo "- GravityPM Production Overview: Available in Grafana"
echo ""
echo "Alert Rules:"
echo "- Configured for critical services, system resources, and performance metrics"
echo "- Alerts sent to Slack and email"
EOF

sudo chmod +x "$PROD_DIR/start-monitoring.sh"

# Create monitoring configuration documentation
echo "Creating monitoring documentation..."

cat > "$PROD_DIR/monitoring/README.md" << EOF
# Production Monitoring Setup

## Overview
This directory contains the monitoring configuration for GravityPM production environment.

## Services Monitored
- **Web Application**: Request rates, response times, error rates
- **API**: Endpoint performance, authentication metrics
- **MongoDB**: Connections, operations, replication status
- **Redis**: Cache hits/misses, memory usage
- **Nginx**: Request rates, upstream health
- **System**: CPU, memory, disk, network usage

## Alert Rules
- **Critical**: Service down, database unavailable
- **Warning**: High resource usage, slow responses
- **Info**: High traffic, maintenance notifications

## Dashboards
- **GravityPM Production Overview**: System and application metrics
- **Database Performance**: MongoDB specific metrics
- **System Resources**: CPU, memory, disk usage

## Configuration Files
- \`prometheus.yml\`: Prometheus scraping configuration
- \`alert_rules.yml\`: Alert definitions
- \`alertmanager.yml\`: Alert routing and notifications
- \`grafana/\`: Grafana datasource and dashboard configuration

## URLs
- Prometheus: http://your-server:9090
- Alertmanager: http://your-server:9093
- Grafana: http://your-server:3001

## Credentials
- Grafana Admin: admin / production_grafana_password_123

## Maintenance
- Logs: \`${PROD_DIR}/logs/monitoring-health-check.log\`
- Health Checks: Run \`./monitoring/health-check.sh\`
- Restart: \`docker-compose restart prometheus alertmanager grafana\`

## Alert Notifications
- **Slack**: #alerts, #critical-alerts, #database-alerts
- **Email**: team@gravitypm.com, dba@gravitypm.com
- **PagerDuty**: Critical alerts only

## Metrics Retention
- Prometheus: 30 days
- Grafana: Unlimited (configure as needed)

## Scaling Considerations
- For high-traffic environments, consider:
  - Prometheus federation
  - Remote write to long-term storage
  - Alertmanager clustering
  - Grafana high availability
EOF

echo "Production monitoring setup completed!"
echo ""
echo "Monitoring components configured:"
echo "- Prometheus with production scraping rules"
echo "- Alertmanager with Slack and email notifications"
echo "- Grafana with production dashboards"
echo "- Alert rules for critical services and performance"
echo "- Health check scripts and cron jobs"
echo ""
echo "Next steps:"
echo "1. Update alertmanager.yml with actual webhook URLs"
echo "2. Configure Grafana SMTP settings"
echo "3. Set up PagerDuty integration for critical alerts"
echo "4. Test alert notifications"
echo "5. Configure backup for monitoring data"
echo "6. Set up log aggregation (ELK stack)"
echo "7. Configure SSL for monitoring endpoints"
