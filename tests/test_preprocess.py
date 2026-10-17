"""Tests for the OpenCV leaf auto-crop."""

from __future__ import annotations

import cv2
import numpy as np

from coffee_leaf.preprocess import MIN_AREA_RATIO, auto_crop_leaf


def _frame_with_leaf(size: int = 200, radius: int = 40) -> np.ndarray:
    """A dark frame with a large green disc in the middle."""
    image = np.full((size, size, 3), 30, dtype=np.uint8)
    cv2.circle(image, (size // 2, size // 2), radius, (70, 190, 80), -1)
    return image


def test_crops_tight_around_the_green_region():
    frame = _frame_with_leaf()
    cropped = auto_crop_leaf(frame)

    assert cropped is not None
    assert cropped.size > 0
    assert cropped.shape[0] < frame.shape[0]
    assert cropped.shape[1] < frame.shape[1]
    # The crop keeps the whole disc: its width is close to the diameter.
    assert abs(cropped.shape[1] - 90) < 25


def test_returns_the_original_frame_when_no_leaf_is_present():
    flat = np.full((120, 120, 3), 20, dtype=np.uint8)
    assert auto_crop_leaf(flat).shape == flat.shape


def test_ignores_regions_below_the_area_threshold():
    frame = np.full((400, 400, 3), 25, dtype=np.uint8)
    # A small green speck well under MIN_AREA_RATIO of the frame.
    speck = int((400 * 400 * MIN_AREA_RATIO / 4) ** 0.5)
    cv2.circle(frame, (200, 200), max(speck - 2, 1), (70, 190, 80), -1)
    assert auto_crop_leaf(frame).shape == frame.shape


def test_handles_degenerate_input():
    assert auto_crop_leaf(np.empty((0, 0, 3), dtype=np.uint8)).size == 0
    assert auto_crop_leaf(None) is None
