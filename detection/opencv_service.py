from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from detection.scripts.common import load_config
from detection.service import DetectionSession

try:
    import cv2
except Exception as exc:  # pragma: no cover - dependency guard
    raise RuntimeError("opencv-python is required for camera detection. Install it with: pip install opencv-python") from exc

try:
    import numpy as np
except Exception as exc:  # pragma: no cover - dependency guard
    raise RuntimeError("numpy is required for camera detection. Install it with: pip install numpy") from exc


@dataclass
class CameraRuntimeConfig:
    camera_index: int
    frame_width: int
    frame_height: int
    inference_interval: int
    mirror: bool
    window_name: str
    show_fps: bool
    line_thickness: int
    font_scale: float

    @classmethod
    def from_yaml(cls, config_path: str | Path = "detection/configs/camera.yaml") -> "CameraRuntimeConfig":
        config = load_config(config_path)
        return cls(
            camera_index=int(config.get("camera_index", 0)),
            frame_width=int(config.get("frame_width", 1280)),
            frame_height=int(config.get("frame_height", 720)),
            inference_interval=max(1, int(config.get("inference_interval", 3))),
            mirror=bool(config.get("mirror", True)),
            window_name=str(config.get("window_name", "Detection Camera Demo")),
            show_fps=bool(config.get("show_fps", True)),
            line_thickness=max(1, int(config.get("line_thickness", 2))),
            font_scale=float(config.get("font_scale", 0.6)),
        )


class OpenCVDetectionService:
    def __init__(
        self,
        detector: DetectionSession,
        camera_config: CameraRuntimeConfig,
    ) -> None:
        self.detector = detector
        self.camera_config = camera_config
        self.capture: cv2.VideoCapture | None = None
        self.frame_index = 0
        self.last_detection_payload: dict = {
            "detection_count": 0,
            "detections": [],
            "explanation": "",
            "concept": "",
        }
        self.last_inference_fps = 0.0

    @classmethod
    def from_config(
        cls,
        detection_config_path: str | Path = "detection/configs/detection.yaml",
        camera_config_path: str | Path = "detection/configs/camera.yaml",
        confidence_threshold: float | None = None,
        iou_threshold: float | None = None,
    ) -> "OpenCVDetectionService":
        detector = DetectionSession.from_config(
            config_path=detection_config_path,
            confidence_threshold=confidence_threshold,
            iou_threshold=iou_threshold,
        )
        camera_config = CameraRuntimeConfig.from_yaml(camera_config_path)
        return cls(detector=detector, camera_config=camera_config)

    def open_camera(self) -> None:
        capture = cv2.VideoCapture(self.camera_config.camera_index)
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.camera_config.frame_width)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.camera_config.frame_height)
        if not capture.isOpened():
            raise RuntimeError(f"Unable to open camera index {self.camera_config.camera_index}")
        self.capture = capture

    def close(self) -> None:
        if self.capture is not None:
            self.capture.release()
            self.capture = None

    def read_frame(self) -> np.ndarray:
        if self.capture is None:
            raise RuntimeError("Camera is not opened")

        ok, frame = self.capture.read()
        if not ok or frame is None:
            raise RuntimeError("Failed to read frame from camera")
        if self.camera_config.mirror:
            frame = cv2.flip(frame, 1)
        return frame

    def process_frame(self, frame_bgr: np.ndarray) -> tuple[np.ndarray, dict]:
        self.frame_index += 1
        if self.frame_index == 1 or self.frame_index % self.camera_config.inference_interval == 0:
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            started_at = time.perf_counter()
            self.last_detection_payload = self.detector.predict_frame(frame_rgb)
            elapsed = time.perf_counter() - started_at
            self.last_inference_fps = (1.0 / elapsed) if elapsed > 0 else 0.0

        rendered = frame_bgr.copy()
        self._draw_detections(rendered, self.last_detection_payload.get("detections", []))
        if self.camera_config.show_fps:
            self._draw_status(rendered)
        return rendered, self.last_detection_payload

    def _draw_detections(self, frame_bgr: np.ndarray, detections: list[dict]) -> None:
        for item in detections:
            x1, y1, x2, y2 = [int(round(value)) for value in item["box"]]
            label = str(item["label"])
            confidence = float(item["confidence"])
            caption = f"{label} {confidence:.2f}"
            cv2.rectangle(
                frame_bgr,
                (x1, y1),
                (x2, y2),
                (0, 200, 0),
                self.camera_config.line_thickness,
            )
            text_origin = (x1, max(24, y1 - 10))
            cv2.putText(
                frame_bgr,
                caption,
                text_origin,
                cv2.FONT_HERSHEY_SIMPLEX,
                self.camera_config.font_scale,
                (0, 200, 0),
                self.camera_config.line_thickness,
                cv2.LINE_AA,
            )

    def _draw_status(self, frame_bgr: np.ndarray) -> None:
        status = (
            f"Detections: {self.last_detection_payload.get('detection_count', 0)}"
            f" | Infer FPS: {self.last_inference_fps:.1f}"
            f" | Interval: {self.camera_config.inference_interval}"
        )
        cv2.putText(
            frame_bgr,
            status,
            (16, 28),
            cv2.FONT_HERSHEY_SIMPLEX,
            self.camera_config.font_scale,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )
