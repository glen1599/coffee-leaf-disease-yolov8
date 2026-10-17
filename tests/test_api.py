"""Contract tests for the HTTP API."""

from __future__ import annotations

import base64
import io

import pytest


def _upload(client, payload: bytes, filename: str = "leaf.jpg", conf: str = "0.25"):
    return client.post(
        "/predict",
        data={"file": (io.BytesIO(payload), filename), "conf": conf},
        content_type="multipart/form-data",
    )


# --- static and meta endpoints -------------------------------------------


def test_index_renders(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Coffee leaf" in response.data or b"coffee leaf" in response.data


def test_health_reports_model_provenance(client):
    payload = client.get("/health").get_json()
    assert payload["status"] == "ok"
    assert payload["using_fallback_weights"] is False
    assert payload["runtime"] == "fake"
    assert sorted(payload["classes"]) == [
        "bercak_phoma",
        "karat_daun",
        "pengorok_daun",
        "sehat",
    ]


def test_security_headers_present(client):
    headers = client.get("/").headers
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["X-Frame-Options"] == "DENY"
    assert "default-src 'self'" in headers["Content-Security-Policy"]
    assert "frame-ancestors 'none'" in headers["Content-Security-Policy"]


def test_static_assets_are_cacheable(client):
    response = client.get("/static/img/favicon.svg")
    assert response.status_code == 200
    assert "max-age" in response.headers.get("Cache-Control", "")


# --- /predict --------------------------------------------------------------


def test_predict_returns_enriched_payload(client, leaf_jpeg):
    response = _upload(client, leaf_jpeg)
    assert response.status_code == 200

    payload = response.get_json()
    assert payload["dominant_class"] == "karat_daun"
    assert payload["severity"] == "high"
    assert payload["info"]["label"] == "Coffee Leaf Rust"
    assert payload["detections"][0]["label_text"] == "Coffee Leaf Rust"


def test_predict_requires_a_file(client):
    response = client.post("/predict")
    assert response.status_code == 400
    assert "error" in response.get_json()


def test_predict_rejects_blank_filename(client, leaf_jpeg):
    response = client.post(
        "/predict",
        data={"file": (io.BytesIO(leaf_jpeg), "")},
        content_type="multipart/form-data",
    )
    assert response.status_code == 400


def test_predict_rejects_unsupported_extension(client, leaf_jpeg):
    response = _upload(client, leaf_jpeg, filename="notes.txt")
    assert response.status_code == 400
    assert "Unsupported format" in response.get_json()["error"]


def test_predict_rejects_undecodable_payload(client):
    response = _upload(client, b"this is not an image")
    assert response.status_code == 400
    assert "decodable" in response.get_json()["error"]


@pytest.mark.parametrize("conf", ["0.0", "1.0", "not-a-number", ""])
def test_predict_clamps_or_ignores_confidence(client, leaf_jpeg, conf):
    assert _upload(client, leaf_jpeg, conf=conf).status_code == 200


# --- /predict/batch --------------------------------------------------------


def test_batch_analyses_every_uploaded_file(client, leaf_jpeg):
    data = {
        "files": [
            (io.BytesIO(leaf_jpeg), "a.jpg"),
            (io.BytesIO(leaf_jpeg), "b.jpg"),
        ],
        "conf": "0.25",
    }
    payload = client.post(
        "/predict/batch", data=data, content_type="multipart/form-data"
    ).get_json()
    assert payload["count"] == 2
    assert [item["filename"] for item in payload["items"]] == ["a.jpg", "b.jpg"]
    assert all(item["dominant_class"] == "karat_daun" for item in payload["items"])


def test_batch_records_per_item_errors(client, leaf_jpeg):
    data = {
        "files": [
            (io.BytesIO(leaf_jpeg), "good.jpg"),
            (io.BytesIO(b"nope"), "broken.jpg"),
        ]
    }
    payload = client.post(
        "/predict/batch", data=data, content_type="multipart/form-data"
    ).get_json()
    assert "dominant_class" in payload["items"][0]
    assert "error" in payload["items"][1]


def test_batch_rejects_empty_and_oversized_requests(client, leaf_jpeg):
    assert client.post("/predict/batch", data={}).status_code == 400

    files = [(io.BytesIO(leaf_jpeg), f"{index}.jpg") for index in range(9)]
    response = client.post(
        "/predict/batch",
        data={"files": files},
        content_type="multipart/form-data",
    )
    assert response.status_code == 400
    assert "at most" in response.get_json()["error"].lower()


# --- /predict/camera -------------------------------------------------------


def test_camera_accepts_a_data_uri(client, leaf_jpeg):
    encoded = base64.b64encode(leaf_jpeg).decode()
    response = client.post("/predict/camera", json={"image": f"data:image/jpeg;base64,{encoded}"})
    assert response.status_code == 200
    assert response.get_json()["dominant_class"] == "karat_daun"


def test_camera_rejects_missing_or_invalid_frames(client):
    assert client.post("/predict/camera", json={}).status_code == 400
    assert client.post("/predict/camera", json={"image": 42}).status_code == 400
    assert (
        client.post("/predict/camera", json={"image": "data:image/jpeg;base64,!!!"}).status_code
        == 400
    )


# --- stats and rate limiting ----------------------------------------------


def test_stats_aggregate_recorded_scans(client, leaf_jpeg):
    assert client.get("/api/stats").get_json()["total"] == 0

    _upload(client, leaf_jpeg)
    _upload(client, leaf_jpeg)

    stats = client.get("/api/stats").get_json()
    assert stats["total"] == 2
    assert stats["distribution"][0]["label"] == "karat_daun"
    assert stats["distribution"][0]["share"] == 100.0
    assert stats["average_confidence"] == pytest.approx(91.5)
    assert len(stats["recent"]) == 2


def test_rate_limit_returns_429(app, client, leaf_jpeg):
    app.config.update(RATE_LIMIT_MAX=2, RATE_LIMIT_WINDOW=60)

    assert _upload(client, leaf_jpeg).status_code == 200
    assert _upload(client, leaf_jpeg).status_code == 200

    blocked = _upload(client, leaf_jpeg)
    assert blocked.status_code == 429
    assert "Too many requests" in blocked.get_json()["error"]


def test_rate_limit_window_is_per_client(app):
    store = app.extensions["store"]
    assert all(store.allow("10.0.0.1", limit=3, window=60) for _ in range(3))
    assert store.allow("10.0.0.1", limit=3, window=60) is False
    # A different client keeps its own window.
    assert store.allow("10.0.0.2", limit=3, window=60) is True
