#!/bin/bash

echo "Setting up GravityManagement local environment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker to run MongoDB and Redis."
    exit 1
fi

# Check and start MongoDB
if ! docker ps | grep -q mongo; then
    if docker ps -a | grep -q mongo; then
        echo "Starting existing MongoDB container..."
        docker start mongo
    else
        echo "Starting new MongoDB container..."
        docker run -d --name mongo -p 27017:27017 mongo:latest
    fi
fi

# Check and start Redis
if ! docker ps | grep -q redis; then
    if docker ps -a | grep -q redis; then
        echo "Starting existing Redis container..."
        docker start redis
    else
        echo "Starting new Redis container..."
        docker run -d --name redis -p 6379:6379 redis:latest
    fi
fi

# Backend setup
if [ ! -d "backend/venv" ]; then
    echo "Setting up backend virtual environment and installing dependencies..."
    cd backend
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    cd ..
fi

# Frontend setup
if [ ! -d "frontend/node_modules" ]; then
    echo "Installing frontend dependencies..."
    cd frontend
    npm install
    cd ..
fi

# Start backend if not running
if ! lsof -i :8000 > /dev/null 2>&1; then
    echo "Starting backend server..."
    cd backend
    source venv/bin/activate
    nohup uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 > ../backend.log 2>&1 &
    cd ..
fi

# Start frontend if not running
if ! lsof -i :3000 > /dev/null 2>&1; then
    echo "Starting frontend server..."
    cd frontend
    nohup npm run dev > ../frontend.log 2>&1 &
    cd ..
fi

echo "Setup complete!"
echo "Backend API: http://localhost:8000"
echo "Frontend: http://localhost:3000"
echo "MongoDB: localhost:27017"
echo "Redis: localhost:6379"
echo "Check backend.log and frontend.log for any errors."
