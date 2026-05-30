"""
Align alembic_version with the real DB schema, then upgrade to head.

Use when `flask db upgrade` fails with DuplicateTable/DuplicateColumn because
migrations were applied manually or via an old broken revision chain.

  cd teamify_flask_backend
  python scripts/sync_migrations_to_head.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import inspect, text

from app import create_app
from models import db

HEAD = "j0k1l2m3n4o5"


def _has_table(insp, name: str) -> bool:
    return name in insp.get_table_names()


def _has_column(insp, table: str, column: str) -> bool:
    if not _has_table(insp, table):
        return False
    return column in {c["name"] for c in insp.get_columns(table)}


def _detect_revision(insp) -> str:
    """Pick the newest revision that matches the live schema."""
    if _has_column(insp, "messages", "file_id"):
        return HEAD
    if _has_table(insp, "project_invitations"):
        return "i9j0k1l2m3n4"
    if _has_column(insp, "users", "avatar_file_id"):
        return "h8i9j0k1l2m3"
    if _has_table(insp, "meeting_sessions"):
        return "f6a7b8c9d0e1"
    if _has_column(insp, "file_metadata", "project_id"):
        return "e5f6a7b8c9d0"
    if _has_column(insp, "project_members", "joined_at"):
        return "c9d1e2f3a4b5"
    if _has_table(insp, "token_blocklist"):
        return "a1b2c3d4e5f6"
    return "6bcfff8e64eb"


def main() -> None:
    app = create_app()
    with app.app_context():
        bind = db.engine
        insp = inspect(bind)
        detected = _detect_revision(insp)
        current = db.session.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        print(f"alembic_version (before): {current}")
        print(f"detected schema revision: {detected}")

        db.session.execute(
            text("UPDATE alembic_version SET version_num = :rev"),
            {"rev": detected},
        )
        db.session.commit()
        print(f"stamped -> {detected}")

    print("Run: flask db upgrade")


if __name__ == "__main__":
    main()
