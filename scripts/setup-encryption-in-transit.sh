#!/bin/bash

# Encryption in Transit Setup Script for GravityPM
# This script sets up TLS/SSL encryption for all data in transit

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
DOMAIN="${2:-gravitypm.com}"
SSL_DIR="/opt/${PROJECT_NAME}/ssl"

echo "Setting up encryption in transit for ${ENVIRONMENT} environment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx openssl

# Create SSL directory structure
sudo mkdir -p "$SSL_DIR"
sudo chmod 700 "$SSL_DIR"

# Generate self-signed certificates for development/testing
echo "Generating self-signed certificates..."

# Root CA
sudo openssl genrsa -out "$SSL_DIR/ca.key" 4096
sudo openssl req -x509 -new -nodes -key "$SSL_DIR/ca.key" -sha256 -days 3650 \
    -out "$SSL_DIR/ca.crt" \
    -subj "/C=US/ST=State/L=City/O=${PROJECT_NAME}/CN=${PROJECT_NAME} Root CA"

# Server certificate
sudo openssl genrsa -out "$SSL_DIR/server.key" 2048
sudo openssl req -new -key "$SSL_DIR/server.key" \
    -out "$SSL_DIR/server.csr" \
    -subj "/C=US/ST=State/L=City/O=${PROJECT_NAME}/CN=*.${DOMAIN}"

# Sign server certificate
cat > "$SSL_DIR/server.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

sudo openssl x509 -req -in "$SSL_DIR/server.csr" \
    -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
    -CAcreateserial -out "$SSL_DIR/server.crt" \
    -days 365 -sha256 -extfile "$SSL_DIR/server.ext"

# Generate client certificates for API authentication
echo "Generating client certificates..."

# Client certificate
sudo openssl genrsa -out "$SSL_DIR/client.key" 2048
sudo openssl req -new -key "$SSL_DIR/client.key" \
    -out "$SSL_DIR/client.csr" \
    -subj "/C=US/ST=State/L=City/O=${PROJECT_NAME}/CN=client.${DOMAIN}"

cat > "$SSL_DIR/client.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = client.${DOMAIN}
EOF

sudo openssl x509 -req -in "$SSL_DIR/client.csr" \
    -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
    -CAcreateserial -out "$SSL_DIR/client.crt" \
    -days 365 -sha256 -extfile "$SSL_DIR/client.ext"

# Set proper permissions
sudo chmod 600 "$SSL_DIR"/*.key
sudo chmod 644 "$SSL_DIR"/*.crt

# Create certificate validation script
echo "Creating certificate validation script..."

cat > "$SSL_DIR/validate-certificates.sh" << 'EOF'
#!/bin/bash

# Certificate validation script
SSL_DIR="/opt/gravitypm/ssl"
LOG_FILE="/var/log/gravitypm/ssl-validation.log"
ALERT_EMAIL="security@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_certificate_expiry() {
    local cert_file="$1"
    local cert_name="$2"
    local warning_days=30

    if [ -f "$cert_file" ]; then
        local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( ($expiry_epoch - $current_epoch) / 86400 ))

        if [ $days_until_expiry -le 0 ]; then
            log "CRITICAL: $cert_name certificate has expired"
            echo "CRITICAL: SSL Certificate expired: $cert_name" | mail -s "SSL Certificate Alert" "$ALERT_EMAIL"
        elif [ $days_until_expiry -le $warning_days ]; then
            log "WARNING: $cert_name certificate expires in $days_until_expiry days"
            echo "WARNING: SSL Certificate expires soon: $cert_name ($days_until_expiry days)" | mail -s "SSL Certificate Warning" "$ALERT_EMAIL"
        else
            log "OK: $cert_name certificate is valid for $days_until_expiry days"
        fi
    else
        log "ERROR: Certificate file not found: $cert_file"
        echo "ERROR: SSL Certificate missing: $cert_file" | mail -s "SSL Certificate Error" "$ALERT_EMAIL"
    fi
}

log "Starting SSL certificate validation..."

check_certificate_expiry "$SSL_DIR/server.crt" "Server"
check_certificate_expiry "$SSL_DIR/client.crt" "Client"
check_certificate_expiry "$SSL_DIR/ca.crt" "CA"

log "SSL certificate validation completed"
EOF

sudo chmod +x "$SSL_DIR/validate-certificates.sh"

# Set up certificate monitoring
sudo crontab -l | { cat; echo "0 8 * * * $SSL_DIR/validate-certificates.sh"; } | sudo crontab -

# Configure Nginx for SSL/TLS
echo "Configuring Nginx for SSL/TLS..."

# Update nginx configuration with enhanced SSL settings
cat >> nginx.conf << 'EOF'

# Enhanced SSL/TLS configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# HSTS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# SSL Certificate paths
ssl_certificate /opt/gravitypm/ssl/server.crt;
ssl_certificate_key /opt/gravitypm/ssl/server.key;
ssl_trusted_certificate /opt/gravitypm/ssl/ca.crt;
EOF

# Create MongoDB SSL configuration
echo "Creating MongoDB SSL configuration..."

cat > "$SSL_DIR/mongodb-ssl.conf" << EOF
# MongoDB SSL/TLS Configuration
net:
  tls:
    mode: requireTLS
    certificateKeyFile: /opt/gravitypm/ssl/server.pem
    CAFile: /opt/gravitypm/ssl/ca.crt
    allowInvalidCertificates: false
    allowInvalidHostnames: false

security:
  clusterAuthMode: x509
  authorization: enabled
EOF

# Combine server certificate and key for MongoDB
sudo cat "$SSL_DIR/server.crt" "$SSL_DIR/server.key" > "$SSL_DIR/server.pem"
sudo chmod 600 "$SSL_DIR/server.pem"

# Create Redis SSL configuration
echo "Creating Redis SSL configuration..."

cat > "$SSL_DIR/redis-ssl.conf" << EOF
# Redis SSL/TLS Configuration
tls-port 6380
tls-cert-file /opt/gravitypm/ssl/server.crt
tls-key-file /opt/gravitypm/ssl/server.key
tls-ca-cert-file /opt/gravitypm/ssl/ca.crt
tls-auth-clients optional
tls-replication yes
EOF

# Create certificate renewal script
echo "Creating certificate renewal script..."

cat > "$SSL_DIR/renew-certificates.sh" << 'EOF'
#!/bin/bash

# Certificate renewal script
SSL_DIR="/opt/gravitypm/ssl"
DOMAIN="gravitypm.com"
LOG_FILE="/var/log/gravitypm/ssl-renewal.log"
BACKUP_DIR="/opt/backup/gravitypm/production/ssl"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

backup_certificates() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/ssl_backup_$timestamp.tar.gz"

    log "Backing up current certificates..."

    sudo mkdir -p "$BACKUP_DIR"
    sudo tar -czf "$backup_file" -C "$SSL_DIR" .
    sudo chmod 600 "$backup_file"

    log "Certificates backed up to: $backup_file"
}

renew_letsencrypt() {
    log "Attempting Let's Encrypt certificate renewal..."

    if certbot renew --quiet; then
        log "Let's Encrypt certificates renewed successfully"
        sudo systemctl reload nginx
        return 0
    else
        log "Let's Encrypt renewal failed"
        return 1
    fi
}

renew_self_signed() {
    log "Renewing self-signed certificates..."

    # Backup current certificates
    backup_certificates

    # Generate new certificates
    sudo openssl req -x509 -newkey rsa:4096 -keyout "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=GravityPM/CN=*.gravitypm.com"

    # Update combined PEM file
    sudo cat "$SSL_DIR/server.crt" "$SSL_DIR/server.key" > "$SSL_DIR/server.pem"
    sudo chmod 600 "$SSL_DIR/server.pem"

    # Reload services
    sudo systemctl reload nginx
    sudo systemctl restart mongod
    sudo systemctl restart redis-server

    log "Self-signed certificates renewed"
}

log "Starting certificate renewal process..."

# Try Let's Encrypt first, fallback to self-signed
if ! renew_letsencrypt; then
    log "Falling back to self-signed certificate renewal..."
    renew_self_signed
fi

log "Certificate renewal process completed"
EOF

sudo chmod +x "$SSL_DIR/renew-certificates.sh"

# Set up certificate renewal (weekly)
sudo crontab -l | { cat; echo "0 3 * * 1 $SSL_DIR/renew-certificates.sh"; } | sudo crontab -

# Create SSL/TLS monitoring script
echo "Creating SSL/TLS monitoring script..."

cat > "$SSL_DIR/monitor-ssl.sh" << 'EOF'
#!/bin/bash

# SSL/TLS monitoring script
SSL_DIR="/opt/gravitypm/ssl"
LOG_FILE="/var/log/gravitypm/ssl-monitor.log"
ALERT_EMAIL="security@gravitypm.com"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

test_ssl_connection() {
    local host="$1"
    local port="$2"
    local service="$3"

    log "Testing SSL connection to $service ($host:$port)..."

    if echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -dates >/dev/null 2>&1; then
        log "OK: SSL connection to $service successful"
    else
        log "ERROR: SSL connection to $service failed"
        echo "ERROR: SSL connection failed: $service" | mail -s "SSL Connection Alert" "$ALERT_EMAIL"
    fi
}

check_ssl_configuration() {
    log "Checking SSL configuration..."

    # Test local services
    test_ssl_connection "localhost" "443" "Nginx"
    test_ssl_connection "localhost" "27017" "MongoDB"
    test_ssl_connection "localhost" "6380" "Redis"

    # Check SSL protocols
    local ssl_protocols=$(openssl ciphers -v | grep -E "(TLSv1\.2|TLSv1\.3)" | wc -l)
    if [ "$ssl_protocols" -lt 2 ]; then
        log "WARNING: Limited SSL protocol support"
        echo "WARNING: Limited SSL protocol support detected" | mail -s "SSL Configuration Warning" "$ALERT_EMAIL"
    fi
}

log "Starting SSL/TLS monitoring..."

check_ssl_configuration

log "SSL/TLS monitoring completed"
EOF

sudo chmod +x "$SSL_DIR/monitor-ssl.sh"

# Set up SSL monitoring (every 6 hours)
sudo crontab -l | { cat; echo "0 */6 * * * $SSL_DIR/monitor-ssl.sh"; } | sudo crontab -

# Update environment configuration
echo "Updating environment configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# SSL/TLS Configuration
SSL_ENABLED=true
SSL_CERT_PATH=$SSL_DIR/server.crt
SSL_KEY_PATH=$SSL_DIR/server.key
SSL_CA_PATH=$SSL_DIR/ca.crt
CLIENT_CERT_PATH=$SSL_DIR/client.crt
CLIENT_KEY_PATH=$SSL_DIR/client.key

# MongoDB SSL
MONGODB_SSL=true
MONGODB_SSL_CA_CERTS=$SSL_DIR/ca.crt
MONGODB_SSL_CERTFILE=$SSL_DIR/client.crt
MONGODB_SSL_KEYFILE=$SSL_DIR/client.key

# Redis SSL
REDIS_SSL=true
REDIS_SSL_CERTFILE=$SSL_DIR/client.crt
REDIS_SSL_KEYFILE=$SSL_DIR/client.key
REDIS_SSL_CA_CERTS=$SSL_DIR/ca.crt
EOF

# Create SSL hardening script
echo "Creating SSL hardening script..."

cat > "$SSL_DIR/harden-ssl.sh" << 'EOF'
#!/bin/bash

# SSL hardening script
SSL_DIR="/opt/gravitypm/ssl"
LOG_FILE="/var/log/gravitypm/ssl-harden.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

harden_ssl_config() {
    log "Applying SSL hardening configurations..."

    # Generate stronger DH parameters
    if [ ! -f "$SSL_DIR/dhparam.pem" ]; then
        log "Generating DH parameters..."
        sudo openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    fi

    # Update nginx configuration with hardening
    sudo sed -i 's|ssl_ciphers.*|ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA;|g' /etc/nginx/nginx.conf

    # Add security headers
    sudo sed -i '/add_header Strict-Transport-Security/a add_header X-Frame-Options "SAMEORIGIN" always;' /etc/nginx/nginx.conf
    sudo sed -i '/add_header X-Frame-Options/a add_header X-Content-Type-Options "nosniff" always;' /etc/nginx/nginx.conf
    sudo sed -i '/add_header X-Content-Type-Options/a add_header X-XSS-Protection "1; mode=block" always;' /etc/nginx/nginx.conf

    # Reload nginx
    sudo systemctl reload nginx

    log "SSL hardening completed"
}

harden_ssl_config
EOF

sudo chmod +x "$SSL_DIR/harden-ssl.sh"

# Run SSL hardening
echo "Running SSL hardening..."
sudo "$SSL_DIR/harden-ssl.sh"

echo "Encryption in transit setup completed!"
echo "SSL directory: $SSL_DIR"
echo "Server certificate: $SSL_DIR/server.crt"
echo "Client certificate: $SSL_DIR/client.crt"
echo "CA certificate: $SSL_DIR/ca.crt"
echo ""
echo "Next steps:"
echo "1. Update application configurations to use SSL/TLS"
echo "2. Test SSL connections to all services"
echo "3. Configure client certificate authentication"
echo "4. Set up certificate auto-renewal with Let's Encrypt"
echo "5. Test SSL monitoring and alerting"
echo "6. Implement SSL/TLS best practices"
echo "7. Set up SSL certificate pinning (if required)"
