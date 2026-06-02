"""Gunicorn entrypoint for production (Render, etc.)."""
from app import create_app

application = create_app()
