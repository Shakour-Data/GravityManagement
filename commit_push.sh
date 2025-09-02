#!/bin/bash

# Get list of changed files
files=$(git status --porcelain | awk '{print $2}')

# Loop through each file
for file in $files; do
    # Skip __pycache__ files
    if [[ $file == *"/__pycache__/"* ]]; then
        continue
    fi

    # Determine message based on file type
    if [[ $file == *.py ]]; then
        msg="Update Python file: $file"
    elif [[ $file == *.md ]]; then
        msg="Update documentation: $file"
    elif [[ $file == *.json ]]; then
        msg="Update configuration: $file"
    elif [[ $file == *.txt ]]; then
        msg="Update text file: $file"
    else
        msg="Update file: $file"
    fi

    # Add and commit
    git add "$file"
    git commit -m "$msg"
done

# Push all commits
git push

# Delete this script
rm -- "$0"
