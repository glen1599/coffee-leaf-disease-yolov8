"""Regenerate the case-study images used by the landing page and the README.

For every class it writes a pair of real files:

* ``static/img/cases/<key>-input.jpg``  - the photograph as uploaded
* ``static/img/cases/<key>-output.jpg`` - the same photo after the model ran

Run it after retraining so the published examples always show real output:

    python scripts/export_cases.py
"""

from __future__ import annotations

import base64
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from coffee_leaf.config import (
    JPEG_QUALITY,
    MODEL_PATH,
    ONNX_MODEL_PATH,
    SAMPLES,
)
from coffee_leaf.detector import LeafDetector

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "static" / "img" / "cases"
MAX_WIDTH = 1400
SAMPLE_QUALITY = min(JPEG_QUALITY, 82)


def write_jpeg(image: np.ndarray, destination: Path) -> None:
    """Write ``image`` to ``destination``, capped at ``MAX_WIDTH`` pixels wide."""
    height, width = image.shape[:2]
    if width > MAX_WIDTH:
        scale = MAX_WIDTH / width
        image = cv2.resize(image, (MAX_WIDTH, int(height * scale)), interpolation=cv2.INTER_AREA)

    ok, buffer = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, SAMPLE_QUALITY])
    if not ok:
        raise RuntimeError(f"could not encode {destination.name}")
    destination.write_bytes(buffer.tobytes())
    print(f"  {destination.name:24} {len(buffer) // 1024:>4} KB")


def decode_data_uri(data_uri: str) -> np.ndarray:
    """Turn a ``data:image/jpeg;base64,...`` payload back into a BGR array."""
    payload = base64.b64decode(data_uri.split(",", 1)[1])
    image = cv2.imdecode(np.frombuffer(payload, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise RuntimeError("could not decode the annotated result")
    return image


def main() -> int:
    weights = ONNX_MODEL_PATH if ONNX_MODEL_PATH.is_file() else MODEL_PATH
    detector = LeafDetector(weights)
    print(f"Using {detector.weights_used} ({detector.runtime})")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for key, relative in SAMPLES.items():
        source = ROOT / "static" / relative
        image = cv2.imread(str(source), cv2.IMREAD_COLOR)
        if image is None:
            print(f"! skipping {key}: cannot read {source}")
            continue

        print(f"{key}:")
        write_jpeg(image, OUTPUT_DIR / f"{key}-input.jpg")

        result = detector.predict(image)
        print(
            f"  -> {result['dominant_class']} "
            f"({result['total_detections']} detections, {result['inference_ms']} ms)"
        )
        write_jpeg(decode_data_uri(result["annotated_image"]), OUTPUT_DIR / f"{key}-output.jpg")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
