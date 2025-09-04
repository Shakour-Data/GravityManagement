from fastapi import WebSocket, WebSocketDisconnect
from typing import List
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                print(f"Error broadcasting to connection: {e}")
                # Remove broken connections
                self.active_connections.remove(connection)

    async def broadcast_event(self, event_type: str, data: dict):
        message = json.dumps({"event": event_type, "data": data})
        await self.broadcast(message)

# Singleton instance
manager = ConnectionManager()
