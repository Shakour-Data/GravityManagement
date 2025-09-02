#!/bin/bash

files=(
"backend/app/models/task.py"
"backend/app/models/user.py"
"backend/app/services/user_service.py"
"backend/requirements.txt"
"backend/tests/test_cache_service.py"
"backend/tests/test_user_service.py"
"backend/tests/test_auth_service.py"
)

for file in "${files[@]}"; do
    git add "$file"
    git commit -m "Update $file"
done

git push
