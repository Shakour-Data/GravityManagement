#!/bin/bash

# Data Encryption Setup Script for GravityPM
# This script sets up data encryption at rest and secure key management

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
KEY_VAULT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-vault"

echo "Setting up data encryption for ${ENVIRONMENT} environment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y gnupg2 openssl cryptsetup

# Create encryption keys directory
ENCRYPTION_DIR="/opt/${PROJECT_NAME}/encryption"
sudo mkdir -p "$ENCRYPTION_DIR"
sudo chmod 700 "$ENCRYPTION_DIR"

# Generate master encryption key
echo "Generating master encryption key..."
MASTER_KEY_FILE="$ENCRYPTION_DIR/master.key"
sudo openssl rand -hex 32 | sudo tee "$MASTER_KEY_FILE" > /dev/null
sudo chmod 600 "$MASTER_KEY_FILE"

# Generate database encryption key
echo "Generating database encryption key..."
DB_KEY_FILE="$ENCRYPTION_DIR/db.key"
sudo openssl rand -hex 32 | sudo tee "$DB_KEY_FILE" > /dev/null
sudo chmod 600 "$DB_KEY_FILE"

# Generate Redis encryption key
echo "Generating Redis encryption key..."
REDIS_KEY_FILE="$ENCRYPTION_DIR/redis.key"
sudo openssl rand -hex 32 | sudo tee "$REDIS_KEY_FILE" > /dev/null
sudo chmod 600 "$REDIS_KEY_FILE"

# Create encrypted backup directory
echo "Setting up encrypted backup directory..."
BACKUP_DIR="/opt/backup/${PROJECT_NAME}/${ENVIRONMENT}"
ENCRYPTED_BACKUP_DIR="$BACKUP_DIR/encrypted"

sudo mkdir -p "$ENCRYPTED_BACKUP_DIR"
sudo chmod 700 "$ENCRYPTED_BACKUP_DIR"

# Set up GPG key for backup encryption
echo "Setting up GPG key for backup encryption..."
GPG_KEY_NAME="${PROJECT_NAME}-backup-${ENVIRONMENT}"
GPG_KEY_EMAIL="backup@${PROJECT_NAME}.com"

# Generate GPG key
cat > gpg-key-config << EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: $GPG_KEY_NAME
Name-Email: $GPG_KEY_EMAIL
Expire-Date: 0
Passphrase: $GPG_PASSPHRASE
EOF

sudo gpg --batch --gen-key gpg-key-config
sudo rm gpg-key-config

# Export public key
sudo gpg --export --armor "$GPG_KEY_EMAIL" > "$ENCRYPTION_DIR/backup-public.key"
sudo chmod 644 "$ENCRYPTION_DIR/backup-public.key"

# Create encryption functions
echo "Creating encryption utility functions..."

cat > "$ENCRYPTION_DIR/encrypt.sh" << 'EOF'
#!/bin/bash

# Encryption utility functions

ENCRYPTION_DIR="/opt/gravitypm/encryption"
MASTER_KEY_FILE="$ENCRYPTION_DIR/master.key"
GPG_KEY_EMAIL="backup@gravitypm.com"

# Encrypt file with AES-256
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_file="${3:-$MASTER_KEY_FILE}"

    openssl enc -aes-256-cbc -salt -in "$input_file" -out "$output_file" -pass file:"$key_file"
}

# Decrypt file with AES-256
decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_file="${3:-$MASTER_KEY_FILE}"

    openssl enc -d -aes-256-cbc -in "$input_file" -out "$output_file" -pass file:"$key_file"
}

# Encrypt file with GPG
encrypt_file_gpg() {
    local input_file="$1"
    local output_file="$2"

    gpg --encrypt --recipient "$GPG_KEY_EMAIL" --output "$output_file" "$input_file"
}

# Decrypt file with GPG
decrypt_file_gpg() {
    local input_file="$1"
    local output_file="$2"

    gpg --decrypt --output "$output_file" "$input_file"
}

# Generate new encryption key
generate_key() {
    local key_file="$1"
    local key_length="${2:-32}"

    openssl rand -hex "$key_length" > "$key_file"
    chmod 600 "$key_file"
}
EOF

sudo chmod +x "$ENCRYPTION_DIR/encrypt.sh"

# Set up encrypted MongoDB configuration
echo "Setting up encrypted MongoDB configuration..."

# Create encrypted database configuration
cat > "$ENCRYPTION_DIR/mongodb-encryption.json" << EOF
{
    "encryption": {
        "keyVault": {
            "db": "encryption",
            "coll": "keys"
        },
        "keyVaultNamespace": "encryption.keys"
    },
    "schemaMap": {
        "gravitypm.*": {
            "properties": {
                "ssn": {
                    "encrypt": {
                        "keyId": "/key-id",
                        "bsonType": "string",
                        "algorithm": "AEAD_AES_256_CBC_HMAC_SHA_512-Deterministic"
                    }
                },
                "credit_card": {
                    "encrypt": {
                        "keyId": "/key-id",
                        "bsonType": "string",
                        "algorithm": "AEAD_AES_256_CBC_HMAC_SHA_512-Random"
                    }
                }
            }
        }
    }
}
EOF

# Set up Redis encryption (using Redis Enterprise features)
echo "Setting up Redis encryption configuration..."

cat > "$ENCRYPTION_DIR/redis-encryption.conf" << EOF
# Redis encryption configuration
requirepass $(cat "$REDIS_KEY_FILE")
masterauth $(cat "$REDIS_KEY_FILE")

# Enable TLS
tls-port 6380
tls-cert-file /opt/gravitypm/ssl/redis.crt
tls-key-file /opt/gravitypm/ssl/redis.key
tls-ca-cert-file /opt/gravitypm/ssl/ca.crt

# Encryption at rest
save 900 1
save 300 10
save 60 10000

# Data persistence with encryption
dbfilename dump.rdb
dir /var/lib/redis
EOF

# Create key rotation script
echo "Creating key rotation script..."

cat > "$ENCRYPTION_DIR/rotate-keys.sh" << 'EOF'
#!/bin/bash

# Key rotation script
ENCRYPTION_DIR="/opt/gravitypm/encryption"
BACKUP_DIR="/opt/backup/gravitypm/production"
LOG_FILE="/var/log/gravitypm/key-rotation.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting key rotation..."

# Backup current keys
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo cp "$ENCRYPTION_DIR/master.key" "$BACKUP_DIR/master.key.$TIMESTAMP"
sudo cp "$ENCRYPTION_DIR/db.key" "$BACKUP_DIR/db.key.$TIMESTAMP"
sudo cp "$ENCRYPTION_DIR/redis.key" "$BACKUP_DIR/redis.key.$TIMESTAMP"

# Generate new keys
sudo openssl rand -hex 32 > "$ENCRYPTION_DIR/master.key.new"
sudo openssl rand -hex 32 > "$ENCRYPTION_DIR/db.key.new"
sudo openssl rand -hex 32 > "$ENCRYPTION_DIR/redis.key.new"

# Update permissions
sudo chmod 600 "$ENCRYPTION_DIR"/*.key*

# Re-encrypt existing data with new keys
# Note: This would require application-specific logic to re-encrypt data

log "Key rotation completed. New keys generated."
log "Old keys backed up with timestamp: $TIMESTAMP"
EOF

sudo chmod +x "$ENCRYPTION_DIR/rotate-keys.sh"

# Set up automated key rotation (monthly)
echo "Setting up automated key rotation..."
sudo crontab -l | { cat; echo "0 2 1 * * $ENCRYPTION_DIR/rotate-keys.sh"; } | sudo crontab -

# Create encryption monitoring script
echo "Creating encryption monitoring script..."

cat > "$ENCRYPTION_DIR/monitor-encryption.sh" << 'EOF'
#!/bin/bash

# Encryption monitoring script
ENCRYPTION_DIR="/opt/gravitypm/encryption"
LOG_FILE="/var/log/gravitypm/encryption-monitor.log"
ALERT_EMAIL="security@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_key_files() {
    local key_files=("master.key" "db.key" "redis.key")

    for key_file in "${key_files[@]}"; do
        if [ ! -f "$ENCRYPTION_DIR/$key_file" ]; then
            log "ERROR: Encryption key file missing: $key_file"
            echo "ALERT: Encryption key file missing: $key_file" | mail -s "Encryption Alert" "$ALERT_EMAIL"
            return 1
        fi

        # Check file permissions
        local perms=$(stat -c %a "$ENCRYPTION_DIR/$key_file")
        if [ "$perms" != "600" ]; then
            log "WARNING: Incorrect permissions on $key_file: $perms"
            echo "WARNING: Incorrect permissions on encryption key file" | mail -s "Encryption Warning" "$ALERT_EMAIL"
        fi
    done
}

check_key_age() {
    local key_file="$1"
    local max_age_days=90

    if [ -f "$ENCRYPTION_DIR/$key_file" ]; then
        local key_age_days=$(( ($(date +%s) - $(stat -c %Y "$ENCRYPTION_DIR/$key_file")) / 86400 ))

        if [ $key_age_days -gt $max_age_days ]; then
            log "WARNING: $key_file is $key_age_days days old (max: $max_age_days)"
            echo "WARNING: Encryption key is old and should be rotated" | mail -s "Key Rotation Warning" "$ALERT_EMAIL"
        fi
    fi
}

log "Starting encryption monitoring..."

check_key_files
check_key_age "master.key"
check_key_age "db.key"
check_key_age "redis.key"

log "Encryption monitoring completed"
EOF

sudo chmod +x "$ENCRYPTION_DIR/monitor-encryption.sh"

# Set up daily monitoring
sudo crontab -l | { cat; echo "0 6 * * * $ENCRYPTION_DIR/monitor-encryption.sh"; } | sudo crontab -

# Update environment configuration
echo "Updating environment configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# Encryption Configuration
ENCRYPTION_ENABLED=true
MASTER_KEY_PATH=$MASTER_KEY_FILE
DB_ENCRYPTION_KEY_PATH=$DB_KEY_FILE
REDIS_ENCRYPTION_KEY_PATH=$REDIS_KEY_FILE
ENCRYPTION_DIR=$ENCRYPTION_DIR
GPG_KEY_EMAIL=$GPG_KEY_EMAIL

# Key rotation settings
KEY_ROTATION_ENABLED=true
KEY_MAX_AGE_DAYS=90
EOF

# Create backup encryption script
echo "Creating backup encryption script..."

cat > "$ENCRYPTION_DIR/encrypt-backup.sh" << 'EOF'
#!/bin/bash

# Backup encryption script
BACKUP_DIR="/opt/backup/gravitypm/production"
ENCRYPTION_DIR="/opt/gravitypm/encryption"
LOG_FILE="/var/log/gravitypm/backup-encryption.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

encrypt_backup() {
    local backup_file="$1"
    local encrypted_file="$backup_file.enc"

    log "Encrypting backup: $backup_file"

    if gpg --encrypt --recipient "backup@gravitypm.com" --output "$encrypted_file" "$backup_file"; then
        # Remove original unencrypted backup
        rm "$backup_file"
        log "Backup encrypted successfully: $encrypted_file"
    else
        log "ERROR: Failed to encrypt backup: $backup_file"
        return 1
    fi
}

# Find and encrypt recent backups
find "$BACKUP_DIR" -name "*.sql" -o -name "*.rdb" -o -name "*.tar.gz" | while read -r backup_file; do
    # Skip already encrypted files
    if [[ "$backup_file" != *.enc ]]; then
        encrypt_backup "$backup_file"
    fi
done

log "Backup encryption process completed"
EOF

sudo chmod +x "$ENCRYPTION_DIR/encrypt-backup.sh"

# Set up backup encryption in cron
sudo crontab -l | { cat; echo "30 2 * * * $ENCRYPTION_DIR/encrypt-backup.sh"; } | sudo crontab -

echo "Data encryption setup completed!"
echo "Encryption directory: $ENCRYPTION_DIR"
echo "Master key: $MASTER_KEY_FILE"
echo "Database key: $DB_KEY_FILE"
echo "Redis key: $REDIS_KEY_FILE"
echo ""
echo "Next steps:"
echo "1. Update application configuration to use encryption"
echo "2. Test encryption/decryption functions"
echo "3. Set up encrypted database connections"
echo "4. Configure Redis with TLS encryption"
echo "5. Test backup encryption and restoration"
echo "6. Set up key rotation procedures"
echo "7. Configure monitoring alerts"
