"""
Tests for Ratings API (/api/ratings)
"""
from unittest.mock import patch, MagicMock
from tests.conftest import MEMBER_USER_ID, _make_user

class TestRatings:
    URL = "/api/ratings"

    @patch("routes.ratings.db.session.commit")
    @patch("routes.ratings.db.session.add")
    @patch("routes.ratings.Rating")
    @patch("routes.ratings.User")
    def test_create_rating_201(self, m_user, m_rating, m_add, m_commit, client, member_headers):
        m_user.query.get.return_value = _make_user(3)
        m_rating.query.filter_by.return_value.first.return_value = None
        m_rating.return_value.to_dict.return_value = {"id": 1, "score": 5}
        r = client.post(self.URL, headers=member_headers, json={"ratee_id": 3, "score": 5})
        assert r.status_code == 201
        assert "rating" in r.get_json()

    @patch("routes.ratings.User")
    def test_create_rating_invalid_score(self, m_user, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        r = client.post(self.URL, headers=member_headers, json={"ratee_id": 2, "score": 6})
        assert r.status_code == 400

    @patch("routes.ratings.User")
    def test_create_rating_self(self, m_user, client, member_headers):
        m_user.query.get.return_value = _make_user(MEMBER_USER_ID)
        r = client.post(self.URL, headers=member_headers, json={"ratee_id": MEMBER_USER_ID, "score": 5})
        assert r.status_code == 400

    @patch("routes.ratings.Rating")
    @patch("routes.ratings.User")
    def test_get_user_ratings_200(self, m_user, m_rating, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        pag = MagicMock()
        pag.items = []
        pag.total = 0
        pag.page = 1
        pag.pages = 0
        pag.per_page = 20
        m_rating.query.filter_by.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}/user/2", headers=member_headers)
        assert r.status_code == 200
        assert "ratings" in r.get_json()

    @patch("routes.ratings.Rating")
    @patch("routes.ratings.User")
    def test_get_user_avg_rating_200(self, m_user, m_rating, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        r1 = MagicMock(); r1.score = 4
        r2 = MagicMock(); r2.score = 5
        m_rating.query.filter_by.return_value.all.return_value = [r1, r2]
        r = client.get(f"{self.URL}/user/2/avg", headers=member_headers)
        assert r.status_code == 200
        assert r.get_json()["average_score"] == 4.5

    @patch("routes.ratings.db.session.commit")
    @patch("routes.ratings.Rating")
    def test_update_rating_200(self, m_rating, m_commit, client, member_headers):
        r_mock = MagicMock()
        r_mock.rater_id = MEMBER_USER_ID
        r_mock.to_dict.return_value = {"id": 1, "score": 4}
        m_rating.query.get.return_value = r_mock
        r = client.put(f"{self.URL}/1", headers=member_headers, json={"score": 4})
        assert r.status_code == 200

    @patch("routes.ratings.db.session.commit")
    @patch("routes.ratings.db.session.delete")
    @patch("routes.ratings.Rating")
    def test_delete_rating_200(self, m_rating, m_del, m_commit, client, member_headers):
        r_mock = MagicMock()
        r_mock.rater_id = MEMBER_USER_ID
        m_rating.query.get.return_value = r_mock
        r = client.delete(f"{self.URL}/1", headers=member_headers)
        assert r.status_code == 200
