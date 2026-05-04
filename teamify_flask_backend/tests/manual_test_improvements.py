import requests, uuid

BASE = 'http://127.0.0.1:5022'
suffix = str(uuid.uuid4())[:8]

def reg(u, e, p, role=None):
    body = {'display_name': u+suffix, 'email': e+suffix+'@t.com', 'password': p}
    if role:
        body['role'] = role
    return requests.post(f'{BASE}/api/auth/register', json=body)

results = []

def chk(label, resp, expected):
    ok = resp.status_code == expected
    results.append((label, resp.status_code, expected, 'PASS' if ok else 'FAIL', resp.text[:120]))
    return resp

# Registration
ra = chk('Register member (default)', reg('ownerA', 'a1', 'Pass1234'), 201)
ta = ra.json().get('access_token', '')

rb = chk('Register guest', reg('guestB', 'b1', 'Pass1234', 'guest'), 201)
tb = rb.json().get('access_token', '')
ub = rb.json().get('user', {}).get('id', '')

chk('Self-register as admin -> blocked (400)', reg('selfadmin', 'c1', 'Pass1234', 'admin'), 400)
chk('Bad email format -> 400', requests.post(f'{BASE}/api/auth/register', json={
    'display_name': 'xx' + suffix, 'email': 'notanemail', 'password': 'Pass1234'
}), 400)

ha = {'Authorization': f'Bearer {ta}'}
hb = {'Authorization': f'Bearer {tb}'}

# /me endpoint
chk('GET /api/auth/me', requests.get(f'{BASE}/api/auth/me', headers=ha), 200)
chk('GET /api/auth/me (no token) -> 401', requests.get(f'{BASE}/api/auth/me'), 401)

# Projects
r = chk('Create project', requests.post(f'{BASE}/api/projects', json={'name': 'Proj' + suffix}, headers=ha), 201)
pid = r.json().get('project', {}).get('id', '')

chk('Add guest as project member', requests.post(
    f'{BASE}/api/projects/{pid}/members', json={'user_id': ub, 'role': 'member'}, headers=ha
), 201)

chk('Guest can GET project (read)', requests.get(f'{BASE}/api/projects/{pid}', headers=hb), 200)
chk('Guest update project -> 403', requests.put(
    f'{BASE}/api/projects/{pid}', json={'description': 'hacked'}, headers=hb
), 403)

# Tasks
r = chk('Create task', requests.post(f'{BASE}/api/tasks', json={'title': 'T1', 'project_id': pid}, headers=ha), 201)
tid = r.json().get('task', {}).get('id', '')

chk('Guest can GET tasks (read)', requests.get(f'{BASE}/api/tasks?project_id={pid}', headers=hb), 200)
chk('Guest update task status -> 403', requests.patch(
    f'{BASE}/api/tasks/{tid}/status', json={'status': 'done'}, headers=hb
), 403)
chk('Member update task status -> 200', requests.patch(
    f'{BASE}/api/tasks/{tid}/status', json={'status': 'in_progress'}, headers=ha
), 200)

# Pagination
r = chk('GET projects paginated', requests.get(f'{BASE}/api/projects?page=1&per_page=5', headers=ha), 200)
body = r.json()
has_pagination = all(k in body for k in ('pages', 'per_page', 'page', 'total'))
results.append(('Pagination fields in response', '-', '-', 'PASS' if has_pagination else 'FAIL', str(body.keys())))

print()
for label, got, exp, status, body in results:
    line = f'  [{status}] {label}'
    if got != '-':
        line += f': HTTP {got} (expected {exp})'
    if status == 'FAIL':
        line += f'\n         -> {body}'
    print(line)
