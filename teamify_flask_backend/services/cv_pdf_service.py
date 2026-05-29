"""
CV PDF Export Service
Converts a CV dict to a polished PDF in memory using ReportLab.

SECURITY: The PDF is NEVER written to disk or a public static folder.
It is generated into a BytesIO buffer and streamed directly through
a protected Flask route, so the file is inaccessible without a valid JWT.

NOTE: Do NOT call reportlab.lib.styles.getSampleStyleSheet() — gevent's
monkey-patch breaks its threading.local singleton (AttributeError on '_Noop').
Use colors.Color(r,g,b) for accent (not HexColor) to avoid gevent draw bugs.
"""
from __future__ import annotations
import io
import re
from typing import Any
from xml.sax.saxutils import escape

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, HRFlowable, ListFlowable, ListItem
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

_DARK_TEXT = colors.Color(0.129, 0.129, 0.129)
_DEFAULT_ACCENT = "#2D5FA6"
_HEX_RE = re.compile(r"^[0-9a-fA-F]{6}$")


def _parse_hex(value: str | None, default: str = _DEFAULT_ACCENT) -> str:
    """Return a normalized 6-digit hex RGB string (no #)."""
    if not value or not isinstance(value, str):
        value = default
    h = value.strip().lstrip("#")
    if len(h) == 8:
        h = h[2:]
    if _HEX_RE.match(h):
        return h.lower()
    fallback = default.lstrip("#")
    return fallback if _HEX_RE.match(fallback) else "2d5fa6"


def _rgb_color(value: str | None, default: str = _DEFAULT_ACCENT) -> colors.Color:
    """Build a ReportLab Color via RGB floats (gevent-safe)."""
    h = _parse_hex(value, default)
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return colors.Color(r, g, b)


def _pdf_text(value: Any) -> str:
    """Escape user text for ReportLab Paragraph mini-markup."""
    if value is None:
        return ""
    text = escape(str(value))
    return text.replace("[", "(").replace("]", ")")


def _section_visible(personal: dict, key: str, default: bool = True) -> bool:
    vis = personal.get("section_visibility")
    if isinstance(vis, dict) and key in vis:
        return bool(vis[key])
    return default


def _make_styles(personal: dict) -> tuple[dict, colors.Color, str, str]:
    accent = _rgb_color(personal.get("accent_color"))
    accent_hex = f"#{_parse_hex(personal.get('accent_color'))}"
    style_name = (personal.get("resume_style") or "Modern").strip()
    center = style_name.lower() != "classic"

    style_dict = {
        "name": ParagraphStyle(
            "name", fontSize=22, textColor=accent,
            fontName="Helvetica-Bold",
            alignment=TA_CENTER if center else TA_LEFT,
            spaceAfter=4,
        ),
        "contact": ParagraphStyle(
            "contact", fontSize=9, textColor=accent,
            fontName="Helvetica",
            alignment=TA_CENTER if center else TA_LEFT,
            spaceAfter=2,
        ),
        "summary": ParagraphStyle(
            "summary", fontSize=10, textColor=_DARK_TEXT,
            fontName="Helvetica-Oblique", spaceAfter=8, leading=14,
        ),
        "section_heading": ParagraphStyle(
            "section_heading", fontSize=12, textColor=accent,
            fontName="Helvetica-Bold", spaceBefore=10, spaceAfter=4,
        ),
        "item_title": ParagraphStyle(
            "item_title", fontSize=10, textColor=_DARK_TEXT,
            fontName="Helvetica-Bold", spaceAfter=2,
        ),
        "item_subtitle": ParagraphStyle(
            "item_subtitle", fontSize=9, textColor=accent,
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
    return style_dict, accent, style_name, accent_hex


def _hr(story: list, accent: colors.Color) -> None:
    story.append(HRFlowable(width="100%", thickness=0.5, color=accent))
    story.append(Spacer(1, 0.1 * cm))


def _section(story: list, title: str, styles: dict, accent: colors.Color) -> None:
    story.append(Paragraph(_pdf_text(title).upper(), styles["section_heading"]))
    _hr(story, accent)


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
    personal = cv_data.get("personal_info") or {}
    if not isinstance(personal, dict):
        personal = {}
    styles, accent, _style_name, accent_hex = _make_styles(personal)
    story: list = []

    # ── Header ────────────────────────────────────────────────────────────────
    full_name = _pdf_text(personal.get("full_name", ""))
    if full_name:
        story.append(Paragraph(full_name, styles["name"]))

    contact_parts = []
    for field in ("email", "phone", "location", "linkedin", "github"):
        val = personal.get(field)
        if val:
            contact_parts.append(_pdf_text(val))
    if contact_parts:
        story.append(Paragraph("  |  ".join(contact_parts), styles["contact"]))
    story.append(Spacer(1, 0.3 * cm))

    # ── Professional Summary ─────────────────────────────────────────────────
    summary = cv_data.get("summary")
    if summary and _section_visible(personal, "Summary"):
        _section(story, "Professional Summary", styles, accent)
        story.append(Paragraph(_pdf_text(summary), styles["summary"]))

    # ── Skills ───────────────────────────────────────────────────────────────
    skills = cv_data.get("skills", [])
    if skills and _section_visible(personal, "Skills"):
        _section(story, "Skills", styles, accent)
        skill_lines = []
        for chunk in [skills[i : i + 4] for i in range(0, len(skills), 4)]:
            line = "    •    ".join(
                f"{_pdf_text(s.get('name', ''))} ({_pdf_text(s.get('level', ''))})"
                for s in chunk
                if isinstance(s, dict)
            )
            if line.strip():
                skill_lines.append(
                    ListItem(Paragraph(line, styles["skill_tag"]), leftIndent=12)
                )
        if skill_lines:
            story.append(ListFlowable(skill_lines, bulletType="bullet"))
            story.append(Spacer(1, 0.2 * cm))

    show_experience = _section_visible(personal, "Experience")

    # ── Experience ───────────────────────────────────────────────────────────
    experience = cv_data.get("experience", [])
    if experience and show_experience:
        _section(story, "Professional Experience", styles, accent)
        for exp in experience:
            if not isinstance(exp, dict):
                continue
            end = _pdf_text(exp.get("end_date") or "Present")
            story.append(Paragraph(
                f"{_pdf_text(exp.get('title', ''))}  —  {_pdf_text(exp.get('company', ''))}",
                styles["item_title"],
            ))
            story.append(Paragraph(
                f"{_pdf_text(exp.get('location', ''))}    "
                f"{_pdf_text(exp.get('start_date', ''))} – {end}",
                styles["item_subtitle"],
            ))
            if exp.get("description"):
                story.append(Paragraph(_pdf_text(exp["description"]), styles["item_body"]))

    # ── Projects ─────────────────────────────────────────────────────────────
    projects = cv_data.get("projects", [])
    if projects and show_experience:
        _section(story, "Projects", styles, accent)
        for proj in projects:
            if not isinstance(proj, dict):
                continue
            name_line = _pdf_text(proj.get("name", ""))
            url = proj.get("url")
            if url:
                safe_url = escape(str(url), {'"': "&quot;"})
                name_line += (
                    f'  <link href="{safe_url}" color="{accent_hex}">(link)</link>'
                )
            if name_line:
                story.append(Paragraph(name_line, styles["item_title"]))
            tech = proj.get("tech_stack")
            if tech:
                stack = ", ".join(_pdf_text(t) for t in tech if t)
                if stack:
                    story.append(Paragraph(f"Stack: {stack}", styles["item_subtitle"]))
            if proj.get("description"):
                story.append(Paragraph(_pdf_text(proj["description"]), styles["item_body"]))

    # ── Education ────────────────────────────────────────────────────────────
    education = cv_data.get("education", [])
    if education:
        _section(story, "Education", styles, accent)
        for edu in education:
            if not isinstance(edu, dict):
                continue
            story.append(Paragraph(
                f"{_pdf_text(edu.get('degree', ''))} in {_pdf_text(edu.get('field', ''))}"
                f"  —  {_pdf_text(edu.get('institution', ''))}",
                styles["item_title"],
            ))
            dates = (
                f"{_pdf_text(edu.get('start_date', ''))} – {_pdf_text(edu.get('end_date', ''))}"
            )
            gpa = f"   GPA: {edu.get('gpa')}" if edu.get("gpa") else ""
            story.append(Paragraph(dates + gpa, styles["item_subtitle"]))

    # ── Certifications ───────────────────────────────────────────────────────
    certs = cv_data.get("certifications", [])
    if certs:
        _section(story, "Certifications", styles, accent)
        for cert in certs:
            if not isinstance(cert, dict):
                continue
            name_line = _pdf_text(cert.get("name", ""))
            url = cert.get("url")
            if url:
                safe_url = escape(str(url), {'"': "&quot;"})
                name_line += (
                    f'  <link href="{safe_url}" color="{accent_hex}">(verify)</link>'
                )
            if name_line:
                story.append(Paragraph(name_line, styles["item_title"]))
            sub = "  |  ".join(
                filter(
                    None,
                    [_pdf_text(cert.get("issuer")), _pdf_text(cert.get("date"))],
                )
            )
            if sub:
                story.append(Paragraph(sub, styles["item_subtitle"]))

    doc.build(story)
    buffer.seek(0)
    return buffer
