

# استاندارد کدنویسی پروژه GravityPM

## مقدمه

این سند استانداردهای کدنویسی برای پروژه GravityPM را تعریف می‌کند. هدف اصلی این استانداردها، ایجاد یکپارچگی، خوانایی، قابلیت نگهداری و بهینه‌سازی در کدهای پروژه است. این استانداردها برای هر دو بخش بک‌اند (پایتون) و فرانت‌اند (Next.js با TypeScript) و همچنین کار با دیتابیس MongoDB اعمال می‌شوند.

## اهداف استاندارد کدنویسی

- افزایش خوانایی و درک کد
- کاهش خطاها و باگ‌ها
- تسهیل نگهداری و توسعه پروژه
- بهبود عملکرد و بهینه‌سازی
- ایجاد یکپارچگی در کدهای تیم
- تسریع فرآیند توسعه و تست

## ساختار پروژه

### ساختار کلی پروژه

```
gravitypm/
├── backend/                 # بک‌اند پایتون
│   ├── app/                # اپلیکیشن اصلی
│   │   ├── main.py         # نقطه ورودی اپلیکیشن
│   │   ├── api/            # روترهای API
│   │   ├── core/           # تنظیمات اصلی
│   │   ├── models/         # مدل‌های دیتابیس
│   │   ├── services/       # سرویس‌های منطق کسب‌وکار
│   │   └── utils/          # توابع کمکی
│   ├── tests/              # تست‌های بک‌اند
│   ├── requirements.txt   # نیازمندی‌های پایتون
│   └── Dockerfile         # فایل داکر برای بک‌اند
│
├── frontend/               # فرانت‌اند Next.js
│   ├── app/               # ساختار App Router
│   │   ├── layout.tsx     # لایوت اصلی
│   │   ├── page.tsx       # صفحه اصلی
│   │   └── (auth)/        # صفحات احراز هویت
│   ├── components/        # کامپوننت‌های ری‌اکت
│   ├── lib/               # توابع کمکی
│   ├── types/             # تعریف تایپ‌ها
│   ├── utils/             # توابع کمکی
│   └── public/            # فایل‌های استاتیک
│
├── shared/                # کدهای مشترک بین بک‌اند و فرانت‌اند
│   └── types/             # تایپ‌های مشترک
│
├── docs/                  # مستندات پروژه
├── docker-compose.yml     # تنظیمات داکر کامپوز
└── README.md             # فایل توضیحات پروژه
```

## استانداردهای کدنویسی بک‌اند (پایتون)

### قالب‌بندی کد

- از ۴ فاصله برای تو رفتگی استفاده کنید (نه Tab).
- حداکثر طول خط ۸۰ کاراکتر باشد.
- از خطوط خالی برای جدا کردن بخش‌های مختلف کد استفاده کنید.

```python
# خوب
def calculate_project_progress(project_id):
    tasks = get_project_tasks(project_id)
    if not tasks:
        return 0
    
    completed_tasks = [task for task in tasks if task.status == "completed"]
    return len(completed_tasks) / len(tasks) * 100

# بد
def calculate_project_progress(project_id):
    tasks=get_project_tasks(project_id)
    if not tasks:return 0
    completed_tasks=[task for task in tasks if task.status=="completed"]
    return len(completed_tasks)/len(tasks)*100
```

### نام‌گذاری

- از `snake_case` برای نام توابع، متغیرها و ماژول‌ها استفاده کنید.
- از `PascalCase` برای نام کلاس‌ها استفاده کنید.
- از `UPPER_CASE` برای نام ثابت‌ها استفاده کنید.

```python
# خوب
class ProjectManager:
    def __init__(self, db_connection):
        self.db_connection = db_connection
        self.MAX_PROJECTS = 100
    
    def create_project(self, project_data):
        # پیاده‌سازی ایجاد پروژه
        pass

# بد
class projectManager:
    def __init__(self, db_connection):
        self.DB = db_connection
        self.maxprojects = 100
    
    def CreateProject(self, project_data):
        # پیاده‌سازی ایجاد پروژه
        pass
```

### توضیحات کد (Docstrings)

- از docstrings برای مستندسازی توابع، کلاس‌ها و ماژول‌ها استفاده کنید.
- از فرمت Google-style docstrings استفاده کنید.

```python
class TaskService:
    """
    سرویس مدیریت وظایف پروژه.
    
    این سرویس عملیات مربوط به ایجاد، ویرایش، حذف و بازیابی وظایف را انجام می‌دهد.
    """
    
    def create_task(self, task_data: dict) -> Task:
        """
        یک وظیفه جدید ایجاد می‌کند.
        
        Args:
            task_data (dict): داده‌های وظیفه شامل عنوان، توضیحات، پروژه و ...
            
        Returns:
            Task: شیء وظیفه ایجاد شده
            
        Raises:
            ValueError: اگر داده‌های ورودی نامعتبر باشند
        """
        # پیاده‌سازی ایجاد وظیفه
        pass
```

### مدیریت خطاها

- از استثناها برای مدیریت خطاها استفاده کنید.
- استثناهای خاص و معنادار ایجاد کنید.

```python
# خوب
def update_task_status(task_id: str, new_status: str) -> bool:
    """
    وضعیت یک وظیفه را به‌روزرسانی می‌کند.
    
    Args:
        task_id (str): شناسه وظیفه
        new_status (str): وضعیت جدید
        
    Returns:
        bool: نتیجه به‌روزرسانی
        
    Raises:
        TaskNotFoundError: اگر وظیفه یافت نشود
        InvalidStatusError: اگر وضعیت نامعتبر باشد
    """
    task = get_task_by_id(task_id)
    if not task:
        raise TaskNotFoundError(f"Task with ID {task_id} not found")
    
    if new_status not in VALID_STATUSES:
        raise InvalidStatusError(f"Invalid status: {new_status}")
    
    # پیاده‌سازی به‌روزرسانی وضعیت
    return True

# بد
def update_task_status(task_id, new_status):
    if not get_task_by_id(task_id):
        return False
    
    if new_status not in ["todo", "in_progress", "done"]:
        return False
    
    # پیاده‌سازی به‌روزرسانی وضعیت
    return True
```

### تست‌ها

- از pytest برای نوشتن تست‌ها استفاده کنید.
- تست‌ها را در پوشه `tests` قرار دهید.
- از توابع fixture برای آماده‌سازی داده‌های تست استفاده کنید.

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
    """تست ایجاد یک وظیفه جدید."""
    task = task_service.create_task(sample_task_data)
    
    assert task.title == sample_task_data["title"]
    assert task.description == sample_task_data["description"]
    assert task.project_id == sample_task_data["project_id"]
    assert task.status == sample_task_data["status"]
```

## استانداردهای کدنویسی فرانت‌اند (Next.js با TypeScript)

### قالب‌بندی کد

- از Prettier برای قالب‌بندی خودکار کد استفاده کنید.
- از ESLint برای بررسی کیفیت کد استفاده کنید.
- از ۲ فاصله برای تو رفتگی استفاده کنید.

```typescript
// خوب
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

// بد
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

### نام‌گذاری

- از `camelCase` برای نام متغیرها، توابع و کامپوننت‌ها استفاده کنید.
- از `PascalCase` برای نام کامپوننت‌ها، نوع‌ها و اینترفیس‌ها استفاده کنید.
- از `UPPER_CASE` برای نام ثابت‌ها استفاده کنید.

```typescript
// خوب
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

// بد
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

### تایپ‌ها

- از TypeScript برای تعریف تایپ‌ها استفاده کنید.
- از اینترفیس‌ها برای تعریف ساختار داده‌ها استفاده کنید.
- از تایپ‌های عمومی (Generics) برای کامپوننت‌های قابل استفاده مجدد استفاده کنید.

```typescript
// خوب
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

// بد
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

### کامپوننت‌ها

- از کامپوننت‌های تابعی با هوک‌ها استفاده کنید.
- کامپوننت‌ها را کوچک و تخصصی نگه دارید.
- از Props destructuring استفاده کنید.

```typescript
// خوب
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

// بد
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

### هوک‌ها

- از هوک‌های استاندارد React استفاده کنید.
- هوک‌های سفارشی را با پیشوند `use` نام‌گذاری کنید.
- از هوک‌ها در بالای کامپوننت و قبل از هر کد شرطی استفاده کنید.

```typescript
// خوب
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

// بد
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

### استایل‌ها (Tailwind CSS)

- از Tailwind CSS برای استایل‌دهی استفاده کنید.
- از کامپوننت‌های shadcn/ui برای المان‌های رابط کاربری استفاده کنید.
- از کلاس‌های Tailwind به صورت معنادار استفاده کنید.

```typescript
// خوب
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

// بد
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

## استانداردهای دیتابیس (MongoDB)

### نام‌گذاری مجموعه‌ها (Collections)

- از نام‌های جمع و `snake_case` برای مجموعه‌ها استفاده کنید.
- از نام‌های معنادار و توصیفی استفاده کنید.

```javascript
// خوب
- users
- projects
- tasks
- project_members
- task_dependencies

// بد
- User
- projectData
- task_items
- projectMembers
- dependencies
```

### ساختار اسناد (Documents)

- از `_id` به عنوان شناسه اصلی استفاده کنید.
- از فیلدهای `created_at` و `updated_at` برای زمان‌نگاری استفاده کنید.
- از نوع داده‌های مناسب برای هر فیلد استفاده کنید.

```javascript
// خوب
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

// بد
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

### ایندکس‌گذاری (Indexing)

- برای فیلدهایی که به طور مکرر جستجو یا مرتب می‌شوند، ایندکس ایجاد کنید.
- از ایندکس‌های ترکیبی برای کوئری‌های پیچیده استفاده کنید.

```javascript
// خوب
// Collection: tasks
db.tasks.createIndex({ "project_id": 1 })
db.tasks.createIndex({ "assignee_id": 1 })
db.tasks.createIndex({ "status": 1 })
db.tasks.createIndex({ "due_date": 1 })
db.tasks.createIndex({ "project_id": 1, "status": 1 })
db.tasks.createIndex({ "assignee_id": 1, "status": 1 })

// بد
// بدون ایندکس یا ایندکس‌های ناکارآمد
db.tasks.createIndex({ "title": "text" })  // اگر به ندرت جستجو می‌شود
db.tasks.createIndex({ "description": "text" })  // اگر به ندرت جستجو می‌شود
```

### کوئری‌ها

- از کوئری‌های بهینه و کارآمد استفاده کنید.
- از پروجکشن برای محدود کردن فیلدهای بازگشتی استفاده کنید.
- از متد `lean()` برای خواندن‌های فقط-خواندنی استفاده کنید.

```javascript
// خوب
// دریافت وظایف یک پروژه با وضعیت مشخص
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

// بد
// دریافت تمام وظایف بدون فیلتر و پروجکشن
const tasks = await db.collection('tasks')
  .find({})
  .toArray();
```

## استانداردهای یکپارچه‌سازی با GitHub

### مدیریت وبهوک‌ها (Webhooks)

- از یک مسیر مشخص برای دریافت وبهوک‌ها استفاده کنید.
- امضای وبهوک را برای تأیید اعتبار سنجی کنید.
- رویدادهای وبهوک را به صورت ناهمزمان پردازش کنید.

```python
# خوب
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
    # تأیید امضای وبهوک
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
    
    # پردازش رویداد
    try:
        event_data = json.loads(payload)
        github_service = GitHubWebhookService()
        
        # پردازش ناهمزمان رویداد
        await github_service.process_webhook_event(x_github_event, event_data)
        
        return JSONResponse({"status": "success"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

// بد
// بدون تأیید امضا و پردازش همزمان
@app.post("/github/webhooks")
async def handle_github_webhook(request: Request):
    payload = await request.json()
    
    # پردازش همزمان رویداد
    if payload.get("action") == "opened":
        # پردازش Issue
        pass
    elif payload.get("ref") == "refs/heads/main":
        # پردازش Push
        pass
    
    return {"status": "success"}
```

### مدیریت توکن‌ها

- توکن‌های GitHub را به صورت امن ذخیره کنید.
- از توکن‌های با حداقل دسترسی‌های لازم استفاده کنید.
- توکن‌ها را منظم به‌روزرسانی کنید.

```python
# خوب
# backend/app/core/security.py
import os
from cryptography.fernet import Fernet

class TokenManager:
    def __init__(self):
        self.key = os.environ.get("ENCRYPTION_KEY")
        self.cipher_suite = Fernet(self.key.encode() if self.key else Fernet.generate_key())
    
    def encrypt_token(self, token: str) -> str:
        """رمزنگاری توکن."""
        return self.cipher_suite.encrypt(token.encode()).decode()
    
    def decrypt_token(self, encrypted_token: str) -> str:
        """رمزگشایی توکن."""
        return self.cipher_suite.decrypt(encrypted_token.encode()).decode()
    
    def get_github_token(self) -> str:
        """دریافت توکن GitHub."""
        encrypted_token = os.environ.get("GITHUB_TOKEN_ENCRYPTED")
        if not encrypted_token:
            raise ValueError("GitHub token not configured")
        
        return self.decrypt_token(encrypted_token)

// بد
// ذخیره توکن به صورت متن ساده
GITHUB_TOKEN = "ghp_YourGitHubTokenHere"
```

### پردازش رویدادها

- از یک سرویس اختصاصی برای پردازش رویدادهای GitHub استفاده کنید.
- رویدادها را بر اساس نوع و محتوا پردازش کنید.
- از الگوی استراتژی برای پردازش رویدادهای مختلف استفاده کنید.

```python
# خوب
# backend/app/services/github_service.py
from abc import ABC, abstractmethod
from typing import Dict, Any

class GitHubEventHandler(ABC):
    @abstractmethod
    async def handle(self, event_data: Dict[str, Any]) -> None:
        pass

class PushEventHandler(GitHubEventHandler):
    async def handle(self, event_data: Dict[str, Any]) -> None:
        # پردازش رویداد Push
        commits = event_data.get("commits", [])
        for commit in commits:
            await self._process_commit(commit)
    
    async def _process_commit(self, commit: Dict[str, Any]) -> None:
        # پردازش هر کامیت
        message = commit.get("message", "")
        if "ACT-" in message:
            task_id = self._extract_task_id(message)
            await self._update_task_status(task_id, "in_progress")
    
    def _extract_task_id(self, message: str) -> str:
        # استخراج شناسه وظیفه از پیام کامیت
        import re
        match = re.search(r'ACT-(\d+)', message)
        return match.group(1) if match else ""
    
    async def _update_task_status(self, task_id: str, status: str) -> None:
        # به‌روزرسانی وضعیت وظیفه
        pass

class IssuesEventHandler(GitHubEventHandler):
    async def handle(self, event_data: Dict[str, Any]) -> None:
        # پردازش رویداد Issues
        action = event_data.get("action")
        issue = event_data.get("issue", {})
        
        if action == "opened":
            await self._handle_issue_opened(issue)
        elif action == "closed":
            await self._handle_issue_closed(issue)
    
    async def _handle_issue_opened(self, issue: Dict[str, Any]) -> None:
        # مدیریت Issue جدید
        pass
    
    async def _handle_issue_closed(self, issue: Dict[str, Any]) -> None:
        # مدیریت Issue بسته شده
        pass

class GitHubWebhookService:
    def __init__(self):
        self._handlers = {
            "push": PushEventHandler(),
            "issues": IssuesEventHandler(),
            # سایر هندلرها
        }
    
    async def process_webhook_event(self, event_type: str, event_data: Dict[str, Any]) -> None:
        handler = self._handlers.get(event_type)
        if handler:
            await handler.handle(event_data)
        else:
            print(f"No handler found for event type: {event_type}")

// بد
// پردازش همه رویدادها در یک تابع بدون جداکاری
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
    # سایر رویدادها
```

## استانداردهای تست و دیباگ

### تست بک‌اند (پایتون)

- از pytest برای نوشتن تست‌ها استفاده کنید.
- از موک‌ها (mocks) برای ایزوله کردن تست‌ها استفاده کنید.
- تست‌ها را در پوشه `tests` با ساختار مشابه اپلیکیشن اصلی قرار دهید.

```python
# خوب
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
    # آماده‌سازی
    mock_db.insert_one.return_value.inserted_id = sample_task["_id"]
    
    # اجرا
    result = task_service.create_task(sample_task)
    
    # تأیید
    assert result["_id"] == sample_task["_id"]
    mock_db.insert_one.assert_called_once()

def test_get_task_by_id(task_service, mock_db, sample_task):
    # آماده‌سازی
    mock_db.find_one.return_value = sample_task
    
    # اجرا
    result = task_service.get_task_by_id(sample_task["_id"])
    
    # تأیید
    assert result["_id"] == sample_task["_id"]
    mock_db.find_one.assert_called_once_with({"_id": sample_task["_id"]})

def test_get_task_by_id_not_found(task_service, mock_db):
    # آماده‌سازی
    mock_db.find_one.return_value = None
    
    # اجرا و تأیید
    with pytest.raises(ValueError, match="Task not found"):
        task_service.get_task_by_id("nonexistent_id")

// بد
// بدون موک و تست‌های ساختاریافته
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

### تست فرانت‌اند (Next.js)

- از Jest و React Testing Library برای تست کامپوننت‌ها استفاده کنید.
- از Cypress برای تست‌های end-to-end استفاده کنید.
- تست‌ها را در پوشه `__tests__` یا کنار فایل‌های مربوطه قرار دهید.

```typescript
// خوب
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

// خوب
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

// بد
// بدون تست‌های ساختاریافته و بدون استفاده از کتابخانه‌های تست
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

## استانداردهای مستندسازی

### مستندسازی کد

- از docstrings برای مستندسازی توابع، کلاس‌ها و ماژول‌ها استفاده کنید.
- از کامنت‌ها برای توضیح منطق پیچیده استفاده کنید.
- از مستندات API برای توضیح endpointها استفاده کنید.

```python
# خوب
# backend/app/services/task_service.py
"""
سرویس مدیریت وظایف پروژه.

این سرویس عملیات مربوط به ایجاد، ویرایش، حذف و بازیابی وظایف را انجام می‌دهد.
"""

from typing import List, Optional
from datetime import datetime
from app.models.task import Task, TaskStatus
from app.database import get_database

class TaskService:
    """
    سرویس مدیریت وظایف.
    
    این کلاس عملیات مربوط به وظایف را پیاده‌سازی می‌کند.
    """
    
    def __init__(self, db=None):
        """
        مقداردهی اولیه سرویس.
        
        Args:
            db: اتصال به دیتابیس (اختیاری)
        """
        self.db = db or get_database()
    
    def create_task(self, task_data: dict) -> Task:
        """
        یک وظیفه جدید ایجاد می‌کند.
        
        Args:
            task_data (dict): داده‌های وظیفه شامل عنوان، توضیحات، پروژه و ...
            
        Returns:
            Task: شیء وظیفه ایجاد شده
            
        Raises:
            ValueError: اگر داده‌های ورودی نامعتبر باشند
        """
        # اعتبارسنجی داده‌های ورودی
        if not task_data.get('title'):
            raise ValueError("Task title is required")
        
        if not task_data.get('project_id'):
            raise ValueError("Project ID is required")
        
        # ایجاد وظیفه جدید
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
        
        # ذخیره وظیفه در دیتابیس
        result = self.db.tasks.insert_one(task.dict())
        task.id = result.inserted_id
        
        return task

// بد
// بدون مستندات مناسب
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

### مستندات API

- از OpenAPI/Swagger برای مستندسازی API استفاده کنید.
- تمام endpointها را مستند کنید.
- از مثال‌های واقعی برای مستندسازی استفاده کنید.

```python
# خوب
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
    یک وظیفه جدید ایجاد می‌کند.
    
    Args:
        task (TaskCreate): داده‌های وظیفه جدید
        current_user (dict): کاربر فعلی
        task_service (TaskService): سرویس وظایف
        
    Returns:
        Task: وظیفه ایجاد شده
        
    Raises:
        HTTPException: اگر داده‌های ورودی نامعتبر باشند
    """
    try:
        # افزودن شناسه کاربر فعلی به عنوان ایجاد کننده
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
    لیست وظایف را بر اساس فیلترهای مشخص شده برمی‌گرداند.
    
    Args:
        project_id (str, optional): شناسه پروژه برای فیلتر کردن
        status (TaskStatus, optional): وضعیت وظیفه برای فیلتر کردن
        assignee_id (str, optional): شناسه مسئول وظیفه برای فیلتر کردن
        skip (int, optional): تعداد وظایف برای پرش (برای صفحه‌بندی)
        limit (int, optional): حداکثر تعداد وظایف برای بازگشت
        current_user (dict): کاربر فعلی
        task_service (TaskService): سرویس وظایف
        
    Returns:
        List[Task]: لیست وظایف فیلتر شده
        
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

// بد
// بدون مستندات مناسب
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

## استانداردهای امنیتی

### احراز هویت و مجوزها

- از JWT برای احراز هویت استفاده کنید.
- از RBAC (Role-Based Access Control) برای مدیریت مجوزها استفاده کنید.
- توکن‌ها را به صورت امن ذخیره و مدیریت کنید.

```python
# خوب
# backend/app/core/auth.py
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status
import os

# تنظیمات JWT
SECRET_KEY = os.environ.get("SECRET_KEY", "your-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# تنظیمات رمز عبور
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class AuthService:
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """تأیید رمز عبور."""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """هش کردن رمز عبور."""
        return pwd_context.hash(password)
    
    @staticmethod
    def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """ایجاد توکن دسترسی."""
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
        """تأیید توکن و استخراج اطلاعات."""
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

# middleware برای بررسی احراز هویت
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse

async def auth_middleware(request: Request, call_next):
    # بررسی توکن در هدر درخواست
    token = request.headers.get("Authorization")
    if not token:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Authentication required"}
        )
    
    try:
        # تأیید توکن
        token = token.split(" ")[1]  # حذف "Bearer " از ابتدای توکن
        payload = AuthService.verify_token(token)
        
        # افزودن اطلاعات کاربر به درخواست
        request.state.user = payload
        
        # ادامه پردازش درخواست
        response = await call_next(request)
        return response
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Invalid or expired token"}
        )

// بد
// بدون امنیت مناسب
def create_token(username):
    return f"token-{username}-{datetime.now().timestamp()}"

def verify_token(token):
    parts = token.split("-")
    if len(parts) < 3:
        return None
    
    username = parts[1]
    timestamp = float(parts[2])
    
    # بررسی انقضای توکن (24 ساعت)
    if datetime.now().timestamp() - timestamp > 86400:
        return None
    
    return {"sub": username}
```

### اعتبارسنجی ورودی‌ها

- از Pydantic برای اعتبارسنجی ورودی‌ها در بک‌اند استفاده کنید.
- از PropTypes یا TypeScript برای اعتبارسنجی props در فرانت‌اند استفاده کنید.
- ورودی‌های کاربر را همیشه اعتبارسنجی کنید.

```python
# خوب
# backend/app/models/task.py
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    """وضعیت‌های مجاز وظیفه."""
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    REVIEW = "review"
    DONE = "done"

class TaskPriority(str, Enum):
    """اولویت‌های مجاز وظیفه."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class TaskBase(BaseModel):
    """مدل پایه وظیفه."""
    title: str = Field(..., min_length=1, max_length=100, description="عنوان وظیفه")
    description: Optional[str] = Field("", max_length=1000, description="توضیحات وظیفه")
    project_id: str = Field(..., description="شناسه پروژه")
    assignee_id: Optional[str] = Field(None, description="شناسه مسئول وظیفه")
    status: TaskStatus = Field(TaskStatus.TODO, description="وضعیت وظیفه")
    priority: TaskPriority = Field(TaskPriority.MEDIUM, description="اولویت وظیفه")
    due_date: Optional[datetime] = Field(None, description="تاریخ سررسید")
    dependencies: Optional[List[str]] = Field([], description="شناسه وظایف وابسته")
    
    @validator('title')
    def validate_title(cls, v):
        """اعتبارسنجی عنوان وظیفه."""
        if not v.strip():
            raise ValueError("Title cannot be empty")
        return v.strip()
    
    @validator('due_date')
    def validate_due_date(cls, v, values):
        """اعتبارسنجی تاریخ سررسید."""
        if v and v < datetime.now():
            raise ValueError("Due date cannot be in the past")
        return v

class TaskCreate(TaskBase):
    """مدل ایجاد وظیفه."""
    pass

class TaskUpdate(BaseModel):
    """مدل به‌روزرسانی وظیفه."""
    title: Optional[str] = Field(None, min_length=1, max_length=100, description="عنوان وظیفه")
    description: Optional[str] = Field(None, max_length=1000, description="توضیحات وظیفه")
    assignee_id: Optional[str] = Field(None, description="شناسه مسئول وظیفه")
    status: Optional[TaskStatus] = Field(None, description="وضعیت وظیفه")
    priority: Optional[TaskPriority] = Field(None, description="اولویت وظیفه")
    due_date: Optional[datetime] = Field(None, description="تاریخ سررسید")
    dependencies: Optional[List[str]] = Field(None, description="شناسه وظایف وابسته")

class Task(TaskBase):
    """مدل کامل وظیفه."""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True

// بد
// بدون اعتبارسنجی مناسب
class TaskBase(BaseModel):
    title: str
    description: Optional[str] = ""
    project_id: str
    assignee_id: Optional[str] = None
    status: str = "todo"
    priority: str = "medium"
    due_date: Optional[datetime] = None
    dependencies: Optional[List[str]] = []
```

```typescript
// خوب
// frontend/types/task.ts
export interface Task {
  id: string;
  title: string;
  description: string;
  project_id: string;
  assignee_id?: string;
  status: TaskStatus;
  priority: TaskPriority;
  due_date?: Date;
  dependencies: string[];
  created_at: Date;
  updated_at: Date;
}

export type TaskStatus = "todo" | "in_progress" | "review" | "done";
export type TaskPriority = "low" | "medium" | "high";

export interface TaskCreate {
  title: string;
  description?: string;
  project_id: string;
  assignee_id?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  due_date?: Date;
  dependencies?: string[];
}

export interface TaskUpdate {
  title?: string;
  description?: string;
  assignee_id?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  due_date?: Date;
  dependencies?: string[];
}

// frontend/components/TaskForm.tsx
import React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { TaskCreate, TaskStatus, TaskPriority } from '@/types/task';

const taskSchema = z.object({
  title: z.string().min(1, 'Title is required').max(100, 'Title must be less than 100 characters'),
  description: z.string().max(1000, 'Description must be less than 1000 characters').optional(),
  project_id: z.string().min(1, 'Project ID is required'),
  assignee_id: z.string().optional(),
  status: z.enum(['todo', 'in_progress', 'review', 'done']).optional(),
  priority: z.enum(['low', 'medium', 'high']).optional(),
  due_date: z.date().optional(),
  dependencies: z.array(z.string()).optional(),
});

type TaskFormData = z.infer<typeof taskSchema>;

interface TaskFormProps {
  onSubmit: (data: TaskCreate) => void;
  initialValues?: Partial<TaskCreate>;
  isLoading?: boolean;
}

const TaskForm: React.FC<TaskFormProps> = ({ onSubmit, initialValues, isLoading = false }) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<TaskFormData>({
    resolver: zodResolver(taskSchema),
    defaultValues: initialValues,
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div className="form-group">
        <label htmlFor="title">Title</label>
        <input
          id="title"
          type="text"
          className={errors.title ? 'error' : ''}
          {...register('title')}
        />
        {errors.title && <span className="error-message">{errors.title.message}</span>}
      </div>
      
      <div className="form-group">
        <label htmlFor="description">Description</label>
        <textarea
          id="description"
          className={errors.description ? 'error' : ''}
          {...register('description')}
        />
        {errors.description && <span className="error-message">{errors.description.message}</span>}
      </div>
      
      {/* سایر فیلدها */}
      
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Saving...' : 'Save Task'}
      </button>
    </form>
  );
};

// بد
// بدون اعتبارسنجی مناسب
interface TaskFormProps {
  onSubmit: (data: any) => void;
  initialValues?: any;
  isLoading?: boolean;
}

const TaskForm: React.FC<TaskFormProps> = ({ onSubmit, initialValues, isLoading = false }) => {
  const [title, setTitle] = React.useState(initialValues?.title || '');
  const [description, setDescription] = React.useState(initialValues?.description || '');
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({
      title,
      description,
      // سایر فیلدها
    });
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label>Title</label>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
      </div>
      
      <div>
        <label>Description</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
      </div>
      
      {/* سایر فیلدها */}
      
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Saving...' : 'Save Task'}
      </button>
    </form>
  );
};
```

## استانداردهای عملکرد و بهینه‌سازی

### بهینه‌سازی بک‌اند

- از اتصال‌های pooling برای دیتابیس استفاده کنید.
- از کش برای داده‌های پرکاربرد استفاده کنید.
- کوئری‌های دیتابیس را بهینه کنید.

```python
# خوب
# backend/app/core/database.py
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo.errors import ConnectionFailure
import os
from functools import lru_cache
import asyncio

class Database:
    _instance = None
    _client = None
    _db = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Database, cls).__new__(cls)
        return cls._instance
    
    async def connect(self):
        """اتصال به دیتابیس."""
        if self._client is None:
            try:
                mongo_url = os.environ.get("MONGODB_URL", "mongodb://localhost:27017")
                self._client = AsyncIOMotorClient(
                    mongo_url,
                    maxPoolSize=10,  # حداکثر تعداد اتصال‌ها
                    minPoolSize=1,   # حداقل تعداد اتصال‌ها
                    maxIdleTimeMS=30000,  # حداکثر زمان عدم استفاده از اتصال
                    serverSelectionTimeoutMS=5000,  # زمان انتظار برای انتخاب سرور
                    connectTimeoutMS=10000,  # زمان انتظار برای اتصال
                )
                self._db = self._client.gravitypm
                # تست اتصال
                await self._client.admin.command('ping')
                print("Connected to MongoDB")
            except ConnectionFailure as e:
                print(f"Could not connect to MongoDB: {e}")
                raise
    
    async def close(self):
        """بستن اتصال به دیتابیس."""
        if self._client:
            self._client.close()
            self._client = None
            self._db = None
            print("Disconnected from MongoDB")
    
    def get_db(self) -> AsyncIOMotorDatabase:
        """دریافت اتصال دیتابیس."""
        if self._db is None:
            raise RuntimeError("Database not connected")
        return self._db

# تابع برای دریافت اتصال دیتابیس
@lru_cache()
def get_database():
    """دریافت اتصال دیتابیس."""
    return Database()

// بد
// بدون pooling و مدیریت اتصال
from motor.motor_asyncio import AsyncIOMotorClient
import os

client = AsyncIOMotorClient(os.environ.get("MONGODB_URL", "mongodb://localhost:27017"))
db = client.gravitypm
```

### بهینه‌سازی فرانت‌اند

- از React.memo برای جلوگیری از رندرهای غیرضروری استفاده کنید.
- از useMemo و useCallback برای بهینه‌سازی کامپوننت‌ها استفاده کنید.
- از code splitting برای کاهش حجم باندل استفاده کنید.

```typescript
// خوب
// frontend/components/TaskList.tsx
import React, { memo, useMemo, useCallback } from 'react';
import { Task } from '@/types/task';
import TaskCard from './TaskCard';

interface TaskListProps {
  tasks: Task[];
  onStatusChange: (taskId: string, status: TaskStatus) => void;
  onEdit: (task: Task) => void;
  onDelete: (taskId: string) => void;
}

const TaskList: React.FC<TaskListProps> = memo(({ 
  tasks, 
  onStatusChange, 
  onEdit, 
  onDelete 
}) => {
  // گروه‌بندی وظایف بر اساس وضعیت
  const groupedTasks = useMemo(() => {
    return tasks.reduce((acc, task) => {
      if (!acc[task.status]) {
        acc[task.status] = [];
      }
      acc[task.status].push(task);
      return acc;
    }, {} as Record<string, Task[]>);
  }, [tasks]);

  // توابع کنترل‌کننده با استفاده از useCallback برای جلوگیری از ایجاد مجدد
  const handleStatusChange = useCallback((taskId: string, status: TaskStatus) => {
    onStatusChange(taskId, status);
  }, [onStatusChange]);

  const handleEdit = useCallback((task: Task) => {
    onEdit(task);
  }, [onEdit]);

  const handleDelete = useCallback((taskId: string) => {
    onDelete(taskId);
  }, [onDelete]);

  return (
    <div className="task-list">
      {Object.entries(groupedTasks).map(([status, statusTasks]) => (
        <div key={status} className="task-column">
          <h2 className="task-column-title">{status}</h2>
          <div className="task-column-content">
            {statusTasks.map(task => (
              <TaskCard
                key={task.id}
                task={task}
                onStatusChange={handleStatusChange}
                onEdit={handleEdit}
                onDelete={handleDelete}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
});

TaskList.displayName = 'TaskList';

export default TaskList;

// خوب
// frontend/app/dashboard/page.tsx
import React, { Suspense } from 'react';
import TaskList from '@/components/TaskList';
import ProjectList from '@/components/ProjectList';
import LoadingSpinner from '@/components/LoadingSpinner';

// بارگذاری تنبل برای کامپوننت‌های سنگین
const HeavyComponent = React.lazy(() => import('@/components/HeavyComponent'));

const DashboardPage: React.FC = () => {
  return (
    <div className="dashboard">
      <h1>Dashboard</h1>
      
      <div className="dashboard-content">
        <div className="dashboard-section">
          <h2>Projects</h2>
          <ProjectList />
        </div>
        
        <div className="dashboard-section">
          <h2>Tasks</h2>
          <TaskList />
        </div>
        
        <div className="dashboard-section">
          <h2>Analytics</h2>
          <Suspense fallback={<LoadingSpinner />}>
            <HeavyComponent />
          </Suspense>
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;

// بد
// بدون بهینه‌سازی
const TaskList: React.FC<TaskListProps> = ({ 
  tasks, 
  onStatusChange, 
  onEdit, 
  onDelete 
}) => {
  // گروه‌بندی وظایف بر اساس وضعیت
  const groupedTasks = tasks.reduce((acc, task) => {
    if (!acc[task.status]) {
      acc[task.status] = [];
    }
    acc[task.status].push(task);
    return acc;
  }, {} as Record<string, Task[]>);

  return (
    <div className="task-list">
      {Object.entries(groupedTasks).map(([status, statusTasks]) => (
        <div key={status} className="task-column">
          <h2 className="task-column-title">{status}</h2>
          <div className="task-column-content">
            {statusTasks.map(task => (
              <TaskCard
                key={task.id}
                task={task}
                onStatusChange={onStatusChange}
                onEdit={onEdit}
                onDelete={onDelete}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};
```

## نتیجه‌گیری

این استانداردهای کدنویسی برای پروژه GravityPM طراحی شده‌اند تا کیفیت، خوانایی، قابلیت نگهداری و عملکرد کدها را تضمین کنند. رعایت این استانداردها به تیم توسعه کمک می‌کند تا کدهای یکپارچه و قابل فهم تولید کند و فرآیندهای توسعه، تست و دیباگ را تسهیل کند.

این استانداردها باید به صورت مستند به روز نگه داشته شوند و در صورت نیاز به‌روزرسانی شوند. تمام اعضای تیم باید با این استانداردها آشنا باشند و در کدنویسی خود از آن‌ها پیروی کنند.