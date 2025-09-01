from typing import Optional, Dict, Any
from fastapi import HTTPException

class GravityPMException(HTTPException):
    """Base exception class for GravityPM application"""

    def __init__(
        self,
        status_code: int,
        detail: str,
        error_code: Optional[str] = None,
        extra_data: Optional[Dict[str, Any]] = None
    ):
        super().__init__(status_code=status_code, detail=detail)
        self.error_code = error_code
        self.extra_data = extra_data or {}

class ValidationError(GravityPMException):
    """Exception raised for validation errors"""

    def __init__(self, detail: str, field: Optional[str] = None):
        super().__init__(
            status_code=400,
            detail=detail,
            error_code="VALIDATION_ERROR",
            extra_data={"field": field} if field else {}
        )

class AuthenticationError(GravityPMException):
    """Exception raised for authentication failures"""

    def __init__(self, detail: str = "Authentication failed"):
        super().__init__(
            status_code=401,
            detail=detail,
            error_code="AUTHENTICATION_ERROR"
        )

class AuthorizationError(GravityPMException):
    """Exception raised for authorization failures"""

    def __init__(self, detail: str = "Not authorized to perform this action"):
        super().__init__(
            status_code=403,
            detail=detail,
            error_code="AUTHORIZATION_ERROR"
        )

class NotFoundError(GravityPMException):
    """Exception raised when a resource is not found"""

    def __init__(self, resource_type: str, resource_id: Optional[str] = None):
        detail = f"{resource_type} not found"
        if resource_id:
            detail += f": {resource_id}"
        super().__init__(
            status_code=404,
            detail=detail,
            error_code="NOT_FOUND_ERROR",
            extra_data={"resource_type": resource_type, "resource_id": resource_id}
        )

class ConflictError(GravityPMException):
    """Exception raised for conflicts (e.g., duplicate resources)"""

    def __init__(self, detail: str, resource_type: Optional[str] = None):
        super().__init__(
            status_code=409,
            detail=detail,
            error_code="CONFLICT_ERROR",
            extra_data={"resource_type": resource_type} if resource_type else {}
        )

class BusinessLogicError(GravityPMException):
    """Exception raised for business logic violations"""

    def __init__(self, detail: str, rule: Optional[str] = None):
        super().__init__(
            status_code=400,
            detail=detail,
            error_code="BUSINESS_LOGIC_ERROR",
            extra_data={"rule": rule} if rule else {}
        )

class ExternalServiceError(GravityPMException):
    """Exception raised for external service failures"""

    def __init__(self, service_name: str, detail: str):
        super().__init__(
            status_code=502,
            detail=f"{service_name}: {detail}",
            error_code="EXTERNAL_SERVICE_ERROR",
            extra_data={"service": service_name}
        )

# Convenience functions for common exceptions
def raise_validation_error(detail: str, field: Optional[str] = None) -> None:
    """Raise a validation error"""
    raise ValidationError(detail=detail, field=field)

def raise_authentication_error(detail: str = "Authentication failed") -> None:
    """Raise an authentication error"""
    raise AuthenticationError(detail=detail)

def raise_authorization_error(detail: str = "Not authorized to perform this action") -> None:
    """Raise an authorization error"""
    raise AuthorizationError(detail=detail)

def raise_not_found_error(resource_type: str, resource_id: Optional[str] = None) -> None:
    """Raise a not found error"""
    raise NotFoundError(resource_type=resource_type, resource_id=resource_id)

def raise_conflict_error(detail: str, resource_type: Optional[str] = None) -> None:
    """Raise a conflict error"""
    raise ConflictError(detail=detail, resource_type=resource_type)

def raise_business_logic_error(detail: str, rule: Optional[str] = None) -> None:
    """Raise a business logic error"""
    raise BusinessLogicError(detail=detail, rule=rule)

def raise_external_service_error(service_name: str, detail: str) -> None:
    """Raise an external service error"""
    raise ExternalServiceError(service_name=service_name, detail=detail)
