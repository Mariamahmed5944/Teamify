"""
CV Marshmallow Schemas
All string fields run through _sanitize_html() to strip XSS payloads
before any data reaches the DB. This is the single choke-point for
CV input sanitization.
"""
import re
from marshmallow import Schema, fields, validate, validates, ValidationError, pre_load

# ─── XSS Sanitizer ────────────────────────────────────────────────────────────
_TAG_RE = re.compile(r"<.*?>", re.DOTALL)

def _strip_tags(value: str) -> str:
    """Remove all HTML/script tags and strip surrounding whitespace."""
    return _TAG_RE.sub("", value).strip()


def _sanitize_str(value):
    """Apply tag stripping to a single string value if it is indeed a string."""
    return _strip_tags(value) if isinstance(value, str) else value


# ─── Skill Whitelist ──────────────────────────────────────────────────────────
# SECURITY: Only recognised skill names are accepted. Unknown entries are
# rejected with a ValidationError, preventing junk or injected values.
ALLOWED_SKILLS = {
    # Programming Languages
    "Python", "JavaScript", "TypeScript", "Java", "C", "C++", "C#", "Go",
    "Rust", "Kotlin", "Swift", "Ruby", "PHP", "Scala", "R", "Dart", "Lua",
    "Perl", "Haskell", "Elixir", "Clojure", "MATLAB", "Shell", "Bash",
    "PowerShell", "SQL", "HTML", "CSS", "Objective-C", "Assembly",
    # Frontend
    "React", "Angular", "Vue", "Svelte", "Next.js", "Nuxt.js", "jQuery",
    "Bootstrap", "TailwindCSS", "Sass", "LESS", "Redux", "Zustand",
    "Webpack", "Vite", "Figma", "Adobe XD",
    # Backend & Frameworks
    "Flask", "Django", "FastAPI", "Express", "NestJS", "Spring Boot",
    "Ruby on Rails", "Laravel", "ASP.NET", "Node.js", "Deno", "Bun",
    # Mobile
    "Flutter", "React Native", "SwiftUI", "Jetpack Compose", "Xamarin",
    "Ionic",
    # Data & AI
    "Machine Learning", "Deep Learning", "TensorFlow", "PyTorch", "Keras",
    "Scikit-learn", "Pandas", "NumPy", "OpenCV", "NLP",
    "Computer Vision", "Data Analysis", "Data Science", "Big Data",
    "Apache Spark", "Hadoop", "Power BI", "Tableau",
    # Cloud & DevOps
    "AWS", "Azure", "GCP", "Docker", "Kubernetes", "Terraform",
    "Ansible", "Jenkins", "GitHub Actions", "CI/CD", "Linux",
    "Nginx", "Apache",
    # Databases
    "PostgreSQL", "MySQL", "MongoDB", "Redis", "SQLite", "Firebase",
    "Elasticsearch", "DynamoDB", "Oracle", "SQL Server", "Cassandra",
    "Neo4j", "Supabase",
    # Testing & Security
    "Pytest", "Jest", "Selenium", "Cypress", "Playwright",
    "Penetration Testing", "OWASP", "Cryptography",
    # Soft Skills & Other
    "Agile", "Scrum", "Git", "GitHub", "GitLab", "Jira", "REST API",
    "GraphQL", "gRPC", "WebSocket", "Microservices", "System Design",
    "Technical Writing", "UI/UX Design", "Project Management",
    "Leadership", "Communication", "Problem Solving", "Team Management",
}

# Case-insensitive lookup set for validation
_ALLOWED_SKILLS_LOWER = {s.lower() for s in ALLOWED_SKILLS}


# ─── Nested Section Schemas ───────────────────────────────────────────────────

class PersonalInfoSchema(Schema):
    full_name   = fields.Str(required=True, validate=validate.Length(min=1, max=150))
    email       = fields.Email(required=True)
    phone       = fields.Str(load_default=None, validate=validate.Length(max=30))
    location    = fields.Str(load_default=None, validate=validate.Length(max=100))
    linkedin    = fields.Url(load_default=None)
    github      = fields.Url(load_default=None)
    website     = fields.Url(load_default=None)

    @pre_load
    def sanitize(self, data, **kwargs):
        # SECURITY: strip HTML tags from every string field to prevent XSS
        return {k: _sanitize_str(v) for k, v in data.items()}


class SkillSchema(Schema):
    name        = fields.Str(required=True, validate=validate.Length(min=1, max=80))
    level       = fields.Str(
        load_default="Intermediate",
        validate=validate.OneOf(
            ["Beginner", "Intermediate", "Advanced", "Expert"],
            error="Invalid skill level"
        )
    )
    years       = fields.Int(load_default=None, validate=validate.Range(min=0, max=50))

    @pre_load
    def sanitize(self, data, **kwargs):
        return {k: _sanitize_str(v) for k, v in data.items()}

    @validates("name")
    def validate_skill_name(self, value):
        """SECURITY: Reject skill names not on the approved whitelist."""
        if value.lower() not in _ALLOWED_SKILLS_LOWER:
            raise ValidationError(
                f"'{value}' is not a recognised skill. "
                f"Choose from the approved list."
            )


class ExperienceSchema(Schema):
    company     = fields.Str(required=True, validate=validate.Length(min=1, max=150))
    title       = fields.Str(required=True, validate=validate.Length(min=1, max=150))
    start_date  = fields.Str(required=True, validate=validate.Length(max=20))   # "2022-01"
    end_date    = fields.Str(load_default=None, validate=validate.Length(max=20))  # None = present
    description = fields.Str(load_default=None, validate=validate.Length(max=2000))
    location    = fields.Str(load_default=None, validate=validate.Length(max=100))

    @pre_load
    def sanitize(self, data, **kwargs):
        return {k: _sanitize_str(v) for k, v in data.items()}


class ProjectSchema(Schema):
    name        = fields.Str(required=True, validate=validate.Length(min=1, max=150))
    description = fields.Str(load_default=None, validate=validate.Length(max=2000))
    url         = fields.Url(load_default=None)
    start_date  = fields.Str(load_default=None, validate=validate.Length(max=20))
    end_date    = fields.Str(load_default=None, validate=validate.Length(max=20))
    tech_stack  = fields.List(fields.Str(), load_default=list)

    @pre_load
    def sanitize(self, data, **kwargs):
        return {k: _sanitize_str(v) for k, v in data.items()}


class EducationSchema(Schema):
    institution = fields.Str(required=True, validate=validate.Length(min=1, max=200))
    degree      = fields.Str(required=True, validate=validate.Length(min=1, max=150))
    field       = fields.Str(load_default=None, validate=validate.Length(max=150))
    start_date  = fields.Str(load_default=None, validate=validate.Length(max=20))
    end_date    = fields.Str(load_default=None, validate=validate.Length(max=20))
    gpa         = fields.Float(load_default=None, validate=validate.Range(min=0.0, max=4.0))

    @pre_load
    def sanitize(self, data, **kwargs):
        return {k: _sanitize_str(v) for k, v in data.items()}


class CertificationSchema(Schema):
    name        = fields.Str(required=True, validate=validate.Length(min=1, max=200))
    issuer      = fields.Str(load_default=None, validate=validate.Length(max=150))
    date        = fields.Str(load_default=None, validate=validate.Length(max=20))
    url         = fields.Url(load_default=None)

    @pre_load
    def sanitize(self, data, **kwargs):
        return {k: _sanitize_str(v) for k, v in data.items()}


# ─── Top-Level CV Schema ──────────────────────────────────────────────────────

class CVCreateSchema(Schema):
    personal_info   = fields.Nested(PersonalInfoSchema, required=True)
    skills          = fields.List(fields.Nested(SkillSchema), load_default=list)
    experience      = fields.List(fields.Nested(ExperienceSchema), load_default=list)
    projects        = fields.List(fields.Nested(ProjectSchema), load_default=list)
    education       = fields.List(fields.Nested(EducationSchema), load_default=list)
    certifications  = fields.List(fields.Nested(CertificationSchema), load_default=list)
    is_public       = fields.Bool(load_default=False)

    @validates("skills")
    def validate_skills_count(self, value):
        if len(value) > 50:
            raise ValidationError("A CV may contain at most 50 skills.")

    @validates("experience")
    def validate_experience_count(self, value):
        if len(value) > 30:
            raise ValidationError("A CV may contain at most 30 experience entries.")

    @validates("projects")
    def validate_projects_count(self, value):
        if len(value) > 30:
            raise ValidationError("A CV may contain at most 30 project entries.")


# Schema singletons (re-used across requests)
cv_create_schema = CVCreateSchema()
