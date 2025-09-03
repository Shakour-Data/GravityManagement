import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from typing import Optional


class EncryptionService:
    def __init__(self, key: Optional[str] = None):
        if key is None:
            # Generate a new key if none provided
            self.key = Fernet.generate_key()
        else:
            # Use provided key or derive from environment
            env_key = os.getenv('ENCRYPTION_KEY')
            if env_key:
                self.key = base64.urlsafe_b64decode(env_key)
            else:
                # Derive key from provided string
                salt = b'gravitypm_salt_2024'
                kdf = PBKDF2HMAC(
                    algorithm=hashes.SHA256(),
                    length=32,
                    salt=salt,
                    iterations=100000,
                )
                self.key = base64.urlsafe_b64encode(kdf.derive(key.encode()))

        self.fernet = Fernet(self.key)

    def encrypt(self, data: str) -> str:
        """Encrypt a string and return base64 encoded result"""
        if not data:
            return data
        encrypted = self.fernet.encrypt(data.encode())
        return base64.urlsafe_b64encode(encrypted).decode()

    def decrypt(self, encrypted_data: str) -> str:
        """Decrypt a base64 encoded encrypted string"""
        if not encrypted_data:
            return encrypted_data
        try:
            encrypted = base64.urlsafe_b64decode(encrypted_data.encode())
            decrypted = self.fernet.decrypt(encrypted)
            return decrypted.decode()
        except Exception as e:
            raise ValueError(f"Decryption failed: {str(e)}")

    def get_key_b64(self) -> str:
        """Get the encryption key in base64 format for storage"""
        return base64.urlsafe_b64encode(self.key).decode()


# Global encryption service instance
encryption_service = EncryptionService()


def encrypt_sensitive_data(data: str) -> str:
    """Convenience function to encrypt sensitive data"""
    return encryption_service.encrypt(data)


def decrypt_sensitive_data(encrypted_data: str) -> str:
    """Convenience function to decrypt sensitive data"""
    return encryption_service.decrypt(encrypted_data)
