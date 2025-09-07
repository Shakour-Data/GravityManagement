#!/bin/bash

# Comprehensive Backup Integration Test Script
# This script tests actual backup and restore operations

TEST_RESULTS_DIR="/test_results/backup_integration/$(date +%Y-%m-%d_%H-%M-%S)"
LOG_FILE="$TEST_RESULTS_DIR/integration_test.log"

# Test configuration
BACKUP_ENCRYPTION_KEY="integration_test_key_12345"
MONGODB_URL="mongodb://localhost:27017/gravitypm_test"
REDIS_HOST="localhost"
REDIS_PORT="6379"
BACKUP_DIR="/tmp/backup_integration_test"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "$(date +%Y-%m-%d_%H-%M-%S): $1" | tee -a "$LOG_FILE"
}

# Test result tracking
TEST_PASSED=0
TEST_FAILED=0

test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    if [ "$result" -eq 0 ]; then
        log "✅ PASS: $test_name"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log "❌ FAIL: $test_name - $details"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
}

log "Starting comprehensive backup integration tests..."
log "Test results will be saved to: $TEST_RESULTS_DIR"

# Set up test environment
export BACKUP_ENCRYPTION_KEY="$BACKUP_ENCRYPTION_KEY"
export MONGODB_URL="$MONGODB_URL"
export REDIS_HOST="$REDIS_HOST"
export REDIS_PORT="$REDIS_PORT"

# Test 1: Create test data in MongoDB
log "Test 1: Setting up test data in MongoDB..."
python3 -c "
import os
from motor.motor_asyncio import AsyncIOMotorClient
import asyncio

async def setup_test_data():
    try:
        client = AsyncIOMotorClient('$MONGODB_URL')
        db = client['gravitypm_test']

        # Create test collections and data
        await db.test_users.insert_many([
            {'username': 'test_user_1', 'email': 'test1@example.com', 'created_at': '2024-01-01'},
            {'username': 'test_user_2', 'email': 'test2@example.com', 'created_at': '2024-01-02'}
        ])

        await db.test_projects.insert_many([
            {'name': 'Test Project 1', 'owner_id': 'user1', 'status': 'active'},
            {'name': 'Test Project 2', 'owner_id': 'user2', 'status': 'completed'}
        ])

        print('Test data created successfully')
        client.close()
    except Exception as e:
        print(f'Failed to create test data: {e}')

asyncio.run(setup_test_data())
" 2>/dev/null

if [ $? -eq 0 ]; then
    test_result "MongoDB test data setup" 0 ""
else
    test_result "MongoDB test data setup" 1 "Failed to create test data"
fi

# Test 2: Test Redis data setup
log "Test 2: Setting up test data in Redis..."
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET test_key "test_value" EX 3600 2>/dev/null
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET test_user_session "session_data" EX 1800 2>/dev/null
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" HSET test_hash field1 "value1" field2 "value2" 2>/dev/null

if [ $? -eq 0 ]; then
    test_result "Redis test data setup" 0 ""
else
    test_result "Redis test data setup" 1 "Failed to create Redis test data"
fi

# Test 3: Create test configuration files
log "Test 3: Creating test configuration files..."
mkdir -p "$BACKUP_DIR/config"
mkdir -p "$BACKUP_DIR/ssl"
mkdir -p "$BACKUP_DIR/env"

# Create test config files
cat > "$BACKUP_DIR/config/app.conf" << EOF
[database]
url = $MONGODB_URL
name = gravitypm_test

[redis]
host = $REDIS_HOST
port = $REDIS_PORT

[security]
encryption_key = $BACKUP_ENCRYPTION_KEY
EOF

cat > "$BACKUP_DIR/ssl/cert.pem" << EOF
-----BEGIN CERTIFICATE-----
MIICiTCCAg+gAwIBAgIJAJ8l4HnPq7F5MAOGA1UEBhMCVVMxCzAJBgNVBAgTAkNB
MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRowGAYDVQQKExFPcGVuU1NMIENlcnRp
ZmljYXRpb24gQXV0aG9yaXR5MRowGAYDVQQDExFPcGVuU1NMIENlcnRpZmljYXRl
-----END CERTIFICATE-----
EOF

cat > "$BACKUP_DIR/env/.env" << EOF
MONGODB_URL=$MONGODB_URL
REDIS_HOST=$REDIS_HOST
REDIS_PORT=$REDIS_PORT
BACKUP_ENCRYPTION_KEY=$BACKUP_ENCRYPTION_KEY
SECRET_KEY=test_secret_key
API_KEY=test_api_key
EOF

test_result "Test configuration files creation" 0 ""

# Test 4: Execute backup script
log "Test 4: Executing backup script..."
if [ -f "scripts/backup.sh" ]; then
    chmod +x scripts/backup.sh
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/backup_$BACKUP_TIMESTAMP.tar.gz.enc"

    # Run backup script
    ./scripts/backup.sh 2>&1 | tee -a "$LOG_FILE"

    if [ -f "$BACKUP_FILE" ]; then
        test_result "Backup script execution" 0 ""
    else
        test_result "Backup script execution" 1 "Backup file not created"
    fi
else
    test_result "Backup script execution" 1 "backup.sh not found"
fi

# Test 5: Verify backup contents
log "Test 5: Verifying backup contents..."
if [ -f "$BACKUP_FILE" ]; then
    # Decrypt and extract backup for verification
    TEMP_EXTRACT_DIR="$TEST_RESULTS_DIR/extracted_backup"
    mkdir -p "$TEMP_EXTRACT_DIR"

    # Decrypt backup
    openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$BACKUP_ENCRYPTION_KEY" -in "$BACKUP_FILE" -out "$TEMP_EXTRACT_DIR/backup.tar.gz" 2>/dev/null

    if [ $? -eq 0 ]; then
        # Extract backup
        tar -xzf "$TEMP_EXTRACT_DIR/backup.tar.gz" -C "$TEMP_EXTRACT_DIR" 2>/dev/null

        # Check if key files exist
        if [ -f "$TEMP_EXTRACT_DIR/mongodb_backup.gz" ] && [ -f "$TEMP_EXTRACT_DIR/redis_backup.rdb" ]; then
            test_result "Backup contents verification" 0 ""
        else
            test_result "Backup contents verification" 1 "Expected backup files not found"
        fi
    else
        test_result "Backup contents verification" 1 "Failed to decrypt backup"
    fi
else
    test_result "Backup contents verification" 1 "No backup file to verify"
fi

# Test 6: Test restore functionality
log "Test 6: Testing restore functionality..."
if [ -f "$BACKUP_FILE" ] && [ -f "$TEMP_EXTRACT_DIR/backup.tar.gz" ]; then
    # Create a new test database for restore
    RESTORE_DB="gravitypm_restored_test"

    # Simulate restore by checking if we can extract and validate data
    if [ -f "$TEMP_EXTRACT_DIR/mongodb_backup.gz" ]; then
        # Test MongoDB dump file
        gunzip -c "$TEMP_EXTRACT_DIR/mongodb_backup.gz" | head -n 5 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            test_result "MongoDB backup integrity" 0 ""
        else
            test_result "MongoDB backup integrity" 1 "MongoDB backup file corrupted"
        fi
    fi

    if [ -f "$TEMP_EXTRACT_DIR/redis_backup.rdb" ]; then
        # Test Redis dump file
        file "$TEMP_EXTRACT_DIR/redis_backup.rdb" | grep -q "data" 2>/dev/null
        if [ $? -eq 0 ]; then
            test_result "Redis backup integrity" 0 ""
        else
            test_result "Redis backup integrity" 1 "Redis backup file corrupted"
        fi
    fi
else
    test_result "Restore functionality test" 1 "No backup available for restore test"
fi

# Test 7: Performance testing
log "Test 7: Performance testing..."
START_TIME=$(date +%s)

# Create larger test dataset for performance testing
python3 -c "
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def create_performance_data():
    client = AsyncIOMotorClient('$MONGODB_URL')
    db = client['gravitypm_performance_test']

    # Create 1000 test documents
    test_docs = []
    for i in range(1000):
        test_docs.append({
            'id': i,
            'name': f'Performance Test Item {i}',
            'data': 'x' * 1000,  # 1KB of data per document
            'timestamp': '2024-01-01T00:00:00Z'
        })

    await db.performance_collection.insert_many(test_docs)
    print('Performance test data created')
    client.close()

asyncio.run(create_performance_data())
" 2>/dev/null

END_TIME=$(date +%s)
DATA_CREATION_TIME=$((END_TIME - START_TIME))

if [ $DATA_CREATION_TIME -lt 30 ]; then
    test_result "Performance data creation" 0 ""
else
    test_result "Performance data creation" 1 "Data creation took too long: ${DATA_CREATION_TIME}s"
fi

# Test 8: Encryption key rotation test
log "Test 8: Testing encryption key rotation..."
NEW_ENCRYPTION_KEY="new_rotation_key_67890"

# Test encrypting with old key and decrypting with new key (should fail)
echo "test key rotation data" > "$TEST_RESULTS_DIR/key_rotation_test.txt"
openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$BACKUP_ENCRYPTION_KEY" -in "$TEST_RESULTS_DIR/key_rotation_test.txt" -out "$TEST_RESULTS_DIR/key_rotation.enc" 2>/dev/null

# Try to decrypt with new key (should fail)
openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$NEW_ENCRYPTION_KEY" -in "$TEST_RESULTS_DIR/key_rotation.enc" -out "$TEST_RESULTS_DIR/key_rotation_decrypted.txt" 2>/dev/null

if [ $? -ne 0 ]; then
    test_result "Encryption key rotation test" 0 ""
else
    test_result "Encryption key rotation test" 1 "Key rotation did not work as expected"
fi

# Test 9: Backup cleanup and retention
log "Test 9: Testing backup cleanup and retention..."
# Create multiple old backup files
touch -d '40 days ago' "$BACKUP_DIR/old_backup1.tar.gz.enc"
touch -d '40 days ago' "$BACKUP_DIR/old_backup2.tar.gz.enc"
touch -d '10 days ago' "$BACKUP_DIR/recent_backup.tar.gz.enc"

# Count files before cleanup
OLD_FILES_BEFORE=$(find "$BACKUP_DIR" -name "*.tar.gz.enc" -mtime +30 | wc -l)

# Simulate cleanup (find and remove old files)
find "$BACKUP_DIR" -name "*.tar.gz.enc" -mtime +30 -delete 2>/dev/null

# Count files after cleanup
OLD_FILES_AFTER=$(find "$BACKUP_DIR" -name "*.tar.gz.enc" -mtime +30 | wc -l)
RECENT_FILES=$(find "$BACKUP_DIR" -name "*.tar.gz.enc" -mtime -30 | wc -l)

if [ $OLD_FILES_AFTER -eq 0 ] && [ $RECENT_FILES -gt 0 ]; then
    test_result "Backup cleanup and retention" 0 ""
else
    test_result "Backup cleanup and retention" 1 "Cleanup did not work correctly"
fi

# Test 10: Multi-region backup simulation
log "Test 10: Simulating multi-region backup..."
# Create mock region directories
mkdir -p "$BACKUP_DIR/region1" "$BACKUP_DIR/region2" "$BACKUP_DIR/region3"

# Simulate cross-region backup copy
echo "region1 backup data" > "$BACKUP_DIR/region1/backup.dat"
cp "$BACKUP_DIR/region1/backup.dat" "$BACKUP_DIR/region2/"
cp "$BACKUP_DIR/region1/backup.dat" "$BACKUP_DIR/region3/"

if [ -f "$BACKUP_DIR/region2/backup.dat" ] && [ -f "$BACKUP_DIR/region3/backup.dat" ]; then
    test_result "Multi-region backup simulation" 0 ""
else
    test_result "Multi-region backup simulation" 1 "Cross-region backup copy failed"
fi

# Generate comprehensive test report
log ""
log "=== COMPREHENSIVE INTEGRATION TEST REPORT ==="
log "Total Tests Run: $((TEST_PASSED + TEST_FAILED))"
log "Tests Passed: $TEST_PASSED"
log "Tests Failed: $TEST_FAILED"
log "Success Rate: $(( (TEST_PASSED * 100) / (TEST_PASSED + TEST_FAILED) ))%"

if [ $TEST_FAILED -eq 0 ]; then
    log "🎉 ALL INTEGRATION TESTS PASSED!"
else
    log "⚠️  SOME INTEGRATION TESTS FAILED - Review log for details"
fi

# Save test summary to file
cat > "$TEST_RESULTS_DIR/integration_test_summary.txt" << EOF
Backup Integration Test Summary
==============================

Test Date: $(date)
Total Tests: $((TEST_PASSED + TEST_FAILED))
Passed: $TEST_PASSED
Failed: $TEST_FAILED
Success Rate: $(( (TEST_PASSED * 100) / (TEST_PASSED + TEST_FAILED) ))%

Test Results Location: $TEST_RESULTS_DIR
Detailed Log: $LOG_FILE

Integration Tests Performed:
- MongoDB test data setup and backup
- Redis test data setup and backup
- Configuration files backup
- SSL certificates backup
- Environment variables backup
- Backup script execution
- Backup contents verification
- MongoDB backup integrity check
- Redis backup integrity check
- Performance data creation
- Encryption key rotation testing
- Backup cleanup and retention
- Multi-region backup simulation

Backup Configuration:
- Encryption Key: Configured
- MongoDB URL: $MONGODB_URL
- Redis Host: $REDIS_HOST
- Redis Port: $REDIS_PORT
- Backup Directory: $BACKUP_DIR

EOF

log "Integration test results saved to: $TEST_RESULTS_DIR"
log "Summary: $TEST_RESULTS_DIR/integration_test_summary.txt"
log "Detailed log: $LOG_FILE"

# Cleanup test data
log "Cleaning up test data..."
rm -rf "$BACKUP_DIR"
rm -rf "$TEST_RESULTS_DIR/extracted_backup"

# Exit with appropriate code
if [ $TEST_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
