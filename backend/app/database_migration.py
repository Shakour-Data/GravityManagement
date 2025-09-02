#!/usr/bin/env python3
"""
Database migration script for creating indexes.
Run this script to initialize database indexes for better query performance.
"""

import asyncio
from database import connect_to_mongo, create_indexes, close_mongo_connection

async def main():
    """
    Main function to run database migration.
    """
    try:
        print("Connecting to MongoDB...")
        await connect_to_mongo()

        print("Creating indexes...")
        await create_indexes()

        print("Migration completed successfully!")

    except Exception as e:
        print(f"Migration failed: {e}")
        raise
    finally:
        await close_mongo_connection()

if __name__ == "__main__":
    asyncio.run(main())
