

# GravityPM Project Coding Standard

## Introduction

This document defines the coding standards for the GravityPM project. The main goal of these standards is to create consistency, readability, maintainability, and optimization in the project's code. These standards apply to both the backend (Python) and frontend (Next.js with TypeScript) parts, as well as working with the MongoDB database.

## Objectives of Coding Standards

- Increase code readability and understanding
- Reduce errors and bugs
- Facilitate project maintenance and development
- Improve performance and optimization
- Create consistency in team code
- Accelerate the development and testing process

## Project Structure

### Overall Project Structure

```
gravitypm/
├── backend/                 # Python backend
│   ├── app/                # Main application
│   │   ├── main.py         # Application entry point
│   │   ├── api/            # API routers
│   │   ├── core/           # Core settings
│   │   ├── models/         # Database models
│   │   ├── services/       # Business logic services
│   │   └── utils/          # Utility functions
│   ├── tests/              # Backend tests
│   ├── requirements.txt   # Python requirements
│   └── Dockerfile         # Docker file for backend
│
├── frontend/               # Next.js frontend
│   ├── app/               # App Router structure
│   │   ├── layout.tsx     # Main layout
│   │   ├── page.tsx       # Home page
│   │   └── (auth)/        # Authentication pages
│   ├── components/        # React components
│   ├── lib/               # Utility functions
│   ├── types/             # Type definitions
│   ├── utils/             # Utility functions
│   └── public/            # Static files
│
├── shared/                # Code shared between backend and frontend
│   └── types/             # Shared types
│
├── docs/                  # Project documentation
├── docker-compose.yml     # Docker compose settings
└── README.md             # Project description file
```

## Backend Coding Standards (Python)

### Code Formatting

- Use 4 spaces for indentation (not Tabs).
- Maximum line length should be 80 characters.
- Use blank lines to separate different sections of code.

```python
# Good
def calculate_project_progress(project_id):
    tasks = get_project_tasks(project_id)
    if not tasks:
        return 0
    
    completed_tasks = [task for task in tasks if task.status == "completed"]
    return len(completed_tasks) / len(tasks) * 100

# Bad
def calculate_project_progress(project_id):
    tasks=get_project_tasks(project_id)
    if not tasks:return 0
    completed_tasks=[task for task in tasks if task.status=="completed"]
    return len(completed_tasks)/len(tasks)*100
```

### Naming

- Use `snake_case` for function names, variables, and modules.
- Use `PascalCase` for class names.
- Use `UPPER_CASE` for constant names.

```python
# Good
class ProjectManager:
    def __init__(self, db_connection):
        self.db_connection = db_connection
        self.MAX_PROJECTS = 100
    
    def create_project(self, project_data):
        # Implement project creation
        pass

# Bad
class projectManager:
    def __init__(self, db_connection):
        self.DB = db_connection
        self.maxprojects = 100
    
    def CreateProject(self, project_data):
        # Implement project creation
        pass
```

### Code Documentation (Docstrings)

- Use docstrings to document functions, classes, and modules.
- Use Google-style docstrings format.

```python
class TaskService:
    """
    Project task management service.
    
    This service performs operations related to creating, editing, deleting, and retrieving tasks.
    """
    
    def create_task(self, task_data: dict) -> Task:
        """
        Creates a new task.
        
        Args:
            task_data (dict): Task data including title, description, project, etc.
            
        Returns:
            Task: The created task object
            
        Raises:
            ValueError: If input data is invalid
        """
        # Implement task creation
        pass
```

### Error Handling

- Use exceptions for error handling.
- Create specific and meaningful exceptions.

```python
# Good
def update_task_status(task_id: str, new_status: str) -> bool:
    """
    Updates the status of a task.
    
    Args:
        task_id (str): Task ID
        new_status (str): New status
        
    Returns:
        bool: Update result
        
    Raises:
        TaskNotFoundError: If the task is not found
        InvalidStatusError: If the status is invalid
    """
    task = get_task_by_id(task_id)
    if not task:
        raise TaskNotFoundError(f"Task with ID {task_id} not found")
    
    if new_status not in VALID_STATUSES:
        raise InvalidStatusError(f"Invalid status: {new_status}")
    
    # Implement status update
    return True

# Bad
def update_task_status(task_id, new_status):
    if not get_task_by_id(task_id):
        return False
    
    if new_status not in ["todo", "in_progress", "done"]:
        return False
    
    # Implement status update
    return True
```

### Tests

- Use pytest for writing tests.
- Place tests in the `tests` folder.
- Use fixture functions to prepare test data.

```python
# tests/test_task_service.py
import pytest
from app.services.task_service import TaskService
from app.models.task import Task

@pytest.fixture
def task_service():
    return TaskService()

@pytest.fixture
def sample_task_data():
    return {
        "title": "Test Task",
        "description": "This is a test task",
        "project_id": "123",
        "status": "todo"
    }

def test_create_task(task_service, sample_task_data):
    """Test creating a new task."""
    task = task_service.create_task(sample_task_data)
    
    assert task.title == sample_task_data["title"]
    assert task.description == sample_task_data["description"]
    assert task.project_id == sample_task_data["project_id"]
    assert task.status == sample_task_data["status"]
```

## Frontend Coding Standards (Next.js with TypeScript)

### Code Formatting

- Use Prettier for automatic code formatting.
- Use ESLint for code quality checking.
- Use 2 spaces for indentation.

```typescript
// Good
interface Task {
  id: string;
  title: string;
  description: string;
  status: "todo" | "in_progress" | "done";
  assignee?: string;
  dueDate?: Date;
}

const TaskCard: React.FC<{ task: Task }> = ({ task }) => {
  return (
    <div className="task-card">
      <h3>{task.title}</h3>
      <p>{task.description}</p>
      <span className={`status status-${task.status}`}>
        {task.status}
      </span>
    </div>
  );
};

// Bad
interface Task{
id:string;
title:string;
description:string;
status:"todo"|"in_progress"|"done";
assignee?:string;
dueDate?:Date;
}

const TaskCard:React.FC<{task:Task}> = ({task}) => {
return (
<div className="task-card">
<h3>{task.title}</h3>
<p>{task.description}</p>
<span className={`status status-${task.status}`}>
{task.status}
</span>
</div>
)
};
```

### Naming

- Use `camelCase` for variable names, functions, and components.
- Use `PascalCase` for component names, types, and interfaces.
- Use `UPPER_CASE` for constant names.

```typescript
// Good
interface Project {
  id: string;
  name: string;
  description: string;
  status: ProjectStatus;
  members: string[];
}

const ProjectCard: React.FC<{ project: Project }> = ({ project }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  
  const toggleExpand = () => {
    setIsExpanded(!isExpanded);
  };
  
  return (
    <div className="project-card">
      <h3>{project.name}</h3>
      <button onClick={toggleExpand}>
        {isExpanded ? "Collapse" : "Expand"}
      </button>
      {isExpanded && (
        <div className="project-details">
          <p>{project.description}</p>
          <span>Status: {project.status}</span>
        </div>
      )}
    </div>
  );
};

// Bad
interface project {
  ID: string;
  Name: string;
  Description: string;
  Status: ProjectStatus;
  Members: string[];
}

const projectcard: React.FC<{ project: project }> = ({ project }) => {
  const [Is_Expanded, SetIs_Expanded] = useState(false);
  
  const Toggle_Expand = () => {
    SetIs_Expanded(!Is_Expanded);
  };
  
  return (
    <div className="project-card">
      <h3>{project.Name}</h3>
      <button onClick={Toggle_Expand}>
        {Is_Expanded ? "Collapse" : "Expand"}
      </button>
      {Is_Expanded && (
        <div className="project-details">
          <p>{project.Description}</p>
          <span>Status: {project.Status}</span>
        </div>
      )}
    </div>
  );
};
```

### Types

- Use TypeScript to define types.
- Use interfaces to define data structures.
- Use generics for reusable components.

```typescript
// Good
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, any>;
  };
}

interface User {
  id: string;
  username: string;
  email: string;
  role: "user" | "admin" | "manager";
}

interface Project {
  id: string;
  name: string;
  description: string;
  owner: User;
  members: User[];
  status: "active" | "completed" | "archived";
}

const useApi = <T>(url: string) => {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch(url);
        const result: ApiResponse<T> = await response.json();
        
        if (result.success && result.data) {
          setData(result.data);
        } else {
          setError(result.error?.message || "Unknown error");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [url]);

  return { data, loading, error };
};

// Bad
interface ApiResponse {
  success: boolean;
  data?: any;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
}

const useApi = (url: string) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch(url);
        const result = await response.json();
        
        if (result.success && result.data) {
          setData(result.data);
        } else {
          setError(result.error?.message || "Unknown error");
        }
      } catch (err) {
        setError(err.message || "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [url]);

  return { data, loading, error };
};
```

### Components

- Use functional components with hooks.
- Keep components small and specialized.
- Use props destructuring.

```typescript
// Good
interface TaskCardProps {
  task: Task;
  onStatusChange: (taskId: string, newStatus: TaskStatus) => void;
  onEdit: (task: Task) => void;
  onDelete: (taskId: string) => void;
}

const TaskCard: React.FC<TaskCardProps> = ({ 
  task, 
  onStatusChange, 
  onEdit, 
  onDelete 
}) => {
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);
  
  const handleStatusChange = (newStatus: TaskStatus) => {
    onStatusChange(task.id, newStatus);
  };
  
  const handleDelete = () => {
    onDelete(task.id);
    setIsConfirmingDelete(false);
  };
  
  return (
    <div className="task-card">
      <div className="task-header">
        <h3>{task.title}</h3>
        <div className="task-actions">
          <button onClick={() => onEdit(task)}>Edit</button>
          {isConfirmingDelete ? (
            <>
              <button onClick={handleDelete}>Confirm</button>
              <button onClick={() => setIsConfirmingDelete(false)}>Cancel</button>
            </>
          ) : (
            <button onClick={() => setIsConfirmingDelete(true)}>Delete</button>
          )}
        </div>
      </div>
      <p>{task.description}</p>
      <div className="task-status">
        <span className={`status status-${task.status}`}>
          {task.status}
        </span>
        <select 
          value={task.status} 
          onChange={(e) => handleStatusChange(e.target.value as TaskStatus)}
        >
          <option value="todo">To Do</option>
          <option value="in_progress">In Progress</option>
          <option value="done">Done</option>
        </select>
      </div>
    </div>
  );
};

// Bad
const TaskCard = (props) => {
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);
  
  const handleStatusChange = (newStatus) => {
    props.onStatusChange(props.task.id, newStatus);
  };
  
  const handleDelete = () => {
    props.onDelete(props.task.id);
    setIsConfirmingDelete(false);
  };
  
  return (
    <div className="task-card">
      <div className="task-header">
        <h3>{props.task.title}</h3>
        <div className="task-actions">
          <button onClick={() => props.onEdit(props.task)}>Edit</button>
          {isConfirmingDelete ? (
            <>
              <button onClick={handleDelete}>Confirm</button>
              <button onClick={() => setIsConfirmingDelete(false)}>Cancel</button>
            </>
          ) : (
            <button onClick={() => setIsConfirmingDelete(true)}>Delete</button>
          )}
        </div>
      </div>
      <p>{props.task.description}</p>
      <div className="task-status">
        <span className={`status status-${props.task.status}`}>
          {props.task.status}
        </span>
        <select 
          value={props.task.status} 
          onChange={(e) => handleStatusChange(e.target.value)}
        >
          <option value="todo">To Do</option>
          <option value="in_progress">In Progress</option>
          <option value="done">Done</option>
        </select>
      </div>
    </div>
  );
};
```

### Hooks

- Use standard React hooks.
- Name custom hooks with the `use` prefix.
- Use hooks at the top of the component and before any conditional code.

```typescript
// Good
interface UseTaskOptions {
  projectId: string;
  status?: TaskStatus;
}

const useTasks = ({ projectId, status }: UseTaskOptions) => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchTasks = async () => {
      try {
        setLoading(true);
        const params = new URLSearchParams();
        params.append("projectId", projectId);
        if (status) params.append("status", status);
        
        const response = await fetch(`/api/tasks?${params.toString()}`);
        const data = await response.json();
        
        if (data.success) {
          setTasks(data.data);
        } else {
          setError(data.error?.message || "Failed to fetch tasks");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchTasks();
  }, [projectId, status]);

  return { tasks, loading, error };
};

const TaskList: React.FC<{ projectId: string }> = ({ projectId }) => {
  const { tasks, loading, error } = useTasks({ projectId });
  
  if (loading) return <div>Loading tasks...</div>;
  if (error) return <div>Error: {error}</div>;
  
  return (
    <div className="task-list">
      {tasks.map(task => (
        <TaskCard key={task.id} task={task} />
      ))}
    </div>
  );
};

// Bad
const TaskList = (props) => {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchTasks = async () => {
      try {
        setLoading(true);
        const response = await fetch(`/api/tasks?projectId=${props.projectId}`);
        const data = await response.json();
        
        if (data.success) {
          setTasks(data.data);
        } else {
          setError(data.error?.message || "Failed to fetch tasks");
        }
      } catch (err) {
        setError(err.message || "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchTasks();
  }, [props.projectId]);
  
  if (loading) return <div>Loading tasks...</div>;
  if (error) return <div>Error: {error}</div>;
  
  return (
    <div className="task-list">
      {tasks.map(task => (
        <TaskCard key={task.id} task={task} />
      ))}
    </div>
  );
};
```

### Styles (Tailwind CSS)

- Use Tailwind CSS for styling.
- Use shadcn/ui components for UI elements.
- Use Tailwind classes meaningfully.

```typescript
// Good
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface ProjectCardProps {
  project: Project;
  onEdit: (project: Project) => void;
  onDelete: (projectId: string) => void;
}

const ProjectCard: React.FC<ProjectCardProps> = ({ project, onEdit, onDelete }) => {
  const getStatusColor = (status: ProjectStatus) => {
    switch (status) {
      case "active": return "bg-green-100 text-green-800";
      case "completed": return "bg-blue-100 text-blue-800";
      case "archived": return "bg-gray-100 text-gray-800";
      default: return "bg-gray-100 text-gray-800";
    }
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <div className="flex justify-between items-start">
          <CardTitle>{project.name}</CardTitle>
          <Badge className={getStatusColor(project.status)}>
            {project.status}
          </Badge>
        </div>
        <CardDescription>{project.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="flex justify-between items-center">
          <span className="text-sm text-gray-500">
            {project.members.length} members
          </span>
          <div className="flex space-x-2">
            <Button 
              variant="outline" 
              size="sm"
              onClick={() => onEdit(project)}
            >
              Edit
            </Button>
            <Button 
              variant="destructive" 
              size="sm"
              onClick={() => onDelete(project.id)}
            >
              Delete
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

// Bad
const ProjectCard = (props) => {
  const getStatusColor = (status) => {
    switch (status) {
      case "active": return "bg-green-100 text-green-800";
      case "completed": return "bg-blue-100 text-blue-800";
      case "archived": return "bg-gray-100 text-gray-800";
      default: return "bg-gray-100 text-gray-800";
    }
  };

  return (
    <div className="w-full max-w-md bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="p-6">
        <div className="flex justify-between items-start">
          <h3 className="text-lg font-semibold">{props.project.name}</h3>
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(props.project.status)}`}>
            {props.project.status}
          </span>
        </div>
        <p className="mt-2 text-sm text-gray-600">{props.project.description}</p>
      </div>
      <div className="px-6 py-4 bg-gray-50 rounded-b-lg">
        <div className="flex justify-between items-center">
          <span className="text-sm text-gray-500">
            {props.project.members.length} members
          </span>
          <div className="flex space-x-2">
            <button 
              className="px-3 py-1 border border-gray-300 rounded-md text-sm"
              onClick={() => props.onEdit(props.project)}
            >
              Edit
            </button>
            <button 
              className="px-3 py-1 bg-red-500 text-white rounded-md text-sm"
              onClick={() => props.onDelete(props.project.id)}
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
```

## Database Standards (MongoDB)

### Collection Naming

- Use plural names and `snake_case` for collections.
- Use meaningful and descriptive names.

```javascript
// Good
- users
- projects
- tasks
- project_members
- task_dependencies

// Bad
- User
- projectData
- task_items
- projectMembers
- dependencies
```

### Document Structure

- Use `_id` as the primary identifier.
- Use `created_at` and `updated_at` fields for timestamps.
- Use appropriate data types for each field.

```javascript
// Good
// Collection: tasks
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "title": "Implement user authentication",
  "description": "Add JWT-based authentication to the system",
  "project_id": ObjectId("507f1f77bcf86cd799439012"),
  "assignee_id": ObjectId("507f1f77bcf86cd799439013"),
  "status": "in_progress",
  "priority": "high",
  "due_date": ISODate("2023-12-31T23:59:59Z"),
  "dependencies": [
    ObjectId("507f1f77bcf86cd799439014"),
    ObjectId("507f1f77bcf86cd799439015")
  ],
  "created_at": ISODate("2023-10-01T08:00:00Z"),
  "updated_at": ISODate("2023-10-15T14:30:00Z")
}

// Bad
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "Title": "Implement user authentication",
  "Desc": "Add JWT-based authentication to the system",
  "projectID": "507f1f77bcf86cd799439012",
  "assignee": "507f1f77bcf86cd799439013",
  "Status": "in_progress",
  "Priority": "high",
  "DueDate": "2023-12-31",
  "deps": [
    "507f1f77bcf86cd799439014",
    "507f1f77bcf86cd799439015"
  ],
  "createdAt": "2023-10-01",
  "updatedAt": "2023-10-15"
}
```

### Indexing

- Create indexes for fields that are frequently searched or sorted.
- Use compound indexes for complex queries.

```javascript
// Good
// Collection: tasks
db.tasks.createIndex({ "project_id": 1 })
db.tasks.createIndex({ "assignee_id": 1 })
db.tasks.createIndex({ "status": 1 })
db.tasks.createIndex({ "due_date": 1 })
db.tasks.createIndex({ "project_id": 1, "status": 1 })
db.tasks.createIndex({ "assignee_id": 1, "status": 1 })

// Bad
// Without indexes or inefficient indexes
db.tasks.createIndex({ "title": "text" })  // If rarely searched
db.tasks.createIndex({ "description": "text" })  // If rarely searched
```

### Queries

- Use optimized and efficient queries.
- Use projection to limit returned fields.
- Use the `lean()` method for read-only operations.

```javascript
// Good
// Get tasks of a project with a specific status
const tasks = await db.collection('tasks')
  .find({ 
    project_id: new ObjectId(projectId),
    status: 'in_progress' 
  })
  .project({ 
    title: 1, 
    description: 1, 
    due_date: 1,
    assignee_id: 1
  })
  .sort({ due_date: 1 })
  .toArray();

// Bad
// Get all tasks without filters and projection
const tasks = await db.collection('tasks')
  .find({})
  .toArray();
```

## GitHub Integration Standards

### Webhook Management

- Use a specific route to receive webhooks.
- Verify the webhook signature for authentication.
- Process webhook events asynchronously.

```python
# Good
# backend/app/api/github_webhooks.py
from fastapi import APIRouter, Request, Header, HTTPException
from fastapi.responses import JSONResponse
import hmac
import hashlib
import json
from app.services.github_service import GitHubWebhookService

router = APIRouter()
GITHUB_WEBHOOK_SECRET = "your_webhook_secret"

@router.post("/github/webhooks")
async def handle_github_webhook(
    request: Request,
    x_hub_signature: str = Header(None),
    x_github_event: str = Header(None)
):
    # Verify webhook signature
    if not x_hub_signature:
        raise HTTPException(status_code=400, detail="Missing signature")
    
    payload = await request.body()
    signature = 'sha256=' + hmac.new(
        GITHUB_WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    if not hmac.compare_digest(x_hub_signature, signature):
        raise HTTPException(status_code=400, detail="Invalid signature")
    
    # Process event
    try:
        event_data = json.loads(payload)
        github_service = GitHubWebhookService()
        
        # Asynchronous event processing
        await github_service.process_webhook_event(x_github_event, event_data)
        
        return JSONResponse({"status": "success"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

// Bad
// Without signature verification and synchronous processing
@app.post("/github/webhooks")
async def handle_github_webhook(request: Request):
    payload = await request.json()
    
    # Synchronous event processing
    if payload.get("action") == "opened":
        # Process Issue
        pass
    elif payload.get("ref") == "refs/heads/main":
        # Process Push
        pass
    
    return {"status": "success"}
```

### Token Management

- Store GitHub tokens securely.
- Use tokens with minimum required permissions.
- Update tokens regularly.

```python
# Good
# backend/app/core/security.py
import os
from cryptography.fernet import Fernet

class TokenManager:
    def __init__(self):
        self.key = os.environ.get("ENCRYPTION_KEY")
        self.cipher_suite = Fernet(self.key.encode() if self.key else Fernet.generate_key())
    
    def encrypt_token(self, token: str) -> str:
        """Encrypt token."""
        return self.cipher_suite.encrypt(token.encode()).decode()
    
    def decrypt_token(self, encrypted_token: str) -> str:
        """Decrypt token."""
        return self.cipher_suite.decrypt(encrypted_token.encode()).decode()
    
    def get_github_token(self) -> str:
        """Get GitHub token."""
        encrypted_token = os.environ.get("GITHUB_TOKEN_ENCRYPTED")
        if not encrypted_token:
            raise ValueError("GitHub token not configured")
        
        return self.decrypt_token(encrypted_token)

// Bad
// Storing token in plain text
GITHUB_TOKEN = "ghp_YourGitHubTokenHere"
```

### Event Processing

- Use a dedicated service to process GitHub events.
- Process events based on their type and content.
- Use the strategy pattern for processing different events.

```python
# Good
# backend/app/services/github_service.py
from abc import ABC, abstractmethod
from typing import Dict, Any

class GitHubEventHandler(ABC):
    @abstractmethod
    async def handle(self, event_data: Dict[str, Any]) -> None:
        pass

class PushEventHandler(GitHubEventHandler):
    async def handle(self, event_data: Dict[str, Any]) -> None:
        # Process Push event
        commits = event_data.get("commits", [])
        for commit in commits:
            await self._process_commit(commit)
    
    async def _process_commit(self, commit: Dict[str, Any]) -> None:
        # Process each commit
        message = commit.get("message", "")
        if "ACT-" in message:
            task_id = self._extract_task_id(message)
            await self._update_task_status(task_id, "in_progress")
    
    def _extract_task_id(self, message: str) -> str:
        # Extract task ID from commit message
        import re
        match = re.search(r'ACT-(\d+)', message)
        return match.group(1) if match else ""
    
    async def _update_task_status(self, task_id: str, status: str) -> None:
        # Update task status
        pass

class IssuesEventHandler(GitHubEventHandler):
    async def handle(self, event_data: Dict[str, Any]) -> None:
        # Process Issues event
        action = event_data.get("action")
        issue = event_data.get("issue", {})
        
        if action == "opened":
            await self._handle_issue_opened(issue)
        elif action == "closed":
            await self._handle_issue_closed(issue)
    
    async def _handle_issue_opened(self, issue: Dict[str, Any]) -> None:
        # Handle new Issue
        pass
    
    async def _handle_issue_closed(self, issue: Dict[str, Any]) -> None:
        # Handle closed Issue
        pass

class GitHubWebhookService:
    def __init__(self):
        self._handlers = {
            "push": PushEventHandler(),
            "issues": IssuesEventHandler(),
            # Other handlers
        }
    
    async def process_webhook_event(self, event_type: str, event_data: Dict[str, Any]) -> None:
        handler = self._handlers.get(event_type)
        if handler:
            await handler.handle(event_data)
        else:
            print(f"No handler found for event type: {event_type}")

// Bad
// Processing all events in one function without separation
async def process_github_event(event_type, event_data):
    if event_type == "push":
        commits = event_data.get("commits", [])
        for commit in commits:
            message = commit.get("message", "")
            if "ACT-" in message:
                task_id = extract_task_id(message)
                update_task_status(task_id, "in_progress")
    elif event_type == "issues":
        action = event_data.get("action")
        issue = event_data.get("issue", {})
        
        if action == "opened":
            handle_issue_opened(issue)
        elif action == "closed":
            handle_issue_closed(issue)
    # Other events
```

## Testing and Debugging Standards

### Backend Testing (Python)

- Use pytest for writing tests.
- Use mocks to isolate tests.
- Place tests in the `tests` folder with a structure similar to the main application.

```python
# Good
# tests/test_task_service.py
import pytest
from unittest.mock import Mock, patch
from app.services.task_service import TaskService
from app.models.task import Task

@pytest.fixture
def mock_db():
    return Mock()

@pytest.fixture
def task_service(mock_db):
    return TaskService(mock_db)

@pytest.fixture
def sample_task():
    return {
        "_id": "507f1f77bcf86cd799439011",
        "title": "Test Task",
        "description": "This is a test task",
        "project_id": "507f1f77bcf86cd799439012",
        "status": "todo",
        "created_at": "2023-10-01T08:00:00Z",
        "updated_at": "2023-10-01T08:00:00Z"
    }

def test_create_task(task_service, mock_db, sample_task):
    # Setup
    mock_db.insert_one.return_value.inserted_id = sample_task["_id"]
    
    # Execution
    result = task_service.create_task(sample_task)
    
    # Verification
    assert result["_id"] == sample_task["_id"]
    mock_db.insert_one.assert_called_once()

def test_get_task_by_id(task_service, mock_db, sample_task):
    # Setup
    mock_db.find_one.return_value = sample_task
    
    # Execution
    result = task_service.get_task_by_id(sample_task["_id"])
    
    # Verification
    assert result["_id"] == sample_task["_id"]
    mock_db.find_one.assert_called_once_with({"_id": sample_task["_id"]})

def test_get_task_by_id_not_found(task_service, mock_db):
    # Setup
    mock_db.find_one.return_value = None
    
    # Execution and verification
    with pytest.raises(ValueError, match="Task not found"):
        task_service.get_task_by_id("nonexistent_id")

// Bad
// Without mocks and structured tests
def test_create_task():
    db = get_db()
    task = {
        "title": "Test Task",
        "description": "This is a test task",
        "project_id": "507f1f77bcf86cd799439012",
        "status": "todo"
    }
    
    result = db.tasks.insert_one(task)
    assert result.inserted_id is not None
```

### Frontend Testing (Next.js)

- Use Jest and React Testing Library for component testing.
- Use Cypress for end-to-end testing.
- Place tests in the `__tests__` folder or next to related files.

```typescript
// Good
// components/__tests__/TaskCard.test.tsx
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { TaskCard } from '../TaskCard';
import { Task } from '@/types';

const mockTask: Task = {
  id: '1',
  title: 'Test Task',
  description: 'This is a test task',
  status: 'todo',
  project_id: 'project1',
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
};

describe('TaskCard', () => {
  it('renders task information correctly', () => {
    render(<TaskCard task={mockTask} onStatusChange={jest.fn()} onEdit={jest.fn()} onDelete={jest.fn()} />);
    
    expect(screen.getByText(mockTask.title)).toBeInTheDocument();
    expect(screen.getByText(mockTask.description)).toBeInTheDocument();
    expect(screen.getByText(mockTask.status)).toBeInTheDocument();
  });

  it('calls onStatusChange when status is changed', () => {
    const mockOnStatusChange = jest.fn();
    render(<TaskCard task={mockTask} onStatusChange={mockOnStatusChange} onEdit={jest.fn()} onDelete={jest.fn()} />);
    
    const statusSelect = screen.getByRole('combobox');
    fireEvent.change(statusSelect, { target: { value: 'in_progress' } });
    
    expect(mockOnStatusChange).toHaveBeenCalledWith(mockTask.id, 'in_progress');
  });

  it('calls onEdit when edit button is clicked', () => {
    const mockOnEdit = jest.fn();
    render(<TaskCard task={mockTask} onStatusChange={jest.fn()} onEdit={mockOnEdit} onDelete={jest.fn()} />);
    
    const editButton = screen.getByRole('button', { name: /edit/i });
    fireEvent.click(editButton);
    
    expect(mockOnEdit).toHaveBeenCalledWith(mockTask);
  });
});

// Good
// cypress/e2e/task-management.cy.ts
describe('Task Management', () => {
  beforeEach(() => {
    cy.login('testuser@example.com', 'password');
    cy.visit('/projects/1/tasks');
  });

  it('should display task list', () => {
    cy.get('.task-card').should('have.length.at.least', 1);
  });

  it('should create a new task', () => {
    cy.get('[data-testid="create-task-button"]').click();
    
    cy.get('[data-testid="task-title-input"]').type('New Test Task');
    cy.get('[data-testid="task-description-input"]').type('This is a new test task');
    cy.get('[data-testid="task-status-select"]').select('todo');
    
    cy.get('[data-testid="save-task-button"]').click();
    
    cy.contains('New Test Task').should('be.visible');
    cy.contains('This is a new test task').should('be.visible');
  });

  it('should update task status', () => {
    cy.get('.task-card').first().within(() => {
      cy.get('[data-testid="task-status-select"]').select('in_progress');
    });
    
    cy.get('.task-card').first().within(() => {
      cy.get('[data-testid="task-status-select"]').should('have.value', 'in_progress');
    });
  });
});

// Bad
// Without structured tests and without using testing libraries
describe('TaskCard', () => {
  it('renders correctly', () => {
    const task = {
      id: '1',
      title: 'Test Task',
      description: 'This is a test task',
      status: 'todo'
    };
    
    const component = renderer.create(
      <TaskCard task={task} onStatusChange={() => {}} onEdit={() => {}} onDelete={() => {}} />
    );
    let tree = component.toJSON();
    expect(tree).toMatchSnapshot();
  });
});
```

## Documentation Standards

### Code Documentation

- Use docstrings to document functions, classes, and modules.
- Use comments to explain complex logic.
- Use API documentation to explain endpoints.

```python
# Good
# backend/app/services/task_service.py
"""
Project task management service.

This service performs operations related to creating, editing, deleting, and retrieving tasks.
"""

from typing import List, Optional
from datetime import datetime
from app.models.task import Task, TaskStatus
from app.database import get_database

class TaskService:
    """
    Task management service.
    
    This class implements task-related operations.
    """
    
    def __init__(self, db=None):
        """
        Initialize the service.
        
        Args:
            db: Database connection (optional)
        """
        self.db = db or get_database()
    
    def create_task(self, task_data: dict) -> Task:
        """
        Create a new task.
        
        Args:
            task_data (dict): Task data including title, description, project, etc.
            
        Returns:
            Task: The created task object
            
        Raises:
            ValueError: If input data is invalid
        """
        # Validate input data
        if not task_data.get('title'):
            raise ValueError("Task title is required")
        
        if not task_data.get('project_id'):
            raise ValueError("Project ID is required")
        
        # Create new task
        now = datetime.utcnow()
        task = Task(
            title=task_data['title'],
            description=task_data.get('description', ''),
            project_id=task_data['project_id'],
            assignee_id=task_data.get('assignee_id'),
            status=task_data.get('status', TaskStatus.TODO),
            due_date=task_data.get('due_date'),
            created_at=now,
            updated_at=now
        )
        
        # Save task to database
        result = self.db.tasks.insert_one(task.dict())
        task.id = result.inserted_id
        
        return task

// Bad
// Without proper documentation
class TaskService:
    def __init__(self, db=None):
        self.db = db or get_database()
    
    def create_task(self, task_data):
        if not task_data.get('title'):
            raise ValueError("Task title is required")
        
        if not task_data.get('project_id'):
            raise ValueError("Project ID is required")
        
        now = datetime.utcnow()
        task = Task(
            title=task_data['title'],
            description=task_data.get('description', ''),
            project_id=task_data['project_id'],
            assignee_id=task_data.get('assignee_id'),
            status=task_data.get('status', TaskStatus.TODO),
            due_date=task_data.get('due_date'),
            created_at=now,
            updated_at=now
        )
        
        result = self.db.tasks.insert_one(task.dict())
        task.id = result.inserted_id
        
        return task
```

### API Documentation

- Use OpenAPI/Swagger for API documentation.
- Document all endpoints.
- Use real examples for documentation.

```python
# Good
# backend/app/api/tasks.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from app.models.task import Task, TaskCreate, TaskUpdate, TaskStatus
from app.services.task_service import TaskService
from app.core.auth import get_current_user

router = APIRouter(
    prefix="/tasks",
    tags=["tasks"],
    responses={404: {"description": "Not found"}},
)

@router.post("/", response_model=Task, status_code=status.HTTP_201_CREATED)
async def create_task(
    task: TaskCreate,
    current_user: dict = Depends(get_current_user),
    task_service: TaskService = Depends()
):
    """
    Create a new task.
    
    Args:
        task (TaskCreate): New task data
        current_user (dict): Current user
        task_service (TaskService): Task service
        
    Returns:
        Task: Created task
        
    Raises:
        HTTPException: If input data is invalid
    """
    try:
        # Add current user ID as creator
        task_data = task.dict()
        task_data['creator_id'] = current_user['id']
        
        return task_service.create_task(task_data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", response_model=List[Task])
async def get_tasks(
    project_id: Optional[str] = None,
    status: Optional[TaskStatus] = None,
    assignee_id: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
    task_service: TaskService = Depends()
):
    """
    Returns a list of tasks based on specified filters.
    
    Args:
        project_id (str, optional): Project ID to filter by
        status (TaskStatus, optional): Task status to filter by
        assignee_id (str, optional): Task assignee ID to filter by
        skip (int, optional): Number of tasks to skip (for pagination)
        limit (int, optional): Maximum number of tasks to return
        current_user (dict): Current user
        task_service (TaskService): Task service
        
    Returns:
        List[Task]: Filtered list of tasks
        
    Example:
        GET /tasks?project_id=123&status=in_progress&limit=10
    """
    filters = {}
    if project_id:
        filters['project_id'] = project_id
    if status:
        filters['status'] = status
    if assignee_id:
        filters['assignee_id'] = assignee_id
    
    return task_service.get_tasks(filters, skip=skip, limit=limit)

// Bad
// Without proper documentation
@router.post("/")
async def create_task(task, current_user=Depends(get_current_user), task_service=Depends()):
    try:
        task_data = task.dict()
        task_data['creator_id'] = current_user['id']
        
        return task_service.create_task(task_data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/")
async def get_tasks(
    project_id=None,
    status=None,
    assignee_id=None,
    skip=0,
    limit=100,
    current_user=Depends(get_current_user),
    task_service=Depends()
):
    filters = {}
    if project_id:
        filters['project_id'] = project_id
    if status:
        filters['status'] = status
    if assignee_id:
        filters['assignee_id'] = assignee_id
    
    return task_service.get_tasks(filters, skip=skip, limit=limit)
```

## Security Standards

### Authentication and Authorization

- Use JWT for authentication.
- Use RBAC (Role-Based Access Control) for permission management.
- Store and manage tokens securely.

```python
# Good
# backend/app/core/auth.py
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status
import os

# JWT settings
SECRET_KEY = os.environ.get("SECRET_KEY", "your-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password settings
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class AuthService:
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify password."""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """Hash password."""
        return pwd_context.hash(password)
    
    @staticmethod
    def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Create access token."""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=15)
        
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt
    
    @staticmethod
    def verify_token(token: str) -> Dict[str, Any]:
        """Verify token and extract information."""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            username: str = payload.get("sub")
            if username is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Could not validate credentials",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            return payload
        except JWTError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

# Middleware for authentication check
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse

async def auth_middleware(request: Request, call_next):
    # Check token in request header
    token = request.headers.get("Authorization")
    if not token:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Authentication required"}
        )
    
    try:
        # Verify token
        token = token.split(" ")[1]  # Remove "Bearer " from the beginning of the token
        payload = AuthService.verify_token(token)
        
        # Add user information to the request
        request.state.user = payload
        
        # Continue processing the request
        response = await call_next(request)
        return response
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Invalid or expired token"}
        )

// Bad
// Without proper security
def create_token(username):
    return f"token-{username}-{datetime.now().timestamp()}"

def verify_token(token):
    parts = token.split("-")
    if len(parts) < 3:
        return None
    
    username = parts[1]
    timestamp = float(parts[2])
    
    # Check token expiration (24 hours)
    if datetime.now().timestamp() - timestamp > 86400:
        return None
    
    return {"sub": username}
```

### Input Validation

- Use Pydantic for input validation in the backend.
- Use PropTypes or TypeScript for props validation in the frontend.
- Always validate user inputs.

```python
# Good
# backend/app/models/task.py
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    """Allowed task statuses."""
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    REVIEW = "review"
    DONE = "done"

class TaskPriority(str, Enum):
    """Allowed task priorities."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class TaskBase(BaseModel):
    """Base task model."""
    title: str = Field(..., min_length=1, max_length=100, description="Task title")
    description: Optional[str] = Field("", max_length=1000, description="Task description")
    project_id: str = Field(..., description="Project ID")
    assignee_id: Optional[str] = Field(None, description="Task assignee ID")
    status: TaskStatus = Field(TaskStatus.TODO, description="Task status")
    priority: TaskPriority = Field(TaskPriority.MEDIUM, description="Task priority")
    due_date: Optional[datetime] = Field(None, description="Due date")
    dependencies: Optional[List[str]] = Field([], description="Dependent task IDs")
    
    @validator('title')
    def validate_title(cls, v):
        """Validate task title."""
        if not v.strip():
            raise ValueError("Title cannot be empty")
        return v.strip()
    
    @validator('due_date')
    def validate_due_date(cls, v, values):
        """Validate due date."""
        if v and v < datetime.now():
            raise ValueError("Due date cannot be in the past")
        return v

class TaskCreate(TaskBase):
    """Task creation model."""
    pass

class TaskUpdate(BaseModel):
    """Task update model."""
    title: Optional[str] = Field(None, min_length=1, max_length=100, description="Task title")
    description: Optional[str] = Field(None, max_length=1000, description="Task description")
    assignee_id: Optional[str] = Field(None, description="Task assignee ID")
    status: Optional[TaskStatus] = Field(None, description="Task status")
    priority: Optional[TaskPriority] = Field(None, description="Task priority")
    due_date: Optional[datetime] = Field(None, description="Due date")
    dependencies: Optional[List[str]] = Field(None, description="Dependent task IDs")
    
    @validator('title')
    def validate_title(cls, v):
        """Validate task title."""
        if v is not None and not v.strip():
            raise ValueError("Title cannot be empty")
        return v.strip() if v else v
    
    @validator('due_date')
    def validate_due_date(cls, v, values):
        """Validate due date."""
        if v and v < datetime.now():
            raise ValueError("Due date cannot be in the past")
        return v

class Task(TaskBase):
    """Complete task model."""
    id: str
    creator_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True

// Bad
// Without proper validation
class TaskBase(BaseModel):
    title: str
    description: Optional[str] = ""
    project_id: str
    assignee_id: Optional[str] = None
    status: str = "todo"
    priority: str = "medium"
    due_date: Optional[str] = None
    dependencies: Optional[List[str]] = []

class TaskCreate(TaskBase):
    pass

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    assignee_id: Optional[str] = None
    status: Optional[str] = None
    priority: Optional[str] = None
    due_date: Optional[str] = None
    dependencies: Optional[List[str]] = None
```