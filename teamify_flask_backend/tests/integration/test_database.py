import pytest
from sqlalchemy.exc import IntegrityError
from models import db
from models.user import User
from models.project import Project

pytestmark = pytest.mark.integration

class TestDatabaseConstraints:
    """Step 4: Database Testing - Model Constraints."""

    @pytest.fixture(autouse=True)
    def clean_db(self, app, _db):
        with app.app_context():
            db.session.query(Project).delete()
            db.session.query(User).delete()
            db.session.commit()
            yield
            db.session.query(Project).delete()
            db.session.query(User).delete()
            db.session.commit()

    def test_unique_email_constraint(self):
        """Verify that the DB strictly enforces unique emails."""
        user1 = User(display_name="user1", email="unique@example.com", password="pwd", role="member")
        db.session.add(user1)
        db.session.commit()

        user2 = User(display_name="user2", email="unique@example.com", password="pwd", role="member")
        db.session.add(user2)

        with pytest.raises(IntegrityError):
            db.session.commit()
        db.session.rollback()

    def test_unique_display_name_constraint(self):
        """Verify that the DB strictly enforces unique display names."""
        user1 = User(display_name="unique_name", email="u1@example.com", password="pwd", role="member")
        db.session.add(user1)
        db.session.commit()

        user2 = User(display_name="unique_name", email="u2@example.com", password="pwd", role="member")
        db.session.add(user2)

        with pytest.raises(IntegrityError):
            db.session.commit()
        db.session.rollback()

    def test_non_nullable_fields(self):
        """Verify that non-nullable fields (like display_name, password) cannot be NULL."""
        # Missing display_name
        user = User(email="nonnull@example.com", password="pwd", role="member")
        db.session.add(user)
        with pytest.raises(IntegrityError):
            db.session.commit()
        db.session.rollback()

        # Missing password
        user2 = User(display_name="nonnull_name", email="nonnull2@example.com", role="member")
        db.session.add(user2)
        with pytest.raises(IntegrityError):
            db.session.commit()
        db.session.rollback()

    def test_project_user_id_constraint(self):
        """Verify that deleting a user fails because project.user_id is non-nullable (and cascade is not set)."""
        # Create user and project
        user = User(display_name="owner", email="owner@example.com", password="pwd", role="member")
        db.session.add(user)
        db.session.commit()

        project = Project(name="Test Proj", user_id=user.id, category="IT")
        db.session.add(project)
        db.session.commit()

        assert len(user.projects) == 1

        # Delete user
        db.session.delete(user)
        
        # Should raise IntegrityError since it tries to set project.user_id to NULL
        with pytest.raises(IntegrityError):
            db.session.commit()
        db.session.rollback()
