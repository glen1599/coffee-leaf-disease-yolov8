"""YOLOv8 + OpenCV inference service for coffee-leaf disease detection.

The model is loaded exactly once at application start-up and reused for
every request: ``LeafDetector`` is deliberately the only place that knows
about Ultralytics.
"""

from __future__ import annotations

import base64
import logging
import time
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from ultralytics import YOLO

from .preprocess import auto_crop_leaf

logger = logging.getLogger(__name__)


class LeafDetector:
    """Wraps the trained YOLOv8 checkpoint with the display pipeline."""

    def __init__(
        self,
        weights: str | Path,
        onnx_weights: str | Path | None = None,
        fallback_weights: str = "yolov8n.pt",
        conf_threshold: float = 0.25,
        jpeg_quality: int = 85,
    ) -> None:
        self.conf_threshold = conf_threshold
        self.jpeg_quality = jpeg_quality
        self.model, self.weights_used, self.used_fallback = self._load(
            Path(weights), Path(onnx_weights) if onnx_weights else None, fallback_weights
        )
        self.class_names: dict[int, str] = dict(self.model.names)

    @property
    def runtime(self) -> str:
        """Backend actually in use, derived from the loaded artefact."""
        suffix = Path(self.weights_used).suffix.lower()
        return {".onnx": "onnxruntime", ".pt": "pytorch", ".engine": "tensorrt"}.get(
            suffix, "ultralytics"
        )

    def _load(
        self, weights: Path, onnx_weights: Path | None, fallback: str
    ) -> tuple[YOLO, str, bool]:
        """Load the best available checkpoint, preferring the ONNX export.

        Ultralytics exposes the same API for every backend, so preferring ONNX
        is a one-line change with no downstream impact — and it removes the
        torch dependency from the request path.
        """
        if onnx_weights is not None and onnx_weights.is_file():
            logger.info("Loaded ONNX export: %s", onnx_weights)
            return YOLO(str(onnx_weights), task="detect"), str(onnx_weights), False
        if weights.is_file():
            logger.info("Loaded trained weights: %s", weights)
            return YOLO(str(weights)), str(weights), False
        logger.warning("Trained weights not found at %s - falling back to %s", weights, fallback)
        return YOLO(fallback), fallback, True

    @property
    def classes(self) -> list[str]:
        """Raw class names as stored in the checkpoint."""
        return sorted(self.class_names.values())

    def _encode_jpeg(self, image: np.ndarray) -> str:
        """Encode a BGR image as a base64 JPEG data URI."""
        ok, buffer = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality])
        if not ok:
            raise RuntimeError("Failed to encode the image as JPEG")
        return "data:image/jpeg;base64," + base64.b64encode(buffer.tobytes()).decode("ascii")

    def predict(self, image: np.ndarray, conf: float | None = None) -> dict[str, Any]:
        """Run detection on a BGR image and return a JSON-serialisable payload.

        Args:
            image: BGR uint8 array (as returned by ``cv2.imdecode``).
            conf: Optional confidence override; falls back to the configured
                threshold when ``None``.

        Returns:
            A mapping with the annotated/original/cropped data URIs, the raw
            detections, the dominant class, the frame size and the latency.

        Raises:
            ValueError: If ``image`` is empty or not a valid array.
        """
        if image is None or image.size == 0:
            raise ValueError("Empty image passed to the detector")

        threshold = self.conf_threshold if conf is None else conf
        started = time.perf_counter()
        result = self.model(image, conf=threshold, verbose=False)[0]
        elapsed_ms = round((time.perf_counter() - started) * 1000, 1)

        height, width = image.shape[:2]
        detections: list[dict[str, Any]] = []
        best_score: dict[str, float] = {}

        for box in result.boxes:
            label = self.class_names[int(box.cls[0])]
            score = float(box.conf[0])
            x1, y1, x2, y2 = (float(value) for value in box.xyxy[0])
            detections.append(
                {
                    "label": label,
                    "confidence": round(score * 100, 2),
                    "box": {
                        "x1": round(x1),
                        "y1": round(y1),
                        "x2": round(x2),
                        "y2": round(y2),
                    },
                }
            )
            best_score[label] = max(best_score.get(label, 0.0), score)

        # The dominant class is the one with the single highest confidence.
        dominant = max(best_score, key=lambda label: best_score[label]) if best_score else None

        return {
            "annotated_image": self._encode_jpeg(result.plot()),
            "original_image": self._encode_jpeg(image),
            "cropped_image": self._encode_jpeg(auto_crop_leaf(image)),
            "detections": detections,
            "dominant_class": dominant,
            "frame": {"width": width, "height": height},
            "total_detections": len(detections),
            "inference_ms": elapsed_ms,
        }
