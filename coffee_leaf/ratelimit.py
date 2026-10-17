"""Per-client rate limiting backed by the shared SQLite store.

The window lives in SQLite rather than in process memory so the quota is
shared across worker processes and survives a restart. At the request rates
this app serves, the write cost is negligible.
"""

from __future__ import annotations

from collections.abc import Callable
from functools import wraps
from typing import TypeVar

from flask import current_app, jsonify, request

ViewFunction = TypeVar("ViewFunction", bound=Callable)


def rate_limit(view: ViewFunction) -> ViewFunction:
    """Reject the request with HTTP 429 once the client's quota is exhausted.

    The limit and window are read from ``app.config`` on every call so they
    stay overridable per environment and per test.
    """

    @wraps(view)
    def wrapper(*args, **kwargs):
        store = current_app.extensions["store"]
        allowed = store.allow(
            request.remote_addr or "unknown",
            current_app.config["RATE_LIMIT_MAX"],
            current_app.config["RATE_LIMIT_WINDOW"],
        )
        if not allowed:
            return jsonify({"error": "Too many requests. Please wait a moment."}), 429
        return view(*args, **kwargs)

    return wrapper  # type: ignore[return-value]
