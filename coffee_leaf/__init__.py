"""Coffee Leaf Disease Detection - Flask application factory."""

from __future__ import annotations

import logging
from collections.abc import Mapping
from typing import Any

from flask import Flask, jsonify, request, url_for

from .config import (
    APP_NAME,
    APP_VERSION,
    BASE_DIR,
    CONF_THRESHOLD,
    DATABASE_PATH,
    FALLBACK_WEIGHTS,
    JPEG_QUALITY,
    MAX_CONTENT_LENGTH,
    MODEL_PATH,
    ONNX_MODEL_PATH,
    RATE_LIMIT_MAX,
    RATE_LIMIT_WINDOW,
    SECURITY_HEADERS,
)
from .detector import LeafDetector
from .routes import bp
from .store import Store


def asset(filename: str) -> str:
    """Static URL carrying a content version, so a deploy busts the cache.

    The stylesheet and the scripts are served with a one-week ``max-age``;
    without this, a returning visitor keeps the previous build.
    """
    try:
        version = int((BASE_DIR / "static" / filename).stat().st_mtime)
    except OSError:
        version = 0
    return url_for("static", filename=filename, v=version)


def create_app(config_overrides: Mapping[str, Any] | None = None) -> Flask:
    """Build and configure the Flask application.

    Loading the detector and opening the store are the expensive steps, so
    both happen once here and are shared through ``app.extensions``.

    Args:
        config_overrides: Values merged into ``app.config`` before the store
            is opened. Used by the test suite to isolate the database.
    """
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    )

    app = Flask(
        APP_NAME,
        template_folder=str(BASE_DIR / "templates"),
        static_folder=str(BASE_DIR / "static"),
    )
    app.config.update(
        APP_VERSION=APP_VERSION,
        MAX_CONTENT_LENGTH=MAX_CONTENT_LENGTH,
        DATABASE_PATH=DATABASE_PATH,
        RATE_LIMIT_MAX=RATE_LIMIT_MAX,
        RATE_LIMIT_WINDOW=RATE_LIMIT_WINDOW,
        JSON_SORT_KEYS=False,
    )
    if config_overrides:
        app.config.update(config_overrides)

    app.extensions["store"] = Store(app.config["DATABASE_PATH"])
    app.extensions["detector"] = LeafDetector(
        MODEL_PATH, ONNX_MODEL_PATH, FALLBACK_WEIGHTS, CONF_THRESHOLD, JPEG_QUALITY
    )
    app.jinja_env.globals["asset"] = asset
    app.register_blueprint(bp)

    @app.after_request
    def harden(response):
        """Apply the hardening headers declared in the config."""
        response.headers.update(SECURITY_HEADERS)
        if request.path.startswith("/static/"):
            response.headers["Cache-Control"] = "public, max-age=604800"
        return response

    @app.errorhandler(413)
    def payload_too_large(_error):
        limit = MAX_CONTENT_LENGTH // (1024 * 1024)
        return jsonify({"error": f"File exceeds the {limit} MB upload limit."}), 413

    @app.errorhandler(404)
    def not_found(_error):
        if request.path.startswith("/api/") or request.path.startswith("/predict"):
            return jsonify({"error": "Not found."}), 404
        return jsonify({"error": "Not found."}), 404

    return app
