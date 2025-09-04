#!/bin/bash
# Script to commit and push all changes with appropriate messages per file, then delete itself

# Get current branch name
branch=$(git rev-parse --abbrev-ref HEAD)

# Add all changes
git add .

# Get list of changed files
files=$(git diff --cached --name-only)

# Commit each file separately with a message
for file in $files; do
  git commit -m "Update $file"
done

# Push the branch
git push origin "$branch"

# Delete this script
rm -- "$0"
