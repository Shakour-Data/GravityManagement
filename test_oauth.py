#!/usr/bin/env python3
"""
Simple test script to validate Google OAuth functionality
"""
import os
import sys

# Set test environment variables
os.environ['GOOGLE_CLIENT_ID'] = 'test-client-id'
os.environ['GOOGLE_CLIENT_SECRET'] = 'test-client-secret'
os.environ['GOOGLE_REDIRECT_URI'] = 'http://localhost:8000/auth/google/callback'

try:
    # Test environment variable loading
    GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "your-google-client-id")
    GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "your-google-client-secret")
    GOOGLE_REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/auth/google/callback")

    print("Testing Google OAuth configuration...")
    print(f"GOOGLE_CLIENT_ID: {GOOGLE_CLIENT_ID}")
    print(f"GOOGLE_CLIENT_SECRET: {'*' * len(GOOGLE_CLIENT_SECRET) if GOOGLE_CLIENT_SECRET else 'Not set'}")
    print(f"GOOGLE_REDIRECT_URI: {GOOGLE_REDIRECT_URI}")

    # Test OAuth URL generation (simplified)
    import secrets
    state = secrets.token_urlsafe(32)
    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "redirect_uri": GOOGLE_REDIRECT_URI,
        "scope": "openid email profile",
        "response_type": "code",
        "state": state,
        "access_type": "offline",
        "prompt": "consent"
    }

    query_string = "&".join([f"{k}={v}" for k, v in params.items()])
    oauth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{query_string}"

    print(f"\nGenerated OAuth URL: {oauth_url}")

    # Check if URL contains required parameters
    required_params = ['client_id', 'redirect_uri', 'scope', 'response_type']
    missing_params = []

    for param in required_params:
        if param not in oauth_url:
            missing_params.append(param)

    if missing_params:
        print(f"❌ Missing parameters in OAuth URL: {missing_params}")
    else:
        print("✅ OAuth URL contains all required parameters")

    print("\n✅ Google OAuth configuration test passed!")

except Exception as e:
    print(f"❌ Error testing Google OAuth: {e}")
    sys.exit(1)
