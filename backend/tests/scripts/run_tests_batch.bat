@echo off
echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing dependencies...
pip install -r requirements.txt
pip install fastapi[all] python-jose[cryptography] passlib[bcrypt] redis

echo Running tests...
python -m pytest tests/ -v --tb=short --asyncio-mode=auto > test_output.txt 2>&1

echo Test output saved to test_output.txt
pause
