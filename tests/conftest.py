"""Shared test fixtures.

The API tests never load a real YOLOv8 checkpoint: ``LeafDetector`` is
replaced with a deterministic fake so the suite runs in seconds and stays
independent of the model file.
"""

from __future__ import annotations

from typing import Any

import cv2
import numpy as np
import pytest

from coffee_leaf import config


class FakeDetector:
    """Deterministic stand-in for :class:`coffee_leaf.detector.LeafDetector`."""

    def __init__(self, *_args: Any, **_kwargs: Any) -> None:
        self.weights_used = "models/fake.onnx"
        self.used_fallback = False
        self.class_names = {
            0: "bercak_phoma",
            1: "karat_daun",
            2: "pengorok_daun",
            3: "sehat",
        }

    @property
    def classes(self) -> list[str]:
        return sorted(self.class_names.values())

    @property
    def runtime(self) -> str:
        return "fake"

    def predict(self, image: np.ndarray, conf: float | None = None) -> dict[str, Any]:
        if image is None or image.size == 0:
            raise ValueError("Empty image passed to the detector")
        height, width = image.shape[:2]
        return {
            "annotated_image": "data:image/jpeg;base64,AAA",
            "original_image": "data:image/jpeg;base64,BBB",
            "cropped_image": "data:image/jpeg;base64,CCC",
            "detections": [
                {
                    "label": "karat_daun",
                    "confidence": 91.5,
                    "box": {"x1": 1, "y1": 2, "x2": 30, "y2": 40},
                }
            ],
            "dominant_class": "karat_daun",
            "frame": {"width": width, "height": height},
            "total_detections": 1,
            "inference_ms": 12.5,
        }


@pytest.fixture()
def leaf_jpeg() -> bytes:
    """A small synthetic leaf photo: a green disc on a dark background."""
    image = np.full((80, 80, 3), 35, dtype=np.uint8)
    cv2.circle(image, (40, 40), 26, (60, 170, 60), -1)  # BGR green
    ok, buffer = cv2.imencode(".jpg", image)
    assert ok
    return buffer.tobytes()


@pytest.fixture()
def app(tmp_path, monkeypatch):
    """Flask app wired to the fake detector and a throwaway database."""
    import coffee_leaf

    monkeypatch.setattr(coffee_leaf, "LeafDetector", FakeDetector)
    application = coffee_leaf.create_app(
        {"DATABASE_PATH": tmp_path / "test.sqlite3", "TESTING": True}
    )
    yield application
    application.extensions["store"].close()


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def labels() -> dict[str, str]:
    return config.CLASS_LABELS
