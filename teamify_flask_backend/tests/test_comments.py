"""
Tests for Comments blueprint (/api/tasks/<id>/comments).
Endpoints: POST create, GET list
"""
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import MEMBER_USER_ID, TASK_ID, NONEXISTENT_ID, _make_task


def _make_comment():
    c = MagicMock()
    c.id = 9999
    c.task_id = TASK_ID
    c.author_id = MEMBER_USER_ID
    c.content = "test comment"
    c.to_dict.return_value = {"id": str(c.id), "content": "test comment"}
    return c


class TestCreateComment:
    URL = f"/api/tasks/{TASK_ID}/comments"

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_success_201(self, m_task, m_tc, client, member_headers):
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        r = client.post(self.URL, headers=member_headers, json={"content": "hello"})
        assert r.status_code == 201

    @patch("routes.comments.Task")
    def test_task_not_found_404(self, m_task, client, member_headers):
        m_task.query.filter_by.return_value.first.return_value = None
        assert client.post(self.URL, headers=member_headers, json={"content": "hi"}).status_code == 404

    @patch("routes.comments.Task")
    def test_empty_content_400(self, m_task, client, member_headers):
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        assert client.post(self.URL, headers=member_headers, json={"content": ""}).status_code == 400

    @patch("routes.comments.Task")
    def test_content_too_long_400(self, m_task, client, member_headers):
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        assert client.post(self.URL, headers=member_headers, json={"content": "x" * 10001}).status_code == 400

    def test_invalid_task_id_400(self, client, member_headers):
        assert client.post("/api/tasks/bad-id/comments", headers=member_headers, json={"content": "hi"}).status_code == 400

    def test_no_token_401(self, client):
        assert client.post(self.URL, json={"content": "hi"}).status_code == 401


class TestListComments:
    URL = f"/api/tasks/{TASK_ID}/comments"

    @patch("routes.comments.TaskComment")
    def test_200(self, m_tc, client, member_headers):
        m_tc.query.filter_by.return_value.order_by.return_value.all.return_value = [_make_comment()]
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200 and "items" in r.get_json()

    def test_invalid_task_id_400(self, client, member_headers):
        assert client.get("/api/tasks/bad-id/comments", headers=member_headers).status_code == 400

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


# ─── Advanced: Input Validation & Injection Prevention ────────────────────────

class TestCommentInputValidation:
    """Edge cases and injection prevention for comments."""
    URL = f"/api/tasks/{TASK_ID}/comments"

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_xss_payload_stored_safely_201(self, m_task, m_tc, client, member_headers):
        """XSS payloads must not crash the server. The route accepts and stores them
        (encryption handles storage safety). The key assertion: no 500."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        xss = '<script>alert("xss")</script>'
        r = client.post(self.URL, headers=member_headers, json={"content": xss})
        assert r.status_code == 201

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_html_injection_payload_201(self, m_task, m_tc, client, member_headers):
        """HTML injection payloads are accepted without crashing."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        html = '<img src=x onerror="alert(1)"><h1>injected</h1>'
        r = client.post(self.URL, headers=member_headers, json={"content": html})
        assert r.status_code == 201

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_sql_injection_payload_201(self, m_task, m_tc, client, member_headers):
        """SQL injection payloads in content are accepted without crashing
        (parameterized queries protect the DB)."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        sqli = "'; DROP TABLE users; --"
        r = client.post(self.URL, headers=member_headers, json={"content": sqli})
        assert r.status_code == 201

    @patch("routes.comments.Task")
    def test_whitespace_only_content_400(self, m_task, client, member_headers):
        """Content with only whitespace is rejected after strip()."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={"content": "   \n\t  "})
        assert r.status_code == 400

    @patch("routes.comments.Task")
    def test_missing_content_key_400(self, m_task, client, member_headers):
        """JSON body with no 'content' key is rejected."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={"text": "oops"})
        assert r.status_code == 400

    def test_malformed_json_400(self, client, member_headers):
        """Non-JSON body returns 400, not 500."""
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(
            f"/api/tasks/{TASK_ID}/comments", headers=headers,
            data="not json at all", content_type="application/json",
        )
        assert r.status_code in (400, 404)  # 400 for bad json or 404 if task not found

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_content_exactly_10000_chars_201(self, m_task, m_tc, client, member_headers):
        """Boundary: exactly 10000 characters should be accepted."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        r = client.post(self.URL, headers=member_headers, json={"content": "A" * 10000})
        assert r.status_code == 201

    @patch("routes.comments.Task")
    def test_content_10001_chars_400(self, m_task, client, member_headers):
        """Boundary: 10001 characters exceeds the 10000 limit."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={"content": "A" * 10001})
        assert r.status_code == 400

    @patch("routes.comments.TaskComment")
    @patch("routes.comments.Task")
    def test_unicode_content_201(self, m_task, m_tc, client, member_headers):
        """Unicode content (emojis, CJK chars) is accepted."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        m_tc.return_value = _make_comment()
        r = client.post(self.URL, headers=member_headers, json={"content": "Hello 🌍 你好 مرحبا"})
        assert r.status_code == 201

    @patch("routes.comments.Task")
    def test_null_content_400(self, m_task, client, member_headers):
        """Null content is rejected."""
        m_task.query.filter_by.return_value.first.return_value = _make_task()
        r = client.post(self.URL, headers=member_headers, json={"content": None})
        assert r.status_code == 400
