"""Minimal thread-safe in-memory rate limiter.

ponytail: per-process memory only -- correct for a single dev/preview worker.
Swap for Flask-Limiter backed by Redis when scaling past one process.
"""

from __future__ import annotations

import time
from collections import defaultdict, deque
from functools import wraps
from threading import Lock
from typing import Callable, TypeVar

from flask import jsonify, request

from .config import RATE_LIMIT_MAX, RATE_LIMIT_WINDOW

ViewFunction = TypeVar("ViewFunction", bound=Callable)


class RateLimiter:
    """Sliding-window limiter keyed by an arbitrary string."""

    def __init__(self, limit: int, window: int) -> None:
        self.limit = limit
        self.window = window
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def allow(self, key: str) -> bool:
        """Record a hit for ``key``; return ``False`` when the quota is spent."""
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                return False
            hits.append(now)
            return True


limiter = RateLimiter(RATE_LIMIT_MAX, RATE_LIMIT_WINDOW)


def rate_limit(view: ViewFunction) -> ViewFunction:
    """Reject the request with HTTP 429 once the client's quota is exhausted."""

    @wraps(view)
    def wrapper(*args, **kwargs):
        if not limiter.allow(request.remote_addr or "unknown"):
            return jsonify({"error": "Too many requests. Please wait a moment."}), 429
        return view(*args, **kwargs)

    return wrapper  # type: ignore[return-value]
