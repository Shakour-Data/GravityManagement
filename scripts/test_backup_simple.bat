@echo off
REM Simple Backup Functionality Test for Windows
REM This script performs basic validation of backup components

echo Starting backup functionality tests...
echo %DATE% %TIME%

set TEST_RESULTS_DIR=test_results\backup_tests\%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
set TEST_RESULTS_DIR=%TEST_RESULTS_DIR: =0%

