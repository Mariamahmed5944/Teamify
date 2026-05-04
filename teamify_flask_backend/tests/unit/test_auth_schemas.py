import pytest
from marshmallow import ValidationError
from validators.auth_validator import register_schema, login_schema, profile_update_schema

class TestRegisterSchema:
    def test_valid_payload(self):
        """Test registration schema with a complete valid payload."""
        payload = {
            "display_name": "johndoe",
            "email": "john@example.com",
            "password": "Password1",
            "role": "member",
            "user_type": "freelancer",
            "full_name": "John Doe"
        }
        result = register_schema.load(payload)
        assert result["email"] == "john@example.com"
        assert result["display_name"] == "johndoe"
        assert result["role"] == "member"

    def test_missing_required_fields(self):
        """Test registration schema throws errors for missing required fields."""
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({})
        
        errors = exc_info.value.messages
        assert "display_name" in errors
        assert "email" in errors
        assert "password" in errors

    def test_invalid_email_format(self):
        """Test email format validation."""
        payload = {
            "display_name": "johndoe",
            "email": "not-an-email",
            "password": "Password1"
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)
        
        assert "email" in exc_info.value.messages

    def test_invalid_password_complexity(self):
        """Test strict password complexity logic (min 8 chars, 1 uppercase, 1 digit)."""
        # Weak password missing uppercase
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({"display_name": "u", "email": "a@b.com", "password": "password1"})
        assert "password" in exc_info.value.messages

        # Weak password missing digit
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load({"display_name": "u", "email": "a@b.com", "password": "Password"})
        assert "password" in exc_info.value.messages

    def test_invalid_role(self):
        """Test that only approved roles are allowed."""
        payload = {
            "display_name": "johndoe",
            "email": "a@b.com",
            "password": "Password1",
            "role": "hacker"
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)
            
        assert "role" in exc_info.value.messages

    def test_invalid_user_type(self):
        """Test that only approved user types are allowed."""
        payload = {
            "display_name": "johndoe",
            "email": "a@b.com",
            "password": "Password1",
            "user_type": "unknown_type"
        }
        with pytest.raises(ValidationError) as exc_info:
            register_schema.load(payload)
            
        assert "user_type" in exc_info.value.messages

class TestLoginSchema:
    def test_valid_login(self):
        """Test login schema with valid email and password."""
        payload = {
            "email": "john@example.com",
            "password": "Password1"
        }
        result = login_schema.load(payload)
        assert result["email"] == "john@example.com"

    def test_missing_login_fields(self):
        """Test that login requires both email and password."""
        with pytest.raises(ValidationError) as exc_info:
            login_schema.load({})
            
        assert "email" in exc_info.value.messages
        assert "password" in exc_info.value.messages

    def test_login_invalid_email(self):
        """Test that login validates email structure."""
        with pytest.raises(ValidationError) as exc_info:
            login_schema.load({"email": "bademail", "password": "Password1"})
            
        assert "email" in exc_info.value.messages

class TestProfileUpdateSchema:
    def test_valid_profile_update(self):
        """Test valid partial profile update."""
        payload = {
            "full_name": "Jane Doe",
            "looking_for_team": True,
            "skills": "Python, Flask"
        }
        result = profile_update_schema.load(payload)
        assert result["full_name"] == "Jane Doe"
        assert result["looking_for_team"] is True
        assert result["skills"] == "Python, Flask"

    def test_invalid_data_types(self):
        """Test that schema rejects incorrect data types."""
        payload = {
            "looking_for_team": "not-a-boolean" # Should fail coercion
        }
        with pytest.raises(ValidationError) as exc_info:
            profile_update_schema.load(payload)
            
        assert "looking_for_team" in exc_info.value.messages
