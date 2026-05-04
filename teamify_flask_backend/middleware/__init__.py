from functools import wraps
from flask import jsonify
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity


def auth_required(fn):
    """
    Auth guard middleware decorator.
    Protects routes by requiring a valid JWT token in the
    Authorization header (Bearer <token>).
    Returns 401 if token is missing, invalid, or expired.
    """

    @wraps(fn)
    def wrapper(*args, **kwargs):
        try:
            verify_jwt_in_request()
        except Exception as e:
            return jsonify({"error": "Unauthorized", "message": str(e)}), 401
        return fn(*args, **kwargs)

    return wrapper
