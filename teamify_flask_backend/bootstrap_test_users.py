"""
Lightweight bootstrap script — creates the admin_master user directly in the DB.
Uses only dotenv + sqlalchemy + bcrypt (NO torch/ML imports).
Run ONCE before test_all_endpoints.py.
"""
import os, sys, json
from dotenv import load_dotenv

load_dotenv()

# Minimal DB URL resolution (mirrors config.py)
db_url = os.getenv("DATABASE_URL", "sqlite:///app.db")
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)

print(f"[bootstrap] DB: {db_url}")

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from flask_bcrypt import generate_password_hash

# Create engine with minimal pool config
engine = create_engine(db_url, pool_pre_ping=True)
Session = sessionmaker(bind=engine)
session = Session()

def hash_pw(pw: str) -> str:
    # bcrypt outside Flask context (no app needed for the standalone function)
    import bcrypt as _bcrypt
    return _bcrypt.hashpw(pw.encode(), _bcrypt.gensalt()).decode()

try:
    import bcrypt as _bcrypt
    def _hash(pw): return _bcrypt.hashpw(pw.encode(), _bcrypt.gensalt()).decode()
except ImportError:
    # Fallback: use flask_bcrypt standalone
    from flask import Flask
    _flask_app = Flask(__name__)
    _b = __import__("flask_bcrypt").Bcrypt(_flask_app)
    def _hash(pw): return _b.generate_password_hash(pw).decode()

try:
    # Check if admin_master exists
    row = session.execute(
        text("SELECT id, role, account_status FROM users WHERE email = :e"),
        {"e": "admin@teamify.com"}
    ).fetchone()

    if row:
        uid = row[0]
        if row[1] != "admin" or row[2] != "approved":
            session.execute(
                text("UPDATE users SET role='admin', account_status='approved' WHERE id=:i"),
                {"i": uid}
            )
            session.commit()
            print(f"[bootstrap] Promoted existing user id={uid} to admin/approved")
        else:
            print(f"[bootstrap] admin@teamify.com already admin/approved  id={uid}")
    else:
        # Insert new admin user
        pw_hash = _hash("Password123!")
        result = session.execute(
            text("""
                INSERT INTO users
                    (display_name, full_name, email, password,
                     role, user_type, account_status)
                VALUES
                    ('admin_master', 'System Admin', 'admin@teamify.com', :pw,
                     'admin', 'freelancer', 'approved')
                RETURNING id
            """),
            {"pw": pw_hash}
        )
        uid = result.fetchone()[0]
        session.commit()
        print(f"[bootstrap] Created admin_master  id={uid}")

    # Write id to file so test script can use it
    with open("bootstrap_result.json", "w") as f:
        json.dump({"admin_id": uid}, f)

    print("[bootstrap] Done.")
    sys.exit(0)

except Exception as exc:
    session.rollback()
    print(f"[bootstrap] ERROR: {exc}")
    import traceback; traceback.print_exc()
    sys.exit(1)
finally:
    session.close()
