#!/usr/bin/env python3
"""
Test runner script for GravityManagement backend
"""
import subprocess
import sys
import os

def run_tests():
    """Run all tests with coverage"""
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(backend_dir)

    # Set PYTHONPATH to include the project root
    env = os.environ.copy()
    env['PYTHONPATH'] = project_root

    # Install test dependencies if not already installed
    try:
        import pytest
        import pytest_asyncio
    except ImportError:
        print("Installing test dependencies...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], check=True, cwd=backend_dir)

    # Run tests
    print("Running tests...")
    result = subprocess.run([
        sys.executable, "-m", "pytest",
        "tests/",
        "-v",
        "--tb=short",
        "--asyncio-mode=auto"
    ], cwd=backend_dir, env=env)

    return result.returncode

if __name__ == "__main__":
    exit_code = run_tests()
    sys.exit(exit_code)
