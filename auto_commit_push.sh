#!/bin/bash

# Script to commit and push all changes with appropriate messages for each file separately, then delete itself

# Get list of changed files
changed_lines=$(git status --porcelain)

if [ -z "$changed_lines" ]; then
    echo "No changes to commit."
    rm "$0"
    exit 0
fi

while IFS= read -r line; do
    status=$(echo "$line" | cut -c1)
    file=$(echo "$line" | cut -c4-)

    git add "$file"

    if [ "$status" = "A" ]; then
        message="Add $file"
    elif [ "$status" = "M" ]; then
        message="Update $file"
    elif [ "$status" = "D" ]; then
        message="Delete $file"
    else
        message="Change $file"
    fi

    git commit -m "$message"
done <<< "$changed_lines"

# Push all commits
git push

# Delete this script
rm "$0"
