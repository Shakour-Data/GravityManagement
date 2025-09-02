@echo off
echo Starting commit and push process...

REM Add all changes
git add .

REM Get list of changed files
for /f "tokens=*" %%i in ('git diff --cached --name-only') do (
    echo Committing file: %%i

    REM Create appropriate commit message based on file type
    if "%%~xi"==".tsx" (
        git commit -m "feat: Add %%~ni component - %%i"
    ) else if "%%~xi"==".ts" (
        git commit -m "feat: Add %%~ni utility - %%i"
    ) else if "%%~xi"==".md" (
        git commit -m "docs: Update %%~ni documentation - %%i"
    ) else if "%%~xi"==".json" (
        git commit -m "config: Update %%~ni configuration - %%i"
    ) else (
        git commit -m "feat: Add/update %%i"
    )
)

REM Push all commits
echo Pushing to repository...
git push origin main

echo All changes committed and pushed successfully!

REM Delete this script
del "%~f0"
