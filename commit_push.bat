@echo off
setlocal enabledelayedexpansion

for /f "tokens=*" %%i in ('git status --porcelain') do (
    set line=%%i
    set file=!line:~3!
    git add "!file!"
    git commit -m "Update !file!"
)

git push

del %0
