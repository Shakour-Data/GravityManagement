from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from .routers import auth, projects, tasks, resources, github_integration, rules
from .routers import ws_router
from .database import connect_to_mongo, close_mongo_connection
from .services.cache_service import cache_service

# Rate limiting
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="GravityPM API", version="1.0.0")

# Add rate limiting middleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

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
    from .database import create_indexes
    await create_indexes()
    await cache_service.initialize()

@app.on_event("shutdown")
async def shutdown_event():
    await close_mongo_connection()

# Include routers
app.include_router(auth, prefix="/auth", tags=["Authentication"])
app.include_router(projects, prefix="/projects", tags=["Projects"])
app.include_router(tasks, prefix="/tasks", tags=["Tasks"])
app.include_router(resources, prefix="/resources", tags=["Resources"])
app.include_router(rules, prefix="/rules", tags=["Rules"])
app.include_router(github_integration, prefix="/github", tags=["GitHub Integration"])
app.include_router(ws_router, prefix="/ws", tags=["WebSocket"])

@app.get("/")
async def root():
    return {"message": "Welcome to GravityPM API"}
