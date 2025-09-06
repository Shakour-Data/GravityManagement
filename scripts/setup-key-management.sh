#!/bin/bash

# Secure Key Management Setup Script for GravityPM
# This script sets up secure key management and rotation

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
KMS_DIR="/opt/${PROJECT_NAME}/kms"
BACKUP_DIR="/opt/backup/${PROJECT_NAME}/${ENVIRONMENT}"

echo "Setting up secure key management for ${ENVIRONMENT} environment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-dev build-essential libssl-dev

# Install Python cryptography libraries
sudo pip3 install cryptography boto3 azure-identity azure-keyvault-keys google-cloud-kms

# Create KMS directory structure
sudo mkdir -p "$KMS_DIR"
sudo chmod 700 "$KMS_DIR"

# Create key management configuration
echo "Creating key management configuration..."

cat > "$KMS_DIR/kms-config.json" << EOF
{
    "version": "1.0",
    "environment": "${ENVIRONMENT}",
    "key_providers": {
        "local": {
            "enabled": true,
            "key_store": "${KMS_DIR}/local-keys",
            "algorithm": "AES256",
            "key_size": 256
        },
        "aws": {
            "enabled": false,
            "region": "us-east-1",
            "key_alias": "${PROJECT_NAME}-${ENVIRONMENT}",
            "key_spec": "SYMMETRIC_DEFAULT"
        },
        "azure": {
            "enabled": false,
            "vault_url": "https://${PROJECT_NAME}-${ENVIRONMENT}.vault.azure.net/",
            "key_name": "${PROJECT_NAME}-master-key"
        },
        "gcp": {
            "enabled": false,
            "project_id": "${PROJECT_NAME}",
            "location": "us-east1",
            "key_ring": "${PROJECT_NAME}-${ENVIRONMENT}",
            "key_name": "master-key"
        }
    },
    "key_rotation": {
        "enabled": true,
        "interval_days": 90,
        "backup_keys": true,
        "notify_on_rotation": true
    },
    "encryption": {
        "default_algorithm": "AES256-GCM",
        "supported_algorithms": ["AES256-GCM", "ChaCha20-Poly1305", "RSA-OAEP"],
        "key_derivation": "PBKDF2",
        "iterations": 100000
    },
    "audit": {
        "enabled": true,
        "log_file": "/var/log/${PROJECT_NAME}/kms-audit.log",
        "log_level": "INFO"
    }
}
EOF

# Create local key store
echo "Setting up local key store..."
LOCAL_KEYS_DIR="$KMS_DIR/local-keys"
sudo mkdir -p "$LOCAL_KEYS_DIR"
sudo chmod 700 "$LOCAL_KEYS_DIR"

# Generate master key
MASTER_KEY_FILE="$LOCAL_KEYS_DIR/master.key"
sudo openssl rand -hex 32 | sudo tee "$MASTER_KEY_FILE" > /dev/null
sudo chmod 600 "$MASTER_KEY_FILE"

# Generate data encryption keys
DATA_KEY_FILE="$LOCAL_KEYS_DIR/data.key"
sudo openssl rand -hex 32 | sudo tee "$DATA_KEY_FILE" > /dev/null
sudo chmod 600 "$DATA_KEY_FILE"

# Generate authentication keys
AUTH_KEY_FILE="$LOCAL_KEYS_DIR/auth.key"
sudo openssl rand -hex 32 | sudo tee "$AUTH_KEY_FILE" > /dev/null
sudo chmod 600 "$AUTH_KEY_FILE"

# Create key metadata
cat > "$LOCAL_KEYS_DIR/metadata.json" << EOF
{
    "master_key": {
        "id": "master-001",
        "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "algorithm": "AES256",
        "status": "active",
        "rotation_due": "$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)"
    },
    "data_key": {
        "id": "data-001",
        "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "algorithm": "AES256-GCM",
        "status": "active",
        "rotation_due": "$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)"
    },
    "auth_key": {
        "id": "auth-001",
        "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "algorithm": "AES256",
        "status": "active",
        "rotation_due": "$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)"
    }
}
EOF

# Create Python key management module
echo "Creating Python key management module..."

cat > "$KMS_DIR/key_manager.py" << 'EOF'
#!/usr/bin/env python3

import os
import json
import base64
import hashlib
import secrets
from datetime import datetime, timedelta
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
import logging

class KeyManager:
    def __init__(self, config_path):
        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.kms_dir = os.path.dirname(config_path)
        self.local_keys_dir = self.config['key_providers']['local']['key_store']
        self.audit_log = self.config['audit']['log_file']

        # Set up logging
        logging.basicConfig(
            filename=self.audit_log,
            level=getattr(logging, self.config['audit']['log_level']),
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def _audit_log(self, action, key_id=None, details=None):
        """Log key management actions for audit purposes"""
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'action': action,
            'key_id': key_id,
            'details': details or {}
        }
        self.logger.info(json.dumps(log_entry))

    def generate_key(self, key_type='data', algorithm='AES256', key_size=256):
        """Generate a new encryption key"""
        if algorithm == 'AES256':
            key = secrets.token_bytes(key_size // 8)
        elif algorithm == 'ChaCha20':
            key = secrets.token_bytes(32)
        else:
            raise ValueError(f"Unsupported algorithm: {algorithm}")

        key_id = f"{key_type}-{secrets.token_hex(4)}"
        key_file = os.path.join(self.local_keys_dir, f"{key_id}.key")

        # Encrypt key with master key before storing
        master_key = self._load_master_key()
        encrypted_key = self._encrypt_with_key(key, master_key)

        with open(key_file, 'wb') as f:
            f.write(encrypted_key)

        os.chmod(key_file, 0o600)

        # Update metadata
        self._update_key_metadata(key_id, algorithm, 'active')

        self._audit_log('key_generated', key_id, {'algorithm': algorithm, 'key_size': key_size})

        return key_id

    def _load_master_key(self):
        """Load the master encryption key"""
        master_key_file = os.path.join(self.local_keys_dir, 'master.key')
        with open(master_key_file, 'rb') as f:
            return f.read()

    def _encrypt_with_key(self, data, key):
        """Encrypt data with the provided key using AES-GCM"""
        # Generate a random nonce
        nonce = secrets.token_bytes(12)

        # Create cipher
        cipher = Cipher(algorithms.AES(key), modes.GCM(nonce), backend=default_backend())
        encryptor = cipher.encryptor()

        # Encrypt the data
        ciphertext = encryptor.update(data) + encryptor.finalize()

        # Return nonce + tag + ciphertext
        return nonce + encryptor.tag + ciphertext

    def _decrypt_with_key(self, encrypted_data, key):
        """Decrypt data with the provided key using AES-GCM"""
        nonce = encrypted_data[:12]
        tag = encrypted_data[12:28]
        ciphertext = encrypted_data[28:]

        # Create cipher
        cipher = Cipher(algorithms.AES(key), modes.GCM(nonce, tag), backend=default_backend())
        decryptor = cipher.decryptor()

        # Decrypt the data
        return decryptor.update(ciphertext) + decryptor.finalize()

    def get_key(self, key_id):
        """Retrieve and decrypt a key"""
        key_file = os.path.join(self.local_keys_dir, f"{key_id}.key")

        if not os.path.exists(key_file):
            raise FileNotFoundError(f"Key not found: {key_id}")

        with open(key_file, 'rb') as f:
            encrypted_key = f.read()

        master_key = self._load_master_key()
        decrypted_key = self._decrypt_with_key(encrypted_key, master_key)

        self._audit_log('key_accessed', key_id)

        return decrypted_key

    def rotate_key(self, key_id):
        """Rotate an existing key"""
        # Generate new key
        old_key = self.get_key(key_id)
        new_key_id = self.generate_key(key_id.split('-')[0])

        # Mark old key as rotated
        self._update_key_metadata(key_id, status='rotated', rotated_to=new_key_id)

        self._audit_log('key_rotated', key_id, {'new_key_id': new_key_id})

        return new_key_id

    def _update_key_metadata(self, key_id, algorithm=None, status=None, rotated_to=None):
        """Update key metadata"""
        metadata_file = os.path.join(self.local_keys_dir, 'metadata.json')

        if os.path.exists(metadata_file):
            with open(metadata_file, 'r') as f:
                metadata = json.load(f)
        else:
            metadata = {}

        if key_id not in metadata:
            metadata[key_id] = {}

        if algorithm:
            metadata[key_id]['algorithm'] = algorithm
        if status:
            metadata[key_id]['status'] = status
        if rotated_to:
            metadata[key_id]['rotated_to'] = rotated_to

        metadata[key_id]['updated'] = datetime.utcnow().isoformat()

        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

    def list_keys(self):
        """List all keys and their status"""
        metadata_file = os.path.join(self.local_keys_dir, 'metadata.json')

        if os.path.exists(metadata_file):
            with open(metadata_file, 'r') as f:
                return json.load(f)
        else:
            return {}

    def derive_key(self, password, salt=None, iterations=None):
        """Derive a key from a password using PBKDF2"""
        if salt is None:
            salt = secrets.token_bytes(16)
        if iterations is None:
            iterations = self.config['encryption']['iterations']

        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=iterations,
            backend=default_backend()
        )

        return kdf.derive(password.encode()), salt

# CLI interface
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 3:
        print("Usage: python key_manager.py <config_path> <command> [args...]")
        sys.exit(1)

    config_path = sys.argv[1]
    command = sys.argv[2]

    km = KeyManager(config_path)

    if command == 'generate':
        key_type = sys.argv[3] if len(sys.argv) > 3 else 'data'
        key_id = km.generate_key(key_type)
        print(f"Generated key: {key_id}")

    elif command == 'get':
        key_id = sys.argv[3]
        key = km.get_key(key_id)
        print(f"Key {key_id}: {key.hex()}")

    elif command == 'rotate':
        key_id = sys.argv[3]
        new_key_id = km.rotate_key(key_id)
        print(f"Rotated key {key_id} to {new_key_id}")

    elif command == 'list':
        keys = km.list_keys()
        print(json.dumps(keys, indent=2))

    else:
        print(f"Unknown command: {command}")
EOF

sudo chmod +x "$KMS_DIR/key_manager.py"

# Create key rotation script
echo "Creating key rotation script..."

cat > "$KMS_DIR/rotate-keys.sh" << 'EOF'
#!/bin/bash

# Key rotation script
KMS_DIR="/opt/gravitypm/kms"
LOG_FILE="/var/log/gravitypm/key-rotation.log"
BACKUP_DIR="/opt/backup/gravitypm/production"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

rotate_keys() {
    log "Starting key rotation process..."

    # Backup current keys
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    sudo mkdir -p "$BACKUP_DIR/keys"
    sudo tar -czf "$BACKUP_DIR/keys/key_backup_$TIMESTAMP.tar.gz" -C "$KMS_DIR" .

    # Rotate keys using Python script
    python3 "$KMS_DIR/key_manager.py" "$KMS_DIR/kms-config.json" rotate master-001
    python3 "$KMS_DIR/key_manager.py" "$KMS_DIR/kms-config.json" rotate data-001
    python3 "$KMS_DIR/key_manager.py" "$KMS_DIR/kms-config.json" rotate auth-001

    # Update application configuration
    log "Updating application configuration with new keys..."

    # This would typically involve updating environment variables
    # and potentially re-encrypting application data

    log "Key rotation completed successfully"
}

rotate_keys
EOF

sudo chmod +x "$KMS_DIR/rotate-keys.sh"

# Set up automated key rotation (quarterly)
sudo crontab -l | { cat; echo "0 2 1 */3 * $KMS_DIR/rotate-keys.sh"; } | sudo crontab -

# Create key monitoring script
echo "Creating key monitoring script..."

cat > "$KMS_DIR/monitor-keys.sh" << 'EOF'
#!/bin/bash

# Key monitoring script
KMS_DIR="/opt/gravitypm/kms"
LOG_FILE="/var/log/gravitypm/key-monitor.log"
ALERT_EMAIL="security@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_key_expiry() {
    local metadata_file="$KMS_DIR/local-keys/metadata.json"
    local warning_days=30

    if [ -f "$metadata_file" ]; then
        # Check for keys due for rotation
        python3 -c "
import json
import sys
from datetime import datetime, timedelta

with open('$metadata_file', 'r') as f:
    metadata = json.load(f)

current_time = datetime.utcnow()
warning_time = current_time + timedelta(days=$warning_days)

for key_id, key_info in metadata.items():
    if 'rotation_due' in key_info:
        rotation_due = datetime.fromisoformat(key_info['rotation_due'].replace('Z', '+00:00'))
        if rotation_due <= current_time:
            print(f'EXPIRED:{key_id}')
        elif rotation_due <= warning_time:
            days_left = (rotation_due - current_time).days
            print(f'WARNING:{key_id}:{days_left}')
        else:
            print(f'OK:{key_id}')
    else:
        print(f'UNKNOWN:{key_id}')
" | while read -r status; do
            case "$status" in
                EXPIRED:*)
                    key_id="${status#EXPIRED:}"
                    log "CRITICAL: Key rotation overdue: $key_id"
                    echo "CRITICAL: Key rotation overdue: $key_id" | mail -s "Key Rotation Alert" "$ALERT_EMAIL"
                    ;;
                WARNING:*)
                    key_id="${status#WARNING:}"
                    days="${status##*:}"
                    log "WARNING: Key rotation due in $days days: $key_id"
                    echo "WARNING: Key rotation due in $days days: $key_id" | mail -s "Key Rotation Warning" "$ALERT_EMAIL"
                    ;;
            esac
        done
    fi
}

check_key_files() {
    local key_files=$(find "$KMS_DIR/local-keys" -name "*.key" -type f)

    for key_file in $key_files; do
        if [ ! -f "$key_file" ]; then
            log "ERROR: Key file missing: $key_file"
            echo "ERROR: Key file missing: $key_file" | mail -s "Key File Alert" "$ALERT_EMAIL"
            continue
        fi

        # Check permissions
        local perms=$(stat -c %a "$key_file")
        if [ "$perms" != "600" ]; then
            log "WARNING: Incorrect permissions on $key_file: $perms"
            echo "WARNING: Incorrect permissions on key file: $key_file" | mail -s "Key Permission Warning" "$ALERT_EMAIL"
        fi
    done
}

log "Starting key monitoring..."

check_key_expiry
check_key_files

log "Key monitoring completed"
EOF

sudo chmod +x "$KMS_DIR/monitor-keys.sh"

# Set up key monitoring (daily)
sudo crontab -l | { cat; echo "0 7 * * * $KMS_DIR/monitor-keys.sh"; } | sudo crontab -

# Create key backup script
echo "Creating key backup script..."

cat > "$KMS_DIR/backup-keys.sh" << 'EOF'
#!/bin/bash

# Key backup script
KMS_DIR="/opt/gravitypm/kms"
BACKUP_DIR="/opt/backup/gravitypm/production/keys"
LOG_FILE="/var/log/gravitypm/key-backup.log"
ENCRYPTION_DIR="/opt/gravitypm/encryption"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

backup_keys() {
    log "Starting key backup..."

    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"

    # Create timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/key_backup_$TIMESTAMP.tar.gz"

    # Create backup archive
    sudo tar -czf "$BACKUP_FILE" -C "$KMS_DIR" .

    # Encrypt backup
    if [ -f "$ENCRYPTION_DIR/master.key" ]; then
        ENCRYPTED_FILE="$BACKUP_FILE.enc"
        sudo openssl enc -aes-256-cbc -salt -in "$BACKUP_FILE" \
            -out "$ENCRYPTED_FILE" -pass file:"$ENCRYPTION_DIR/master.key"
        sudo rm "$BACKUP_FILE"
        BACKUP_FILE="$ENCRYPTED_FILE"
    fi

    # Set permissions
    sudo chmod 600 "$BACKUP_FILE"

    # Clean up old backups (keep last 10)
    sudo find "$BACKUP_DIR" -name "key_backup_*.tar.gz*" -type f \
        -printf '%T@ %p\n' | sort -n | head -n -10 | cut -d' ' -f2- | xargs -r sudo rm

    log "Key backup completed: $BACKUP_FILE"
}

backup_keys
EOF

sudo chmod +x "$KMS_DIR/backup-keys.sh"

# Set up key backup (daily)
sudo crontab -l | { cat; echo "0 1 * * * $KMS_DIR/backup-keys.sh"; } | sudo crontab -

# Update environment configuration
echo "Updating environment configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# Key Management Configuration
KMS_ENABLED=true
KMS_CONFIG_PATH=$KMS_DIR/kms-config.json
MASTER_KEY_ID=master-001
DATA_KEY_ID=data-001
AUTH_KEY_ID=auth-001

# Key rotation settings
KEY_ROTATION_ENABLED=true
KEY_ROTATION_INTERVAL_DAYS=90
KEY_BACKUP_ENABLED=true
EOF

# Test key management
echo "Testing key management..."

# Generate test keys
python3 "$KMS_DIR/key_manager.py" "$KMS_DIR/kms-config.json" generate data
python3 "$KMS_DIR/key_manager.py" "$KMS_DIR/kms-config.json" list

echo "Secure key management setup completed!"
echo "KMS directory: $KMS_DIR"
echo "Configuration: $KMS_DIR/kms-config.json"
echo "Local keys: $LOCAL_KEYS_DIR"
echo ""
echo "Next steps:"
echo "1. Test key generation and retrieval"
echo "2. Configure application to use KMS"
echo "3. Set up cloud KMS integration (AWS/Azure/GCP)"
echo "4. Test key rotation procedures"
echo "5. Configure key backup and recovery"
echo "6. Set up key monitoring and alerting"
echo "7. Implement key usage auditing"
echo "8. Test disaster recovery with key restoration"
