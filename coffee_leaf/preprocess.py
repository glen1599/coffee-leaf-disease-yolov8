"""OpenCV pre-processing helpers for coffee-leaf images."""

from __future__ import annotations

import cv2
import numpy as np

# Padding (px) added around the detected leaf contour.
PADDING = 10
# Below this fraction of the frame the detected region is treated as noise.
MIN_AREA_RATIO = 0.03


def auto_crop_leaf(image: np.ndarray) -> np.ndarray:
    """Return a tight crop around the largest green region of ``image``.

    Two independent green indices are thresholded with Otsu's method and
    intersected, which is more robust than a single fixed HSV range for
    photos taken under varying light. The original image is returned
    unchanged when no region is found.

    Args:
        image: BGR uint8 image as produced by ``cv2.imdecode``.

    Returns:
        The cropped BGR image, or ``image`` itself when no leaf is found.
    """
    if image is None or image.size == 0:
        return image

    blue, green, red = cv2.split(image.astype(np.float32))

    # Index 1: normalised green.
    total = green + blue + red + 1e-6
    normalised_green = cv2.normalize(green / total, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
    _, mask_green = cv2.threshold(
        normalised_green, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )

    # Index 2: excess green (2G - R - B).
    excess_green = cv2.normalize(
        green * 2 - blue - red, None, 0, 255, cv2.NORM_MINMAX
    ).astype(np.uint8)
    _, mask_excess = cv2.threshold(
        excess_green, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )

    mask = cv2.bitwise_and(mask_green, mask_excess)

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    for operation in (cv2.MORPH_CLOSE, cv2.MORPH_OPEN, cv2.MORPH_CLOSE):
        mask = cv2.morphologyEx(mask, operation, kernel)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return image

    largest = max(contours, key=cv2.contourArea)
    height, width = image.shape[:2]
    if cv2.contourArea(largest) / (height * width) < MIN_AREA_RATIO:
        return image

    x, y, box_w, box_h = cv2.boundingRect(largest)
    x1 = max(x - PADDING, 0)
    y1 = max(y - PADDING, 0)
    x2 = min(x + box_w + PADDING, width)
    y2 = min(y + box_h + PADDING, height)
    return image[y1:y2, x1:x2]
