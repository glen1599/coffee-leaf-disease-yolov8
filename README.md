<div align="center">

# ☕ Coffee Leaf Disease Detection

**YOLOv8 object detection for coffee leaf disease, served as a Flask web app.**

Upload a photo of a coffee leaf and get the diagnosed class, per-lesion bounding
boxes, confidence scores and a field treatment protocol — in under a second.

![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-3.x-000000?logo=flask&logoColor=white)
![YOLOv8](https://img.shields.io/badge/Ultralytics-YOLOv8-111F68)
![OpenCV](https://img.shields.io/badge/OpenCV-4.9%2B-5C3EE8?logo=opencv&logoColor=white)
![mAP@50](https://img.shields.io/badge/mAP%4050-98.49%25-37d99a)
![License](https://img.shields.io/badge/License-MIT-e0a96d)

</div>

---

## Overview

Coffee is one of the most valuable agricultural commodities in Indonesia, and
leaf disease is one of the main causes of yield loss. Diagnosis normally
requires an agronomist on site; this project turns a phone photo into an
immediate, machine-assisted diagnosis.

The repository contains a fine-tuned **YOLOv8n** detector, an **OpenCV**
pre-processing stage that isolates the leaf from a cluttered background, and a
**Flask** application that exposes the whole pipeline over HTTP with a
production-style web dashboard.

| Class key | Display label | Cause |
| --- | --- | --- |
| `sehat` | Healthy | — |
| `bercak_phoma` | Phoma Leaf Spot | *Phoma* spp. (fungus) |
| `karat_daun` | Coffee Leaf Rust | *Hemileia vastatrix* (fungus) |
| `pengorok_daun` | Leaf Miner | *Pectinifera* spp. (larvae) |

> The class keys are baked into the checkpoint and kept in Indonesian; the UI
> displays English labels. See [`coffee_leaf/config.py`](coffee_leaf/config.py).

## Key Features

- **End-to-end detection pipeline** — image decode, green-mask auto-crop,
  YOLOv8 inference and annotation in a single request.
- **Two input modes** — drag-and-drop file upload with live preview, or a frame
  captured straight from the device camera.
- **In-memory processing** — uploads are never written to disk; the file is
  decoded from a byte buffer, so there is nothing to clean up and no temp-path
  coupling.
- **Explainable output** — annotated image, auto-cropped leaf, per-detection
  confidence bars, dominant class, latency and a treatment protocol.
- **Adjustable confidence threshold** — tune the recall/precision trade-off from
  the UI, clamped server-side between 0.05 and 0.95.
- **Disease knowledge base** — status, pathogen, symptoms and a step-by-step
  protocol for each class, rendered from a single source of truth.
- **Production hygiene** — application factory, blueprint routing, type hints,
  structured logging, input validation, per-IP rate limiting, health endpoint
  and environment-driven configuration.
- **Responsive dark UI** — one static page, no front-end build step, no
  JavaScript dependencies.

## Tech Stack

| Layer | Technology | Role |
| --- | --- | --- |
| Model | Ultralytics **YOLOv8n** | Object detection (4 classes) |
| Vision | **OpenCV** | Decode, Otsu green-mask auto-crop, annotation |
| Numerics | **NumPy** | Array handling |
| Backend | **Flask** 3 | HTTP API + Jinja templating |
| Front-end | Vanilla **HTML / CSS / JS** | Dashboard, drag-and-drop, camera, history |
| Serving | **Gunicorn** | Production WSGI server |

## Project Structure

```
coffee-leaf-disease-yolov8/
├── app.py                       # Entrypoint: `python app.py`
├── coffee_leaf/                 # Application package
│   ├── __init__.py              #   application factory (create_app)
│   ├── config.py                #   settings + disease knowledge base
│   ├── routes.py                #   HTTP layer: routes and validation
│   ├── detector.py              #   YOLOv8 inference service
│   ├── preprocess.py            #   OpenCV leaf auto-crop
│   └── ratelimit.py             #   in-memory rate limiter
├── models/
│   └── best.pt                  # Fine-tuned YOLOv8n checkpoint (committed)
├── templates/index.html         # Single-page dashboard
├── static/
│   ├── css/app.css              # Design system
│   ├── js/app.js                # Front-end controller
│   ├── img/                     # Hero art, favicon, sample photos
│   └── manifest.json            # PWA manifest
├── docs/training/               # Training log + arguments (evidence)
├── datasets/README.md           # Dataset provenance (data not committed)
├── requirements.txt
└── LICENSE
```

## Installation & Usage

Requires **Python 3.10+**. Verified with Python 3.11.

```bash
git clone https://github.com/<your-username>/coffee-leaf-disease-yolov8.git
cd coffee-leaf-disease-yolov8
```

<details open>
<summary><b>With uv (recommended)</b></summary>

```bash
uv venv --python 3.11
uv pip install -r requirements.txt
uv run python app.py
```

</details>

<details>
<summary><b>With pip</b></summary>

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

</details>

Open <http://127.0.0.1:5000> and drop a leaf photo into the console.

### Production

```bash
gunicorn --workers 1 --timeout 120 "coffee_leaf:create_app()"
```

> Keep `--workers 1` while the rate limiter is in-memory, or swap it for a
> Redis-backed limiter first. Each worker loads its own copy of the model.

### Configuration

Every setting is overridable through the environment:

| Variable | Default | Description |
| --- | --- | --- |
| `PORT` | `5000` | HTTP port |
| `HOST` | `127.0.0.1` | Bind address |
| `FLASK_DEBUG` | `0` | `1` enables the reloader |
| `MODEL_PATH` | `models/best.pt` | Checkpoint to load |
| `CONF_THRESHOLD` | `0.25` | Default confidence threshold |
| `MAX_CONTENT_LENGTH` | `10485760` | Upload cap in bytes (10 MB) |
| `JPEG_QUALITY` | `85` | Encoding quality of returned images |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW` | `30` / `60` | Requests per IP per window |

## API Reference

| Method | Endpoint | Body | Response |
| --- | --- | --- | --- |
| `GET` | `/` | — | Dashboard (HTML) |
| `GET` | `/health` | — | Model provenance and class list |
| `POST` | `/predict` | `multipart/form-data`: `file`, optional `conf` | Detection payload |
| `POST` | `/predict/camera` | `application/json`: `{ "image": "<data-URI>", "conf": 0.25 }` | Detection payload |

<details>
<summary><b>Example</b></summary>

```bash
curl -s http://127.0.0.1:5000/predict \
  -F "file=@static/img/samples/coffee_leaf_rust.jpg" \
  -F "conf=0.25"
```

```json
{
  "dominant_class": "karat_daun",
  "total_detections": 1,
  "inference_ms": 142.7,
  "frame": { "width": 640, "height": 640 },
  "detections": [
    {
      "label": "karat_daun",
      "label_text": "Coffee Leaf Rust",
      "confidence": 91.42,
      "box": { "x1": 88, "y1": 61, "x2": 540, "y2": 588 }
    }
  ],
  "info": {
    "label": "Coffee Leaf Rust",
    "status": "Pathogen detected",
    "severity": "high",
    "pathogen": "Hemileia vastatrix (fungus)",
    "summary": "...",
    "symptoms": ["..."],
    "treatment": ["..."]
  },
  "annotated_image": "data:image/jpeg;base64,...",
  "original_image": "data:image/jpeg;base64,...",
  "cropped_image": "data:image/jpeg;base64,..."
}
```

</details>

Error responses are always JSON: `400` invalid input, `413` payload too large,
`429` rate limited, `500` inference failure.

## Screenshots

| Dashboard | Detection result |
| --- | --- |
| ![Dashboard](docs/screenshots/dashboard.png) | ![Result](docs/screenshots/result.png) |

| Disease knowledge base | Model metrics |
| --- | --- |
| ![Disease library](docs/screenshots/library.png) | ![Metrics](docs/screenshots/metrics.png) |

<p align="center">
  <img src="docs/screenshots/mobile.png" alt="Mobile layout" width="360">
  <br><em>Responsive layout on a 430 px viewport.</em>
</p>


## Model Metrics

Fine-tuned for **50 epochs** at **640 px** with the *Coffee Leaf — v5* dataset.
Values below are the final validation epoch (see
[`docs/training/results.csv`](docs/training/results.csv)).

| Metric | Value |
| --- | --- |
| Precision | **96.99 %** |
| Recall | **96.59 %** |
| F1 score | **96.79 %** |
| mAP@50 | **98.49 %** |
| mAP@50-95 | **76.32 %** |

| Curves | Confusion matrix |
| --- | --- |
| ![Training curves](static/img/training/results.png) | ![Confusion matrix](static/img/training/confusion_matrix_normalized.png) |

| Ground truth batch | Predicted batch |
| --- | --- |
| ![Validation labels](static/img/training/val_batch0_labels.jpg) | ![Validation predictions](static/img/training/val_batch0_pred.jpg) |

## Dataset

*Coffee Leaf — v5*, exported from Roboflow Universe under **CC BY 4.0**:
3,992 images (3,493 / 333 / 166) across the four classes above. The dataset is
not committed — see [`datasets/README.md`](datasets/README.md) for provenance,
class mapping and retraining instructions.

## Roadmap

- [ ] ONNX / TensorRT export for CPU-only edge deployment
- [ ] Redis-backed rate limiting for multi-worker deployments
- [ ] Tiled inference for high-resolution field photos
- [ ] Bahasa Indonesia and English UI localisation

## License

Released under the [MIT License](LICENSE). The dataset is distributed under
CC BY 4.0 by its original authors.

## Author

**Glen Devit Renaldi** — machine learning and full-stack engineering.
Found a bug or want to improve the pipeline? Issues and pull requests are
welcome.
