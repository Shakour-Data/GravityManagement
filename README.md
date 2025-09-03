# GravityManagement (GravityPM)

A modern, comprehensive project management system with automated features and seamless GitHub integration.

## Documentation

This project provides documentation in multiple languages:

- **[English Documentation](README_EN.md)** - Complete English documentation with architecture diagrams and technical details
- **[Persian Documentation](README_FA.md)** - مستندات کامل به زبان فارسی با نمودارهای معماری و جزئیات فنی

## Quick Start

### Prerequisites
- Python 3.8+
- Node.js 18+
- MongoDB
- Redis (optional)

### Installation

1. **Backend Setup:**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Frontend Setup:**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

3. **Environment Variables:**
   - Copy `.env.example` to `.env`
   - Configure your MongoDB connection and GitHub credentials

### Running the Application

1. **Start MongoDB and Redis**
2. **Backend:** `cd backend && uvicorn app.main:app --reload`
3. **Frontend:** `cd frontend && npm run dev`

## Features

- ✅ Project Management
- ✅ Task Management with Kanban Board
- ✅ Resource Allocation
- ✅ GitHub Integration
- ✅ Real-time Collaboration
- ✅ Rule-based Automation
- ✅ User Authentication & Authorization
- ✅ API Documentation (Swagger/OpenAPI)

## Technology Stack

- **Backend:** FastAPI, Python, MongoDB, Redis, JWT
- **Frontend:** Next.js 14, React, TypeScript, Tailwind CSS, Radix UI
- **Infrastructure:** Docker, Git, GitHub Actions

## Contributing

Please read the documentation files for detailed information about the project architecture, API endpoints, and development guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
