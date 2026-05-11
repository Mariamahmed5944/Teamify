import re
from marshmallow import Schema, fields, validate, validates, ValidationError, pre_load

# At least 8 chars, 1 uppercase letter, 1 digit
PASSWORD_RE = re.compile(r'^(?=.*[A-Z])(?=.*\d).{8,}$')

VALID_ROLES = ["member", "guest", "admin"]
VALID_USER_TYPES = ["freelancer", "student", "admin"]


class RegisterSchema(Schema):
    display_name = fields.Str(required=True, validate=validate.Length(min=1, max=50))
    email = fields.Email(required=True)
    password = fields.Str(required=True)
    full_name = fields.Str(load_default=None, validate=validate.Length(max=100))
    role = fields.Str(
        load_default="member",
        validate=validate.OneOf(VALID_ROLES, error="Invalid role")
    )
    user_type = fields.Str(
        load_default=None,
        validate=validate.OneOf(VALID_USER_TYPES, error="Invalid user_type")
    )
    professional_field = fields.Str(load_default=None)
    experience_level = fields.Str(load_default=None)
    availability = fields.Str(load_default=None)
    skills = fields.Str(load_default=None)
    current_level = fields.Str(load_default=None)
    major = fields.Str(load_default=None)
    looking_for_team = fields.Bool(load_default=None)
    reason_for_joining = fields.Str(load_default=None)

    @pre_load
    def sanitize_strings(self, data, **kwargs):
        """Sanitize string fields before validation (strip whitespace and block basic XSS)."""
        xss_re = re.compile(r'<.*?>')
        for key, value in data.items():
            if isinstance(value, str):
                sanitized = xss_re.sub("", value).strip()
                data[key] = sanitized
        return data

    @validates("password")
    def validate_password(self, value):
        if not PASSWORD_RE.match(value):
            raise ValidationError(
                "Password must be at least 8 characters with 1 uppercase letter and 1 digit"
            )


class LoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.Str(required=True)


class ProfileUpdateSchema(Schema):
    full_name = fields.Str(validate=validate.Length(max=100))
    user_type = fields.Str(
        validate=validate.OneOf(VALID_USER_TYPES, error="Invalid user_type")
    )
    professional_field = fields.Str()
    experience_level = fields.Str()
    availability = fields.Str()
    skills = fields.Str()
    current_level = fields.Str()
    major = fields.Str()
    looking_for_team = fields.Bool()
    reason_for_joining = fields.Str()


# Schema singletons
register_schema = RegisterSchema()
login_schema = LoginSchema()
profile_update_schema = ProfileUpdateSchema()
