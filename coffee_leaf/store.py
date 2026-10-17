"""SQLite-backed persistence for the anonymous scan log and rate-limit windows.

Standard library only (``sqlite3``). No image bytes, no client IP and no
filename ever reach the database: the log stores the predicted class, the
confidence, the detection count and the latency, which is what the dashboard
aggregates.
"""

from __future__ import annotations

import logging
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS scans (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at  REAL    NOT NULL,
    label       TEXT    NOT NULL,
    confidence  REAL    NOT NULL,
    detections  INTEGER NOT NULL,
    latency_ms  REAL    NOT NULL,
    source      TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_scans_created ON scans (created_at DESC);

CREATE TABLE IF NOT EXISTS rate_hits (
    key    TEXT NOT NULL,
    hit_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rate_hits ON rate_hits (key, hit_at);
"""

# Rows kept in the scan log; older rows are pruned on insert.
_MAX_ROWS = 5_000


class Store:
    """Thread-safe SQLite store shared by the whole process."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._db = sqlite3.connect(str(self.path), timeout=5, check_same_thread=False)
        self._db.row_factory = sqlite3.Row
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.execute("PRAGMA synchronous=NORMAL")
        self._db.executescript(_SCHEMA)
        self._db.commit()
        logger.info("Scan log ready at %s", self.path)

    def _prune(self) -> None:
        self._db.execute(
            "DELETE FROM scans WHERE id NOT IN (SELECT id FROM scans ORDER BY id DESC LIMIT ?)",
            (_MAX_ROWS,),
        )
        self._db.execute("DELETE FROM rate_hits WHERE hit_at < ?", (time.time() - 86_400,))

    def record_scan(
        self,
        *,
        label: str | None,
        confidence: float,
        detections: int,
        latency_ms: float,
        source: str,
    ) -> None:
        """Append one anonymous scan record."""
        with self._lock:
            self._db.execute(
                "INSERT INTO scans (created_at, label, confidence, detections, latency_ms, source)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (time.time(), label or "unknown", confidence, detections, latency_ms, source),
            )
            self._prune()
            self._db.commit()

    def allow(self, key: str, limit: int, window: int) -> bool:
        """Sliding-window rate limit check against the ``rate_hits`` table."""
        now = time.time()
        cutoff = now - window
        with self._lock:
            self._db.execute("DELETE FROM rate_hits WHERE key = ? AND hit_at <= ?", (key, cutoff))
            used = self._db.execute(
                "SELECT COUNT(*) FROM rate_hits WHERE key = ?", (key,)
            ).fetchone()[0]
            if used >= limit:
                self._db.commit()
                return False
            self._db.execute("INSERT INTO rate_hits (key, hit_at) VALUES (?, ?)", (key, now))
            self._db.commit()
            return True

    def stats(self, recent_limit: int = 8) -> dict[str, Any]:
        """Aggregate totals for the dashboard activity panel."""
        with self._lock:
            total = self._db.execute("SELECT COUNT(*) FROM scans").fetchone()[0]
            if not total:
                return {
                    "total": 0,
                    "average_confidence": 0.0,
                    "average_latency_ms": 0.0,
                    "distribution": [],
                    "recent": [],
                }

            summary = self._db.execute(
                "SELECT AVG(confidence) AS conf, AVG(latency_ms) AS latency FROM scans"
            ).fetchone()
            distribution = self._db.execute(
                "SELECT label, COUNT(*) AS count, AVG(confidence) AS confidence"
                " FROM scans GROUP BY label ORDER BY count DESC"
            ).fetchall()
            recent = self._db.execute(
                "SELECT created_at, label, confidence, detections, latency_ms, source"
                " FROM scans ORDER BY id DESC LIMIT ?",
                (recent_limit,),
            ).fetchall()

        return {
            "total": total,
            "average_confidence": round(summary["conf"] or 0.0, 2),
            "average_latency_ms": round(summary["latency"] or 0.0, 1),
            "distribution": [
                {
                    "label": row["label"],
                    "count": row["count"],
                    "share": round(row["count"] * 100 / total, 1),
                    "average_confidence": round(row["confidence"] or 0.0, 2),
                }
                for row in distribution
            ],
            "recent": [dict(row) for row in recent],
        }

    def close(self) -> None:
        with self._lock:
            self._db.close()
