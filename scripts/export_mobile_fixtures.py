"""Reference implementation of the on-device pipeline, and its test fixtures.

The mobile app runs ``models/best.onnx`` on the phone with ONNX Runtime. It
cannot use Ultralytics there, so it has to do three things itself: letterbox
the photo to 640 x 640, decode the raw ``[1, 8, 8400]`` output, and run
non-maximum suppression. This script is that same pipeline in NumPy.

It does two jobs:

1. **Prove the pipeline** -- every sample is run through both this code and
   the server's ``LeafDetector``; the script fails if they disagree.
2. **Export fixtures** for the Dart tests in ``mobile/test/fixtures``: the raw
   model output per sample (so the Dart decoder and NMS are tested on real
   data) and the detections the app is expected to produce.

    python scripts/export_mobile_fixtures.py            # check + write fixtures
    python scripts/export_mobile_fixtures.py --check    # check only
    python scripts/export_mobile_fixtures.py --tensors DIR
        # score tensors preprocessed by the Dart code (see mobile/tool/)
"""

from __future__ import annotations

import argparse
import gzip
import json
import logging
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import onnxruntime as ort

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from coffee_leaf.config import (  # noqa: E402
    CONF_THRESHOLD,
    FALLBACK_WEIGHTS,
    MODEL_PATH,
    ONNX_MODEL_PATH,
    SAMPLES,
)
from coffee_leaf.detector import LeafDetector  # noqa: E402

FIXTURES_DIR = ROOT / "mobile" / "test" / "fixtures"

# Must match the constants in mobile/lib/domain/detection/.
INPUT_SIZE = 640
PAD_VALUE = 114
IOU_THRESHOLD = 0.7
MAX_DETECTIONS = 300
# Boxes of different classes never suppress each other: shifting each class
# far apart before NMS is how Ultralytics does it.
CLASS_OFFSET = 7680.0

# Raw outputs are ~270 KB each, so only two are committed: one with many
# overlapping boxes (exercises NMS) and one with a single box.
RAW_OUTPUT_SAMPLES = ("karat_daun", "sehat")

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
    conf: float = CONF_THRESHOLD,
) -> list[Detection]:
    """Decode a ``[8, 8400]`` output into detections on the original photo."""
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


def run_reference(
    session: ort.InferenceSession, names: dict[int, str], image: np.ndarray
) -> tuple[np.ndarray, list[Detection]]:
    """Full on-device pipeline: letterbox, model, decode, NMS."""
    height, width = image.shape[:2]
    padded, scale, left, top = letterbox(image)
    raw = session.run(None, {session.get_inputs()[0].name: to_tensor(padded)})[0][0]
    return raw, postprocess(raw, names, width=width, height=height, scale=scale, left=left, top=top)


def _by_confidence(detections: list[Detection]) -> list[Detection]:
    return sorted(detections, key=lambda item: -item["confidence"])


def _box_iou(left: dict[str, int], right: dict[str, int]) -> float:
    width = min(left["x2"], right["x2"]) - max(left["x1"], right["x1"])
    height = min(left["y2"], right["y2"]) - max(left["y1"], right["y1"])
    intersection = max(width, 0) * max(height, 0)
    area_left = (left["x2"] - left["x1"]) * (left["y2"] - left["y1"])
    area_right = (right["x2"] - right["x1"]) * (right["y2"] - right["y1"])
    return intersection / (area_left + area_right - intersection + 1e-7)


def compare(expected: list[Detection], actual: list[Detection]) -> tuple[bool, int, float]:
    """Return (same findings, worst box error in px, worst confidence error).

    Detections are paired by position on the photo, not by rank: two lesions
    with nearly equal scores may swap places between two pipelines without
    anything having changed.
    """
    if len(expected) != len(actual):
        return False, -1, -1.0
    remaining = list(actual)
    same, box_error, confidence_error = True, 0, 0.0
    for want in _by_confidence(expected):
        got = max(remaining, key=lambda item: _box_iou(want["box"], item["box"]))
        remaining.remove(got)
        same &= want["label"] == got["label"] and _box_iou(want["box"], got["box"]) > 0.5
        confidence_error = max(confidence_error, abs(want["confidence"] - got["confidence"]))
        box_error = max(box_error, *(abs(want["box"][k] - got["box"][k]) for k in want["box"]))
    return same, box_error, round(confidence_error, 2)


def score_dart_tensors(directory: Path, session, names, server: LeafDetector) -> bool:
    """Run tensors preprocessed by the Dart code and compare with the server.

    ``mobile/tool/dump_tensors.dart`` writes, per sample, ``<key>.tensor.bin``
    (float32 NCHW) and ``<key>.json`` with the letterbox parameters it used.
    The only thing that differs from the phone is who decoded and resized the
    JPEG, which is exactly what this measures.
    """
    all_good = True
    for key, relative in SAMPLES.items():
        meta = json.loads((directory / f"{key}.json").read_text())
        tensor = np.fromfile(directory / f"{key}.tensor.bin", dtype="<f4").reshape(
            1, 3, INPUT_SIZE, INPUT_SIZE
        )
        raw = session.run(None, {session.get_inputs()[0].name: tensor})[0][0]
        actual = postprocess(
            raw,
            names,
            width=meta["width"],
            height=meta["height"],
            scale=meta["scale"],
            left=meta["left"],
            top=meta["top"],
        )
        expected = server.detect(cv2.imread(str(ROOT / "static" / relative)))["detections"]
        same, box_error, confidence_error = compare(expected, actual)
        top_expected = max((d["confidence"] for d in expected), default=0.0)
        top_actual = max((d["confidence"] for d in actual), default=0.0)
        dominant_same = bool(expected) == bool(actual) and (
            not expected
            or _by_confidence(expected)[0]["label"] == _by_confidence(actual)[0]["label"]
        )
        all_good &= dominant_same and same
        print(
            f"{key:14s} server={len(expected):2d} dart={len(actual):2d} "
            f"same_verdict={dominant_same} top_conf server={top_expected} dart={top_actual} "
            f"same_findings={same} box_px={box_error} conf={confidence_error}"
        )
    return all_good


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="verify only, write nothing")
    parser.add_argument("--tensors", type=Path, help="score tensors written by the Dart tool")
    args = parser.parse_args()

    logging.disable(logging.CRITICAL)
    server = LeafDetector(MODEL_PATH, ONNX_MODEL_PATH, FALLBACK_WEIGHTS, CONF_THRESHOLD)
    session = ort.InferenceSession(str(ONNX_MODEL_PATH), providers=["CPUExecutionProvider"])
    names = server.class_names

    if args.tensors:
        return 0 if score_dart_tensors(args.tensors, session, names, server) else 1

    expected_payload: dict[str, Any] = {
        "model": {
            "input_size": INPUT_SIZE,
            "pad_value": PAD_VALUE,
            "conf_threshold": CONF_THRESHOLD,
            "iou_threshold": IOU_THRESHOLD,
            "max_detections": MAX_DETECTIONS,
            "class_names": [names[index] for index in sorted(names)],
            "output_shape": [len(names) + 4, 8400],
        },
        "samples": {},
    }
    raw_outputs: dict[str, np.ndarray] = {}
    all_match = True

    for key, relative in SAMPLES.items():
        image = cv2.imread(str(ROOT / "static" / relative))
        height, width = image.shape[:2]
        raw, reference = run_reference(session, names, image)
        same, box_error, confidence_error = compare(server.detect(image)["detections"], reference)
        all_match &= same and box_error <= 1 and confidence_error <= 0.01
        print(
            f"{key:14s} detections={len(reference):2d} matches_server={same} "
            f"box_px={box_error} conf={confidence_error}"
        )

        _, scale, left, top = letterbox(image)
        expected_payload["samples"][key] = {
            "file": Path(relative).name,
            "width": width,
            "height": height,
            "letterbox": {"scale": scale, "left": left, "top": top},
            "detections": _by_confidence(reference),
        }
        if key in RAW_OUTPUT_SAMPLES:
            raw_outputs[key] = raw

    if not all_match:
        print("The reference pipeline no longer matches the server.", file=sys.stderr)
        return 1
    if args.check:
        return 0

    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    (FIXTURES_DIR / "expected.json").write_text(
        json.dumps(expected_payload, indent=2) + "\n", encoding="utf-8"
    )
    for key, raw in raw_outputs.items():
        # mtime=0 keeps the archive byte-identical between runs.
        with gzip.GzipFile(FIXTURES_DIR / f"{key}.output.bin.gz", "wb", mtime=0) as handle:
            handle.write(raw.astype("<f4").tobytes())
    print(f"Wrote fixtures to {FIXTURES_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
