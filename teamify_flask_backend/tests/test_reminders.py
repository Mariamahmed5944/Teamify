"""
Tests for Reminders blueprint (/api/reminders).
Endpoint: GET /api/reminders
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import _make_log


class TestGetReminders:
    URL = "/api/reminders"

    @patch("routes.reminders.Log")
    def test_member_200(self, m_log, client, member_headers):
        m_log.query.filter.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "reminders" in r.get_json()

    @patch("routes.reminders.Log")
    def test_with_type_filter_200(self, m_log, client, member_headers):
        m_log.query.filter.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [_make_log(action="DUE_TODAY")]
        r = client.get(f"{self.URL}?type=DUE_TODAY", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.reminders.Log")
    def test_guest_200(self, m_log, client, guest_headers):
        m_log.query.filter.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401
