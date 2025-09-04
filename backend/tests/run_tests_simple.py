#!/usr/bin/env python3
"""
Simple test runner for GravityManagement backend
"""
import subprocess
import sys
import os

def run_tests():
    """Run all tests and capture output"""
    try:
        # Change to backend directory
        backend_dir = os.path.dirname(os.path.abspath(__file__))
        os.chdir(backend_dir)

        # Set PYTHONPATH
        env = os.environ.copy()
        env['PYTHONPATH'] = os.path.dirname(backend_dir)

        print("Running backend tests...")
        print("=" * 50)

        # Run pytest
        result = subprocess.run([
            sys.executable, "-m", "pytest",
            "tests/",
            "-v",
            "--tb=short",
            "--asyncio-mode=auto"
        ], env=env, capture_output=True, text=True)

        print("STDOUT:")
        print(result.stdout)
        print("\nSTDERR:")
        print(result.stderr)
        print(f"\nReturn code: {result.returncode}")

        return result.returncode

    except Exception as e:
        print(f"Error running tests: {e}")
        return 1

if __name__ == "__main__":
    exit_code = run_tests()
    sys.exit(exit_code)
