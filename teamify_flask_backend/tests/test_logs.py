"""
Tests for Logs blueprint (/api/logs/*).
Endpoints: GET /my, GET /all (admin only)
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID,
    _make_user, _make_log,
)


class TestGetMyLogs:
    URL = "/api/logs/my"

    @patch("routes.logs.Log")
    def test_member_200(self, m_log, client, member_headers):
        m_log.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = [_make_log()]
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "logs" in r.get_json()

    @patch("routes.logs.Log")
    def test_guest_200(self, m_log, client, guest_headers):
        m_log.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = []
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestGetAllLogs:
    URL = "/api/logs/all"

    @patch("routes.logs.Log")
    @patch("models.user.User")
    def test_admin_200(self, m_user, m_log, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        m_log.query.order_by.return_value.limit.return_value.all.return_value = []
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
