#!/bin/bash

# Redis Cloud Setup Script for GravityPM
# This script helps set up Redis Cloud for production use

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"

echo "Setting up Redis Cloud for ${ENVIRONMENT} environment..."

# Check if Redis CLI is installed
if ! command -v redis-cli &> /dev/null; then
    echo "Redis CLI is not installed. Please install Redis first."
    exit 1
fi

# Redis Cloud configuration
REDIS_PLAN="cache-500"  # 500MB cache plan
REDIS_REGION="us-east-1"

echo "Please provide your Redis Cloud credentials:"
read -p "Redis Cloud API Key: " REDIS_API_KEY
read -p "Redis Cloud API Secret: " REDIS_API_SECRET

# Create Redis Cloud subscription
echo "Creating Redis Cloud subscription..."

SUBSCRIPTION_RESPONSE=$(curl -s -X POST \
    "https://api.redislabs.com/v1/subscriptions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $REDIS_API_KEY" \
    -H "x-api-secret: $REDIS_API_SECRET" \
    -d "{
        \"name\": \"${PROJECT_NAME}-${ENVIRONMENT}\",
        \"provider\": \"AWS\",
        \"region\": \"$REDIS_REGION\",
        \"deploymentType\": \"single-region\",
        \"memoryStorage\": \"ram\",
        \"dataPersistence\": \"aof-every-1-second\",
        \"replication\": true,
        \"throughputMeasurement\": {
            \"by\": \"operations-per-second\",
            \"value\": 10000
        },
        \"averageItemSizeInBytes\": 1000,
        \"modules\": []
    }")

SUBSCRIPTION_ID=$(echo "$SUBSCRIPTION_RESPONSE" | jq -r '.id')

if [ "$SUBSCRIPTION_ID" = "null" ]; then
    echo "Failed to create Redis Cloud subscription"
    echo "Response: $SUBSCRIPTION_RESPONSE"
    exit 1
fi

echo "Subscription created with ID: $SUBSCRIPTION_ID"

# Wait for subscription to be ready
echo "Waiting for Redis Cloud subscription to be ready..."
sleep 300

# Get database endpoints
echo "Getting Redis Cloud database endpoints..."

DATABASES_RESPONSE=$(curl -s \
    "https://api.redislabs.com/v1/subscriptions/$SUBSCRIPTION_ID/databases" \
    -H "x-api-key: $REDIS_API_KEY" \
    -H "x-api-secret: $REDIS_API_SECRET")

REDIS_ENDPOINT=$(echo "$DATABASES_RESPONSE" | jq -r '.[0].endpoints[0].dns_name')
REDIS_PORT=$(echo "$DATABASES_RESPONSE" | jq -r '.[0].endpoints[0].port')
REDIS_PASSWORD=$(echo "$DATABASES_RESPONSE" | jq -r '.[0].password')

# Test connection
echo "Testing Redis Cloud connection..."
redis-cli -h "$REDIS_ENDPOINT" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" ping

if [ $? -eq 0 ]; then
    echo "Redis Cloud connection successful!"
else
    echo "Failed to connect to Redis Cloud"
    exit 1
fi

# Configure Redis settings
echo "Configuring Redis settings..."

# Enable clustering if needed
curl -X PUT \
    "https://api.redislabs.com/v1/subscriptions/$SUBSCRIPTION_ID/databases/1" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $REDIS_API_KEY" \
    -H "x-api-secret: $REDIS_API_SECRET" \
    -d "{
        \"replication\": true,
        \"dataPersistence\": \"aof-every-1-second\",
        \"backup\": true,
        \"backupInterval\": 3600,
        \"backupRetention\": 7
    }"

# Set up monitoring
echo "Setting up Redis Cloud monitoring..."

# Create monitoring configuration
cat > redis-cloud-monitoring.json << EOF
{
    "subscriptionId": "$SUBSCRIPTION_ID",
    "alerts": [
        {
            "type": "dataset-size",
            "value": 80,
            "unit": "percent"
        },
        {
            "type": "connections-limit",
            "value": 90,
            "unit": "percent"
        },
        {
            "type": "latency",
            "value": 100,
            "unit": "milliseconds"
        }
    ],
    "integrations": {
        "datadog": {
            "enabled": true,
            "apiKey": "$DATADOG_API_KEY"
        }
    }
}
EOF

# Create backup configuration
echo "Setting up Redis Cloud backup configuration..."

cat > redis-cloud-backup-config.json << EOF
{
    "subscriptionId": "$SUBSCRIPTION_ID",
    "backup": {
        "enabled": true,
        "interval": 3600,
        "retention": 7,
        "location": "AWS_S3",
        "bucket": "${PROJECT_NAME}-${ENVIRONMENT}-redis-backups"
    }
}
EOF

# Save configuration to environment file
echo "Saving Redis Cloud configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# Redis Cloud Configuration
REDIS_ENDPOINT=$REDIS_ENDPOINT
REDIS_PORT=$REDIS_PORT
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_URL=redis://:$REDIS_PASSWORD@$REDIS_ENDPOINT:$REDIS_PORT
REDIS_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF

echo "Redis Cloud setup completed!"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Redis Endpoint: $REDIS_ENDPOINT:$REDIS_PORT"
echo ""
echo "Next steps:"
echo "1. Update your application configuration with the Redis URL"
echo "2. Set up monitoring and alerting"
echo "3. Configure backup retention policies"
echo "4. Test Redis operations in your application"
echo "5. Set up Redis cluster if high availability is needed"
