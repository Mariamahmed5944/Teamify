"""
Full endpoint integration test — all 5 users, all routes.
Prerequisites:
  1. Flask server running on :5022
  2. Run bootstrap_test_users.py once to create admin_master in DB
"""
import sys, os, json, io, time, requests
from datetime import date

BASE    = "http://127.0.0.1:5022"
RESULTS = []

tokens         = {}
refresh_tokens = {}
user_ids       = {}
project_id     = None
task_id        = None
cv_id          = None
dispute_id     = None
rating_id      = None
fb_id          = None


# ── helpers ──────────────────────────────────────────────────────────────────

def _h(name):
    t = tokens.get(name, "")
    return {"Authorization": f"Bearer {t}"} if t else {}

def _safe_json(resp):
    try:
        return resp.json()
    except Exception:
        return {}

def rec(group, method, path, resp, ok_statuses=(200, 201)):
    ok = resp.status_code in ok_statuses
    try:
        body = resp.json()
        note = str(list(body.keys())[:4]) if isinstance(body, dict) else str(body)[:60]
    except Exception:
        note = resp.text[:60]
    RESULTS.append({"group": group, "method": method, "path": path,
                     "status": resp.status_code, "ok": ok, "note": note})
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {method:<7} {path:<55} {resp.status_code}  {note[:50]}")
    return resp

def _call(method, url, **kw):
    """Call with automatic retry on server reload (WinError 10054) or timeout."""
    timeout = kw.pop("timeout", 120)   # AI endpoints can take >60s on first load
    for attempt in range(4):
        try:
            return getattr(requests, method)(url, timeout=timeout, **kw)
        except (requests.exceptions.ConnectionError, requests.exceptions.ReadTimeout) as exc:
            if attempt == 3:
                raise
            wait_secs = 15 if "timed out" in str(exc).lower() else 8
            print(f"    [retry {attempt+1}] {exc.__class__.__name__}, waiting {wait_secs}s...")
            time.sleep(wait_secs)
            wait_for_server(max_tries=12, delay=2.0)

def GET(group, path, user, **kw):
    return rec(group, "GET", path,
               _call("get", BASE+path, headers=_h(user), **kw))

def POST(group, path, user, payload=None, **kw):
    return rec(group, "POST", path,
               _call("post", BASE+path, json=payload, headers=_h(user), **kw))

def PUT(group, path, user, payload=None):
    return rec(group, "PUT", path,
               _call("put", BASE+path, json=payload, headers=_h(user)))

def PATCH(group, path, user, payload=None):
    return rec(group, "PATCH", path,
               _call("patch", BASE+path, json=payload, headers=_h(user)))

def DELETE(group, path, user):
    return rec(group, "DELETE", path,
               _call("delete", BASE+path, headers=_h(user)),
               ok_statuses=(200, 204))

def wait_for_server(max_tries=8, delay=2.0):
    for i in range(max_tries):
        try:
            r = requests.get(BASE+"/api/health", timeout=5)
            if r.status_code == 200:
                print(f"  Server ready.")
                return True
        except Exception:
            pass
        print(f"  Waiting for server... ({i+1}/{max_tries})")
        time.sleep(delay)
    return False


# ════════════════════════════════════════════════════════════════════════════
# 1.  HEALTH
# ════════════════════════════════════════════════════════════════════════════
print("\n=== HEALTH CHECK ===")
if not wait_for_server():
    print("ERROR: server not reachable — start Flask first.")
    sys.exit(1)

GET("Health", "/api/health", None)


# ════════════════════════════════════════════════════════════════════════════
# 2.  AUTH — login admin (must exist via bootstrap_test_users.py)
# ════════════════════════════════════════════════════════════════════════════
print("\n=== AUTH: login admin ===")
r = requests.post(BASE+"/api/auth/login",
                  json={"email": "admin@teamify.com", "password": "Password123!"},
                  timeout=10)
if r.status_code == 200:
    b = r.json()
    tokens["admin_master"]         = b.get("access_token", "")
    refresh_tokens["admin_master"] = b.get("refresh_token", "")
    user_ids["admin_master"]       = (b.get("user") or {}).get("id")
    RESULTS.append({"group":"Auth","method":"POST","path":"/api/auth/login",
                     "status":200,"ok":True,"note":"admin_master"})
    print(f"  [PASS] login admin_master -> 200  id={user_ids['admin_master']}")
else:
    RESULTS.append({"group":"Auth","method":"POST","path":"/api/auth/login",
                     "status":r.status_code,"ok":False,"note":"admin_master"})
    print(f"  [FAIL] login admin_master -> {r.status_code} — did you run bootstrap_test_users.py?")
    sys.exit(1)


# Register the other 4 users (using admin JWT so pending approval can be done next)
OTHER_USERS = [
    {"display_name": "ahmed_free", "email": "ahmed.freelancer@example.com",
     "full_name": "Ahmed Ali",   "password": "Password123!",
     "role": "member", "user_type": "freelancer"},
    {"display_name": "sara_edu",  "email": "sara.student@example.com",
     "full_name": "Sara Hassan", "password": "Password123!",
     "role": "member", "user_type": "student"},
    {"display_name": "omar_lead", "email": "omar.lead@example.com",
     "full_name": "Omar Tariq",  "password": "Password123!",
     "role": "member", "user_type": "freelancer"},
    {"display_name": "nour_uni",  "email": "nour.uni@example.com",
     "full_name": "Nour Khaled", "password": "Password123!",
     "role": "member", "user_type": "student"},
]

print("\n=== AUTH: register 4 users ===")
for u in OTHER_USERS:
    r = requests.post(BASE+"/api/auth/register", json=u,
                      headers=_h("admin_master"), timeout=10)
    ok = r.status_code in (200, 201, 409)
    RESULTS.append({"group":"Auth","method":"POST","path":"/api/auth/register",
                     "status":r.status_code,"ok":ok,"note":u["display_name"]})
    print(f"  [{'PASS' if ok else 'FAIL'}] register {u['display_name']} -> {r.status_code}")

print("\n=== ADMIN: approve all pending users ===")
r2 = requests.get(BASE+"/admin/users/pending", headers=_h("admin_master"), timeout=10)
if r2.status_code == 200:
    pending = r2.json().get("items", [])
    for pu in pending:
        uid_val = pu.get("id")
        rr = requests.patch(BASE+f"/admin/users/{uid_val}/approve",
                            headers=_h("admin_master"), timeout=10)
        RESULTS.append({"group":"Admin","method":"PATCH",
                         "path":f"/admin/users/{uid_val}/approve",
                         "status":rr.status_code,"ok":rr.status_code==200,
                         "note":pu.get("display_name","")})
        print(f"  [{'PASS' if rr.status_code==200 else 'FAIL'}] approve {pu.get('display_name')} -> {rr.status_code}")

print("\n=== AUTH: login 4 users ===")
for u in OTHER_USERS:
    r = requests.post(BASE+"/api/auth/login",
                      json={"email": u["email"], "password": u["password"]},
                      timeout=10)
    ok = r.status_code == 200
    RESULTS.append({"group":"Auth","method":"POST","path":"/api/auth/login",
                     "status":r.status_code,"ok":ok,"note":u["display_name"]})
    print(f"  [{'PASS' if ok else 'FAIL'}] login {u['display_name']} -> {r.status_code}")
    if ok:
        b = r.json()
        tokens[u["display_name"]]         = b.get("access_token", "")
        refresh_tokens[u["display_name"]] = b.get("refresh_token", "")
        user_ids[u["display_name"]]       = (b.get("user") or {}).get("id")

admin_id = user_ids.get("admin_master")
ahmed_id = user_ids.get("ahmed_free")
sara_id  = user_ids.get("sara_edu")
omar_id  = user_ids.get("omar_lead")
nour_id  = user_ids.get("nour_uni")

print(f"\n  IDs: admin={admin_id}  ahmed={ahmed_id}  sara={sara_id}  omar={omar_id}  nour={nour_id}")

print("\n=== AUTH: /me, refresh, forgot-password, logout ===")
GET("Auth",  "/api/auth/me",                "ahmed_free")
r_ref = requests.post(BASE+"/api/auth/refresh",
                      headers={"Authorization": f"Bearer {refresh_tokens.get('sara_edu','')}"},
                      timeout=10)
rec("Auth", "POST", "/api/auth/refresh", r_ref)
POST("Auth", "/api/auth/forgot-password", None, {"email": "ahmed.freelancer@example.com"})
POST("Auth", "/api/auth/logout",  "nour_uni")


# ════════════════════════════════════════════════════════════════════════════
# 3.  USERS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== USERS ===")
GET("Users",  "/api/users/profile",             "ahmed_free")
PUT("Users",  "/api/users/profile",             "sara_edu",
    {"full_name": "Sara Hassan Updated"})
if ahmed_id:
    GET("Users", f"/api/users/{ahmed_id}/profile", "admin_master")
    GET("Users", f"/api/users/{ahmed_id}/stats",   "admin_master")
GET("Users",  "/api/users/admin-dashboard",     "admin_master")
rec("Users", "GET", "/api/users/admin-dashboard",
    requests.get(BASE+"/api/users/admin-dashboard", headers=_h("ahmed_free"), timeout=10),
    ok_statuses=(403,))   # member should be denied


# ════════════════════════════════════════════════════════════════════════════
# 4.  ADMIN ROUTES
# ════════════════════════════════════════════════════════════════════════════
print("\n=== ADMIN ===")
GET("Admin", "/admin/users",                   "admin_master")
GET("Admin", "/admin/users/pending",           "admin_master")
GET("Admin", "/admin/reports/summary",         "admin_master")
GET("Admin", "/admin/analytics/overview",      "admin_master")
GET("Admin", "/admin/analytics/users/growth",  "admin_master")
GET("Admin", "/admin/logs",                    "admin_master")
GET("Admin", "/admin/activity",                "admin_master")
GET("Admin", "/admin/audit-logs",              "admin_master")
GET("Admin", "/admin/alerts",                  "admin_master")
GET("Admin", "/admin/export/users",            "admin_master")


# ════════════════════════════════════════════════════════════════════════════
# 5.  PROJECTS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== PROJECTS ===")
r = POST("Projects", "/api/projects", "admin_master", {
    "name":        "Teamify Integration Test",
    "description": "Created by automated endpoint test",
    "status":      "active",
    "start_date":  str(date.today()),
    "end_date":    "2026-12-31",
})
if r.status_code in (200, 201):
    body = r.json()
    prj = body.get("project") or body
    project_id = prj.get("id") if isinstance(prj, dict) else None

# Add members BEFORE any member-access calls
if project_id and ahmed_id:
    POST("Projects", f"/api/projects/{project_id}/members", "admin_master",
         {"user_id": ahmed_id, "role": "member"})
if project_id and sara_id:
    POST("Projects", f"/api/projects/{project_id}/members", "admin_master",
         {"user_id": sara_id, "role": "member"})

if project_id:
    GET("Projects",  f"/api/projects/{project_id}",         "ahmed_free")   # now a member
    PUT("Projects",  f"/api/projects/{project_id}",         "admin_master",
        {"description": "Updated by test"})
    GET("Projects",  f"/api/projects/{project_id}/members", "admin_master")

GET("Projects", "/api/projects",           "ahmed_free")
GET("Projects", "/api/projects/completed", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 6.  TASKS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== TASKS ===")
task_payload = {
    "title":       "Implement JWT authentication API",
    "description": "Build a secure REST JWT endpoint with refresh tokens",
    "status":      "in_progress",   # valid: pending | in_progress | done
    "priority":    "high",
    "due_date":    "2026-09-01",
    "project_id":  project_id,
    "assigned_to": ahmed_id,
}
r = POST("Tasks", "/api/tasks", "admin_master", task_payload)
if r.status_code in (200, 201):
    body = r.json()
    tsk = body.get("task") or body
    task_id = tsk.get("id") if isinstance(tsk, dict) else None

if project_id:
    GET("Tasks", "/api/tasks", "ahmed_free", params={"project_id": project_id})

if task_id:
    GET("Tasks",   f"/api/tasks/{task_id}",        "ahmed_free")
    PUT("Tasks",   f"/api/tasks/{task_id}",        "admin_master",
        {"description": "Updated task description"})
    PATCH("Tasks", f"/api/tasks/{task_id}/status", "ahmed_free",
          {"status": "done"})
    POST("Tasks",  f"/api/tasks/{task_id}/comments", "ahmed_free",
         {"content": "Started working on this task."})
    GET("Tasks",   f"/api/tasks/{task_id}/comments", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 7.  AI ENDPOINTS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== AI ===")
POST("AI", "/api/ai/classify-task", "ahmed_free",
     {"text": "Build a secure REST JWT authentication API with refresh tokens"})

POST("AI", "/api/ai/assign-members", "admin_master", {
    "task_info": {"category": "backend", "required_skills": ["Python", "Flask"]},
    "members": [
        {"id": ahmed_id, "member_primary_domain": "backend",
         "member_skills": ["Python", "Flask"], "rating": 4.2, "current_tasks": 1},
        {"id": sara_id,  "member_primary_domain": "frontend",
         "member_skills": ["React", "CSS"],   "rating": 3.8, "current_tasks": 3},
    ]
})

CHAT = ("Ahmed: We need to finish the authentication API by Friday.\n"
        "Sara: I will handle the frontend integration.\n"
        "Omar: I need to update the deployment docs before the release.\n"
        "Nour: I can help with testing the endpoints tomorrow.")

POST("AI", "/api/ai/summarize-chat",      "ahmed_free", {"chat_text": CHAT})
POST("AI", "/api/ai/chat/summarize",      "sara_edu",   {"text": CHAT, "top_n": 2})
POST("AI", "/api/ai/detect-anomaly",      "admin_master",
     {"user_id": ahmed_id or 1, "failed_attempts": 7})
POST("AI", "/api/ai/recommend-teammates", "ahmed_free", {
    "user_stats": {"member_on_time_rate": 0.9, "member_avg_delay_days": 1,
                   "member_experience_years": 3, "max_capacity": 5},
    "top_n": 3,
})

if task_id:
    GET("AI", f"/api/ai/predict-delay/{task_id}", "admin_master")

if ahmed_id:
    GET("AI", f"/api/ai/predict-rating/{ahmed_id}",  "admin_master")
    GET("AI", f"/api/ai/mentor-report/{ahmed_id}",   "admin_master")
    GET("AI", f"/api/ai/mentor/analyse/{ahmed_id}",  "admin_master")
    GET("AI", f"/api/ai/mentor/analyse/{ahmed_id}",  "ahmed_free")  # own profile

POST("AI", "/api/ai/cv/build", "ahmed_free", {})
if admin_id and ahmed_id:
    POST("AI", "/api/ai/cv/build", "admin_master", {"target_user_id": ahmed_id})

# Transcribe — no audio, expects 400; no STT service, might be 502
r_tr = requests.post(BASE+"/api/ai/transcribe", headers=_h("ahmed_free"), timeout=10)
rec("AI", "POST", "/api/ai/transcribe", r_tr, ok_statuses=(400, 502))


# ════════════════════════════════════════════════════════════════════════════
# 8.  STATS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== STATS ===")
GET("Stats", "/api/stats/global",            "admin_master")
GET("Stats", "/api/stats/workload-overview", "admin_master")
if project_id:
    GET("Stats", f"/api/stats/project/{project_id}", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 9.  DASHBOARD
# ════════════════════════════════════════════════════════════════════════════
print("\n=== DASHBOARD ===")
GET("Dashboard", "/api/dashboard", "ahmed_free")
GET("Dashboard", "/api/dashboard", "admin_master")


# ════════════════════════════════════════════════════════════════════════════
# 10. NOTIFICATIONS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== NOTIFICATIONS ===")
GET("Notifications",  "/api/notifications",              "ahmed_free")
GET("Notifications",  "/api/notifications/unread-count", "ahmed_free")
POST("Notifications", "/api/notifications/mark-all-read","ahmed_free")

# Try to mark individual notification as read
notif_r = requests.get(BASE+"/api/notifications", headers=_h("ahmed_free"), timeout=10)
if notif_r.ok:
    body = notif_r.json()
    nlist = body if isinstance(body, list) else body.get("notifications", body.get("items", []))
    if nlist and isinstance(nlist[0], dict):
        nid = nlist[0].get("id")
        if nid:
            PATCH("Notifications", f"/api/notifications/{nid}/read", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 11. LOGS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== LOGS ===")
GET("Logs", "/api/logs/my",  "ahmed_free")
GET("Logs", "/api/logs/all", "admin_master")


# ════════════════════════════════════════════════════════════════════════════
# 12. SEARCH
# ════════════════════════════════════════════════════════════════════════════
print("\n=== SEARCH ===")
GET("Search", "/api/search/users",    "ahmed_free", params={"q": "sara"})
GET("Search", "/api/search/projects", "ahmed_free", params={"q": "teamify"})


# ════════════════════════════════════════════════════════════════════════════
# 13. REMINDERS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== REMINDERS ===")
GET("Reminders", "/api/reminders", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 14. FEEDBACK
# ════════════════════════════════════════════════════════════════════════════
print("\n=== FEEDBACK ===")
if project_id and sara_id:
    r = POST("Feedback", "/api/feedback", "ahmed_free", {
        "user_id":       sara_id,          # required: person being reviewed
        "project_id":    project_id,
        "quality_score": 4.5,
        "teamwork_score":4.0,
        "feedback_text": "Sara was great to work with!",
    })
    if r.status_code in (200, 201):
        b = r.json()
        fb_id = (b.get("feedback") or b).get("id") if isinstance(b, dict) else None

if ahmed_id:
    GET("Feedback", f"/api/feedback/user/{ahmed_id}", "admin_master")
if project_id:
    GET("Feedback", f"/api/feedback/project/{project_id}", "admin_master")
if fb_id:
    GET("Feedback",    f"/api/feedback/{fb_id}",  "ahmed_free")
    PUT("Feedback",    f"/api/feedback/{fb_id}",  "ahmed_free",
        {"content": "Updated: Great collaboration!"})
    DELETE("Feedback", f"/api/feedback/{fb_id}",  "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 15. RATINGS
# ════════════════════════════════════════════════════════════════════════════
print("\n=== RATINGS ===")
if ahmed_id and admin_id:
    r = POST("Ratings", "/api/ratings", "admin_master", {
        "ratee_id": ahmed_id,
        "score":    4,
        "comment":  "Good work on the backend.",
    })
    if r.status_code in (200, 201):
        b = r.json()
        rating_id = (b.get("rating") or b).get("id") if isinstance(b, dict) else None
    GET("Ratings", f"/api/ratings/user/{ahmed_id}",     "admin_master")
    GET("Ratings", f"/api/ratings/user/{ahmed_id}/avg", "admin_master")
    if rating_id:
        PUT("Ratings",    f"/api/ratings/{rating_id}", "admin_master", {"score": 5})
        DELETE("Ratings", f"/api/ratings/{rating_id}", "admin_master")


# ════════════════════════════════════════════════════════════════════════════
# 16. CV
# ════════════════════════════════════════════════════════════════════════════
print("\n=== CV ===")
r = POST("CV", "/api/cv", "ahmed_free", {
    "personal_info": {
        "full_name": "Ahmed Ali",
        "email":     "ahmed.freelancer@example.com",
        "location":  "Cairo, Egypt",
    },
    "skills": [
        {"name": "Python", "level": "Expert"},
        {"name": "Flask",  "level": "Advanced"},
    ],
    "is_public": False,
})
if r.status_code in (200, 201):
    b = r.json()
    cv_id = (b.get("cv") or b).get("id") if isinstance(b, dict) else None

if cv_id:
    GET("CV",   f"/api/cv/{cv_id}", "ahmed_free")
    PATCH("CV", f"/api/cv/{cv_id}", "ahmed_free",
          {"is_public": True,
           "skills": [{"name": "Python", "level": "Expert"},
                      {"name": "Flask",  "level": "Advanced"},
                      {"name": "PostgreSQL", "level": "Intermediate"}]})
    POST("CV",  f"/api/cv/{cv_id}/export", "ahmed_free", {"format": "json"})


# ════════════════════════════════════════════════════════════════════════════
# 17. DISPUTES
# ════════════════════════════════════════════════════════════════════════════
print("\n=== DISPUTES ===")
r = POST("Disputes", "/api/disputes", "ahmed_free", {
    "accused_id":  omar_id,               # required: must be a different user
    "subject":     "Task deadline not communicated",
    "description": "The task deadline was changed without notification.",
    "project_id":  project_id,
    "category":    "deadline",
})
if r.status_code in (200, 201):
    b = r.json()
    dispute_id = (b.get("dispute") or b).get("id") if isinstance(b, dict) else None

GET("Disputes", "/api/disputes",     "admin_master")
GET("Disputes", "/api/disputes/my",  "ahmed_free")

if dispute_id:
    GET("Disputes",   f"/api/disputes/{dispute_id}",        "admin_master")
    PATCH("Disputes", f"/api/disputes/{dispute_id}/status", "admin_master",
          {"status": "resolved"})


# ════════════════════════════════════════════════════════════════════════════
# 18. FILES
# ════════════════════════════════════════════════════════════════════════════
print("\n=== FILES ===")
file_resp = requests.post(
    BASE+"/api/files",
    headers=_h("ahmed_free"),
    files={"file": ("hello.txt", io.BytesIO(b"Teamify file upload test"), "text/plain")},
    data={"project_id": str(project_id) if project_id else ""},
    timeout=15,
)
rec("Files", "POST", "/api/files", file_resp, ok_statuses=(200, 201, 400, 422))
if file_resp.status_code in (200, 201):
    b = file_resp.json()
    fid = (b.get("file") or b).get("id") if isinstance(b, dict) else None
    if fid:
        GET("Files", f"/api/files/{fid}", "ahmed_free")


# ════════════════════════════════════════════════════════════════════════════
# 19. CLEANUP
# ════════════════════════════════════════════════════════════════════════════
print("\n=== CLEANUP ===")
if task_id:
    DELETE("Cleanup", f"/api/tasks/{task_id}",       "admin_master")
# Delete dispute first to avoid FK violation on project delete
if dispute_id:
    rec("Cleanup", "DELETE", f"/api/disputes/{dispute_id}",
        requests.delete(BASE+f"/api/disputes/{dispute_id}", headers=_h("admin_master"), timeout=30),
        ok_statuses=(200, 204, 404, 405))  # may not be supported — record but don't fail
if project_id:
    DELETE("Cleanup", f"/api/projects/{project_id}", "admin_master")


# ════════════════════════════════════════════════════════════════════════════
# FINAL REPORT
# ════════════════════════════════════════════════════════════════════════════
total  = len(RESULTS)
passed = sum(1 for r in RESULTS if r["ok"])
failed = total - passed

print("\n" + "="*74)
print("  ENDPOINT TEST REPORT")
print("="*74)

groups = {}
for r in RESULTS:
    groups.setdefault(r["group"], []).append(r)

for gname, items in groups.items():
    g_pass = sum(1 for i in items if i["ok"])
    print(f"\n  [{gname}]  {g_pass}/{len(items)} passed")
    for i in items:
        mark = "PASS" if i["ok"] else "FAIL"
        print(f"    [{mark}] {i['method']:<7} {i['path']:<55} {i['status']}")

print("\n" + "="*74)
print(f"  TOTAL: {passed}/{total} passed  |  {failed} FAILED")
print("="*74)

with open("test_results.json", "w", encoding="utf-8") as f:
    json.dump({
        "summary":    {"total": total, "passed": passed, "failed": failed},
        "user_ids":   user_ids,
        "project_id": project_id,
        "task_id":    task_id,
        "results":    RESULTS,
    }, f, indent=2, ensure_ascii=False)

print("Results saved to test_results.json")
