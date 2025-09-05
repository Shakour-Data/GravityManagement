import pytest
from pydantic import ValidationError
from app.models.user import User, UserCreate, UserUpdate, Token, TokenData

class TestUserModel:
    def test_user_creation_valid(self):
        user = User(
            username="testuser",
            email="test@example.com",
            full_name="Test User",
            role="user"
        )
        assert user.username == "testuser"
        assert user.email == "test@example.com"
        assert user.full_name == "Test User"
        assert user.role == "user"
        assert user.disabled is False

    def test_user_creation_invalid_username(self):
        with pytest.raises(ValidationError):
            User(
                username="us",  # too short
                email="test@example.com"
            )

    def test_user_creation_invalid_email(self):
        with pytest.raises(ValidationError):
            User(
                username="testuser",
                email="invalid-email"
            )

    def test_user_creation_invalid_role(self):
        with pytest.raises(ValidationError):
            User(
                username="testuser",
                email="test@example.com",
                role="invalid"
            )

    def test_username_validator_alphanumeric(self):
        user = User(
            username="test_user-123",
            email="test@example.com"
        )
        assert user.username == "test_user-123"

    def test_username_validator_invalid(self):
        with pytest.raises(ValidationError):
            User(
                username="test@user",
                email="test@example.com"
            )

    def test_role_validator_valid(self):
        user = User(
            username="testuser",
            email="test@example.com",
            role="admin"
        )
        assert user.role == "admin"

    def test_role_validator_invalid(self):
        with pytest.raises(ValidationError):
            User(
                username="testuser",
                email="test@example.com",
                role="superuser"
            )

class TestUserCreateModel:
    def test_user_create_valid(self):
        user_create = UserCreate(
            username="testuser",
            email="test@example.com",
            password="Password123",
            full_name="Test User"
        )
        assert user_create.username == "testuser"
        assert user_create.email == "test@example.com"
        assert user_create.password == "Password123"
        assert user_create.full_name == "Test User"

    def test_user_create_password_weak(self):
        with pytest.raises(ValidationError):
            UserCreate(
                username="testuser",
                email="test@example.com",
                password="password"  # no upper, no digit
            )

    def test_user_create_password_missing_upper(self):
        with pytest.raises(ValidationError):
            UserCreate(
                username="testuser",
                email="test@example.com",
                password="password123"  # no upper
            )

    def test_user_create_password_missing_lower(self):
        with pytest.raises(ValidationError):
            UserCreate(
                username="testuser",
                email="test@example.com",
                password="PASSWORD123"  # no lower
            )

    def test_user_create_password_missing_digit(self):
        with pytest.raises(ValidationError):
            UserCreate(
                username="testuser",
                email="test@example.com",
                password="Password"  # no digit
            )

class TestUserUpdateModel:
    def test_user_update_valid(self):
        user_update = UserUpdate(
            email="new@example.com",
            full_name="New Name",
            disabled=True
        )
        assert user_update.email == "new@example.com"
        assert user_update.full_name == "New Name"
        assert user_update.disabled is True

class TestTokenModel:
    def test_token_creation(self):
        token = Token(
            access_token="token123",
            token_type="bearer"
        )
        assert token.access_token == "token123"
        assert token.token_type == "bearer"

class TestTokenDataModel:
    def test_token_data_creation(self):
        token_data = TokenData(username="testuser")
        assert token_data.username == "testuser"

    def test_token_data_none_username(self):
        token_data = TokenData()
        assert token_data.username is None
