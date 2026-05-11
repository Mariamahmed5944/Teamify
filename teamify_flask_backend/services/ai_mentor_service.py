"""
AI Mentor Service
=================
Generates career progression and mentoring reports for a user.

Adapts the ai_mentor_csv.py pipeline from ml_models/ to read live data
from the SQLAlchemy ORM instead of CSV files. The four-layer pipeline:

  Layer 1 — Rule-based career scoring and weakness/strength detection
  Layer 2 — Simple sentiment analysis on feedback text
  Layer 3 — Career report generation (Claude API if key set, else fallback)
  Extra   — Course recommendations based on skill gaps

Also attempts to load Profiles&AI Rating/teamify_model.pkl for a
GradientBoosting-based rating prediction. Falls back to formula if
the model is unavailable.
"""
from __future__ import annotations

import logging
import os
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)

_RATING_MODEL_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__), "..", "ml_models",
        "Profiles&AI Rating", "teamify_model.pkl"
    )
)

_rating_cache: Any = None
_rating_error: Optional[str] = None


def _load_rating_model():
    global _rating_cache, _rating_error
    if _rating_cache is not None:
        return _rating_cache
    if _rating_error:
        return None
    try:
        import joblib
        _rating_cache = joblib.load(_RATING_MODEL_PATH)
        logger.info("Profile rating model loaded from %s", _RATING_MODEL_PATH)
        return _rating_cache
    except FileNotFoundError:
        _rating_error = f"teamify_model.pkl not found at {_RATING_MODEL_PATH}"
        logger.warning(_rating_error)
    except Exception as exc:
        _rating_error = f"Failed to load teamify_model.pkl: {exc}"
        logger.error(_rating_error, exc_info=True)
    return None


# ── Career scoring constants (mirror ai_mentor_csv.py) ────────────────────────

THRESHOLDS = {
    "commitment": {"warn": 75, "danger": 60},
    "teamwork":   {"warn": 70, "danger": 55},
    "quality":    {"warn": 75, "danger": 58},
}

ROLE_REQUIREMENTS = {
    "Junior Developer":    {"skills": ["Python", "Git", "SQL", "HTML/CSS", "REST APIs"],               "min_prof": 2},
    "Mid-level Developer": {"skills": ["React", "FastAPI", "Docker", "TypeScript", "PostgreSQL", "Unit Testing"], "min_prof": 3},
    "Senior Developer":    {"skills": ["System Design", "AWS", "GraphQL", "CI/CD", "Code Review", "Microservices"], "min_prof": 3},
    "Tech Lead":           {"skills": ["Architecture", "Team Management", "OKRs", "Product Thinking", "Stakeholder Communication"], "min_prof": 3},
}

LEVEL_NEXT = {
    "Junior Developer":    "Mid-level Developer",
    "Mid-level Developer": "Senior Developer",
    "Senior Developer":    "Tech Lead",
    "Tech Lead":           "Tech Lead",
}

SKILL_DEMAND = {
    "System Design": 0.95, "Python": 0.92, "AWS": 0.90, "Docker": 0.88,
    "React": 0.87, "TypeScript": 0.85, "SQL": 0.82, "GraphQL": 0.80,
    "REST APIs": 0.80, "FastAPI": 0.78, "PostgreSQL": 0.75, "CI/CD": 0.88,
    "Git": 0.70, "Microservices": 0.93, "Unit Testing": 0.78,
}

COURSE_CATALOG = [
    {"title": "System Design for Developers",  "platform": "Coursera",    "skills_covered": "Microservices|System Design", "rating": "4.8", "duration_hrs": "24", "market_demand": 0.95},
    {"title": "Microservices Architecture",    "platform": "Coursera",    "skills_covered": "AWS|Microservices",           "rating": "4.8", "duration_hrs": "35", "market_demand": 0.93},
    {"title": "AWS Certified Developer",       "platform": "A Cloud Guru","skills_covered": "CI/CD|AWS",                  "rating": "4.7", "duration_hrs": "40", "market_demand": 0.90},
    {"title": "Docker & Kubernetes Mastery",   "platform": "Udemy",       "skills_covered": "CI/CD|Docker",               "rating": "4.6", "duration_hrs": "20", "market_demand": 0.88},
    {"title": "CI/CD with GitHub Actions",     "platform": "A Cloud Guru","skills_covered": "CI/CD",                      "rating": "4.6", "duration_hrs": "15", "market_demand": 0.88},
    {"title": "React - The Complete Guide",    "platform": "Udemy",       "skills_covered": "React|TypeScript",           "rating": "4.7", "duration_hrs": "45", "market_demand": 0.87},
    {"title": "FastAPI Full Course",           "platform": "YouTube",     "skills_covered": "FastAPI|REST APIs",          "rating": "4.5", "duration_hrs": "10", "market_demand": 0.78},
    {"title": "PostgreSQL Performance Tuning", "platform": "Pluralsight", "skills_covered": "PostgreSQL|SQL",             "rating": "4.4", "duration_hrs": "12", "market_demand": 0.75},
    {"title": "Python Testing with pytest",    "platform": "Pragmatic",   "skills_covered": "Unit Testing",               "rating": "4.5", "duration_hrs": "8",  "market_demand": 0.78},
    {"title": "GraphQL in Production",         "platform": "Frontend Masters", "skills_covered": "GraphQL",              "rating": "4.6", "duration_hrs": "6",  "market_demand": 0.80},
]

POS_WORDS = {"great", "excellent", "good", "reliable", "delivers", "communicates",
             "helpful", "strong", "clean", "positive", "proactive", "responsive"}
NEG_WORDS = {"poor", "missing", "needs", "improvement", "incomplete", "rushed",
             "lacks", "weak", "inconsistent", "issues", "problems", "delay"}


# ── Layer 1: Rule-based scoring ────────────────────────────────────────────────

def _compute_career_score(user, tasks, feedback_sentiment: float = 0.5) -> dict:
    skills = user.skills or []
    skill_score = (sum(3 for _ in skills) / max(len(skills) * 5, 1)) * 100 if skills else 0.0

    all_tasks = tasks
    done = [t for t in all_tasks if t.status == "done"]
    proj_score = (len(done) / max(len(all_tasks), 1)) * 100

    on_time = (user.member_on_time_rate or 0.75) * 100
    quality = (user.quality_score if hasattr(user, "quality_score") else 0.75) * 100
    teamwork = (user.teamwork_score if hasattr(user, "teamwork_score") else 0.75) * 100
    perf_score = (on_time + quality + teamwork) / 3

    course_score = 0.0  # no course data in ORM yet
    sent_score = feedback_sentiment * 100

    total = (
        skill_score  * 0.30
        + perf_score * 0.25
        + proj_score * 0.20
        + course_score * 0.15
        + sent_score * 0.10
    )

    level = (
        "Junior Developer"    if total < 26 else
        "Mid-level Developer" if total < 51 else
        "Senior Developer"    if total < 76 else
        "Tech Lead"
    )

    return {
        "total_score": round(total, 1),
        "level": level,
        "breakdown": {
            "skill_mastery":   round(skill_score,  1),
            "performance_avg": round(perf_score,   1),
            "project_rate":    round(proj_score,   1),
            "course_score":    round(course_score, 1),
            "sentiment_score": round(sent_score,   1),
        },
    }


def _detect_weaknesses(user) -> list:
    perf = {
        "commitment": (user.member_on_time_rate or 0.75) * 100,
        "teamwork":   (user.teamwork_score if hasattr(user, "teamwork_score") else 0.75) * 100,
        "quality":    (user.quality_score if hasattr(user, "quality_score") else 0.75) * 100,
    }
    results = []
    for metric, bounds in THRESHOLDS.items():
        score = perf.get(metric, 75.0)
        if score < bounds["danger"]:
            sev = "high"
        elif score < bounds["warn"]:
            sev = "medium"
        else:
            continue
        results.append({
            "area": metric,
            "score": round(score, 1),
            "severity": sev,
            "message": f"{metric.capitalize()} is {score:.1f}/100 — below threshold of {bounds['warn']}.",
        })
    return sorted(results, key=lambda x: 0 if x["severity"] == "high" else 1)


def _detect_strengths(user) -> list:
    perf = {
        "commitment": (user.member_on_time_rate or 0.75) * 100,
        "quality":    (user.quality_score if hasattr(user, "quality_score") else 0.75) * 100,
    }
    strengths = []
    for m, score in perf.items():
        if score >= 85:
            strengths.append({
                "area": m,
                "score": round(score, 1),
                "message": f"{m.capitalize()} is well above average.",
            })
    return strengths


def _detect_skill_gaps(user) -> dict:
    career_level = user.career_level if hasattr(user, "career_level") else (
        user.experience_level or "Junior Developer"
    )
    target = LEVEL_NEXT.get(career_level, "Senior Developer")
    req = ROLE_REQUIREMENTS.get(target, {})
    required = set(req.get("skills", []))
    min_prof = req.get("min_prof", 3)
    user_skills = set(s for s in (user.skills or []))
    owned = user_skills & required
    missing = sorted(required - owned, key=lambda s: SKILL_DEMAND.get(s, 0.5), reverse=True)
    gap_pct = round(len(missing) / max(len(required), 1) * 100, 1)
    return {
        "target_role":     target,
        "required_skills": sorted(required),
        "owned_skills":    sorted(owned),
        "missing_skills":  missing,
        "gap_pct":         gap_pct,
        "priority_skill":  missing[0] if missing else None,
    }


# ── Layer 2: Sentiment analysis ────────────────────────────────────────────────

def _analyse_feedback(feedback_rows) -> dict:
    if not feedback_rows:
        return {"avg_sentiment_score": 0.5, "sentiment_label": "neutral",
                "top_keywords": [], "feedback_count": 0}

    scores = []
    for row in feedback_rows:
        text = (getattr(row, "comment", None) or getattr(row, "text", None) or "").lower()
        sentiment = getattr(row, "sentiment", None)
        if sentiment == "positive":
            scores.append(0.85)
        elif sentiment == "negative":
            scores.append(0.25)
        else:
            pos = sum(1 for w in POS_WORDS if w in text)
            neg = sum(1 for w in NEG_WORDS if w in text)
            total = pos + neg
            scores.append((pos / total) if total > 0 else 0.5)

    avg = round(sum(scores) / len(scores), 3)
    label = "positive" if avg > 0.6 else "negative" if avg < 0.4 else "neutral"

    career_kw = ["delivery", "communication", "teamwork", "code quality",
                 "documentation", "testing", "reliability", "leadership"]
    word_freq: dict = defaultdict(int)
    for row in feedback_rows:
        text = (getattr(row, "comment", None) or getattr(row, "text", None) or "").lower()
        for kw in career_kw:
            if kw in text:
                word_freq[kw] += 1
    top_kw = sorted(word_freq, key=word_freq.get, reverse=True)[:4]

    return {
        "avg_sentiment_score": avg,
        "sentiment_label": label,
        "top_keywords": top_kw,
        "feedback_count": len(feedback_rows),
    }


# ── Layer 3: Report generation ─────────────────────────────────────────────────

def _generate_report(user, scores, weaknesses, strengths, nlp, gaps) -> str:
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    name = user.display_name or (user.full_name or "").split()[0] or "User"

    if api_key:
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=api_key)
            system = (
                "You are an expert AI career mentor for tech freelancers. "
                "Given structured career data, write a concise report with: "
                "## Career Summary (2-3 sentences), ## Strengths (bullet list), "
                "## Areas to Improve (bullet list with one fix each), "
                "## Your Next Step (one specific action). "
                "Use the user's first name. Mention at least 2 scores. Under 250 words."
            )
            prompt = (
                f"Name: {name} | Level: {scores['level']} | Target: {gaps['target_role']}\n"
                f"Career Score: {scores['total_score']}%\n"
                f"Weaknesses: {[w['area'] + ' (' + str(w['score']) + ')' for w in weaknesses]}\n"
                f"Strengths: {[s['area'] + ' (' + str(s['score']) + ')' for s in strengths]}\n"
                f"Missing skills: {gaps['missing_skills']}\n"
                f"Feedback: {nlp['sentiment_label']} | Themes: {nlp['top_keywords']}\n"
            )
            r = client.messages.create(
                model="claude-sonnet-4-20250514", max_tokens=400,
                system=system, messages=[{"role": "user", "content": prompt}]
            )
            return r.content[0].text
        except Exception as e:
            logger.warning("Claude API error in mentor report: %s — using fallback.", e)

    # Built-in fallback report
    total = scores["total_score"]
    target = gaps["target_role"]
    pri = gaps["priority_skill"] or "a key skill"
    s_list = "\n".join(
        f"- {s['area'].capitalize()}: {s['score']}/100"
        for s in strengths
    ) or "- Consistent project delivery"
    w_list = "\n".join(
        f"- {w['area'].capitalize()}: {w['score']}/100 — {w['severity']} priority"
        for w in weaknesses
    ) or "- Continue monitoring all areas"
    missing = ", ".join(gaps["missing_skills"][:3]) or "N/A"

    return (
        f"## Career Summary\n"
        f"{name} is currently a {scores['level']} with an overall career score of {total}%.\n"
        f"{'Strong collaboration scores reflect reliable team contribution.' if total > 55 else 'There is meaningful room for growth across several areas.'}\n"
        f"The next target role is {target}.\n\n"
        f"## Strengths\n{s_list}\n\n"
        f"## Areas to Improve\n{w_list}\n"
        f"- Skill gaps for {target}: {missing}\n\n"
        f"## Your Next Step\n"
        f"Prioritise learning **{pri}** — it is the highest-demand missing skill\n"
        f"for the {target} role. Enroll in a structured course this week and\n"
        f"apply it in a real side project to build verifiable experience.\n"
    )


# ── Course recommendations ─────────────────────────────────────────────────────

def _recommend_courses(gaps, top_n=5) -> list:
    missing = set(gaps["missing_skills"])
    recs = []
    for c in COURSE_CATALOG:
        covered = set(c["skills_covered"].split("|"))
        overlap = covered & missing
        if not overlap:
            continue
        gap_match = len(overlap) / max(len(missing), 1)
        rating_norm = float(c["rating"]) / 5
        demand = float(c["market_demand"])
        relevance = gap_match * 0.50 + rating_norm * 0.30 + demand * 0.20
        recs.append({
            "title": c["title"], "platform": c["platform"],
            "relevance": round(relevance, 3), "fills": sorted(overlap),
            "rating": c["rating"], "hours": c["duration_hrs"],
        })
    return sorted(recs, key=lambda x: x["relevance"], reverse=True)[:top_n]


# ── Public API ─────────────────────────────────────────────────────────────────

def generate_mentor_report(user_id: int) -> dict:
    """
    Generate a full AI career mentor report for a user by reading from the DB.

    Returns the same shape as ai_mentor_csv.py's analyse_user() output.
    """
    from models import db
    from models.user import User
    from models.task import Task
    from models.feedback import Feedback

    user = db.session.get(User, user_id)
    if not user:
        return {"error": f"User {user_id} not found"}

    tasks = Task.query.filter_by(assigned_to=user_id).all()
    feedback_rows = []
    try:
        feedback_rows = Feedback.query.filter_by(reviewee_id=user_id).all()
    except Exception:
        try:
            feedback_rows = Feedback.query.filter_by(recipient_id=user_id).all()
        except Exception:
            feedback_rows = []

    nlp = _analyse_feedback(feedback_rows)
    scores = _compute_career_score(user, tasks, nlp["avg_sentiment_score"])
    weaknesses = _detect_weaknesses(user)
    strengths = _detect_strengths(user)
    gaps = _detect_skill_gaps(user)
    report = _generate_report(user, scores, weaknesses, strengths, nlp, gaps)
    course_recs = _recommend_courses(gaps)

    return {
        "user_id": user_id,
        "user_name": user.display_name,
        "career_level": getattr(user, "career_level", user.experience_level or "Junior Developer"),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "career_progress": {
            "score":          scores["total_score"],
            "level":          scores["level"],
            "next_milestone": gaps["priority_skill"],
            "breakdown":      scores["breakdown"],
        },
        "weaknesses":    weaknesses,
        "strengths":     strengths,
        "skill_gaps":    gaps,
        "feedback_nlp":  nlp,
        "top_courses":   course_recs,
        "mentor_report": report,
    }
