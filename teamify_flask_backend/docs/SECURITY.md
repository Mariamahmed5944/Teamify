# Security Architecture

This document describes the security primitives added to the backend:
audit logging, payload encryption, file integrity verification, and
brute-force anomaly detection.

---

## 1. Hashing vs. Encryption

Both transformations turn data into unreadable bytes, but they answer
**opposite** questions and are **not interchangeable**.

| Property            | Hashing (SHA-256)                 | Encryption (Fernet / AES)               |
|---------------------|-----------------------------------|-----------------------------------------|
| Direction           | One-way                           | Two-way (with the key)                  |
| Goal                | Prove data has not changed        | Hide data from anyone without the key   |
| Output size         | Fixed (256 bits)                  | Proportional to input                   |
| Key required        | No                                | Yes                                     |
| Reversible          | No (collisions infeasible)        | Yes — `decrypt(encrypt(x)) == x`        |
| Used here for       | File integrity, password storage* | Comment bodies and file bytes at rest   |

\* Passwords use **bcrypt**, a deliberately *slow* hash designed to resist
brute force. SHA-256 is a *fast* hash — appropriate for integrity, but
**not** for passwords.

### Why this system uses both

- **Encryption** protects **confidentiality**.
  An attacker who reads the database or the `UPLOAD_DIR` sees only ciphertext.
  The Fernet key lives in the `FERNET_KEY` env var, never in source control
  and never in the database.
- **Hashing** protects **integrity**.
  When a user downloads a file, we decrypt it and recompute its SHA-256.
  If the recomputed hash does not match the one stored at upload time,
  the file has been tampered with — possibly via direct disk access — and
  we refuse the download and raise an `Alert(type='file_integrity_failure')`.
- **Bcrypt** (existing) is a slow password hash; SHA-256 is a fast
  integrity hash. Different jobs, different tools.

In short: **encryption** asks *"can the right person read this?"*,
**hashing** asks *"is this still the same bytes I saved?"* We need both
answers, so we use both primitives.

---

## 2. Components

| Concern                  | Code                                            |
|--------------------------|-------------------------------------------------|
| Fernet key + helpers     | `utils/crypto.py`                               |
| Generate a Fernet key    | `python scripts/generate_fernet_key.py`         |
| Login audit table        | `models/login_log.py`                           |
| Anomaly alert table      | `models/alert.py`                               |
| File metadata + hash     | `models/file_metadata.py`                       |
| Encrypted comment        | `models/task_comment.py`                        |
| Anomaly detector         | `services/anomaly.py`                           |
| Admin endpoints          | `routes/admin.py` (`/admin/logs`, `/admin/alerts`) |
| Encrypted file routes    | `routes/files.py` (`/api/files`)                |
| Encrypted comment routes | `routes/comments.py` (`/api/tasks/<id>/comments`) |
| Login hook               | `routes/auth.py::_record_login_attempt`         |

All admin endpoints are guarded by the existing `@admin_required`
decorator in `middleware/auth.py` (verifies a valid JWT **and** that
`user.role == "admin"`).

---

## 3. Login Flow + Logging + Anomaly Detection

1. `POST /api/auth/login` is called.
2. Whether the credentials match or not, a row is appended to
   `login_logs` with `status`, `ip_address` (`request.remote_addr`),
   and `device_info` (User-Agent, truncated to 512 chars).
3. On failure, `services.anomaly.check_login_anomalies(ip)` is called
   inline. It counts failed attempts from that IP in the last 5
   minutes; if there are **≥ 5**, it inserts an unresolved
   `Alert(type='brute_force_login')` — but only if no such unresolved
   alert already exists for that IP within the same window
   (idempotent).
4. Admins fetch alerts via `GET /admin/alerts` and resolve them via
   `PATCH /admin/alerts/<id>/resolve`.

The same detector is exported as `scan_recent_failures()` and is safe
to call from the existing APScheduler job in `services/scheduler.py`
if periodic scanning is desired.

---

## 4. Encrypted Comments

`models/task_comment.py` stores `content_encrypted: TEXT`. The
`TaskComment.content` Python property transparently encrypts on
assignment (`@content.setter`) and decrypts on access (`@property`).
Serializers always go through `to_dict()`, which calls the property —
the underlying ciphertext column is never exposed.

---

## 5. Encrypted File Upload + Integrity Verification

### Upload (`POST /api/files`)

1. Validate MIME (allowlist) and size (≤ 10 MB).
2. **Compute `SHA-256(plaintext)` first** — this hash is the integrity anchor.
3. Encrypt the bytes with Fernet.
4. Write to `UPLOAD_DIR/<uuid4>.enc` using
   `os.open(..., O_WRONLY|O_CREAT|O_EXCL, 0o600)` so the path is
   server-generated, not client-controlled, and existing files are never
   clobbered.
5. Persist a `FileMetadata` row containing `encrypted_path` **and**
   `sha256_hash`.

### Download (`GET /api/files/<id>`)

1. Verify the caller owns the file or is an admin.
2. Read the on-disk ciphertext, decrypt with Fernet.
3. Recompute SHA-256 of the plaintext and compare with the stored hash
   using `hmac.compare_digest` (constant-time).
4. **Mismatch ⇒ HTTP 409** and an `Alert(type='file_integrity_failure')`.
   The file is **not** returned.
5. Match ⇒ stream the plaintext via `send_file` with the original
   filename and MIME.

---

## 6. Key Rotation

Implemented via `cryptography.fernet.MultiFernet`.

1. Generate a new key: `python scripts/generate_fernet_key.py`.
2. In `.env`, set `FERNET_KEY_OLD = <current key>` and
   `FERNET_KEY = <new key>`. Restart the app.
3. New writes use the new key; old ciphertexts still decrypt.
4. Optionally migrate existing rows in a one-off script using
   `MultiFernet(...).rotate(token)`.
5. When migration is complete, unset `FERNET_KEY_OLD`.

---

## 7. Threat Model Summary

| Threat                                            | Mitigation                                             |
|---------------------------------------------------|--------------------------------------------------------|
| Stolen DB dump reveals message content            | Fernet encryption of `content_encrypted` column        |
| Stolen disk reveals uploaded files                | Fernet encryption of file bytes at rest                |
| Tampered file on disk served to user              | SHA-256 verify on download → 409 + Alert               |
| Brute-force credential attack                     | Inline anomaly check after each failed login → Alert   |
| Lost or rotated key                               | `MultiFernet` with `FERNET_KEY` + `FERNET_KEY_OLD`     |
| Privilege escalation in audit view                | `/admin/*` endpoints require `role == "admin"` JWT     |
| Path traversal / file clobber on upload           | Server-generated UUID filename + `O_EXCL` open         |
| Timing attack on hash comparison                  | `hmac.compare_digest`                                  |

---

## 8. Architecture Diagram

```mermaid
flowchart TD
    Client([Client])
    Login[/POST /api/auth/login/]
    AuthCheck{Credentials valid?}
    Token[Issue JWT]
    LogSuccess[(LoginLog: success)]
    LogFail[(LoginLog: fail)]
    Anomaly{>= 5 fails<br/>from IP in 5 min?}
    AlertTbl[(Alert)]

    Client --> Login --> AuthCheck
    AuthCheck -- yes --> Token --> LogSuccess
    AuthCheck -- no --> LogFail --> Anomaly
    Anomaly -- yes --> AlertTbl
    Anomaly -- no --> Client

    subgraph "Encrypted Comments"
        Comment[/POST /api/tasks/:id/comments/] --> Fernet1[Fernet.encrypt]
        Fernet1 --> CommentDB[(task_comments<br/>content_encrypted)]
        CommentRead[/GET /api/tasks/:id/comments/] --> Fernet2[Fernet.decrypt]
        Fernet2 --> Client
    end

    subgraph "Encrypted Files"
        Upload[/POST /api/files/] --> Sha1[SHA-256 plaintext]
        Sha1 --> FernetF1[Fernet.encrypt bytes]
        FernetF1 --> Disk[(UPLOAD_DIR/uuid.enc)]
        Sha1 --> FileMeta[(file_metadata<br/>sha256_hash)]
        Download[/GET /api/files/:id/] --> ReadDisk[(Read .enc)]
        ReadDisk --> FernetF2[Fernet.decrypt]
        FernetF2 --> Sha2[Recompute SHA-256]
        Sha2 --> Verify{Hash matches?}
        Verify -- yes --> Client
        Verify -- no --> AlertTbl
    end

    subgraph "Admin"
        Admin([Admin]) --> AdminLogs[/GET /admin/logs/] --> LogSuccess
        AdminLogs --> LogFail
        Admin --> AdminAlerts[/GET /admin/alerts/] --> AlertTbl
        Admin --> Resolve[/PATCH /admin/alerts/:id/resolve/] --> AlertTbl
    end
```

---

## 9. Operational Checklist

- [ ] `FERNET_KEY` is set in every environment. Missing key fails fast at startup.
- [ ] `UPLOAD_DIR` is on durable storage and excluded from version control.
- [ ] Database migration applied (`flask db migrate && flask db upgrade`)
      so the new tables exist: `login_logs`, `alerts`, `file_metadata`,
      `task_comments`. (Dev environments using `db.create_all()` get
      these automatically on first boot.)
- [ ] Admin users exist (`role='admin'`) to access `/admin/logs` and
      `/admin/alerts`.
- [ ] Backups encrypt the database and uploads at rest as well — defence in depth.
