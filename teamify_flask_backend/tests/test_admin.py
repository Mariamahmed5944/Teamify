"""
Tests for Admin blueprint (/admin/*).
Endpoints: GET /logs, GET /alerts, PATCH /alerts/<id>/resolve
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID,
    ALERT_ID, NONEXISTENT_ID,
    _make_user, _make_alert, _make_login_log,
)


class TestAdminLoginLogs:
    URL = "/admin/logs"

    @patch("routes.admin.LoginLog")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_ll, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=50; pag.pages=0
        m_ll.query.order_by.return_value.paginate.return_value = pag
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


class TestAdminAlerts:
    URL = "/admin/alerts"

    @patch("routes.admin.Alert")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_alert, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=50; pag.pages=0
        m_alert.query.order_by.return_value.paginate.return_value = pag
        assert client.get(self.URL, headers=admin_headers).status_code == 200

    @patch("models.user.User")
    def test_member_403(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID, role="member")
        assert client.get(self.URL, headers=member_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestResolveAlert:
    URL = f"/admin/alerts/{ALERT_ID}/resolve"

    @patch("routes.admin.Alert")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_alert, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        alert = _make_alert()
        m_alert.query.filter_by.return_value.first.return_value = alert
        assert client.patch(self.URL, headers=admin_headers).status_code == 200

    @patch("routes.admin.Alert")
    @patch("models.user.User")
    def test_not_found_404(self, m_user, m_alert, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        m_alert.query.filter_by.return_value.first.return_value = None
        assert client.patch(f"/admin/alerts/{NONEXISTENT_ID}/resolve", headers=admin_headers).status_code == 404

    @patch("models.user.User")
    def test_member_403(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID, role="member")
        assert client.patch(self.URL, headers=member_headers).status_code == 403

    @patch("models.user.User")
    def test_invalid_id_400(self, m_user, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        assert client.patch("/admin/alerts/bad-id/resolve", headers=admin_headers).status_code == 400

    def test_no_token_401(self, client):
        assert client.patch(self.URL).status_code == 401
