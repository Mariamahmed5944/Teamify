"""
CV PDF Export Service
Converts a CV dict to a polished PDF in memory using ReportLab.

SECURITY: The PDF is NEVER written to disk or a public static folder.
It is generated into a BytesIO buffer and streamed directly through
a protected Flask route, so the file is inaccessible without a valid JWT.
"""
from __future__ import annotations
import io
from typing import Any

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, HRFlowable, ListFlowable, ListItem
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER


# ─── Colour palette ───────────────────────────────────────────────────────────
_PRIMARY   = colors.HexColor("#1A237E")   # deep indigo
_SECONDARY = colors.HexColor("#3949AB")
_ACCENT    = colors.HexColor("#42A5F5")
_LIGHT_GREY = colors.HexColor("#F5F5F5")
_DARK_TEXT  = colors.HexColor("#212121")


def _make_styles() -> dict:
    base = getSampleStyleSheet()
    return {
        "name": ParagraphStyle(
            "name", fontSize=22, textColor=_PRIMARY,
            fontName="Helvetica-Bold", alignment=TA_CENTER, spaceAfter=4,
        ),
        "contact": ParagraphStyle(
            "contact", fontSize=9, textColor=_SECONDARY,
            fontName="Helvetica", alignment=TA_CENTER, spaceAfter=2,
        ),
        "summary": ParagraphStyle(
            "summary", fontSize=10, textColor=_DARK_TEXT,
            fontName="Helvetica-Oblique", spaceAfter=8, leading=14,
        ),
        "section_heading": ParagraphStyle(
            "section_heading", fontSize=12, textColor=_PRIMARY,
            fontName="Helvetica-Bold", spaceBefore=10, spaceAfter=4,
        ),
        "item_title": ParagraphStyle(
            "item_title", fontSize=10, textColor=_DARK_TEXT,
            fontName="Helvetica-Bold", spaceAfter=2,
        ),
        "item_subtitle": ParagraphStyle(
            "item_subtitle", fontSize=9, textColor=_SECONDARY,
            fontName="Helvetica", spaceAfter=2,
        ),
        "item_body": ParagraphStyle(
            "item_body", fontSize=9, textColor=_DARK_TEXT,
            fontName="Helvetica", spaceAfter=4, leading=13,
        ),
        "skill_tag": ParagraphStyle(
            "skill_tag", fontSize=9, textColor=_DARK_TEXT,
            fontName="Helvetica",
        ),
    }


def _hr(story: list) -> None:
    story.append(HRFlowable(width="100%", thickness=0.5, color=_ACCENT))
    story.append(Spacer(1, 0.1 * cm))


def _section(story: list, title: str, styles: dict) -> None:
    story.append(Paragraph(title.upper(), styles["section_heading"]))
    _hr(story)


def build_cv_pdf(cv_data: dict) -> io.BytesIO:
    """
    Render cv_data to a PDF and return a seeked BytesIO buffer.

    SECURITY: No disk I/O whatsoever — the buffer lives in RAM and is
    discarded by GC as soon as the HTTP response is sent.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=1.8 * cm,
        leftMargin=1.8 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
    )
    styles = _make_styles()
    story  = []

    personal = cv_data.get("personal_info", {})

    # ── Header ────────────────────────────────────────────────────────────────
    story.append(Paragraph(personal.get("full_name", ""), styles["name"]))

    contact_parts = []
    for field in ("email", "phone", "location", "linkedin", "github"):
        val = personal.get(field)
        if val:
            contact_parts.append(val)
    story.append(Paragraph("  |  ".join(contact_parts), styles["contact"]))
    story.append(Spacer(1, 0.3 * cm))

    # ── Professional Summary ─────────────────────────────────────────────────
    summary = cv_data.get("summary")
    if summary:
        _section(story, "Professional Summary", styles)
        story.append(Paragraph(summary, styles["summary"]))

    # ── Skills ───────────────────────────────────────────────────────────────
    skills = cv_data.get("skills", [])
    if skills:
        _section(story, "Skills", styles)
        skill_lines = []
        for chunk in [skills[i:i+4] for i in range(0, len(skills), 4)]:
            line = "    •    ".join(
                f"{s['name']} ({s.get('level', '')})" for s in chunk
            )
            skill_lines.append(ListItem(Paragraph(line, styles["skill_tag"]), leftIndent=12))
        story.append(ListFlowable(skill_lines, bulletType="bullet"))
        story.append(Spacer(1, 0.2 * cm))

    # ── Experience ───────────────────────────────────────────────────────────
    experience = cv_data.get("experience", [])
    if experience:
        _section(story, "Professional Experience", styles)
        for exp in experience:
            end = exp.get("end_date") or "Present"
            story.append(Paragraph(
                f"{exp.get('title', '')}  —  {exp.get('company', '')}",
                styles["item_title"]
            ))
            story.append(Paragraph(
                f"{exp.get('location', '')}    {exp.get('start_date', '')} – {end}",
                styles["item_subtitle"]
            ))
            if exp.get("description"):
                story.append(Paragraph(exp["description"], styles["item_body"]))

    # ── Projects ─────────────────────────────────────────────────────────────
    projects = cv_data.get("projects", [])
    if projects:
        _section(story, "Projects", styles)
        for proj in projects:
            name_line = proj.get("name", "")
            if proj.get("url"):
                name_line += f'  <link href="{proj["url"]}" color="{_ACCENT.hexval()}">[link]</link>'
            story.append(Paragraph(name_line, styles["item_title"]))
            if proj.get("tech_stack"):
                story.append(Paragraph(
                    "Stack: " + ", ".join(proj["tech_stack"]),
                    styles["item_subtitle"]
                ))
            if proj.get("description"):
                story.append(Paragraph(proj["description"], styles["item_body"]))

    # ── Education ────────────────────────────────────────────────────────────
    education = cv_data.get("education", [])
    if education:
        _section(story, "Education", styles)
        for edu in education:
            story.append(Paragraph(
                f"{edu.get('degree', '')} in {edu.get('field', '')}  —  {edu.get('institution', '')}",
                styles["item_title"]
            ))
            dates = f"{edu.get('start_date', '')} – {edu.get('end_date', '')}"
            gpa   = f"   GPA: {edu.get('gpa')}" if edu.get("gpa") else ""
            story.append(Paragraph(dates + gpa, styles["item_subtitle"]))

    # ── Certifications ───────────────────────────────────────────────────────
    certs = cv_data.get("certifications", [])
    if certs:
        _section(story, "Certifications", styles)
        for cert in certs:
            name_line = cert.get("name", "")
            if cert.get("url"):
                name_line += f'  <link href="{cert["url"]}" color="{_ACCENT.hexval()}">[verify]</link>'
            story.append(Paragraph(name_line, styles["item_title"]))
            sub = "  |  ".join(filter(None, [cert.get("issuer"), cert.get("date")]))
            if sub:
                story.append(Paragraph(sub, styles["item_subtitle"]))

    doc.build(story)
    buffer.seek(0)
    return buffer
