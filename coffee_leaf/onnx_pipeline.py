"""The YOLOv8 detection pipeline in NumPy + OpenCV, without Ultralytics.

Ultralytics does three things around the network itself: letterbox the photo
to 640 x 640, decode the raw ``[1, 4 + classes, 8400]`` output, and run
class-aware non-maximum suppression. Doing them here lets the server run the
ONNX export with ONNX Runtime alone (no PyTorch), and is the same pipeline the
mobile app ports to Dart. ``scripts/export_mobile_fixtures.py`` checks that it
matches Ultralytics on every sample photo.
"""

from __future__ import annotations

from typing import Any

import cv2
import numpy as np

INPUT_SIZE = 640
PAD_VALUE = 114
IOU_THRESHOLD = 0.7
MAX_DETECTIONS = 300
# Boxes of different classes never suppress each other: shifting each class
# far apart before NMS is how Ultralytics does it.
CLASS_OFFSET = 7680.0

Detection = dict[str, Any]


def letterbox(image: np.ndarray) -> tuple[np.ndarray, float, int, int]:
    """Resize ``image`` to fit a grey 640 x 640 square, keeping its aspect ratio.

    Returns the padded image, the scale that was applied and the left / top
    padding, which are needed to map boxes back to the original photo.
    """
    height, width = image.shape[:2]
    scale = min(INPUT_SIZE / height, INPUT_SIZE / width)
    new_width, new_height = round(width * scale), round(height * scale)
    pad_x, pad_y = (INPUT_SIZE - new_width) / 2, (INPUT_SIZE - new_height) / 2

    if (width, height) != (new_width, new_height):
        image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
    top, bottom = round(pad_y - 0.1), round(pad_y + 0.1)
    left, right = round(pad_x - 0.1), round(pad_x + 0.1)
    padded = cv2.copyMakeBorder(
        image, top, bottom, left, right, cv2.BORDER_CONSTANT, value=(PAD_VALUE,) * 3
    )
    return padded, scale, left, top


def to_tensor(padded_bgr: np.ndarray) -> np.ndarray:
    """BGR uint8 HWC -> RGB float32 NCHW in the 0-1 range."""
    rgb = padded_bgr[:, :, ::-1].transpose(2, 0, 1)[None]
    return np.ascontiguousarray(rgb, dtype=np.float32) / 255.0


def _iou(box: np.ndarray, others: np.ndarray) -> np.ndarray:
    x1 = np.maximum(box[0], others[:, 0])
    y1 = np.maximum(box[1], others[:, 1])
    x2 = np.minimum(box[2], others[:, 2])
    y2 = np.minimum(box[3], others[:, 3])
    intersection = np.clip(x2 - x1, 0, None) * np.clip(y2 - y1, 0, None)
    area = (box[2] - box[0]) * (box[3] - box[1])
    areas = (others[:, 2] - others[:, 0]) * (others[:, 3] - others[:, 1])
    return intersection / (area + areas - intersection + 1e-7)


def postprocess(
    raw: np.ndarray,
    names: dict[int, str],
    *,
    width: int,
    height: int,
    scale: float,
    left: int,
    top: int,
    conf: float,
) -> list[Detection]:
    """Decode a ``[4 + classes, 8400]`` output into detections on the photo.

    Detections come out from the most to the least confident, in the same
    shape ``LeafDetector`` reports them.
    """
    rows = raw.T  # (8400, 4 + classes): cx, cy, w, h, then one score per class
    class_ids = rows[:, 4:].argmax(1)
    scores = rows[:, 4:].max(1)
    keep = scores > conf
    rows, class_ids, scores = rows[keep], class_ids[keep], scores[keep]

    cx, cy, w, h = rows[:, 0], rows[:, 1], rows[:, 2], rows[:, 3]
    boxes = np.stack([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], axis=1)
    shifted = boxes + class_ids[:, None] * CLASS_OFFSET

    order = scores.argsort()[::-1]
    selected: list[int] = []
    while order.size and len(selected) < MAX_DETECTIONS:
        best, rest = order[0], order[1:]
        selected.append(int(best))
        if not rest.size:
            break
        order = rest[_iou(shifted[best], shifted[rest]) <= IOU_THRESHOLD]

    detections = []
    for index in selected:
        x1, y1, x2, y2 = boxes[index]
        detections.append(
            {
                "label": names[int(class_ids[index])],
                "confidence": round(float(scores[index]) * 100, 2),
                "box": {
                    "x1": round(float(np.clip((x1 - left) / scale, 0, width))),
                    "y1": round(float(np.clip((y1 - top) / scale, 0, height))),
                    "x2": round(float(np.clip((x2 - left) / scale, 0, width))),
                    "y2": round(float(np.clip((y2 - top) / scale, 0, height))),
                },
            }
        )
    return detections
