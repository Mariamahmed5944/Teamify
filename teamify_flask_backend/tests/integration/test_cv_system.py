"""
Integration Tests — CV System, Mentor, Skill Whitelist, Token Downloads, AuditLog DB
=====================================================================================
Covers all 4 gaps and the full CV lifecycle with real DB operations.

Requires: pytest.mark.integration (real DB, no mocks)
"""
import json
import pytest
from models import db
from models.user import User
from models.cv import CV
from models.cv_download_token import CVDownloadToken
from models.audit_log import AuditLog
from flask_jwt_extended import create_access_token
from flask_bcrypt import generate_password_hash

pytestmark = pytest.mark.integration


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def clean_tables(app, _db):
    """Start every test with a clean slate."""
    with app.app_context():
        CVDownloadToken.query.delete()
        CV.query.delete()
        AuditLog.query.delete()
        User.query.filter(User.id > 0).delete()
        db.session.commit()
        yield
        CVDownloadToken.query.delete()
        CV.query.delete()
        AuditLog.query.delete()
        User.query.filter(User.id > 0).delete()
        db.session.commit()


def _seed_user(role="member", display="cv_user", email="cv@test.com"):
    hashed = generate_password_hash("Password123").decode("utf-8")
    user = User(display_name=display, email=email, password=hashed, role=role,
                skills=["Python", "Flask"])
    db.session.add(user)
    db.session.commit()
    return user


def _make_token(app, user_id):
    with app.app_context():
        return create_access_token(identity=str(user_id))


def _auth(token):
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


# ─── Valid CV payload ─────────────────────────────────────────────────────────

VALID_CV = {
    "personal_info": {
        "full_name": "Ahmad Ali",
        "email": "ahmad@test.com",
        "phone": "+962799999999",
        "location": "Amman, Jordan",
    },
    "skills": [
        {"name": "Python", "level": "Expert", "years": 5},
        {"name": "Flask", "level": "Advanced", "years": 3},
    ],
    "experience": [
        {
            "company": "TechCo",
            "title": "Backend Developer",
            "start_date": "2022-01",
            "end_date": "2024-06",
            "description": "Built REST APIs with Flask.",
        },
    ],
    "projects": [
        {
            "name": "Teamify",
            "description": "Team management platform.",
            "start_date": "2024-01",
            "tech_stack": ["Python", "Flask", "PostgreSQL"],
        },
    ],
    "education": [
        {
            "institution": "University of Jordan",
            "degree": "BSc",
            "field": "Computer Science",
            "start_date": "2018",
            "end_date": "2022",
            "gpa": 3.5,
        },
    ],
    "certifications": [
        {"name": "AWS Certified Developer", "issuer": "Amazon", "date": "2023-06"},
    ],
    "is_public": True,
}


# ═══════════════════════════════════════════════════════════════════════════════
# GAP 1 — Skill Name Whitelist
# ═══════════════════════════════════════════════════════════════════════════════

class TestSkillWhitelist:
    """Verify that unknown skill names are rejected and valid ones pass."""

    def test_valid_skill_accepted(self, app):
        from validators.cv_validator import cv_create_schema
        data = dict(VALID_CV)
        result = cv_create_schema.load(data)
        assert len(result["skills"]) == 2
        assert result["skills"][0]["name"] == "Python"

    def test_fake_skill_rejected(self, app):
        from validators.cv_validator import cv_create_schema
        from marshmallow import ValidationError
        data = dict(VALID_CV)
        data["skills"] = [{"name": "DefinitelyFakeSkill999", "level": "Advanced"}]
        with pytest.raises(ValidationError) as exc_info:
            cv_create_schema.load(data)
        assert "skills" in exc_info.value.messages

    def test_skill_validation_case_insensitive(self, app):
        from validators.cv_validator import cv_create_schema
        data = dict(VALID_CV)
        data["skills"] = [{"name": "python", "level": "Expert"}]
        result = cv_create_schema.load(data)
        assert result["skills"][0]["name"] == "python"

    def test_xss_in_skill_name_stripped(self, app):
        from validators.cv_validator import cv_create_schema
        from marshmallow import ValidationError
        data = dict(VALID_CV)
        data["skills"] = [{"name": "<script>alert('xss')</script>React", "level": "Advanced"}]
        # After stripping tags, name becomes "alert('xss')React" which is not on whitelist
        with pytest.raises(ValidationError):
            cv_create_schema.load(data)


# ═══════════════════════════════════════════════════════════════════════════════
# CV CRUD — Logic Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCVCreate:
    """POST /api/cv — create/replace CV."""

    def test_member_creates_cv(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                r = c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                assert r.status_code == 201
                body = r.get_json()
                assert body["cv"]["personal_info"]["full_name"] == "Ahmad Ali"
                assert body["cv"]["summary"] is not None  # AI summary generated

    def test_guest_cannot_create_cv(self, app, _db):
        with app.app_context():
            guest = _seed_user(role="guest", display="guest_cv", email="g@t.com")
            token = _make_token(app, guest.id)
            with app.test_client() as c:
                r = c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                assert r.status_code == 403

    def test_invalid_payload_rejected(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                # Missing required personal_info
                r = c.post("/api/cv", json={"skills": []}, headers=_auth(token))
                assert r.status_code == 400

    def test_upsert_replaces_existing(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                updated = dict(VALID_CV)
                updated["personal_info"]["full_name"] = "Updated Name"
                r = c.post("/api/cv", json=updated, headers=_auth(token))
                assert r.status_code == 200
                assert r.get_json()["cv"]["personal_info"]["full_name"] == "Updated Name"
                # Only one CV row should exist
                assert CV.query.filter_by(user_id=user.id).count() == 1


class TestCVRead:
    """GET /api/cv/<id> — IDOR checks."""

    def test_owner_can_read_own_cv(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                r1 = c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv_id = r1.get_json()["cv"]["id"]
                r2 = c.get(f"/api/cv/{cv_id}", headers=_auth(token))
                assert r2.status_code == 200

    def test_member_cannot_read_other_cv(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            other = _seed_user(display="other", email="other@t.com")
            token_owner = _make_token(app, owner.id)
            token_other = _make_token(app, other.id)
            with app.test_client() as c:
                r1 = c.post("/api/cv", json=VALID_CV, headers=_auth(token_owner))
                cv_id = r1.get_json()["cv"]["id"]
                r2 = c.get(f"/api/cv/{cv_id}", headers=_auth(token_other))
                assert r2.status_code == 403

    def test_admin_can_read_any_cv(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            admin = _seed_user(role="admin", display="adm", email="a@t.com")
            with app.test_client() as c:
                r1 = c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv_id = r1.get_json()["cv"]["id"]
                r2 = c.get(f"/api/cv/{cv_id}", headers=_auth(_make_token(app, admin.id)))
                assert r2.status_code == 200

    def test_guest_sees_public_cv_redacted(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            guest = _seed_user(role="guest", display="g", email="g@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                r = c.get(f"/api/cv/{cv.id}", headers=_auth(_make_token(app, guest.id)))
                assert r.status_code == 200
                body = r.get_json()
                # Redacted: no experience, no projects, no summary
                assert "experience" not in body
                assert "projects" not in body
                assert "skills" in body


# ═══════════════════════════════════════════════════════════════════════════════
# GAP 2 — Mentor Endpoints
# ═══════════════════════════════════════════════════════════════════════════════

class TestMentorEndpoints:
    """AI Mentor recommendations, performance, and courses."""

    def test_owner_gets_recommendations(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/recommendations/{user.id}", headers=_auth(token))
                assert r.status_code == 200
                data = r.get_json()
                assert "career_summary" in data
                assert "next_steps" in data
                assert "career_path_percentage" in data

    def test_non_owner_blocked_from_recommendations(self, app, _db):
        with app.app_context():
            user = _seed_user()
            spy = _seed_user(display="spy", email="spy@t.com")
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/recommendations/{user.id}",
                          headers=_auth(_make_token(app, spy.id)))
                assert r.status_code == 403

    def test_owner_gets_performance(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/performance/{user.id}",
                          headers=_auth(_make_token(app, user.id)))
                assert r.status_code == 200
                data = r.get_json()
                assert "scores" in data
                assert "overall" in data
                assert "ai_tip" in data
                assert "trend" in data

    def test_owner_gets_courses(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/courses/{user.id}",
                          headers=_auth(_make_token(app, user.id)))
                assert r.status_code == 200
                assert "recommended_courses" in r.get_json()

    def test_unauthenticated_mentor_rejected(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/recommendations/{user.id}")
                assert r.status_code == 401

    def test_admin_can_view_any_mentor_data(self, app, _db):
        with app.app_context():
            user = _seed_user()
            admin = _seed_user(role="admin", display="adm", email="a@t.com")
            with app.test_client() as c:
                r = c.get(f"/api/ai/mentor/courses/{user.id}",
                          headers=_auth(_make_token(app, admin.id)))
                assert r.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
# GAP 3 — Token-Based Download
# ═══════════════════════════════════════════════════════════════════════════════

class TestTokenDownload:
    """POST /api/cv/<id>/export + GET /api/cv/download/<token>."""

    def test_full_token_flow(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                # Create CV
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                # Generate download link
                r = c.post(f"/api/cv/{cv.id}/export", headers=_auth(token))
                assert r.status_code == 201
                body = r.get_json()
                assert "download_url" in body
                assert body["expires_in"] == "15 minutes"
                # Download the PDF
                dl_url = body["download_url"]
                r2 = c.get(dl_url, headers=_auth(token))
                assert r2.status_code == 200
                assert r2.content_type == "application/pdf"

    def test_token_single_use(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                r = c.post(f"/api/cv/{cv.id}/export", headers=_auth(token))
                dl_url = r.get_json()["download_url"]
                # First download succeeds
                c.get(dl_url, headers=_auth(token))
                # Second download fails (already used)
                r2 = c.get(dl_url, headers=_auth(token))
                assert r2.status_code == 410

    def test_other_user_cannot_use_token(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            hacker = _seed_user(display="hacker", email="h@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                r = c.post(f"/api/cv/{cv.id}/export", headers=_auth(_make_token(app, owner.id)))
                dl_url = r.get_json()["download_url"]
                # Hacker tries to download
                r2 = c.get(dl_url, headers=_auth(_make_token(app, hacker.id)))
                assert r2.status_code == 403

    def test_guest_cannot_generate_token(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            guest = _seed_user(role="guest", display="g", email="g@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                r = c.post(f"/api/cv/{cv.id}/export", headers=_auth(_make_token(app, guest.id)))
                assert r.status_code == 403

    def test_expired_token_returns_410(self, app, _db):
        from datetime import datetime, timezone, timedelta
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                # Manually create an expired token
                dl_token = CVDownloadToken.create_token(user.id, cv.id)
                dl_token.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
                db.session.commit()
                r = c.get(f"/api/cv/download/{dl_token.token}", headers=_auth(token))
                assert r.status_code == 410

    def test_invalid_token_returns_404(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                r = c.get("/api/cv/download/nonexistent_token_abc",
                          headers=_auth(_make_token(app, user.id)))
                assert r.status_code == 404


# ═══════════════════════════════════════════════════════════════════════════════
# GAP 4 — AuditLog DB Persistence
# ═══════════════════════════════════════════════════════════════════════════════

class TestAuditLogDB:
    """Verify audit events are persisted to the audit_logs table."""

    def test_cv_creation_logged(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, user.id)))
                logs = AuditLog.query.filter_by(action="CV_GENERATED").all()
                assert len(logs) >= 1
                log = logs[-1]
                assert log.user_id == user.id
                details = json.loads(log.details)
                assert "cv_id" in details

    def test_export_token_logged(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                c.post(f"/api/cv/{cv.id}/export", headers=_auth(token))
                logs = AuditLog.query.filter_by(action="CV_EXPORT_TOKEN_CREATED").all()
                assert len(logs) >= 1

    def test_download_logged(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                r = c.post(f"/api/cv/{cv.id}/export", headers=_auth(token))
                dl_url = r.get_json()["download_url"]
                c.get(dl_url, headers=_auth(token))
                logs = AuditLog.query.filter_by(action="CV_DOWNLOADED").all()
                assert len(logs) >= 1

    def test_denied_export_logged(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            hacker = _seed_user(display="h", email="h@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                c.post(f"/api/cv/{cv.id}/export", headers=_auth(_make_token(app, hacker.id)))
                logs = AuditLog.query.filter_by(action="UNAUTHORIZED_CV_EXPORT_ATTEMPT").all()
                assert len(logs) >= 1

    def test_audit_log_has_correct_fields(self, app, _db):
        with app.app_context():
            user = _seed_user()
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, user.id)))
                log = AuditLog.query.filter_by(action="CV_GENERATED").first()
                assert log is not None
                assert log.severity == "INFO"
                assert log.ip_address is not None
                assert log.created_at is not None


# ═══════════════════════════════════════════════════════════════════════════════
# PDF Direct Export (existing endpoint)
# ═══════════════════════════════════════════════════════════════════════════════

class TestPDFDirectExport:
    """GET /api/cv/<id>/export/pdf — direct streaming endpoint."""

    def test_member_exports_own_pdf(self, app, _db):
        with app.app_context():
            user = _seed_user()
            token = _make_token(app, user.id)
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(token))
                cv = CV.query.filter_by(user_id=user.id).first()
                r = c.get(f"/api/cv/{cv.id}/export/pdf", headers=_auth(token))
                assert r.status_code == 200
                assert r.content_type == "application/pdf"
                # Verify it's a real PDF (starts with %PDF)
                assert r.data[:5] == b"%PDF-"

    def test_guest_blocked_from_pdf(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            guest = _seed_user(role="guest", display="g", email="g@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                r = c.get(f"/api/cv/{cv.id}/export/pdf",
                          headers=_auth(_make_token(app, guest.id)))
                assert r.status_code == 403

    def test_idor_blocked_for_other_member(self, app, _db):
        with app.app_context():
            owner = _seed_user()
            other = _seed_user(display="o", email="o@t.com")
            with app.test_client() as c:
                c.post("/api/cv", json=VALID_CV, headers=_auth(_make_token(app, owner.id)))
                cv = CV.query.filter_by(user_id=owner.id).first()
                r = c.get(f"/api/cv/{cv.id}/export/pdf",
                          headers=_auth(_make_token(app, other.id)))
                assert r.status_code == 403
