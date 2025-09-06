#!/bin/bash

# Monitoring Setup Validation Script for GravityPM
# This script validates the monitoring and alerting setup for the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
MONITORING_DIR="${PROD_DIR}/monitoring"
LOG_FILE="${PROD_DIR}/logs/monitoring_validation_\$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${PROD_DIR}/reports/monitoring_validation_report_\$(date +%Y%m%d_%H%M%S).html"

echo "Validating monitoring setup for ${PROJECT_NAME} production environment..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create monitoring directory
mkdir -p "$MONITORING_DIR"
mkdir -p "${PROD_DIR}/logs"
mkdir -p "${PROD_DIR}/reports"

# Initialize test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log "✅ $test_name: PASSED - $details"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log "❌ $test_name: FAILED - $details"
    fi
}

log "Monitoring validation started"
log "Environment: Production"
log "Monitoring Directory: $MONITORING_DIR"

# 1. Prometheus Validation
echo "=== PROMETHEUS VALIDATION ==="

log "Validating Prometheus setup..."

# Check if Prometheus is running
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q prometheus; then
    test_result "Prometheus Service" "PASS" "Prometheus service is running"
else
    test_result "Prometheus Service" "FAIL" "Prometheus service is not running"
fi

# Check Prometheus configuration
if [ -f "${PROD_DIR}/prometheus.yml" ]; then
    # Validate Prometheus configuration syntax
    if docker run --rm -v "${PROD_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro" prom/prometheus:latest --config.check > /dev/null 2>&1; then
        test_result "Prometheus Configuration" "PASS" "Configuration syntax is valid"
    else
        test_result "Prometheus Configuration" "FAIL" "Configuration syntax is invalid"
    fi

    # Check for required scrape configs
    if grep -q "job_name.*gravitypm" "${PROD_DIR}/prometheus.yml"; then
        test_result "Prometheus Scrape Configs" "PASS" "GravityPM scrape configs found"
    else
        test_result "Prometheus Scrape Configs" "FAIL" "GravityPM scrape configs missing"
    fi
else
    test_result "Prometheus Configuration" "FAIL" "prometheus.yml not found"
fi

# Test Prometheus metrics endpoint
if curl -s "http://localhost:9090/-/healthy" > /dev/null 2>&1; then
    test_result "Prometheus Health Check" "PASS" "Prometheus health endpoint responding"
else
    test_result "Prometheus Health Check" "FAIL" "Prometheus health endpoint not responding"
fi

# 2. Grafana Validation
echo "=== GRAFANA VALIDATION ==="

log "Validating Grafana setup..."

# Check if Grafana is running
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q grafana; then
    test_result "Grafana Service" "PASS" "Grafana service is running"
else
    test_result "Grafana Service" "FAIL" "Grafana service is not running"
fi

# Test Grafana health
if curl -s "http://localhost:3001/api/health" > /dev/null 2>&1; then
    test_result "Grafana Health Check" "PASS" "Grafana health endpoint responding"
else
    test_result "Grafana Health Check" "FAIL" "Grafana health endpoint not responding"
fi

# Check Grafana datasources
GRAFANA_DATASOURCES=$(curl -s -u admin:admin "http://localhost:3001/api/datasources" 2>/dev/null | jq -r '.[]?.name' 2>/dev/null || echo "")

if echo "$GRAFANA_DATASOURCES" | grep -q "Prometheus"; then
    test_result "Grafana Data Sources" "PASS" "Prometheus datasource configured"
else
    test_result "Grafana Data Sources" "FAIL" "Prometheus datasource not configured"
fi

# 3. Alert Manager Validation
echo "=== ALERT MANAGER VALIDATION ==="

log "Validating Alert Manager setup..."

# Check if Alert Manager is running
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q alertmanager; then
    test_result "Alert Manager Service" "PASS" "Alert Manager service is running"
else
    test_result "Alert Manager Service" "FAIL" "Alert Manager service is not running"
fi

# Test Alert Manager health
if curl -s "http://localhost:9093/-/healthy" > /dev/null 2>&1; then
    test_result "Alert Manager Health" "PASS" "Alert Manager health endpoint responding"
else
    test_result "Alert Manager Health" "FAIL" "Alert Manager health endpoint not responding"
fi

# Check alert rules
if [ -f "${PROD_DIR}/alert_rules.yml" ]; then
    # Validate alert rules syntax
    if docker run --rm -v "${PROD_DIR}/alert_rules.yml:/etc/prometheus/alert_rules.yml:ro" prom/prometheus:latest --config.check --rule-files=/etc/prometheus/alert_rules.yml > /dev/null 2>&1; then
        test_result "Alert Rules Configuration" "PASS" "Alert rules syntax is valid"
    else
        test_result "Alert Rules Configuration" "FAIL" "Alert rules syntax is invalid"
    fi

    # Check for critical alerts
    ALERT_COUNT=$(grep -c "alert:" "${PROD_DIR}/alert_rules.yml" 2>/dev/null || echo "0")
    if [ "$ALERT_COUNT" -gt 0 ]; then
        test_result "Alert Rules" "PASS" "$ALERT_COUNT alert rules configured"
    else
        test_result "Alert Rules" "FAIL" "No alert rules configured"
    fi
else
    test_result "Alert Rules Configuration" "FAIL" "alert_rules.yml not found"
fi

# 4. Application Metrics Validation
echo "=== APPLICATION METRICS VALIDATION ==="

log "Validating application metrics..."

# Test application metrics endpoint
if curl -s "http://localhost:5000/metrics" > /dev/null 2>&1; then
    test_result "Application Metrics Endpoint" "PASS" "Application metrics endpoint responding"
else
    test_result "Application Metrics Endpoint" "FAIL" "Application metrics endpoint not responding"
fi

# Test web application metrics
if curl -s "http://localhost:3000/metrics" > /dev/null 2>&1; then
    test_result "Web Application Metrics" "PASS" "Web application metrics endpoint responding"
else
    test_result "Web Application Metrics" "FAIL" "Web application metrics endpoint not responding"
fi

# 5. Database Metrics Validation
echo "=== DATABASE METRICS VALIDATION ==="

log "Validating database metrics..."

# Check MongoDB exporter
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q mongodb-exporter; then
    test_result "MongoDB Exporter" "PASS" "MongoDB exporter service is running"
else
    test_result "MongoDB Exporter" "FAIL" "MongoDB exporter service is not running"
fi

# Test MongoDB metrics endpoint
if curl -s "http://localhost:9216/metrics" > /dev/null 2>&1; then
    test_result "MongoDB Metrics" "PASS" "MongoDB metrics endpoint responding"
else
    test_result "MongoDB Metrics" "FAIL" "MongoDB metrics endpoint not responding"
fi

# 6. Redis Metrics Validation
echo "=== REDIS METRICS VALIDATION ==="

log "Validating Redis metrics..."

# Check Redis exporter
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q redis-exporter; then
    test_result "Redis Exporter" "PASS" "Redis exporter service is running"
else
    test_result "Redis Exporter" "FAIL" "Redis exporter service is not running"
fi

# Test Redis metrics endpoint
if curl -s "http://localhost:9121/metrics" > /dev/null 2>&1; then
    test_result "Redis Metrics" "PASS" "Redis metrics endpoint responding"
else
    test_result "Redis Metrics" "FAIL" "Redis metrics endpoint not responding"
fi

# 7. Node Exporter Validation
echo "=== NODE EXPORTER VALIDATION ==="

log "Validating Node Exporter setup..."

# Check Node Exporter
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q node-exporter; then
    test_result "Node Exporter Service" "PASS" "Node Exporter service is running"
else
    test_result "Node Exporter Service" "FAIL" "Node Exporter service is not running"
fi

# Test Node Exporter metrics
if curl -s "http://localhost:9100/metrics" > /dev/null 2>&1; then
    test_result "Node Metrics" "PASS" "Node metrics endpoint responding"
else
    test_result "Node Metrics" "FAIL" "Node metrics endpoint not responding"
fi

# 8. ELK Stack Validation
echo "=== ELK STACK VALIDATION ==="

log "Validating ELK stack setup..."

# Check Elasticsearch
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q elasticsearch; then
    test_result "Elasticsearch Service" "PASS" "Elasticsearch service is running"
else
    test_result "Elasticsearch Service" "FAIL" "Elasticsearch service is not running"
fi

# Check Logstash
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q logstash; then
    test_result "Logstash Service" "PASS" "Logstash service is running"
else
    test_result "Logstash Service" "FAIL" "Logstash service is not running"
fi

# Check Kibana
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q kibana; then
    test_result "Kibana Service" "PASS" "Kibana service is running"
else
    test_result "Kibana Service" "FAIL" "Kibana service is not running"
fi

# Test Elasticsearch health
if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
    test_result "Elasticsearch Health" "PASS" "Elasticsearch cluster health endpoint responding"
else
    test_result "Elasticsearch Health" "FAIL" "Elasticsearch cluster health endpoint not responding"
fi

# 9. Alert Testing
echo "=== ALERT TESTING ==="

log "Testing alert functionality..."

# Create a test alert
TEST_ALERT_FILE="${MONITORING_DIR}/test_alert.yml"

cat > "$TEST_ALERT_FILE" << EOF
groups:
  - name: test
    rules:
      - alert: TestAlert
        expr: up == 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Test alert for monitoring validation"
EOF

# Test alert rule syntax
if docker run --rm -v "$TEST_ALERT_FILE:/etc/prometheus/test_alert.yml:ro" prom/prometheus:latest --config.check --rule-files=/etc/prometheus/test_alert.yml > /dev/null 2>&1; then
    test_result "Alert Rule Syntax" "PASS" "Test alert rule syntax is valid"
else
    test_result "Alert Rule Syntax" "FAIL" "Test alert rule syntax is invalid"
fi

# Clean up test alert file
rm -f "$TEST_ALERT_FILE"

# 10. Dashboard Validation
echo "=== DASHBOARD VALIDATION ==="

log "Validating monitoring dashboards..."

# Check for Grafana dashboards
if [ -d "${PROD_DIR}/grafana/dashboards" ]; then
    DASHBOARD_COUNT=$(find "${PROD_DIR}/grafana/dashboards" -name "*.json" | wc -l)
    if [ "$DASHBOARD_COUNT" -gt 0 ]; then
        test_result "Grafana Dashboards" "PASS" "$DASHBOARD_COUNT dashboards configured"
    else
        test_result "Grafana Dashboards" "FAIL" "No dashboards found"
    fi
else
    test_result "Grafana Dashboards" "FAIL" "Grafana dashboards directory not found"
fi

# 11. Notification Testing
echo "=== NOTIFICATION TESTING ==="

log "Testing notification setup..."

# Check Slack webhook configuration
if [ -n "${SLACK_WEBHOOK}" ]; then
    # Test Slack webhook (don't actually send)
    test_result "Slack Notifications" "PASS" "Slack webhook configured"
else
    test_result "Slack Notifications" "FAIL" "Slack webhook not configured"
fi

# Check email configuration
if [ -f "${PROD_DIR}/alertmanager.yml" ]; then
    if grep -q "smtp" "${PROD_DIR}/alertmanager.yml" 2>/dev/null; then
        test_result "Email Notifications" "PASS" "Email notifications configured"
    else
        test_result "Email Notifications" "FAIL" "Email notifications not configured"
    fi
else
    test_result "Email Notifications" "FAIL" "Alert manager configuration not found"
fi

# 12. Generate Monitoring Validation Report
echo "=== GENERATING MONITORING VALIDATION REPORT ==="

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Production Monitoring Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #e9ecef; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .passed { color: green; }
        .failed { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { background-color: #f8f9fa; }
        .monitoring { background-color: #d4edda; }
        .alerting { background-color: #fff3cd; }
        .logging { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GravityPM Production Monitoring Validation Report</h1>
        <p><strong>Test Date:</strong> $(date)</p>
        <p><strong>Environment:</strong> Production</p>
        <p><strong>Test Duration:</strong> $(($(date +%s) - $(stat -c %Y "$LOG_FILE")))</p>
    </div>

    <div class="summary">
        <h2>Test Summary</h2>
        <table>
            <tr>
                <td><strong>Total Tests:</strong></td>
                <td>$TESTS_RUN</td>
            </tr>
            <tr>
                <td><strong>Passed:</strong></td>
                <td class="passed">$TESTS_PASSED</td>
            </tr>
            <tr>
                <td><strong>Failed:</strong></td>
                <td class="failed">$TESTS_FAILED</td>
            </tr>
            <tr>
                <td><strong>Success Rate:</strong></td>
                <td>$((TESTS_PASSED * 100 / TESTS_RUN))%</td>
            </tr>
        </table>
    </div>

    <h2>Monitoring Stack Status</h2>
    <table>
        <tr>
            <th>Component</th>
            <th>Status</th>
            <th>Endpoint</th>
            <th>Details</th>
        </tr>
        <tr class="monitoring">
            <td>Prometheus</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q prometheus; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9090</td>
            <td>Metrics collection and storage</td>
        </tr>
        <tr class="monitoring">
            <td>Grafana</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q grafana; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:3001</td>
            <td>Visualization and dashboards</td>
        </tr>
        <tr class="alerting">
            <td>Alert Manager</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q alertmanager; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9093</td>
            <td>Alert routing and notifications</td>
        </tr>
        <tr class="monitoring">
            <td>Node Exporter</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q node-exporter; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9100</td>
            <td>System metrics</td>
        </tr>
        <tr class="monitoring">
            <td>MongoDB Exporter</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q mongodb-exporter; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9216</td>
            <td>Database metrics</td>
        </tr>
        <tr class="monitoring">
            <td>Redis Exporter</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q redis-exporter; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9121</td>
            <td>Cache metrics</td>
        </tr>
        <tr class="logging">
            <td>Elasticsearch</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q elasticsearch; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:9200</td>
            <td>Log storage and search</td>
        </tr>
        <tr class="logging">
            <td>Logstash</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q logstash; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>N/A</td>
            <td>Log processing</td>
        </tr>
        <tr class="logging">
            <td>Kibana</td>
            <td>$(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q kibana; then echo "✅ Running"; else echo "❌ Stopped"; fi)</td>
            <td>http://localhost:5601</td>
            <td>Log visualization</td>
        </tr>
    </table>

    <h2>Configuration Validation</h2>
    <table>
        <tr>
            <th>Configuration</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
        <tr>
            <td>Prometheus Config</td>
            <td>$(if [ -f "${PROD_DIR}/prometheus.yml" ]; then echo "✅ Found"; else echo "❌ Missing"; fi)</td>
            <td>prometheus.yml configuration file</td>
        </tr>
        <tr>
            <td>Alert Rules</td>
            <td>$(if [ -f "${PROD_DIR}/alert_rules.yml" ]; then echo "✅ Found"; else echo "❌ Missing"; fi)</td>
            <td>alert_rules.yml alert definitions</td>
        </tr>
        <tr>
            <td>Grafana Dashboards</td>
            <td>$(if [ -d "${PROD_DIR}/grafana/dashboards" ]; then echo "✅ Found"; else echo "❌ Missing"; fi)</td>
            <td>Monitoring dashboards</td>
        </tr>
        <tr>
            <td>Alert Manager Config</td>
            <td>$(if [ -f "${PROD_DIR}/alertmanager.yml" ]; then echo "✅ Found"; else echo "❌ Missing"; fi)</td>
            <td>alertmanager.yml notification routing</td>
        </tr>
    </table>

    <h2>Recommendations</h2>
    <ul>
        <li><strong>Service Health:</strong> $(if [ $TESTS_FAILED -eq 0 ]; then echo "All monitoring services are running correctly"; else echo "Address failed monitoring services immediately"; fi)</li>
        <li><strong>Configuration:</strong> Ensure all configuration files are properly validated and version controlled</li>
        <li><strong>Alerting:</strong> Test alert notifications regularly to ensure they reach the intended recipients</li>
        <li><strong>Dashboards:</strong> Create comprehensive dashboards for all critical metrics</li>
        <li><strong>Retention:</strong> Configure appropriate data retention policies for metrics and logs</li>
        <li><strong>Security:</strong> Secure monitoring endpoints with authentication and TLS</li>
        <li><strong>Backup:</strong> Include monitoring configuration in backup procedures</li>
    </ul>

    <h2>Monitoring Coverage</h2>
    <ul>
        <li><strong>Application Metrics:</strong> Response times, error rates, throughput</li>
        <li><strong>System Metrics:</strong> CPU, memory, disk, network usage</li>
        <li><strong>Database Metrics:</strong> Connection pools, query performance, replication status</li>
        <li><strong>Cache Metrics:</strong> Hit rates, memory usage, eviction rates</li>
        <li><strong>Business Metrics:</strong> User activity, feature usage, conversion rates</li>
    </ul>

    <h2>Alert Categories</h2>
    <table>
        <tr>
            <th>Category</th>
            <th>Description</th>
            <th>Examples</th>
        </tr>
        <tr>
            <td>Critical</td>
            <td>Immediate action required</td>
            <td>Service down, data loss, security breach</td>
        </tr>
        <tr>
            <td>Warning</td>
            <td>Attention needed</td>
            <td>High resource usage, performance degradation</td>
        </tr>
        <tr>
            <td>Info</td>
            <td>Awareness only</td>
            <td>Maintenance notifications, status changes</td>
        </tr>
    </table>

    <div class="footer">
        <p><strong>Test Completed:</strong> $(date)</p>
        <p><strong>Report Generated By:</strong> GravityPM Monitoring Validation Script</p>
    </div>
</body>
</html>
EOF

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "${SLACK_WEBHOOK}" ]; then
    if [ $TESTS_FAILED -gt 0 ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ Monitoring Validation Completed: $TESTS_FAILED failed tests found. Review: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    else
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Monitoring Validation Completed: All tests passed! Report: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
fi

echo ""
echo "=== MONITORING VALIDATION COMPLETED ==="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $((TESTS_PASSED * 100 / TESTS_RUN))%"
echo ""
echo "Monitoring Services Status:"
echo "- Prometheus: $(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q prometheus; then echo "Running"; else echo "Stopped"; fi)"
echo "- Grafana: $(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q grafana; then echo "Running"; else echo "Stopped"; fi)"
echo "- Alert Manager: $(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q alertmanager; then echo "Running"; else echo "Stopped"; fi)"
echo "- ELK Stack: $(if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q elasticsearch && docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q logstash && docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q kibana; then echo "Running"; else echo "Partial/Stopped"; fi)"
echo ""
echo "Reports:"
echo "- Log File: $LOG_FILE"
echo "- HTML Report: $REPORT_FILE"
echo ""
echo "Next Steps:"
echo "1. Review the HTML report for detailed results"
echo "2. Address any failed monitoring services"
echo "3. Configure additional dashboards and alerts"
echo "4. Set up monitoring for external dependencies"
echo "5. Establish monitoring runbooks and procedures"

# Exit with error if critical services are down
CRITICAL_SERVICES_DOWN=0
for service in prometheus grafana alertmanager; do
    if ! docker-compose -f "${PROD_DIR}/docker-compose.production.yml" ps | grep -q "$service"; then
        CRITICAL_SERVICES_DOWN=$((CRITICAL_SERVICES_DOWN + 1))
    fi
done

if [ $CRITICAL_SERVICES_DOWN -gt 0 ]; then
    echo ""
    echo "⚠️  WARNING: $CRITICAL_SERVICES_DOWN critical monitoring services are not running!"
    echo "Please start the monitoring services before proceeding."
    exit 1
fi

echo ""
echo "🎉 Monitoring validation completed successfully!"
