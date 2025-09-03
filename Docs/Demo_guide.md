# GravityPM Demo Guide

## Overview
GravityPM is a comprehensive project management tool that integrates with GitHub to provide real-time task tracking, resource management, and automated rule-based workflows.

## Prerequisites
- Node.js 18+ and npm
- Python 3.8+
- MongoDB (local or Atlas)
- GitHub account (for integration features)

## Quick Start

### 1. Backend Setup
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Frontend Setup
```bash
cd frontend
npm install
npm run dev
```

### 3. Access the Application
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Documentation: http://localhost:8000/docs

## Demo Scenarios

### Scenario 1: Basic Project Management
1. **Login/Register**: Create an account or login
2. **Create Project**: Click "Create Project" and fill in details
3. **Add Tasks**: Navigate to project and add tasks with different priorities
4. **Task Board**: View tasks in Kanban board, drag and drop to change status
5. **Real-time Updates**: Open multiple browser tabs to see real-time synchronization

### Scenario 2: GitHub Integration
1. **Connect GitHub**: Go to Settings > GitHub Integration
2. **Link Repository**: Connect your GitHub repository
3. **View Commits/PRs**: See GitHub activity in the dashboard
4. **Automated Rules**: Set up rules that trigger on GitHub events

### Scenario 3: Resource Management
1. **Add Resources**: Create resources (team members, equipment, etc.)
2. **Assign to Tasks**: Link resources to specific tasks
3. **Track Utilization**: Monitor resource usage across projects

### Scenario 4: Rule Engine
1. **Create Rules**: Define automated workflows
2. **Set Conditions**: Configure triggers and actions
3. **Test Rules**: Use the rule testing interface
4. **Monitor Execution**: View rule execution logs

## Key Features to Showcase

### Real-Time Collaboration
- WebSocket-based real-time updates
- Live task status changes
- Instant notifications

### GitHub Integration
- Commit tracking
- Pull request monitoring
- Issue synchronization
- Webhook handling

### Advanced Task Management
- Kanban board interface
- Task dependencies
- Progress tracking
- Priority management

### Resource Management
- Resource allocation
- Utilization tracking
- Capacity planning

### Rule Engine
- Automated workflows
- Conditional triggers
- Custom actions
- Rule testing interface

## Troubleshooting

### Backend Issues
- Check MongoDB connection
- Verify environment variables
- Check logs in terminal

### Frontend Issues
- Clear browser cache
- Check console for errors
- Verify API endpoints

### WebSocket Issues
- Ensure backend is running on port 8000
- Check firewall settings
- Verify WebSocket URL configuration

## Demo Script

### Opening Script
"Welcome to GravityPM, a modern project management platform with GitHub integration and real-time collaboration features."

### Feature Demonstration
1. **Login Flow**: "Let's start by logging into the system..."
2. **Project Creation**: "Now I'll create a new project..."
3. **Task Management**: "Here we can see the task board with real-time updates..."
4. **GitHub Integration**: "Let's connect this project to GitHub..."
5. **Rule Engine**: "Now I'll show you the automated rule system..."

### Closing Script
"Thank you for watching the GravityPM demo. This platform provides everything you need for modern project management with powerful automation and real-time collaboration."
