#!/bin/bash

# Deployment Script for GravityPM
# Usage: ./deploy.sh [staging|production]

ENVIRONMENT=${1:-staging}

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "Usage: $0 [staging|production]"
    exit 1
fi

echo "Deploying to $ENVIRONMENT environment..."

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    export $(cat .env.$ENVIRONMENT | xargs)
else
    echo "Environment file .env.$ENVIRONMENT not found!"
    exit 1
fi

# Pull latest changes
echo "Pulling latest changes..."
git pull origin main

# Build and deploy with docker-compose
COMPOSE_FILE="docker-compose.$ENVIRONMENT.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Compose file $COMPOSE_FILE not found!"
    exit 1
fi

echo "Stopping existing containers..."
docker-compose -f $COMPOSE_FILE down

echo "Building and starting containers..."
docker-compose -f $COMPOSE_FILE up -d --build

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Run health checks
echo "Running health checks..."
curl -f http://localhost:3000 || echo "Frontend health check failed"
curl -f http://localhost:8000/docs || echo "Backend health check failed"

echo "Deployment to $ENVIRONMENT completed!"
