"""One-shot patch: insert approval gate into routes/auth.py login handler."""
import pathlib

auth_file = pathlib.Path(__file__).parent.parent / "routes" / "auth.py"
content = auth_file.read_text(encoding="utf-8")

OLD = "    # --- Log the login ---\n    log = Log(\n        action=\"LOGIN\","

NEW = """\
    # \u2500\u2500\u2500 Approval Gate \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    if getattr(user, "account_status", "approved") == "pending":
        db.session.commit()
        return jsonify({
            "error": "Account Pending Approval",
            "message": "Your account is awaiting admin approval. You will be notified once approved.",
        }), 403
    if getattr(user, "account_status", "approved") == "rejected":
        db.session.commit()
        reason = user.account_status_note or "Please contact support."
        return jsonify({
            "error": "Account Rejected",
            "message": f"Your account has been rejected. Reason: {reason}",
        }), 403

    # --- Log the login ---
    log = Log(
        action="LOGIN","""

if OLD in content:
    content = content.replace(OLD, NEW, 1)
    auth_file.write_text(content, encoding="utf-8")
    print("OK: approval gate inserted into routes/auth.py")
else:
    print("ERROR: target string not found. File may have already been patched.")
