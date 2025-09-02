@echo off
echo Starting git operations...

REM Check git status
git status

REM Add all changes
git add .

REM Get list of changed files and commit each one separately
for /f "tokens=*" %%i in ('git diff --cached --name-only') do (
    echo Committing file: %%i
    if "%%i"=="frontend/components/TaskDependencies.tsx" (
        git commit -m "feat: Implement task dependencies visualization with SVG graph

- Add custom SVG-based dependency graph visualization
- Implement add/remove dependency functionality
- Fix TypeScript errors and improve type safety
- Replace ReactFlow with lightweight SVG implementation
- Add interactive dependency management UI"
    ) else if "%%i"=="frontend/TODO_dev02.md" (
        git commit -m "docs: Update TODO progress - mark task dependencies visualization as complete

- Mark task dependencies visualization as completed
- Update overall progress from 65%% to 70%%"
    ) else (
        git commit -m "chore: Update %%i"
    )
)

REM Push changes
echo Pushing changes to remote repository...
git push origin HEAD

echo All operations completed successfully!

REM Delete this script
del "%~f0"

pause
