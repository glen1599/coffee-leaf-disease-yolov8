"""Application settings and the coffee-leaf disease knowledge base.

Every value can be overridden through environment variables so the same
codebase runs unchanged on a laptop, in Docker or on a PaaS.
"""

from __future__ import annotations

import os
from pathlib import Path

# --- Identity -------------------------------------------------------------
APP_NAME = "Coffee Leaf Disease Detection"
APP_VERSION = os.getenv("APP_VERSION", "2.0.0")

# Decompression-bomb guard. OpenCV reads this limit when the library
# initialises, so it must be set before ``cv2`` is imported anywhere in the
# process. ``coffee_leaf/__init__.py`` imports this module first, which
# guarantees the ordering for every entrypoint.
MAX_IMAGE_PIXELS = int(os.getenv("MAX_IMAGE_PIXELS", str(40_000_000)))
os.environ.setdefault("OPENCV_IO_MAX_IMAGE_PIXELS", str(MAX_IMAGE_PIXELS))

# --- Paths (resolved from the repository root: clone-and-run friendly) -----
BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"

# Trained checkpoint. A sibling ``.onnx`` export is preferred when present.
# It is NOT faster in this project (see scripts/benchmark.py -- both backends
# measure ~43 ms) and Ultralytics still loads it through torch, so treat ONNX
# as the route to a torch-free deployment, not as a speed-up.
MODEL_PATH = Path(os.getenv("MODEL_PATH", str(MODELS_DIR / "best.pt")))
ONNX_MODEL_PATH = MODEL_PATH.with_suffix(".onnx")
# YOLOv8n COCO weights used only when the trained checkpoint is missing.
# Ultralytics auto-downloads them when the local file is absent.
_LOCAL_FALLBACK = MODELS_DIR / "yolov8n.pt"
FALLBACK_WEIGHTS = str(_LOCAL_FALLBACK) if _LOCAL_FALLBACK.is_file() else "yolov8n.pt"

# --- Inference ------------------------------------------------------------
CONF_THRESHOLD = float(os.getenv("CONF_THRESHOLD", "0.25"))
JPEG_QUALITY = int(os.getenv("JPEG_QUALITY", "85"))

# --- Upload validation ----------------------------------------------------
ALLOWED_EXTENSIONS = frozenset({"png", "jpg", "jpeg", "bmp", "webp"})
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(10 * 1024 * 1024)))
MAX_BATCH_FILES = int(os.getenv("MAX_BATCH_FILES", "8"))

# --- Storage & rate limiting ---------------------------------------------
# Anonymous scan log + rate-limit windows, in a single SQLite file.
DATABASE_PATH = Path(os.getenv("DATABASE_PATH", str(BASE_DIR / "instance" / "app.sqlite3")))
RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", "30"))
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))

# --- Responses ------------------------------------------------------------
# Hardening headers applied to every response (see coffee_leaf/__init__.py).
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "camera=(self), microphone=(), geolocation=()",
    "Cross-Origin-Opener-Policy": "same-origin",
    # No inline script and no inline style attribute anywhere in the markup;
    # the page only sets custom properties through CSSOM, which CSP allows.
    "Content-Security-Policy": (
        "default-src 'self'; "
        "img-src 'self' data: blob:; "
        "style-src 'self'; "
        "script-src 'self'; "
        "connect-src 'self'; "
        "font-src 'self'; "
        "base-uri 'none'; "
        "form-action 'self'; "
        "frame-ancestors 'none'; "
        "object-src 'none'"
    ),
}

# --- Reported validation metrics ------------------------------------------
# Last epoch of docs/training/results.csv (50 epochs, YOLOv8n, 640px).
MODEL_METRICS = {
    "precision": 96.99,
    "recall": 96.59,
    "f1_score": 96.79,
    "map50": 98.49,
    "map50_95": 76.32,
}

# --- Class labels ---------------------------------------------------------
# Keys are baked into models/best.pt and MUST stay in sync with the weights.
CLASS_LABELS = {
    "sehat": "Healthy",
    "bercak_phoma": "Phoma Leaf Spot",
    "karat_daun": "Coffee Leaf Rust",
    "pengorok_daun": "Leaf Miner",
}

# --- Showcase samples -----------------------------------------------------
# Real photographs shipped with the repository, one per class. They power the
# "try a sample" shortcuts and the class explorer on the landing page.
SAMPLES = {
    "bercak_phoma": "img/samples/phoma_leaf_spot.jpg",
    "karat_daun": "img/samples/coffee_leaf_rust.jpg",
    "pengorok_daun": "img/samples/leaf_miner.jpg",
    "sehat": "img/samples/healthy_leaf.jpg",
}

# --- Domain knowledge base ------------------------------------------------
# ``severity`` drives the colour of the result badges in the UI.
DISEASE_INFO = {
    "bercak_phoma": {
        "label": "Phoma Leaf Spot",
        "status": "Pathogen detected",
        "severity": "high",
        "pathogen": "Phoma spp. (fungus)",
        "summary": (
            "A fungal infection that produces necrotic brown-to-black lesions. "
            "Left untreated the lesions merge and kill the leaf tissue permanently."
        ),
        "symptoms": [
            "Dark brown circular spots with a lighter grey centre",
            "Lesions that enlarge and merge across the blade",
            "Premature leaf drop in severe infections",
        ],
        "treatment": [
            "Apply a fungicide based on mancozeb or chlorothalonil on a 7-10 day interval.",
            "Prune and destroy infected leaves; burn the removed plant debris.",
            "Improve soil drainage to lower humidity around the canopy.",
            "Avoid overhead irrigation, which spreads spores between plants.",
        ],
    },
    "karat_daun": {
        "label": "Coffee Leaf Rust",
        "status": "Pathogen detected",
        "severity": "high",
        "pathogen": "Hemileia vastatrix (fungus)",
        "summary": (
            "Aggressive rust infection. Orange-yellow spore pustules form on the "
            "underside of the leaf and can trigger mass defoliation and yield loss."
        ),
        "symptoms": [
            "Yellow-orange powdery pustules on the leaf underside",
            "Yellow chlorotic blotches on the upper surface",
            "Defoliation starting from the lower branches",
        ],
        "treatment": [
            "Apply a systemic triazole fungicide (e.g. triadimefon) at the first symptoms.",
            "Isolate and destroy heavily infected plants away from the main block.",
            "Thin the canopy to improve airflow and sunlight penetration.",
            "Plant rust-resistant coffee varieties for the next cycle.",
        ],
    },
    "pengorok_daun": {
        "label": "Leaf Miner",
        "status": "Pest detected",
        "severity": "moderate",
        "pathogen": "Pectinifera spp. (larvae)",
        "summary": (
            "Larvae tunnel through the leaf mesophyll, leaving white winding mines "
            "that destroy chlorophyll and reduce photosynthetic capacity."
        ),
        "symptoms": [
            "White or translucent winding galleries across the blade",
            "Blistered, distorted leaf surface along the mine",
            "Reduced vigour and leaf area on infested branches",
        ],
        "treatment": [
            "Apply a systemic insecticide based on abamectin at the recommended dose.",
            "Deploy yellow sticky traps to control the adult fly population.",
            "Prune leaves showing active mines and destroy the larvae inside.",
            "Increase scouting of the affected block to a weekly schedule.",
        ],
    },
    "sehat": {
        "label": "Healthy",
        "status": "No pathogen found",
        "severity": "none",
        "pathogen": "None",
        "summary": (
            "The leaf morphology is intact and healthy. Chlorophyll is evenly "
            "distributed with no signs of pathogens, fungal spores or pest damage."
        ),
        "symptoms": [
            "Uniform green colouration",
            "No lesions, mines or spore pustules",
            "Intact blade and veins",
        ],
        "treatment": [
            "Keep the standard irrigation schedule based on soil moisture.",
            "Continue the regular NPK fertilisation cycle.",
            "Run routine pruning to maintain the canopy shape.",
            "Keep monitoring for pests and diseases at regular intervals.",
        ],
    },
}
