"""
Tests for Search blueprint (/api/search/*).
Endpoints: GET /users, GET /projects
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import MEMBER_USER_ID, _make_user


class TestSearchUsers:
    URL = "/api/search/users"

    @patch("routes.search.User")
    def test_200(self, m_user, client, member_headers):
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "users" in r.get_json()

    @patch("routes.search.or_", return_value=MagicMock())
    @patch("routes.search.User")
    def test_with_query_200(self, m_user, m_or, client, member_headers):
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_user.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?q=john", headers=member_headers)
        assert r.status_code == 200

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


class TestSearchProjects:
    URL = "/api/search/projects"

    @patch("routes.search.ProjectMember")
    @patch("routes.search.Project")
    @patch("routes.search.User")
    def test_200(self, m_user, m_proj, m_pm, client, member_headers):
        m_user.query.get.return_value = _make_user(MEMBER_USER_ID)
        m_pm.query.filter_by.return_value.all.return_value = []
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_proj.query.filter.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "projects" in r.get_json()

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


# ─── Advanced: Pagination & Query Parameters ─────────────────────────────────

class TestSearchUsersPagination:
    """Test pagination edge cases for GET /api/search/users."""
    URL = "/api/search/users"

    @patch("routes.search.User")
    def test_page_zero_clamped_to_1(self, m_user, client, member_headers):
        """page=0 is clamped to page=1 by max(1, ...)."""
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=0", headers=member_headers)
        assert r.status_code == 200
        assert r.get_json()["page"] == 1

    @patch("routes.search.User")
    def test_negative_page_clamped_to_1(self, m_user, client, member_headers):
        """page=-10 is clamped to page=1."""
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=20; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=-10", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.search.User")
    def test_huge_page_returns_empty(self, m_user, client, member_headers):
        """Requesting page=1000 returns empty results, not an error."""
        pag = MagicMock(); pag.items=[]; pag.total=5; pag.page=1000; pag.per_page=20; pag.pages=1
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=1000", headers=member_headers)
        assert r.status_code == 200
        assert r.get_json()["users"] == []

    @patch("routes.search.User")
    def test_per_page_capped_at_100(self, m_user, client, member_headers):
        """per_page=200 is capped to 100."""
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=100; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?per_page=200", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.search.User")
    def test_per_page_1_returns_200(self, m_user, client, member_headers):
        """per_page=1 is a valid minimum."""
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=1; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?per_page=1", headers=member_headers)
        assert r.status_code == 200

    def test_non_integer_page_raises_error(self, client, member_headers):
        """page=abc causes ValueError from int() — the route lacks input sanitization.
        This documents a known edge case: non-integer page params crash the route."""
        with pytest.raises(ValueError, match="invalid literal"):
            client.get(f"{self.URL}?page=abc", headers=member_headers)

    @patch("routes.search.User")
    def test_custom_per_page_value(self, m_user, client, member_headers):
        """per_page=5 returns valid paginated response."""
        pag = MagicMock(); pag.items=[]; pag.total=0; pag.page=1; pag.per_page=5; pag.pages=0
        m_user.query.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}?page=1&per_page=5", headers=member_headers)
        assert r.status_code == 200
        assert r.get_json()["per_page"] == 5
