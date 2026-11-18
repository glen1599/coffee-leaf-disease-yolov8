"""The light detector (ONNX Runtime only) must find what the server finds.

``mobile/test/fixtures/expected.json`` holds the detections the Ultralytics
server produced on the four sample photos (written and checked by
``scripts/export_mobile_fixtures.py``). The light detector is compared
against them, so swapping backends can never change a result unnoticed.

The model file used here is the copy the mobile app ships, which is
versioned; ``models/best.onnx`` is not.
"""

from __future__ import annotations

import base64
import json
from pathlib import Path

import cv2
import numpy as np
import pytest

from coffee_leaf.onnx_detector import OnnxLeafDetector

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "mobile" / "assets" / "models" / "best.onnx"
EXPECTED = json.loads((ROOT / "mobile" / "test" / "fixtures" / "expected.json").read_text())
SAMPLES = EXPECTED["samples"]


@pytest.fixture(scope="module")
def detector() -> OnnxLeafDetector:
    return OnnxLeafDetector(MODEL)


def _photo(key: str) -> np.ndarray:
    image = cv2.imread(str(ROOT / "static" / "img" / "samples" / SAMPLES[key]["file"]))
    assert image is not None
    return image


def test_reads_the_class_names_from_the_model(detector):
    assert detector.class_names == {
        0: "bercak_phoma",
        1: "karat_daun",
        2: "pengorok_daun",
        3: "sehat",
    }
    assert detector.runtime == "onnxruntime"
    assert detector.used_fallback is False


@pytest.mark.parametrize("key", sorted(SAMPLES))
def test_finds_exactly_what_the_server_finds(detector, key):
    expected = SAMPLES[key]["detections"]

    result = detector.detect(_photo(key))

    assert result["total_detections"] == len(expected)
    assert result["dominant_class"] == key
    assert result["frame"] == {"width": SAMPLES[key]["width"], "height": SAMPLES[key]["height"]}
    by_box = lambda items: sorted(  # noqa: E731
        items, key=lambda item: (item["box"]["x1"], item["box"]["y1"], item["label"])
    )
    for got, want in zip(by_box(result["detections"]), by_box(expected), strict=True):
        assert got["label"] == want["label"]
        assert got["box"] == want["box"]
        assert got["confidence"] == pytest.approx(want["confidence"], abs=0.01)


def test_detections_come_most_confident_first(detector):
    scores = [item["confidence"] for item in detector.detect(_photo("karat_daun"))["detections"]]
    assert scores == sorted(scores, reverse=True)


def test_a_higher_threshold_keeps_fewer_findings(detector):
    image = _photo("karat_daun")
    assert detector.detect(image, conf=0.8)["total_detections"] < len(
        SAMPLES["karat_daun"]["detections"]
    )


def test_predict_also_returns_the_images_for_the_web_page(detector):
    image = _photo("pengorok_daun")

    result = detector.predict(image)

    for field in ("annotated_image", "original_image", "cropped_image"):
        assert result[field].startswith("data:image/jpeg;base64,")
    annotated = cv2.imdecode(
        np.frombuffer(base64.b64decode(result["annotated_image"].split(",", 1)[1]), np.uint8),
        cv2.IMREAD_COLOR,
    )
    assert annotated.shape == image.shape
    assert not np.array_equal(annotated, image)  # the boxes were drawn


def test_rejects_an_empty_image(detector):
    with pytest.raises(ValueError):
        detector.detect(np.zeros((0, 0, 3), dtype=np.uint8))


def test_explains_a_missing_model(tmp_path):
    with pytest.raises(FileNotFoundError, match="ONNX export"):
        OnnxLeafDetector(tmp_path / "missing.onnx")


def test_the_app_can_run_on_the_light_detector(tmp_path):
    import coffee_leaf

    app = coffee_leaf.create_app(
        {
            "DATABASE_PATH": tmp_path / "light.sqlite3",
            "TESTING": True,
            "DETECTOR_BACKEND": "onnx",
            "ONNX_MODEL_PATH": MODEL,
        }
    )
    try:
        client = app.test_client()
        health = client.get("/api/v1/health").get_json()
        assert health["model"]["runtime"] == "onnxruntime"

        ok, jpeg = cv2.imencode(".jpg", _photo("sehat"))
        assert ok
        import io

        payload = client.post(
            "/api/v1/predict",
            data={"file": (io.BytesIO(jpeg.tobytes()), "leaf.jpg")},
            content_type="multipart/form-data",
        ).get_json()
        assert payload["disease"]["id"] == "sehat"
    finally:
        app.extensions["store"].close()


def test_an_unknown_backend_is_refused(tmp_path):
    import coffee_leaf

    with pytest.raises(ValueError, match="DETECTOR_BACKEND"):
        coffee_leaf.create_app(
            {"DATABASE_PATH": tmp_path / "x.sqlite3", "DETECTOR_BACKEND": "tensorflow"}
        )
