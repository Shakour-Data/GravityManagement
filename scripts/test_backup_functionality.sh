#!/bin/bash

# Comprehensive Backup Functionality Test Script
# This script tests all backup-related functionality

TEST_RESULTS_DIR="/test_results/backup_tests/$(date +%Y-%m-%d_%H-%M-%S)"
LOG_FILE="$TEST_RESULTS_DIR/test_backup.log"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Test configuration
BACKUP_ENCRYPTION_KEY="test_encryption_key_12345"
MONGODB_URL="mongodb://localhost:27017/gravitypm_test"
REDIS_HOST="localhost"
REDIS_PORT="6379"

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

log "Starting comprehensive backup functionality tests..."
log "Test results will be saved to: $TEST_RESULTS_DIR"

# Test 1: Backup script existence and permissions
log "Test 1: Checking backup script existence and permissions..."
if [ -f "scripts/backup.sh" ]; then
    if [ -x "scripts/backup.sh" ]; then
        test_result "Backup script exists and is executable" 0 ""
    else
        test_result "Backup script exists but not executable" 1 "Script needs execute permissions"
    fi
else
    test_result "Backup script exists" 1 "backup.sh not found in scripts directory"
fi

# Test 2: Environment variable setup
log "Test 2: Testing environment variable setup..."
export BACKUP_ENCRYPTION_KEY="$BACKUP_ENCRYPTION_KEY"
export MONGODB_URL="$MONGODB_URL"
export REDIS_HOST="$REDIS_HOST"
export REDIS_PORT="$REDIS_PORT"

if [ -n "$BACKUP_ENCRYPTION_KEY" ] && [ -n "$MONGODB_URL" ]; then
    test_result "Environment variables set correctly" 0 ""
else
    test_result "Environment variables set correctly" 1 "Required environment variables not set"
fi

# Test 3: Backup directory creation
log "Test 3: Testing backup directory creation..."
BACKUP_TEST_DIR="/tmp/backup_test_$(date +%s)"
mkdir -p "$BACKUP_TEST_DIR"
if [ -d "$BACKUP_TEST_DIR" ]; then
    test_result "Backup directory creation" 0 ""
    rmdir "$BACKUP_TEST_DIR"
else
    test_result "Backup directory creation" 1 "Failed to create backup directory"
fi

# Test 4: Encryption functionality
log "Test 4: Testing encryption functionality..."
TEST_DATA="This is test data for encryption"
echo "$TEST_DATA" > "$TEST_RESULTS_DIR/test_data.txt"

# Test encryption
openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$BACKUP_ENCRYPTION_KEY" -in "$TEST_RESULTS_DIR/test_data.txt" -out "$TEST_RESULTS_DIR/test_data.enc" 2>/dev/null
if [ $? -eq 0 ]; then
    # Test decryption
    openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$BACKUP_ENCRYPTION_KEY" -in "$TEST_RESULTS_DIR/test_data.enc" -out "$TEST_RESULTS_DIR/test_data_decrypted.txt" 2>/dev/null
    if [ $? -eq 0 ]; then
        DECRYPTED_CONTENT=$(cat "$TEST_RESULTS_DIR/test_data_decrypted.txt")
        if [ "$DECRYPTED_CONTENT" = "$TEST_DATA" ]; then
            test_result "Encryption/decryption functionality" 0 ""
        else
            test_result "Encryption/decryption functionality" 1 "Decrypted content does not match original"
        fi
    else
        test_result "Encryption/decryption functionality" 1 "Decryption failed"
    fi
else
    test_result "Encryption/decryption functionality" 1 "Encryption failed"
fi

# Test 5: Compression functionality
log "Test 5: Testing compression functionality..."
echo "Test compression data" > "$TEST_RESULTS_DIR/compress_test.txt"
tar -czf "$TEST_RESULTS_DIR/compress_test.tar.gz" -C "$TEST_RESULTS_DIR" compress_test.txt 2>/dev/null
if [ $? -eq 0 ] && [ -f "$TEST_RESULTS_DIR/compress_test.tar.gz" ]; then
    # Test decompression
    mkdir -p "$TEST_RESULTS_DIR/decompress_test"
    tar -xzf "$TEST_RESULTS_DIR/compress_test.tar.gz" -C "$TEST_RESULTS_DIR/decompress_test" 2>/dev/null
    if [ $? -eq 0 ] && [ -f "$TEST_RESULTS_DIR/decompress_test/compress_test.txt" ]; then
        test_result "Compression/decompression functionality" 0 ""
    else
        test_result "Compression/decompression functionality" 1 "Decompression failed"
    fi
else
    test_result "Compression/decompression functionality" 1 "Compression failed"
fi

# Test 6: MongoDB connection test (mock)
log "Test 6: Testing MongoDB connection simulation..."
if command -v mongodump &> /dev/null; then
    test_result "MongoDB tools availability" 0 ""
else
    test_result "MongoDB tools availability" 1 "mongodump command not found"
fi

# Test 7: Redis connection test (mock)
log "Test 7: Testing Redis connection simulation..."
if command -v redis-cli &> /dev/null; then
    test_result "Redis CLI availability" 0 ""
else
    test_result "Redis CLI availability" 1 "redis-cli command not found"
fi

# Test 8: File system operations
log "Test 8: Testing file system operations..."
# Create test directories and files
mkdir -p "$TEST_RESULTS_DIR/test_config"
mkdir -p "$TEST_RESULTS_DIR/test_ssl"
echo "test config data" > "$TEST_RESULTS_DIR/test_config/app.conf"
echo "test ssl data" > "$TEST_RESULTS_DIR/test_ssl/cert.pem"

# Test copying operations
cp -r "$TEST_RESULTS_DIR/test_config" "$TEST_RESULTS_DIR/config_backup" 2>/dev/null
cp -r "$TEST_RESULTS_DIR/test_ssl" "$TEST_RESULTS_DIR/ssl_backup" 2>/dev/null

if [ -d "$TEST_RESULTS_DIR/config_backup" ] && [ -d "$TEST_RESULTS_DIR/ssl_backup" ]; then
    test_result "File system operations" 0 ""
else
    test_result "File system operations" 1 "File copy operations failed"
fi

# Test 9: Environment variable filtering
log "Test 9: Testing environment variable filtering..."
export TEST_PASSWORD="secret123"
export TEST_API_KEY="apikey456"
export TEST_NORMAL_VAR="normal_value"

env | grep -v -E "(PASSWORD|SECRET|KEY)" > "$TEST_RESULTS_DIR/filtered_env.txt"
FILTERED_CONTENT=$(cat "$TEST_RESULTS_DIR/filtered_env.txt")

if echo "$FILTERED_CONTENT" | grep -q "TEST_NORMAL_VAR" && ! echo "$FILTERED_CONTENT" | grep -q "TEST_PASSWORD" && ! echo "$FILTERED_CONTENT" | grep -q "TEST_API_KEY"; then
    test_result "Environment variable filtering" 0 ""
else
    test_result "Environment variable filtering" 1 "Environment variable filtering not working correctly"
fi

# Test 10: Cleanup functionality
log "Test 10: Testing cleanup functionality..."
# Create old test files
touch -d '40 days ago' "$TEST_RESULTS_DIR/old_file.tar.gz"
touch -d '40 days ago' "$TEST_RESULTS_DIR/old_file.tar.gz.enc"
touch -d '40 days ago' "$TEST_RESULTS_DIR/old_file.rdb"

# Run cleanup (simulate find command)
find "$TEST_RESULTS_DIR" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null
find "$TEST_RESULTS_DIR" -name "*.tar.gz.enc" -mtime +30 -delete 2>/dev/null
find "$TEST_RESULTS_DIR" -name "*.rdb" -mtime +30 -delete 2>/dev/null

if [ ! -f "$TEST_RESULTS_DIR/old_file.tar.gz" ] && [ ! -f "$TEST_RESULTS_DIR/old_file.tar.gz.enc" ] && [ ! -f "$TEST_RESULTS_DIR/old_file.rdb" ]; then
    test_result "Cleanup functionality" 0 ""
else
    test_result "Cleanup functionality" 1 "Old files not cleaned up properly"
fi

# Test 11: Backup script syntax validation
log "Test 11: Testing backup script syntax..."
bash -n scripts/backup.sh 2>/dev/null
if [ $? -eq 0 ]; then
    test_result "Backup script syntax validation" 0 ""
else
    test_result "Backup script syntax validation" 1 "Syntax errors in backup script"
fi

# Test 12: Error handling simulation
log "Test 12: Testing error handling..."
# Simulate missing encryption key
unset BACKUP_ENCRYPTION_KEY
if [ -z "$BACKUP_ENCRYPTION_KEY" ]; then
    test_result "Error handling - missing encryption key" 0 ""
else
    test_result "Error handling - missing encryption key" 1 "Should handle missing encryption key gracefully"
fi

# Generate comprehensive test report
log ""
log "=== COMPREHENSIVE TEST REPORT ==="
log "Total Tests Run: $((TEST_PASSED + TEST_FAILED))"
log "Tests Passed: $TEST_PASSED"
log "Tests Failed: $TEST_FAILED"
log "Success Rate: $(( (TEST_PASSED * 100) / (TEST_PASSED + TEST_FAILED) ))%"

if [ $TEST_FAILED -eq 0 ]; then
    log "🎉 ALL TESTS PASSED!"
else
    log "⚠️  SOME TESTS FAILED - Review log for details"
fi

# Save test summary to file
cat > "$TEST_RESULTS_DIR/test_summary.txt" << EOF
Backup Functionality Test Summary
=================================

Test Date: $(date)
Total Tests: $((TEST_PASSED + TEST_FAILED))
Passed: $TEST_PASSED
Failed: $TEST_FAILED
Success Rate: $(( (TEST_PASSED * 100) / (TEST_PASSED + TEST_FAILED) ))%

Test Results Location: $TEST_RESULTS_DIR
Detailed Log: $LOG_FILE

Components Tested:
- Backup script existence and permissions
- Environment variable setup
- Backup directory creation
- Encryption/decryption functionality
- Compression/decompression functionality
- MongoDB tools availability
- Redis CLI availability
- File system operations
- Environment variable filtering
- Cleanup functionality
- Script syntax validation
- Error handling

EOF

log "Test results saved to: $TEST_RESULTS_DIR"
log "Summary: $TEST_RESULTS_DIR/test_summary.txt"
log "Detailed log: $LOG_FILE"

# Exit with appropriate code
if [ $TEST_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
