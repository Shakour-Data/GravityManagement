#!/usr/bin/env python3
"""
Test runner script for GravityManagement backend with output saved to file
"""
import subprocess
import sys
import os

def run_tests():
    """Run all tests with coverage and save output to file"""
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(backend_dir)

    # Set PYTHONPATH to include the project root
    env = os.environ.copy()
    env['PYTHONPATH'] = project_root

    output_file = os.path.join(backend_dir, "test_output.txt")

    # Activate virtual environment and run tests, saving output
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
    exit_code = run_tests()
    sys.exit(exit_code)
