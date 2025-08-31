from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import auth, projects, tasks, resources, github_integration
from .database import connect_to_mongo, close_mongo_connection

app = FastAPI(title="GravityPM API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Next.js dev server
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database events
@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()

@app.on_event("shutdown")
async def shutdown_event():
    await close_mongo_connection()

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(projects.router, prefix="/projects", tags=["Projects"])
app.include_router(tasks.router, prefix="/tasks", tags=["Tasks"])
app.include_router(resources.router, prefix="/resources", tags=["Resources"])
app.include_router(github_integration.router, prefix="/github", tags=["GitHub Integration"])

@app.get("/")
async def root():
    return {"message": "Welcome to GravityPM API"}
