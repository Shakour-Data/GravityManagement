#!/usr/bin/env python3
"""
Script to fix import paths in test files from 'backend.app' to 'app'
"""
import os
import re

def fix_imports_in_file(filepath):
    """Fix import paths in a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Replace backend.app imports with app imports
        original_content = content
        content = re.sub(r'from backend\.app\.', 'from app.', content)
        content = re.sub(r'import backend\.app\.', 'import app.', content)

        # Also fix patch paths
        content = re.sub(r'@patch\(\'backend\.app\.', '@patch(\'app.', content)
        content = re.sub(r'patch\(\'backend\.app\.', 'patch(\'app.', content)

        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed imports in {filepath}")
            return True
        else:
            print(f"No changes needed in {filepath}")
            return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to fix imports in all test files"""
    test_dir = 'tests/unit_tests'

    if not os.path.exists(test_dir):
        print(f"Test directory {test_dir} not found")
        return

    fixed_count = 0
    total_count = 0

    for filename in os.listdir(test_dir):
        if filename.endswith('.py'):
            filepath = os.path.join(test_dir, filename)
            total_count += 1
            if fix_imports_in_file(filepath):
                fixed_count += 1

    print(f"\nSummary: Fixed {fixed_count} out of {total_count} test files")

if __name__ == '__main__':
    main()
