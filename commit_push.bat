@echo off
echo Starting commit and push process...

REM Add all changes
git add .

REM Commit each file separately with appropriate messages
for /f "tokens=*" %%i in ('git diff --cached --name-only') do (
    if "%%i"=="frontend/lib/hooks.ts" (
        git commit -m "feat: Add resource CRUD hooks (useResource, useCreateResource, useUpdateResource, useDeleteResource)" -- %%i
    ) else if "%%i"=="frontend/app/resources/page.tsx" (
        git commit -m "feat: Create resource management page with filtering, charts, and table view" -- %%i
    ) else if "%%i"=="frontend/app/resources/[id]/page.tsx" (
        git commit -m "feat: Create resource detail page with allocation interface and utilization charts" -- %%i
    ) else if "%%i"=="frontend/TODO_progress.md" (
        git commit -m "docs: Update TODO progress - mark resource management tasks as completed" -- %%i
    ) else (
        git commit -m "feat: Update %%i" -- %%i
    )
)

REM Push all commits
git push origin main

echo All changes committed and pushed successfully!

REM Delete this script
del "%~f0"

echo Script deleted. Process complete.
