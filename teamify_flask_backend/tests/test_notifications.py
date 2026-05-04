"""
Tests for Notifications blueprint (/api/notifications/*).
Endpoints: GET list, GET /unread-count, PATCH /<id>/read, POST /mark-all-read
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    MEMBER_USER_ID, GUEST_USER_ID, NOTIFICATION_ID, NONEXISTENT_ID,
    _make_notification,
)


class TestGetNotifications:
    URL = "/api/notifications"

    @patch("routes.notifications.Notification")
    def test_member_200(self, m_notif, client, member_headers):
        m_notif.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = [_make_notification()]
        m_notif.query.filter_by.return_value.count.return_value = 1
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200
        d = r.get_json()
        assert "notifications" in d and "unread_count" in d

    @patch("routes.notifications.Notification")
    def test_guest_200(self, m_notif, client, guest_headers):
        m_notif.query.filter_by.return_value.order_by.return_value.limit.return_value.all.return_value = []
        m_notif.query.filter_by.return_value.count.return_value = 0
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestUnreadCount:
    URL = "/api/notifications/unread-count"

    @patch("routes.notifications.Notification")
    def test_200(self, m_notif, client, member_headers):
        m_notif.query.filter_by.return_value.count.return_value = 5
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and r.get_json()["unread_count"] == 5

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestMarkAsRead:
    URL = f"/api/notifications/{NOTIFICATION_ID}/read"

    @patch("routes.notifications.Notification")
    def test_owner_200(self, m_notif, client, member_headers):
        n = _make_notification()
        m_notif.query.filter_by.return_value.first.return_value = n
        assert client.patch(self.URL, headers=member_headers).status_code == 200

    @patch("routes.notifications.Notification")
    def test_not_found_404(self, m_notif, client, member_headers):
        m_notif.query.filter_by.return_value.first.return_value = None
        assert client.patch(f"/api/notifications/{NONEXISTENT_ID}/read", headers=member_headers).status_code == 404

    def test_no_token_401(self, client):
        assert client.patch(self.URL).status_code == 401


class TestMarkAllRead:
    URL = "/api/notifications/mark-all-read"

    @patch("routes.notifications.Notification")
    def test_200(self, m_notif, client, member_headers):
        m_notif.query.filter_by.return_value.update.return_value = 3
        r = client.post(self.URL, headers=member_headers)
        assert r.status_code == 200

    def test_no_token_401(self, client):
        assert client.post(self.URL).status_code == 401
