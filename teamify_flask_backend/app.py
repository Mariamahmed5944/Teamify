import os
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt
from flask_migrate import Migrate
from flasgger import Swagger
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from config import Config
from models import db

# Module-level limiter so routes can import it without circular deps
limiter = Limiter(key_func=get_remote_address, storage_uri="memory://")


def create_app(test_config=None):
    """Create and configure the Flask application."""

    app = Flask(__name__)
    app.config.from_object(Config)
    if test_config is not None:
        app.config.update(test_config)

    # --- Initialize Extensions ---
    db.init_app(app)
    Migrate(app, db)          # enables: flask db init / migrate / upgrade
    CORS(app, resources={r"/api/*": {
        "origins": os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080").split(","),
        "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }})
    jwt = JWTManager(app)
    Bcrypt(app)
    limiter.init_app(app)

    # --- JWT Token Blacklist ---
    BLACKLISTED_TOKENS: set = set()

    @jwt.token_in_blocklist_loader
    def check_if_token_revoked(jwt_header, jwt_payload):
        return jwt_payload["jti"] in BLACKLISTED_TOKENS

    # Make blacklist accessible from routes via app config
    app.config["BLACKLISTED_TOKENS"] = BLACKLISTED_TOKENS

    # --- Swagger Configuration ---
    is_production = os.getenv("FLASK_ENV") == "production"

    swagger_config = {
        "headers": [],
        "specs": [
            {
                "endpoint": "apispec",
                "route": "/apispec.json",
                "rule_filter": lambda rule: True,
                "model_filter": lambda tag: True,
            }
        ],
        "static_url_path": "/flasgger_static",
        "swagger_ui": not is_production,
        "specs_route": "/swagger/",
    }

    swagger_template = {
        "info": {
            "title": "Backend Task 1 API",
            "description": "REST API with Auth, JWT, and DB Schema",
            "version": "1.0.0",
        },
        "securityDefinitions": {
            "Bearer": {
                "type": "apiKey",
                "name": "Authorization",
                "in": "header",
                "description": "JWT token. Format: Bearer <token>",
            }
        },
    }

    Swagger(app, config=swagger_config, template=swagger_template)

    # --- Security Headers ---
    @app.after_request
    def set_security_headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if is_production:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response

    # --- Global Error Handlers ---
    @app.errorhandler(413)
    def request_entity_too_large(e):
        return jsonify({"error": "Payload Too Large", "message": "Request body exceeds the 5 MB limit"}), 413

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Not Found", "message": "The requested URL was not found"}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"error": "Method Not Allowed"}), 405

    @app.errorhandler(500)
    def internal_server_error(e):
        return jsonify({"error": "Internal Server Error"}), 500

    # --- Register Blueprints ---
    from routes.auth import auth_bp
    from routes.users import users_bp
    from routes.projects import projects_bp
    from routes.tasks import tasks_bp
    from routes.logs import logs_bp
    from routes.ai import ai_bp
    from routes.stats import stats_bp
    from routes.reminders import reminders_bp
    from routes.notifications import notifications_bp
    from routes.dashboard import dashboard_bp
    from routes.search import search_bp
    from routes.admin import admin_bp
    from routes.files import files_bp
    from routes.comments import comments_bp
    from routes.feedback import feedback_bp
    from routes.ratings import ratings_bp
    from routes.cv import cv_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(users_bp)
    app.register_blueprint(projects_bp)
    app.register_blueprint(tasks_bp)
    app.register_blueprint(logs_bp)
    app.register_blueprint(ai_bp)
    app.register_blueprint(stats_bp)
    app.register_blueprint(reminders_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(search_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(files_bp)
    app.register_blueprint(comments_bp)
    app.register_blueprint(feedback_bp)
    app.register_blueprint(ratings_bp)
    app.register_blueprint(cv_bp)

    # ─── Health Check ─────────────────────────────────────────────────────────
    @app.route("/api/health", methods=["GET"])
    def health():
        """
        Health check — confirms the API and database are reachable.
        ---
        tags:
          - Health
        responses:
          200:
            description: API is healthy
            schema:
              type: object
              properties:
                status:
                  type: string
                  example: ok
                database:
                  type: string
                  example: ok
          503:
            description: Database unreachable
        """
        from sqlalchemy import text
        try:
            db.session.execute(text("SELECT 1"))
            db_status = "ok"
            http_status = 200
        except Exception:
            db_status = "error"
            http_status = 503
        return jsonify({"status": "ok" if http_status == 200 else "degraded", "database": db_status}), http_status

    # --- Import models + create tables if they don't exist ---
    with app.app_context():
        from models.user import User
        from models.project import Project
        from models.project_member import ProjectMember
        from models.task import Task
        from models.log import Log
        from models.notification import Notification
        from models.login_log import LoginLog
        from models.alert import Alert
        from models.file_metadata import FileMetadata
        from models.task_comment import TaskComment
        from models.feedback import Feedback
        from models.rating import Rating
        from models.cv import CV
        from models.cv_download_token import CVDownloadToken
        from models.audit_log import AuditLog

        db.create_all()  # ← مهم: بينشئ الجداول في PostgreSQL لو مش موجودة

    # --- Start reminders scheduler ---
    from services.scheduler import init_scheduler
    init_scheduler(app)

    return app


if __name__ == "__main__":
    app = create_app()
    port = int(os.getenv("PORT", 5022))
    debug = os.getenv("FLASK_DEBUG", "False").lower() in ("true", "1")
    host = "127.0.0.1" if debug else "0.0.0.0"

    print(f"[OK] Server running on http://localhost:{port}")
    print(f"[OK] Debug mode: {debug}")
    print(f"[OK] Swagger UI: http://localhost:{port}/swagger/")
    print(f"[OK] Endpoints:")
    print(f"    POST /api/auth/register")
    print(f"    POST /api/auth/login")
    print(f"    GET  /api/users/profile        (protected)")
    print(f"    GET  /api/users/admin-dashboard (admin only)")

    app.run(host=host, port=port, debug=debug)
