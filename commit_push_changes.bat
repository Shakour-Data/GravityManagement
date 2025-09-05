@echo off
REM Script to commit and push all changes file by file with appropriate messages

REM Add all changes
git add .

REM Get list of changed files and commit each one
for /f "delims=" %%f in ('git diff --cached --name-only') do (
    echo Committing file: %%f
    git commit -m "Update %%f - organized tests folder and added unit tests"
)

REM Push to current branch
git push

REM Delete this script
del "%~f0"
