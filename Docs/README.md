# GravityCommit

[![Version](https://img.shields.io/badge/version-1.5.0-blue.svg)](https://github.com/your-repo/gravitycommit)
[![Python](https://img.shields.io/badge/python-3.7+-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-red.svg)](LICENSE)

Automatic commit package for Python projects. Automatically commits changes at specified intervals when your project is open in an editor.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Supported Platforms](#supported-platforms)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## ✨ Features

| Feature | Description | Status |
|---------|-------------|--------|
| 🚀 Automatic Commits | Configurable interval-based commits | ✅ Complete |
| 📝 Smart Messages | AI-powered commit message generation | ✅ Complete |
| 👁️ Project Monitoring | Editor detection for active projects | ✅ Complete |
| 🔧 Cross-Platform | Linux, Windows, macOS support | ✅ Complete |
| ⚙️ Service Integration | System service management | ✅ Complete |
| 🎯 Git Integration | Advanced git operations | ✅ Complete |
| 📊 Statistics | Commit analytics and reporting | ✅ Complete |
| 🔄 Undo Management | Safe commit undo functionality | ✅ Complete |
| 📢 Notifications | Multi-channel notification system | ✅ Complete |
| 🔗 CI/CD Integration | GitHub Actions, GitLab CI, Jenkins | ✅ Complete |

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CLI Interface │    │  Configuration  │    │  Project Monitor│
│                 │    │   Manager       │    │                 │
│ • setup         │◄──►│ • .autocommit   │◄──►│ • Editor detect │
│ • status        │    │ • intervals     │    │ • VS Code       │
│ • remove        │    │ • settings      │    │ • PyCharm       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Scheduler     │    │ Commit Generator│    │  Git Operations│
│                 │    │                 │    │                 │
│ • timed tasks   │◄──►│ • AI messages   │◄──►│ • staging       │
│ • intervals     │    │ • file analysis │    │ • committing    │
│ • background    │    │ • type detection│    │ • status check  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│Service Manager  │    │   Statistics    │    │ Notifications   │
│                 │    │                 │    │                 │
│ • systemd       │◄──►│ • analytics     │◄──►│ • desktop       │
│ • Windows svc   │    │ • reports       │    │ • email         │
│ • daemon        │    │ • metrics       │    │ • webhook       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📦 Installation

### System Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| Python | 3.7+ | Required for all platforms |
| Git | Latest | Must be installed and configured |
| Linux | systemd | For service management |
| Windows | Administrator rights | For service installation |
| macOS | System permissions | For service management |

### Quick Install

```bash
# Install from PyPI
pip install gravitycommit

# Or install from source
git clone https://github.com/your-repo/gravitycommit.git
cd gravitycommit
pip install -e .
```

### Platform-Specific Installation

#### Linux
```bash
# Standard installation
pip install gravitycommit

# With development dependencies
pip install -e .[dev]
```

#### Windows
```bash
# Install with Windows service support
pip install gravitycommit[windows]

# Or from source
pip install -e .[windows]
```

#### macOS
```bash
# Standard installation
pip install gravitycommit

# Grant necessary permissions for service management
# System Preferences → Security & Privacy → Full Disk Access
```

## Quick Start

1. Navigate to your git project:
```bash
cd /path/to/your/project
```

2. Setup automatic commits:
```bash
autocommit setup . --interval 15
```

This will:
- Create a `.autocommit` configuration file
- Install a system service
- Start monitoring for changes every 15 minutes

3. Check status:
```bash
autocommit status .
```

## Usage

### Setup Command

Setup automatic commits for a project:

```bash
autocommit setup /path/to/project --interval 10
```

Options:
- `--interval`: Commit interval in minutes (default: 10)

### Remove Command

Remove automatic commits from a project:

```bash
autocommit remove /path/to/project
```

### Status Command

Check the current status:

```bash
autocommit status /path/to/project
```

Shows:
- Commit interval
- Service running status
- Project open status

## Usage Examples

### Basic Setup

```bash
# Setup auto-commit for current directory with 15-minute intervals
autocommit setup . --interval 15

# Check status
autocommit status .

# Remove auto-commit from project
autocommit remove .
```

### Advanced Usage

```bash
# Setup for a specific project with custom interval
autocommit setup ~/projects/my-app --interval 30

# Monitor multiple projects
autocommit status ~/projects/my-app
autocommit status ~/projects/website
```

### Integration with Development Workflow

```bash
# In your project directory
cd /path/to/your/project

# Initialize git if not already done
git init
git add .
git commit -m "Initial commit"

# Setup auto-commit
autocommit setup . --interval 20

# Continue working - commits will happen automatically
# when the project is open in your editor
```

### Service Management

```bash
# Linux: Check service status
sudo systemctl status autocommit-*

# Windows: Check service status (requires admin)
sc query "AutoCommit Service"
```

## How It Works

1. **Project Monitoring**: Detects when your project is open in supported editors (VS Code, Atom, Sublime, etc.)
2. **Change Detection**: Monitors git status for uncommitted changes
3. **Smart Commits**: Only commits when changes exist and project is active
4. **Message Generation**: Creates meaningful commit messages based on file types and changes
5. **Service Management**: Runs as a background service that survives system restarts

## Supported Editors

- Visual Studio Code
- Atom
- Sublime Text
- Vim/Neovim
- Emacs
- PyCharm
- IntelliJ IDEA
- And many more...

## Configuration

Configuration is stored in `.autocommit` file in your project root:

```json
{
  "interval": 10
}
```

## System Service

### Linux (systemd)

The package installs a systemd service that:
- Starts automatically on boot
- Runs under your user account
- Monitors your project continuously

### Windows

Windows service support is implemented using the Windows Service Manager. Requires:
- Administrator privileges for service installation
- pywin32 package (`pip install pywin32`)
- Windows Services must be enabled in your system

## Development

### Project Structure

```
gravitycommit/
├── autocommit/
│   ├── __init__.py
│   ├── cli.py              # Command line interface
│   ├── config_manager.py   # Configuration management
│   ├── commit_generator.py # Commit message generation
│   ├── git_operations.py   # Git operations
│   ├── scheduler.py        # Task scheduling
│   ├── project_monitor.py  # Editor detection
│   └── daemon_manager.py   # Service management
├── setup.py
└── README.md
```

### Running Tests

```bash
python -m pytest
```

## Contributing

1. Create a feature branch from the main branch
2. Make your changes
3. Add tests if applicable
4. Test your changes thoroughly
5. Commit your changes with descriptive messages
6. Merge or submit your changes according to project workflow

## License

MIT License - see LICENSE file for details

## Troubleshooting

### Service won't start
- **Linux**: Ensure you have sudo privileges
- **Windows**: Run commands as administrator and ensure pywin32 is installed
- Check system logs:
  - Linux: `journalctl -u autocommit-*`
  - Windows: Event Viewer → Windows Logs → Application

### Commits not happening
- Verify project is open in a supported editor
- Check git status: `git status`
- Review service status: `autocommit status /path/to/project`
- Ensure the project directory is a valid git repository

### Permission errors
- **Linux**: Ensure user has access to `/etc/systemd/system/`
- **Windows**: Run commands as administrator
- **General**: Check file permissions on the project directory

### Windows-specific issues
- Install pywin32: `pip install pywin32`
- Ensure Windows Services are enabled
- Check Windows Event Log for detailed error messages
- Try running the daemon manually: `autocommit daemon /path/to/project`

### Common issues
- **"Not a git repository"**: Run `git init` in your project directory
- **"No changes detected"**: Make sure you have uncommitted changes
- **"Project not open"**: Open your project in a supported editor (VS Code, Atom, etc.)
- **"Service installation failed"**: Check system permissions and logs

## Roadmap

- [x] Windows service support
- [x] Linux systemd support
- [x] Cross-platform compatibility
- [x] Intelligent commit message generation
- [x] macOS support
- [ ] Custom commit message templates
- [ ] Git hooks integration
- [ ] Web interface for monitoring
- [ ] Plugin system for custom editors

## Diagrams and Tables

### System Architecture Diagram

```plaintext
+-------------------+       +-------------------+       +-------------------+
|   CLI Interface   |<----->| Configuration Mgr |<----->| Project Monitor   |
+-------------------+       +-------------------+       +-------------------+
         |                           |                           |
         v                           v                           v
+-------------------+       +-------------------+       +-------------------+
|    Scheduler      |<----->| Commit Generator  |<----->|   Git Operations  |
+-------------------+       +-------------------+       +-------------------+
         |                           |                           |
         v                           v                           v
+-------------------+       +-------------------+       +-------------------+
| Service Manager   |<----->|   Statistics      |<----->|  Notifications    |
+-------------------+       +-------------------+       +-------------------+
```

### Feature Status Table

| Feature                 | Status    | Notes                          |
|-------------------------|-----------|--------------------------------|
| Automatic Commits       | Complete  | Interval-based commits         |
| Smart Commit Messages   | Complete  | AI-powered message generation  |
| Project Monitoring      | Complete  | Editor detection               |
| Cross-Platform Support  | Complete  | Linux, Windows, macOS          |
| Service Integration     | Complete  | systemd, Windows Service       |
| Git Operations          | Complete  | Staging, committing, status    |
| Statistics & Reporting  | Complete  | Commit analytics               |
| Undo Management         | Complete  | Safe undo functionality        |
| Notifications           | Complete  | Email, desktop, webhook, Slack |
