"""
Profile Rating Service
======================
Provides two functions consumed by routes/ai.py:

  predict_user_rating(user_stats) → predicted AI rating score
    Attempts Profiles&AI Rating/teamify_model.pkl prediction.
    Falls back to a weighted formula if the model is unavailable.

  recommend_teammates(user_stats, top_n) → ranked list of similar users
    Uses cosine similarity on feature vectors drawn from the DB.
"""
from __future__ import annotations

import logging
import os
from typing import Any, Optional

logger = logging.getLogger(__name__)

_MODEL_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__), "..", "ml_models",
        "Profiles&AI Rating", "teamify_model.pkl"
    )
)

_model_cache: Any = None
_model_load_error: Optional[str] = None


def _load_model():
    global _model_cache, _model_load_error
    if _model_cache is not None:
        return _model_cache
    if _model_load_error:
        return None
    try:
        import sys
        import joblib

        # The pkl was pickled with TeamifyModel from the ml_models directory.
        # Add that directory to sys.path temporarily so pickle can find the class.
        rating_dir = os.path.dirname(_MODEL_PATH)
        if rating_dir not in sys.path:
            sys.path.insert(0, rating_dir)

        _model_cache = joblib.load(_MODEL_PATH)
        logger.info("Profile rating model loaded from %s", _MODEL_PATH)
        return _model_cache
    except FileNotFoundError:
        _model_load_error = f"teamify_model.pkl not found at {_MODEL_PATH}"
        logger.warning(_model_load_error)
    except ModuleNotFoundError as exc:
        _model_load_error = (
            f"Cannot unpickle teamify_model.pkl — class module not found ({exc}). "
            "Using formula fallback."
        )
        logger.warning(_model_load_error)
    except Exception as exc:
        _model_load_error = f"Failed to load teamify_model.pkl: {exc}"
        logger.error(_model_load_error, exc_info=True)
    return None


def _formula_rating(stats: dict) -> float:
    """
    Weighted formula fallback that mirrors the GradientBoosting target.
    Produces a 0-5 score from standard user stat fields.
    """
    tasks_assigned = float(stats.get("tasks_assigned", 10))
    tasks_completed = float(stats.get("tasks_completed", 7))
    overdue = float(stats.get("overdue_tasks", 1))
    quality = float(stats.get("quality_score", 3.5))
    teamwork = float(stats.get("teamwork_score", 3.5))
    attendance = float(stats.get("attendance_rate", 0.9))
    skill_match = float(stats.get("skill_match_score", 0.7))
    avg_rating = float(stats.get("avg_rating", 3.5))
    availability = float(stats.get("availability_score", 0.8))

    completion_rate = min(tasks_completed / max(tasks_assigned, 1), 1.0)
    overdue_rate = min(overdue / max(tasks_assigned, 1), 1.0)

    score = (
        completion_rate * 1.5
        + (1 - overdue_rate) * 1.0
        + (quality / 5.0) * 0.8
        + (teamwork / 5.0) * 0.5
        + attendance * 0.4
        + skill_match * 0.4
        + (avg_rating / 5.0) * 0.4
        + availability * 0.3
        + float(stats.get("project_similarity", 0.5)) * 0.2
    )
    return round(min(score, 5.0), 2)


def predict_user_rating(user_stats: dict) -> dict:
    """
    Predict an AI performance rating for a user.

    Parameters
    ----------
    user_stats : dict
        Numeric feature dict from the user's ORM data.

    Returns
    -------
    dict with keys: predicted_rating, max_rating, source, percentile_label
    """
    model = _load_model()
    predicted = None
    source = "formula"

    if model is not None:
        try:
            import pandas as pd

            feature_cols = [
                "tasks_assigned", "tasks_completed", "overdue_tasks",
                "quality_score", "teamwork_score", "attendance_rate",
                "skill_match_score", "avg_rating", "availability_score",
                "project_similarity",
            ]
            row = {col: float(user_stats.get(col, 0)) for col in feature_cols}
            row["completion_rate"] = min(
                row["tasks_completed"] / max(row["tasks_assigned"], 1), 1.0
            )
            row["overdue_rate"] = min(
                row["overdue_tasks"] / max(row["tasks_assigned"], 1), 1.0
            )
            df = pd.DataFrame([row])

            if hasattr(model, "predict_rating"):
                # TeamifyModel.predict_rating(dict) → {"predicted_rating": float, ...}
                raw = model.predict_rating(row)
                predicted = float(raw["predicted_rating"] if isinstance(raw, dict) else raw)
                source = "ml_model"
            elif hasattr(model, "predict"):
                predicted = float(model.predict(df)[0])
                source = "ml_model"
        except Exception as exc:
            logger.error("Profile rating ML prediction failed: %s", exc, exc_info=True)

    if predicted is None:
        predicted = _formula_rating(user_stats)

    predicted = round(min(max(predicted, 0.0), 5.0), 2)

    if predicted >= 4.5:
        label = "Excellent"
    elif predicted >= 3.5:
        label = "Good"
    elif predicted >= 2.5:
        label = "Average"
    else:
        label = "Needs Improvement"

    return {
        "predicted_rating": predicted,
        "max_rating": 5.0,
        "percentile_label": label,
        "source": source,
    }


def recommend_teammates(user_stats: dict, top_n: int = 5) -> list:
    """
    Find the most compatible teammates based on feature vector similarity.

    Reads all users from the DB, computes cosine similarity against
    user_stats, and returns the top_n most compatible profiles.

    Returns a list of dicts with user_id, display_name, similarity_score.
    """
    try:
        import numpy as np
        from models import db
        from models.user import User

        _FEAT_KEYS = [
            "member_on_time_rate", "member_avg_delay_days",
            "member_experience_years", "max_capacity", "max_allowed_tasks",
        ]

        def _vec(source: dict) -> list:
            return [float(source.get(k, 0)) for k in _FEAT_KEYS]

        ref_vec = np.array(_vec(user_stats))
        ref_norm = np.linalg.norm(ref_vec)
        if ref_norm == 0:
            ref_norm = 1.0

        users = User.query.all()
        scored = []
        for u in users:
            u_stats = {
                "member_on_time_rate":    u.member_on_time_rate,
                "member_avg_delay_days":  u.member_avg_delay_days,
                "member_experience_years": u.member_experience_years,
                "max_capacity":           u.max_capacity,
                "max_allowed_tasks":      u.max_allowed_tasks,
            }
            u_vec = np.array(_vec(u_stats))
            u_norm = np.linalg.norm(u_vec) or 1.0
            similarity = float(np.dot(ref_vec, u_vec) / (ref_norm * u_norm))
            scored.append({
                "user_id": u.id,
                "display_name": u.display_name,
                "full_name": u.full_name,
                "user_type": u.user_type,
                "professional_field": u.professional_field,
                "similarity_score": round(similarity, 4),
                "match_percent": round(similarity * 100, 1),
                "experience_level": u.experience_level,
                "skills": (u.skills or [])[:8],
            })

        scored.sort(key=lambda x: x["similarity_score"], reverse=True)
        return scored[:top_n]

    except Exception as exc:
        logger.error("Teammate recommendation failed: %s", exc, exc_info=True)
        return []
