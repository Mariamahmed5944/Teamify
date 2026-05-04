import pytest
from models import db
from models.user import User

pytestmark = pytest.mark.integration

class TestAuthBenchmarks:
    """Step 7: Performance Testing with pytest-benchmark."""

    @pytest.fixture(autouse=True)
    def setup_bench_user(self, app, _db):
        """Ensure a clean database and insert the user to benchmark."""
        with app.app_context():
            db.session.query(User).delete()
            db.session.commit()
            
            from flask_bcrypt import generate_password_hash
            hashed = generate_password_hash("Password123").decode("utf-8")
            user = User(display_name="bench_user", email="bench@example.com", password=hashed)
            db.session.add(user)
            db.session.commit()
            
            yield
            
            db.session.query(User).delete()
            db.session.commit()

    def test_login_performance(self, app, benchmark):
        """
        Benchmark the execution time of the /api/auth/login endpoint.
        Since it uses bcrypt for password hashing, we want to ensure it runs
        within an acceptable threshold (e.g. under 800ms locally) to prevent blocking.
        """
        payload = {"email": "bench@example.com", "password": "Password123"}
        
        # Execute the benchmark using app.test_client() without nested with-blocks
        test_client = app.test_client()
        def do_login():
            resp = test_client.post("/api/auth/login", json=payload)
            assert resp.status_code == 200
            return resp

        # We specify limited rounds so it doesn't take too long during local runs.
        result = benchmark.pedantic(do_login, rounds=5, iterations=1)
        
        # Verify that the mean execution time is under a reasonable threshold (0.8s)
        # Typically bcrypt overhead is ~100ms-300ms depending on hardware.
        mean_time = benchmark.stats.stats.mean
        assert mean_time < 0.8, f"Login is too slow! Mean time was {mean_time:.3f} seconds"
