#!/bin/bash
# Script to commit and push each changed file separately with appropriate commit messages

branch=$(git branch --show-current)

# Get list of modified files
files=$(git status --porcelain | grep '^ M' | awk '{print $2}')

for file in $files; do
  # Stage the file
  git add "$file"

  # Determine appropriate commit message based on file
  if [[ $file == *"package.json" ]]; then
    msg="Update package dependencies and configuration"
  elif [[ $file == *"package-lock.json" ]]; then
    msg="Update package-lock.json for dependency changes"
  elif [[ $file == *".tsx" ]]; then
    msg="Update UI component: $(basename "$file" .tsx)"
  else
    msg="Update $file"
  fi

  # Commit with appropriate message
  git commit -m "$msg"
done

# Get list of untracked files (new files)
new_files=$(git status --porcelain | grep '^??' | awk '{print $2}')

for file in $new_files; do
  # Stage the file
  git add "$file"

  # Determine appropriate commit message for new files
  if [[ $file == *"test.tsx" ]]; then
    msg="Add test for $(basename "$file" .test.tsx) component"
  elif [[ $file == *"TODO"* ]]; then
    msg="Add TODO file: $(basename "$file")"
  else
    msg="Add new file: $(basename "$file")"
  fi

  # Commit with appropriate message
  git commit -m "$msg"
done

# Push the branch
git push origin "$branch"

# Remove the script itself
rm -- "$0"
