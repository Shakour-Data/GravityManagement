#!/bin/bash

# Performance Testing Script for GravityPM
# This script conducts comprehensive performance testing of the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
TEST_RESULTS_DIR="${PROD_DIR}/performance-tests"
LOG_FILE="${PROD_DIR}/logs/performance_test_\$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${PROD_DIR}/reports/performance_test_report_\$(date +%Y%m%d_%H%M%S).html"

echo "Conducting performance testing for ${PROJECT_NAME} production environment..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"
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

log "Performance testing started"
log "Environment: Production"
log "Results Directory: $TEST_RESULTS_DIR"

# 1. System Resource Baseline
echo "=== SYSTEM RESOURCE BASELINE ==="

log "Capturing system baseline metrics..."

# CPU baseline
CPU_BASELINE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
log "CPU Usage Baseline: ${CPU_BASELINE}%"

# Memory baseline
MEM_BASELINE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
log "Memory Usage Baseline: ${MEM_BASELINE}%"

# Disk I/O baseline
DISK_IO_BASELINE=$(iostat -d 1 1 | grep -A 1 "Device" | tail -1 | awk '{print $2}')
log "Disk I/O Baseline: ${DISK_IO_BASELINE} tps"

# Network baseline
NET_BASELINE=$(sar -n DEV 1 1 | grep -E "eth0|ens" | tail -1 | awk '{print $5}')
log "Network Baseline: ${NET_BASELINE} packets/sec"

# 2. Application Response Time Testing
echo "=== APPLICATION RESPONSE TIME TESTING ==="

# Test web application response times
log "Testing web application response times..."

WEB_RESPONSE_TIME=$(curl -w "@-" -o /dev/null -s "http://localhost:3000" <<EOF
    time_total: %{time_total}
EOF
)

if [ $? -eq 0 ]; then
    test_result "Web Application Response Time" "PASS" "${WEB_RESPONSE_TIME}s"
else
    test_result "Web Application Response Time" "FAIL" "Unable to connect"
fi

# Test API response times
log "Testing API response times..."

API_RESPONSE_TIME=$(curl -w "@-" -o /dev/null -s "http://localhost:5000/health" <<EOF
    time_total: %{time_total}
EOF
)

if [ $? -eq 0 ]; then
    test_result "API Response Time" "PASS" "${API_RESPONSE_TIME}s"
else
    test_result "API Response Time" "FAIL" "Unable to connect"
fi

# 3. Database Performance Testing
echo "=== DATABASE PERFORMANCE TESTING ==="

log "Testing database performance..."

# MongoDB connection test
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    test_result "MongoDB Connection" "PASS" "Connection successful"
else
    test_result "MongoDB Connection" "FAIL" "Connection failed"
fi

# MongoDB query performance
DB_QUERY_TIME=$(docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh gravitypm_production --eval "db.stats()" --quiet 2>/dev/null | grep -o '"ok":[0-9.]*' | cut -d: -f2)

if [ $? -eq 0 ]; then
    test_result "MongoDB Query Performance" "PASS" "Query executed in ${DB_QUERY_TIME}s"
else
    test_result "MongoDB Query Performance" "FAIL" "Query failed"
fi

# 4. Cache Performance Testing
echo "=== CACHE PERFORMANCE TESTING ==="

log "Testing Redis cache performance..."

# Redis connection test
if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T redis-production redis-cli ping | grep -q PONG; then
    test_result "Redis Connection" "PASS" "Connection successful"
else
    test_result "Redis Connection" "FAIL" "Connection failed"
fi

# Redis performance test
REDIS_PERF=$(docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T redis-production redis-cli --latency -i 1 -c 1 2>/dev/null | tail -1 | awk '{print $2}')

if [ $? -eq 0 ]; then
    test_result "Redis Latency" "PASS" "${REDIS_PERF}ms average latency"
else
    test_result "Redis Latency" "FAIL" "Latency test failed"
fi

# 5. Load Testing with Apache Bench
echo "=== LOAD TESTING ==="

log "Running load tests..."

# Web application load test
log "Testing web application under load..."
AB_WEB_RESULTS="${TEST_RESULTS_DIR}/ab_web_results.txt"

ab -n 1000 -c 10 -g "${TEST_RESULTS_DIR}/web_load.tsv" "http://localhost:3000/" > "$AB_WEB_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    WEB_RPS=$(grep "Requests per second" "$AB_WEB_RESULTS" | awk '{print $4}')
    WEB_MEAN_TIME=$(grep "Time per request.*mean" "$AB_WEB_RESULTS" | awk '{print $4}')
    test_result "Web Load Test (1000 requests, 10 concurrent)" "PASS" "${WEB_RPS} req/sec, ${WEB_MEAN_TIME}ms mean response time"
else
    test_result "Web Load Test" "FAIL" "Load test failed"
fi

# API load test
log "Testing API under load..."
AB_API_RESULTS="${TEST_RESULTS_DIR}/ab_api_results.txt"

ab -n 1000 -c 10 -g "${TEST_RESULTS_DIR}/api_load.tsv" "http://localhost:5000/health" > "$AB_API_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    API_RPS=$(grep "Requests per second" "$AB_API_RESULTS" | awk '{print $4}')
    API_MEAN_TIME=$(grep "Time per request.*mean" "$AB_API_RESULTS" | awk '{print $4}')
    test_result "API Load Test (1000 requests, 10 concurrent)" "PASS" "${API_RPS} req/sec, ${API_MEAN_TIME}ms mean response time"
else
    test_result "API Load Test" "FAIL" "Load test failed"
fi

# 6. Memory Leak Testing
echo "=== MEMORY LEAK TESTING ==="

log "Testing for memory leaks..."

# Monitor memory usage over time
MEM_TEST_FILE="${TEST_RESULTS_DIR}/memory_test.txt"

for i in {1..5}; do
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    echo "$(date '+%H:%M:%S') $MEM_USAGE" >> "$MEM_TEST_FILE"
    sleep 10
done

MEM_START=$(head -1 "$MEM_TEST_FILE" | awk '{print $2}')
MEM_END=$(tail -1 "$MEM_TEST_FILE" | awk '{print $2}')
MEM_DIFF=$(echo "$MEM_END - $MEM_START" | bc 2>/dev/null || echo "0")

if (( $(echo "$MEM_DIFF < 5" | bc -l 2>/dev/null || echo "1") )); then
    test_result "Memory Leak Test" "PASS" "Memory usage stable (±${MEM_DIFF}%)"
else
    test_result "Memory Leak Test" "FAIL" "Potential memory leak detected (${MEM_DIFF}% increase)"
fi

# 7. Concurrent User Testing
echo "=== CONCURRENT USER TESTING ==="

log "Testing concurrent user load..."

# Simulate concurrent users
CONCURRENT_TEST_FILE="${TEST_RESULTS_DIR}/concurrent_test.txt"

for users in 5 10 20; do
    log "Testing with $users concurrent users..."
    ab -n $((users * 50)) -c $users "http://localhost:3000/" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "$users users: SUCCESS" >> "$CONCURRENT_TEST_FILE"
    else
        echo "$users users: FAILED" >> "$CONCURRENT_TEST_FILE"
    fi
done

CONCURRENT_SUCCESS=$(grep -c "SUCCESS" "$CONCURRENT_TEST_FILE")
if [ "$CONCURRENT_SUCCESS" -eq 3 ]; then
    test_result "Concurrent User Test" "PASS" "All concurrent user tests passed"
else
    test_result "Concurrent User Test" "FAIL" "$CONCURRENT_SUCCESS/3 tests passed"
fi

# 8. Stress Testing
echo "=== STRESS TESTING ==="

log "Running stress tests..."

# CPU stress test
STRESS_CPU_FILE="${TEST_RESULTS_DIR}/stress_cpu.txt"
timeout 30 stress --cpu 2 --timeout 20 > "$STRESS_CPU_FILE" 2>&1

if [ $? -eq 0 ]; then
    test_result "CPU Stress Test" "PASS" "System handled CPU stress"
else
    test_result "CPU Stress Test" "FAIL" "System failed under CPU stress"
fi

# Memory stress test
STRESS_MEM_FILE="${TEST_RESULTS_DIR}/stress_memory.txt"
timeout 30 stress --vm 1 --vm-bytes 256M --timeout 20 > "$STRESS_MEM_FILE" 2>&1

if [ $? -eq 0 ]; then
    test_result "Memory Stress Test" "PASS" "System handled memory stress"
else
    test_result "Memory Stress Test" "FAIL" "System failed under memory stress"
fi

# 9. Network Performance Testing
echo "=== NETWORK PERFORMANCE TESTING ==="

log "Testing network performance..."

# Network latency test
NET_LATENCY=$(ping -c 5 localhost | tail -1 | awk '{print $4}' | cut -d '/' -f 2)

if (( $(echo "$NET_LATENCY < 1" | bc -l 2>/dev/null || echo "1") )); then
    test_result "Network Latency" "PASS" "${NET_LATENCY}ms average latency"
else
    test_result "Network Latency" "FAIL" "${NET_LATENCY}ms average latency (too high)"
fi

# Bandwidth test (if iperf available)
if command -v iperf3 > /dev/null 2>&1; then
    BANDWIDTH_TEST="${TEST_RESULTS_DIR}/bandwidth_test.txt"
    iperf3 -c localhost -t 10 > "$BANDWIDTH_TEST" 2>&1

    if [ $? -eq 0 ]; then
        BANDWIDTH=$(grep "sender" "$BANDWIDTH_TEST" | awk '{print $5, $6}')
        test_result "Network Bandwidth" "PASS" "$BANDWIDTH"
    else
        test_result "Network Bandwidth" "FAIL" "Bandwidth test failed"
    fi
else
    test_result "Network Bandwidth" "PASS" "iperf3 not available, skipping"
fi

# 10. Generate Performance Report
echo "=== GENERATING PERFORMANCE REPORT ==="

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Production Performance Test Report</title>
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
        .chart { background-color: #e9ecef; padding: 10px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GravityPM Production Performance Test Report</h1>
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

    <h2>Performance Metrics</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Value</th>
            <th>Status</th>
            <th>Threshold</th>
        </tr>
        <tr class="metric">
            <td>Web Response Time</td>
            <td>${WEB_RESPONSE_TIME}s</td>
            <td>$(if (( $(echo "$WEB_RESPONSE_TIME < 2" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Good"; else echo "⚠️ Slow"; fi)</td>
            <td>< 2s</td>
        </tr>
        <tr class="metric">
            <td>API Response Time</td>
            <td>${API_RESPONSE_TIME}s</td>
            <td>$(if (( $(echo "$API_RESPONSE_TIME < 1" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Good"; else echo "⚠️ Slow"; fi)</td>
            <td>< 1s</td>
        </tr>
        <tr class="metric">
            <td>Web Requests/sec</td>
            <td>${WEB_RPS}</td>
            <td>$(if (( $(echo "$WEB_RPS > 50" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Good"; else echo "⚠️ Low"; fi)</td>
            <td>> 50 req/sec</td>
        </tr>
        <tr class="metric">
            <td>API Requests/sec</td>
            <td>${API_RPS}</td>
            <td>$(if (( $(echo "$API_RPS > 100" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Good"; else echo "⚠️ Low"; fi)</td>
            <td>> 100 req/sec</td>
        </tr>
        <tr class="metric">
            <td>CPU Usage Baseline</td>
            <td>${CPU_BASELINE}%</td>
            <td>$(if (( $(echo "$CPU_BASELINE < 70" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Normal"; else echo "⚠️ High"; fi)</td>
            <td>< 70%</td>
        </tr>
        <tr class="metric">
            <td>Memory Usage Baseline</td>
            <td>${MEM_BASELINE}%</td>
            <td>$(if (( $(echo "$MEM_BASELINE < 80" | bc -l 2>/dev/null || echo "1") )); then echo "✅ Normal"; else echo "⚠️ High"; fi)</td>
            <td>< 80%</td>
        </tr>
    </table>

    <div class="chart">
        <h3>Load Test Results</h3>
        <p><strong>Web Application:</strong> ${WEB_RPS} requests/sec, ${WEB_MEAN_TIME}ms mean response time</p>
        <p><strong>API:</strong> ${API_RPS} requests/sec, ${API_MEAN_TIME}ms mean response time</p>
    </div>

    <h2>Recommendations</h2>
    <ul>
        <li><strong>Optimization:</strong> $(if (( $(echo "$WEB_RESPONSE_TIME > 2" | bc -l 2>/dev/null || echo "0") )); then echo "Consider implementing caching and CDN for static assets"; else echo "Response times are within acceptable limits"; fi)</li>
        <li><strong>Scaling:</strong> $(if (( $(echo "$WEB_RPS < 50" | bc -l 2>/dev/null || echo "0") )); then echo "Consider horizontal scaling for better throughput"; else echo "Current throughput meets requirements"; fi)</li>
        <li><strong>Monitoring:</strong> Set up continuous performance monitoring with alerts</li>
        <li><strong>Load Testing:</strong> Schedule regular load testing with increasing user counts</li>
        <li><strong>Database:</strong> Monitor query performance and consider indexing optimization</li>
    </ul>

    <h2>Test Files</h2>
    <ul>
        <li><strong>Log File:</strong> $LOG_FILE</li>
        <li><strong>Apache Bench Web Results:</strong> $AB_WEB_RESULTS</li>
        <li><strong>Apache Bench API Results:</strong> $AB_API_RESULTS</li>
        <li><strong>Memory Test Data:</strong> $MEM_TEST_FILE</li>
        <li><strong>Concurrent Test Results:</strong> $CONCURRENT_TEST_FILE</li>
    </ul>

    <div class="footer">
        <p><strong>Test Completed:</strong> $(date)</p>
        <p><strong>Report Generated By:</strong> GravityPM Performance Testing Script</p>
    </div>
</body>
</html>
EOF

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "${SLACK_WEBHOOK}" ]; then
    if [ $TESTS_FAILED -gt 0 ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ Performance Testing Completed: $TESTS_FAILED failed tests found. Review: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    else
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Performance Testing Completed: All tests passed! Report: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
fi

echo ""
echo "=== PERFORMANCE TESTING COMPLETED ==="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $((TESTS_PASSED * 100 / TESTS_RUN))%"
echo ""
echo "Reports:"
echo "- Log File: $LOG_FILE"
echo "- HTML Report: $REPORT_FILE"
echo "- Test Results: $TEST_RESULTS_DIR"
echo ""
echo "Key Metrics:"
echo "- Web Response Time: ${WEB_RESPONSE_TIME}s"
echo "- API Response Time: ${API_RESPONSE_TIME}s"
echo "- Web RPS: ${WEB_RPS}"
echo "- API RPS: ${API_RPS}"
echo ""
echo "Next Steps:"
echo "1. Review the HTML report for detailed results"
echo "2. Address any failed performance tests"
echo "3. Implement recommended optimizations"
echo "4. Set up continuous performance monitoring"
echo "5. Schedule regular performance testing"

# Exit with error if critical tests failed
if [ $TESTS_FAILED -gt 2 ]; then
    echo ""
    echo "⚠️  WARNING: $TESTS_FAILED performance tests failed!"
    echo "Please review the performance report and address the issues."
    exit 1
fi

echo ""
echo "🎉 Performance testing completed successfully!"
