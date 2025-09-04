#!/usr/bin/env python3
"""
Complete test runner script for GravityManagement backend
"""
import subprocess
import sys
import os

def install_dependencies():
    """Install all required dependencies"""
    print("Installing dependencies...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], check=True)
        subprocess.run([sys.executable, "-m", "pip", "install", "fastapi[all]", "python-jose[cryptography]", "passlib[bcrypt]", "redis"], check=True)
        print("Dependencies installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to install dependencies: {e}")
        return False

def run_tests():
    """Run all tests with coverage and save output to file"""
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(backend_dir)

    # Set PYTHONPATH to include the project root
    env = os.environ.copy()
    env['PYTHONPATH'] = project_root

    output_file = os.path.join(backend_dir, "test_output.txt")

    # Run tests
    print("Running tests...")
    with open(output_file, "w", encoding="utf-8") as f:
        process = subprocess.run([
            sys.executable, "-m", "pytest",
            "tests/",
            "-v",
            "--tb=short",
            "--asyncio-mode=auto"
        ], cwd=backend_dir, env=env, stdout=f, stderr=subprocess.STDOUT)

    print(f"Test output saved to {output_file}")
    return process.returncode

if __name__ == "__main__":
    if install_dependencies():
        exit_code = run_tests()
        sys.exit(exit_code)
    else:
        print("Failed to install dependencies")
        sys.exit(1)
