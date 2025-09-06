#!/bin/bash

# MongoDB Replica Set Setup Script
# This script initializes the MongoDB replica set after containers are running

echo "Setting up MongoDB Replica Set..."

# Wait for MongoDB containers to be ready
echo "Waiting for MongoDB containers to start..."
sleep 30

# Connect to primary and initiate replica set
echo "Initiating replica set..."
docker exec gravitypm-mongodb-primary mongo --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    {_id: 0, host: 'mongodb-primary:27017', priority: 2},
    {_id: 1, host: 'mongodb-secondary:27017', priority: 1},
    {_id: 2, host: 'mongodb-arbiter:27017', arbiterOnly: true}
  ]
})
"

# Wait for replica set to be ready
echo "Waiting for replica set to initialize..."
sleep 10

# Check replica set status
echo "Checking replica set status..."
docker exec gravitypm-mongodb-primary mongo --eval "rs.status()"

# Create application database and user
echo "Creating application database and user..."
docker exec gravitypm-mongodb-primary mongo gravitypm --eval "
db.createUser({
  user: 'gravitypm_user',
  pwd: 'gravitypm_password',
  roles: ['readWrite']
})
"

echo "MongoDB Replica Set setup completed successfully!"
echo "Primary: mongodb-primary:27017"
echo "Secondary: mongodb-secondary:27017"
echo "Arbiter: mongodb-arbiter:27017"
