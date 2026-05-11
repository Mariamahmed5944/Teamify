"""
Teamify - AI-Powered Resume Builder
====================================
Production-grade CV generation system with auto-update, notifications, and PDF export.
"""

import json
import math
from datetime import datetime, date
from typing import Optional
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER


# ─────────────────────────────────────────────────────────────────────────────
# DATA MODELS (Simulated DB objects)
# ─────────────────────────────────────────────────────────────────────────────

def make_user(name: str, role: str, email: str) -> dict:
    return {"name": name, "role": role, "email": email}

def make_project(title, description, technologies, user_role, status, rating, start_date, end_date=None) -> dict:
    return {
        "title": title, "description": description,
        "technologies": technologies, "role": user_role,
        "status": status, "rating": rating,
        "start_date": start_date, "end_date": end_date or str(date.today())
    }

def make_task(completed: int, total: int, overdue: int) -> dict:
    return {"completed": completed, "total": total, "overdue": overdue}

def make_metrics(trust_score, consistency_score, teamwork_score, avg_rating) -> dict:
    return {
        "trust_score": trust_score,
        "consistency_score": consistency_score,
        "teamwork_score": teamwork_score,
        "avg_rating": avg_rating
    }

def make_collaboration(messages_sent, comments_written, team_count) -> dict:
    return {
        "messages_sent": messages_sent,
        "comments_written": comments_written,
        "team_count": team_count
    }

def make_activity(activity_count, login_frequency) -> dict:
    return {"activity_count": activity_count, "login_frequency": login_frequency}


# ─────────────────────────────────────────────────────────────────────────────
# 1. FEATURE ENGINEERING
# ─────────────────────────────────────────────────────────────────────────────

def extract_features(user_data: dict) -> dict:
    """
    Extracts all ML-ready features from raw user platform data.
    These features feed every downstream AI generation function.
    """
    projects   = user_data.get("projects", [])
    tasks      = user_data.get("tasks", {})
    metrics    = user_data.get("metrics", {})
    collab     = user_data.get("collaboration", {})
    activity   = user_data.get("activity", {})

    # ── Performance Features ──────────────────────────────────────────────────
    total_tasks     = tasks.get("total", 1)
    completed_tasks = tasks.get("completed", 0)
    overdue_tasks   = tasks.get("overdue", 0)
    completion_rate = round(completed_tasks / max(total_tasks, 1), 2)
    task_efficiency = round((completed_tasks - overdue_tasks) / max(completed_tasks, 1), 2)

    # ── Project Features ──────────────────────────────────────────────────────
    completed_projects   = [p for p in projects if p["status"] == "completed"]
    in_progress_projects = [p for p in projects if p["status"] == "in_progress"]

    # ── Skills Features ───────────────────────────────────────────────────────
    all_techs = []
    for p in projects:
        all_techs.extend(p.get("technologies", []))
    tech_frequency = {}
    for t in all_techs:
        tech_frequency[t] = tech_frequency.get(t, 0) + 1
    # Sort by frequency — most-used skills first
    technical_skills = sorted(tech_frequency, key=lambda x: -tech_frequency[x])

    # ── Collaboration Score (0-100) ───────────────────────────────────────────
    msgs     = collab.get("messages_sent", 0)
    comments = collab.get("comments_written", 0)
    teams    = collab.get("team_count", 0)
    collab_score = round(min(100, (msgs * 0.3 + comments * 0.4 + teams * 5)), 1)

    # ── Impact Score per Project ──────────────────────────────────────────────
    projects_with_impact = []
    for p in projects:
        rating   = p.get("rating", 0)
        duration = _project_duration_days(p)
        impact   = round((rating * 20) + (min(duration, 180) / 180 * 30) + (10 if p["status"] == "completed" else 0), 1)
        projects_with_impact.append({**p, "impact_score": impact, "duration_days": duration})

    return {
        # Performance
        "completion_rate":    completion_rate,
        "avg_rating":         metrics.get("avg_rating", 0),
        "consistency_score":  metrics.get("consistency_score", 0),
        "trust_score":        metrics.get("trust_score", 0),
        "teamwork_score":     metrics.get("teamwork_score", 0),

        # Projects
        "project_count":         len(projects),
        "completed_projects":    len(completed_projects),
        "in_progress_projects":  len(in_progress_projects),
        "projects_with_impact":  projects_with_impact,

        # Tasks
        "tasks_completed": completed_tasks,
        "tasks_overdue":   overdue_tasks,
        "task_efficiency": task_efficiency,

        # Collaboration
        "team_count":        collab.get("team_count", 0),
        "messages_sent":     msgs,
        "comments_written":  comments,
        "collaboration_score": collab_score,

        # Skills
        "technical_skills": technical_skills,

        # Activity
        "activity_count":    activity.get("activity_count", 0),
        "login_frequency":   activity.get("login_frequency", 0),
    }


def _project_duration_days(project: dict) -> int:
    """Calculates project duration in days."""
    try:
        start = datetime.fromisoformat(project["start_date"])
        end   = datetime.fromisoformat(project["end_date"])
        return max((end - start).days, 1)
    except Exception:
        return 30


# ─────────────────────────────────────────────────────────────────────────────
# 2. GENERATE PROFESSIONAL SUMMARY
# ─────────────────────────────────────────────────────────────────────────────

def generate_summary(user: dict, features: dict) -> str:
    """
    Generates an HR-ready professional summary based on performance features.
    Uses rule-based NLG with template selection driven by feature thresholds.
    """
    name  = user["name"]
    role  = user["role"]
    cr    = features["completion_rate"]
    rating = features["avg_rating"]
    proj_count = features["project_count"]
    collab = features["collaboration_score"]
    skills = features["technical_skills"][:4]
    skills_str = ", ".join(skills) if skills else "multiple technologies"

    # ── Performance tier ──────────────────────────────────────────────────────
    if cr >= 0.9 and rating >= 4.5:
        perf_phrase = "an exceptionally high-performing professional with a proven track record of excellence"
    elif cr >= 0.75 and rating >= 3.8:
        perf_phrase = "a results-driven professional with consistent delivery and strong execution"
    else:
        perf_phrase = "a motivated professional with hands-on project experience"

    # ── Collaboration tier ────────────────────────────────────────────────────
    if collab >= 70:
        collab_phrase = "demonstrates outstanding cross-functional collaboration and team leadership"
    elif collab >= 40:
        collab_phrase = "works effectively within teams and contributes meaningfully to collaborative environments"
    else:
        collab_phrase = "brings solid individual contribution and growing teamwork capabilities"

    summary = (
        f"{name} is {perf_phrase}. "
        f"With {proj_count} project(s) delivered on the Teamify platform and expertise in {skills_str}, "
        f"they {collab_phrase}. "
        f"Achieved a task completion rate of {int(cr * 100)}% and an average peer rating of {rating}/5, "
        f"reflecting both technical competence and professional reliability."
    )

    return summary


# ─────────────────────────────────────────────────────────────────────────────
# 3. IMPROVE PROJECT DESCRIPTIONS
# ─────────────────────────────────────────────────────────────────────────────

def improve_project_description(project: dict, features: dict) -> dict:
    """
    Transforms raw project descriptions into bullet-point,
    impact-driven professional entries.
    """
    title       = project["title"]
    raw_desc    = project["description"]
    techs       = project.get("technologies", [])
    role        = project.get("role", "Contributor")
    status      = project.get("status", "completed")
    impact      = project.get("impact_score", 50)
    duration    = project.get("duration_days", 30)
    rating      = project.get("rating", 4)

    tech_str    = ", ".join(techs) if techs else "various technologies"
    status_str  = "Successfully completed" if status == "completed" else "Currently developing"
    impact_tier = "high-impact" if impact >= 70 else "meaningful"

    bullets = [
        f"{status_str} '{title}' as {role} — a {impact_tier} platform project spanning {duration} days.",
        f"Built using {tech_str}, focusing on scalability, performance, and user experience.",
        f"{_generate_impact_bullet(rating, impact)}",
        f"Original scope: {raw_desc}",
    ]

    return {
        "title":       title,
        "role":        role,
        "technologies": techs,
        "status":      status,
        "impact_score": impact,
        "duration_days": duration,
        "rating":      rating,
        "bullets":     bullets,
        "start_date":  project.get("start_date"),
        "end_date":    project.get("end_date"),
    }


def _generate_impact_bullet(rating: float, impact: float) -> str:
    if rating >= 4.5:
        return f"Received exceptional peer review rating of {rating}/5, recognized for quality and initiative."
    elif rating >= 3.5:
        return f"Delivered quality output with a {rating}/5 peer rating and {impact:.0f}/100 platform impact score."
    else:
        return f"Contributed to team goals with an impact score of {impact:.0f}/100."


# ─────────────────────────────────────────────────────────────────────────────
# 4. SKILLS EXTRACTION
# ─────────────────────────────────────────────────────────────────────────────

def extract_skills(features: dict) -> dict:
    """
    Separates technical skills (from technologies) and
    infers soft skills from behavioral/collaboration metrics.
    """
    technical = features["technical_skills"]

    soft = []
    if features["collaboration_score"] >= 70:
        soft.append("Team Leadership")
    if features["collaboration_score"] >= 40:
        soft.append("Cross-functional Collaboration")
    if features["consistency_score"] >= 75:
        soft.append("Reliability & Consistency")
    if features["teamwork_score"] >= 75:
        soft.append("Teamwork & Synergy")
    if features["completion_rate"] >= 0.9:
        soft.append("Time Management")
    if features["task_efficiency"] >= 0.85:
        soft.append("Efficient Execution")
    if features["trust_score"] >= 80:
        soft.append("Professional Integrity")
    if features["activity_count"] >= 50:
        soft.append("High Initiative & Engagement")

    return {"technical": technical, "soft": soft}


# ─────────────────────────────────────────────────────────────────────────────
# 5. PROJECT RANKING
# ─────────────────────────────────────────────────────────────────────────────

def rank_projects(projects_with_impact: list) -> list:
    """
    Ranks projects by a composite score: impact (50%) + recency (30%) + rating (20%).
    Returns projects sorted best-first.
    """
    now = datetime.now()

    def composite_score(p):
        impact  = p.get("impact_score", 0) / 100
        rating  = p.get("rating", 0) / 5
        try:
            end_date = datetime.fromisoformat(p.get("end_date", str(date.today())))
            age_days = max((now - end_date).days, 0)
            recency  = math.exp(-age_days / 365)  # decays over 1 year
        except Exception:
            recency = 0.5
        return 0.5 * impact + 0.3 * recency + 0.2 * rating

    return sorted(projects_with_impact, key=composite_score, reverse=True)


# ─────────────────────────────────────────────────────────────────────────────
# 6. ACHIEVEMENTS GENERATION
# ─────────────────────────────────────────────────────────────────────────────

def generate_achievements(features: dict) -> list:
    """
    Generates quantified achievement statements from platform metrics.
    Each achievement follows the STAR-lite format: Action + Metric + Context.
    """
    achievements = []
    cr    = features["completion_rate"]
    comp  = features["tasks_completed"]
    proj  = features["completed_projects"]
    collab = features["collaboration_score"]
    msgs  = features["messages_sent"]
    rating = features["avg_rating"]

    if cr >= 0.9:
        achievements.append(
            f"🏆 Maintained a {int(cr*100)}% task completion rate across all assigned projects — "
            f"ranking in the top-tier performers on the platform."
        )
    if comp >= 20:
        achievements.append(
            f"✅ Successfully completed {comp} tasks, demonstrating sustained productivity and focus."
        )
    if proj >= 2:
        achievements.append(
            f"📦 Delivered {proj} full project(s) end-to-end, each passing quality review standards."
        )
    if collab >= 60:
        achievements.append(
            f"🤝 Achieved a collaboration score of {collab}/100, contributing {msgs} messages "
            f"and active team engagement across {features['team_count']} team(s)."
        )
    if rating >= 4.5:
        achievements.append(
            f"⭐ Earned an average peer rating of {rating}/5 — a testament to consistent quality delivery."
        )
    if features["trust_score"] >= 80:
        achievements.append(
            f"🔐 Attained a trust score of {features['trust_score']}/100, "
            f"reflecting accountability and professional conduct."
        )

    return achievements if achievements else ["📌 Active contributor on Teamify platform with growing project portfolio."]


# ─────────────────────────────────────────────────────────────────────────────
# 7. FULL CV UPDATE PIPELINE
# ─────────────────────────────────────────────────────────────────────────────

def update_cv(user_data: dict) -> dict:
    """
    Master pipeline: runs all AI layers and returns a structured CV JSON.
    Called on demand or triggered automatically on new activity.
    """
    user     = user_data["user"]
    features = extract_features(user_data)

    # Run all AI modules
    summary      = generate_summary(user, features)
    skills       = extract_skills(features)
    ranked_proj  = rank_projects(features["projects_with_impact"])
    improved_proj = [improve_project_description(p, features) for p in ranked_proj]
    achievements = generate_achievements(features)

    cv = {
        "generated_at": datetime.now().isoformat(),
        "user":         {"name": user["name"], "role": user["role"], "email": user["email"]},
        "summary":      summary,
        "skills":       skills,
        "projects":     improved_proj,
        "achievements": achievements,
        "metadata": {
            "completion_rate":    features["completion_rate"],
            "avg_rating":         features["avg_rating"],
            "collaboration_score": features["collaboration_score"],
            "project_count":      features["project_count"],
        }
    }

    return cv


# ─────────────────────────────────────────────────────────────────────────────
# 8. AUTO-UPDATE TRIGGER: ON NEW PROJECT
# ─────────────────────────────────────────────────────────────────────────────

def on_new_project(user_data: dict, new_project: dict) -> dict:
    """
    Event handler: triggered when user adds a new project.
    Flow: Save → Update data → Re-run AI → Update CV → Send notification.
    """
    print(f"\n🔔 [Event] New project added: '{new_project['title']}'")

    # 1. Save project to data store
    user_data["projects"].append(new_project)
    print("   ✓ Project saved to data store.")

    # 2. Re-run full CV pipeline
    updated_cv = update_cv(user_data)
    print("   ✓ CV pipeline re-executed.")

    # 3. Send notification
    send_notification(user_data["user"], new_project)

    print("   ✓ CV updated successfully.\n")
    return updated_cv


# ─────────────────────────────────────────────────────────────────────────────
# 9. NOTIFICATION SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

def send_notification(user: dict, project: dict) -> None:
    """
    Sends an in-app notification (simulated — replace with email/websocket in prod).
    """
    msg = (
        f"🎉 Hey {user['name']}! "
        f"Your new project '{project['title']}' has been added to your CV "
        f"and your skills have been updated automatically."
    )
    print(f"\n📨 [Notification → {user['email']}]")
    print(f"   {msg}")

    # Production: replace this with:
    # EmailService.send(user["email"], subject="CV Updated!", body=msg)
    # WebSocketManager.push(user["id"], {"type": "CV_UPDATED", "message": msg})


# ─────────────────────────────────────────────────────────────────────────────
# 10. PDF GENERATION (on-demand only)
# ─────────────────────────────────────────────────────────────────────────────

def generate_pdf(cv: dict, output_path: str = "teamify_cv.pdf") -> str:
    """
    Generates a professional A4 PDF CV from the structured CV JSON.
    Only called when user clicks "Download CV".
    Uses ReportLab for PDF generation.
    """
    doc    = SimpleDocTemplate(output_path, pagesize=A4,
                               topMargin=1.5*cm, bottomMargin=1.5*cm,
                               leftMargin=2*cm, rightMargin=2*cm)
    story  = []
    styles = getSampleStyleSheet()

    # ── Color palette ─────────────────────────────────────────────────────────
    NAVY   = colors.HexColor("#1a2744")
    ACCENT = colors.HexColor("#2563eb")
    GRAY   = colors.HexColor("#64748b")
    LIGHT  = colors.HexColor("#f1f5f9")

    # ── Custom styles ─────────────────────────────────────────────────────────
    name_style = ParagraphStyle("Name", fontSize=24, textColor=NAVY,
                                fontName="Helvetica-Bold", spaceAfter=4, alignment=TA_LEFT)
    role_style = ParagraphStyle("Role", fontSize=13, textColor=ACCENT,
                                fontName="Helvetica", spaceAfter=2)
    email_style = ParagraphStyle("Email", fontSize=9, textColor=GRAY,
                                 fontName="Helvetica", spaceAfter=12)
    section_style = ParagraphStyle("Section", fontSize=12, textColor=NAVY,
                                   fontName="Helvetica-Bold", spaceBefore=14, spaceAfter=4)
    body_style = ParagraphStyle("Body", fontSize=9.5, textColor=colors.HexColor("#334155"),
                                fontName="Helvetica", spaceAfter=4, leading=14)
    bullet_style = ParagraphStyle("Bullet", fontSize=9, textColor=colors.HexColor("#334155"),
                                  fontName="Helvetica", leftIndent=12, spaceAfter=3, leading=13)
    tag_style = ParagraphStyle("Tag", fontSize=8.5, textColor=ACCENT,
                               fontName="Helvetica-Bold", spaceAfter=2)

    user = cv["user"]

    # ── Header ────────────────────────────────────────────────────────────────
    story.append(Paragraph(user["name"], name_style))
    story.append(Paragraph(user["role"], role_style))
    story.append(Paragraph(user["email"], email_style))
    story.append(HRFlowable(width="100%", thickness=2, color=ACCENT))
    story.append(Spacer(1, 8))

    # ── Summary ───────────────────────────────────────────────────────────────
    story.append(Paragraph("Professional Summary", section_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=LIGHT))
    story.append(Spacer(1, 4))
    story.append(Paragraph(cv["summary"], body_style))
    story.append(Spacer(1, 6))

    # ── Skills ────────────────────────────────────────────────────────────────
    story.append(Paragraph("Skills", section_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=LIGHT))
    story.append(Spacer(1, 4))

    tech_str = "  •  ".join(cv["skills"]["technical"])
    soft_str = "  •  ".join(cv["skills"]["soft"])
    story.append(Paragraph(f"<b>Technical:</b>  {tech_str}", body_style))
    story.append(Paragraph(f"<b>Soft Skills:</b>  {soft_str}", body_style))
    story.append(Spacer(1, 6))

    # ── Projects ──────────────────────────────────────────────────────────────
    story.append(Paragraph("Projects", section_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=LIGHT))

    for proj in cv["projects"]:
        story.append(Spacer(1, 8))
        header = f"<b>{proj['title']}</b>  <font color='#2563eb'>|  {proj['role']}</font>"
        story.append(Paragraph(header, body_style))
        dates = f"{proj.get('start_date','')[:7]} → {proj.get('end_date','')[:7]}   |   ⭐ {proj['rating']}/5   |   Impact: {proj['impact_score']}/100"
        story.append(Paragraph(dates, tag_style))
        for b in proj["bullets"]:
            story.append(Paragraph(f"• {b}", bullet_style))

    story.append(Spacer(1, 6))

    # ── Achievements ──────────────────────────────────────────────────────────
    story.append(Paragraph("Achievements", section_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=LIGHT))
    story.append(Spacer(1, 4))
    for ach in cv["achievements"]:
        story.append(Paragraph(ach, body_style))

    # ── Footer ────────────────────────────────────────────────────────────────
    story.append(Spacer(1, 20))
    story.append(HRFlowable(width="100%", thickness=0.5, color=GRAY))
    footer = f"<font color='#94a3b8' size=7>Generated by Teamify AI Resume Builder • {cv['generated_at'][:10]}</font>"
    story.append(Paragraph(footer, ParagraphStyle("footer", alignment=TA_CENTER, spaceAfter=0)))

    doc.build(story)
    print(f"\n📄 PDF generated successfully → {output_path}")
    return output_path


# ─────────────────────────────────────────────────────────────────────────────
# DEMO: FULL END-TO-END FLOW
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  Teamify · AI Resume Builder · Demo Run")
    print("=" * 60)

    # ── Sample Input Data ─────────────────────────────────────────────────────
    user_data = {
        "user": make_user("Ahmed Al-Rashid", "Full Stack Developer", "ahmed@teamify.io"),

        "projects": [
            make_project(
                title="E-Commerce Platform",
                description="Built an online store for a local brand with payment integration.",
                technologies=["React", "Node.js", "PostgreSQL", "Stripe"],
                user_role="Lead Developer",
                status="completed",
                rating=4.8,
                start_date="2024-01-10",
                end_date="2024-04-20"
            ),
            make_project(
                title="Task Management API",
                description="REST API for team task tracking with notifications.",
                technologies=["Python", "FastAPI", "Redis", "Docker"],
                user_role="Backend Developer",
                status="completed",
                rating=4.5,
                start_date="2024-05-01",
                end_date="2024-07-15"
            ),
            make_project(
                title="AI Chat Widget",
                description="Embedded AI assistant for customer support on websites.",
                technologies=["Python", "OpenAI API", "React", "WebSockets"],
                user_role="Full Stack Developer",
                status="in_progress",
                rating=4.2,
                start_date="2024-09-01",
                end_date="2024-12-01"
            ),
        ],

        "tasks":   make_task(completed=87, total=94, overdue=3),
        "metrics": make_metrics(trust_score=88, consistency_score=82, teamwork_score=79, avg_rating=4.5),
        "collaboration": make_collaboration(messages_sent=234, comments_written=178, team_count=4),
        "activity": make_activity(activity_count=312, login_frequency=6.2),
    }

    # ── Step 1: Generate initial CV ───────────────────────────────────────────
    print("\n[Step 1] Generating initial CV...")
    cv = update_cv(user_data)
    print("✓ CV generated.")

    # ── Step 2: Print CV JSON ─────────────────────────────────────────────────
    print("\n[Step 2] CV Output (JSON):\n")
    output = {
        "summary":      cv["summary"],
        "skills":       cv["skills"],
        "projects":     [{"title": p["title"], "bullets": p["bullets"]} for p in cv["projects"]],
        "achievements": cv["achievements"],
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))

    # ── Step 3: Simulate adding a new project ─────────────────────────────────
    print("\n" + "=" * 60)
    print("[Step 3] Simulating: User adds a new project...")
    new_proj = make_project(
        title="Portfolio Website",
        description="Personal portfolio showcasing projects and skills.",
        technologies=["Next.js", "TailwindCSS", "Vercel"],
        user_role="Frontend Developer",
        status="completed",
        rating=4.7,
        start_date="2024-10-01",
        end_date="2024-11-10"
    )
    updated_cv = on_new_project(user_data, new_proj)

    # ── Step 4: Generate PDF ──────────────────────────────────────────────────
    print("\n[Step 4] User clicks 'Download CV' → Generating PDF...")
    pdf_path = generate_pdf(updated_cv, "/mnt/user-data/outputs/teamify_cv.pdf")
    print(f"✓ PDF ready: {pdf_path}")

    print("\n" + "=" * 60)
    print("  ✅ Full Flow Complete!")
    print("=" * 60)
