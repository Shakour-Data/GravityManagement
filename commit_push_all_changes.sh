#!/bin/bash
# Script to commit and push all remaining changes with appropriate messages per file, then delete itself

# Get current branch name
branch=$(git rev-parse --abbrev-ref HEAD)

# Add all changes
git add .

# Get list of changed files
files=$(git diff --cached --name-only)

# If no files to commit, exit
if [ -z "$files" ]; then
  echo "No changes to commit"
  rm -- "$0"
  exit 0
fi

# Commit each file separately with appropriate message based on file type
for file in $files; do
  if [[ $file == *.py ]]; then
    git commit -m "Update Python file: $file"
  elif [[ $file == *.js || $file == *.jsx ]]; then
    git commit -m "Update JavaScript file: $file"
  elif [[ $file == *.ts || $file == *.tsx ]]; then
    git commit -m "Update TypeScript file: $file"
  elif [[ $file == *.json ]]; then
    git commit -m "Update configuration file: $file"
  elif [[ $file == *.md ]]; then
    git commit -m "Update documentation: $file"
  elif [[ $file == *.sh ]]; then
    git commit -m "Update shell script: $file"
  elif [[ $file == *.yml || $file == *.yaml ]]; then
    git commit -m "Update YAML configuration: $file"
  elif [[ $file == *.sql ]]; then
    git commit -m "Update database schema: $file"
  elif [[ $file == *.php ]]; then
    git commit -m "Update PHP file: $file"
  else
    git commit -m "Update file: $file"
  fi
done

# Push the branch
git push origin "$branch"

# Delete this script
rm -- "$0"
