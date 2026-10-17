# Training artefacts

Evidence behind the metrics shown in the app and the README.

| File | Description |
| --- | --- |
| `results.csv` | Per-epoch loss and validation metrics for all 50 epochs. |
| `args.yaml` | Exact Ultralytics training arguments. |

The plots referenced by the UI live in `static/img/training/` because they are
served to the browser:

| File | Description |
| --- | --- |
| `results.png` | Loss, precision, recall and mAP curves. |
| `confusion_matrix.png` / `confusion_matrix_normalized.png` | Class confusion on the validation split. |
| `BoxPR_curve.png` | Precision-recall curve. |
| `BoxF1_curve.png`, `BoxP_curve.png`, `BoxR_curve.png` | F1 / precision / recall against confidence. |
| `labels.jpg` | Class and box distribution in the training set. |
| `val_batch0_labels.jpg`, `val_batch0_pred.jpg` | Ground truth vs. predictions on a validation batch. |

## Final epoch (50/50)

| Metric | Value |
| --- | --- |
| Precision | 0.96985 |
| Recall | 0.96593 |
| mAP@50 | 0.98490 |
| mAP@50-95 | 0.76318 |
