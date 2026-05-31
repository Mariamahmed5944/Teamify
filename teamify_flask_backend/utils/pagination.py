"""Shared pagination query parsing."""
from __future__ import annotations

from flask import jsonify


def parse_pagination(default_page: int = 1, default_per_page: int = 20, max_per_page: int = 100):
    """
    Parse page and per_page from the current Flask request args.

    Returns (page, per_page, None) on success or (None, None, error_response).
    """
    from flask import request

    try:
        page = max(1, int(request.args.get("page", default_page)))
    except (TypeError, ValueError):
        return None, None, (jsonify({"error": "page must be a positive integer"}), 400)

    try:
        per_page = min(int(request.args.get("per_page", default_per_page)), max_per_page)
        if per_page < 1:
            raise ValueError
    except (TypeError, ValueError):
        return None, None, (jsonify({"error": "per_page must be a positive integer"}), 400)

    return page, per_page, None
