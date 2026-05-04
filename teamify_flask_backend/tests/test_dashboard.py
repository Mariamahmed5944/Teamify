"""
Tests for Dashboard blueprint (/api/dashboard).
Endpoint: GET /api/dashboard
"""
from unittest.mock import patch, MagicMock
from datetime import date
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID,
    _make_user,
)


def _make_column_mock():
    """Create a mock that supports SQLAlchemy-like comparison operators."""
    col = MagicMock()
    col.__lt__ = MagicMock(return_value=MagicMock())
    col.__le__ = MagicMock(return_value=MagicMock())
    col.__gt__ = MagicMock(return_value=MagicMock())
    col.__eq__ = MagicMock(return_value=MagicMock())
    col.__ne__ = MagicMock(return_value=MagicMock())
    col.isnot = MagicMock(return_value=MagicMock())
    col.in_ = MagicMock(return_value=MagicMock())
    col.asc = MagicMock(return_value=MagicMock())
    col.desc = MagicMock(return_value=MagicMock())
    return col


class TestGetDashboard:
    URL = "/api/dashboard"

    @patch("routes.dashboard.Notification")
    @patch("routes.dashboard.Log")
    @patch("routes.dashboard.predict_delay")
    @patch("routes.dashboard.ProjectMember")
    @patch("routes.dashboard.Task")
    @patch("routes.dashboard.Project")
    @patch("models.user.User")
    def test_member_200(self, m_user, m_proj, m_task, m_pm, m_delay, m_log, m_notif, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.get.return_value = u
        # Make Task columns support comparison operators
        m_task.due_date = _make_column_mock()
        m_task.status = _make_column_mock()
        m_task.project_id = _make_column_mock()
        # No owned projects, no memberships → project_ids = []
        m_proj.query.filter_by.return_value.all.return_value = []
        m_pm.query.filter_by.return_value.all.return_value = []
        # Task.query.filter(False) → base_q with chainable .filter().count()
        base_q = MagicMock()
        base_q.count.return_value = 0
        base_q.filter.return_value.count.return_value = 0
        base_q.filter.return_value.filter.return_value.count.return_value = 0
        base_q.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_task.query.filter.return_value = base_q
        m_proj.query.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_log.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_notif.query.filter_by.return_value.count.return_value = 0
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200
        d = r.get_json()
        assert "stats" in d and "active_projects" in d and "user" in d

    @patch("routes.dashboard.Notification")
    @patch("routes.dashboard.Log")
    @patch("routes.dashboard.predict_delay")
    @patch("routes.dashboard.ProjectMember")
    @patch("routes.dashboard.Task")
    @patch("routes.dashboard.Project")
    @patch("models.user.User")
    def test_admin_sees_all_200(self, m_user, m_proj, m_task, m_pm, m_delay, m_log, m_notif, client, admin_headers):
        m_user.query.get.return_value = _make_user(ADMIN_USER_ID, role="admin")
        m_task.due_date = _make_column_mock()
        m_task.status = _make_column_mock()
        m_task.project_id = _make_column_mock()
        m_proj.query.all.return_value = []
        base_q = MagicMock()
        base_q.count.return_value = 0
        base_q.filter.return_value.count.return_value = 0
        base_q.filter.return_value.filter.return_value.count.return_value = 0
        base_q.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_task.query.filter.return_value = base_q
        m_proj.query.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_log.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_notif.query.filter_by.return_value.count.return_value = 0
        assert client.get(self.URL, headers=admin_headers).status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401
