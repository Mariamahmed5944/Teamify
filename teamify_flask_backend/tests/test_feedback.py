"""
Tests for Feedback API (/api/feedback)
"""
from unittest.mock import patch, MagicMock
from tests.conftest import MEMBER_USER_ID, _make_user

class TestFeedback:
    URL = "/api/feedback"

    @patch("routes.feedback.db.session.commit")
    @patch("routes.feedback.db.session.add")
    @patch("routes.feedback.Project")
    @patch("routes.feedback.User")
    def test_create_feedback_201(self, m_user, m_proj, m_add, m_commit, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        m_proj.query.get.return_value = MagicMock()
        r = client.post(self.URL, headers=member_headers, json={
            "user_id": 2, 
            "project_id": 1, 
            "quality_score": 4.5, 
            "teamwork_score": 5.0
        })
        assert r.status_code == 201
        assert "feedback" in r.get_json()

    @patch("routes.feedback.Project")
    @patch("routes.feedback.User")
    def test_create_feedback_invalid_score_400(self, m_user, m_proj, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        m_proj.query.get.return_value = MagicMock()
        r = client.post(self.URL, headers=member_headers, json={
            "user_id": 2, 
            "project_id": 1, 
            "quality_score": 6.0
        })
        assert r.status_code == 400

    @patch("routes.feedback.Feedback")
    @patch("routes.feedback.User")
    def test_get_user_feedback_200(self, m_user, m_fb, client, member_headers):
        m_user.query.get.return_value = _make_user(2)
        pag = MagicMock()
        f1 = MagicMock(); f1.quality_score = 4.0; f1.teamwork_score = 5.0
        f1.to_dict.return_value = {"id": 1, "quality_score": 4.0, "teamwork_score": 5.0}
        f2 = MagicMock(); f2.quality_score = 5.0; f2.teamwork_score = 5.0
        f2.to_dict.return_value = {"id": 2, "quality_score": 5.0, "teamwork_score": 5.0}
        pag.items = [f1, f2]
        pag.total = 2; pag.page = 1; pag.pages = 1; pag.per_page = 20
        m_fb.query.filter_by.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}/user/2", headers=member_headers)
        assert r.status_code == 200
        data = r.get_json()
        assert data["avg_quality"] == 4.5
        assert data["avg_teamwork"] == 5.0

    @patch("routes.feedback.Feedback")
    @patch("routes.feedback.Project")
    def test_get_project_feedback_200(self, m_proj, m_fb, client, member_headers):
        m_proj.query.get.return_value = MagicMock()
        pag = MagicMock(); pag.items = []; pag.total = 0; pag.page = 1; pag.pages = 0; pag.per_page = 20
        m_fb.query.filter_by.return_value.order_by.return_value.paginate.return_value = pag
        r = client.get(f"{self.URL}/project/1", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.feedback.Feedback")
    def test_get_feedback_200(self, m_fb, client, member_headers):
        f = MagicMock()
        f.to_dict.return_value = {"id": 1}
        m_fb.query.get.return_value = f
        r = client.get(f"{self.URL}/1", headers=member_headers)
        assert r.status_code == 200

    @patch("routes.feedback.db.session.commit")
    @patch("routes.feedback.Feedback")
    def test_update_feedback_200(self, m_fb, m_commit, client, member_headers):
        f = MagicMock()
        f.reviewer_id = MEMBER_USER_ID
        f.to_dict.return_value = {"id": 1}
        m_fb.query.get.return_value = f
        r = client.put(f"{self.URL}/1", headers=member_headers, json={"quality_score": 4.8})
        assert r.status_code == 200

    @patch("routes.feedback.db.session.commit")
    @patch("routes.feedback.db.session.delete")
    @patch("routes.feedback.Feedback")
    def test_delete_feedback_200(self, m_fb, m_del, m_commit, client, member_headers):
        f = MagicMock()
        f.reviewer_id = MEMBER_USER_ID
        m_fb.query.get.return_value = f
        r = client.delete(f"{self.URL}/1", headers=member_headers)
        assert r.status_code == 200
