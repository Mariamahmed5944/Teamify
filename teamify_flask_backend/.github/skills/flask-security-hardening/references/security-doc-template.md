# Security Documentation Template

Drop the sections below into `docs/SECURITY.md`.

---

## Hashing vs. Encryption

Both turn data into unreadable bytes, but they solve **opposite** problems and are **not interchangeable**.

| Property | Hashing (SHA-256) | Encryption (Fernet / AES) |
|---|---|---|
| Direction | One-way | Two-way (with the key) |
| Goal | Prove data has not changed | Hide data from anyone without the key |
| Output size | Fixed (256 bits) | Proportional to input |
| Key required | No | Yes |
| Reversible | No — collisions are computationally infeasible | Yes — `decrypt(encrypt(x)) == x` |
| Typical use here | File integrity verification, password storage (with bcrypt) | Comment bodies at rest, file bytes at rest |

### Why this system uses both

- **Encryption (Fernet, AES-128-CBC + HMAC)** protects **confidentiality**. If an attacker reads the database or the uploads directory, they see ciphertext only. The key lives in `.env`, never in source control or the database.
- **Hashing (SHA-256)** protects **integrity**. When a user downloads a file, we decrypt it and recompute its SHA-256. If the recomputed hash does not match the one stored at upload time, the file has been tampered with — possibly via direct disk access — and we refuse the download and raise an alert.
- **Bcrypt** (already used for passwords) is a *slow* hash designed to resist brute force; SHA-256 is a *fast* hash appropriate for integrity but **not** for passwords.

In short: encryption asks *"can the right person read this?"*, hashing asks *"is this still the same bytes I saved?"* We need both answers.

---

## Security Architecture

```mermaid
flowchart TD
    Client([Client])
    Login[/POST /api/auth/login/]
    AuthCheck{Credentials valid?}
    Token[Issue JWT]
    LogSuccess[(LoginLog: success)]
    LogFail[(LoginLog: fail)]
    Anomaly{>= 5 fails<br/>from IP in 5 min?}
    AlertTbl[(Alert: brute_force_login)]

    Client --> Login --> AuthCheck
    AuthCheck -- yes --> Token --> LogSuccess
    AuthCheck -- no --> LogFail --> Anomaly
    Anomaly -- yes --> AlertTbl
    Anomaly -- no --> Client

    subgraph "Encrypted Payloads"
        Comment[/POST comment/] --> Fernet1[Fernet.encrypt]
        Fernet1 --> CommentDB[(task_comments<br/>content_encrypted)]
        CommentRead[/GET comment/] --> Fernet2[Fernet.decrypt] --> Client
    end

    subgraph "Encrypted Files"
        Upload[/POST /api/files/] --> Sha1[SHA-256 of plaintext]
        Sha1 --> FernetF1[Fernet.encrypt bytes]
        FernetF1 --> Disk[(UPLOAD_DIR/*.enc)]
        Sha1 --> FileMeta[(file_metadata)]
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
    end
```

---

## Threat Model Summary

| Threat | Mitigation |
|---|---|
| Stolen DB dump reveals message content | Fernet encryption of `content_encrypted` column |
| Stolen disk reveals uploaded files | Fernet encryption of file bytes at rest |
| Tampered file on disk served to user | SHA-256 verify on download → 409 + Alert |
| Brute-force credential attack | Inline anomaly check after each failed login → Alert |
| Lost or rotated key | `MultiFernet` with `FERNET_KEY` + `FERNET_KEY_OLD` |
| Log forgery / privilege escalation in audit view | `/admin/*` endpoints require `role == "admin"` JWT |
