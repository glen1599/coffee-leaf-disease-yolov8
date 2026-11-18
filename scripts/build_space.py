"""Assemble the folder that is uploaded to a Hugging Face Space.

Only what the server needs at runtime goes in: the Flask package, templates,
static files, the trained weights and the Space's own Dockerfile and README.
The Flutter app, the dataset and the tests stay out.

    python scripts/build_space.py              # writes build/space
    python scripts/build_space.py --output DIR

The ONNX export (models/best.onnx) is git-ignored but preferred at runtime:
it is faster on CPU and keeps PyTorch off the request path. Regenerate it
with ``yolo export model=models/best.pt format=onnx opset=12 simplify=True``.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPACE_FILES = ROOT / "deploy" / "huggingface"
DEFAULT_OUTPUT = ROOT / "build" / "space"

# Copied as they are, relative to the repository root.
RUNTIME_PATHS = (
    "app.py",
    "coffee_leaf",
    "templates",
    "static",
    "requirements.txt",
    "LICENSE",
    "models/best.pt",
)
OPTIONAL_PATHS = ("models/best.onnx",)

IGNORE = shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store")


def build(output: Path) -> list[Path]:
    """Recreate ``output`` and return the files written into it."""
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    for relative in RUNTIME_PATHS + OPTIONAL_PATHS:
        source = ROOT / relative
        if not source.exists():
            if relative in OPTIONAL_PATHS:
                print(f"warning: {relative} not found; the Space will run PyTorch")
                continue
            raise SystemExit(f"missing required file: {relative}")
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target, ignore=IGNORE)
        else:
            shutil.copy2(source, target)

    for name in ("Dockerfile", "README.md"):
        shutil.copy2(SPACE_FILES / name, output / name)

    return sorted(path for path in output.rglob("*") if path.is_file())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    files = build(args.output)
    size = sum(path.stat().st_size for path in files) / (1024 * 1024)
    print(f"Wrote {len(files)} files ({size:.1f} MB) to {args.output}")


if __name__ == "__main__":
    sys.exit(main())
