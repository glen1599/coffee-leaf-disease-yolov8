# Model Card — Coffee Leaf Disease Detector

Following the structure proposed by Mitchell et al., *Model Cards for Model
Reporting* (2019). Everything here refers to `models/best.pt` / `models/best.onnx`.

## Model details

| | |
| --- | --- |
| Architecture | Ultralytics **YOLOv8n** (object detection) |
| Task | Single-stage detection, 4 classes, bounding boxes + class confidence |
| Input | 640 × 640, BGR, 3 channels |
| Output | Boxes with class and confidence; the app reports the highest-confidence class as the verdict |
| Parameters | ~3.2 M |
| Artefacts | `models/best.pt` (PyTorch, versioned) and an optional `models/best.onnx` export (derived, git-ignored) |
| Trained by | Glen Devit Renaldi, 2026 |
| License | MIT (code and weights) |

## Intended use

**In scope.** Decision support for coffee growers, agronomy students and
extension workers: photograph a leaf, get a provisional class and a starting
point for what to do about it.

**Out of scope.**

- Any autonomous spraying, dosing or treatment decision.
- Certification, compliance or export grading.
- Diagnosing a plant from a photograph of a whole tree, a canopy or a fruit.
- Species other than *Coffea*.

## Training data

| | |
| --- | --- |
| Source | Roboflow Universe — *Coffee Leaf v5* (`metopen-ryukv/coffee-leaf-aodpp`) |
| License | CC BY 4.0 |
| Size | 3,992 images — 3,493 train / 333 valid / 166 test |
| Pre-processing | EXIF auto-orient, resize to 640 × 640 (stretch) |
| Augmentation | 3× per source image: horizontal flip (p ≈ 0.5), rotation ±15°, exposure ±10 % |
| Annotation | COCO, one region class plus four detection classes |

Classes: `bercak_phoma` (Phoma Leaf Spot), `karat_daun` (Coffee Leaf Rust),
`pengorok_daun` (Leaf Miner), `sehat` (Healthy). The keys are stored inside the
checkpoint and are deliberately kept in the dataset's original language; only
the display labels are translated.

## Metrics

Final validation epoch, 50 epochs, `imgsz=640`. Reproduce with
`docs/training/results.csv`.

| Metric | Value |
| --- | --- |
| Precision | 0.9699 |
| Recall | 0.9659 |
| F1 | 0.9679 |
| mAP@50 | 0.9849 |
| mAP@50-95 | 0.7632 |

Inference cost, measured with `scripts/benchmark.py` on an Apple-silicon CPU
over the four sample photographs: ~20 ms per model call, ~43 ms end-to-end
including leaf cropping, annotation and JPEG encoding. PyTorch and ONNX
measured within noise of each other (1.00×); ONNX is preferred because it
removes the runtime torch dependency, not because it is faster.

## Limitations

1. **Localisation is the weak point.** The 22-point gap between mAP@50 and
   mAP@50-95 means boxes are systematically larger than the lesion. Use them to
   locate, not to measure.
2. **Single-source data.** All images come from one Roboflow collection.
   Cultivar, altitude, camera and lighting diversity are unknown, so the
   accuracy figures above are *in-distribution* numbers only.
3. **Validation images are the clean originals.** The split happens at
   source-image level first, then only the training set is expanded 3× by
   augmentation — verified by prefixing file names: 3,493 training files map to
   1,165 source images, while the 333 validation and 166 test files map 1:1 to
   333 and 166 sources, with zero index overlap between splits. So there is no
   train/validation leakage, but the reported metrics are measured on clean
   photographs and say nothing about how the model handles blur, motion or
   harsh field lighting.
4. **Four classes, closed set.** A leaf with a condition outside these four is
   still forced into one of them. The detector has no "unknown" class.
5. **No confidence calibration.** A 0.9 output is a model score, not a
   probability that the diagnosis is right.
6. **Class imbalance is unknown.** The published distribution
   (`static/img/training/labels.jpg`) is not stratified per class, so per-class
   recall is worth reading off the confusion matrix before trusting a rare class.

## Responsible-use notes

- The treatment text is generic. It is not adapted to local regulation,
  resistance status or pre-harvest interval — always confirm with a local
  extension officer.
- The service stores no images and no IP addresses. Only the predicted class,
  the confidence, the detection count, the latency and the request source are
  written to the local SQLite scan log (see `coffee_leaf/store.py`).
- Uploaded images are decoded in memory and never written to disk.

## How to reproduce

```bash
uv venv --python 3.11 && uv pip install -r requirements.txt
python scripts/export_cases.py     # regenerate the published case images
python scripts/benchmark.py 3 15   # regenerate the latency table
```

Retraining instructions live in [`datasets/README.md`](../datasets/README.md).
