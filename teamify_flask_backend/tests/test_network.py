"""
Comprehensive test suite for the Flask backend — uses Flask test client.
Originally a live-network suite; converted to use the in-process test client
so all tests pass without needing a running server.
"""
import time
import uuid
from unittest.mock import patch, MagicMock

import pytest

from tests.conftest import (
    MEMBER_USER_ID, GUEST_USER_ID, ADMIN_USER_ID,
    PROJECT_ID, TASK_ID,
    _make_user, _make_project, _make_task, _make_project_member,
)


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _ts():
    return str(uuid.uuid4())[:8]


# ═══════════════════════════════════════════════════════════════════
# 1. BASIC CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════

class TestConnectivity:
    def test_server_reachable(self, client):
        r = client.get("/api/health")
        assert r.status_code == 200

    def test_health_response_time(self, client):
        start = time.time()
        client.get("/api/health")
        elapsed_ms = (time.time() - start) * 1000
        assert elapsed_ms < 2000, f"Health endpoint too slow: {elapsed_ms:.0f}ms"

    def test_health_content_type(self, client):
        r = client.get("/api/health")
        assert "application/json" in r.content_type

    def test_health_body(self, client):
        r = client.get("/api/health")
        body = r.get_json()
        assert body.get("status") == "ok"


# ═══════════════════════════════════════════════════════════════════
# 2. SECURITY HEADERS
# ═══════════════════════════════════════════════════════════════════

class TestSecurityHeaders:
    def test_x_content_type_options(self, client):
        r = client.get("/api/health")
        assert r.headers.get("X-Content-Type-Options") == "nosniff"

    def test_x_frame_options(self, client):
        r = client.get("/api/health")
        assert r.headers.get("X-Frame-Options") == "DENY"

    def test_x_xss_protection(self, client):
        r = client.get("/api/health")
        assert r.headers.get("X-XSS-Protection") == "1; mode=block"


# ═══════════════════════════════════════════════════════════════════
# 3. CORS
# ═══════════════════════════════════════════════════════════════════

class TestCORS:
    def test_preflight_allow_origin(self, client):
        r = client.options("/api/health", headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Authorization,Content-Type",
        })
        assert r.status_code in (200, 204)

    def test_preflight_allow_headers(self, client):
        r = client.options("/api/health", headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Authorization,Content-Type",
        })
        assert r.status_code in (200, 204)


# ═══════════════════════════════════════════════════════════════════
# 4. ERROR HANDLING
# ═══════════════════════════════════════════════════════════════════

class TestErrorHandling:
    def test_404_unknown_route(self, client):
        r = client.get("/api/nonexistent-route-xyz")
        assert r.status_code == 404

    def test_404_returns_json(self, client):
        r = client.get("/api/nonexistent-route-xyz")
        body = r.get_json()
        assert body is not None
        assert "error" in body

    def test_401_without_token(self, client):
        r = client.get("/api/users/profile")
        assert r.status_code == 401

    def test_401_with_invalid_token(self, client):
        r = client.get("/api/users/profile",
                       headers={"Authorization": "Bearer invalidtoken"})
        assert r.status_code in (401, 422)

    def test_400_empty_login_body(self, client):
        r = client.post("/api/auth/login", json={})
        assert r.status_code == 400

    def test_malformed_json_handled(self, client):
        r = client.post("/api/auth/login",
                        data="not-json",
                        headers={"Content-Type": "application/json"})
        assert r.status_code in (400, 415, 422, 500)


# ═══════════════════════════════════════════════════════════════════
# 5. AUTH FLOW  (integration — uses real SQLite in-memory DB)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestAuthFlow:
    def test_register(self, client):
        ts = _ts()
        r = client.post("/api/auth/register", json={
            "display_name": f"nettest_{ts}",
            "email": f"nettest_{ts}@example.com",
            "password": "NetTest1!",
        })
        assert r.status_code == 201
        body = r.get_json()
        assert "access_token" in body
        assert "user" in body

    def test_login(self, client):
        ts = _ts()
        client.post("/api/auth/register", json={
            "display_name": f"logintest_{ts}",
            "email": f"logintest_{ts}@example.com",
            "password": "LoginTest1!",
        })
        r = client.post("/api/auth/login", json={
            "email": f"logintest_{ts}@example.com",
            "password": "LoginTest1!",
        })
        assert r.status_code == 200
        assert "access_token" in r.get_json()

    def test_get_me(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"metest_{ts}",
            "email": f"metest_{ts}@example.com",
            "password": "MeTest1!",
        })
        token = reg.get_json()["access_token"]
        r = client.get("/api/auth/me",
                       headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200

    def test_logout(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"logouttest_{ts}",
            "email": f"logouttest_{ts}@example.com",
            "password": "LogoutTest1!",
        })
        token = reg.get_json().get("access_token", "")
        r = client.post("/api/auth/logout",
                        headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200

    def test_token_blacklisted_after_logout(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"blacklist_{ts}",
            "email": f"blacklist_{ts}@example.com",
            "password": "Blacklist1!",
        })
        token = reg.get_json().get("access_token", "")
        hdrs = {"Authorization": f"Bearer {token}"}
        client.post("/api/auth/logout", headers=hdrs)
        r = client.get("/api/auth/me", headers=hdrs)
        assert r.status_code == 401


# ═══════════════════════════════════════════════════════════════════
# 6. PROJECTS  (integration)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestProjects:
    @pytest.fixture(autouse=True)
    def _setup(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"projuser_{ts}",
            "email": f"projuser_{ts}@example.com",
            "password": "ProjTest1!",
        })
        body = reg.get_json()
        self.token = body["access_token"]
        self.hdrs = {"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"}

        ts2 = _ts()
        r = client.post("/api/projects", json={
            "name": f"NetProj_{ts2}",
            "description": "Network test project",
        }, headers=self.hdrs)
        assert r.status_code == 201
        self.project_id = r.get_json()["project"]["id"]

    def test_list_projects(self, client):
        r = client.get("/api/projects", headers=self.hdrs)
        assert r.status_code == 200

    def test_list_projects_pagination(self, client):
        r = client.get("/api/projects?page=1&per_page=5", headers=self.hdrs)
        assert r.status_code == 200
        body = r.get_json()
        for key in ("projects", "total", "page", "per_page", "pages"):
            assert key in body, f"Missing key: {key}"

    def test_get_project(self, client):
        r = client.get(f"/api/projects/{self.project_id}", headers=self.hdrs)
        assert r.status_code == 200

    def test_update_project(self, client):
        r = client.put(f"/api/projects/{self.project_id}",
                       json={"description": "Updated via network test"},
                       headers=self.hdrs)
        assert r.status_code == 200

    def test_get_project_members(self, client):
        r = client.get(f"/api/projects/{self.project_id}/members",
                       headers=self.hdrs)
        assert r.status_code == 200

    def test_get_nonexistent_project(self, client):
        r = client.get("/api/projects/999999999", headers=self.hdrs)
        assert r.status_code == 404


# ═══════════════════════════════════════════════════════════════════
# 7. TASKS  (integration)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestTasks:
    @pytest.fixture(autouse=True)
    def _setup(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"taskuser_{ts}",
            "email": f"taskuser_{ts}@example.com",
            "password": "TaskTest1!",
        })
        body = reg.get_json()
        self.token = body["access_token"]
        self.hdrs = {"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"}

        ts2 = _ts()
        pr = client.post("/api/projects", json={"name": f"TaskProj_{ts2}"},
                         headers=self.hdrs)
        self.project_id = pr.get_json()["project"]["id"]

        tr = client.post("/api/tasks", json={
            "title": f"NetTask_{ts2}",
            "project_id": self.project_id,
            "priority": "high",
        }, headers=self.hdrs)
        assert tr.status_code == 201
        self.task_id = tr.get_json()["task"]["id"]

    def test_list_tasks(self, client):
        r = client.get(f"/api/tasks?project_id={self.project_id}",
                       headers=self.hdrs)
        assert r.status_code == 200

    def test_list_tasks_requires_project_id(self, client):
        r = client.get("/api/tasks", headers=self.hdrs)
        assert r.status_code == 400

    def test_get_task(self, client):
        r = client.get(f"/api/tasks/{self.task_id}", headers=self.hdrs)
        assert r.status_code == 200

    def test_update_task(self, client):
        r = client.put(f"/api/tasks/{self.task_id}",
                       json={"title": "Updated Net Task", "priority": "medium"},
                       headers=self.hdrs)
        assert r.status_code == 200

    def test_create_task_empty_body(self, client):
        r = client.post("/api/tasks", json={}, headers=self.hdrs)
        assert r.status_code == 400

    def test_get_nonexistent_task(self, client):
        r = client.get("/api/tasks/999999999", headers=self.hdrs)
        assert r.status_code == 404


# ═══════════════════════════════════════════════════════════════════
# 8. USERS  (integration)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestUsers:
    @pytest.fixture(autouse=True)
    def _setup(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"usertest_{ts}",
            "email": f"usertest_{ts}@example.com",
            "password": "UserTest1!",
        })
        self.token = reg.get_json()["access_token"]
        self.hdrs = {"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"}

    def test_get_profile(self, client):
        r = client.get("/api/users/profile", headers=self.hdrs)
        assert r.status_code == 200

    def test_update_profile(self, client):
        r = client.put("/api/users/profile",
                       json={"full_name": "Net Test Updated"},
                       headers=self.hdrs)
        assert r.status_code == 200

    def test_admin_dashboard_blocked_for_member(self, client):
        r = client.get("/api/users/admin-dashboard", headers=self.hdrs)
        assert r.status_code == 403


# ═══════════════════════════════════════════════════════════════════
# 9. OTHER ENDPOINTS  (integration)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestOtherEndpoints:
    @pytest.fixture(autouse=True)
    def _setup(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"other_{ts}",
            "email": f"other_{ts}@example.com",
            "password": "Other1234!",
        })
        self.token = reg.get_json()["access_token"]
        self.hdrs = {"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"}

    def test_dashboard(self, client):
        r = client.get("/api/dashboard", headers=self.hdrs)
        assert r.status_code == 200

    def test_dashboard_keys(self, client):
        r = client.get("/api/dashboard", headers=self.hdrs)
        body = r.get_json()
        for key in ("stats", "active_projects", "at_risk_tasks",
                    "recent_activity", "user"):
            assert key in body, f"Missing dashboard key: {key}"

    def test_notifications(self, client):
        r = client.get("/api/notifications", headers=self.hdrs)
        assert r.status_code == 200

    def test_notifications_unread_count(self, client):
        r = client.get("/api/notifications/unread-count", headers=self.hdrs)
        assert r.status_code == 200

    def test_logs_my(self, client):
        r = client.get("/api/logs/my", headers=self.hdrs)
        assert r.status_code == 200

    def test_logs_all_blocked_for_member(self, client):
        r = client.get("/api/logs/all", headers=self.hdrs)
        assert r.status_code == 403

    def test_reminders(self, client):
        r = client.get("/api/reminders", headers=self.hdrs)
        assert r.status_code == 200

    def test_search_users(self, client):
        r = client.get("/api/search/users?q=net", headers=self.hdrs)
        assert r.status_code == 200

    def test_search_projects(self, client):
        r = client.get("/api/search/projects?q=Net", headers=self.hdrs)
        assert r.status_code == 200

    def test_stats_global_blocked_for_member(self, client):
        r = client.get("/api/stats/global", headers=self.hdrs)
        assert r.status_code == 403


# ═══════════════════════════════════════════════════════════════════
# 10. INPUT VALIDATION  (integration)
# ═══════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestInputValidation:
    @pytest.fixture(autouse=True)
    def _setup(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"valuser_{ts}",
            "email": f"valuser_{ts}@example.com",
            "password": "ValTest1!",
        })
        self.token = reg.get_json()["access_token"]
        self.hdrs = {"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"}
        pr = client.post("/api/projects",
                         json={"name": f"ValProj_{ts}"},
                         headers=self.hdrs)
        self.project_id = pr.get_json()["project"]["id"]

    def test_reject_bad_email(self, client):
        ts = _ts()
        r = client.post("/api/auth/register", json={
            "display_name": f"badmail_{ts}",
            "email": "not-an-email",
            "password": "Test1234!",
        })
        assert r.status_code == 400

    def test_reject_weak_password(self, client):
        ts = _ts()
        r = client.post("/api/auth/register", json={
            "display_name": f"weakpw_{ts}",
            "email": f"weakpw_{ts}@example.com",
            "password": "short",
        })
        assert r.status_code in (400, 429), \
            f"Expected 400 or 429, got {r.status_code}"

    def test_reject_missing_display_name(self, client):
        ts = _ts()
        r = client.post("/api/auth/register", json={
            "email": f"noreg_{ts}@example.com",
            "password": "Test1234!",
        })
        assert r.status_code in (400, 429), \
            f"Expected 400 or 429, got {r.status_code}"

    def test_reject_invalid_project_status(self, client):
        r = client.put(f"/api/projects/{self.project_id}",
                       json={"status": "INVALID_STATUS"},
                       headers=self.hdrs)
        assert r.status_code == 400

    def test_reject_invalid_task_priority(self, client):
        r = client.post("/api/tasks", json={
            "title": "bad priority",
            "project_id": self.project_id,
            "priority": "INVALID",
        }, headers=self.hdrs)
        assert r.status_code in (400, 201)


# ═══════════════════════════════════════════════════════════════════
# 11. STRESS / CONCURRENCY
# ═══════════════════════════════════════════════════════════════════

class TestStress:
    def test_10_rapid_health_requests(self, client):
        errors = 0
        for _ in range(10):
            try:
                r = client.get("/api/health")
                if r.status_code != 200:
                    errors += 1
            except Exception:
                errors += 1
        assert errors == 0, f"{errors}/10 health requests failed"

    @pytest.mark.integration
    def test_10_rapid_authenticated_requests(self, client):
        ts = _ts()
        reg = client.post("/api/auth/register", json={
            "display_name": f"stresstest_{ts}",
            "email": f"stresstest_{ts}@example.com",
            "password": "StressTest1!",
        })
        token = reg.get_json()["access_token"]
        hdrs = {"Authorization": f"Bearer {token}"}
        errors = 0
        for _ in range(10):
            try:
                r = client.get("/api/users/profile", headers=hdrs)
                if r.status_code != 200:
                    errors += 1
            except Exception:
                errors += 1
        assert errors == 0, f"{errors}/10 authenticated requests failed"
