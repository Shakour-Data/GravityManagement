#!/bin/bash

# SSL Certificate Renewal Script for GravityPM
# This script assumes Let's Encrypt with Certbot

DOMAIN="yourdomain.com"
EMAIL="admin@yourdomain.com"

# Install Certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    sudo apt update
    sudo apt install -y certbot
fi

# Renew certificate
echo "Renewing SSL certificate for $DOMAIN..."
sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive

# Reload nginx
if [ $? -eq 0 ]; then
    echo "Certificate renewed successfully. Reloading nginx..."
    sudo nginx -t
    if [ $? -eq 0 ]; then
        sudo nginx -s reload
        echo "Nginx reloaded successfully."
    else
        echo "Nginx configuration test failed!"
        exit 1
    fi
else
    echo "Certificate renewal failed!"
    exit 1
fi

echo "SSL renewal process completed."
