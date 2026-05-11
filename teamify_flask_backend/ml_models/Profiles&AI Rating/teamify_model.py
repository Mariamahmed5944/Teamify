"""
TeamifyModel
============
Profile rating + teammate recommendation model.

Stores only sklearn estimators and numpy arrays — never a pandas DataFrame —
so the joblib pickle loads cleanly across any pandas version.

Training
--------
GradientBoostingRegressor on 9 profile features → final_rating (1-5).
MinMaxScaler normalises features before feeding the regressor.
KMeans (k=4) clusters users into performance tiers for recommendations.
Cosine similarity on normalised match vectors drives teammate ranking.

Notebook reference: ml_models/data/Profiles & AI Rating System.ipynb
  MAE  : 0.0282
  R²   : 0.9959
"""
from __future__ import annotations

import numpy as np

FEATURE_COLS = [
    "skill_match_score",    # skill fit (0-1)
    "avg_rating",           # historical rating
    "tasks_assigned",       # workload / experience proxy
    "completion_rate",      # reliability (0-1, derived)
    "overdue_rate",         # punctuality penalty (0-1, derived)
    "quality_score",        # work quality
    "teamwork_score",       # collaboration score
    "attendance_rate",      # commitment (0-1)
    "availability_score",   # future availability (0-1)
]

MATCH_COLS = FEATURE_COLS + ["project_similarity"]

CLUSTER_LABELS = {
    0: "High Performer",
    1: "Consistent Worker",
    2: "Developing",
    3: "Struggling",
}


class TeamifyModel:
    """
    Trained rating predictor + cosine-similarity teammate recommender.

    Public API
    ----------
    predict_rating(user_data: dict) -> dict
        Keys in: FEATURE_COLS (completion_rate / overdue_rate derived if absent).
        Returns: {"predicted_rating": float, "performance_label": str}

    recommend_team(user_vector: dict, top_n=5) -> list[dict]
        Keys in: MATCH_COLS.
        Returns list of {candidate_index, similarity, cluster}.
    """

    def __init__(self, df=None):
        self.feature_cols = FEATURE_COLS
        self.match_cols   = MATCH_COLS

        # serialisation-safe attributes (populated by _train or joblib.load)
        self.scaler       = None   # MinMaxScaler for rating model
        self.rating_model = None   # GradientBoostingRegressor
        self.match_scaler = None   # MinMaxScaler for similarity space
        self.X_match      = None   # (n_users, len(MATCH_COLS)) numpy array
        self.kmeans       = None   # KMeans cluster assignments
        self._cluster_map = CLUSTER_LABELS   # int → label dict

        if df is not None:
            self._train(df)

    # ── Training ──────────────────────────────────────────────────────────────

    def _train(self, df) -> None:
        """Train all components; df must contain columns used in the notebook."""
        from sklearn.preprocessing import MinMaxScaler
        from sklearn.ensemble import GradientBoostingRegressor
        from sklearn.cluster import KMeans

        df = df.copy()

        # Derive completion_rate / overdue_rate exactly as the notebook does
        assigned = df["tasks_assigned"].replace(0, np.nan)
        df["completion_rate"] = (df["tasks_completed"] / assigned).fillna(0).clip(0, 1)
        df["overdue_rate"]    = (df["overdue_tasks"]   / assigned).fillna(0).clip(0, 1)

        # ── Rating model ──────────────────────────────────────────────────────
        X_raw = df[self.feature_cols].values.astype(float)
        y     = df["final_rating"].values.astype(float)

        self.scaler = MinMaxScaler()
        X_scaled    = self.scaler.fit_transform(X_raw)

        self.rating_model = GradientBoostingRegressor(
            n_estimators=200,
            learning_rate=0.08,
            max_depth=4,
            random_state=42,
        )
        self.rating_model.fit(X_scaled, y)

        # ── Cosine-similarity space ───────────────────────────────────────────
        X_match_raw      = df[self.match_cols].values.astype(float)
        self.match_scaler = MinMaxScaler()
        self.X_match      = self.match_scaler.fit_transform(X_match_raw)

        # ── Performance-tier clustering ───────────────────────────────────────
        self.kmeans = KMeans(n_clusters=4, random_state=42, n_init=10)
        self.kmeans.fit(self.X_match)

    # ── Inference ─────────────────────────────────────────────────────────────

    def predict_rating(self, user_data: dict) -> dict:
        """
        Predict a performance rating for one user.

        Parameters
        ----------
        user_data : dict
            Keys: FEATURE_COLS.  completion_rate and overdue_rate are derived
            automatically from tasks_completed/tasks_assigned/overdue_tasks
            when not supplied directly.

        Returns
        -------
        dict  {"predicted_rating": float 1-5, "performance_label": str}
        """
        if self.rating_model is None or self.scaler is None:
            return {"predicted_rating": 3.0, "performance_label": "Good"}

        data = dict(user_data)

        # Auto-derive rates if caller supplied raw task counts
        if "completion_rate" not in data:
            assigned  = float(data.get("tasks_assigned", 1) or 1)
            completed = float(data.get("tasks_completed", 0) or 0)
            data["completion_rate"] = min(completed / max(assigned, 1), 1.0)
        if "overdue_rate" not in data:
            assigned = float(data.get("tasks_assigned", 1) or 1)
            overdue  = float(data.get("overdue_tasks", 0)  or 0)
            data["overdue_rate"] = min(overdue / max(assigned, 1), 1.0)

        row        = np.array([[float(data.get(col, 0)) for col in self.feature_cols]])
        row_scaled = self.scaler.transform(row)
        rating     = float(self.rating_model.predict(row_scaled)[0])
        rating     = round(float(np.clip(rating, 1.0, 5.0)), 2)

        if rating >= 4.0:
            label = "Excellent"
        elif rating >= 3.0:
            label = "Good"
        elif rating >= 2.0:
            label = "Needs Improvement"
        else:
            label = "Poor"

        return {"predicted_rating": rating, "performance_label": label}

    def recommend_team(self, user_vector: dict, top_n: int = 5) -> list:
        """
        Return top_n most similar users by cosine similarity.

        Parameters
        ----------
        user_vector : dict  keys: MATCH_COLS
        top_n       : int

        Returns
        -------
        list of dicts: {candidate_index, similarity, cluster}
        """
        if self.X_match is None or self.match_scaler is None:
            return []

        from sklearn.metrics.pairwise import cosine_similarity as cos_sim

        row        = np.array([[float(user_vector.get(col, 0)) for col in self.match_cols]])
        row_scaled = self.match_scaler.transform(row)
        sims       = cos_sim(row_scaled, self.X_match)[0]

        top_indices = np.argsort(sims)[::-1][:top_n]
        results = []
        for idx in top_indices:
            cluster_id = int(self.kmeans.labels_[idx]) if self.kmeans is not None else -1
            results.append({
                "candidate_index": int(idx),
                "similarity":      round(float(sims[idx]), 4),
                "cluster":         self._cluster_map.get(cluster_id, "Unknown"),
            })
        return results
