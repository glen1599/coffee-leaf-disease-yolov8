"""Export the knowledge base the mobile app ships offline.

The phone runs detection on-device, so it needs its own copy of the disease
names, symptoms and treatment steps. Generating that copy from
``coffee_leaf.content`` keeps a single source of truth: edit the text there,
rerun this script, and the app and ``GET /api/v1/diseases`` stay identical.

    python scripts/export_mobile_content.py
    python scripts/export_mobile_content.py --output some/other/path.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from coffee_leaf.content import mobile_bundle  # noqa: E402

DEFAULT_OUTPUT = ROOT / "mobile" / "assets" / "content" / "diseases.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(mobile_bundle(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
