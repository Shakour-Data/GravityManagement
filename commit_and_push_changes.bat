@echo off
REM Script to commit and push all changes with appropriate commit messages per file, then delete itself

REM Function to get a commit message based on file path
:get_commit_message
set "file=%~1"
if "%file%"=="TODO_GPM.md" (
    set "msg=Update TODO_GPM.md with latest progress"
) else if "%file%"=="backend\app\routers\__init__.py" (
    set "msg=Refactor WebSocket router and connection manager"
) else if "%file%"=="backend\app\services\project_service.py" (
    set "msg=Add WebSocket broadcast for project events"
) else if "%file%"=="backend\app\services\task_service.py" (
    set "msg=Add WebSocket broadcast for task events"
) else if "%file%"=="frontend\TODO_Front.md" (
    set "msg=Update frontend TODO list with completed tasks"
) else if "%file%"=="frontend\app\layout.tsx" (
    set "msg=Update layout component for frontend"
) else if "%file%"=="frontend\app\projects\[id]\page.tsx" (
    set "msg=Enhance project detail page"
) else if "%file%"=="frontend\app\resources\[id]\page.tsx" (
    set "msg=Enhance resource detail page"
) else if "%file%"=="frontend\jest.setup.js" (
    set "msg=Fix jest setup import for testing-library"
) else (
    set "msg=Update %file%"
)
goto :eof

REM Stage and commit modified files individually
for /f "tokens=*" %%f in ('git diff --name-only --diff-filter=M') do (
    git add "%%f"
    call :get_commit_message "%%f"
    git commit -m "%msg%"
)

REM Stage and commit untracked files individually
for /f "tokens=*" %%f in ('git ls-files --others --exclude-standard') do (
    git add "%%f"
    call :get_commit_message "%%f"
    git commit -m "%msg%"
)

REM Push commits to current branch
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set current_branch=%%b
git push origin %current_branch%

REM Remove this script
del "%~f0"
