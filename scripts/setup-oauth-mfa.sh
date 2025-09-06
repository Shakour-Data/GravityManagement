#!/bin/bash

# OAuth 2.0 and MFA Setup Script for GravityPM
# This script sets up OAuth 2.0 flows and multi-factor authentication

set -e

# Configuration
PROJECT_NAME="gravitypm"
ENVIRONMENT="${1:-production}"
AUTH_DIR="/opt/${PROJECT_NAME}/auth"
OAUTH_DIR="$AUTH_DIR/oauth"
MFA_DIR="$AUTH_DIR/mfa"

echo "Setting up OAuth 2.0 and MFA for ${ENVIRONMENT} environment..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-dev build-essential libssl-dev
sudo pip3 install pyotp qrcode[pil] oauthlib requests-oauthlib flask-oauthlib

# Create authentication directory structure
sudo mkdir -p "$AUTH_DIR"
sudo mkdir -p "$OAUTH_DIR"
sudo mkdir -p "$MFA_DIR"
sudo chmod 700 "$AUTH_DIR"

# Create OAuth 2.0 configuration
echo "Creating OAuth 2.0 configuration..."

cat > "$OAUTH_DIR/oauth-config.json" << EOF
{
    "version": "1.0",
    "environment": "${ENVIRONMENT}",
    "providers": {
        "google": {
            "enabled": true,
            "client_id": "${GOOGLE_CLIENT_ID:-your-google-client-id}",
            "client_secret": "${GOOGLE_CLIENT_SECRET:-your-google-client-secret}",
            "redirect_uri": "https://gravitypm.com/auth/google/callback",
            "scope": ["openid", "email", "profile"],
            "authorization_url": "https://accounts.google.com/o/oauth2/auth",
            "token_url": "https://oauth2.googleapis.com/token",
            "userinfo_url": "https://openidconnect.googleapis.com/v1/userinfo"
        },
        "github": {
            "enabled": true,
            "client_id": "${GITHUB_CLIENT_ID:-your-github-client-id}",
            "client_secret": "${GITHUB_CLIENT_SECRET:-your-github-client-secret}",
            "redirect_uri": "https://gravitypm.com/auth/github/callback",
            "scope": ["user:email", "read:user"],
            "authorization_url": "https://github.com/login/oauth/authorize",
            "token_url": "https://github.com/login/oauth/access_token",
            "userinfo_url": "https://api.github.com/user"
        },
        "microsoft": {
            "enabled": false,
            "client_id": "${MICROSOFT_CLIENT_ID:-your-microsoft-client-id}",
            "client_secret": "${MICROSOFT_CLIENT_SECRET:-your-microsoft-client-secret}",
            "redirect_uri": "https://gravitypm.com/auth/microsoft/callback",
            "scope": ["openid", "email", "profile"],
            "authorization_url": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            "token_url": "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            "userinfo_url": "https://graph.microsoft.com/v1.0/me"
        }
    },
    "jwt": {
        "secret_key": "${JWT_SECRET_KEY:-generate-a-secure-random-key}",
        "algorithm": "HS256",
        "access_token_expire_minutes": 30,
        "refresh_token_expire_days": 7,
        "issuer": "gravitypm.com"
    },
    "session": {
        "secret_key": "${SESSION_SECRET_KEY:-generate-a-secure-random-key}",
        "max_age": 86400,
        "secure": true,
        "httponly": true,
        "samesite": "strict"
    }
}
EOF

# Create Python OAuth handler
echo "Creating Python OAuth handler..."

cat > "$OAUTH_DIR/oauth_handler.py" << 'EOF'
#!/usr/bin/env python3

import os
import json
import secrets
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple
import jwt
import requests
from flask import Flask, request, redirect, session, url_for, jsonify
from oauthlib.oauth2 import WebApplicationClient
import logging

class OAuthHandler:
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.oauth_dir = os.path.dirname(config_path)
        self.clients = {}

        # Initialize OAuth clients
        for provider, config in self.config['providers'].items():
            if config.get('enabled', False):
                self.clients[provider] = WebApplicationClient(config['client_id'])

        # Set up logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)

    def get_authorization_url(self, provider: str, state: str = None) -> Tuple[str, str]:
        """Generate OAuth authorization URL"""
        if provider not in self.clients:
            raise ValueError(f"OAuth provider not configured: {provider}")

        provider_config = self.config['providers'][provider]
        client = self.clients[provider]

        if not state:
            state = secrets.token_urlsafe(32)

        authorization_url = client.prepare_authorization_request(
            provider_config['authorization_url'],
            redirect_url=provider_config['redirect_uri'],
            scope=provider_config['scope'],
            state=state
        )[0]

        return authorization_url, state

    def exchange_code_for_token(self, provider: str, code: str, state: str) -> Dict[str, Any]:
        """Exchange authorization code for access token"""
        if provider not in self.clients:
            raise ValueError(f"OAuth provider not configured: {provider}")

        provider_config = self.config['providers'][provider]
        client = self.clients[provider]

        token_url, headers, body = client.prepare_token_request(
            provider_config['token_url'],
            authorization_response=request.url,
            redirect_url=provider_config['redirect_uri'],
            code=code,
            client_secret=provider_config['client_secret']
        )

        token_response = requests.post(
            token_url,
            headers=headers,
            data=body,
            timeout=30
        )

        if token_response.status_code != 200:
            raise Exception(f"Token exchange failed: {token_response.text}")

        client.parse_token_response(token_response.text)
        token_data = json.loads(token_response.text)

        # Fetch user info
        user_info = self._fetch_user_info(provider, token_data['access_token'])

        return {
            'access_token': token_data['access_token'],
            'refresh_token': token_data.get('refresh_token'),
            'expires_in': token_data.get('expires_in'),
            'token_type': token_data.get('token_type', 'Bearer'),
            'user_info': user_info
        }

    def _fetch_user_info(self, provider: str, access_token: str) -> Dict[str, Any]:
        """Fetch user information from OAuth provider"""
        provider_config = self.config['providers'][provider]
        headers = {'Authorization': f'Bearer {access_token}'}

        response = requests.get(
            provider_config['userinfo_url'],
            headers=headers,
            timeout=30
        )

        if response.status_code != 200:
            raise Exception(f"Failed to fetch user info: {response.text}")

        user_data = response.json()

        # Normalize user data across providers
        normalized_user = {
            'id': user_data.get('sub') or user_data.get('id'),
            'email': user_data.get('email'),
            'name': user_data.get('name'),
            'picture': user_data.get('picture') or user_data.get('avatar_url'),
            'provider': provider,
            'verified_email': user_data.get('email_verified', user_data.get('verified'))
        }

        return normalized_user

    def generate_jwt_token(self, user_info: Dict[str, Any]) -> str:
        """Generate JWT access token"""
        jwt_config = self.config['jwt']

        payload = {
            'sub': user_info['id'],
            'email': user_info['email'],
            'name': user_info['name'],
            'provider': user_info['provider'],
            'iat': datetime.utcnow(),
            'exp': datetime.utcnow() + timedelta(minutes=jwt_config['access_token_expire_minutes']),
            'iss': jwt_config['issuer']
        }

        token = jwt.encode(payload, jwt_config['secret_key'], algorithm=jwt_config['algorithm'])
        return token

    def generate_refresh_token(self, user_info: Dict[str, Any]) -> str:
        """Generate refresh token"""
        jwt_config = self.config['jwt']

        payload = {
            'sub': user_info['id'],
            'type': 'refresh',
            'iat': datetime.utcnow(),
            'exp': datetime.utcnow() + timedelta(days=jwt_config['refresh_token_expire_days']),
            'iss': jwt_config['issuer']
        }

        token = jwt.encode(payload, jwt_config['secret_key'], algorithm=jwt_config['algorithm'])
        return token

    def validate_jwt_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Validate JWT token"""
        try:
            jwt_config = self.config['jwt']
            payload = jwt.decode(token, jwt_config['secret_key'], algorithms=[jwt_config['algorithm']])

            # Check expiration
            exp = datetime.fromtimestamp(payload['exp'])
            if datetime.utcnow() > exp:
                return None

            return payload
        except jwt.ExpiredSignatureError:
            self.logger.warning("JWT token expired")
            return None
        except jwt.InvalidTokenError:
            self.logger.warning("Invalid JWT token")
            return None

    def refresh_access_token(self, refresh_token: str) -> Optional[str]:
        """Refresh access token using refresh token"""
        payload = self.validate_jwt_token(refresh_token)

        if not payload or payload.get('type') != 'refresh':
            return None

        # Generate new access token
        user_info = {
            'id': payload['sub'],
            'email': payload.get('email'),
            'name': payload.get('name'),
            'provider': payload.get('provider')
        }

        return self.generate_jwt_token(user_info)

# Flask OAuth integration example
def create_oauth_app(oauth_handler):
    app = Flask(__name__)
    app.secret_key = os.urandom(24)

    @app.route('/auth/<provider>')
    def oauth_login(provider):
        try:
            authorization_url, state = oauth_handler.get_authorization_url(provider)
            session['oauth_state'] = state
            session['oauth_provider'] = provider
            return redirect(authorization_url)
        except ValueError as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/auth/<provider>/callback')
    def oauth_callback(provider):
        code = request.args.get('code')
        state = request.args.get('state')

        if not code:
            return jsonify({'error': 'Authorization code not provided'}), 400

        if state != session.get('oauth_state'):
            return jsonify({'error': 'Invalid state parameter'}), 400

        try:
            token_data = oauth_handler.exchange_code_for_token(provider, code, state)

            # Generate JWT tokens
            access_token = oauth_handler.generate_jwt_token(token_data['user_info'])
            refresh_token = oauth_handler.generate_refresh_token(token_data['user_info'])

            # Store tokens in session
            session['access_token'] = access_token
            session['refresh_token'] = refresh_token
            session['user_info'] = token_data['user_info']

            return redirect('/dashboard')

        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @app.route('/auth/logout')
    def logout():
        session.clear()
        return redirect('/')

    @app.route('/auth/refresh')
    def refresh_token():
        refresh_token = session.get('refresh_token')
        if not refresh_token:
            return jsonify({'error': 'No refresh token'}), 401

        new_access_token = oauth_handler.refresh_access_token(refresh_token)
        if not new_access_token:
            return jsonify({'error': 'Invalid refresh token'}), 401

        session['access_token'] = new_access_token
        return jsonify({'access_token': new_access_token})

    return app

# CLI interface
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python oauth_handler.py <config_path> [command]")
        sys.exit(1)

    config_path = sys.argv[1]
    oauth = OAuthHandler(config_path)

    if len(sys.argv) > 2:
        command = sys.argv[2]

        if command == 'test':
            # Test OAuth configuration
            for provider in oauth.clients.keys():
                try:
                    url, state = oauth.get_authorization_url(provider)
                    print(f"{provider}: {url}")
                except Exception as e:
                    print(f"{provider}: Error - {e}")

        elif command == 'jwt-test':
            # Test JWT generation
            test_user = {
                'id': 'test-user-123',
                'email': 'test@example.com',
                'name': 'Test User',
                'provider': 'test'
            }

            token = oauth.generate_jwt_token(test_user)
            print(f"JWT Token: {token}")

            # Test validation
            payload = oauth.validate_jwt_token(token)
            print(f"Validated payload: {payload}")

        else:
            print(f"Unknown command: {command}")
EOF

sudo chmod +x "$OAUTH_DIR/oauth_handler.py"

# Create MFA configuration
echo "Creating MFA configuration..."

cat > "$MFA_DIR/mfa-config.json" << EOF
{
    "version": "1.0",
    "environment": "${ENVIRONMENT}",
    "enabled": true,
    "required_for_roles": ["admin", "manager"],
    "methods": {
        "totp": {
            "enabled": true,
            "issuer": "GravityPM",
            "digits": 6,
            "interval": 30
        },
        "sms": {
            "enabled": false,
            "provider": "twilio",
            "account_sid": "${TWILIO_ACCOUNT_SID:-your-twilio-sid}",
            "auth_token": "${TWILIO_AUTH_TOKEN:-your-twilio-token}",
            "from_number": "${TWILIO_FROM_NUMBER:-your-twilio-number}"
        },
        "email": {
            "enabled": true,
            "smtp_server": "${SMTP_SERVER:-smtp.gmail.com}",
            "smtp_port": 587,
            "smtp_username": "${SMTP_USERNAME:-your-email@gmail.com}",
            "smtp_password": "${SMTP_PASSWORD:-your-email-password}"
        }
    },
    "backup_codes": {
        "enabled": true,
        "count": 10,
        "length": 8
    },
    "session": {
        "mfa_verified_timeout": 3600,
        "remember_device_days": 30
    }
}
EOF

# Create Python MFA handler
echo "Creating Python MFA handler..."

cat > "$MFA_DIR/mfa_handler.py" << 'EOF'
#!/usr/bin/env python3

import os
import json
import secrets
import string
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import pyotp
import qrcode
from io import BytesIO
import base64
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging

class MFAHandler:
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.mfa_dir = os.path.dirname(config_path)
        self.secrets_file = os.path.join(self.mfa_dir, 'user_secrets.json')
        self.backup_codes_file = os.path.join(self.mfa_dir, 'backup_codes.json')

        # Ensure secrets directory exists
        os.makedirs(self.mfa_dir, exist_ok=True)

        # Set up logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.get_logger(__name__)

    def setup_totp(self, user_id: str) -> Dict[str, Any]:
        """Set up TOTP for a user"""
        secret = pyotp.random_base32()

        # Store secret securely
        self._store_user_secret(user_id, 'totp', secret)

        # Generate QR code
        totp = pyotp.TOTP(secret)
        provisioning_uri = totp.provisioning_uri(
            name=user_id,
            issuer_name=self.config['methods']['totp']['issuer']
        )

        # Generate QR code image
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(provisioning_uri)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        buffered = BytesIO()
        img.save(buffered, format="PNG")
        qr_code_base64 = base64.b64encode(buffered.getvalue()).decode()

        return {
            'secret': secret,
            'qr_code': qr_code_base64,
            'provisioning_uri': provisioning_uri
        }

    def verify_totp(self, user_id: str, code: str) -> bool:
        """Verify TOTP code"""
        secret = self._get_user_secret(user_id, 'totp')

        if not secret:
            return False

        totp = pyotp.TOTP(secret)
        return totp.verify(code)

    def setup_backup_codes(self, user_id: str) -> List[str]:
        """Generate backup codes for a user"""
        codes = []
        for _ in range(self.config['backup_codes']['count']):
            code = ''.join(secrets.choice(string.ascii_letters + string.digits)
                          for _ in range(self.config['backup_codes']['length']))
            codes.append(code.upper())

        # Store backup codes securely
        self._store_backup_codes(user_id, codes)

        return codes

    def verify_backup_code(self, user_id: str, code: str) -> bool:
        """Verify and consume backup code"""
        codes = self._get_backup_codes(user_id)

        if code.upper() in codes:
            # Remove used code
            codes.remove(code.upper())
            self._store_backup_codes(user_id, codes)
            return True

        return False

    def send_sms_code(self, phone_number: str, code: str) -> bool:
        """Send MFA code via SMS"""
        if not self.config['methods']['sms']['enabled']:
            return False

        try:
            # This would integrate with Twilio or similar service
            # For now, just log the code
            self.logger.info(f"SMS code {code} would be sent to {phone_number}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to send SMS: {e}")
            return False

    def send_email_code(self, email: str, code: str) -> bool:
        """Send MFA code via email"""
        if not self.config['methods']['email']['enabled']:
            return False

        try:
            smtp_config = self.config['methods']['email']

            msg = MIMEMultipart()
            msg['From'] = smtp_config['smtp_username']
            msg['To'] = email
            msg['Subject'] = 'GravityPM MFA Code'

            body = f"Your MFA code is: {code}\n\nThis code will expire in 10 minutes."
            msg.attach(MIMEText(body, 'plain'))

            server = smtplib.SMTP(smtp_config['smtp_server'], smtp_config['smtp_port'])
            server.starttls()
            server.login(smtp_config['smtp_username'], smtp_config['smtp_password'])
            text = msg.as_string()
            server.sendmail(smtp_config['smtp_username'], email, text)
            server.quit()

            return True
        except Exception as e:
            self.logger.error(f"Failed to send email: {e}")
            return False

    def generate_email_code(self, user_id: str, email: str) -> str:
        """Generate and send email MFA code"""
        code = ''.join(secrets.choice(string.digits) for _ in range(6))

        # Store code temporarily (in production, use Redis/database)
        self._store_temp_code(user_id, code, 'email')

        # Send code via email
        if self.send_email_code(email, code):
            return code
        else:
            raise Exception("Failed to send email code")

    def verify_email_code(self, user_id: str, code: str) -> bool:
        """Verify email MFA code"""
        stored_code = self._get_temp_code(user_id, 'email')

        if stored_code and stored_code == code:
            # Clear used code
            self._clear_temp_code(user_id, 'email')
            return True

        return False

    def is_mfa_required(self, user_role: str) -> bool:
        """Check if MFA is required for user role"""
        required_roles = self.config.get('required_for_roles', [])
        return user_role in required_roles

    def _store_user_secret(self, user_id: str, method: str, secret: str):
        """Store user MFA secret securely"""
        secrets = self._load_secrets()
        user_key = f"{user_id}:{method}"

        # Encrypt secret before storing
        encrypted_secret = self._encrypt_secret(secret)

        secrets[user_key] = {
            'secret': encrypted_secret,
            'created': datetime.utcnow().isoformat(),
            'method': method
        }

        self._save_secrets(secrets)

    def _get_user_secret(self, user_id: str, method: str) -> Optional[str]:
        """Retrieve user MFA secret"""
        secrets = self._load_secrets()
        user_key = f"{user_id}:{method}"

        if user_key in secrets:
            encrypted_secret = secrets[user_key]['secret']
            return self._decrypt_secret(encrypted_secret)

        return None

    def _store_backup_codes(self, user_id: str, codes: List[str]):
        """Store backup codes securely"""
        backup_data = self._load_backup_codes()

        # Hash codes for storage
        hashed_codes = [hashlib.sha256(code.encode()).hexdigest() for code in codes]

        backup_data[user_id] = {
            'codes': hashed_codes,
            'created': datetime.utcnow().isoformat()
        }

        with open(self.backup_codes_file, 'w') as f:
            json.dump(backup_data, f, indent=2)

    def _get_backup_codes(self, user_id: str) -> List[str]:
        """Retrieve backup codes"""
        backup_data = self._load_backup_codes()

        if user_id in backup_data:
            return backup_data[user_id]['codes']

        return []

    def _store_temp_code(self, user_id: str, code: str, method: str):
        """Store temporary MFA code"""
        # In production, use Redis with expiration
        temp_file = os.path.join(self.mfa_dir, f'temp_{user_id}_{method}.json')

        data = {
            'code': code,
            'created': datetime.utcnow().isoformat(),
            'expires': (datetime.utcnow() + timedelta(minutes=10)).isoformat()
        }

        with open(temp_file, 'w') as f:
            json.dump(data, f)

    def _get_temp_code(self, user_id: str, method: str) -> Optional[str]:
        """Retrieve temporary MFA code"""
        temp_file = os.path.join(self.mfa_dir, f'temp_{user_id}_{method}.json')

        if os.path.exists(temp_file):
            with open(temp_file, 'r') as f:
                data = json.load(f)

            expires = datetime.fromisoformat(data['expires'])
            if datetime.utcnow() < expires:
                return data['code']
            else:
                # Code expired, clean up
                os.remove(temp_file)

        return None

    def _clear_temp_code(self, user_id: str, method: str):
        """Clear temporary MFA code"""
        temp_file = os.path.join(self.mfa_dir, f'temp_{user_id}_{method}.json')
        if os.path.exists(temp_file):
            os.remove(temp_file)

    def _load_secrets(self) -> Dict[str, Any]:
        """Load user secrets"""
        if os.path.exists(self.secrets_file):
            with open(self.secrets_file, 'r') as f:
                return json.load(f)
        return {}

    def _save_secrets(self, secrets: Dict[str, Any]):
        """Save user secrets"""
        with open(self.secrets_file, 'w') as f:
            json.dump(secrets, f, indent=2)

        # Set secure permissions
        os.chmod(self.secrets_file, 0o600)

    def _load_backup_codes(self) -> Dict[str, Any]:
        """Load backup codes"""
        if os.path.exists(self.backup_codes_file):
            with open(self.backup_codes_file, 'r') as f:
                return json.load(f)
        return {}

    def _encrypt_secret(self, secret: str) -> str:
        """Encrypt secret (simplified - use proper encryption in production)"""
        # In production, use proper encryption with KMS
        return base64.b64encode(secret.encode()).decode()

    def _decrypt_secret(self, encrypted_secret: str) -> str:
        """Decrypt secret"""
        return base64.b64decode(encrypted_secret.encode()).decode()

# CLI interface
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python mfa_handler.py <config_path> [command] [args...]")
        sys.exit(1)

    config_path = sys.argv[1]
    mfa = MFAHandler(config_path)

    if len(sys.argv) > 2:
        command = sys.argv[2]

        if command == 'setup-totp':
            user_id = sys.argv[3] if len(sys.argv) > 3 else 'test-user'
            result = mfa.setup_totp(user_id)
            print(f"TOTP setup for {user_id}:")
            print(f"Secret: {result['secret']}")
            print("QR Code generated")

        elif command == 'verify-totp':
            user_id = sys.argv[3]
            code = sys.argv[4]
            valid = mfa.verify_totp(user_id, code)
            print(f"TOTP verification: {'VALID' if valid else 'INVALID'}")

        elif command == 'backup-codes':
            user_id = sys.argv[3] if len(sys.argv) > 3 else 'test-user'
            codes = mfa.setup_backup_codes(user_id)
            print(f"Backup codes for {user_id}:")
            for code in codes:
                print(f"  {code}")

        else:
            print(f"Unknown command: {command}")
EOF

sudo chmod +x "$MFA_DIR/mfa_handler.py"

# Create session management configuration
echo "Creating session management configuration..."

cat > "$AUTH_DIR/session-config.json" << EOF
{
    "version": "1.0",
    "environment": "${ENVIRONMENT}",
    "session": {
        "max_age": 3600,
        "idle_timeout": 1800,
        "absolute_timeout": 28800,
        "renew_threshold": 300,
        "secure": true,
        "httponly": true,
        "samesite": "strict"
    },
    "password_policy": {
        "min_length": 12,
        "require_uppercase": true,
        "require_lowercase": true,
        "require_digits": true,
        "require_special_chars": true,
        "max_age_days": 90,
        "prevent_reuse_count": 5,
        "lockout_attempts": 5,
        "lockout_duration_minutes": 30
    },
    "account_lockout": {
        "enabled": true,
        "max_attempts": 5,
        "lockout_duration_minutes": 30,
        "reset_after_minutes": 1440,
        "notify_on_lockout": true
    }
}
EOF

# Create password policy and account lockout handler
echo "Creating password policy and account lockout handler..."

cat > "$AUTH_DIR/auth_security.py" << 'EOF'
#!/usr/bin/env python3

import os
import json
import re
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple
import logging

class AuthSecurity:
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.auth_dir = os.path.dirname(config_path)
        self.password_history_file = os.path.join(self.auth_dir, 'password_history.json')
        self.lockout_file = os.path.join(self.auth_dir, 'account_lockouts.json')

        # Set up logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.get_logger(__name__)

    def validate_password(self, password: str, user_id: str = None) -> Tuple[bool, str]:
        """Validate password against policy"""
        policy = self.config['password_policy']

        # Check minimum length
        if len(password) < policy['min_length']:
            return False, f"Password must be at least {policy['min_length']} characters long"

        # Check character requirements
        if policy['require_uppercase'] and not re.search(r'[A-Z]', password):
            return False, "Password must contain at least one uppercase letter"

        if policy['require_lowercase'] and not re.search(r'[a-z]', password):
            return False, "Password must contain at least one lowercase letter"

        if policy['require_digits'] and not re.search(r'\d', password):
            return False, "Password must contain at least one digit"

        if policy['require_special_chars'] and not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            return False, "Password must contain at least one special character"

        # Check password history (prevent reuse)
        if user_id:
            if self._is_password_reused(user_id, password):
                return False, "Password has been used recently"

        return True, "Password is valid"

    def _is_password_reused(self, user_id: str, password: str) -> bool:
        """Check if password has been used recently"""
        history = self._load_password_history()
        policy = self.config['password_policy']

        if user_id not in history:
            return False

        password_hash = hashlib.sha256(password.encode()).hexdigest()
        recent_passwords = history[user_id][-policy['prevent_reuse_count']:]

        return password_hash in recent_passwords

    def record_password_change(self, user_id: str, new_password: str):
        """Record password change in history"""
        history = self._load_password_history()

        if user_id not in history:
            history[user_id] = []

        password_hash = hashlib.sha256(new_password.encode()).hexdigest()
        history[user_id].append({
            'hash': password_hash,
            'changed': datetime.utcnow().isoformat()
        })

        # Keep only recent passwords
        policy = self.config['password_policy']
        history[user_id] = history[user_id][-policy['prevent_reuse_count']:]

        self._save_password_history(history)

    def check_password_age(self, user_id: str, last_change: datetime) -> bool:
        """Check if password needs to be changed due to age"""
        policy = self.config['password_policy']
        max_age = timedelta(days=policy['max_age_days'])

        return datetime.utcnow() - last_change > max_age

    def check_account_lockout(self, user_id: str) -> Tuple[bool, Optional[int]]:
        """Check if account is locked out"""
        lockouts = self._load_lockouts()

        if user_id not in lockouts:
            return False, None

        lockout_data = lockouts[user_id]
        lockout_until = datetime.fromisoformat(lockout_data['lockout_until'])

        if datetime.utcnow() < lockout_until:
            remaining_minutes = int((lockout_until - datetime.utcnow()).total_seconds() / 60)
            return True, remaining_minutes

        # Lockout expired, remove it
        del lockouts[user_id]
        self._save_lockouts(lockouts)
        return False, None

    def record_failed_attempt(self, user_id: str):
        """Record failed authentication attempt"""
        lockouts = self._load_lockouts()
        lockout_config = self.config['account_lockout']

        if user_id not in lockouts:
            lockouts[user_id] = {
                'attempts': 0,
                'first_attempt': datetime.utcnow().isoformat(),
                'lockout_until': None
            }

        lockouts[user_id]['attempts'] += 1

        # Check if lockout threshold reached
        if lockouts[user_id]['attempts'] >= lockout_config['max_attempts']:
            lockout_duration = timedelta(minutes=lockout_config['lockout_duration_minutes'])
            lockout_until = datetime.utcnow() + lockout_duration

            lockouts[user_id]['lockout_until'] = lockout_until.isoformat()

            self.logger.warning(f"Account locked out: {user_id}")

            if lockout_config['notify_on_lockout']:
                # Send lockout notification (implement email/SMS)
                pass

        self._save_lockouts(lockouts)

    def record_successful_attempt(self, user_id: str):
        """Record successful authentication attempt"""
        lockouts = self._load_lockouts()

        if user_id in lockouts:
            # Reset failed attempts on successful login
            del lockouts[user_id]
            self._save_lockouts(lockouts)

    def reset_lockout(self, user_id: str):
        """Manually reset account lockout"""
        lockouts = self._load_lockouts()

        if user_id in lockouts:
            del lockouts[user_id]
            self._save_lockouts(lockouts)
            self.logger.info(f"Account lockout reset: {user_id}")

    def _load_password_history(self) -> Dict[str, Any]:
        """Load password history"""
        if os.path.exists(self.password_history_file):
            with open(self.password_history_file, 'r') as f:
                return json.load(f)
        return {}

    def _save_password_history(self, history: Dict[str, Any]):
        """Save password history"""
        with open(self.password_history_file, 'w') as f:
            json.dump(history, f, indent=2)

        os.chmod(self.password_history_file, 0o600)

    def _load_lockouts(self) -> Dict[str, Any]:
        """Load account lockouts"""
        if os.path.exists(self.lockout_file):
            with open(self.lockout_file, 'r') as f:
                return json.load(f)
        return {}

    def _save_lockouts(self, lockouts: Dict[str, Any]):
        """Save account lockouts"""
        with open(self.lockout_file, 'w') as f:
            json.dump(lockouts, f, indent=2)

        os.chmod(self.lockout_file, 0o600)

# CLI interface
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python auth_security.py <config_path> [command] [args...]")
        sys.exit(1)

    config_path = sys.argv[1]
    auth_security = AuthSecurity(config_path)

    if len(sys.argv) > 2:
        command = sys.argv[2]

        if command == 'validate-password':
            password = sys.argv[3]
            user_id = sys.argv[4] if len(sys.argv) > 4 else None
            valid, message = auth_security.validate_password(password, user_id)
            print(f"Password validation: {'VALID' if valid else 'INVALID'} - {message}")

        elif command == 'check-lockout':
            user_id = sys.argv[3]
            locked, remaining = auth_security.check_account_lockout(user_id)
            if locked:
                print(f"Account locked: {remaining} minutes remaining")
            else:
                print("Account not locked")

        elif command == 'record-failed':
            user_id = sys.argv[3]
            auth_security.record_failed_attempt(user_id)
            print(f"Failed attempt recorded for: {user_id}")

        elif command == 'record-success':
            user_id = sys.argv[3]
            auth_security.record_successful_attempt(user_id)
            print(f"Successful attempt recorded for: {user_id}")

        else:
            print(f"Unknown command: {command}")
EOF

sudo chmod +x "$AUTH_DIR/auth_security.py"

# Update environment configuration
echo "Updating environment configuration..."

cat >> ".env.${ENVIRONMENT}" << EOF

# OAuth Configuration
OAUTH_ENABLED=true
OAUTH_CONFIG_PATH=$OAUTH_DIR/oauth-config.json
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:-your-google-client-id}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET:-your-google-client-secret}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID:-your-github-client-id}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET:-your-github-client-secret}

# MFA Configuration
MFA_ENABLED=true
MFA_CONFIG_PATH=$MFA_DIR/mfa-config.json
MFA_REQUIRED_ROLES=admin,manager

# Session Management
SESSION_CONFIG_PATH=$AUTH_DIR/session-config.json
SESSION_SECRET_KEY=${SESSION_SECRET_KEY:-generate-a-secure-random-key}
JWT_SECRET_KEY=${JWT_SECRET_KEY:-generate-a-secure-random-key}

# Password Policy
PASSWORD_POLICY_CONFIG_PATH=$AUTH_DIR/session-config.json
PASSWORD_MIN_LENGTH=12
PASSWORD_MAX_AGE_DAYS=90
ACCOUNT_LOCKOUT_ENABLED=true
ACCOUNT_LOCKOUT_MAX_ATTEMPTS=5
ACCOUNT_LOCKOUT_DURATION_MINUTES=30
EOF

# Create test script
echo "Creating test script..."

cat > "$AUTH_DIR/test-auth.sh" << 'EOF'
#!/bin/bash

# Test authentication setup
AUTH_DIR="/opt/gravitypm/auth"
OAUTH_DIR="$AUTH_DIR/oauth"
MFA_DIR="$AUTH_DIR/mfa"

echo "Testing OAuth setup..."
python3 "$OAUTH_DIR/oauth_handler.py" "$OAUTH_DIR/oauth-config.json" test

echo -e "\nTesting MFA setup..."
python3 "$MFA_DIR/mfa_handler.py" "$MFA_DIR/mfa-config.json" setup-totp test-user

echo -e "\nTesting password policy..."
python3 "$AUTH_DIR/auth_security.py" "$AUTH_DIR/session-config.json" validate-password "Test
