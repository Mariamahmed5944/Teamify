"""
Tests for Users blueprint (/api/users/*).
Endpoints: GET /profile, PUT /profile, GET /admin-dashboard
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID, MEMBER2_USER_ID,
    _make_user,
)


class TestGetProfile:
    URL = "/api/users/profile"

    @patch("routes.users.User")
    def test_member_200(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "user" in r.get_json()

    @patch("routes.users.User")
    def test_admin_200(self, m_user, client, admin_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(ADMIN_USER_ID, role="admin")
        assert client.get(self.URL, headers=admin_headers).status_code == 200

    @patch("routes.users.User")
    def test_guest_200(self, m_user, client, guest_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(GUEST_USER_ID, role="guest")
        assert client.get(self.URL, headers=guest_headers).status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401

    def test_bad_token_401(self, client):
        assert client.get(self.URL, headers={"Authorization": "Bearer bad"}).status_code == 401

    @patch("routes.users.User")
    def test_user_deleted_404(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = None
        assert client.get(self.URL, headers=member_headers).status_code == 404


class TestUpdateProfile:
    URL = "/api/users/profile"

    @patch("routes.users.User")
    def test_update_display_name_200(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        m_user.query.filter.return_value.first.return_value = None
        r = client.put(self.URL, headers=member_headers, json={"display_name": "newname"})
        assert r.status_code == 200

    @patch("routes.users.User")
    def test_update_full_name_200(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        r = client.put(self.URL, headers=member_headers, json={"full_name": "New Full"})
        assert r.status_code == 200

    @patch("routes.users.User")
    def test_update_user_type_200(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        r = client.put(self.URL, headers=member_headers, json={"user_type": "student"})
        assert r.status_code == 200

    @patch("routes.users.User")
    def test_invalid_user_type_400(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        r = client.put(self.URL, headers=member_headers, json={"user_type": "invalid"})
        assert r.status_code == 400

    @patch("routes.users.User")
    def test_empty_display_name_400(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        r = client.put(self.URL, headers=member_headers, json={"display_name": ""})
        assert r.status_code == 400

    @patch("routes.users.User")
    def test_duplicate_display_name_409(self, m_user, client, member_headers):
        u = _make_user(MEMBER_USER_ID)
        m_user.query.filter_by.return_value.first.return_value = u
        m_user.query.filter.return_value.first.return_value = _make_user(MEMBER2_USER_ID)
        r = client.put(self.URL, headers=member_headers, json={"display_name": "taken"})
        assert r.status_code == 409

    def test_no_token_401(self, client):
        assert client.put(self.URL, json={"full_name": "x"}).status_code == 401

    @patch("routes.users.User")
    def test_user_deleted_404(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = None
        assert client.put(self.URL, headers=member_headers, json={"full_name": "x"}).status_code == 404

    @patch("routes.users.User")
    def test_guest_can_update_own_profile(self, m_user, client, guest_headers):
        u = _make_user(GUEST_USER_ID, role="guest")
        m_user.query.filter_by.return_value.first.return_value = u
        r = client.put(self.URL, headers=guest_headers, json={"full_name": "Guest Full"})
        assert r.status_code == 200


class TestAdminDashboard:
    URL = "/api/users/admin-dashboard"

    # admin_required imports User from models.user inside the function,
    # so we must patch models.user.User (not routes.users.User).

    @patch("routes.users.User")
    @patch("models.user.User")
    def test_admin_200(self, m_model_user, m_route_user, client, admin_headers):
        admin = _make_user(ADMIN_USER_ID, role="admin")
        # models.user.User is used by admin_required decorator
        m_model_user.query.filter_by.return_value.first.return_value = admin
        # routes.users.User is used by the route handler (top-level import)
        pag = MagicMock()
        pag.items = [admin]
        pag.total = 1
        pag.page = 1
        pag.per_page = 20
        pag.pages = 1
        m_route_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(self.URL, headers=admin_headers)
        assert r.status_code == 200
        d = r.get_json()
        assert "users" in d
        assert d["total"] == 1

    @patch("models.user.User")
    def test_member_forbidden_403(self, m_user, client, member_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID, role="member")
        assert client.get(self.URL, headers=member_headers).status_code == 403

    @patch("models.user.User")
    def test_guest_forbidden_403(self, m_user, client, guest_headers):
        m_user.query.filter_by.return_value.first.return_value = _make_user(GUEST_USER_ID, role="guest")
        assert client.get(self.URL, headers=guest_headers).status_code == 403

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401

    @patch("models.user.User")
    def test_member_freelancer_forbidden(self, m_user, client, member_headers):
        """user_type=freelancer with role=member still gets 403."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(
            MEMBER_USER_ID, role="member", user_type="freelancer"
        )
        assert client.get(self.URL, headers=member_headers).status_code == 403

    @patch("models.user.User")
    def test_guest_student_forbidden(self, m_user, client, guest_headers):
        """user_type=student with role=guest still gets 403."""
        m_user.query.filter_by.return_value.first.return_value = _make_user(
            GUEST_USER_ID, role="guest", user_type="student"
        )
        assert client.get(self.URL, headers=guest_headers).status_code == 403


class TestPublicProfile:
    URL = "/api/users/1/profile"

    @patch("routes.users.User")
    def test_get_public_profile_200(self, m_user, client, member_headers):
        u = _make_user(1)
        u.skills = ["Python", "Flask"]
        u.tasks_completed = 0
        u.quality_score = 5.0
        u.attendance_rate = 1.0
        u.member_on_time_rate = 1.0
        m_user.query.get.return_value = u
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200
        assert "profile" in r.get_json()

    @patch("routes.users.User")
    def test_get_public_profile_404(self, m_user, client, member_headers):
        m_user.query.get.return_value = None
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 404


class TestUserStats:
    URL = "/api/users/1/stats"

    @patch("models.feedback.Feedback")
    @patch("models.rating.Rating")
    @patch("routes.users.User")
    def test_get_user_stats_200(self, m_user, m_rating, m_feedback, client, member_headers):
        u = _make_user(1)
        u.assigned_tasks = []
        u.tasks_completed = 0
        u.overdue_tasks = 0
        u.member_current_tasks = 0
        u.member_on_time_rate = 1.0
        u.member_avg_delay_days = 0.0
        u.quality_score = 5.0
        u.attendance_rate = 1.0
        u.availability_score = 1.0
        m_user.query.get.return_value = u
        m_rating.query.filter_by.return_value.all.return_value = []
        m_feedback.query.filter_by.return_value.all.return_value = []
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200
        assert "tasks" in r.get_json()

    @patch("routes.users.User")
    def test_get_user_stats_404(self, m_user, client, member_headers):
        m_user.query.get.return_value = None
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 404
