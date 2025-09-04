# TODO: Project Structure Restructuring

This document outlines the professional restructuring of the GravityManagement project to improve organization, maintainability, and scalability.

## Current Issues Identified
- Scattered scripts and configuration files at root level
- Inconsistent naming (Docs/ vs docs/)
- Test results mixed at root and app levels
- Infrastructure files (monitoring, ssl) not grouped
- App-specific scripts not organized within apps

## Proposed New Structure
```
GravityManagement/
├── .gitignore
├── LICENSE
├── README.md
├── README_EN.md
├── README_FA.md
├── docs/                    # Documentation (renamed from Docs/)
├── infra/                   # Infrastructure files
│   ├── monitoring/
│   ├── ssl/
│   ├── docker-compose.elk.yml
│   ├── docker-compose.monitoring.yml
│   └── nginx.conf
├── scripts/                 # Utility scripts
│   ├── backup.sh
│   ├── commit_and_push_changes.sh
│   ├── commit_push_all_changes.sh
│   ├── firewall.sh
│   ├── generate-ssl.sh
│   ├── setup_and_run.bat
│   ├── setup_and_run.sh
│   └── test_backup_restoration.sh
├── tools/                   # Development tools
│   └── rustup-init.exe
├── reports/                 # Test results and reports (renamed from test_results/)
├── backend/                 # Backend application
│   ├── scripts/             # Backend-specific scripts
│   │   ├── run_tests_batch.bat
│   │   ├── run_tests_complete.py
│   │   ├── run_tests_simple.py
│   │   ├── run_tests_with_output.py
│   │   ├── run_tests_with_venv.bat
│   │   ├── run_tests.py
│   │   ├── security_test.py
│   │   ├── test_output.txt
│   │   └── test_runner.bat
│   └── ... (rest of backend structure)
├── frontend/                # Frontend application
│   ├── test_results/        # Frontend test results
│   │   ├── test_results.md
│   │   └── test-results.json
│   └── ... (rest of frontend structure)
└── docs/                    # Project documentation
    ├── DISASTER_RECOVERY_PLAN.md
    └── TODO_GPM.md
```

## Activities to Perform

### Phase 1: Create New Directories
- [x] Create `docs/` directory
- [x] Create `infra/` directory
- [x] Create `scripts/` directory
- [x] Create `tools/` directory
- [x] Create `reports/` directory
- [x] Create `backend/scripts/` directory
- [x] Create `frontend/test_results/` directory

### Phase 2: Move Documentation Files
- [x] Move `Docs/` to `docs/`
- [x] Move `DISASTER_RECOVERY_PLAN.md` to `docs/`
- [x] Move `TODO_GPM.md` to `docs/`

### Phase 3: Move Infrastructure Files
- [x] Move `monitoring/` to `infra/monitoring/`
- [x] Move `ssl/` to `infra/ssl/`
- [x] Move `docker-compose.elk.yml` to `infra/`
- [x] Move `docker-compose.monitoring.yml` to `infra/`
- [x] Move `nginx.conf` to `infra/`

### Phase 4: Move Scripts and Tools
- [x] Move `backup.sh` to `scripts/`
- [x] Move `commit_and_push_changes.sh` to `scripts/`
- [x] Move `commit_push_all_changes.sh` to `scripts/`
- [x] Move `firewall.sh` to `scripts/`
- [x] Move `generate-ssl.sh` to `scripts/`
- [x] Move `setup_and_run.bat` to `scripts/`
- [x] Move `setup_and_run.sh` to `scripts/`
- [x] Move `test_backup_restoration.sh` to `scripts/`
- [x] Move `rustup-init.exe` to `tools/`

### Phase 5: Move Test Results
- [x] Move `test_results/` to `reports/`
- [x] Move `frontend/test_results.md` to `frontend/test_results/`
- [x] Move `frontend/test-results.json` to `frontend/test_results/`

### Phase 6: Organize Backend Scripts
- [x] Move `backend/run_tests_batch.bat` to `backend/scripts/`
- [x] Move `backend/run_tests_complete.py` to `backend/scripts/`
- [x] Move `backend/run_tests_simple.py` to `backend/scripts/`
- [x] Move `backend/run_tests_with_output.py` to `backend/scripts/`
- [x] Move `backend/run_tests_with_venv.bat` to `backend/scripts/`
- [x] Move `backend/run_tests.py` to `backend/scripts/`
- [x] Move `backend/security_test.py` to `backend/scripts/`
- [x] Move `backend/test_output.txt` to `backend/scripts/`
- [x] Move `backend/test_runner.bat` to `backend/scripts/`

### Phase 7: Update References
- [x] Update all import paths and references to moved files
- [x] Update README files to reflect new structure
- [x] Update any scripts that reference moved files
- [x] Update CI/CD configurations if any

### Phase 8: Cleanup
- [x] Remove empty directories
- [x] Verify all files are moved correctly
- [x] Test that the application still works after restructuring

## Notes
- Ensure all file moves preserve file permissions
- Update any hardcoded paths in code or scripts
- Test the application thoroughly after restructuring
- Commit changes in logical groups to maintain git history clarity
