import pytest
from models.user import User
from models import db
from flask_bcrypt import Bcrypt

bcrypt = Bcrypt()

pytestmark = pytest.mark.integration

@pytest.fixture(autouse=True)
def setup_db(app, _db):
    """Ensure DB is clean before starting."""
    with app.app_context():
        # Clean existing users to avoid conflicts
        db.session.query(User).delete()
        db.session.commit()
        
        # Seed an admin user for the test
        admin = User(
            display_name="admin_e2e",
            email="admin@example.com",
            password=bcrypt.generate_password_hash("adminpassword").decode("utf-8"),
            role="admin",
            user_type="admin",
            account_status="approved"
        )
        db.session.add(admin)
        db.session.commit()
        
        yield
        
        # Cleanup after test
        db.session.query(User).delete()
        db.session.commit()


def test_end_to_end_api_flow(client):
    """
    Test the E2E API flow designed for Apidog/Postman.
    1. Admin Setup
    2. User Onboarding (Freelancer)
    3. Admin Approval
    4. Core Application Flow (Projects, Tasks)
    5. AI Integration Test
    6. Cleanup (Project)
    """
    
    # --- Step 1: Admin Setup ---
    resp = client.post("/api/auth/login", json={
        "email": "admin@example.com",
        "password": "adminpassword"
    })
    assert resp.status_code == 200, f"Admin login failed: {resp.get_json()}"
    admin_token = resp.get_json()["access_token"]

    # --- Step 2: User Onboarding ---
    resp = client.post("/api/auth/register", json={
        "display_name": "test_freelancer",
        "email": "freelancer@test.com",
        "password": "Password123",
        "role": "member", # Changed guest to member to allow project creation later if needed
        "user_type": "freelancer"
    })
    assert resp.status_code == 201, f"Register failed: {resp.get_json()}"
    new_user_id = resp.get_json()["user"]["id"]

    # Try login as pending user
    resp = client.post("/api/auth/login", json={
        "email": "freelancer@test.com",
        "password": "Password123"
    })
    # Expect 403 because account is pending
    assert resp.status_code == 403, "Pending user should be blocked"

    # --- Step 3: Admin Approval ---
    resp = client.patch(
        f"/admin/users/{new_user_id}/approve",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert resp.status_code == 200, f"Approve failed: {resp.get_json()}"

    # --- Step 4: Core Application Flow ---
    resp = client.post("/api/auth/login", json={
        "email": "freelancer@test.com",
        "password": "Password123"
    })
    assert resp.status_code == 200, "Approved user should login"
    freelancer_token = resp.get_json()["access_token"]

    # Create Project
    resp = client.post(
        "/api/projects",
        headers={"Authorization": f"Bearer {freelancer_token}"},
        json={
            "name": "Automated E2E Project",
            "description": "Project created via Apidog flow."
        }
    )
    assert resp.status_code == 201, f"Create project failed: {resp.get_json()}"
    project_id = resp.get_json()["project"]["id"] if "project" in resp.get_json() else resp.get_json().get("id")

    # Create Task
    resp = client.post(
        "/api/tasks",
        headers={"Authorization": f"Bearer {freelancer_token}"},
        json={
            "project_id": project_id,
            "title": "Implement AI Module",
            "description": "Develop and deploy the classification model."
        }
    )
    assert resp.status_code == 201, f"Create task failed: {resp.get_json()}"
    task_id = resp.get_json()["task"]["id"] if "task" in resp.get_json() else resp.get_json().get("id")

    # --- Step 5: AI Integration Test ---
    resp = client.post(
        "/api/ai/classify-task",
        headers={"Authorization": f"Bearer {freelancer_token}"},
        json={
            "task_id": task_id,
            "text": "Develop and deploy the classification model."
        }
    )
    assert resp.status_code == 200, f"AI classify failed: {resp.get_json()}"

    resp = client.get(
        f"/api/ai/predict-delay/{task_id}",
        headers={"Authorization": f"Bearer {freelancer_token}"}
    )
    assert resp.status_code == 200, f"AI delay predict failed: {resp.get_json()}"

    # --- Step 6: Cleanup ---
    resp = client.delete(
        f"/api/projects/{project_id}",
        headers={"Authorization": f"Bearer {freelancer_token}"}
    )
    assert resp.status_code in [200, 202, 204], f"Delete project failed: {resp.get_json()}"
    # Note: Deleting users is not exposed in the API, so it is handled by the fixture teardown.
