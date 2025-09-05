import subprocess

def run_tests():
    result = subprocess.run(
        ["pytest", "backend/tests/unit_tests", "--maxfail=5", "--disable-warnings", "-q", "--tb=short"],
        capture_output=True,
        text=True,
    )
    with open("backend/tests/outputs/test_results.txt", "w", encoding="utf-8") as f:
        f.write(result.stdout)
        f.write("\n")
        f.write(result.stderr)
    return result.returncode

if __name__ == "__main__":
    retcode = run_tests()
    if retcode == 0:
        print("All tests passed successfully.")
    else:
        print(f"Tests failed with return code {retcode}. See backend/tests/outputs/test_results.txt for details.")
