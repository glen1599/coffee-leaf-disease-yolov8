# Dataset

The training data is **not committed** to this repository (it is 111 MB / 3,992 images).
Place it here as `datasets/coffee_leaf_v5i_coco/` if you want to retrain.

## Source

| Field | Value |
| --- | --- |
| Dataset | Coffee Leaf — v5 |
| Provider | Roboflow Universe (`metopen-ryukv/coffee-leaf-aodpp`) |
| URL | https://universe.roboflow.com/metopen-ryukv/coffee-leaf-aodpp |
| Format | COCO |
| License | CC BY 4.0 |
| Images | 3,992 (3,493 train / 333 valid / 166 test) |
| Pre-processing | Auto-orient (EXIF stripped), resize to 640×640 (stretch) |
| Augmentation | 3× per source image: horizontal flip, ±15° rotation, ±10% exposure |

## Classes

The COCO export carries a region-level supercategory (`coffee-leaf-diseases`) plus the
four detection classes used by the model:

| Index | Annotation name | Model class key | Display label |
| --- | --- | --- | --- |
| 0 | Bercak Phoma | `bercak_phoma` | Phoma Leaf Spot |
| 1 | Karat Daun | `karat_daun` | Coffee Leaf Rust |
| 2 | Pengorok Daun | `pengorok_daun` | Leaf Miner |
| 3 | Sehat | `sehat` | Healthy |

> The Indonesian keys are baked into `models/best.pt` and must not be renamed.
> Only the display labels are translated; see `coffee_leaf/config.py`.

## Retraining

```bash
yolo detect train model=yolov8n.pt data=datasets/data.yaml epochs=50 imgsz=640
```

Copy the resulting `runs/detect/train/weights/best.pt` over `models/best.pt`, then
update `MODEL_METRICS` in `coffee_leaf/config.py` with the final epoch values from
`runs/detect/train/results.csv` so the dashboard reports real numbers.
