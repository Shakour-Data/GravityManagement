#!/bin/bash

# Script to commit and push remaining changes with appropriate messages per file, then delete itself

# Get current branch name
branch=$(git rev-parse --abbrev-ref HEAD)

# Check if branch name is empty
if [ -z "$branch" ]; then
  echo "Could not determine current branch."
  exit 1
fi

# Get list of changed files (staged and unstaged)
files=$(git diff --name-only)

# Get list of untracked files
untracked=$(git ls-files --others --exclude-standard)

# Combine all files
all_files="$files $untracked"

if [ -z "$all_files" ]; then
  echo "No changes to commit."
  rm -- "$0"
  exit 0
fi

# Commit each file separately with a message
for file in $all_files; do
  if [ -f "$file" ]; then
    git add "$file"
    # Create a commit message based on file path and name
    commit_message="Update $file"
    git commit -m "$commit_message"
  fi
done

# Push the current branch
git push origin "$branch"

# Delete this script
rm -- "$0"
