from __future__ import annotations

import argparse
from pathlib import Path

from detection.scripts.common import (
    build_dataset_yaml,
    ensure_ultralytics,
    load_config,
    resolve_device,
    resolve_run_dir,
    resolve_weights_path,
    save_json,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate a trained YOLO detector")
    parser.add_argument(
        "--config",
        default="detection/configs/detection.yaml",
        help="Path to detection YAML config",
    )
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

    dataset_yaml = build_dataset_yaml(config)
    weights_path = Path(args.weights) if args.weights else resolve_weights_path(config, "best.pt")
    if not weights_path.exists():
        raise FileNotFoundError(f"Weights not found: {weights_path}")

    model = YOLO(str(weights_path))
    metrics = model.val(
        data=str(dataset_yaml),
        split=str(config["eval"].get("split", "test")),
        imgsz=int(config["train"].get("image_size", 640)),
        batch=int(config["train"].get("batch_size", 8)),
        device=resolve_device(config["train"].get("device", "auto")),
        workers=int(config["data"].get("workers", 0)),
        conf=float(config["eval"].get("confidence_threshold", 0.25)),
        iou=float(config["eval"].get("iou_threshold", 0.7)),
        save_json=bool(config["eval"].get("save_json", False)),
        project=str(Path(config["project"]["output_dir"])),
        name=f"{config['project'].get('run_name', 'exp')}_eval",
        exist_ok=True,
    )

    payload = {
        "weights": str(weights_path),
        "split": str(config["eval"].get("split", "test")),
        "map50": float(metrics.box.map50),
        "map50_95": float(metrics.box.map),
        "mp": float(metrics.box.mp),
        "mr": float(metrics.box.mr),
    }
    summary_path = save_json(
        resolve_run_dir(config) / "evaluation_summary.json",
        payload,
    )
    print(f"Evaluation summary saved to: {summary_path}")
    print(payload)


if __name__ == "__main__":
    main()
