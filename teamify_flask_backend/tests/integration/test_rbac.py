import pytest
from models import db
from models.user import User

pytestmark = pytest.mark.integration

class TestRBACIntegration:
    """Step 5: Advanced Authentication & Authorization (RBAC)."""

    @pytest.fixture(autouse=True)
    def clean_db(self, app, _db):
        with app.app_context():
            db.session.query(User).delete()
            db.session.commit()
            yield
            db.session.query(User).delete()
            db.session.commit()

    @pytest.fixture
    def setup_users(self, client):
        """Register an admin, member, and guest, returning their tokens."""
        users = {}
        for role in ["admin", "member", "guest"]:
            # Note: The auth routes only allow self-registration for 'member' and 'guest'.
            # So we create them via DB models for this integration test.
            user = User(
                display_name=f"{role}_user",
                email=f"{role}@example.com",
                password="hashed_pwd",
                role=role
            )
            db.session.add(user)
        db.session.commit()

        # Login to get tokens
        for role in ["admin", "member", "guest"]:
            from flask_jwt_extended import create_access_token
            user = User.query.filter_by(role=role).first()
            users[role] = create_access_token(identity=str(user.id))
        
        return users

    def test_admin_endpoint_forbidden_for_members_and_guests(self, client, setup_users):
        """Test that /admin/logs correctly blocks non-admins with 403."""
        member_token = setup_users["member"]
        guest_token = setup_users["guest"]

        # Member attempts access
        resp_member = client.get("/admin/logs", headers={"Authorization": f"Bearer {member_token}"})
        assert resp_member.status_code == 403
        assert resp_member.get_json()["error"] == "Forbidden"

        # Guest attempts access
        resp_guest = client.get("/admin/logs", headers={"Authorization": f"Bearer {guest_token}"})
        assert resp_guest.status_code == 403
        assert resp_guest.get_json()["error"] == "Forbidden"

    def test_admin_endpoint_allowed_for_admin(self, client, setup_users):
        """Test that /admin/logs allows admins with 200."""
        admin_token = setup_users["admin"]

        resp_admin = client.get("/admin/logs", headers={"Authorization": f"Bearer {admin_token}"})
        # Could be 200 (success)
        assert resp_admin.status_code == 200
        data = resp_admin.get_json()
        assert "items" in data
