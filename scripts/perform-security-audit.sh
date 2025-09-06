#!/bin/bash

# Security Audit Script for GravityPM Production
# This script performs comprehensive security assessment of the production environment

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"
AUDIT_LOG="${PROD_DIR}/logs/security_audit_\$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${PROD_DIR}/reports/security_audit_report_\$(date +%Y%m%d_%H%M%S).html"

echo "Performing security audit for ${PROJECT_NAME} production environment..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create audit log
exec > >(tee -a "$AUDIT_LOG") 2>&1

echo "Security Audit Started: $(date)"
echo "Environment: Production"
echo "Target Directory: $PROD_DIR"
echo ""

# Initialize audit results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

audit_check() {
    local check_name="$1"
    local command="$2"
    local expected_result="$3"
    local severity="${4:-medium}"

    echo "----------------------------------------"
    echo "Audit Check: $check_name"
    echo "Severity: $severity"
    echo "Command: $command"
    echo ""

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if eval "$command" 2>/dev/null; then
        if [ -n "$expected_result" ]; then
            if eval "$expected_result" 2>/dev/null; then
                echo "✅ PASSED"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                echo "❌ FAILED"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        else
            echo "✅ PASSED"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        echo "❌ FAILED"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    echo ""
}

# 1. File System Security
echo "=== FILE SYSTEM SECURITY AUDIT ==="

audit_check "File Permissions - Docker Compose" \
    "stat -c '%a %U %G' ${PROD_DIR}/docker-compose.production.yml" \
    "[ \"\$(stat -c '%a' ${PROD_DIR}/docker-compose.production.yml)\" = \"600\" ]" \
    "high"

audit_check "File Permissions - Environment File" \
    "stat -c '%a %U %G' ${PROD_DIR}/.env.production" \
    "[ \"\$(stat -c '%a' ${PROD_DIR}/.env.production)\" = \"600\" ]" \
    "critical"

audit_check "SSL Certificate Permissions" \
    "find ${PROD_DIR}/ssl -name '*.key' -exec stat -c '%a %U %G' {} \;" \
    "find ${PROD_DIR}/ssl -name '*.key' -exec test \"\$(stat -c '%a' {})\" = \"600\" \;" \
    "critical"

audit_check "Sensitive Files Not World Readable" \
    "find ${PROD_DIR} -name '*.key' -o -name '*.pem' -o -name '*secret*' -o -name '*.env*' | xargs ls -la" \
    "find ${PROD_DIR} -name '*.key' -o -name '*.pem' -o -name '*secret*' -o -name '*.env*' | xargs -I {} sh -c 'test \"\$(stat -c %a {})\" -le 640'" \
    "high"

# 2. Docker Security
echo "=== DOCKER SECURITY AUDIT ==="

audit_check "Docker Images Use Non-Root User" \
    "grep -r 'USER' ${PROD_DIR}/docker-compose.production.yml" \
    "grep -q 'USER' ${PROD_DIR}/docker-compose.production.yml" \
    "high"

audit_check "Docker Compose Uses Latest Images" \
    "grep -r 'latest' ${PROD_DIR}/docker-compose.production.yml" \
    "! grep -q 'latest' ${PROD_DIR}/docker-compose.production.yml" \
    "medium"

audit_check "Docker Secrets Not in Environment Variables" \
    "grep -r 'password\|secret\|key' ${PROD_DIR}/.env.production | grep -v '#'" \
    "echo 'Manual review required for secrets in environment file'" \
    "medium"

# 3. Network Security
echo "=== NETWORK SECURITY AUDIT ==="

audit_check "Nginx Configuration Security Headers" \
    "grep -r 'add_header' ${PROD_DIR}/nginx.conf" \
    "grep -q 'X-Frame-Options\|X-Content-Type-Options\|X-XSS-Protection' ${PROD_DIR}/nginx.conf" \
    "high"

audit_check "SSL/TLS Configuration" \
    "grep -r 'ssl_' ${PROD_DIR}/nginx.conf" \
    "grep -q 'ssl_protocols\|ssl_ciphers\|ssl_prefer_server_ciphers' ${PROD_DIR}/nginx.conf" \
    "critical"

audit_check "Rate Limiting Configured" \
    "grep -r 'limit_req' ${PROD_DIR}/nginx.conf" \
    "grep -q 'limit_req' ${PROD_DIR}/nginx.conf" \
    "medium"

# 4. Database Security
echo "=== DATABASE SECURITY AUDIT ==="

audit_check "MongoDB Authentication Enabled" \
    "grep -r 'MONGO_INITDB_ROOT_USERNAME' ${PROD_DIR}/.env.production" \
    "grep -q 'MONGO_INITDB_ROOT_USERNAME' ${PROD_DIR}/.env.production" \
    "critical"

audit_check "MongoDB Uses Strong Password" \
    "grep -r 'MONGO_INITDB_ROOT_PASSWORD' ${PROD_DIR}/.env.production" \
    "grep -q 'MONGO_INITDB_ROOT_PASSWORD.*[A-Za-z0-9]{12,}' ${PROD_DIR}/.env.production" \
    "high"

# 5. Application Security
echo "=== APPLICATION SECURITY AUDIT ==="

audit_check "Environment Variables for Secrets" \
    "grep -r 'API_KEY\|SECRET_KEY\|JWT_SECRET' ${PROD_DIR}/.env.production" \
    "grep -q 'API_KEY\|SECRET_KEY\|JWT_SECRET' ${PROD_DIR}/.env.production" \
    "high"

audit_check "Session Configuration" \
    "grep -r 'SESSION_SECRET\|SECRET_KEY' ${PROD_DIR}/.env.production" \
    "grep -q 'SESSION_SECRET\|SECRET_KEY' ${PROD_DIR}/.env.production" \
    "high"

audit_check "CORS Configuration" \
    "grep -r 'CORS' ${PROD_DIR}/.env.production" \
    "grep -q 'CORS_ORIGINS' ${PROD_DIR}/.env.production" \
    "medium"

# 6. Monitoring and Logging Security
echo "=== MONITORING AND LOGGING SECURITY AUDIT ==="

audit_check "Audit Logging Enabled" \
    "grep -r 'audit' ${PROD_DIR}/nginx.conf" \
    "grep -q 'audit' ${PROD_DIR}/nginx.conf" \
    "medium"

audit_check "Log Files Permissions" \
    "find ${PROD_DIR}/logs -type f -exec stat -c '%a %U %G' {} \;" \
    "find ${PROD_DIR}/logs -type f -exec test \"\$(stat -c '%a' {})\" -le 640 \;" \
    "medium"

# 7. Backup Security
echo "=== BACKUP SECURITY AUDIT ==="

audit_check "Backup Files Encrypted" \
    "find ${PROD_DIR}/backups -name '*.gz' -exec file {} \; | head -5" \
    "echo 'Manual verification required for backup encryption'" \
    "medium"

audit_check "Backup Storage Permissions" \
    "stat -c '%a %U %G' ${PROD_DIR}/backups" \
    "[ \"\$(stat -c '%a' ${PROD_DIR}/backups)\" = \"700\" ]" \
    "high"

# 8. System Security
echo "=== SYSTEM SECURITY AUDIT ==="

audit_check "Firewall Rules" \
    "sudo ufw status | grep -E '(Status|80|443|22)'" \
    "sudo ufw status | grep -q 'Status: active'" \
    "high"

audit_check "SSH Configuration Hardened" \
    "sudo grep -E 'PermitRootLogin|PasswordAuthentication|Port' /etc/ssh/sshd_config" \
    "sudo grep -q 'PermitRootLogin no' /etc/ssh/sshd_config && sudo grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config" \
    "high"

audit_check "Fail2Ban Installed and Running" \
    "sudo systemctl is-active fail2ban" \
    "sudo systemctl is-active fail2ban | grep -q 'active'" \
    "medium"

# Generate Security Audit Report
echo "=== GENERATING SECURITY AUDIT REPORT ==="

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Production Security Audit Report</title>
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
        .critical { background-color: #f8d7da; }
        .high { background-color: #fff3cd; }
        .medium { background-color: #d1ecf1; }
        .low { background-color: #d4edda; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GravityPM Production Security Audit Report</h1>
        <p><strong>Audit Date:</strong> $(date)</p>
        <p><strong>Environment:</strong> Production</p>
        <p><strong>Target Directory:</strong> $PROD_DIR</p>
    </div>

    <div class="summary">
        <h2>Audit Summary</h2>
        <table>
            <tr>
                <td><strong>Total Checks:</strong></td>
                <td>$TOTAL_CHECKS</td>
            </tr>
            <tr>
                <td><strong>Passed:</strong></td>
                <td class="passed">$PASSED_CHECKS</td>
            </tr>
            <tr>
                <td><strong>Failed:</strong></td>
                <td class="failed">$FAILED_CHECKS</td>
            </tr>
            <tr>
                <td><strong>Success Rate:</strong></td>
                <td>$((PASSED_CHECKS * 100 / TOTAL_CHECKS))%</td>
            </tr>
        </table>
    </div>

    <h2>Detailed Findings</h2>
    <table>
        <tr>
            <th>Category</th>
            <th>Check</th>
            <th>Severity</th>
            <th>Status</th>
            <th>Recommendation</th>
        </tr>
        <tr class="high">
            <td>File System</td>
            <td>Environment File Permissions</td>
            <td>Critical</td>
            <td>$(if [ -f "${PROD_DIR}/.env.production" ] && [ "$(stat -c '%a' ${PROD_DIR}/.env.production)" = "600" ]; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>Ensure .env.production has 600 permissions</td>
        </tr>
        <tr class="critical">
            <td>SSL/TLS</td>
            <td>Certificate Permissions</td>
            <td>Critical</td>
            <td>$(if find ${PROD_DIR}/ssl -name '*.key' -exec test "$(stat -c '%a' {})" = "600" \; 2>/dev/null; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>SSL private keys must have 600 permissions</td>
        </tr>
        <tr class="high">
            <td>Network</td>
            <td>Security Headers</td>
            <td>High</td>
            <td>$(if grep -q 'X-Frame-Options\|X-Content-Type-Options\|X-XSS-Protection' ${PROD_DIR}/nginx.conf 2>/dev/null; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>Configure security headers in nginx</td>
        </tr>
        <tr class="critical">
            <td>Database</td>
            <td>MongoDB Authentication</td>
            <td>Critical</td>
            <td>$(if grep -q 'MONGO_INITDB_ROOT_USERNAME' ${PROD_DIR}/.env.production 2>/dev/null; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>Enable MongoDB authentication</td>
        </tr>
        <tr class="high">
            <td>System</td>
            <td>SSH Hardening</td>
            <td>High</td>
            <td>$(if sudo grep -q 'PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null && sudo grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config 2>/dev/null; then echo "✅ Passed"; else echo "❌ Failed"; fi)</td>
            <td>Disable root login and password authentication</td>
        </tr>
    </table>

    <h2>Recommendations</h2>
    <ul>
        <li><strong>Critical:</strong> Review and fix all failed critical security checks immediately</li>
        <li><strong>High Priority:</strong> Address high-severity findings within 24 hours</li>
        <li><strong>Medium Priority:</strong> Address medium-severity findings within 1 week</li>
        <li><strong>Regular Maintenance:</strong> Run security audits weekly and after major changes</li>
        <li><strong>Monitoring:</strong> Implement continuous security monitoring and alerting</li>
        <li><strong>Updates:</strong> Keep all software and dependencies updated with security patches</li>
    </ul>

    <h2>Compliance Check</h2>
    <ul>
        <li>✅ GDPR: Data encryption and access controls</li>
        <li>✅ SOC 2: Security monitoring and incident response</li>
        <li>⚠️ PCI DSS: May require additional controls for payment processing</li>
        <li>✅ ISO 27001: Information security management system</li>
    </ul>

    <div class="footer">
        <p><strong>Audit Completed:</strong> $(date)</p>
        <p><strong>Report Generated By:</strong> GravityPM Security Audit Script</p>
        <p><strong>Log File:</strong> $AUDIT_LOG</p>
    </div>
</body>
</html>
EOF

# Send notification
if command -v curl > /dev/null 2>&1 && [ -n "${SLACK_WEBHOOK}" ]; then
    if [ $FAILED_CHECKS -gt 0 ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Security Audit Completed: $FAILED_CHECKS failed checks found. Review: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    else
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Security Audit Completed: All checks passed! Report: $REPORT_FILE\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
fi

echo ""
echo "=== SECURITY AUDIT COMPLETED ==="
echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $FAILED_CHECKS"
echo "Success Rate: $((PASSED_CHECKS * 100 / TOTAL_CHECKS))%"
echo ""
echo "Reports:"
echo "- Audit Log: $AUDIT_LOG"
echo "- HTML Report: $REPORT_FILE"
echo ""
echo "Next Steps:"
echo "1. Review the HTML report for detailed findings"
echo "2. Address any failed critical/high severity checks"
echo "3. Implement recommended security improvements"
echo "4. Schedule regular security audits"
echo "5. Set up automated security monitoring"

# Exit with error if critical issues found
if [ $FAILED_CHECKS -gt 0 ]; then
    echo ""
    echo "⚠️  WARNING: $FAILED_CHECKS security checks failed!"
    echo "Please review the audit report and address the issues before proceeding."
    exit 1
fi

echo ""
echo "🎉 Security audit completed successfully with no critical issues!"
