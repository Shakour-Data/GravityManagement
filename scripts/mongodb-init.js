// MongoDB Replica Set Initialization Script
// This script runs when the primary MongoDB container starts

const config = {
  "_id": "rs0",
  "version": 1,
  "members": [
    {
      "_id": 0,
      "host": "mongodb-primary:27017",
      "priority": 2
    },
    {
      "_id": 1,
      "host": "mongodb-secondary:27017",
      "priority": 1
    },
    {
      "_id": 2,
      "host": "mongodb-arbiter:27017",
      "arbiterOnly": true
    }
  ]
};

try {
  rs.initiate(config);
  print("Replica set initiated successfully");
} catch (e) {
  print("Error initiating replica set:", e);
}

// Wait for replica set to be ready
while (!rs.isMaster().ismaster) {
  sleep(1000);
}

print("Replica set is ready and primary is elected");

// Create application database and user
db = db.getSiblingDB('gravitypm');

// Create application user with read/write permissions
db.createUser({
  user: process.env.MONGO_APP_USERNAME || 'gravitypm_user',
  pwd: process.env.MONGO_APP_PASSWORD || 'gravitypm_password',
  roles: [
    {
      role: 'readWrite',
      db: 'gravitypm'
    }
  ]
});

print("Application user created successfully");
