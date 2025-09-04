# Script to commit and push all changes with appropriate commit messages per file, then delete itself

function Get-CommitMessage {
    param([string]$file)
    switch ($file) {
        "TODO_GPM.md" { "Update TODO_GPM.md with latest progress" }
        "backend/app/routers/__init__.py" { "Refactor WebSocket router and connection manager" }
        "backend/app/services/project_service.py" { "Add WebSocket broadcast for project events" }
        "backend/app/services/task_service.py" { "Add WebSocket broadcast for task events" }
        "frontend/TODO_Front.md" { "Update frontend TODO list with completed tasks" }
        "frontend/app/layout.tsx" { "Update layout component for frontend" }
        "frontend/app/projects/[id]/page.tsx" { "Enhance project detail page" }
        "frontend/app/resources/[id]/page.tsx" { "Enhance resource detail page" }
        "frontend/jest.setup.js" { "Fix jest setup import for testing-library" }
        default { "Update $file" }
    }
}

# Stage and commit modified files individually
$modifiedFiles = git diff --name-only --diff-filter=M
foreach ($file in $modifiedFiles) {
    git add $file
    $msg = Get-CommitMessage $file
    git commit -m $msg
}

# Stage and commit untracked files individually
$untrackedFiles = git ls-files --others --exclude-standard
foreach ($file in $untrackedFiles) {
    git add $file
    $msg = Get-CommitMessage $file
    git commit -m $msg
}

# Push commits to current branch
$currentBranch = git rev-parse --abbrev-ref HEAD
git push origin $currentBranch

# Remove this script
Remove-Item $MyInvocation.MyCommand.Path
