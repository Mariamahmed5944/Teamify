"""Comprehensive backend test covering all endpoints."""
import requests
import uuid
import time

BASE = "http://127.0.0.1:5022/api"
S = requests.Session()
passed = 0
failed = 0


def test(name, method, url, expected_status, **kwargs):
    global passed, failed
    try:
        r = getattr(S, method)(BASE + url, **kwargs)
        if r.status_code == expected_status:
            passed += 1
            print(f"  PASS  {name} ({r.status_code})")
            return r.json() if r.content else {}
        else:
            failed += 1
            body = r.text[:200]
            print(f"  FAIL  {name} expected={expected_status} got={r.status_code} body={body}")
            return {}
    except Exception as e:
        failed += 1
        print(f"  FAIL  {name} ERROR: {e}")
        return {}


print("=" * 70)
print("COMPREHENSIVE BACKEND TEST")
print("=" * 70)

# 1. Health
print("\n--- Health ---")
test("Health check", "get", "/health", 200)

# 2. Auth
print("\n--- Auth ---")
ts = str(int(time.time()))
reg_data = {
    "display_name": f"testuser_{ts}",
    "email": f"test_{ts}@example.com",
    "password": "Test1234!",
    "full_name": "Test User",
    "user_type": "freelancer",
    "professional_field": "Designer",
    "experience_level": "Intermediate",
    "availability": "Full Time",
    "skills": "UI Design,UX Design,Figma",
}
r = test("Register user", "post", "/auth/register", 201, json=reg_data)
test("Register duplicate email", "post", "/auth/register", 409, json=reg_data)

login_data = {"email": reg_data["email"], "password": "Test1234!"}
r = test("Login", "post", "/auth/login", 200, json=login_data)
token = r.get("access_token", "")
S.headers.update({"Authorization": f"Bearer {token}"})

test("Login wrong password", "post", "/auth/login", 401,
     json={"email": reg_data["email"], "password": "wrong"})

# 3. Profile
print("\n--- Users/Profile ---")
r = test("Get profile", "get", "/users/profile", 200)
user_id = r.get("user", {}).get("id", "")
skills = r.get("user", {}).get("skills", [])
print(f"  INFO  User ID: {user_id}")
print(f"  INFO  Skills: {skills}")
print(f"  INFO  prof_field: {r.get('user', {}).get('professional_field')}")

test("Update profile", "put", "/users/profile", 200, json={
    "full_name": "Updated Name",
    "skills": "React,Node.js",
    "looking_for_team": True,
})

r = test("Get updated profile", "get", "/users/profile", 200)
print(f"  INFO  Updated skills: {r.get('user', {}).get('skills')}")
print(f"  INFO  looking_for_team: {r.get('user', {}).get('looking_for_team')}")

# 4. Projects
print("\n--- Projects ---")
proj_data = {
    "name": f"Test Project {ts}",
    "description": "A test project",
    "status": "active",
    "start_date": "2025-01-01",
    "end_date": "2025-12-31",
}
r = test("Create project", "post", "/projects", 201, json=proj_data)
project_id = r.get("project", {}).get("id", "")
print(f"  INFO  Project ID: {project_id}")

test("Get projects list", "get", "/projects", 200)
test("Get single project", "get", f"/projects/{project_id}", 200)
test("Update project", "put", f"/projects/{project_id}", 200, json={"description": "Updated"})

# 5. Tasks
print("\n--- Tasks ---")
task_data = {
    "title": f"Test Task {ts}",
    "description": "A test task",
    "project_id": project_id,
    "priority": "high",
    "status": "pending",
    "due_date": "2025-07-15",
}
r = test("Create task", "post", "/tasks", 201, json=task_data)
task_id = r.get("task", {}).get("id", "")
print(f"  INFO  Task ID: {task_id}")

test("Get tasks", "get", f"/tasks?project_id={project_id}", 200)
test("Get single task", "get", f"/tasks/{task_id}", 200)
test("Update task status", "patch", f"/tasks/{task_id}/status", 200, json={"status": "in_progress"})
test("Update task", "put", f"/tasks/{task_id}", 200, json={"title": "Updated Task", "priority": "medium"})

# Auto-assign test
task_auto = {
    "title": "Auto assign test",
    "project_id": project_id,
    "auto_assign": True,
    "due_date": "2025-08-01",
}
r = test("Create task with auto_assign", "post", "/tasks", 201, json=task_auto)
auto_task_id = r.get("task", {}).get("id", "")

# 6. AI
print("\n--- AI ---")
test("AI suggest priority", "post", "/ai/suggest-priority", 200, json={
    "project_id": project_id, "title": "urgent bugfix", "due_date": "2025-07-10"
})
test("AI suggest deadline", "post", "/ai/suggest-deadline", 200, json={
    "project_id": project_id, "priority": "high"
})
test("AI auto-assign", "post", "/ai/assign", 200, json={
    "project_id": project_id, "priority": "high"
})
test("AI delay prediction", "post", "/ai/delay", 200, json={
    "task_id": task_id
})
test("AI workload", "get", "/ai/workload", 200)

# 7. Stats
print("\n--- Stats ---")
test("Project stats", "get", f"/stats/project/{project_id}", 200)

# 8. Reminders
print("\n--- Reminders ---")
test("Get reminders", "get", "/reminders", 200)

# 9. Logs
print("\n--- Logs ---")
test("Get logs", "get", "/logs/my", 200)

# 10. Notifications
print("\n--- Notifications ---")
r = test("Get notifications", "get", "/notifications", 200)
print(f"  INFO  Notification count: {r.get('total', 0)}")
print(f"  INFO  Unread count: {r.get('unread_count', 0)}")
test("Get unread count", "get", "/notifications/unread-count", 200)
test("Mark all read", "post", "/notifications/mark-all-read", 200)
r2 = test("Get notifications after mark-all", "get", "/notifications", 200)
print(f"  INFO  Unread after mark-all: {r2.get('unread_count', '?')}")

# 11. Dashboard
print("\n--- Dashboard ---")
r = test("Get dashboard", "get", "/dashboard", 200)
if r:
    print(f"  INFO  Dashboard keys: {list(r.keys())}")
    print(f"  INFO  Stats: {r.get('stats', {})}")
    print(f"  INFO  Active projects: {len(r.get('active_projects', []))}")
    print(f"  INFO  At-risk tasks: {len(r.get('at_risk_tasks', []))}")
    print(f"  INFO  Recent activity: {len(r.get('recent_activity', []))}")
    print(f"  INFO  User: {r.get('user', {})}")

# 12. Search
print("\n--- Search ---")
r = test("Search users by name", "get", "/search/users?q=testuser", 200)
print(f"  INFO  Users found: {r.get('total', 0)}")
r = test("Search users by skill", "get", "/search/users?skill=React", 200)
print(f"  INFO  Users with React skill: {r.get('total', 0)}")
r = test("Search users by user_type", "get", "/search/users?user_type=freelancer", 200)
print(f"  INFO  Freelancers found: {r.get('total', 0)}")
r = test("Search projects", "get", "/search/projects?q=Test", 200)
print(f"  INFO  Projects found: {r.get('total', 0)}")

# 13. Project members (improved)
print("\n--- Project Members ---")
r = test("Get project members", "get", f"/projects/{project_id}/members", 200)
if r.get("members"):
    m = r["members"][0]
    print(f"  INFO  Member keys: {list(m.keys())}")
    print(f"  INFO  Has skills: {'skills' in m}")
    print(f"  INFO  Has user_type: {'user_type' in m}")
    print(f"  INFO  Has availability: {'availability' in m}")

# 14. Error cases
print("\n--- Error Cases ---")
test("Get task 404", "get", f"/tasks/{uuid.uuid4()}", 404)
test("Get project 404", "get", f"/projects/{uuid.uuid4()}", 404)
test("Create task no body", "post", "/tasks", 400, json={})
test("Create project no name", "post", "/projects", 400, json={})

# 15. Cleanup
print("\n--- Cleanup ---")
if auto_task_id:
    test("Delete auto task", "delete", f"/tasks/{auto_task_id}", 200)
test("Delete task", "delete", f"/tasks/{task_id}", 200)
test("Delete project", "delete", f"/projects/{project_id}", 200)

# Summary
print("\n" + "=" * 70)
print(f"RESULTS: {passed} passed, {failed} failed, {passed + failed} total")
print("=" * 70)
