from __future__ import annotations

import argparse
from pathlib import Path

from detection.scripts.common import (
    build_dataset_yaml,
    ensure_ultralytics,
    load_config,
    resolve_device,
    resolve_weights_path,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run YOLO detection inference on a single image")
    parser.add_argument(
        "--config",
        default="detection/configs/detection.yaml",
        help="Path to detection YAML config",
    )
    parser.add_argument("--image", required=True, help="Path to the image for detection")
    parser.add_argument(
        "--weights",
        default=None,
        help="Optional path to model weights. Defaults to best.pt in the configured run directory.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    YOLO = ensure_ultralytics()

    image_path = Path(args.image)
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    build_dataset_yaml(config)
    weights_path = Path(args.weights) if args.weights else resolve_weights_path(config, "best.pt")
    if not weights_path.exists():
        raise FileNotFoundError(f"Weights not found: {weights_path}")

    save_dir = Path(config["infer"].get("save_dir", "detection/outputs/predict"))
    model = YOLO(str(weights_path))
    results = model.predict(
        source=str(image_path),
        conf=float(config["infer"].get("confidence_threshold", 0.25)),
        iou=float(config["infer"].get("iou_threshold", 0.7)),
        imgsz=int(config["train"].get("image_size", 640)),
        device=resolve_device(config["train"].get("device", "auto")),
        project=str(save_dir.parent),
        name=save_dir.name,
        exist_ok=True,
        save=True,
        verbose=False,
    )

    result = results[0]
    print(f"Image: {image_path}")
    print(f"Saved prediction visualizations under: {save_dir}")
    print(f"Detected boxes: {len(result.boxes) if result.boxes is not None else 0}")
    if result.boxes is not None:
        names = result.names
        for cls_id, conf, xyxy in zip(
            result.boxes.cls.tolist(),
            result.boxes.conf.tolist(),
            result.boxes.xyxy.tolist(),
        ):
            label = names[int(cls_id)]
            print(f"{label}: conf={conf:.4f} box={[round(v, 1) for v in xyxy]}")


if __name__ == "__main__":
    main()
