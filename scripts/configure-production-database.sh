#!/bin/bash

# Production Database Configuration Script for GravityPM
# This script configures the production database with security, replication, and monitoring

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="production"
DB_NAME="${PROJECT_NAME}_${ENVIRONMENT}"
PROD_DIR="/opt/${PROJECT_NAME}/${ENVIRONMENT}"

echo "Configuring production database for ${PROJECT_NAME}..."

# Check if production environment exists
if [ ! -d "$PROD_DIR" ]; then
    echo "ERROR: Production environment not found at $PROD_DIR"
    echo "Please run prepare-production-environment.sh first"
    exit 1
fi

# Create database configuration directory
echo "Creating database configuration directory..."
mkdir -p "$PROD_DIR/config/mongodb"

# Create MongoDB production configuration
echo "Creating MongoDB production configuration..."

cat > "$PROD_DIR/config/mongodb/mongod.conf" << EOF
# MongoDB Production Configuration
storage:
  dbPath: /data/db
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
  verbosity: 0
  quiet: false
  traceAllExceptions: false

net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 1000
  compression:
    compressors: snappy,zlib,zstd

processManagement:
  fork: false
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
  keyFile: /etc/mongodb/keyfile
  clusterAuthMode: keyFile
  javascriptEnabled: false
  redactClientLogData: true

replication:
  replSetName: rs0
  enableMajorityReadConcern: true

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
  slowOpSampleRate: 1.0

setParameter:
  wiredTigerMaxCacheOverflowSizeGB: 0.5
  wiredTigerCacheSizeCheckDelaySecs: 5
EOF

# Create MongoDB keyfile for authentication
echo "Creating MongoDB keyfile..."
sudo mkdir -p /etc/mongodb
sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
sudo mv /tmp/mongodb-keyfile /etc/mongodb/keyfile
sudo chmod 400 /etc/mongodb/keyfile
sudo chown mongodb:mongodb /etc/mongodb/keyfile

# Create database initialization script
echo "Creating database initialization script..."

cat > "$PROD_DIR/init-production-db.sh" << EOF
#!/bin/bash

# Production Database Initialization Script
set -e

echo "Initializing production database..."

# Wait for MongoDB to be ready
sleep 30

# Initialize replica set
mongosh --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    {
      _id: 0,
      host: 'mongodb-production:27017'
    }
  ]
});
"

# Wait for replica set to be ready
sleep 10

# Create admin user
mongosh --eval "
db.getSiblingDB('admin').createUser({
  user: 'admin',
  pwd: 'production_mongo_admin_password_123',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
});
"

# Create application database and user
mongosh -u admin -p production_mongo_admin_password_123 --authenticationDatabase admin --eval "
use ${DB_NAME};

db.createUser({
  user: 'app_user',
  pwd: 'production_app_password_123',
  roles: [
    { role: 'readWrite', db: '${DB_NAME}' },
    { role: 'dbAdmin', db: '${DB_NAME}' }
  ]
});

db.createUser({
  user: 'readonly_user',
  pwd: 'production_readonly_password_123',
  roles: [
    { role: 'read', db: '${DB_NAME}' }
  ]
});

db.createUser({
  user: 'backup_user',
  pwd: 'production_backup_password_123',
  roles: [
    { role: 'backup', db: 'admin' },
    { role: 'read', db: '${DB_NAME}' }
  ]
});
"

# Create collections with indexes
mongosh -u app_user -p production_app_password_123 --authenticationDatabase ${DB_NAME} ${DB_NAME} --eval "
// Create collections
db.createCollection('users');
db.createCollection('projects');
db.createCollection('tasks');
db.createCollection('resources');
db.createCollection('rules');
db.createCollection('audit_logs', { capped: true, size: 104857600 }); // 100MB
db.createCollection('sessions');
db.createCollection('notifications');

// Create indexes
db.users.createIndex({ 'email': 1 }, { unique: true });
db.users.createIndex({ 'username': 1 }, { unique: true });
db.users.createIndex({ 'created_at': 1 });

db.projects.createIndex({ 'owner': 1 });
db.projects.createIndex({ 'status': 1 });
db.projects.createIndex({ 'created_at': 1 });
db.projects.createIndex({ 'name': 1 });

db.tasks.createIndex({ 'project_id': 1 });
db.tasks.createIndex({ 'assigned_to': 1 });
db.tasks.createIndex({ 'status': 1 });
db.tasks.createIndex({ 'due_date': 1 });
db.tasks.createIndex({ 'created_at': 1 });

db.resources.createIndex({ 'project_id': 1 });
db.resources.createIndex({ 'type': 1 });
db.resources.createIndex({ 'created_at': 1 });

db.rules.createIndex({ 'project_id': 1 });
db.rules.createIndex({ 'type': 1 });
db.rules.createIndex({ 'active': 1 });

db.audit_logs.createIndex({ 'timestamp': 1 });
db.audit_logs.createIndex({ 'user_id': 1 });
db.audit_logs.createIndex({ 'action': 1 });

db.sessions.createIndex({ 'user_id': 1 });
db.sessions.createIndex({ 'expires_at': 1 }, { expireAfterSeconds: 0 });

db.notifications.createIndex({ 'user_id': 1 });
db.notifications.createIndex({ 'read': 1 });
db.notifications.createIndex({ 'created_at': 1 });

// Create validation rules
db.users.insertOne({
  _id: ObjectId(),
  email: 'admin@gravitypm.com',
  username: 'admin',
  password: '\$2b\$12\$L.Q9Zx8zKj8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc8nJc
