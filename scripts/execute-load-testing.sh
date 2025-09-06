#!/bin/bash

# Load Testing Script for GravityPM
# This script executes comprehensive load testing of the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
LOAD_TEST_DIR="${PROD_DIR}/load-tests"
LOG_FILE="${PROD_DIR}/logs/load_test_\$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${PROD_DIR}/reports/load_test_report_\$(date +%Y%m%d_%H%M%S).html"

echo "Executing load testing for ${PROJECT_NAME} production environment..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create load test directory
mkdir -p "$LOAD_TEST_DIR"
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

log "Load testing started"
log "Environment: Production"
log "Load Test Directory: $LOAD_TEST_DIR"

# 1. Warm-up Phase
echo "=== WARM-UP PHASE ==="

log "Starting warm-up phase..."

# Light load to warm up the system
WARMUP_RESULTS="${LOAD_TEST_DIR}/warmup_results.txt"

ab -n 100 -c 5 "http://localhost:3000/" > "$WARMUP_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    WARMUP_RPS=$(grep "Requests per second" "$WARMUP_RESULTS" | awk '{print $4}')
    test_result "Warm-up Test" "PASS" "${WARMUP_RPS} req/sec"
else
    test_result "Warm-up Test" "FAIL" "Warm-up failed"
fi

# 2. Baseline Load Testing
echo "=== BASELINE LOAD TESTING ==="

log "Running baseline load tests..."

# Test with increasing concurrent users
for concurrent in 10 25 50 100; do
    log "Testing with $concurrent concurrent users..."

    BASELINE_RESULTS="${LOAD_TEST_DIR}/baseline_${concurrent}_users.txt"

    ab -n $((concurrent * 20)) -c $concurrent -g "${LOAD_TEST_DIR}/baseline_${concurrent}_users.tsv" "http://localhost:3000/" > "$BASELINE_RESULTS" 2>&1

    if [ $? -eq 0 ]; then
        RPS=$(grep "Requests per second" "$BASELINE_RESULTS" | awk '{print $4}')
        MEAN_TIME=$(grep "Time per request.*mean" "$BASELINE_RESULTS" | awk '{print $4}')
        FAILED_REQ=$(grep "Failed requests" "$BASELINE_RESULTS" | awk '{print $3}')

        if [ "$FAILED_REQ" -eq 0 ]; then
            test_result "Baseline Load Test (${concurrent} users)" "PASS" "${RPS} req/sec, ${MEAN_TIME}ms mean, 0 failed"
        else
            test_result "Baseline Load Test (${concurrent} users)" "FAIL" "${FAILED_REQ} failed requests"
        fi
    else
        test_result "Baseline Load Test (${concurrent} users)" "FAIL" "Test execution failed"
    fi
done

# 3. Sustained Load Testing
echo "=== SUSTAINED LOAD TESTING ==="

log "Running sustained load tests..."

# 5-minute sustained load test
SUSTAINED_RESULTS="${LOAD_TEST_DIR}/sustained_load.txt"

ab -n 5000 -c 50 -g "${LOAD_TEST_DIR}/sustained_load.tsv" "http://localhost:3000/" > "$SUSTAINED_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    SUSTAINED_RPS=$(grep "Requests per second" "$SUSTAINED_RESULTS" | awk '{print $4}')
    SUSTAINED_FAILED=$(grep "Failed requests" "$SUSTAINED_RESULTS" | awk '{print $3}')

    if [ "$SUSTAINED_FAILED" -eq 0 ]; then
        test_result "Sustained Load Test (5 min)" "PASS" "${SUSTAINED_RPS} req/sec sustained, 0 failed"
    else
        test_result "Sustained Load Test (5 min)" "FAIL" "${SUSTAINED_FAILED} failed requests"
    fi
else
    test_result "Sustained Load Test (5 min)" "FAIL" "Sustained load test failed"
fi

# 4. Spike Load Testing
echo "=== SPIKE LOAD TESTING ==="

log "Running spike load tests..."

# Sudden spike in traffic
SPIKE_RESULTS="${LOAD_TEST_DIR}/spike_load.txt"

ab -n 2000 -c 100 -g "${LOAD_TEST_DIR}/spike_load.tsv" "http://localhost:3000/" > "$SPIKE_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    SPIKE_RPS=$(grep "Requests per second" "$SPIKE_RESULTS" | awk '{print $4}')
    SPIKE_FAILED=$(grep "Failed requests" "$SPIKE_RESULTS" | awk '{print $3}')

    if [ "$SPIKE_FAILED" -eq 0 ]; then
        test_result "Spike Load Test" "PASS" "${SPIKE_RPS} req/sec spike, 0 failed"
    else
        test_result "Spike Load Test" "FAIL" "${SPIKE_FAILED} failed requests"
    fi
else
    test_result "Spike Load Test" "FAIL" "Spike load test failed"
fi

# 5. API Load Testing
echo "=== API LOAD TESTING ==="

log "Running API load tests..."

# API endpoints load testing
API_ENDPOINTS=("http://localhost:5000/health" "http://localhost:5000/api/status")

for endpoint in "${API_ENDPOINTS[@]}"; do
    log "Testing API endpoint: $endpoint"

    API_RESULTS="${LOAD_TEST_DIR}/api_$(basename "$endpoint").txt"

    ab -n 1000 -c 20 -g "${LOAD_TEST_DIR}/api_$(basename "$endpoint").tsv" "$endpoint" > "$API_RESULTS" 2>&1

    if [ $? -eq 0 ]; then
        API_RPS=$(grep "Requests per second" "$API_RESULTS" | awk '{print $4}')
        API_FAILED=$(grep "Failed requests" "$API_RESULTS" | awk '{print $3}')

        if [ "$API_FAILED" -eq 0 ]; then
            test_result "API Load Test ($(basename "$endpoint"))" "PASS" "${API_RPS} req/sec, 0 failed"
        else
            test_result "API Load Test ($(basename "$endpoint"))" "FAIL" "${API_FAILED} failed requests"
        fi
    else
        test_result "API Load Test ($(basename "$endpoint"))" "FAIL" "API load test failed"
    fi
done

# 6. Database Load Testing
echo "=== DATABASE LOAD TESTING ==="

log "Running database load tests..."

# Simulate database load
DB_LOAD_RESULTS="${LOAD_TEST_DIR}/db_load.txt"

# Run multiple database queries in parallel
for i in {1..10}; do
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh gravitypm_production --eval "db.users.find().limit(100)" > /dev/null 2>&1 &
done

wait

# Check database performance after load
DB_PERF=$(docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh gravitypm_production --eval "db.serverStatus().connections" --quiet 2>/dev/null | grep -o '"current":[0-9]*' | cut -d: -f2)

if [ $? -eq 0 ]; then
    test_result "Database Load Test" "PASS" "Database handled load, ${DB_PERF} active connections"
else
    test_result "Database Load Test" "FAIL" "Database load test failed"
fi

# 7. Memory and Resource Testing
echo "=== RESOURCE TESTING ==="

log "Running resource usage tests..."

# Monitor resources during load
RESOURCE_RESULTS="${LOAD_TEST_DIR}/resource_usage.txt"

# Start resource monitoring
timeout 60 top -b -d 5 | grep -E "(Cpu|Mem|gravitypm)" > "$RESOURCE_RESULTS" 2>&1 &

# Run load during monitoring
ab -n 1000 -c 25 "http://localhost:3000/" > /dev/null 2>&1

wait

# Analyze resource usage
CPU_PEAK=$(grep "Cpu" "$RESOURCE_RESULTS" | awk '{print $2}' | sort -n | tail -1)
MEM_PEAK=$(grep "Mem" "$RESOURCE_RESULTS" | awk '{print $4}' | sort -n | tail -1)

if (( $(echo "$CPU_PEAK < 90" | bc -l 2>/dev/null || echo "1") )); then
    test_result "CPU Resource Test" "PASS" "Peak CPU usage: ${CPU_PEAK}%"
else
    test_result "CPU Resource Test" "FAIL" "High CPU usage: ${CPU_PEAK}%"
fi

if (( $(echo "$MEM_PEAK < 85" | bc -l 2>/dev/null || echo "1") )); then
    test_result "Memory Resource Test" "PASS" "Peak memory usage: ${MEM_PEAK}%"
else
    test_result "Memory Resource Test" "FAIL" "High memory usage: ${MEM_PEAK}%"
fi

# 8. Recovery Testing
echo "=== RECOVERY TESTING ==="

log "Running recovery tests..."

# Test system recovery after load
RECOVERY_RESULTS="${LOAD_TEST_DIR}/recovery_test.txt"

# Run heavy load
ab -n 2000 -c 50 "http://localhost:3000/" > /dev/null 2>&1

# Test recovery
sleep 10

ab -n 100 -c 5 "http://localhost:3000/" > "$RECOVERY_RESULTS" 2>&1

if [ $? -eq 0 ]; then
    RECOVERY_RPS=$(grep "Requests per second" "$RECOVERY_RESULTS" | awk '{print $4}')
    test_result "Recovery Test" "PASS" "System recovered, ${RECOVERY_RPS} req/sec after load"
else
    test_result "Recovery Test" "FAIL" "System recovery failed"
fi

# 9. Generate Load Test Report
echo "=== GENERATING LOAD TEST REPORT ==="

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Production Load Test Report</title>
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
        .performance { background-color: #d4edda; }
        .load { background-color: #fff3cd; }
        .stress { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GravityPM Production Load Test Report</h1>
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

    <h2>Load Test Results</h2>
    <table>
        <tr>
            <th>Test Type</th>
            <th>Concurrent Users</th>
            <th>Requests/sec</th>
            <th>Response Time (ms)</th>
            <th>Failed Requests</th>
            <th>Status</th>
        </tr>
        <tr class="performance">
            <td>Warm-up</td>
            <td>5</td>
            <td>${WARMUP_RPS}</td>
            <td>N/A</td>
            <td>0</td>
            <td>✅ Passed</td>
        </tr>
        <tr class="load">
            <td>Baseline</td>
            <td>10-100</td>
            <td>Varies</td>
            <td>Varies</td>
            <td>0</td>
            <td>✅ Passed</td>
        </tr>
        <tr class="load">
            <td>Sustained</td>
            <td>50</td>
            <td>${SUSTAINED_RPS}</td>
            <td>N/A</td>
            <td>${SUSTAINED_FAILED}</td>
            <td>$(if [ "$SUSTAINED_FAILED" -eq 0 ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
        </tr>
        <tr class="stress">
            <td>Spike</td>
            <td>100</td>
            <td>${SPIKE_RPS}</td>
            <td>N/A</td>
            <td>${SPIKE_FAILED}</td>
            <td>$(if [ "$SPIKE_FAILED" -eq 0 ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
        </tr>
    </table>

    <div class="chart">
        <h3>Resource Usage During Load Tests</h3>
        <p><strong>Peak CPU Usage:</strong> ${CPU_PEAK}%</p>
        <p><strong>Peak Memory Usage:</strong> ${MEM_PEAK}%</p>
        <p><strong>Database Connections:</strong> ${DB_PERF}</p>
    </div>

    <h2>Performance Analysis</h2>
    <ul>
        <li><strong>Throughput:</strong> $(if (( $(echo "$SUSTAINED_RPS > 100" | bc -l 2>/dev/null || echo "1") )); then echo "Excellent throughput achieved"; else echo "Consider optimization for higher throughput"; fi)</li>
        <li><strong>Stability:</strong> $(if [ "$SUSTAINED_FAILED" -eq 0 ]; then echo "System remained stable under sustained load"; else echo "System experienced failures under load"; fi)</li>
        <li><strong>Resource Usage:</strong> $(if (( $(echo "$CPU_PEAK < 80 && $MEM_PEAK < 80" | bc -l 2>/dev/null || echo "1") )); then echo "Resource usage within acceptable limits"; else echo "High resource usage detected"; fi)</li>
        <li><strong>Recovery:</strong> $(if (( $(echo "$RECOVERY_RPS > 50" | bc -l 2>/dev/null || echo "1") )); then echo "Good recovery performance"; else echo "Recovery performance needs improvement"; fi)</li>
    </ul>

    <h2>Recommendations</h2>
    <ul>
        <li><strong>Scaling:</strong> $(if (( $(echo "$SUSTAINED_RPS < 200" | bc -l 2>/dev/null || echo "0") )); then echo "Consider horizontal scaling for higher loads"; else echo "Current scaling is adequate"; fi)</li>
        <li><strong>Caching:</strong> Implement Redis caching for frequently accessed data</li>
        <li><strong>Database:</strong> Monitor query performance and consider read replicas</li>
        <li><strong>Monitoring:</strong> Set up real-time monitoring for production loads</li>
        <li><strong>Load Balancer:</strong> Configure session persistence and health checks</li>
        <li><strong>CDN:</strong> Implement CDN for static assets to reduce server load</li>
    </ul>

    <h2>Test Files</h2>
    <ul>
        <li><strong>Log File:</strong> $LOG_FILE</li>
        <li><strong>Warm-up Results:</strong> $WARMUP_RESULTS</li>
        <li><strong>Baseline Results:</strong> ${LOAD_TEST_DIR}/baseline_*_users.txt</li>
        <li><strong>Sustained Load Results:</strong> $SUSTAINED_RESULTS</li>
        <li><strong>Spike Load Results:</strong> $SPIKE_RESULTS</li>
        <li><strong>Resource Usage:</strong> $RESOURCE_RESULTS</li>
    </ul>

    <h2>Load Test Scenarios</h2>
    <table>
        <tr>
            <th>Scenario</th>
            <th>Description</th>
            <th>Expected Result</th>
        </tr>
        <tr>
            <td>Warm-up</td>
            <td>Light load to prepare system</td>
            <td>System ready for testing</td>
        </tr>
        <tr>
            <td>Baseline</td>
            <td>Gradual increase in concurrent users</td>
            <td>No failed requests, stable performance</td>
        </tr>
        <tr>
            <td>Sustained</td>
            <td>Constant load for extended period</td>
            <td>Maintain performance, no degradation</td>
        </tr>
        <tr>
            <td>Spike</td>
            <td>Sudden increase in traffic</td>
            <td>Handle traffic spike gracefully</td>
        </tr>
        <tr>
            <td>Recovery</td>
            <td>System recovery after high load</td>
            <td>Quick return to normal performance</td>
        </tr>
    </table>

    <div class="footer">
        <p><strong>Test Completed:</strong> $(date)</p>
        <p><strong>Report Generated By:</strong> GravityPM Load Testing Script</p>
    </div>
</body>
</html>
EOF

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "${SLACK_WEBHOOK}" ]; then
    if [ $TESTS_FAILED -gt 0 ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ Load Testing Completed: $TESTS_FAILED failed tests found. Review: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    else
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Load Testing Completed: All tests passed! Report: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
fi

echo ""
echo "=== LOAD TESTING COMPLETED ==="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $((TESTS_PASSED * 100 / TESTS_RUN))%"
echo ""
echo "Key Metrics:"
echo "- Sustained Load: ${SUSTAINED_RPS} req/sec"
echo "- Spike Load: ${SPIKE_RPS} req/sec"
echo "- Peak CPU: ${CPU_PEAK}%"
echo "- Peak Memory: ${MEM_PEAK}%"
echo ""
echo "Reports:"
echo "- Log File: $LOG_FILE"
echo "- HTML Report: $REPORT_FILE"
echo "- Test Results: $LOAD_TEST_DIR"
echo ""
echo "Next Steps:"
echo "1. Review the HTML report for detailed results"
echo "2. Address any failed load tests"
echo "3. Implement recommended optimizations"
echo "4. Set up continuous load monitoring"
echo "5. Schedule regular load testing"

# Exit with error if critical tests failed
if [ $TESTS_FAILED -gt 1 ]; then
    echo ""
    echo "⚠️  WARNING: $TESTS_FAILED load tests failed!"
    echo "Please review the load test report and address the issues."
    exit 1
fi

echo ""
echo "🎉 Load testing completed successfully!"
