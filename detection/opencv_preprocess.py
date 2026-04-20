from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from detection.scripts.common import load_config

try:
    import cv2
except Exception as exc:  # pragma: no cover - dependency guard
    raise RuntimeError("opencv-python is required for preprocessing. Install it with: pip install opencv-python") from exc

try:
    import numpy as np
except Exception as exc:  # pragma: no cover - dependency guard
    raise RuntimeError("numpy is required for preprocessing. Install it with: pip install numpy") from exc


@dataclass(frozen=True)
class PreprocessConfig:
    enabled: bool
    resize_enabled: bool
    resize_width: int
    resize_height: int
    brightness_enabled: bool
    brightness_beta: float
    contrast_enabled: bool
    contrast_alpha: float
    blur_enabled: bool
    blur_kernel_size: int
    roi_enabled: bool
    roi_x: int
    roi_y: int
    roi_width: int
    roi_height: int

    @classmethod
    def from_yaml(
        cls,
        config_path: str | Path = "detection/configs/preprocess.yaml",
    ) -> "PreprocessConfig":
        config = load_config(config_path)
        resize = config.get("resize", {})
        brightness = config.get("brightness", {})
        contrast = config.get("contrast", {})
        blur = config.get("gaussian_blur", {})
        roi = config.get("roi", {})
        kernel_size = int(blur.get("kernel_size", 5))
        if kernel_size % 2 == 0:
            kernel_size += 1

        return cls(
            enabled=bool(config.get("enabled", False)),
            resize_enabled=bool(resize.get("enabled", False)),
            resize_width=max(1, int(resize.get("width", 640))),
            resize_height=max(1, int(resize.get("height", 640))),
            brightness_enabled=bool(brightness.get("enabled", False)),
            brightness_beta=float(brightness.get("beta", 0.0)),
            contrast_enabled=bool(contrast.get("enabled", False)),
            contrast_alpha=float(contrast.get("alpha", 1.0)),
            blur_enabled=bool(blur.get("enabled", False)),
            blur_kernel_size=max(1, kernel_size),
            roi_enabled=bool(roi.get("enabled", False)),
            roi_x=max(0, int(roi.get("x", 0))),
            roi_y=max(0, int(roi.get("y", 0))),
            roi_width=max(1, int(roi.get("width", 640))),
            roi_height=max(1, int(roi.get("height", 640))),
        )


def preprocess_frame(
    frame_bgr: "np.ndarray",
    config: PreprocessConfig,
) -> tuple["np.ndarray", dict]:
    processed = frame_bgr.copy()
    steps: list[str] = []

    if not config.enabled:
        return processed, {"enabled": False, "steps": steps}

    if config.roi_enabled:
        height, width = processed.shape[:2]
        x1 = min(config.roi_x, width - 1)
        y1 = min(config.roi_y, height - 1)
        x2 = min(x1 + config.roi_width, width)
        y2 = min(y1 + config.roi_height, height)
        processed = processed[y1:y2, x1:x2]
        steps.append(f"roi({x1},{y1},{x2},{y2})")

    if config.resize_enabled:
        processed = cv2.resize(
            processed,
            (config.resize_width, config.resize_height),
            interpolation=cv2.INTER_LINEAR,
        )
        steps.append(f"resize({config.resize_width}x{config.resize_height})")

    if config.contrast_enabled or config.brightness_enabled:
        alpha = config.contrast_alpha if config.contrast_enabled else 1.0
        beta = config.brightness_beta if config.brightness_enabled else 0.0
        processed = cv2.convertScaleAbs(processed, alpha=alpha, beta=beta)
        if config.contrast_enabled:
            steps.append(f"contrast(alpha={alpha:.2f})")
        if config.brightness_enabled:
            steps.append(f"brightness(beta={beta:.1f})")

    if config.blur_enabled:
        kernel = (config.blur_kernel_size, config.blur_kernel_size)
        processed = cv2.GaussianBlur(processed, kernel, 0)
        steps.append(f"gaussian_blur(kernel={config.blur_kernel_size})")

    return processed, {"enabled": True, "steps": steps}
