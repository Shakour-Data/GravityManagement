@echo off
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo Failed to activate virtual environment
    pause
    exit /b 1
)

echo Installing dependencies if needed...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo Failed to install dependencies
    pause
    exit /b 1
)

echo Running tests...
python -m pytest tests/ -v --tb=short
if %errorlevel% neq 0 (
    echo Tests failed with exit code %errorlevel%
) else (
    echo Tests completed successfully
)

pause
