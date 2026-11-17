"""Versioned JSON API for native clients (the mobile app).

It lives next to the web routes in ``coffee_leaf.routes`` and never changes
them. Compared with the legacy ``/predict`` it differs in three ways:

* responses carry no base64 images -- a phone already holds the photograph and
  draws the boxes itself, so a reply is a few kilobytes instead of a megabyte;
* text is localised (Indonesian by default, ``?lang=en`` for English);
* every error has the same shape: ``{"error": {"code": ..., "message": ...}}``.
"""

from __future__ import annotations

import logging
from typing import Any

from flask import Blueprint, Response, current_app, g, jsonify, request, url_for
from werkzeug.exceptions import RequestEntityTooLarge

from . import content
from .config import ALLOWED_EXTENSIONS, DISEASE_INFO, MODEL_METRICS, SAMPLES
from .detector import LeafDetector
from .ratelimit import client_allowed
from .routes import _decode_image, _is_allowed, _resolve_confidence
from .store import Store

logger = logging.getLogger(__name__)

URL_PREFIX = "/api/v1"
bp = Blueprint("api_v1", __name__, url_prefix=URL_PREFIX)

_MEGABYTE = 1024 * 1024


class ApiError(Exception):
    """A request that ends in a JSON error response."""

    def __init__(
        self,
        code: str,
        status: int,
        *,
        headers: dict[str, str] | None = None,
        **values: Any,
    ) -> None:
        super().__init__(code)
        self.code = code
        self.status = status
        self.headers = headers
        self.values = values


def _detector() -> LeafDetector:
    return current_app.extensions["detector"]


def _store() -> Store:
    return current_app.extensions["store"]


def _fallback_language() -> str:
    """Best language for an error reply, without touching the request body."""
    resolved = g.get("api_language")
    if resolved:
        return resolved
    requested = request.args.get("lang", "").strip().lower()
    return requested if requested in content.LANGUAGES else content.DEFAULT_LANGUAGE


def _language() -> str:
    """Resolve the ``lang`` parameter (query string or form field)."""
    requested = (request.values.get("lang") or "").strip().lower()
    if not requested:
        requested = content.DEFAULT_LANGUAGE
    if requested not in content.LANGUAGES:
        raise ApiError("invalid_language", 400, allowed=", ".join(content.LANGUAGES))
    g.api_language = requested
    return requested


def error_response(
    code: str,
    status: int,
    *,
    headers: dict[str, str] | None = None,
    **values: Any,
) -> Response:
    """Build the uniform error body used by every ``/api/v1`` endpoint."""
    text = content.message(code, _fallback_language(), **values)
    response = jsonify({"error": {"code": code, "message": text}})
    response.status_code = status
    if headers:
        response.headers.update(headers)
    return response


@bp.errorhandler(ApiError)
def _handle_api_error(error: ApiError) -> Response:
    return error_response(error.code, error.status, headers=error.headers, **error.values)


@bp.errorhandler(RequestEntityTooLarge)
def _handle_too_large(_error: RequestEntityTooLarge) -> Response:
    limit = max(1, (current_app.config["MAX_CONTENT_LENGTH"] or 0) // _MEGABYTE)
    return error_response("file_too_large", 413, limit=limit)


def _serialise(result: dict[str, Any], lang: str) -> dict[str, Any]:
    """Turn the detector summary into the mobile payload and log the scan."""
    dominant = result["dominant_class"]
    disease = content.disease_payload(dominant, lang) if dominant else None
    detected = disease is not None

    # With the COCO fallback weights the model can name classes this project
    # knows nothing about; those are not coffee-leaf findings.
    detections = [
        {
            "class_id": item["label"],
            "name": content.class_name(item["label"], lang),
            "confidence": item["confidence"],
            "box": item["box"],
        }
        for item in result["detections"]
        if detected and item["label"] in DISEASE_INFO
    ]
    top = max(
        (item["confidence"] for item in detections if item["class_id"] == dominant),
        default=None,
    )

    _store().record_scan(
        label=dominant if detected else None,
        confidence=top or 0.0,
        detections=len(detections),
        latency_ms=result["inference_ms"],
        source="api_v1",
    )

    return {
        "detected": detected,
        "disease": disease,
        "confidence": content.confidence_payload(top, lang) if top is not None else None,
        "detections": detections,
        "total_detections": len(detections),
        "image": result["frame"],
        "inference_ms": result["inference_ms"],
        "message": None if detected else content.message("no_leaf_detected", lang),
        "disclaimer": content.DISCLAIMER[lang],
    }


@bp.get("/health")
def health() -> Response:
    """Liveness probe with model provenance and the upload limits."""
    detector = _detector()
    return jsonify(
        {
            "status": "ok",
            "version": current_app.config["APP_VERSION"],
            "model": {
                "runtime": detector.runtime,
                "weights": detector.weights_used.split("/")[-1],
                "using_fallback_weights": detector.used_fallback,
                "classes": detector.classes,
            },
            "limits": {
                "max_upload_mb": current_app.config["MAX_CONTENT_LENGTH"] // _MEGABYTE,
                "allowed_formats": sorted(ALLOWED_EXTENSIONS),
            },
            "languages": list(content.LANGUAGES),
        }
    )


@bp.get("/diseases")
def diseases() -> Response:
    """The knowledge base: every class with its symptoms and treatment."""
    lang = _language()
    items = content.diseases_payload(lang)
    for item in items:
        item["sample_image"] = url_for("static", filename=SAMPLES[item["id"]], _external=True)
    return jsonify(
        {
            "language": lang,
            "count": len(items),
            "diseases": items,
            "metrics": MODEL_METRICS,
            "disclaimer": content.DISCLAIMER[lang],
        }
    )


@bp.post("/predict")
def predict() -> Response:
    """Detect disease on one uploaded photograph."""
    lang = _language()
    if not client_allowed():
        window = str(current_app.config["RATE_LIMIT_WINDOW"])
        raise ApiError("rate_limited", 429, headers={"Retry-After": window})

    file = request.files.get("file")
    if file is None or not file.filename:
        raise ApiError("missing_file", 400)
    if not _is_allowed(file.filename):
        allowed = ", ".join(sorted(extension.upper() for extension in ALLOWED_EXTENSIONS))
        raise ApiError("unsupported_format", 415, allowed=allowed)

    image = _decode_image(file.read())
    if image is None:
        raise ApiError("invalid_image", 400)

    try:
        result = _detector().detect(image, conf=_resolve_confidence(request.form.get("conf")))
    except MemoryError:
        logger.exception("Out of memory during inference")
        raise ApiError("out_of_memory", 500) from None
    except Exception:
        logger.exception("Inference failed")
        raise ApiError("inference_failed", 500) from None

    return jsonify(_serialise(result, lang))
