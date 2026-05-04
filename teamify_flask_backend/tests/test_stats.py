"""
Tests for Stats blueprint (/api/stats/*).
Endpoints: GET /project/<id>, GET /global (admin), GET /workload-overview (admin)
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID,
    PROJECT_ID, NONEXISTENT_ID,
    _make_user,
)


class TestProjectStats:
    URL = f"/api/stats/project/{PROJECT_ID}"

    @patch("routes.stats.get_project_stats")
    @patch("routes.stats.get_project_role")
    def test_member_200(self, m_role, m_stats, client, member_headers):
        m_role.return_value = "member"
        m_stats.return_value = {"total_tasks": 5, "completion_rate": 40}
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200

    @patch("routes.stats.get_project_role")
    def test_non_member_403(self, m_role, client, member_headers):
        m_role.return_value = None
        assert client.get(self.URL, headers=member_headers).status_code == 403

    @patch("routes.stats.get_project_stats")
    @patch("routes.stats.get_project_role")
    def test_not_found_404(self, m_role, m_stats, client, member_headers):
        m_role.return_value = "member"
        m_stats.return_value = {"error": "Project not found"}
        assert client.get(f"/api/stats/project/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestGlobalStats:
    URL = "/api/stats/global"

    @patch("routes.stats.get_global_stats")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_stats, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        m_stats.return_value = {"total_users": 10}
        assert client.get(self.URL, headers=admin_headers).status_code == 200

    @patch("models.user.User")
    def test_member_403(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID, role="member")
        assert client.get(self.URL, headers=member_headers).status_code == 403

    @patch("models.user.User")
    def test_guest_403(self, m_user, client, guest_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(GUEST_USER_ID, role="guest")
        assert client.get(self.URL, headers=guest_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestWorkloadOverview:
    URL = "/api/stats/workload-overview"

    @patch("routes.stats.calculate_workload")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_wl, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        m_wl.return_value = []
        r = client.get(self.URL, headers=admin_headers)
        assert r.status_code == 200 and "workloads" in r.get_json()

    @patch("models.user.User")
    def test_member_403(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID, role="member")
        assert client.get(self.URL, headers=member_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401
