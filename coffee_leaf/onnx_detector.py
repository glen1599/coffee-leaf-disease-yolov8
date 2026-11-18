"""A light detector: the ONNX export run by ONNX Runtime, no PyTorch.

Same interface and same detections as :class:`coffee_leaf.detector.LeafDetector`,
in a fraction of the memory: the image needs no PyTorch or Ultralytics, which
is what lets the server fit a 512 MB free hosting plan. Select it with
``DETECTOR_BACKEND=onnx``.
"""

from __future__ import annotations

import ast
import base64
import logging
import time
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import onnxruntime as ort

from .onnx_pipeline import letterbox, postprocess, to_tensor
from .preprocess import auto_crop_leaf

logger = logging.getLogger(__name__)

# BGR colours for the boxes drawn on the web page, one per class index.
_PALETTE = ((56, 56, 255), (31, 112, 255), (29, 178, 255), (49, 210, 207))


class OnnxLeafDetector:
    """Runs ``models/best.onnx`` with the pipeline in :mod:`.onnx_pipeline`."""

    def __init__(
        self,
        onnx_weights: str | Path,
        conf_threshold: float = 0.25,
        jpeg_quality: int = 85,
        threads: int = 0,
    ) -> None:
        path = Path(onnx_weights)
        if not path.is_file():
            raise FileNotFoundError(
                f"{path} not found. The light detector needs the ONNX export; "
                "create it with `yolo export model=models/best.pt format=onnx`."
            )
        options = ort.SessionOptions()
        if threads:
            options.intra_op_num_threads = threads
        self.session = ort.InferenceSession(
            str(path), sess_options=options, providers=["CPUExecutionProvider"]
        )
        self.input_name = self.session.get_inputs()[0].name
        self.class_names = self._read_names(self.session)
        self.weights_used = str(path)
        self.used_fallback = False
        self.conf_threshold = conf_threshold
        self.jpeg_quality = jpeg_quality
        logger.info("Loaded ONNX export without PyTorch: %s", path)

    @staticmethod
    def _read_names(session: ort.InferenceSession) -> dict[int, str]:
        """Class names as Ultralytics stored them in the model's metadata."""
        raw = session.get_modelmeta().custom_metadata_map.get("names")
        if not raw:
            raise ValueError("The ONNX model carries no class names in its metadata")
        names = ast.literal_eval(raw)
        return {int(index): str(name) for index, name in names.items()}

    @property
    def runtime(self) -> str:
        return "onnxruntime"

    @property
    def classes(self) -> list[str]:
        return sorted(self.class_names.values())

    def _run(self, image: np.ndarray, conf: float | None) -> dict[str, Any]:
        if image is None or image.size == 0:
            raise ValueError("Empty image passed to the detector")

        threshold = self.conf_threshold if conf is None else conf
        started = time.perf_counter()
        height, width = image.shape[:2]
        padded, scale, left, top = letterbox(image)
        raw = self.session.run(None, {self.input_name: to_tensor(padded)})[0][0]
        detections = postprocess(
            raw,
            self.class_names,
            width=width,
            height=height,
            scale=scale,
            left=left,
            top=top,
            conf=threshold,
        )
        elapsed_ms = round((time.perf_counter() - started) * 1000, 1)

        return {
            "detections": detections,
            # Detections are sorted, so the first one is the most confident.
            "dominant_class": detections[0]["label"] if detections else None,
            "frame": {"width": width, "height": height},
            "total_detections": len(detections),
            "inference_ms": elapsed_ms,
        }

    def detect(self, image: np.ndarray, conf: float | None = None) -> dict[str, Any]:
        """Detections only; see :meth:`LeafDetector.detect`."""
        return self._run(image, conf)

    def predict(self, image: np.ndarray, conf: float | None = None) -> dict[str, Any]:
        """Detections plus the images for the web page; see :meth:`LeafDetector.predict`."""
        summary = self._run(image, conf)
        return {
            "annotated_image": self._encode_jpeg(self._draw(image, summary["detections"])),
            "original_image": self._encode_jpeg(image),
            "cropped_image": self._encode_jpeg(auto_crop_leaf(image)),
            **summary,
        }

    def _draw(self, image: np.ndarray, detections: list[dict[str, Any]]) -> np.ndarray:
        """Boxes with a "label 0.86" tag, in the style Ultralytics draws them."""
        canvas = image.copy()
        height, width = canvas.shape[:2]
        line = max(round((height + width) / 2 * 0.003), 2)
        font_scale = line / 3
        index_of = {name: index for index, name in self.class_names.items()}

        # Least confident first, so the surest boxes end up on top.
        for detection in reversed(detections):
            box = detection["box"]
            colour = _PALETTE[index_of.get(detection["label"], 0) % len(_PALETTE)]
            top_left, bottom_right = (box["x1"], box["y1"]), (box["x2"], box["y2"])
            cv2.rectangle(canvas, top_left, bottom_right, colour, line, cv2.LINE_AA)

            text = f"{detection['label']} {detection['confidence'] / 100:.2f}"
            (text_w, text_h), _ = cv2.getTextSize(
                text, cv2.FONT_HERSHEY_SIMPLEX, font_scale, max(line - 1, 1)
            )
            above = box["y1"] - text_h - 3 >= 0
            y_text = box["y1"] - 2 if above else box["y1"] + text_h + 2
            cv2.rectangle(
                canvas,
                (box["x1"], y_text - text_h - 2),
                (box["x1"] + text_w, y_text + 2),
                colour,
                -1,
                cv2.LINE_AA,
            )
            cv2.putText(
                canvas,
                text,
                (box["x1"], y_text),
                cv2.FONT_HERSHEY_SIMPLEX,
                font_scale,
                (255, 255, 255),
                max(line - 1, 1),
                cv2.LINE_AA,
            )
        return canvas

    def _encode_jpeg(self, image: np.ndarray) -> str:
        ok, buffer = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality])
        if not ok:
            raise RuntimeError("Failed to encode the image as JPEG")
        return "data:image/jpeg;base64," + base64.b64encode(buffer.tobytes()).decode("ascii")
