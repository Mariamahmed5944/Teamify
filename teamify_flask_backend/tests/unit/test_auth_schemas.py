from typing import Any

import pytest
from marshmallow import Schema, ValidationError

from validators.auth_validator import login_schema, profile_update_schema, register_schema


def _load(schema: Schema, payload: dict[str, Any]) -> dict[str, Any]:
    result = schema.load(payload)
    assert isinstance(result, dict)
    return result


def _validation_messages(exc_info: pytest.ExceptionInfo[ValidationError]) -> dict[str, Any]:
    messages = exc_info.value.messages
    assert isinstance(messages, dict)
    return messages


class TestRegisterSchema:
    def test_valid_payload(self):
        """Test registration schema with a complete valid payload."""
        payload = {
            "email": "john@example.com",
            "password": "Password1",
            "role": "member",
            "user_type": "freelancer",
            "full_name": "John Doe",
        }
        result = _load(register_schema, payload)
        assert result["email"] == "john@example.com"
        assert result["full_name"] == "John Doe"
        assert result["role"] == "member"

    def test_missing_required_fields(self):
        """Test registration schema throws errors for missing required fields."""
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({})

        errors = _validation_messages(exc_info)
        assert "full_name" in errors
        assert "email" in errors
        assert "password" in errors

    def test_invalid_email_format(self):
        """Test email format validation."""
        payload = {
            "full_name": "John Doe",
            "email": "not-an-email",
            "password": "Password1",
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)

        assert "email" in _validation_messages(exc_info)

    def test_invalid_password_complexity(self):
        """Test strict password complexity logic (min 8 chars, 1 uppercase, 1 digit)."""
        base = {"full_name": "John Doe", "email": "a@b.com"}
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({**base, "password": "password1"})
        assert "password" in _validation_messages(exc_info)

        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({**base, "password": "Password"})
        assert "password" in _validation_messages(exc_info)

    def test_invalid_role(self):
        """Test that only approved roles are allowed."""
        payload = {
            "full_name": "John Doe",
            "email": "a@b.com",
            "password": "Password1",
            "role": "hacker",
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)

        assert "role" in _validation_messages(exc_info)

    def test_invalid_user_type(self):
        """Test that only approved user types are allowed."""
        payload = {
            "full_name": "John Doe",
            "email": "a@b.com",
            "password": "Password1",
            "user_type": "unknown_type",
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)

        assert "user_type" in _validation_messages(exc_info)

    def test_legacy_display_name_optional(self):
        """display_name may be sent by old clients but is not required at signup."""
        payload = {
            "display_name": "legacy_handle",
            "email": "legacy@example.com",
            "password": "Password1",
            "full_name": "Legacy User",
        }
        result = _load(register_schema, payload)
        assert result["display_name"] == "legacy_handle"
        assert result["full_name"] == "Legacy User"

    def test_empty_full_name_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({
                "email": "a@b.com",
                "password": "Password1",
                "full_name": "   ",
            })
        assert "full_name" in _validation_messages(exc_info)


class TestLoginSchema:
    def test_valid_login(self):
        """Test login schema with valid email and password."""
        payload = {
            "email": "john@example.com",
            "password": "Password1"
        }
        result = _load(login_schema, payload)
        assert result["email"] == "john@example.com"

    def test_missing_login_fields(self):
        """Test that login requires both email and password."""
        with pytest.raises(ValidationError) as exc_info:
            login_schema.load({})

        errors = _validation_messages(exc_info)
        assert "email" in errors
        assert "password" in errors

    def test_login_invalid_email(self):
        """Test that login validates email structure."""
        with pytest.raises(ValidationError) as exc_info:
            login_schema.load({"email": "bademail", "password": "Password1"})

        assert "email" in _validation_messages(exc_info)


class TestProfileUpdateSchema:
    def test_valid_profile_update(self):
        """Test valid partial profile update."""
        payload = {
            "full_name": "Jane Doe",
            "looking_for_team": True,
            "skills": "Python, Flask"
        }
        result = _load(profile_update_schema, payload)
        assert result["full_name"] == "Jane Doe"
        assert result["looking_for_team"] is True
        assert result["skills"] == "Python, Flask"

    def test_username_update(self):
        """Profile may set a unique username via display_name."""
        payload = {"display_name": "mohamed_dev", "full_name": "Mohamed Ali"}
        result = _load(profile_update_schema, payload)
        assert result["display_name"] == "mohamed_dev"
        assert result["full_name"] == "Mohamed Ali"

    def test_username_too_short_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            profile_update_schema.load({"display_name": "ab"})
        assert "display_name" in _validation_messages(exc_info)

    def test_invalid_data_types(self):
        """Test that schema rejects incorrect data types."""
        payload = {
            "looking_for_team": "not-a-boolean"  # Should fail coercion
        }
        with pytest.raises(ValidationError) as exc_info:
            profile_update_schema.load(payload)

        assert "looking_for_team" in _validation_messages(exc_info)
