"""Unit tests for services.anomaly.

Run with:  pytest services/test_anomaly.py -v
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta

import pytest
from flask import Flask

# Ensure project root is importable when running pytest from any cwd.
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from models import db  # noqa: E402
from models.login_log import LoginLog  # noqa: E402
from models.alert import Alert  # noqa: E402
from services.anomaly import (  # noqa: E402
    check_login_anomalies,
    scan_recent_failures,
    ALERT_TYPE_BRUTE_FORCE,
    FAIL_THRESHOLD,
    WINDOW_MINUTES,
)


# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #
@pytest.fixture()
def app():
    """Minimal Flask app with in-memory SQLite for isolated unit tests."""
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["TESTING"] = True
    db.init_app(app)
    # Import every model module so all relationships resolve and FK target
    # tables are registered in metadata before db.create_all().
    import models.user  # noqa: F401
    import models.project  # noqa: F401
    import models.project_member  # noqa: F401
    import models.task  # noqa: F401
    import models.notification  # noqa: F401
    import models.log  # noqa: F401
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def ctx(app):
    with app.app_context():
        yield


def _add_fail(ip: str, *, minutes_ago: int = 0) -> LoginLog:
    log = LoginLog(
        user_id=None,
        status="fail",
        ip_address=ip,
        device_info="pytest/1.0",
        timestamp=datetime.utcnow() - timedelta(minutes=minutes_ago),
    )
    db.session.add(log)
    db.session.commit()
    return log


def _add_success(ip: str, *, minutes_ago: int = 0) -> LoginLog:
    log = LoginLog(
        user_id=None,
        status="success",
        ip_address=ip,
        device_info="pytest/1.0",
        timestamp=datetime.utcnow() - timedelta(minutes=minutes_ago),
    )
    db.session.add(log)
    db.session.commit()
    return log


# --------------------------------------------------------------------------- #
# check_login_anomalies
# --------------------------------------------------------------------------- #
class TestCheckLoginAnomalies:
    def test_returns_none_when_ip_empty(self, ctx):
        assert check_login_anomalies("") is None
        assert check_login_anomalies(None) is None

    def test_below_threshold_creates_no_alert(self, ctx):
        for _ in range(FAIL_THRESHOLD - 1):
            _add_fail("10.0.0.1")
        assert check_login_anomalies("10.0.0.1") is None
        assert Alert.query.count() == 0

    def test_at_threshold_creates_alert(self, ctx):
        for _ in range(FAIL_THRESHOLD):
            _add_fail("10.0.0.2")
        alert = check_login_anomalies("10.0.0.2")
        assert alert is not None
        assert alert.type == ALERT_TYPE_BRUTE_FORCE
        assert alert.resolved is False
        assert "10.0.0.2" in alert.description
        assert Alert.query.count() == 1

    def test_other_ips_do_not_aggregate(self, ctx):
        for _ in range(FAIL_THRESHOLD - 1):
            _add_fail("10.0.0.3")
        for _ in range(FAIL_THRESHOLD - 1):
            _add_fail("10.0.0.4")
        assert check_login_anomalies("10.0.0.3") is None
        assert check_login_anomalies("10.0.0.4") is None
        assert Alert.query.count() == 0

    def test_old_failures_outside_window_ignored(self, ctx):
        for _ in range(FAIL_THRESHOLD + 2):
            _add_fail("10.0.0.5", minutes_ago=WINDOW_MINUTES + 1)
        assert check_login_anomalies("10.0.0.5") is None
        assert Alert.query.count() == 0

    def test_success_logs_ignored(self, ctx):
        for _ in range(FAIL_THRESHOLD):
            _add_success("10.0.0.6")
        assert check_login_anomalies("10.0.0.6") is None
        assert Alert.query.count() == 0

    def test_dedupes_within_window(self, ctx):
        for _ in range(FAIL_THRESHOLD):
            _add_fail("10.0.0.7")
        a1 = check_login_anomalies("10.0.0.7")
        _add_fail("10.0.0.7")
        a2 = check_login_anomalies("10.0.0.7")
        assert a1 is not None and a2 is not None
        assert a1.id == a2.id
        assert Alert.query.count() == 1

    def test_custom_threshold_and_window(self, ctx):
        for _ in range(2):
            _add_fail("10.0.0.8")
        alert = check_login_anomalies("10.0.0.8", threshold=2, window_minutes=1)
        assert alert is not None
        assert Alert.query.count() == 1

    def test_mixed_success_and_fail_only_counts_fail(self, ctx):
        for _ in range(FAIL_THRESHOLD - 1):
            _add_fail("10.0.0.9")
        _add_success("10.0.0.9")
        assert check_login_anomalies("10.0.0.9") is None
        assert Alert.query.count() == 0


# --------------------------------------------------------------------------- #
# scan_recent_failures
# --------------------------------------------------------------------------- #
class TestScanRecentFailures:
    def test_no_failures_creates_nothing(self, ctx):
        assert scan_recent_failures() == []
        assert Alert.query.count() == 0

    def test_only_offending_ips_get_alerts(self, ctx):
        for _ in range(FAIL_THRESHOLD):
            _add_fail("10.0.1.1")
        for _ in range(FAIL_THRESHOLD - 1):
            _add_fail("10.0.1.2")
        for _ in range(FAIL_THRESHOLD + 2):
            _add_fail("10.0.1.3")

        created = scan_recent_failures()
        ips_alerted = sorted(
            a.description.split(" from ")[1].split(" ")[0] for a in created
        )
        assert ips_alerted == ["10.0.1.1", "10.0.1.3"]
        assert Alert.query.count() == 2

    def test_scan_is_idempotent(self, ctx):
        for _ in range(FAIL_THRESHOLD):
            _add_fail("10.0.1.4")
        scan_recent_failures()
        scan_recent_failures()
        assert Alert.query.count() == 1

    def test_scan_ignores_old_failures(self, ctx):
        for _ in range(FAIL_THRESHOLD + 3):
            _add_fail("10.0.1.5", minutes_ago=WINDOW_MINUTES + 5)
        assert scan_recent_failures() == []
        assert Alert.query.count() == 0
