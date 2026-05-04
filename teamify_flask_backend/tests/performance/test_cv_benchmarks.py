"""
Performance Benchmarks — CV Generation, PDF Export, Mentor Endpoints
====================================================================
Uses pytest-benchmark to measure response times of key endpoints.
"""
import pytest
from models import db
from models.user import User
from models.cv import CV
from flask_bcrypt import generate_password_hash
from flask_jwt_extended import create_access_token

pytestmark = pytest.mark.integration

VALID_CV = {
    "personal_info": {"full_name": "Perf User", "email": "perf@test.com"},
    "skills": [
        {"name": "Python", "level": "Expert", "years": 5},
        {"name": "Docker", "level": "Advanced"},
        {"name": "React", "level": "Intermediate"},
    ],
    "experience": [
        {"company": "Co1", "title": "Dev", "start_date": "2020-01", "end_date": "2022-01",
         "description": "Built things."},
        {"company": "Co2", "title": "Sr Dev", "start_date": "2022-02",
         "description": "Led a team of 5 engineers."},
    ],
    "projects": [
        {"name": "ProjA", "description": "A project", "start_date": "2023-01",
         "tech_stack": ["Python", "Flask"]},
    ],
    "education": [
        {"institution": "MIT", "degree": "BSc", "field": "CS", "gpa": 3.8},
    ],
}


class TestCVBenchmarks:
    """Benchmark CV system endpoints."""

    @pytest.fixture(autouse=True)
    def setup_user(self, app, _db):
        with app.app_context():
            db.session.query(CV).delete()
            db.session.query(User).delete()
            db.session.commit()
            hashed = generate_password_hash("Password123").decode("utf-8")
            self.user = User(display_name="perf_user", email="perf@test.com",
                             password=hashed, role="member", skills=["Python"])
            db.session.add(self.user)
            db.session.commit()
            self.user_id = self.user.id
            self.token = create_access_token(identity=str(self.user_id))
            self.headers = {"Authorization": f"Bearer {self.token}",
                            "Content-Type": "application/json"}
            yield
            db.session.query(CV).delete()
            db.session.query(User).delete()
            db.session.commit()

    def test_cv_creation_performance(self, app, benchmark):
        """CV creation (validation + AI enhancement + DB write) should be < 500ms."""
        client = app.test_client()

        def create_cv():
            r = client.post("/api/cv", json=VALID_CV, headers=self.headers)
            assert r.status_code in (200, 201)

        benchmark.pedantic(create_cv, rounds=5, iterations=1)
        mean = benchmark.stats.stats.mean
        assert mean < 0.5, f"CV creation too slow: {mean:.3f}s"

    def test_cv_read_performance(self, app, benchmark):
        """CV read should be < 100ms."""
        client = app.test_client()
        client.post("/api/cv", json=VALID_CV, headers=self.headers)
        with app.app_context():
            cv = CV.query.filter_by(user_id=self.user_id).first()
            cv_id = cv.id

        def read_cv():
            r = client.get(f"/api/cv/{cv_id}", headers=self.headers)
            assert r.status_code == 200

        benchmark.pedantic(read_cv, rounds=10, iterations=1)
        mean = benchmark.stats.stats.mean
        assert mean < 0.1, f"CV read too slow: {mean:.3f}s"

    def test_pdf_export_performance(self, app, benchmark):
        """PDF rendering (ReportLab) should complete in < 800ms."""
        client = app.test_client()
        client.post("/api/cv", json=VALID_CV, headers=self.headers)
        with app.app_context():
            cv = CV.query.filter_by(user_id=self.user_id).first()
            cv_id = cv.id

        def export_pdf():
            r = client.get(f"/api/cv/{cv_id}/export/pdf", headers=self.headers)
            assert r.status_code == 200

        benchmark.pedantic(export_pdf, rounds=5, iterations=1)
        mean = benchmark.stats.stats.mean
        assert mean < 0.8, f"PDF export too slow: {mean:.3f}s"

    def test_mentor_recommendations_performance(self, app, benchmark):
        """Mentor recommendations should be < 100ms."""
        client = app.test_client()

        def get_recs():
            r = client.get(f"/api/ai/mentor/recommendations/{self.user_id}",
                           headers=self.headers)
            assert r.status_code == 200

        benchmark.pedantic(get_recs, rounds=10, iterations=1)
        mean = benchmark.stats.stats.mean
        assert mean < 0.1, f"Mentor recs too slow: {mean:.3f}s"

    def test_mentor_courses_performance(self, app, benchmark):
        """Mentor courses should be < 100ms."""
        client = app.test_client()

        def get_courses():
            r = client.get(f"/api/ai/mentor/courses/{self.user_id}",
                           headers=self.headers)
            assert r.status_code == 200

        benchmark.pedantic(get_courses, rounds=10, iterations=1)
        mean = benchmark.stats.stats.mean
        assert mean < 0.1, f"Mentor courses too slow: {mean:.3f}s"
