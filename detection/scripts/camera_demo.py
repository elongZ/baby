from __future__ import annotations

import argparse

from detection.opencv_service import OpenCVDetectionService


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run real-time object detection from a camera")
    parser.add_argument(
        "--config",
        default="detection/configs/detection.yaml",
        help="Path to detection YAML config",
    )
    parser.add_argument(
        "--camera-config",
        default="detection/configs/camera.yaml",
        help="Path to camera YAML config",
    )
    parser.add_argument(
        "--confidence",
        type=float,
        default=None,
        help="Optional runtime confidence threshold override",
    )
    parser.add_argument(
        "--iou",
        type=float,
        default=None,
        help="Optional runtime IoU threshold override",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    service = OpenCVDetectionService.from_config(
        detection_config_path=args.config,
        camera_config_path=args.camera_config,
        confidence_threshold=args.confidence,
        iou_threshold=args.iou,
    )
    service.open_camera()

    try:
        import cv2

        print("Camera demo started. Press 'q' to quit.")
        while True:
            frame = service.read_frame()
            rendered_frame, payload = service.process_frame(frame)
            cv2.imshow(service.camera_config.window_name, rendered_frame)

            key = cv2.waitKey(1) & 0xFF
            if key in {ord("q"), 27}:
                break

            if payload.get("detection_count"):
                top = payload["detections"][0]
                print(
                    f"top={top['label']} conf={top['confidence']:.3f} "
                    f"count={payload['detection_count']}",
                    end="\r",
                    flush=True,
                )
    finally:
        service.close()
        try:
            import cv2

            cv2.destroyAllWindows()
        except Exception:
            pass


if __name__ == "__main__":
    main()
