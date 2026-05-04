"""
Tests for Projects blueprint (/api/projects/*).
Endpoints: GET list, POST create, GET single, PUT update, DELETE,
           POST add member, GET members, DELETE remove member
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID, MEMBER2_USER_ID,
    PROJECT_ID, NONEXISTENT_ID, PM_ID,
    _make_user, _make_project, _make_project_member,
)


class TestGetProjects:
    URL = "/api/projects"

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_member_200(self, m_user, m_proj, m_pm, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items = []; pag.total = 0; pag.page = 1; pag.per_page = 20; pag.pages = 0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestCreateProject:
    URL = "/api/projects"

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_success_201(self, m_proj, m_pm, m_log, client, member_headers):
        p = _make_project()
        m_proj.return_value = p
        r = client.post(self.URL, headers=member_headers, json={"name": "New Project"})
        assert r.status_code == 201

    def test_no_name_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={}).status_code == 400

    def test_empty_name_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"name": ""}).status_code == 400

    def test_name_too_long_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"name": "x" * 151}).status_code == 400

    def test_invalid_status_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"name": "P", "status": "bad"}).status_code == 400

    def test_invalid_date_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"name": "P", "start_date": "not-a-date"}).status_code == 400

    def test_end_before_start_400(self, client, member_headers):
        r = client.post(self.URL, headers=member_headers, json={
            "name": "P", "start_date": "2025-12-31", "end_date": "2025-01-01"
        })
        assert r.status_code == 400

    def test_no_token_401(self, client):
        assert client.post(self.URL, json={"name": "P"}).status_code == 401

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_guest_can_create(self, m_proj, m_pm, m_log, client, guest_headers):
        m_proj.return_value = _make_project(owner_id=GUEST_USER_ID)
        r = client.post(self.URL, headers=guest_headers, json={"name": "Guest Proj"})
        assert r.status_code == 201


class TestGetProject:
    URL = f"/api/projects/{PROJECT_ID}"

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_owner_200(self, m_proj, m_role, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        assert client.get(self.URL, headers=member_headers).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_admin_200(self, m_proj, m_role, client, admin_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "admin"
        assert client.get(self.URL, headers=admin_headers).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_guest_read_200(self, m_proj, m_role, client, guest_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "guest"
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_non_member_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = None
        assert client.get(self.URL, headers=member2_headers).status_code == 403

    @patch("routes.projects.Project")
    def test_not_found_404(self, m_proj, client, member_headers):
        m_proj.query.get.return_value = None
        assert client.get(f"/api/projects/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestUpdateProject:
    URL = f"/api/projects/{PROJECT_ID}"

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_owner_200(self, m_proj, m_role, m_log, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        r = client.put(self.URL, headers=member_headers, json={"name": "Updated"})
        assert r.status_code == 200

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_admin_200(self, m_proj, m_role, m_log, client, admin_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "admin"
        assert client.put(self.URL, headers=admin_headers, json={"name": "Updated"}).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_member_forbidden_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        assert client.put(self.URL, headers=member2_headers, json={"name": "X"}).status_code == 403

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_guest_forbidden_403(self, m_proj, m_role, client, guest_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "guest"
        assert client.put(self.URL, headers=guest_headers, json={"name": "X"}).status_code == 403

    @patch("routes.projects.Project")
    def test_not_found_404(self, m_proj, client, member_headers):
        m_proj.query.get.return_value = None
        assert client.put(f"/api/projects/{NONEXISTENT_ID}", headers=member_headers, json={"name": "X"}).status_code == 404

    def test_no_token_401(self, client):
        assert client.put(self.URL, json={"name": "X"}).status_code == 401


class TestDeleteProject:
    URL = f"/api/projects/{PROJECT_ID}"

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_owner_200(self, m_proj, m_role, m_log, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        assert client.delete(self.URL, headers=member_headers).status_code == 200

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_admin_200(self, m_proj, m_role, m_log, client, admin_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "admin"
        assert client.delete(self.URL, headers=admin_headers).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_member_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        assert client.delete(self.URL, headers=member2_headers).status_code == 403

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_guest_403(self, m_proj, m_role, client, guest_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "guest"
        assert client.delete(self.URL, headers=guest_headers).status_code == 403

    @patch("routes.projects.Project")
    def test_not_found_404(self, m_proj, client, member_headers):
        m_proj.query.get.return_value = None
        assert client.delete(f"/api/projects/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.delete(self.URL).status_code == 401


class TestAddMember:
    URL = f"/api/projects/{PROJECT_ID}/members"

    @patch("routes.notifications.create_notification")
    @patch("routes.projects.Log")
    @patch("models.user.User")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_owner_adds_201(self, m_proj, m_role, m_pm, m_user, m_log, m_notif, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        m_pm.query.filter_by.return_value.first.return_value = None
        target = _make_user(MEMBER2_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = target
        pm = _make_project_member(user_id=MEMBER2_USER_ID)
        m_pm.return_value = pm
        r = client.post(self.URL, headers=member_headers, json={"user_id": str(MEMBER2_USER_ID)})
        assert r.status_code == 201

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_member_forbidden_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        r = client.post(self.URL, headers=member2_headers, json={"user_id": str(GUEST_USER_ID)})
        assert r.status_code == 403

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_guest_forbidden_403(self, m_proj, m_role, client, guest_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "guest"
        r = client.post(self.URL, headers=guest_headers, json={"user_id": str(MEMBER2_USER_ID)})
        assert r.status_code == 403

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_missing_user_id_400(self, m_proj, m_role, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        assert client.post(self.URL, headers=member_headers, json={}).status_code == 400

    def test_no_token_401(self, client):
        assert client.post(self.URL, json={"user_id": str(MEMBER2_USER_ID)}).status_code == 401


class TestGetMembers:
    URL = f"/api/projects/{PROJECT_ID}/members"

    @patch("models.user.User")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_member_200(self, m_proj, m_role, m_pm, m_user, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        m_pm.query.filter_by.return_value.all.return_value = []
        assert client.get(self.URL, headers=member_headers).status_code == 200

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_non_member_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = None
        assert client.get(self.URL, headers=member2_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestRemoveMember:
    URL = f"/api/projects/{PROJECT_ID}/members/{MEMBER2_USER_ID}"

    @patch("models.user.User")
    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_owner_removes_200(self, m_proj, m_role, m_pm, m_log, m_user, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        pm = _make_project_member(user_id=MEMBER2_USER_ID, role="member")
        m_pm.query.filter_by.return_value.first.return_value = pm
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER2_USER_ID)
        assert client.delete(self.URL, headers=member_headers).status_code == 200

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_cannot_remove_owner_400(self, m_proj, m_role, m_pm, client, admin_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "admin"
        pm = _make_project_member(user_id=MEMBER_USER_ID, role="owner")
        m_pm.query.filter_by.return_value.first.return_value = pm
        assert client.delete(f"/api/projects/{PROJECT_ID}/members/{MEMBER_USER_ID}", headers=admin_headers).status_code == 400

    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_member_forbidden_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        assert client.delete(self.URL, headers=member2_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.delete(self.URL).status_code == 401


# ─── Advanced: Input Validation & Injection Prevention ────────────────────────

class TestProjectInputValidation:
    """Edge cases and injection prevention for project create/update."""
    URL = "/api/projects"

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_xss_in_name_201(self, m_proj, m_pm, m_log, client, member_headers):
        """XSS payload in project name is accepted without crashing (no server-side sanitisation)."""
        m_proj.return_value = _make_project()
        xss = '<script>alert("xss")</script>'
        r = client.post(self.URL, headers=member_headers, json={"name": xss})
        assert r.status_code == 201

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_xss_in_description_201(self, m_proj, m_pm, m_log, client, member_headers):
        """XSS payload in description is accepted without crashing."""
        m_proj.return_value = _make_project()
        r = client.post(self.URL, headers=member_headers, json={
            "name": "Safe", "description": '<img src=x onerror="alert(1)">'
        })
        assert r.status_code == 201

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_sql_injection_in_name_201(self, m_proj, m_pm, m_log, client, member_headers):
        """SQL injection in name is harmless (parameterized queries)."""
        m_proj.return_value = _make_project()
        r = client.post(self.URL, headers=member_headers, json={"name": "'; DROP TABLE projects;--"})
        assert r.status_code == 201

    def test_name_exactly_150_chars_boundary(self, client, member_headers):
        """Boundary: exactly 150 characters should be accepted."""
        with patch("routes.projects.Log"), \
             patch("routes.projects.ProjectMember"), \
             patch("routes.projects.Project") as m_proj:
            m_proj.return_value = _make_project()
            r = client.post(self.URL, headers=member_headers, json={"name": "A" * 150})
            assert r.status_code == 201

    def test_name_151_chars_400(self, client, member_headers):
        """Boundary: 151 characters exceeds the 150-char limit."""
        r = client.post(self.URL, headers=member_headers, json={"name": "A" * 151})
        assert r.status_code == 400

    def test_malformed_json_body_400(self, client, member_headers):
        """Malformed JSON body returns 400, not 500."""
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data="{broken json", content_type="application/json")
        assert r.status_code == 400

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_description_5000_chars_201(self, m_proj, m_pm, m_log, client, member_headers):
        """Boundary: 5000-char description is valid."""
        m_proj.return_value = _make_project()
        r = client.post(self.URL, headers=member_headers, json={
            "name": "P", "description": "D" * 5000
        })
        assert r.status_code == 201

    def test_description_5001_chars_400(self, client, member_headers):
        """Boundary: 5001-char description exceeds the limit."""
        with patch("routes.projects.get_project_role") as m_role, \
             patch("routes.projects.Project") as m_proj:
            m_proj.query.get.return_value = _make_project()
            m_role.return_value = "owner"
            r = client.put(f"/api/projects/{PROJECT_ID}", headers=member_headers, json={
                "description": "D" * 5001
            })
            assert r.status_code == 400

    @patch("routes.projects.Log")
    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    def test_unicode_name_201(self, m_proj, m_pm, m_log, client, member_headers):
        """Unicode project name is accepted."""
        m_proj.return_value = _make_project()
        r = client.post(self.URL, headers=member_headers, json={"name": "Проект 日本語 🚀"})
        assert r.status_code == 201


# ─── Advanced: Pagination & Query Parameters ─────────────────────────────────

class TestProjectListPagination:
    """Test pagination edge cases for GET /api/projects."""
    URL = "/api/projects"

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_page_zero_clamped_to_1(self, m_user, m_proj, m_pm, client, member_headers):
        """page=0 is clamped to page=1 by max(1, ...)."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=0", headers=member_headers)
        assert r.status_code == 200
        assert r.get_json()["page"] == 1

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_negative_page_clamped_to_1(self, m_user, m_proj, m_pm, client, member_headers):
        """page=-5 is clamped to page=1."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=-5", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_huge_page_returns_empty(self, m_user, m_proj, m_pm, client, member_headers):
        """Requesting page=9999 returns empty results, not an error."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=9999; pag.per_page=20; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=9999", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_per_page_capped_at_100(self, m_user, m_proj, m_pm, client, member_headers):
        """per_page=500 is capped to 100 by min(..., 100)."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=100; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?per_page=500", headers=member_headers)
        assert r.status_code == 200


class TestCompletedProjects:
    URL_GET = "/api/projects/completed"
    URL_COMPLETE = f"/api/projects/{PROJECT_ID}/complete"
    URL_REOPEN = f"/api/projects/{PROJECT_ID}/reopen"

    @patch("routes.projects.ProjectMember")
    @patch("routes.projects.Project")
    @patch("models.user.User")
    def test_get_completed_projects_200(self, m_user, m_proj, m_pm, client, member_headers):
        m_user.query.get.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(self.URL_GET, headers=member_headers)
        assert r.status_code == 200
        assert "projects" in r.get_json()

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_complete_project_200(self, m_proj, m_role, m_log, client, member_headers):
        p = _make_project()
        p.status = "active"
        m_proj.query.get.return_value = p
        m_role.return_value = "owner"
        r = client.post(self.URL_COMPLETE, headers=member_headers)
        assert r.status_code == 200
        assert p.status == "completed"

    @patch("routes.projects.Log")
    @patch("routes.projects.get_project_role")
    @patch("routes.projects.Project")
    def test_reopen_project_200(self, m_proj, m_role, m_log, client, member_headers):
        p = _make_project()
        p.status = "completed"
        m_proj.query.get.return_value = p
        m_role.return_value = "owner"
        r = client.post(self.URL_REOPEN, headers=member_headers)
        assert r.status_code == 200
        assert p.status == "active"
