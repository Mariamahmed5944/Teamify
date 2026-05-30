"""One-off: add mentor_chat_messages.thread_key if missing."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app
from models import db
from sqlalchemy import inspect, text

app = create_app()
with app.app_context():
    insp = inspect(db.engine)
    cols = {c["name"] for c in insp.get_columns("mentor_chat_messages")}
    print("columns:", sorted(cols))
    if "thread_key" in cols:
        print("thread_key already exists")
    else:
        with db.engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE mentor_chat_messages "
                    "ADD COLUMN IF NOT EXISTS thread_key VARCHAR(120) "
                    "NOT NULL DEFAULT 'general'"
                )
            )
        print("thread_key added")
