

# GravityPM Architecture Documentation

## Overview

GravityPM is a comprehensive project management system built with modern web technologies. The system provides automated project management capabilities with seamless GitHub integration for streamlined development workflows.

## Technology Stack

### Backend
- **Framework**: FastAPI (Python)
- **Database**: MongoDB
- **Authentication**: JWT (JSON Web Tokens)
- **API Documentation**: OpenAPI/Swagger
- **ASGI Server**: Uvicorn

### Frontend
- **Framework**: Next.js 14 (React)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: Radix UI
- **State Management**: React Hooks
- **HTTP Client**: Axios

### Infrastructure
- **Database**: MongoDB
- **Cache**: Redis (optional)
- **Deployment**: Docker
- **Version Control**: Git
- **CI/CD**: GitHub Actions

## System Architecture

### High-Level Architecture

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

### Component Architecture

#### Backend Components

```mermaid
graph TB
    subgraph "FastAPI Application"
        A[main.py]
        B[routers/]
        C[models/]
        D[services/]
        E[database.py]
    end

    subgraph "Routers"
        F[auth.py]
        G[projects.py]
        H[tasks.py]
        I[resources.py]
        J[github_integration.py]
    end

    subgraph "Models"
        K[user.py]
        L[project.py]
        M[task.py]
        N[resource.py]
        O[rule.py]
    end

    subgraph "Services"
        P[auth_service.py]
        Q[github_service.py]
    end

    A --> B
    A --> C
    A --> D
    A --> E
    B --> F
    B --> G
    B --> H
    B --> I
    B --> J
    C --> K
    C --> L
    C --> M
    C --> N
    C --> O
    D --> P
    D --> Q
```

#### Frontend Components

```mermaid
graph TB
    subgraph "Next.js Application"
        A[app/]
        B[components/]
        C[lib/]
        D[types/]
        E[utils/]
    end

    subgraph "App Router"
        F[layout.tsx]
        G[page.tsx]
        H[loading.tsx]
        I[error.tsx]
    end

    subgraph "Components"
        J[ProjectList]
        K[TaskBoard]
        L[UserProfile]
        M[GitHubIntegration]
    end

    subgraph "Utilities"
        N[API Client]
        O[Auth Hooks]
        P[Form Validation]
        Q[Date Utils]
    end

    A --> F
    A --> G
    A --> H
    A --> I
    A --> J
    A --> K
    A --> L
    A --> M
    A --> N
    A --> O
    A --> P
    A --> Q
```

## Data Flow

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

### GitHub Integration Flow

```mermaid
sequenceDiagram
    participant GitHub
    participant Backend
    participant Database
    participant Frontend

    GitHub->>Backend: Webhook Event
    Backend->>Backend: Validate Signature
    Backend->>Backend: Process Event
    Backend->>Database: Update Task Status
    Database-->>Backend: Update Confirmation
    Backend-->>GitHub: 200 OK
    Backend->>Frontend: Real-time Update (WebSocket)
```

## Database Schema

### User Collection
```json
{
  "_id": ObjectId,
  "username": "string",
  "email": "string",
  "full_name": "string",
  "hashed_password": "string",
  "role": "user|admin|manager",
  "github_id": "string",
  "disabled": false,
  "created_at": DateTime,
  "updated_at": DateTime
}
```

### Project Collection
```json
{
  "_id": ObjectId,
  "name": "string",
  "description": "string",
  "owner_id": ObjectId,
  "members": [ObjectId],
  "status": "active|completed|archived",
  "github_repo": "string",
  "created_at": DateTime,
  "updated_at": DateTime
}
```

### Task Collection
```json
{
  "_id": ObjectId,
  "title": "string",
  "description": "string",
  "project_id": ObjectId,
  "assignee_id": ObjectId,
  "status": "todo|in_progress|review|done",
  "priority": "low|medium|high",
  "due_date": DateTime,
  "github_issue_id": "string",
  "created_at": DateTime,
  "updated_at": DateTime
}
```

## API Design

### RESTful Endpoints

#### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /auth/refresh` - Token refresh
- `GET /auth/me` - Get current user

#### Projects
- `GET /projects` - List projects
- `POST /projects` - Create project
- `GET /projects/{id}` - Get project details
- `PUT /projects/{id}` - Update project
- `DELETE /projects/{id}` - Delete project

#### Tasks
- `GET /tasks` - List tasks
- `POST /tasks` - Create task
- `GET /tasks/{id}` - Get task details
- `PUT /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task

#### GitHub Integration
- `POST /github/webhook` - GitHub webhook handler
- `GET /github/repos` - Get user repositories
- `POST /github/connect` - Connect GitHub account

### Response Format

#### Success Response
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

#### Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": { ... }
  }
}
```

## Security Considerations

### Authentication & Authorization
- JWT-based authentication
- Password hashing with bcrypt
- Role-based access control (RBAC)
- Token expiration and refresh

### Data Protection
- Input validation with Pydantic
- SQL injection prevention (MongoDB)
- XSS protection in frontend
- CORS configuration

### GitHub Integration Security
- Webhook signature validation
- GitHub token encryption
- Rate limiting
- Secure token storage

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

### Backend Optimizations
- Asynchronous database operations
- Connection pooling
- Caching with Redis
- Database indexing
- API rate limiting

### Frontend Optimizations
- Code splitting
- Image optimization
- Lazy loading
- Service worker caching
- Bundle analysis

## Monitoring & Logging

### Application Monitoring
- Health check endpoints
- Performance metrics
- Error tracking
- Database monitoring

### Logging Strategy
- Structured logging
- Log levels (DEBUG, INFO, WARNING, ERROR)
- Centralized log aggregation
- Log retention policies

## Conclusion

The GravityPM architecture provides a scalable, maintainable, and secure foundation for project management with seamless GitHub integration. The separation of concerns between frontend and backend, combined with modern technologies, ensures high performance and developer productivity.