from .auth import router as auth
from .projects import router as projects
from .tasks import router as tasks
from .resources import router as resources
from .github_integration import router as github_integration
from .rules import router as rules

# WebSocket router for real-time updates
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from ..services.websocket_manager import manager

ws_router = APIRouter()

@ws_router.websocket("/updates")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Echo received message for demo; in real app, broadcast updates
            await manager.broadcast(f"Message: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
