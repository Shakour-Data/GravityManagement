#!/bin/bash

# MongoDB Atlas Setup Script for GravityPM
# This script helps set up MongoDB Atlas cluster for production use

set -e

# Configuration
PROJECT_NAME="gravitypm"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
ENVIRONMENT="${1:-production}"

echo "Setting up MongoDB Atlas for ${ENVIRONMENT} environment..."

# Check if mongosh is installed
if ! command -v mongosh &> /dev/null; then
    echo "MongoDB Shell (mongosh) is not installed. Please install it first."
    echo "Visit: https://docs.mongodb.com/mongodb-shell/install/"
    exit 1
fi

# Check if Atlas CLI is installed
if ! command -v atlas &> /dev/null; then
    echo "MongoDB Atlas CLI is not installed. Installing..."
    # Install Atlas CLI (adjust for your OS)
    curl -LO https://fastdl.mongodb.org/mongocli/mongocli_linux_x86_64.tar.gz
    tar -xzf mongocli_linux_x86_64.tar.gz
    sudo mv mongocli /usr/local/bin/atlas
    rm mongocli_linux_x86_64.tar.gz
fi

# Login to Atlas (interactive)
echo "Please login to MongoDB Atlas:"
atlas auth login

# Create project
echo "Creating Atlas project..."
PROJECT_ID=$(atlas projects create "$PROJECT_NAME-$ENVIRONMENT" --output json | jq -r '.id')

# Create cluster
echo "Creating Atlas cluster..."
atlas clusters create "$CLUSTER_NAME" \
    --projectId "$PROJECT_ID" \
    --provider AWS \
    --region us-east-1 \
    --tier M10 \
    --members 3 \
    --diskSizeGB 10 \
    --backupEnabled \
    --output json

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
sleep 300

# Get connection string
CONNECTION_STRING=$(atlas clusters connectionString "$CLUSTER_NAME" --projectId "$PROJECT_ID")

# Create database user
echo "Creating database user..."
atlas dbusers create \
    --username gravitypm_user \
    --password "$(openssl rand -base64 32)" \
    --projectId "$PROJECT_ID" \
    --role readWrite@gravitypm_$ENVIRONMENT

# Enable MongoDB Atlas features
echo "Enabling Atlas features..."

# Enable backup
atlas backups schedules create \
    --clusterName "$CLUSTER_NAME" \
    --projectId "$PROJECT_ID" \
    --referenceHourOfDay 2 \
    --referenceMinuteOfHour 0 \
    --restoreWindowDays 7

# Configure network access
echo "Configuring network access..."
atlas accessLists create \
    --projectId "$PROJECT_ID" \
    --currentIp

# Create database
echo "Creating initial database..."
mongosh "$CONNECTION_STRING" --eval "
    use gravitypm_$ENVIRONMENT;
    db.createCollection('users');
    db.createCollection('projects');
    db.createCollection('tasks');
    db.createCollection('resources');
    db.createCollection('rules');
"

# Set up encryption at rest
echo "Setting up encryption at rest..."
atlas security encryptionAtRest enable \
    --projectId "$PROJECT_ID" \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/atlas-kms-role

# Configure monitoring
echo "Setting up monitoring integrations..."
atlas integrations create DATADOG \
    --projectId "$PROJECT_ID" \
    --apiKey "$DATADOG_API_KEY" \
    --region US

# Create backup configuration
echo "Creating backup configuration..."
cat > mongodb-atlas-backup-config.json << EOF
{
    "projectId": "$PROJECT_ID",
    "clusterName": "$CLUSTER_NAME",
    "backupSchedule": {
        "referenceHourOfDay": 2,
        "referenceMinuteOfHour": 0,
        "restoreWindowDays": 7
    },
    "retentionPolicy": {
        "unit": "days",
        "value": 30
    }
}
EOF

echo "MongoDB Atlas setup completed!"
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Connection String: $CONNECTION_STRING"
echo ""
echo "Next steps:"
echo "1. Update your .env file with the connection string"
echo "2. Configure your application to use the new Atlas cluster"
echo "3. Set up monitoring and alerting"
echo "4. Test the connection from your application"
