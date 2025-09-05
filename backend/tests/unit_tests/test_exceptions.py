import pytest
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.exceptions import (
    GravityPMException,
    ValidationError,
    AuthenticationError,
    AuthorizationError,
    NotFoundError,
    ConflictError,
    BusinessLogicError,
    ExternalServiceError
)

class TestExceptions:
    def test_gravity_pm_exception(self):
        exc = GravityPMException(status_code=500, detail="Test error")
        assert exc.detail == "Test error"
        assert exc.status_code == 500

    def test_validation_error(self):
        exc = ValidationError("Invalid input")
        assert exc.detail == "Invalid input"
        assert exc.status_code == 400
        assert exc.error_code == "VALIDATION_ERROR"

    def test_authentication_error(self):
        exc = AuthenticationError("Invalid credentials")
        assert exc.detail == "Invalid credentials"
        assert exc.status_code == 401
        assert exc.error_code == "AUTHENTICATION_ERROR"

    def test_authorization_error(self):
        exc = AuthorizationError("Access denied")
        assert exc.detail == "Access denied"
        assert exc.status_code == 403
        assert exc.error_code == "AUTHORIZATION_ERROR"

    def test_not_found_error(self):
        exc = NotFoundError("User", "123")
        assert exc.detail == "User not found: 123"
        assert exc.status_code == 404
        assert exc.error_code == "NOT_FOUND_ERROR"

    def test_conflict_error(self):
        exc = ConflictError("Resource already exists", "Project")
        assert exc.detail == "Resource already exists"
        assert exc.status_code == 409
        assert exc.error_code == "CONFLICT_ERROR"

    def test_business_logic_error(self):
        exc = BusinessLogicError("Invalid operation", "rule1")
        assert exc.detail == "Invalid operation"
        assert exc.status_code == 400
        assert exc.error_code == "BUSINESS_LOGIC_ERROR"

    def test_external_service_error(self):
        exc = ExternalServiceError("GitHub", "Service unavailable")
        assert exc.detail == "GitHub: Service unavailable"
        assert exc.status_code == 502
        assert exc.error_code == "EXTERNAL_SERVICE_ERROR"
