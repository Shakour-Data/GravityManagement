from typing import Dict, Any, List
import os
import uuid
from datetime import datetime
from pathlib import Path
from fastapi import UploadFile, HTTPException
from ..database import get_database

class FileService:
    def __init__(self):
        self.db = get_database()
        self.upload_dir = Path(os.getenv("UPLOAD_DIR", "uploads"))
        self.upload_dir.mkdir(exist_ok=True)
        self.max_file_size = int(os.getenv("MAX_FILE_SIZE", "10485760"))  # 10MB default
        self.allowed_extensions = os.getenv("ALLOWED_EXTENSIONS", "pdf,doc,docx,txt,jpg,jpeg,png,gif").split(",")

    async def upload_file(self, file: UploadFile, uploaded_by: str, project_id: str = None) -> Dict[str, Any]:
        """
        Upload a file and store metadata
        """
        # Validate file
        if file.size > self.max_file_size:
            raise HTTPException(status_code=400, detail=f"File too large. Max size: {self.max_file_size} bytes")

        file_ext = Path(file.filename).suffix.lower().lstrip('.')
        if file_ext not in self.allowed_extensions:
            raise HTTPException(status_code=400, detail=f"File type not allowed. Allowed: {', '.join(self.allowed_extensions)}")

        # Generate unique filename
        unique_filename = f"{uuid.uuid4()}_{file.filename}"
        file_path = self.upload_dir / unique_filename

        # Save file
        try:
            with open(file_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")

        # Store metadata in database
        file_metadata = {
            "original_filename": file.filename,
            "stored_filename": unique_filename,
            "file_path": str(file_path),
            "file_size": file.size,
            "file_type": file.content_type,
            "file_extension": file_ext,
            "uploaded_by": uploaded_by,
            "project_id": project_id,
            "uploaded_at": datetime.utcnow(),
            "download_count": 0
        }

        result = await self.db.files.insert_one(file_metadata)
        file_metadata["_id"] = result.inserted_id

        return {
            "file_id": str(result.inserted_id),
            "filename": file.filename,
            "size": file.size,
            "uploaded_at": file_metadata["uploaded_at"],
            "message": "File uploaded successfully"
        }

    async def get_file_metadata(self, file_id: str) -> Dict[str, Any]:
        """
        Get file metadata by ID
        """
        file_doc = await self.db.files.find_one({"_id": file_id})
        if not file_doc:
            raise HTTPException(status_code=404, detail="File not found")

        return {
            "file_id": str(file_doc["_id"]),
            "original_filename": file_doc["original_filename"],
            "file_size": file_doc["file_size"],
            "file_type": file_doc["file_type"],
            "uploaded_by": file_doc["uploaded_by"],
            "project_id": file_doc["project_id"],
            "uploaded_at": file_doc["uploaded_at"],
            "download_count": file_doc["download_count"]
        }

    async def download_file(self, file_id: str) -> Dict[str, Any]:
        """
        Get file path for download and increment download count
        """
        file_doc = await self.db.files.find_one({"_id": file_id})
        if not file_doc:
            raise HTTPException(status_code=404, detail="File not found")

        file_path = Path(file_doc["file_path"])
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File not found on disk")

        # Increment download count
        await self.db.files.update_one(
            {"_id": file_id},
            {"$inc": {"download_count": 1}}
        )

        return {
            "file_path": str(file_path),
            "original_filename": file_doc["original_filename"],
            "file_type": file_doc["file_type"]
        }

    async def delete_file(self, file_id: str, deleted_by: str) -> Dict[str, Any]:
        """
        Delete a file and its metadata
        """
        file_doc = await self.db.files.find_one({"_id": file_id})
        if not file_doc:
            raise HTTPException(status_code=404, detail="File not found")

        file_path = Path(file_doc["file_path"])

        # Delete physical file
        if file_path.exists():
            try:
                file_path.unlink()
            except Exception as e:
                # Log error but continue with database deletion
                print(f"Failed to delete physical file: {str(e)}")

        # Delete metadata
        await self.db.files.update_one(
            {"_id": file_id},
            {"$set": {
                "deleted": True,
                "deleted_by": deleted_by,
                "deleted_at": datetime.utcnow()
            }}
        )

        return {"message": "File deleted successfully"}

    async def list_project_files(self, project_id: str) -> List[Dict[str, Any]]:
        """
        List all files for a project
        """
        files = await self.db.files.find(
            {"project_id": project_id, "deleted": {"$ne": True}}
        ).sort("uploaded_at", -1).to_list(length=None)

        return [{
            "file_id": str(file["_id"]),
            "original_filename": file["original_filename"],
            "file_size": file["file_size"],
            "file_type": file["file_type"],
            "uploaded_by": file["uploaded_by"],
            "uploaded_at": file["uploaded_at"],
            "download_count": file["download_count"]
        } for file in files]

    async def get_storage_stats(self) -> Dict[str, Any]:
        """
        Get storage statistics
        """
        total_files = await self.db.files.count_documents({"deleted": {"$ne": True}})
        total_size = await self.db.files.aggregate([
            {"$match": {"deleted": {"$ne": True}}},
            {"$group": {"_id": None, "total_size": {"$sum": "$file_size"}}}
        ]).to_list(length=1)

        total_size_bytes = total_size[0]["total_size"] if total_size else 0

        return {
            "total_files": total_files,
            "total_size_bytes": total_size_bytes,
            "total_size_mb": round(total_size_bytes / (1024 * 1024), 2),
            "upload_dir": str(self.upload_dir)
        }

file_service = FileService()
