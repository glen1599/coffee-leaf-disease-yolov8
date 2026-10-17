"""Coffee Leaf Disease Detection - Flask application factory."""

from __future__ import annotations

import logging

from flask import Flask, jsonify

from .config import (
    APP_NAME,
    APP_VERSION,
    BASE_DIR,
    CONF_THRESHOLD,
    FALLBACK_WEIGHTS,
    JPEG_QUALITY,
    MAX_CONTENT_LENGTH,
    MODEL_PATH,
)
from .detector import LeafDetector
from .routes import bp


def create_app() -> Flask:
    """Build and configure the Flask application.

    Loading the YOLOv8 checkpoint is the expensive step, so it happens once
    here and the instance is shared through ``app.extensions``.
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
        JSON_SORT_KEYS=False,
    )
    app.extensions["detector"] = LeafDetector(
        MODEL_PATH, FALLBACK_WEIGHTS, CONF_THRESHOLD, JPEG_QUALITY
    )
    app.register_blueprint(bp)

    @app.errorhandler(413)
    def payload_too_large(_error):
        limit = MAX_CONTENT_LENGTH // (1024 * 1024)
        return jsonify({"error": f"File exceeds the {limit} MB upload limit."}), 413

    return app
