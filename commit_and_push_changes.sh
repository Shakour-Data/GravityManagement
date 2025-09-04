#!/bin/bash
# Script to commit and push all changes with appropriate commit messages per file, then delete itself

# Function to get a commit message based on file path
get_commit_message() {
  case "$1" in
    "TODO_GPM.md")
      echo "Update TODO_GPM.md with latest progress"
      ;;
    "backend/app/routers/__init__.py")
      echo "Refactor WebSocket router and connection manager"
      ;;
    "backend/app/services/project_service.py")
      echo "Add WebSocket broadcast for project events"
      ;;
    "backend/app/services/task_service.py")
      echo "Add WebSocket broadcast for task events"
      ;;
    "frontend/TODO_Front.md")
      echo "Update frontend TODO list with completed tasks"
      ;;
    "frontend/app/layout.tsx")
      echo "Update layout component for frontend"
      ;;
    "frontend/app/projects/[id]/page.tsx")
      echo "Enhance project detail page"
      ;;
    "frontend/app/resources/[id]/page.tsx")
      echo "Enhance resource detail page"
      ;;
    "frontend/jest.setup.js")
      echo "Fix jest setup import for testing-library"
      ;;
    *)
      echo "Update $1"
      ;;
  esac
}

# Stage and commit modified files individually
git diff --name-only --diff-filter=M | while read file; do
  git add "$file"
  msg=$(get_commit_message "$file")
  git commit -m "$msg"
done

# Stage and commit untracked files individually
git ls-files --others --exclude-standard | while read file; do
  git add "$file"
  msg=$(get_commit_message "$file")
  git commit -m "$msg"
done

# Push commits to current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
git push origin "$current_branch"

# Remove this script
rm -- "$0"
