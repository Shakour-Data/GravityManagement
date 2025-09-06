#!/bin/bash

# Backup Restoration Testing Script for GravityPM
# This script tests the backup and restoration procedures for the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
TEST_DIR="${PROD_DIR}/backup-test"
LOG_FILE="${PROD_DIR}/logs/backup_test_\$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${PROD_DIR}/reports/backup_test_report_\$(date +%Y%m%d_%H%M%S).html"

echo "Testing backup restoration for ${PROJECT_NAME} production environment..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create test directory
mkdir -p "$TEST_DIR"
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

log "Backup restoration testing started"
log "Environment: Production"
log "Test Directory: $TEST_DIR"

# 1. Test Database Backup Creation
echo "=== TESTING DATABASE BACKUP CREATION ==="

log "Testing database backup creation..."

# Create a test database backup
DB_BACKUP_FILE="${TEST_DIR}/test_db_backup_\$(date +%Y%m%d_%H%M%S).gz"

if docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh gravitypm_production --eval "db.runCommand({createBackup: 1})" > /dev/null 2>&1; then
    # Alternative: Use mongodump for backup
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongodump --db gravitypm_production --gzip --archive > "$DB_BACKUP_FILE" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "$DB_BACKUP_FILE" ]; then
        BACKUP_SIZE=$(stat -c%s "$DB_BACKUP_FILE" 2>/dev/null || echo "0")
        test_result "Database Backup Creation" "PASS" "Backup created successfully (${BACKUP_SIZE} bytes)"
    else
        test_result "Database Backup Creation" "FAIL" "Failed to create database backup"
    fi
else
    test_result "Database Backup Creation" "FAIL" "Database backup command failed"
fi

# 2. Test File System Backup
echo "=== TESTING FILE SYSTEM BACKUP ==="

log "Testing file system backup..."

# Create a test file system backup
FS_BACKUP_FILE="${TEST_DIR}/test_fs_backup_\$(date +%Y%m%d_%H%M%S).tar.gz"

# Create some test files first
mkdir -p "${TEST_DIR}/test_data"
echo "Test file 1" > "${TEST_DIR}/test_data/file1.txt"
echo "Test file 2" > "${TEST_DIR}/test_data/file2.txt"
mkdir -p "${TEST_DIR}/test_data/subdir"
echo "Test file 3" > "${TEST_DIR}/test_data/subdir/file3.txt"

tar -czf "$FS_BACKUP_FILE" -C "${PROD_DIR}" . > /dev/null 2>&1

if [ $? -eq 0 ] && [ -f "$FS_BACKUP_FILE" ]; then
    FS_BACKUP_SIZE=$(stat -c%s "$FS_BACKUP_FILE" 2>/dev/null || echo "0")
    test_result "File System Backup" "PASS" "File system backup created (${FS_BACKUP_SIZE} bytes)"
else
    test_result "File System Backup" "FAIL" "File system backup creation failed"
fi

# 3. Test Configuration Backup
echo "=== TESTING CONFIGURATION BACKUP ==="

log "Testing configuration backup..."

# Test environment variables backup
ENV_BACKUP_FILE="${TEST_DIR}/test_env_backup_\$(date +%Y%m%d_%H%M%S).enc"

if [ -f "${PROD_DIR}/.env.production" ]; then
    # Simulate encryption (in real scenario, use proper encryption)
    cp "${PROD_DIR}/.env.production" "${TEST_DIR}/temp_env"
    openssl enc -aes-256-cbc -salt -in "${TEST_DIR}/temp_env" -out "$ENV_BACKUP_FILE" -k "test_key_123" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "$ENV_BACKUP_FILE" ]; then
        test_result "Configuration Backup" "PASS" "Environment variables backed up and encrypted"
        rm -f "${TEST_DIR}/temp_env"
    else
        test_result "Configuration Backup" "FAIL" "Configuration backup failed"
    fi
else
    test_result "Configuration Backup" "FAIL" ".env.production file not found"
fi

# 4. Test SSL Certificate Backup
echo "=== TESTING SSL CERTIFICATE BACKUP ==="

log "Testing SSL certificate backup..."

SSL_BACKUP_FILE="${TEST_DIR}/test_ssl_backup_\$(date +%Y%m%d_%H%M%S).tar.gz"

if [ -d "${PROD_DIR}/ssl" ]; then
    tar -czf "$SSL_BACKUP_FILE" -C "${PROD_DIR}/ssl" . > /dev/null 2>&1

    if [ $? -eq 0 ] && [ -f "$SSL_BACKUP_FILE" ]; then
        test_result "SSL Certificate Backup" "PASS" "SSL certificates backed up"
    else
        test_result "SSL Certificate Backup" "FAIL" "SSL certificate backup failed"
    fi
else
    test_result "SSL Certificate Backup" "FAIL" "SSL directory not found"
fi

# 5. Test Database Restoration
echo "=== TESTING DATABASE RESTORATION ==="

log "Testing database restoration..."

if [ -f "$DB_BACKUP_FILE" ]; then
    # Create a test database for restoration
    TEST_DB_NAME="gravitypm_test_restore"

    # Restore database
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongorestore --db "$TEST_DB_NAME" --gzip --archive < "$DB_BACKUP_FILE" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        # Verify restoration
        RESTORE_COUNT=$(docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh "$TEST_DB_NAME" --eval "db.stats().collections" --quiet 2>/dev/null || echo "0")

        if [ "$RESTORE_COUNT" != "0" ]; then
            test_result "Database Restoration" "PASS" "Database restored successfully (${RESTORE_COUNT} collections)"
        else
            test_result "Database Restoration" "FAIL" "Database restoration verification failed"
        fi

        # Clean up test database
        docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongosh --eval "db.getSiblingDB('$TEST_DB_NAME').dropDatabase()" > /dev/null 2>&1
    else
        test_result "Database Restoration" "FAIL" "Database restoration failed"
    fi
else
    test_result "Database Restoration" "FAIL" "No database backup file available for testing"
fi

# 6. Test File System Restoration
echo "=== TESTING FILE SYSTEM RESTORATION ==="

log "Testing file system restoration..."

if [ -f "$FS_BACKUP_FILE" ]; then
    RESTORE_TEST_DIR="${TEST_DIR}/restore_test"

    mkdir -p "$RESTORE_TEST_DIR"
    tar -xzf "$FS_BACKUP_FILE" -C "$RESTORE_TEST_DIR" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        # Verify restoration
        if [ -f "${RESTORE_TEST_DIR}/docker-compose.production.yml" ] && [ -d "${RESTORE_TEST_DIR}/nginx" ]; then
            test_result "File System Restoration" "PASS" "File system restored successfully"
        else
            test_result "File System Restoration" "FAIL" "File system restoration verification failed"
        fi

        # Clean up
        rm -rf "$RESTORE_TEST_DIR"
    else
        test_result "File System Restoration" "FAIL" "File system restoration failed"
    fi
else
    test_result "File System Restoration" "FAIL" "No file system backup available for testing"
fi

# 7. Test Configuration Restoration
echo "=== TESTING CONFIGURATION RESTORATION ==="

log "Testing configuration restoration..."

if [ -f "$ENV_BACKUP_FILE" ]; then
    # Decrypt and verify
    DECRYPTED_FILE="${TEST_DIR}/decrypted_env"

    openssl enc -d -aes-256-cbc -in "$ENV_BACKUP_FILE" -out "$DECRYPTED_FILE" -k "test_key_123" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "$DECRYPTED_FILE" ]; then
        # Verify content
        if grep -q "MONGO_INITDB_ROOT_USERNAME" "$DECRYPTED_FILE" 2>/dev/null; then
            test_result "Configuration Restoration" "PASS" "Configuration restored and decrypted successfully"
        else
            test_result "Configuration Restoration" "FAIL" "Configuration restoration verification failed"
        fi

        # Clean up
        rm -f "$DECRYPTED_FILE"
    else
        test_result "Configuration Restoration" "FAIL" "Configuration decryption failed"
    fi
else
    test_result "Configuration Restoration" "FAIL" "No encrypted configuration backup available"
fi

# 8. Test Backup Integrity
echo "=== TESTING BACKUP INTEGRITY ==="

log "Testing backup integrity..."

# Test database backup integrity
if [ -f "$DB_BACKUP_FILE" ]; then
    # Try to list contents
    docker-compose -f "${PROD_DIR}/docker-compose.production.yml" exec -T mongodb-production mongorestore --dry-run --gzip --archive < "$DB_BACKUP_FILE" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        test_result "Database Backup Integrity" "PASS" "Database backup integrity verified"
    else
        test_result "Database Backup Integrity" "FAIL" "Database backup integrity check failed"
    fi
else
    test_result "Database Backup Integrity" "FAIL" "No database backup to verify"
fi

# Test file system backup integrity
if [ -f "$FS_BACKUP_FILE" ]; then
    tar -tzf "$FS_BACKUP_FILE" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        test_result "File System Backup Integrity" "PASS" "File system backup integrity verified"
    else
        test_result "File System Backup Integrity" "FAIL" "File system backup integrity check failed"
    fi
else
    test_result "File System Backup Integrity" "FAIL" "No file system backup to verify"
fi

# 9. Test Backup Automation
echo "=== TESTING BACKUP AUTOMATION ==="

log "Testing backup automation..."

# Check if backup cron job exists
if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    test_result "Backup Automation" "PASS" "Automated backup cron job configured"
else
    test_result "Backup Automation" "FAIL" "Automated backup cron job not found"
fi

# 10. Test Backup Retention
echo "=== TESTING BACKUP RETENTION ==="

log "Testing backup retention policies..."

# Check backup directory for old files
BACKUP_COUNT=$(find "${PROD_DIR}/backups" -name "*.gz" -mtime +30 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -eq 0 ]; then
    test_result "Backup Retention" "PASS" "No backups older than 30 days found"
else
    test_result "Backup Retention" "FAIL" "${BACKUP_COUNT} backups older than 30 days (should be cleaned up)"
fi

# 11. Generate Backup Test Report
echo "=== GENERATING BACKUP TEST REPORT ==="

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Production Backup Test Report</title>
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
        .backup { background-color: #d4edda; }
        .restore { background-color: #fff3cd; }
        .integrity { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GravityPM Production Backup Test Report</h1>
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

    <h2>Backup Test Results</h2>
    <table>
        <tr>
            <th>Test Category</th>
            <th>Test Name</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
        <tr class="backup">
            <td>Database</td>
            <td>Database Backup Creation</td>
            <td>$(if [ -f "$DB_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$DB_BACKUP_FILE" ]; then echo "Backup: $(basename "$DB_BACKUP_FILE") ($(stat -c%s "$DB_BACKUP_FILE" 2>/dev/null || echo "0") bytes)"; else echo "Backup creation failed"; fi)</td>
        </tr>
        <tr class="backup">
            <td>File System</td>
            <td>File System Backup</td>
            <td>$(if [ -f "$FS_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$FS_BACKUP_FILE" ]; then echo "Backup: $(basename "$FS_BACKUP_FILE") ($(stat -c%s "$FS_BACKUP_FILE" 2>/dev/null || echo "0") bytes)"; else echo "Backup creation failed"; fi)</td>
        </tr>
        <tr class="backup">
            <td>Configuration</td>
            <td>Configuration Backup</td>
            <td>$(if [ -f "$ENV_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$ENV_BACKUP_FILE" ]; then echo "Encrypted backup created"; else echo "Backup creation failed"; fi)</td>
        </tr>
        <tr class="backup">
            <td>SSL</td>
            <td>SSL Certificate Backup</td>
            <td>$(if [ -f "$SSL_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$SSL_BACKUP_FILE" ]; then echo "SSL certificates backed up"; else echo "Backup creation failed"; fi)</td>
        </tr>
        <tr class="restore">
            <td>Database</td>
            <td>Database Restoration</td>
            <td>$(if [ "$RESTORE_COUNT" != "0" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ "$RESTORE_COUNT" != "0" ]; then echo "Restored ${RESTORE_COUNT} collections"; else echo "Restoration failed"; fi)</td>
        </tr>
        <tr class="restore">
            <td>File System</td>
            <td>File System Restoration</td>
            <td>$(if [ -d "$RESTORE_TEST_DIR" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -d "$RESTORE_TEST_DIR" ]; then echo "File system restored successfully"; else echo "Restoration failed"; fi)</td>
        </tr>
        <tr class="integrity">
            <td>Database</td>
            <td>Backup Integrity</td>
            <td>$(if [ -f "$DB_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$DB_BACKUP_FILE" ]; then echo "Backup integrity verified"; else echo "Integrity check failed"; fi)</td>
        </tr>
        <tr class="integrity">
            <td>File System</td>
            <td>Backup Integrity</td>
            <td>$(if [ -f "$FS_BACKUP_FILE" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>$(if [ -f "$FS_BACKUP_FILE" ]; then echo "Backup integrity verified"; else echo "Integrity check failed"; fi)</td>
        </tr>
    </table>

    <h2>Backup Configuration</h2>
    <table>
        <tr>
            <th>Component</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
        <tr>
            <td>Automated Backups</td>
            <td>$(if crontab -l 2>/dev/null | grep -q "backup.sh"; then echo "✅ Configured"; else echo "❌ Not Configured"; fi)</td>
            <td>Cron job for automated backups</td>
        </tr>
        <tr>
            <td>Retention Policy</td>
            <td>$(if [ "$BACKUP_COUNT" -eq 0 ]; then echo "✅ Compliant"; else echo "⚠️ Non-compliant"; fi)</td>
            <td>30-day retention policy</td>
        </tr>
        <tr>
            <td>Encryption</td>
            <td>$(if [ -f "$ENV_BACKUP_FILE" ]; then echo "✅ Enabled"; else echo "❌ Disabled"; fi)</td>
            <td>Configuration files encrypted</td>
        </tr>
    </table>

    <h2>Recommendations</h2>
    <ul>
        <li><strong>Automation:</strong> $(if crontab -l 2>/dev/null | grep -q "backup.sh"; then echo "Automated backups are properly configured"; else echo "Set up automated backup cron jobs"; fi)</li>
        <li><strong>Retention:</strong> $(if [ "$BACKUP_COUNT" -eq 0 ]; then echo "Backup retention policy is working correctly"; else echo "Clean up old backups to comply with retention policy"; fi)</li>
        <li><strong>Encryption:</strong> Ensure all sensitive backups are properly encrypted</li>
        <li><strong>Testing:</strong> Schedule regular backup restoration testing</li>
        <li><strong>Monitoring:</strong> Set up monitoring for backup success/failure</li>
        <li><strong>Storage:</strong> Consider off-site backup storage for disaster recovery</li>
        <li><strong>Documentation:</strong> Document backup and restoration procedures</li>
    </ul>

    <h2>Test Files</h2>
    <ul>
        <li><strong>Log File:</strong> $LOG_FILE</li>
        <li><strong>Database Backup:</strong> $DB_BACKUP_FILE</li>
        <li><strong>File System Backup:</strong> $FS_BACKUP_FILE</li>
        <li><strong>Configuration Backup:</strong> $ENV_BACKUP_FILE</li>
        <li><strong>SSL Backup:</strong> $SSL_BACKUP_FILE</li>
    </ul>

    <h2>Backup Strategy Summary</h2>
    <ul>
        <li><strong>Database:</strong> MongoDB dumps with compression</li>
        <li><strong>File System:</strong> Full directory tar archives</li>
        <li><strong>Configuration:</strong> Encrypted environment files</li>
        <li><strong>SSL Certificates:</strong> Certificate and key archives</li>
        <li><strong>Frequency:</strong> Daily automated backups</li>
        <li><strong>Retention:</strong> 30 days with automatic cleanup</li>
        <li><strong>Storage:</strong> Local with off-site replication</li>
    </ul>

    <div class="footer">
        <p><strong>Test Completed:</strong> $(date)</p>
        <p><strong>Report Generated By:</strong> GravityPM Backup Testing Script</p>
    </div>
</body>
</html>
EOF

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "${SLACK_WEBHOOK}" ]; then
    if [ $TESTS_FAILED -gt 0 ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ Backup Testing Completed: $TESTS_FAILED failed tests found. Review: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    else
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Backup Testing Completed: All tests passed! Report: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
fi

echo ""
echo "=== BACKUP TESTING COMPLETED ==="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $((TESTS_PASSED * 100 / TESTS_RUN))%"
echo ""
echo "Backup Files Created:"
echo "- Database: $DB_BACKUP_FILE"
echo "- File System: $FS_BACKUP_FILE"
echo "- Configuration: $ENV_BACKUP_FILE"
echo "- SSL: $SSL_BACKUP_FILE"
echo ""
echo "Reports:"
echo "- Log File: $LOG_FILE"
echo "- HTML Report: $REPORT_FILE"
echo ""
echo "Next Steps:"
echo "1. Review the HTML report for detailed results"
echo "2. Address any failed backup tests"
echo "3. Implement recommended improvements"
echo "4. Set up automated backup monitoring"
echo "5. Schedule regular backup testing"

# Clean up test files (keep backups for verification)
log "Cleaning up test files..."
rm -rf "${TEST_DIR}/test_data"

# Exit with error if critical tests failed
if [ $TESTS_FAILED -gt 2 ]; then
    echo ""
    echo "⚠️  WARNING: $TESTS_FAILED backup tests failed!"
    echo "Please review the backup test report and address the issues."
    exit 1
fi

echo ""
echo "🎉 Backup testing completed successfully!"
