"""
Integration tests: users must only see projects they own or are members of.
"""
import pytest
from flask_bcrypt import generate_password_hash
from flask_jwt_extended import create_access_token

from models import db
from models.project import Project
from models.project_member import ProjectMember
from models.task import Task
from models.user import User

pytestmark = pytest.mark.integration


def _hash_password(raw: str) -> str:
    return generate_password_hash(raw).decode("utf-8")


def _create_user(display_name: str, email: str, user_type: str) -> User:
    user = User(
        display_name=display_name,
        email=email,
        password=_hash_password("Password123!"),
        role="member",
        user_type=user_type,
    )
    db.session.add(user)
    db.session.commit()
    return user


def _auth_headers(user_id: int) -> dict:
    token = create_access_token(identity=str(user_id))
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


@pytest.fixture(autouse=True)
def clean_db(app, _db):
    with app.app_context():
        db.session.query(Task).delete()
        db.session.query(ProjectMember).delete()
        db.session.query(Project).delete()
        db.session.query(User).delete()
        db.session.commit()
        yield
        db.session.query(Task).delete()
        db.session.query(ProjectMember).delete()
        db.session.query(Project).delete()
        db.session.query(User).delete()
        db.session.commit()


class TestProjectIsolation:
    """User B must not see User A's projects or tasks."""

    def test_cross_user_project_and_task_isolation(self, client):
        user_a = _create_user("freelancer_a", "freelancer_a@test.com", "freelancer")
        user_b = _create_user("student_b", "student_b@test.com", "student")
        headers_a = _auth_headers(user_a.id)
        headers_b = _auth_headers(user_b.id)

        # User A creates a project and task
        create_resp = client.post(
            "/api/projects",
            headers=headers_a,
            json={"name": "User A Private Project", "status": "active"},
        )
        assert create_resp.status_code == 201
        project_id = create_resp.get_json()["project"]["id"]

        task_resp = client.post(
            "/api/tasks",
            headers=headers_a,
            json={
                "title": "Secret task",
                "project_id": project_id,
                "status": "pending",
                "priority": "medium",
            },
        )
        assert task_resp.status_code == 201

        # User B: empty project list
        list_b = client.get("/api/projects", headers=headers_b)
        assert list_b.status_code == 200
        projects_b = list_b.get_json().get("projects", [])
        assert projects_b == []

        # User B: cannot open project details
        detail_b = client.get(f"/api/projects/{project_id}", headers=headers_b)
        assert detail_b.status_code == 403
        assert detail_b.get_json().get("error") == "Access denied"

        # User B: cannot list tasks for User A's project
        tasks_b = client.get(
            f"/api/tasks?project_id={project_id}",
            headers=headers_b,
        )
        assert tasks_b.status_code == 403
        assert tasks_b.get_json().get("error") == "Access denied"

        # User A still sees own project
        list_a = client.get("/api/projects", headers=headers_a)
        assert list_a.status_code == 200
        projects_a = list_a.get_json().get("projects", [])
        assert len(projects_a) == 1
        assert projects_a[0]["id"] == project_id

        tasks_a = client.get(
            f"/api/tasks?project_id={project_id}",
            headers=headers_a,
        )
        assert tasks_a.status_code == 200
        assert len(tasks_a.get_json().get("tasks", [])) == 1

        # Dashboard for User B shows no accessible projects
        dash_b = client.get("/api/dashboard", headers=headers_b)
        assert dash_b.status_code == 200
        dash_body = dash_b.get_json()
        assert dash_body["stats"]["accessible_projects_count"] == 0
        assert dash_body["active_projects"] == []

    def test_member_sees_project_after_accepting_invitation(self, client):
        owner = _create_user("owner", "owner@test.com", "freelancer")
        member = _create_user("member", "member@test.com", "student")
        headers_owner = _auth_headers(owner.id)
        headers_member = _auth_headers(member.id)

        create_resp = client.post(
            "/api/projects",
            headers=headers_owner,
            json={"name": "Shared Project", "member_ids": [member.id]},
        )
        assert create_resp.status_code == 201
        project_id = create_resp.get_json()["project"]["id"]

        # Before accept, invitee does not see the project
        list_before = client.get("/api/projects", headers=headers_member)
        assert list_before.status_code == 200
        ids_before = [p["id"] for p in list_before.get_json().get("projects", [])]
        assert project_id not in ids_before

        inv_list = client.get("/api/projects/invitations", headers=headers_member)
        assert inv_list.status_code == 200
        invitations = inv_list.get_json().get("invitations", [])
        assert len(invitations) >= 1
        inv_id = invitations[0]["id"]

        accept = client.post(
            f"/api/projects/invitations/{inv_id}/accept",
            headers=headers_member,
        )
        assert accept.status_code == 200

        list_after = client.get("/api/projects", headers=headers_member)
        assert list_after.status_code == 200
        ids_after = [p["id"] for p in list_after.get_json().get("projects", [])]
        assert project_id in ids_after
