@echo off
echo Setting up GravityManagement local environment...

REM Docker not available, skipping MongoDB and Redis setup.
echo Note: MongoDB and Redis not started. Backend will run in demo mode without database.

REM Backend setup
if not exist backend\venv (
    echo Setting up backend virtual environment and installing dependencies...
    cd backend
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install -r requirements.txt
    cd ..
)

REM Frontend setup
if not exist frontend\node_modules (
    echo Installing frontend dependencies...
    cd frontend
    npm install
    cd ..
)

REM Start backend if not running
tasklist | findstr uvicorn >nul
if %errorlevel% neq 0 (
    echo Starting backend server...
    start /b cmd /c "cd backend && call venv\Scripts\activate.bat && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
)

REM Start frontend if not running
tasklist | findstr node >nul
if %errorlevel% neq 0 (
    echo Starting frontend server...
    start /b cmd /c "cd frontend && npm run dev"
)

echo Setup complete!
echo Backend API: http://localhost:8000
echo Frontend: http://localhost:3000
echo MongoDB: localhost:27017
echo Redis: localhost:6379
echo.
echo Press any key to open the browser...
pause >nul
start http://localhost:3000
