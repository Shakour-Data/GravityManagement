#!/bin/bash

# Audit Logging Setup Script for GravityPM
# This script sets up comprehensive audit logging and data masking

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
AUDIT_DIR="/opt/${PROJECT_NAME}/audit"
LOG_DIR="/var/log/${PROJECT_NAME}"

echo "Setting up audit logging and data masking for ${ENVIRONMENT} environment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y rsyslog auditd audispd-plugins python3-pip

# Install Python logging libraries
sudo pip3 install structlog python-json-logger

# Create audit directory structure
sudo mkdir -p "$AUDIT_DIR"
sudo mkdir -p "$LOG_DIR"
sudo chmod 700 "$AUDIT_DIR"
sudo chmod 755 "$LOG_DIR"

# Configure auditd for system-level auditing
echo "Configuring auditd..."

# Backup original audit rules
sudo cp /etc/audit/audit.rules /etc/audit/audit.rules.backup

# Create comprehensive audit rules
cat > /etc/audit/audit.rules << EOF
# GravityPM Audit Rules

# Delete all existing rules
-D

# Buffer size
-b 8192

# Failure mode
-f 1

# System startup/shutdown
-w /sbin/shutdown -p x -k system-shutdown
-w /sbin/poweroff -p x -k system-shutdown
-w /sbin/reboot -p x -k system-shutdown
-w /sbin/halt -p x -k system-shutdown

# User authentication
-w /etc/passwd -p wa -k user-modification
-w /etc/shadow -p wa -k user-modification
-w /etc/group -p wa -k user-modification
-w /etc/gshadow -p wa -k user-modification

# SSH authentication
-w /var/log/auth.log -p wa -k authentication
-w /etc/ssh/sshd_config -p wa -k ssh-configuration

# Application logs
-w /var/log/${PROJECT_NAME}/ -p wa -k application-logs

# Database access
-w /var/lib/mongodb/ -p wa -k database-access
-w /var/lib/redis/ -p wa -k redis-access

# Key management
-w /opt/${PROJECT_NAME}/encryption/ -p wa -k key-management
-w /opt/${PROJECT_NAME}/kms/ -p wa -k key-management

# Network configuration
-w /etc/nginx/nginx.conf -p wa -k network-configuration
-w /etc/hosts -p wa -k network-configuration

# File integrity monitoring
-w /etc/passwd -p wa -k file-integrity
-w /etc/shadow -p wa -k file-integrity
-w /etc/group -p wa -k file-integrity
-w /etc/gshadow -p wa -k file-integrity
-w /etc/sudoers -p wa -k file-integrity

# Process execution monitoring
-a always,exit -F arch=b64 -S execve -k process-execution
-a always,exit -F arch=b32 -S execve -k process-execution

# Account changes
-w /etc/login.defs -p wa -k account-changes
-w /etc/securetty -p wa -k account-changes

# Kernel module loading
-w /etc/modprobe.conf -p wa -k kernel-modules
-w /etc/modprobe.d/ -p wa -k kernel-modules

# Cron jobs
-w /etc/cron.allow -p wa -k cron-jobs
-w /etc/cron.deny -p wa -k cron-jobs
-w /var/spool/cron/ -p wa -k cron-jobs

# End of rules
EOF

# Configure auditd
cat > /etc/audit/auditd.conf << EOF
#
# This file controls the configuration of the audit daemon
#

local_events = yes
write_logs = yes
log_file = /var/log/audit/audit.log
log_group = adm
log_format = ENRICHED
flush = INCREMENTAL_ASYNC
freq = 50
max_log_file = 8
num_logs = 5
priority_boost = 4
disp_qos = lossy
dispatcher = /sbin/audispd
name_format = NONE
##name = mydomain
max_log_file_action = ROTATE
space_left = 75
space_left_action = SYSLOG
action_mail_acct = root
admin_space_left = 50
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
##tcp_listen_port =
tcp_listen_queue = 5
tcp_max_per_addr = 1
##tcp_client_ports = 1024-65535
tcp_client_max_idle = 0
enable_krb5 = no
krb5_principal = auditd
##krb5_key_file = /etc/audit/audit.key
distribute_network = no
EOF

# Restart auditd
sudo systemctl restart auditd
sudo systemctl enable auditd

# Configure rsyslog for application logging
echo "Configuring rsyslog for application logging..."

# Create rsyslog configuration for GravityPM
cat > /etc/rsyslog.d/${PROJECT_NAME}.conf << EOF
# GravityPM Logging Configuration

# Application logs
if \$programname == '${PROJECT_NAME}' then /var/log/${PROJECT_NAME}/application.log
if \$programname == '${PROJECT_NAME}' then ~
if \$programname == '${PROJECT_NAME}-audit' then /var/log/${PROJECT_NAME}/audit.log
if \$programname == '${PROJECT_NAME}-audit' then ~

# Security events
if \$syslogfacility-text == 'auth' or \$syslogfacility-text == 'authpriv' then /var/log/${PROJECT_NAME}/security.log
if \$syslogfacility-text == 'auth' or \$syslogfacility-text == 'authpriv' then ~

# Database logs
if \$programname == 'mongod' then /var/log/${PROJECT_NAME}/database.log
if \$programname == 'mongod' then ~
if \$programname == 'redis-server' then /var/log/${PROJECT_NAME}/redis.log
if \$programname == 'redis-server' then ~

# Web server logs
if \$programname == 'nginx' then /var/log/${PROJECT_NAME}/web.log
if \$programname == 'nginx' then ~

# Log rotation
\$outchannel log_rotation,/var/log/${PROJECT_NAME}/application.log,10485760,/opt/${PROJECT_NAME}/scripts/logrotate.sh
EOF

# Create logrotate script
cat > /opt/${PROJECT_NAME}/scripts/logrotate.sh << 'EOF'
#!/bin/bash

# Log rotation script for GravityPM
LOG_DIR="/var/log/gravitypm"
BACKUP_DIR="/opt/backup/gravitypm/production/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Compress and backup logs
find "$LOG_DIR" -name "*.log" -type f | while read -r log_file; do
    base_name=$(basename "$log_file")
    compressed_file="$BACKUP_DIR/${base_name%.log}_${TIMESTAMP}.gz"

    # Compress the log file
    gzip -c "$log_file" > "$compressed_file"

    # Clear the original log file
    > "$log_file"

    echo "Rotated log: $log_file -> $compressed_file"
done

# Clean up old backups (keep last 30 days)
find "$BACKUP_DIR" -name "*.gz" -type f -mtime +30 -delete
EOF

sudo chmod +x /opt/${PROJECT_NAME}/scripts/logrotate.sh

# Set up logrotate configuration
cat > /etc/logrotate.d/${PROJECT_NAME} << EOF
/var/log/${PROJECT_NAME}/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root adm
    postrotate
        systemctl reload rsyslog
    endscript
}
EOF

# Restart rsyslog
sudo systemctl restart rsyslog

# Create Python audit logging module
echo "Creating Python audit logging module..."

cat > "$AUDIT_DIR/audit_logger.py" << 'EOF'
#!/usr/bin/env python3

import os
import json
import logging
import hashlib
from datetime import datetime
from typing import Dict, Any, Optional
import structlog

class AuditLogger:
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.audit_dir = os.path.dirname(config_path)
        self.log_file = self.config.get('audit_log_file', '/var/log/gravitypm/audit.log')

        # Configure structured logging
        structlog.configure(
            processors=[
                structlog.stdlib.filter_by_level,
                structlog.stdlib.add_logger_name,
                structlog.stdlib.add_log_level,
                structlog.stdlib.PositionalArgumentsFormatter(),
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.processors.StackInfoRenderer(),
                structlog.processors.format_exc_info,
                structlog.processors.UnicodeDecoder(),
                self._add_audit_fields,
                structlog.processors.JSONRenderer()
            ],
            context_class=dict,
            logger_factory=structlog.stdlib.LoggerFactory(),
            wrapper_class=structlog.stdlib.BoundLogger,
            cache_logger_on_first_use=True,
        )

        self.logger = structlog.get_logger()

    def _add_audit_fields(self, logger, method_name, event_dict):
        """Add audit-specific fields to log entries"""
        event_dict['audit_event'] = True
        event_dict['audit_timestamp'] = datetime.utcnow().isoformat()
        event_dict['audit_version'] = '1.0'

        # Add hash for integrity
        content = json.dumps(event_dict, sort_keys=True)
        event_dict['integrity_hash'] = hashlib.sha256(content.encode()).hexdigest()

        return event_dict

    def log_authentication(self, user_id: str, action: str, success: bool,
                          ip_address: str, user_agent: str = None,
                          details: Dict[str, Any] = None):
        """Log authentication events"""
        self.logger.info(
            'authentication_event',
            event_type='authentication',
            user_id=self._mask_sensitive_data(user_id),
            action=action,
            success=success,
            ip_address=ip_address,
            user_agent=user_agent,
            details=details or {}
        )

    def log_authorization(self, user_id: str, resource: str, action: str,
                         decision: str, ip_address: str,
                         details: Dict[str, Any] = None):
        """Log authorization events"""
        self.logger.info(
            'authorization_event',
            event_type='authorization',
            user_id=self._mask_sensitive_data(user_id),
            resource=resource,
            action=action,
            decision=decision,
            ip_address=ip_address,
            details=details or {}
        )

    def log_data_access(self, user_id: str, data_type: str, operation: str,
                       record_id: str = None, ip_address: str = None,
                       details: Dict[str, Any] = None):
        """Log data access events"""
        self.logger.info(
            'data_access_event',
            event_type='data_access',
            user_id=self._mask_sensitive_data(user_id),
            data_type=data_type,
            operation=operation,
            record_id=self._mask_sensitive_data(record_id) if record_id else None,
            ip_address=ip_address,
            details=self._mask_sensitive_details(details) if details else {}
        )

    def log_security_event(self, event_type: str, severity: str,
                          description: str, user_id: str = None,
                          ip_address: str = None, details: Dict[str, Any] = None):
        """Log security events"""
        self.logger.warning(
            'security_event',
            event_type=event_type,
            severity=severity,
            description=description,
            user_id=self._mask_sensitive_data(user_id) if user_id else None,
            ip_address=ip_address,
            details=self._mask_sensitive_details(details) if details else {}
        )

    def log_admin_action(self, admin_id: str, action: str, target: str = None,
                        ip_address: str = None, details: Dict[str, Any] = None):
        """Log administrative actions"""
        self.logger.info(
            'admin_action_event',
            event_type='admin_action',
            admin_id=self._mask_sensitive_data(admin_id),
            action=action,
            target=self._mask_sensitive_data(target) if target else None,
            ip_address=ip_address,
            details=self._mask_sensitive_details(details) if details else {}
        )

    def _mask_sensitive_data(self, data: str) -> str:
        """Mask sensitive data in logs"""
        if not data:
            return data

        # Mask email addresses
        if '@' in data:
            parts = data.split('@')
            if len(parts) == 2:
                username = parts[0][:2] + '*' * (len(parts[0]) - 2) if len(parts[0]) > 2 else parts[0]
                domain = parts[1]
                return f"{username}@{domain}"

        # Mask phone numbers
        if data.replace('+', '').replace('-', '').replace(' ', '').isdigit() and len(data) > 6:
            return data[:3] + '*' * (len(data) - 6) + data[-3:]

        # Mask credit card numbers
        if data.replace(' ', '').replace('-', '').isdigit() and len(data.replace(' ', '').replace('-', '')) >= 13:
            return '*' * (len(data) - 4) + data[-4:]

        # Mask social security numbers
        if len(data) == 11 and data[3] == '-' and data[6] == '-':
            return '***-**-' + data[-4:]

        return data

    def _mask_sensitive_details(self, details: Dict[str, Any]) -> Dict[str, Any]:
        """Mask sensitive data in detail dictionaries"""
        if not details:
            return details

        masked_details = {}
        sensitive_keys = ['password', 'token', 'secret', 'key', 'credit_card', 'ssn', 'phone']

        for key, value in details.items():
            if any(sensitive in key.lower() for sensitive in sensitive_keys):
                if isinstance(value, str):
                    masked_details[key] = self._mask_sensitive_data(value)
                else:
                    masked_details[key] = '[REDACTED]'
            else:
                masked_details[key] = value

        return masked_details

    def verify_log_integrity(self, log_file: str = None) -> bool:
        """Verify the integrity of audit logs"""
        log_file = log_file or self.log_file

        if not os.path.exists(log_file):
            return False

        with open(log_file, 'r') as f:
            for line in f:
                try:
                    log_entry = json.loads(line.strip())
                    content = json.dumps({k: v for k, v in log_entry.items() if k != 'integrity_hash'}, sort_keys=True)
                    expected_hash = hashlib.sha256(content.encode()).hexdigest()
                    actual_hash = log_entry.get('integrity_hash')

                    if expected_hash != actual_hash:
                        return False
                except (json.JSONDecodeError, KeyError):
                    return False

        return True

# CLI interface for testing
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python audit_logger.py <config_path> [command]")
        sys.exit(1)

    config_path = sys.argv[1]
    audit = AuditLogger(config_path)

    if len(sys.argv) > 2:
        command = sys.argv[2]

        if command == 'test':
            # Test audit logging
            audit.log_authentication('user123', 'login', True, '192.168.1.1')
            audit.log_security_event('suspicious_activity', 'medium', 'Multiple failed login attempts', 'user123', '192.168.1.1')
            print("Audit logging test completed")

        elif command == 'verify':
            # Verify log integrity
            valid = audit.verify_log_integrity()
            print(f"Log integrity: {'VALID' if valid else 'INVALID'}")

        else:
            print(f"Unknown command: {command}")
EOF

sudo chmod +x "$AUDIT_DIR/audit_logger.py"

# Create audit configuration
cat > "$AUDIT_DIR/audit-config.json" << EOF
{
    "version": "1.0",
    "environment": "${ENVIRONMENT}",
    "audit_log_file": "/var/log/${PROJECT_NAME}/audit.log",
    "application_log_file": "/var/log/${PROJECT_NAME}/application.log",
    "security_log_file": "/var/log/${PROJECT_NAME}/security.log",
    "log_rotation": {
        "enabled": true,
        "max_size_mb": 10,
        "retention_days": 90,
        "compression": true
    },
    "data_masking": {
        "enabled": true,
        "mask_emails": true,
        "mask_phone_numbers": true,
        "mask_credit_cards": true,
        "mask_ssn": true,
        "custom_patterns": []
    },
    "integrity_check": {
        "enabled": true,
        "check_interval_hours": 24
    },
    "alerting": {
        "enabled": true,
        "alert_email": "security@gravitypm.com",
        "alert_on_suspicious_activity": true,
        "alert_on_failed_auth": true
    }
}
EOF

# Create audit monitoring script
echo "Creating audit monitoring script..."

cat > "$AUDIT_DIR/monitor-audit.sh" << 'EOF'
#!/bin/bash

# Audit monitoring script
AUDIT_DIR="/opt/gravitypm/audit"
LOG_DIR="/var/log/gravitypm"
LOG_FILE="/var/log/gravitypm/audit-monitor.log"
ALERT_EMAIL="security@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_log_files() {
    local log_files=("$LOG_DIR/audit.log" "$LOG_DIR/application.log" "$LOG_DIR/security.log")

    for log_file in "${log_files[@]}"; do
        if [ ! -f "$log_file" ]; then
            log "ERROR: Log file missing: $log_file"
            echo "ERROR: Log file missing: $log_file" | mail -s "Audit Log Alert" "$ALERT_EMAIL"
            continue
        fi

        # Check file permissions
        local perms=$(stat -c %a "$log_file")
        if [ "$perms" != "644" ]; then
            log "WARNING: Incorrect permissions on $log_file: $perms"
            echo "WARNING: Incorrect permissions on log file: $log_file" | mail -s "Log Permission Warning" "$ALERT_EMAIL"
        fi

        # Check file size
        local size=$(stat -c %s "$log_file")
        local max_size=$((10 * 1024 * 1024))  # 10MB
        if [ $size -gt $max_size ]; then
            log "WARNING: Log file size exceeds limit: $log_file (${size} bytes)"
        fi
    done
}

check_audit_integrity() {
    log "Checking audit log integrity..."

    python3 "$AUDIT_DIR/audit_logger.py" "$AUDIT_DIR/audit-config.json" verify
    if [ $? -ne 0 ]; then
        log "ERROR: Audit log integrity check failed"
        echo "ERROR: Audit log integrity compromised" | mail -s "Audit Integrity Alert" "$ALERT_EMAIL"
    else
        log "Audit log integrity check passed"
    fi
}

check_failed_authentications() {
    local auth_log="/var/log/auth.log"
    local threshold=5

    if [ -f "$auth_log" ]; then
        # Count failed authentications in last hour
        local failed_count=$(grep "Failed password" "$auth_log" | grep "$(date '+%b %e %H')" | wc -l)

        if [ $failed_count -gt $threshold ]; then
            log "WARNING: High number of failed authentications: $failed_count"
            echo "WARNING: High number of failed authentications detected: $failed_count" | mail -s "Authentication Warning" "$ALERT_EMAIL"
        fi
    fi
}

check_suspicious_activity() {
    local audit_log="/var/log/audit/audit.log"

    if [ -f "$audit_log" ]; then
        # Check for suspicious patterns
        local suspicious_count=$(grep -c "suspicious_activity\|security_event" "$audit_log")

        if [ $suspicious_count -gt 0 ]; then
            log "ALERT: Suspicious activity detected in audit logs"
            echo "ALERT: Suspicious activity detected in audit logs" | mail -s "Security Alert" "$ALERT_EMAIL"
        fi
    fi
}

log "Starting audit monitoring..."

check_log_files
check_audit_integrity
check_failed_authentications
check_suspicious_activity

log "Audit monitoring completed"
EOF

sudo chmod +x "$AUDIT_DIR/monitor-audit.sh"

# Set up audit monitoring (hourly)
sudo crontab -l | { cat; echo "0 * * * * $AUDIT_DIR/monitor-audit.sh"; } | sudo crontab -

# Create log analysis script
echo "Creating log analysis script..."

cat > "$AUDIT_DIR/analyze-logs.sh" << 'EOF'
#!/bin/bash

# Log analysis script
AUDIT_DIR="/opt/gravitypm/audit"
LOG_DIR="/var/log/gravitypm"
REPORT_DIR="/opt/gravitypm/reports"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

generate_report() {
    local report_date=$(date +%Y%m%d)
    local report_file="$REPORT_DIR/audit-report-${report_date}.html"

    mkdir -p "$REPORT_DIR"

    cat > "$report_file" << HTML
<!DOCTYPE html>
<html>
<head>
    <title>GravityPM Audit Report - ${report_date}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin-bottom: 30px; }
        .metric { background: #f0f0f0; padding: 10px; margin: 10px 0; }
        .alert { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>GravityPM Audit Report</h1>
    <p>Report Date: $(date)</p>

    <div class="section">
        <h2>Authentication Events</h2>
        <div class="metric">
            Total Authentications: $(grep -c "authentication_event" "$LOG_DIR/audit.log" 2>/dev/null || echo "0")
        </div>
        <div class="metric">
            Failed Authentications: $(grep -c '"success": false' "$LOG_DIR/audit.log" 2>/dev/null || echo "0")
        </div>
    </div>

    <div class="section">
        <h2>Security Events</h2>
        <div class="metric">
            Total Security Events: $(grep -c "security_event" "$LOG_DIR/audit.log" 2>/dev/null || echo "0")
        </div>
        <div class="metric">
            High Severity Events: $(grep -c '"severity": "high"' "$LOG_DIR/audit.log" 2>/dev/null || echo "0")
        </div>
    </div>

    <div class="section">
        <h2>Data Access Events</h2>
        <div class="metric">
            Total Data Access: $(grep -c "data_access_event" "$LOG_DIR/audit.log" 2>/dev/null || echo "0")
        </div>
    </div>

    <div class="section">
        <h2>Recent Events</h2>
        <table>
            <tr><th>Timestamp</th><th>Event Type</th><th>User</th><th>Action</th></tr>
HTML

    # Add recent events to report
    tail -20 "$LOG_DIR/audit.log" 2>/dev/null | jq -r '.timestamp + "," + .event_type + "," + (.user_id // "N/A") + "," + (.action // .description // "N/A")' 2>/dev/null | while IFS=',' read -r timestamp event_type user action; do
        echo "            <tr><td>$timestamp</td><td>$event_type</td><td>$user</td><td>$action</td></tr>" >> "$report_file"
    done

    cat >> "$report_file" << HTML
        </table>
    </div>
</body>
</html>
HTML

    log "Audit report generated: $report_file"
}

log "Starting log analysis..."

generate_report

log "Log analysis completed"
EOF

sudo chmod +x "$AUDIT_DIR/analyze-logs.sh"

# Set up weekly log analysis
sudo crontab -l | { cat; echo "0 6 * * 1 $AUDIT_DIR/analyze-logs.sh"; } | sudo crontab -

# Update environment configuration
echo "Updating environment configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# Audit Logging Configuration
AUDIT_LOGGING_ENABLED=true
AUDIT_CONFIG_PATH=$AUDIT_DIR/audit-config.json
AUDIT_LOG_FILE=$LOG_DIR/audit.log
AUDIT_LOG_LEVEL=INFO
DATA_MASKING_ENABLED=true

# Log rotation settings
LOG_ROTATION_ENABLED=true
LOG_MAX_SIZE_MB=10
LOG_RETENTION_DAYS=90
EOF

# Test audit logging
echo "Testing audit logging..."

# Create test log entry
python3 "$AUDIT_DIR/audit_logger.py" "$AUDIT_DIR/audit-config.json" test

echo "Audit logging and data masking setup completed!"
echo "Audit directory: $AUDIT_DIR"
echo "Configuration: $AUDIT_DIR/audit-config.json"
echo "Audit logs: $LOG_DIR/audit.log"
echo "Application logs: $LOG_DIR/application.log"
echo "Security logs: $LOG_DIR/security.log"
echo ""
echo "Next steps:"
echo "1. Test audit logging functionality"
echo "2. Configure application to use audit logger"
echo "3. Set up log shipping to centralized logging system"
echo "4. Configure log alerting and monitoring"
echo "5. Test data masking functionality"
echo "6. Set up log backup and archival"
echo "7. Configure compliance reporting"
echo "8. Test log integrity verification"
