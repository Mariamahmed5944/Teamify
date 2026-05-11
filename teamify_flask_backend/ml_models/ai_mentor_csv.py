"""
ai_mentor_csv.py
Teamify AI Mentor — Full model that reads from CSV files.
Run: python ai_mentor_csv.py
"""

import csv
import os
import json
from datetime import datetime
from collections import defaultdict

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# ─────────────────────────────────────────────────────────────
#  CSV loaders
# ─────────────────────────────────────────────────────────────

def _load(filename):
    path = os.path.join(DATA_DIR, filename)
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_all():
    """Load every CSV into memory and group by user_id."""
    users        = {u["user_id"]: u for u in _load("users.csv")}
    skills_raw   = _load("skills.csv")
    projects_raw = _load("projects.csv")
    perf_raw     = _load("performance.csv")
    feedback_raw = _load("feedback.csv")
    courses      = {c["course_id"]: c for c in _load("courses.csv")}
    uc_raw       = _load("user_courses.csv")

    skills_by_user   = defaultdict(list)
    projects_by_user = defaultdict(list)
    perf_by_user     = defaultdict(list)
    feedback_by_user = defaultdict(list)
    courses_by_user  = defaultdict(list)

    for r in skills_raw:
        skills_by_user[r["user_id"]].append(r)
    for r in projects_raw:
        projects_by_user[r["user_id"]].append(r)
    for r in perf_raw:
        perf_by_user[r["user_id"]].append(r)
    for r in feedback_raw:
        feedback_by_user[r["user_id"]].append(r)
    for r in uc_raw:
        if r["completed"] == "True":
            c = courses.get(r["course_id"])
            if c:
                courses_by_user[r["user_id"]].append(c)

    return (users, skills_by_user, projects_by_user,
            perf_by_user, feedback_by_user, courses_by_user, courses)


# ─────────────────────────────────────────────────────────────
#  Layer 1 — Rule-based scoring
# ─────────────────────────────────────────────────────────────

THRESHOLDS = {
    "commitment": {"warn": 75, "danger": 60},
    "teamwork":   {"warn": 70, "danger": 55},
    "quality":    {"warn": 75, "danger": 58},
}

ROLE_REQUIREMENTS = {
    "Junior Developer":    {"skills": ["Python","Git","SQL","HTML/CSS","REST APIs"],         "min_prof": 2},
    "Mid-level Developer": {"skills": ["React","FastAPI","Docker","TypeScript","PostgreSQL","Unit Testing"], "min_prof": 3},
    "Senior Developer":    {"skills": ["System Design","AWS","GraphQL","CI/CD","Code Review","Microservices"], "min_prof": 3},
    "Tech Lead":           {"skills": ["Architecture","Team Management","OKRs","Product Thinking","Stakeholder Communication"], "min_prof": 3},
}

LEVEL_NEXT = {
    "Junior Developer":    "Mid-level Developer",
    "Mid-level Developer": "Senior Developer",
    "Senior Developer":    "Tech Lead",
    "Tech Lead":           "Tech Lead",
}

SKILL_DEMAND = {
    "System Design":0.95,"Python":0.92,"AWS":0.90,"Docker":0.88,
    "React":0.87,"TypeScript":0.85,"SQL":0.82,"GraphQL":0.80,
    "REST APIs":0.80,"FastAPI":0.78,"PostgreSQL":0.75,"CI/CD":0.88,
    "Git":0.70,"Microservices":0.93,"Unit Testing":0.78,
}


def _avg_performance(perf_rows):
    """Average commitment/teamwork/quality across all recorded rows."""
    if not perf_rows:
        return {"commitment": 0, "teamwork": 0, "quality": 0}
    keys = ["commitment", "teamwork", "quality"]
    totals = {k: sum(float(r[k]) for r in perf_rows) for k in keys}
    n = len(perf_rows)
    return {k: round(totals[k] / n, 1) for k in keys}


def compute_career_score(skills, perf, projects, completed_courses,
                          sentiment_score=0.5):
    # skill mastery
    if skills:
        skill_score = sum(int(s["proficiency"]) for s in skills) / (len(skills) * 5) * 100
    else:
        skill_score = 0.0

    # performance average
    perf_score = (perf["commitment"] + perf["teamwork"] + perf["quality"]) / 3

    # project completion rate
    done = sum(1 for p in projects if p["status"] == "completed")
    proj_score = (done / max(len(projects), 1)) * 100

    # course completions (cap at 5)
    course_score = min(len(completed_courses) / 5 * 100, 100)

    # sentiment (from Layer 2)
    sent_score = sentiment_score * 100

    total = (skill_score  * 0.30 +
             perf_score   * 0.25 +
             proj_score   * 0.20 +
             course_score * 0.15 +
             sent_score   * 0.10)

    level = ("Junior Developer"    if total < 26 else
             "Mid-level Developer" if total < 51 else
             "Senior Developer"    if total < 76 else
             "Tech Lead")

    return {
        "total_score": round(total, 1),
        "level": level,
        "breakdown": {
            "skill_mastery":   round(skill_score,   1),
            "performance_avg": round(perf_score,    1),
            "project_rate":    round(proj_score,    1),
            "course_score":    round(course_score,  1),
            "sentiment_score": round(sent_score,    1),
        }
    }


def detect_weaknesses(perf):
    results = []
    for metric, bounds in THRESHOLDS.items():
        score = perf[metric]
        if score < bounds["danger"]:
            sev = "high"
        elif score < bounds["warn"]:
            sev = "medium"
        else:
            continue
        results.append({
            "area": metric, "score": score, "severity": sev,
            "message": (f"{metric.capitalize()} is {score}/100 — "
                        f"below threshold of {bounds['warn']}.")
        })
    return sorted(results, key=lambda x: 0 if x["severity"] == "high" else 1)


def detect_strengths(perf, all_perfs):
    if not all_perfs:
        return []
    strengths = []
    for m in ["commitment", "teamwork", "quality"]:
        avg = sum(p[m] for p in all_perfs) / len(all_perfs)
        diff = perf[m] - avg
        if diff >= 8:
            strengths.append({
                "area": m, "score": perf[m],
                "peer_average": round(avg, 1),
                "vs_peer": f"+{round(diff, 1)} above average"
            })
    return strengths


def detect_skill_gaps(skills, career_level):
    target = LEVEL_NEXT.get(career_level, "Senior Developer")
    req    = ROLE_REQUIREMENTS.get(target, {})
    required   = set(req.get("skills", []))
    min_prof   = req.get("min_prof", 3)
    owned = {s["skill_name"] for s in skills if int(s["proficiency"]) >= min_prof}
    missing = sorted(required - owned,
                     key=lambda s: SKILL_DEMAND.get(s, 0.5), reverse=True)
    gap_pct = round(len(missing) / max(len(required), 1) * 100, 1)
    return {
        "target_role":     target,
        "required_skills": list(required),
        "owned_skills":    list(owned & required),
        "missing_skills":  missing,
        "gap_pct":         gap_pct,
        "priority_skill":  missing[0] if missing else None,
    }


# ─────────────────────────────────────────────────────────────
#  Layer 2 — Simple sentiment (no HuggingFace needed)
# ─────────────────────────────────────────────────────────────

POS_WORDS = {"great","excellent","good","reliable","delivers","communicates",
             "helpful","strong","clean","positive","proactive","responsive"}
NEG_WORDS = {"poor","missing","needs","improvement","incomplete","rushed",
             "lacks","weak","inconsistent","issues","problems","delay"}


def analyse_feedback(feedback_rows):
    if not feedback_rows:
        return {"avg_sentiment_score": 0.5, "sentiment_label": "neutral",
                "top_keywords": [], "feedback_count": 0}

    scores = []
    for row in feedback_rows:
        # Use pre-computed sentiment from CSV when available
        if row.get("sentiment") == "positive":
            scores.append(0.85)
        elif row.get("sentiment") == "negative":
            scores.append(0.25)
        else:
            text = row.get("feedback_text", "").lower()
            pos  = sum(1 for w in POS_WORDS if w in text)
            neg  = sum(1 for w in NEG_WORDS if w in text)
            total = pos + neg
            scores.append((pos / total) if total > 0 else 0.5)

    avg   = round(sum(scores) / len(scores), 3)
    label = "positive" if avg > 0.6 else "negative" if avg < 0.4 else "neutral"

    # extract recurring words
    word_freq = defaultdict(int)
    career_kw = ["delivery","communication","teamwork","code quality",
                 "documentation","testing","reliability","leadership"]
    for row in feedback_rows:
        text = row.get("feedback_text", "").lower()
        for kw in career_kw:
            if kw in text:
                word_freq[kw] += 1
    top_kw = sorted(word_freq, key=word_freq.get, reverse=True)[:4]

    return {
        "avg_sentiment_score": avg,
        "sentiment_label":     label,
        "top_keywords":        top_kw,
        "feedback_count":      len(feedback_rows),
    }


# ─────────────────────────────────────────────────────────────
#  Layer 3 — Report generator (fallback, no API key needed)
# ─────────────────────────────────────────────────────────────

def generate_report(user, scores, weaknesses, strengths, nlp, gaps):
    """Generates the career report. Uses Claude API if key is set,
       otherwise uses the built-in rule-based fallback."""

    api_key = os.getenv("ANTHROPIC_API_KEY", "")

    if api_key:
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=api_key)
            system = (
                "You are an expert AI career mentor for tech freelancers. "
                "Given structured career data, write a concise report with: "
                "## Career Summary (2-3 sentences), "
                "## Strengths (bullet list), "
                "## Areas to Improve (bullet list with one fix each), "
                "## Your Next Step (one specific action). "
                "Use the user's first name. Mention at least 2 scores. Under 250 words."
            )
            first = user["name"].split()[0]
            prompt = f"""
Name: {first} | Level: {user['career_level']} | Target: {gaps['target_role']}
Performance: commitment={scores['breakdown']['performance_avg']:.0f}/100
Career Score: {scores['total_score']}% ({scores['level']})
Weaknesses: {[w['area']+' ('+str(w['score'])+')' for w in weaknesses]}
Strengths: {[s['area']+' ('+str(s['score'])+')' for s in strengths]}
Missing skills: {gaps['missing_skills']}
Feedback: {nlp['sentiment_label']} | Themes: {nlp['top_keywords']}
"""
            r = client.messages.create(
                model="claude-sonnet-4-20250514", max_tokens=400,
                system=system, messages=[{"role":"user","content":prompt}]
            )
            return r.content[0].text
        except Exception as e:
            print(f"  [Layer 3] Claude API error: {e} — using fallback.")

    # ── Fallback report ──
    first  = user["name"].split()[0]
    level  = scores["level"]
    total  = scores["total_score"]
    target = gaps["target_role"]
    pri    = gaps["priority_skill"] or "a key skill"
    s_list = "\n".join(f"- {s['area'].capitalize()}: {s['score']}/100 ({s['vs_peer']})" for s in strengths) or "- Consistent project delivery"
    w_list = "\n".join(f"- {w['area'].capitalize()}: {w['score']}/100 — {w['severity']} priority" for w in weaknesses) or "- Continue monitoring all areas"
    missing = ", ".join(gaps["missing_skills"][:3]) or "N/A"

    return f"""## Career Summary
{first} is currently a {level} with an overall career score of {total}%.
{"Strong collaboration scores reflect reliable team contribution." if total > 55 else "There is meaningful room for growth across several areas."}
The next target role is {target}.

## Strengths
{s_list}

## Areas to Improve
{w_list}
- Skill gaps for {target}: {missing}

## Your Next Step
Prioritise learning **{pri}** — it is the highest-demand missing skill
for the {target} role. Enroll in a structured course this week and
apply it in a real side project to build verifiable experience.
"""


# ─────────────────────────────────────────────────────────────
#  Course recommendation (content-based)
# ─────────────────────────────────────────────────────────────

def recommend_courses(gaps, all_courses, top_n=5):
    missing = set(gaps["missing_skills"])
    recs    = []
    for c in all_courses.values():
        covered = set(c["skills_covered"].split("|"))
        overlap = covered & missing
        if not overlap:
            continue
        gap_match   = len(overlap) / max(len(missing), 1)
        rating_norm = float(c["rating"]) / 5
        demand      = float(c["market_demand"])
        relevance   = gap_match * 0.50 + rating_norm * 0.30 + demand * 0.20
        recs.append({
            "title":     c["title"],
            "platform":  c["platform"],
            "relevance": round(relevance, 3),
            "fills":     list(overlap),
            "rating":    c["rating"],
            "hours":     c["duration_hrs"],
        })
    return sorted(recs, key=lambda x: x["relevance"], reverse=True)[:top_n]


# ─────────────────────────────────────────────────────────────
#  Master pipeline
# ─────────────────────────────────────────────────────────────

def analyse_user(user_id, all_data):
    (users, skills_by_user, projects_by_user,
     perf_by_user, feedback_by_user, courses_by_user, all_courses) = all_data

    user = users.get(user_id)
    if not user:
        return {"error": f"User {user_id} not found"}

    skills    = skills_by_user[user_id]
    projects  = projects_by_user[user_id]
    perf_rows = perf_by_user[user_id]
    fb_rows   = feedback_by_user[user_id]
    done_c    = courses_by_user[user_id]

    # all peers average performance (exclude current user)
    all_perfs = [
        _avg_performance(perf_by_user[uid])
        for uid in users if uid != user_id and perf_by_user[uid]
    ]

    # Layer 1
    perf      = _avg_performance(perf_rows)
    nlp       = analyse_feedback(fb_rows)          # Layer 2 first (need sentiment)
    scores    = compute_career_score(skills, perf, projects, done_c,
                                     nlp["avg_sentiment_score"])
    weaknesses= detect_weaknesses(perf)
    strengths = detect_strengths(perf, all_perfs)
    gaps      = detect_skill_gaps(skills, user["career_level"])

    # Layer 3
    report = generate_report(user, scores, weaknesses, strengths, nlp, gaps)

    # Course recommendations
    course_recs = recommend_courses(gaps, all_courses)

    return {
        "user_id":        user_id,
        "user_name":      user["name"],
        "career_level":   user["career_level"],
        "generated_at":   datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "career_progress": {
            "score":          scores["total_score"],
            "level":          scores["level"],
            "next_milestone": gaps["priority_skill"],
            "breakdown":      scores["breakdown"],
        },
        "weaknesses":       weaknesses,
        "strengths":        strengths,
        "skill_gaps":       gaps,
        "feedback_nlp":     nlp,
        "top_courses":      course_recs,
        "mentor_report":    report,
    }


# ─────────────────────────────────────────────────────────────
#  Run
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Loading CSV data...")
    all_data = load_all()
    users    = all_data[0]

    # Analyse first 3 users as a demo
    sample_ids = list(users.keys())[:3]

    for uid in sample_ids:
        print(f"\n{'='*55}")
        result = analyse_user(uid, all_data)
        print(f"User : {result['user_name']}  ({result['career_level']})")
        print(f"Score: {result['career_progress']['score']}%  →  {result['career_progress']['level']}")
        print(f"Weaknesses : {[w['area'] for w in result['weaknesses']]}")
        print(f"Strengths  : {[s['area'] for s in result['strengths']]}")
        print(f"Skill gaps : {result['skill_gaps']['missing_skills'][:3]}")
        print(f"Top course : {result['top_courses'][0]['title'] if result['top_courses'] else 'N/A'}")
        print(f"\n--- MENTOR REPORT ---")
        print(result["mentor_report"])

    # Save one full result as JSON example
    full = analyse_user(sample_ids[0], all_data)
    out_path = os.path.join(os.path.dirname(__file__), "sample_output.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(full, f, indent=2, ensure_ascii=False)
    print(f"\nFull JSON output saved → sample_output.json")
