"""Appends GitHub OAuth endpoint to routes/auth.py"""
import pathlib

auth_file = pathlib.Path(__file__).parent.parent / "routes" / "auth.py"
content = auth_file.read_text(encoding="utf-8")

GITHUB_ENDPOINT = '''

# ─── POST /api/auth/github ────────────────────────────────────────────────────
# Receives a GitHub OAuth code from the client, exchanges it for a GitHub
# access token, fetches the GitHub user profile, and issues app JWTs.

@auth_bp.route("/github", methods=["POST"])
@limiter.limit("10 per minute")
def github_login():
    """
    GitHub OAuth login — exchange code for app JWT.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [code]
          properties:
            code:
              type: string
              description: OAuth code received from GitHub callback
    responses:
      200:
        description: Login successful
      400:
        description: Missing code or GitHub error
      500:
        description: GitHub API error
    """
    import os, requests as _req
    data = request.get_json(silent=True, force=True) or {}
    code = data.get("code", "").strip()
    if not code:
        return jsonify({"error": "code is required"}), 400

    client_id     = os.getenv("GITHUB_CLIENT_ID", "")
    client_secret = os.getenv("GITHUB_CLIENT_SECRET", "")

    # Step 1: Exchange code for GitHub access token
    token_resp = _req.post(
        "https://github.com/login/oauth/access_token",
        json={"client_id": client_id, "client_secret": client_secret, "code": code},
        headers={"Accept": "application/json"},
        timeout=10,
    )
    if token_resp.status_code != 200:
        return jsonify({"error": "Failed to reach GitHub token endpoint"}), 502

    token_data   = token_resp.json()
    github_token = token_data.get("access_token")
    if not github_token:
        err = token_data.get("error_description", token_data.get("error", "Unknown error"))
        return jsonify({"error": f"GitHub OAuth error: {err}"}), 400

    # Step 2: Fetch GitHub user profile
    profile_resp = _req.get(
        "https://api.github.com/user",
        headers={"Authorization": f"Bearer {github_token}", "Accept": "application/json"},
        timeout=10,
    )
    if profile_resp.status_code != 200:
        return jsonify({"error": "Failed to fetch GitHub user profile"}), 502

    gh_user    = profile_resp.json()
    github_id  = str(gh_user.get("id", ""))
    gh_email   = gh_user.get("email") or ""
    gh_name    = gh_user.get("name") or gh_user.get("login") or "github_user"
    gh_login   = gh_user.get("login") or f"gh_{github_id}"

    # Step 3: Fetch primary email if not public
    if not gh_email:
        emails_resp = _req.get(
            "https://api.github.com/user/emails",
            headers={"Authorization": f"Bearer {github_token}", "Accept": "application/json"},
            timeout=10,
        )
        if emails_resp.status_code == 200:
            for em in emails_resp.json():
                if em.get("primary") and em.get("verified"):
                    gh_email = em.get("email", "")
                    break

    if not github_id:
        return jsonify({"error": "Could not retrieve GitHub user ID"}), 400

    # Step 4: Find or create user
    user = User.query.filter_by(github_id=github_id).first()
    if not user and gh_email:
        user = User.query.filter_by(email=gh_email).first()
        if user:
            user.github_id = github_id  # link existing account

    if not user:
        # Auto-register a new user via GitHub
        import secrets as _sec
        dummy_pw = bcrypt.generate_password_hash(_sec.token_hex(32)).decode("utf-8")
        # Ensure unique display_name
        base_name = gh_login[:78]
        display_name = base_name
        counter = 1
        while User.query.filter_by(display_name=display_name).first():
            display_name = f"{base_name}_{counter}"
            counter += 1

        user = User(
            display_name=display_name,
            full_name=gh_name[:150] if gh_name else None,
            email=gh_email or f"{github_id}@github.noemail",
            password=dummy_pw,
            role="member",
            github_id=github_id,
            account_status="approved",  # GitHub users are pre-verified
        )
        db.session.add(user)
        db.session.flush()
        db.session.add(Log(
            action="GITHUB_REGISTER", entity="User", entity_id=user.id,
            details=f"GitHub OAuth registration for login '{gh_login}'",
            user_id=user.id,
        ))
        db.session.commit()

    # Step 5: Check account status
    if getattr(user, "account_status", "approved") == "rejected":
        reason = user.account_status_note or "Contact support."
        return jsonify({"error": "Account Rejected", "message": reason}), 403

    # Step 6: Issue app JWT
    access_token  = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))

    ip = request.remote_addr or "unknown"
    _record_login_attempt(user.id, "success")
    log_security_event("GITHUB_LOGIN_SUCCESS", user_id=user.id, ip=ip,
                       details={"github_login": gh_login})

    response = make_response(jsonify({
        "message":       "GitHub login successful",
        "user":          user.to_dict(),
        "access_token":  access_token,
        "refresh_token": refresh_token,
    }), 200)
    set_access_cookies(response, access_token)
    set_refresh_cookies(response, refresh_token)
    return response
'''

if "def github_login" not in content:
    content = content + GITHUB_ENDPOINT
    auth_file.write_text(content, encoding="utf-8")
    print("OK: GitHub OAuth endpoint appended to routes/auth.py")
else:
    print("INFO: github_login already present, skipping.")
