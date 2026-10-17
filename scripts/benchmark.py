"""Benchmark the available backends on the shipped sample photos.

    python scripts/benchmark.py [warmup] [runs]

Prints mean and p95 latency per backend so the numbers quoted in the README
can be reproduced rather than trusted.
"""

from __future__ import annotations

import statistics
import sys
import time
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from coffee_leaf.config import MODEL_PATH, ONNX_MODEL_PATH, SAMPLES
from coffee_leaf.detector import LeafDetector

ROOT = Path(__file__).resolve().parent.parent


def benchmark(weights: Path, images: list, warmup: int, runs: int) -> dict:
    detector = LeafDetector(weights)
    for image in images:  # warm-up: the first call loads and specialises kernels
        for _ in range(warmup):
            detector.predict(image)

    samples: list[float] = []
    for _ in range(runs):
        for image in images:
            started = time.perf_counter()
            detector.predict(image)
            samples.append((time.perf_counter() - started) * 1000)

    samples.sort()
    return {
        "weights": weights.name,
        "runtime": detector.runtime,
        "mean": round(statistics.fmean(samples), 1),
        "p95": round(samples[int(len(samples) * 0.95) - 1], 1),
        "n": len(samples),
    }


def main() -> int:
    warmup = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    runs = int(sys.argv[2]) if len(sys.argv) > 2 else 10

    images = []
    for relative in SAMPLES.values():
        image = cv2.imread(str(ROOT / "static" / relative), cv2.IMREAD_COLOR)
        if image is not None:
            images.append(image)
    if not images:
        print("no sample images found")
        return 1

    print(f"{len(images)} images x {runs} runs (after {warmup} warm-up passes)\n")
    results = []
    for weights in (MODEL_PATH, ONNX_MODEL_PATH):
        if weights.is_file():
            results.append(benchmark(weights, images, warmup, runs))

    width = max(len(r["weights"]) for r in results)
    print(f"{'weights'.ljust(width)}  {'runtime':12}  {'mean':>8}  {'p95':>8}")
    for row in results:
        print(
            f"{row['weights'].ljust(width)}  {row['runtime']:12}  "
            f"{row['mean']:>6} ms  {row['p95']:>6} ms"
        )

    if len(results) == 2:
        speedup = results[0]["mean"] / results[1]["mean"]
        print(f"\nONNX vs PyTorch mean speedup: {speedup:.2f}x")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
