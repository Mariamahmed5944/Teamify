"""
Tests for Tasks blueprint (/api/tasks/*).
Endpoints: GET list, POST create, GET single, PUT update, PATCH status, DELETE
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID, MEMBER2_USER_ID,
    PROJECT_ID, TASK_ID, NONEXISTENT_ID,
    _make_user, _make_project, _make_task, _make_project_member,
)


class TestGetTasks:
    URL = "/api/tasks"

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    def test_member_200(self, m_proj, m_role, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        with patch("routes.tasks.Task") as m_task:
            m_task.query.filter_by.return_value.filter.return_value.filter.return_value.filter.return_value.order_by.return_value.paginate.return_value = pag
            r = client.get(f"{self.URL}?project_id={PROJECT_ID}", headers=member_headers)
        assert r.status_code == 200

    def test_missing_project_id_400(self, client, member_headers):
        assert client.get(self.URL, headers=member_headers).status_code == 400

    def test_invalid_project_id_400(self, client, member_headers):
        assert client.get(f"{self.URL}?project_id=bad", headers=member_headers).status_code == 400

    @patch("routes.tasks.Project")
    def test_project_not_found_404(self, m_proj, client, member_headers):
        m_proj.query.get.return_value = None
        assert client.get(f"{self.URL}?project_id={NONEXISTENT_ID}", headers=member_headers).status_code == 404

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    def test_non_member_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = None
        assert client.get(f"{self.URL}?project_id={PROJECT_ID}", headers=member2_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(f"{self.URL}?project_id={PROJECT_ID}").status_code == 401


class TestCreateTask:
    URL = "/api/tasks"

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_owner_201(self, m_task, m_proj, m_role, m_log, client, member_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        m_task.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={
            "title": "New Task", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 201

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_admin_201(self, m_task, m_proj, m_role, m_log, client, admin_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "admin"
        m_task.return_value = _make_task()
        r = client.post(self.URL, headers=admin_headers, json={
            "title": "Admin Task", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 201

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    def test_member_forbidden_403(self, m_proj, m_role, client, member2_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "member"
        r = client.post(self.URL, headers=member2_headers, json={
            "title": "T", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 403

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    def test_guest_forbidden_403(self, m_proj, m_role, client, guest_headers):
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "guest"
        r = client.post(self.URL, headers=guest_headers, json={
            "title": "T", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 403

    def test_no_body_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, data="", content_type="application/json").status_code == 400

    def test_missing_title_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"project_id": str(PROJECT_ID)}).status_code == 400

    def test_missing_project_id_400(self, client, member_headers):
        assert client.post(self.URL, headers=member_headers, json={"title": "T"}).status_code == 400

    def test_no_token_401(self, client):
        assert client.post(self.URL, json={"title": "T", "project_id": str(PROJECT_ID)}).status_code == 401


class TestGetTask:
    URL = f"/api/tasks/{TASK_ID}"

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_member_200(self, m_task, m_role, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        assert client.get(self.URL, headers=member_headers).status_code == 200

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_guest_read_200(self, m_task, m_role, client, guest_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "guest"
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_non_member_403(self, m_task, m_role, client, member2_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = None
        assert client.get(self.URL, headers=member2_headers).status_code == 403

    @patch("routes.tasks.Task")
    def test_not_found_404(self, m_task, client, member_headers):
        m_task.query.get.return_value = None
        assert client.get(f"/api/tasks/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestUpdateTaskStatus:
    URL = f"/api/tasks/{TASK_ID}/status"

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_member_200(self, m_task, m_role, m_log, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        r = client.patch(self.URL, headers=member_headers, json={"status": "in_progress"})
        assert r.status_code == 200

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_guest_forbidden_403(self, m_task, m_role, client, guest_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "guest"
        assert client.patch(self.URL, headers=guest_headers, json={"status": "done"}).status_code == 403

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_invalid_status_400(self, m_task, m_role, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        assert client.patch(self.URL, headers=member_headers, json={"status": "bad"}).status_code == 400

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_missing_status_400(self, m_task, m_role, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        assert client.patch(self.URL, headers=member_headers, json={}).status_code == 400

    def test_no_token_401(self, client):
        assert client.patch(self.URL, json={"status": "done"}).status_code == 401


class TestUpdateTask:
    URL = f"/api/tasks/{TASK_ID}"

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_owner_200(self, m_task, m_role, m_log, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "owner"
        assert client.put(self.URL, headers=member_headers, json={"title": "Updated"}).status_code == 200

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_member_forbidden_403(self, m_task, m_role, client, member2_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        assert client.put(self.URL, headers=member2_headers, json={"title": "X"}).status_code == 403

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_guest_forbidden_403(self, m_task, m_role, client, guest_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "guest"
        assert client.put(self.URL, headers=guest_headers, json={"title": "X"}).status_code == 403

    def test_no_token_401(self, client):
        assert client.put(self.URL, json={"title": "X"}).status_code == 401


class TestDeleteTask:
    URL = f"/api/tasks/{TASK_ID}"

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_owner_200(self, m_task, m_role, m_log, client, member_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "owner"
        assert client.delete(self.URL, headers=member_headers).status_code == 200

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_member_forbidden_403(self, m_task, m_role, client, member2_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "member"
        assert client.delete(self.URL, headers=member2_headers).status_code == 403

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Task")
    def test_guest_forbidden_403(self, m_task, m_role, client, guest_headers):
        m_task.query.get.return_value = _make_task()
        m_role.return_value = "guest"
        assert client.delete(self.URL, headers=guest_headers).status_code == 403

    @patch("routes.tasks.Task")
    def test_not_found_404(self, m_task, client, member_headers):
        m_task.query.get.return_value = None
        assert client.delete(f"/api/tasks/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.delete(self.URL).status_code == 401


# ─── Advanced: Input Validation & Injection Prevention ────────────────────────

class TestTaskInputValidation:
    """Edge cases and injection prevention for task create/update."""
    URL = "/api/tasks"

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_xss_in_title_201(self, m_task, m_proj, m_role, m_log, client, member_headers):
        """XSS payload in task title does not crash the server."""
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        m_task.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={
            "title": '<script>alert("xss")</script>', "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 201

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_sql_injection_in_title_201(self, m_task, m_proj, m_role, m_log, client, member_headers):
        """SQL injection in title is harmless."""
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        m_task.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={
            "title": "'; DROP TABLE tasks; --", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 201

    def test_both_fields_missing_400(self, client, member_headers):
        """Missing both title and project_id returns 400."""
        r = client.post(self.URL, headers=member_headers, json={"description": "only desc"})
        assert r.status_code == 400

    def test_empty_title_400(self, client, member_headers):
        """Empty string title is rejected."""
        r = client.post(self.URL, headers=member_headers, json={
            "title": "", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 400

    def test_malformed_json_body_400(self, client, member_headers):
        """Malformed JSON returns 400, not 500."""
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data="not-json", content_type="application/json")
        assert r.status_code == 400

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_invalid_priority_400(self, m_task, m_proj, m_role, client, member_headers):
        """Invalid priority value is rejected."""
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        r = client.post(self.URL, headers=member_headers, json={
            "title": "T", "project_id": str(PROJECT_ID), "priority": "critical"
        })
        assert r.status_code == 400

    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_invalid_due_date_format_400(self, m_task, m_proj, m_role, client, member_headers):
        """Non-ISO date format is rejected."""
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        r = client.post(self.URL, headers=member_headers, json={
            "title": "T", "project_id": str(PROJECT_ID), "due_date": "31/12/2025"
        })
        assert r.status_code == 400

    @patch("routes.tasks.Log")
    @patch("routes.tasks.get_project_role")
    @patch("routes.tasks.Project")
    @patch("routes.tasks.Task")
    def test_unicode_title_201(self, m_task, m_proj, m_role, m_log, client, member_headers):
        """Unicode task title is accepted."""
        m_proj.query.get.return_value = _make_project()
        m_role.return_value = "owner"
        m_task.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={
            "title": "修复 バグ 🐛", "project_id": str(PROJECT_ID)
        })
        assert r.status_code == 201
