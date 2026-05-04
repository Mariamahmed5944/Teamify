import pathlib

p = pathlib.Path("migrations/versions/f3ef3d3b5fae_add_account_status_github_id_disputes_.py")
c = p.read_text("utf-8")

OLD = "batch_op.add_column(sa.Column('account_status', sa.String(length=20), nullable=False))"
NEW = "batch_op.add_column(sa.Column('account_status', sa.String(length=20), nullable=False, server_default='approved'))"

if OLD in c:
    c = c.replace(OLD, NEW, 1)
    p.write_text(c, "utf-8")
    print("Patched OK")
else:
    print("Pattern not found. Printing relevant lines:")
    for i, line in enumerate(c.splitlines(), 1):
        if "account_status" in line:
            print(f"  {i}: {line}")
