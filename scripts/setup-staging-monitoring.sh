#!/bin/bash

# Staging Monitoring Setup Script for GravityPM
# This script sets up comprehensive monitoring for the staging environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="staging"
STAGING_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
MONITORING_DIR="$STAGING_DIR/monitoring"
DOMAIN="staging.gravitypm.com"

echo "Setting up monitoring for ${PROJECT_NAME} ${ENVIRONMENT} environment..."

# Check if staging environment exists
if [ ! -d "$STAGING_DIR" ]; then
    echo "ERROR: Staging environment not found at $STAGING_DIR"
    echo "Please run setup-staging-environment.sh first"
    exit 1
fi

# Create monitoring directory
sudo mkdir -p "$MONITORING_DIR"
sudo mkdir -p "$MONITORING_DIR/prometheus"
sudo mkdir -p "$MONITORING_DIR/grafana"
sudo mkdir -p "$MONITORING_DIR/alertmanager"
sudo mkdir -p "$MONITORING_DIR/logs"

# Create Prometheus configuration for staging
echo "Creating Prometheus configuration..."

cat > "$MONITORING_DIR/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: staging
    project: gravitypm

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'gravitypm-staging-app'
    static_configs:
      - targets: ['host.docker.internal:3000', 'localhost:3000']
        labels:
          service: 'web-app'
    scrape_interval: 5s
    metrics_path: '/metrics'

  - job_name: 'gravitypm-staging-api'
    static_configs:
      - targets: ['host.docker.internal:5000', 'localhost:5000']
        labels:
          service: 'backend-api'
    scrape_interval: 5s
    metrics_path: '/metrics'

  - job_name: 'mongodb-staging'
    static_configs:
      - targets: ['host.docker.internal:27017', 'localhost:27017']
        labels:
          service: 'database'
    scrape_interval: 30s
    metrics_path: '/metrics'

  - job_name: 'redis-staging'
    static_configs:
      - targets: ['host.docker.internal:6379', 'localhost:6379']
        labels:
          service: 'cache'
    scrape_interval: 30s

  - job_name: 'nginx-staging'
    static_configs:
      - targets: ['host.docker.internal:80', 'localhost:80']
        labels:
          service: 'web-server'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['host.docker.internal:9100', 'localhost:9100']
        labels:
          service: 'system'
    scrape_interval: 30s

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['host.docker.internal:8080', 'localhost:8080']
        labels:
          service: 'containers'
    scrape_interval: 30s
    metrics_path: '/metrics'
EOF

# Create alert rules for staging
echo "Creating alert rules..."

cat > "$MONITORING_DIR/alert_rules.yml" << EOF
groups:
  - name: staging_application_alerts
    rules:
