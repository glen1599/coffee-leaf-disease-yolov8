"""HTTP layer: routing, request validation and JSON serialisation."""

from __future__ import annotations

import base64
import binascii
import logging
from typing import Any

import cv2
import numpy as np
from flask import Blueprint, current_app, jsonify, render_template, request

from .config import (
    ALLOWED_EXTENSIONS,
    CLASS_LABELS,
    DISEASE_INFO,
    MAX_BATCH_FILES,
    MAX_CONTENT_LENGTH,
    MODEL_METRICS,
    SAMPLES,
)
from .detector import LeafDetector
from .ratelimit import rate_limit
from .store import Store

logger = logging.getLogger(__name__)

bp = Blueprint("main", __name__)

# Upper bound for a single base64 camera frame.
MAX_FRAME_BYTES = 8 * 1024 * 1024


def _detector() -> LeafDetector:
    """Return the process-wide detector created by the app factory."""
    return current_app.extensions["detector"]


def _store() -> Store:
    """Return the process-wide SQLite store created by the app factory."""
    return current_app.extensions["store"]


def _is_allowed(filename: str) -> bool:
    """Check the file extension against the allow-list."""
    return "." in filename and filename.rsplit(".", 1)[-1].lower() in ALLOWED_EXTENSIONS


def _decode_image(payload: bytes) -> np.ndarray | None:
    """Decode raw image bytes into a BGR array, or ``None`` when unusable.

    Images above ``MAX_IMAGE_PIXELS`` are refused by OpenCV itself, which is
    the decompression-bomb guard configured in ``coffee_leaf.config``.
    """
    buffer = np.frombuffer(payload, dtype=np.uint8)
    return cv2.imdecode(buffer, cv2.IMREAD_COLOR)


def _resolve_confidence(raw: Any) -> float | None:
    """Clamp a client-provided confidence value, ignoring malformed input."""
    if raw in (None, ""):
        return None
    try:
        return min(max(float(raw), 0.05), 0.95)
    except (TypeError, ValueError):
        return None


def _enrich(result: dict[str, Any], source: str) -> dict[str, Any]:
    """Attach display labels, the knowledge base and log the anonymous scan."""
    for detection in result["detections"]:
        detection["label_text"] = CLASS_LABELS.get(detection["label"], detection["label"])
    info = DISEASE_INFO.get(result["dominant_class"])
    result["info"] = info
    result["severity"] = info["severity"] if info else "unknown"

    top = max((d["confidence"] for d in result["detections"]), default=0.0)
    _store().record_scan(
        label=result["dominant_class"],
        confidence=top,
        detections=result["total_detections"],
        latency_ms=result["inference_ms"],
        source=source,
    )
    return result


def _infer(image: np.ndarray, conf: float | None, source: str):
    """Run inference and translate failures into HTTP responses."""
    try:
        result = _detector().predict(image, conf=conf)
        return jsonify(_enrich(result, source)), 200
    except MemoryError:
        logger.exception("Out of memory during inference")
        return jsonify({"error": "Server ran out of memory. Try a smaller image."}), 500
    except Exception:
        logger.exception("Inference failed")
        return jsonify({"error": "Internal inference error. Please try again."}), 500


@bp.get("/")
def index():
    """Render the single-page application shell."""
    detector = _detector()
    return render_template(
        "index.html",
        metrics=MODEL_METRICS,
        diseases=DISEASE_INFO,
        class_labels=CLASS_LABELS,
        samples={key: f"img/samples/{path.split('/')[-1]}" for key, path in SAMPLES.items()},
        max_upload_mb=MAX_CONTENT_LENGTH // (1024 * 1024),
        max_batch=MAX_BATCH_FILES,
        runtime=detector.runtime,
        weights_name=detector.weights_used.split("/")[-1],
        using_fallback=detector.used_fallback,
    )


@bp.get("/health")
def health():
    """Liveness probe with model provenance."""
    detector = _detector()
    return jsonify(
        {
            "status": "ok",
            "version": current_app.config["APP_VERSION"],
            "weights": detector.weights_used,
            "runtime": detector.runtime,
            "using_fallback_weights": detector.used_fallback,
            "classes": detector.classes,
        }
    )


@bp.get("/api/stats")
def stats():
    """Aggregate activity for the dashboard panel (anonymous counts only)."""
    return jsonify(_store().stats())


@bp.post("/predict")
@rate_limit
def predict():
    """Classify an uploaded image file."""
    file = request.files.get("file")
    if file is None or not file.filename:
        return jsonify({"error": "No image file was uploaded."}), 400
    if not _is_allowed(file.filename):
        allowed = ", ".join(sorted(extension.upper() for extension in ALLOWED_EXTENSIONS))
        return jsonify({"error": f"Unsupported format. Allowed: {allowed}."}), 400

    image = _decode_image(file.read())
    if image is None:
        return jsonify({"error": "The uploaded file is not a decodable image."}), 400

    return _infer(image, _resolve_confidence(request.form.get("conf")), "upload")


@bp.post("/predict/batch")
@rate_limit
def predict_batch():
    """Classify several uploaded images in one request."""
    files = [f for f in request.files.getlist("files") if f and f.filename]
    if not files:
        return jsonify({"error": "No image files were uploaded."}), 400
    if len(files) > MAX_BATCH_FILES:
        return jsonify({"error": f"At most {MAX_BATCH_FILES} images can be analysed at once."}), 400

    conf = _resolve_confidence(request.form.get("conf"))
    items: list[dict[str, Any]] = []
    for file in files:
        if not _is_allowed(file.filename):
            items.append({"filename": file.filename, "error": "Unsupported format."})
            continue
        image = _decode_image(file.read())
        if image is None:
            items.append({"filename": file.filename, "error": "Not a decodable image."})
            continue
        try:
            payload = _enrich(_detector().predict(image, conf=conf), "batch")
            payload["filename"] = file.filename
        except Exception:
            logger.exception("Batch item failed: %s", file.filename)
            payload = {"filename": file.filename, "error": "Inference failed."}
        items.append(payload)

    return jsonify({"count": len(items), "items": items}), 200


@bp.post("/predict/camera")
@rate_limit
def predict_camera():
    """Classify a base64-encoded frame captured from the browser camera."""
    payload = request.get_json(silent=True)
    if not payload or not isinstance(payload.get("image"), str):
        return jsonify({"error": "No image frame was provided."}), 400

    encoded = payload["image"].split(",", 1)[-1]
    if len(encoded) > MAX_FRAME_BYTES:
        return jsonify({"error": "The camera frame is too large."}), 413

    try:
        raw = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError):
        return jsonify({"error": "The camera frame is not valid base64 data."}), 400

    image = _decode_image(raw)
    if image is None:
        return jsonify({"error": "The camera frame could not be decoded."}), 400

    return _infer(image, _resolve_confidence(payload.get("conf")), "camera")
