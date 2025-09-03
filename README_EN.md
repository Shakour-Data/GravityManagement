# GravityManagement (GravityPM)

## Project Overview
GravityManagement (GravityPM) is a modern, comprehensive project management system designed to streamline project workflows with automated features and seamless GitHub integration. It supports task management, resource allocation, rule-based automation, and real-time collaboration.

## Technology Stack

| Layer       | Technology / Frameworks                  |
|-------------|----------------------------------------|
| Backend     | FastAPI, Python, MongoDB, Redis, JWT   |
| Frontend    | Next.js 14, React, TypeScript, Tailwind CSS, Radix UI |
| Infrastructure | Docker, Git, GitHub Actions          |

## System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        A[Next.js Frontend]
        B[React Components]
        C[API Client]
    end

    subgraph "API Layer"
        D[FastAPI Server]
        E[Authentication Middleware]
        F[CORS Middleware]
        G[Route Handlers]
    end

    subgraph "Service Layer"
        H[Business Logic]
        I[GitHub Integration]
        J[Data Validation]
        K[Error Handling]
    end

    subgraph "Data Layer"
        L[MongoDB Database]
        M[Data Models]
        N[Database Connection]
    end

    subgraph "External Services"
        O[GitHub API]
        P[GitHub Webhooks]
    end

    A --> C
    C --> D
    D --> E
    D --> F
    D --> G
    G --> H
    H --> I
    H --> J
    H --> K
    H --> N
    N --> L
    I --> O
    I --> P
```

## Data Flow Examples

### Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant Backend
    participant Database

    User->>Frontend: Login Request
    Frontend->>Backend: POST /auth/login
    Backend->>Database: Verify Credentials
    Database-->>Backend: User Data
    Backend-->>Frontend: JWT Token
    Frontend-->>User: Login Success
```

### Project Management Flow

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant Backend
    participant Database
    participant GitHub

    User->>Frontend: Create Project
    Frontend->>Backend: POST /projects
    Backend->>Database: Save Project
    Database-->>Backend: Project ID
    Backend-->>GitHub: Create Repository (Optional)
    GitHub-->>Backend: Repository Info
    Backend-->>Frontend: Project Created
    Frontend-->>User: Success Message
```

## Database Schema (Example)

| Collection | Fields                                                                                  |
|------------|-----------------------------------------------------------------------------------------|
| User       | _id, username, email, full_name, hashed_password, role, github_id, disabled, timestamps |
| Project    | _id, name, description, owner_id, members, status, github_repo, timestamps              |
| Task       | _id, title, description, project_id, assignee_id, status, priority, due_date, timestamps |

## API Endpoints Overview

| Resource       | Endpoint               | Method | Description                  |
|----------------|------------------------|--------|------------------------------|
| Authentication | /auth/login            | POST   | User login                   |
|                | /auth/register         | POST   | User registration            |
| Projects       | /projects              | GET    | List projects                |
|                | /projects              | POST   | Create project               |
| Tasks          | /tasks                 | GET    | List tasks                   |
|                | /tasks                 | POST   | Create task                  |
| GitHub         | /github/webhook        | POST   | GitHub webhook handler       |
|                | /github/repos          | GET    | Get user repositories        |

## Security Considerations
- JWT-based authentication with role-based access control
- Password hashing with bcrypt
- Input validation and XSS protection
- GitHub webhook signature validation
- Rate limiting and secure token storage

## Deployment Architecture

### Development Environment
```mermaid
graph TB
    subgraph "Development"
        A[Local Machine]
        B[Next.js Dev Server :3000]
        C[FastAPI Dev Server :8000]
        D[MongoDB Local]
    end

    A --> B
    A --> C
    A --> D
```

### Production Environment
```mermaid
graph TB
    subgraph "Production"
        A[Load Balancer]
        B[Next.js App]
        C[FastAPI App]
        D[MongoDB Cluster]
        E[Redis Cache]
    end

    A --> B
    A --> C
    B --> C
    C --> D
    C --> E
```

## Performance Optimization
- Asynchronous database operations
- Caching with Redis
- Database indexing
- API rate limiting
- Frontend code splitting and lazy loading

## Monitoring & Logging
- Health check endpoints
- Structured logging with log levels
- Centralized log aggregation

## Conclusion
GravityManagement offers a scalable, secure, and efficient project management platform with modern technologies and seamless GitHub integration.
