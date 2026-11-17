"""Contract tests for the versioned JSON API consumed by the mobile app."""

from __future__ import annotations

import io

import pytest

from coffee_leaf import config, content

LEGACY_IMAGE_FIELDS = {"annotated_image", "original_image", "cropped_image"}


def _predict(client, payload: bytes, filename: str = "leaf.jpg", **fields: str):
    return client.post(
        "/api/v1/predict",
        data={"file": (io.BytesIO(payload), filename), **fields},
        content_type="multipart/form-data",
    )


def _error(response) -> dict[str, str]:
    body = response.get_json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message"}
    assert body["error"]["message"]
    return body["error"]


# --- /api/v1/health ---------------------------------------------------------


def test_health_reports_model_and_limits(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200

    payload = response.get_json()
    assert payload["status"] == "ok"
    assert payload["model"]["runtime"] == "fake"
    assert payload["model"]["using_fallback_weights"] is False
    assert payload["model"]["classes"] == sorted(config.CLASS_LABELS)
    assert payload["limits"]["max_upload_mb"] == config.MAX_CONTENT_LENGTH // (1024 * 1024)
    assert payload["limits"]["allowed_formats"] == sorted(config.ALLOWED_EXTENSIONS)
    assert payload["languages"] == list(content.LANGUAGES)


# --- /api/v1/diseases -------------------------------------------------------


def test_diseases_default_to_indonesian(client):
    response = client.get("/api/v1/diseases")
    assert response.status_code == 200

    payload = response.get_json()
    assert payload["language"] == "id"
    assert payload["count"] == len(config.DISEASE_INFO) == len(payload["diseases"])
    assert {item["id"] for item in payload["diseases"]} == set(config.CLASS_LABELS)
    assert payload["metrics"] == config.MODEL_METRICS
    assert payload["disclaimer"]

    rust = next(item for item in payload["diseases"] if item["id"] == "karat_daun")
    assert rust["name"] == "Karat Daun"
    assert rust["severity"] == "high"
    assert rust["severity_label"] == "Berbahaya"
    assert "Hemileia vastatrix" in rust["pathogen"]
    assert rust["sample_image"].endswith("/static/img/samples/coffee_leaf_rust.jpg")


def test_diseases_in_english_mirror_the_knowledge_base(client):
    payload = client.get("/api/v1/diseases?lang=en").get_json()
    assert payload["language"] == "en"
    for item in payload["diseases"]:
        source = config.DISEASE_INFO[item["id"]]
        assert item["name"] == source["label"]
        assert item["summary"] == source["summary"]
        assert item["symptoms"] == source["symptoms"]
        assert item["treatment"] == source["treatment"]


def test_diseases_reject_an_unknown_language(client):
    response = client.get("/api/v1/diseases?lang=fr")
    assert response.status_code == 400
    assert _error(response)["code"] == "invalid_language"


def test_indonesian_translation_stays_in_step_with_the_source():
    """A translated entry may never add or drop a symptom or a treatment step."""
    assert set(content.DISEASE_INFO_ID) == set(config.DISEASE_INFO)
    for key, source in config.DISEASE_INFO.items():
        translated = content.DISEASE_INFO_ID[key]
        assert len(translated["symptoms"]) == len(source["symptoms"]), key
        assert len(translated["treatment"]) == len(source["treatment"]), key
        for field in ("label", "status", "pathogen", "summary"):
            assert translated[field], (key, field)


@pytest.mark.parametrize(
    ("percent", "level"),
    [(100.0, "high"), (85.0, "high"), (84.99, "medium"), (60.0, "medium"), (59.99, "low")],
)
def test_confidence_levels_follow_the_configured_thresholds(percent, level):
    assert content.confidence_level(percent) == level


# --- /api/v1/predict --------------------------------------------------------


def test_predict_returns_a_lean_indonesian_payload(client, leaf_jpeg):
    response = _predict(client, leaf_jpeg)
    assert response.status_code == 200

    payload = response.get_json()
    assert payload["detected"] is True
    assert payload["message"] is None
    assert payload["disease"]["id"] == "karat_daun"
    assert payload["disease"]["name"] == "Karat Daun"
    assert payload["disease"]["severity"] == "high"
    assert payload["disease"]["severity_label"] == "Berbahaya"
    assert len(payload["disease"]["treatment"]) == 4
    assert payload["confidence"] == {"value": 91.5, "level": "high", "label": "Sangat yakin"}
    assert payload["detections"] == [
        {
            "class_id": "karat_daun",
            "name": "Karat Daun",
            "confidence": 91.5,
            "box": {"x1": 1, "y1": 2, "x2": 30, "y2": 40},
        }
    ]
    assert payload["total_detections"] == 1
    assert payload["image"] == {"width": 80, "height": 80}
    assert payload["inference_ms"] == 12.5
    assert payload["disclaimer"]
    # The mobile client draws the boxes itself: no base64 images on the wire.
    assert LEGACY_IMAGE_FIELDS.isdisjoint(payload)


def test_predict_can_answer_in_english(client, leaf_jpeg):
    payload = _predict(client, leaf_jpeg, lang="en").get_json()
    assert payload["disease"]["name"] == "Coffee Leaf Rust"
    assert payload["disease"]["severity_label"] == "Dangerous"
    assert payload["confidence"]["label"] == "Very confident"


def test_predict_requires_a_file(client):
    response = client.post("/api/v1/predict")
    assert response.status_code == 400
    assert _error(response)["code"] == "missing_file"


def test_predict_rejects_an_unsupported_extension(client, leaf_jpeg):
    response = _predict(client, leaf_jpeg, filename="notes.txt")
    assert response.status_code == 415
    error = _error(response)
    assert error["code"] == "unsupported_format"
    assert "JPG" in error["message"]


def test_predict_rejects_an_undecodable_payload(client):
    response = _predict(client, b"this is not an image")
    assert response.status_code == 400
    assert _error(response)["code"] == "invalid_image"


def test_predict_rejects_an_oversized_upload(app, client, leaf_jpeg):
    app.config["MAX_CONTENT_LENGTH"] = 64
    response = _predict(client, leaf_jpeg)
    assert response.status_code == 413
    assert _error(response)["code"] == "file_too_large"


def test_predict_rejects_an_unknown_language(client, leaf_jpeg):
    response = _predict(client, leaf_jpeg, lang="xx")
    assert response.status_code == 400
    assert _error(response)["code"] == "invalid_language"


@pytest.mark.parametrize("conf", ["0.0", "1.0", "not-a-number", ""])
def test_predict_clamps_or_ignores_confidence(client, leaf_jpeg, conf):
    assert _predict(client, leaf_jpeg, conf=conf).status_code == 200


def test_predict_reports_a_photo_without_a_leaf(app, client, leaf_jpeg, monkeypatch):
    def nothing_found(image, conf=None):
        return {
            "detections": [],
            "dominant_class": None,
            "frame": {"width": 80, "height": 80},
            "total_detections": 0,
            "inference_ms": 9.0,
        }

    monkeypatch.setattr(app.extensions["detector"], "detect", nothing_found)

    response = _predict(client, leaf_jpeg)
    assert response.status_code == 200

    payload = response.get_json()
    assert payload["detected"] is False
    assert payload["disease"] is None
    assert payload["confidence"] is None
    assert payload["detections"] == []
    assert "Daun kopi tidak terlihat" in payload["message"]


def test_predict_turns_an_inference_failure_into_json(app, client, leaf_jpeg, monkeypatch):
    def boom(image, conf=None):
        raise RuntimeError("model exploded")

    monkeypatch.setattr(app.extensions["detector"], "detect", boom)

    response = _predict(client, leaf_jpeg)
    assert response.status_code == 500
    error = _error(response)
    assert error["code"] == "inference_failed"
    assert "exploded" not in error["message"]


def test_predict_is_rate_limited(app, client, leaf_jpeg):
    app.config.update(RATE_LIMIT_MAX=1, RATE_LIMIT_WINDOW=60)

    assert _predict(client, leaf_jpeg).status_code == 200

    blocked = _predict(client, leaf_jpeg)
    assert blocked.status_code == 429
    assert _error(blocked)["code"] == "rate_limited"
    assert blocked.headers["Retry-After"] == "60"


def test_predict_is_recorded_in_the_anonymous_scan_log(client, leaf_jpeg):
    _predict(client, leaf_jpeg)

    stats = client.get("/api/stats").get_json()
    assert stats["total"] == 1
    assert stats["recent"][0]["source"] == "api_v1"
    assert stats["recent"][0]["label"] == "karat_daun"


# --- routing errors under /api/v1 -------------------------------------------


def test_unknown_v1_route_answers_in_the_v1_error_format(client):
    response = client.get("/api/v1/nope")
    assert response.status_code == 404
    assert _error(response)["code"] == "not_found"


def test_wrong_method_answers_in_the_v1_error_format(client):
    response = client.get("/api/v1/predict")
    assert response.status_code == 405
    assert _error(response)["code"] == "method_not_allowed"


# --- the web application keeps its own contract -----------------------------


def test_legacy_predict_still_ships_the_rendered_images(client, leaf_jpeg):
    response = client.post(
        "/predict",
        data={"file": (io.BytesIO(leaf_jpeg), "leaf.jpg")},
        content_type="multipart/form-data",
    )
    payload = response.get_json()
    assert set(payload) >= LEGACY_IMAGE_FIELDS
    assert payload["info"]["label"] == "Coffee Leaf Rust"


def test_legacy_errors_keep_their_plain_string_shape(client):
    assert client.post("/predict").get_json() == {"error": "No image file was uploaded."}
    assert client.get("/nope").get_json() == {"error": "Not found."}
