"""
Export script — run from the Profiles&AI Rating directory:

    cd "ml_models/Profiles&AI Rating"
    python save_model.py

Trains TeamifyModel from teamify_dataset.csv and saves teamify_model.pkl
using joblib (pandas-version-independent serialisation).
"""
import os, sys, json
from pathlib import Path

# Allow import from this directory regardless of cwd
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

import numpy as np
import pandas as pd
import joblib

from teamify_model import TeamifyModel

# ── Load and validate dataset ──────────────────────────────────────────────
csv_path = HERE / "teamify_dataset.csv"
if not csv_path.exists():
    raise FileNotFoundError(f"Dataset not found: {csv_path}")

df = pd.read_csv(csv_path)
print(f"Dataset loaded: {df.shape[0]} rows × {df.shape[1]} columns")

required = [
    "tasks_assigned", "tasks_completed", "overdue_tasks",
    "final_rating", "skill_match_score", "avg_rating",
    "quality_score", "teamwork_score", "attendance_rate",
    "availability_score", "project_similarity",
]
missing_cols = [c for c in required if c not in df.columns]
if missing_cols:
    raise ValueError(f"Dataset is missing columns: {missing_cols}")

# Convert any string columns to numeric (safety net)
for col in required:
    df[col] = pd.to_numeric(df[col], errors="coerce")
df.dropna(subset=required, inplace=True)
print(f"After cleaning: {df.shape[0]} rows")

# ── Train ──────────────────────────────────────────────────────────────────
print("Training TeamifyModel …")
model = TeamifyModel(df)

# Quick self-check
sample = {
    "skill_match_score": 0.75, "avg_rating": 4.1, "tasks_assigned": 15,
    "tasks_completed": 12, "overdue_tasks": 1, "quality_score": 3.9,
    "teamwork_score": 4.2, "attendance_rate": 0.93, "availability_score": 0.68,
}
result = model.predict_rating(sample)
assert isinstance(result["predicted_rating"], float), "predict_rating must return a float"
print(f"Self-check passed — sample rating: {result['predicted_rating']} ({result['performance_label']})")

# ── Save ───────────────────────────────────────────────────────────────────
pkl_path = HERE / "teamify_model.pkl"
joblib.dump(model, pkl_path, compress=3)
print(f"Saved: {pkl_path}  ({pkl_path.stat().st_size:,} bytes)")

# Write export metadata
meta = {
    "python":      sys.version,
    "pandas":      pd.__version__,
    "numpy":       np.__version__,
    "sklearn":     __import__("sklearn").__version__,
    "joblib":      joblib.__version__,
    "rows_trained": int(df.shape[0]),
    "feature_cols": model.feature_cols,
}
meta_path = HERE / "export_meta.json"
meta_path.write_text(json.dumps(meta, indent=2))
print(f"Metadata: {meta_path}")
print("Done.")
