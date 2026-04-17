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
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a YOLO detector")
    parser.add_argument(
        "--config",
        default="detection/configs/detection.yaml",
        help="Path to detection YAML config",
    )
    parser.add_argument(
        "--epochs",
        type=int,
        default=None,
        help="Optional override for training epochs",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=None,
        help="Optional override for training batch size",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    YOLO = ensure_ultralytics()

    dataset_yaml = build_dataset_yaml(config)
    device = resolve_device(config["train"].get("device", "auto"))
    output_root = Path(config["project"]["output_dir"])
    run_name = config["project"].get("run_name", "exp")
    epochs = int(args.epochs) if args.epochs is not None else int(config["train"].get("epochs", 30))
    batch_size = int(args.batch_size) if args.batch_size is not None else int(config["train"].get("batch_size", 8))

    model = YOLO(config["train"]["model_name"])
    model.train(
        data=str(dataset_yaml),
        imgsz=int(config["train"].get("image_size", 640)),
        epochs=epochs,
        batch=batch_size,
        device=device,
        workers=int(config["data"].get("workers", 0)),
        patience=int(config["train"].get("patience", 10)),
        project=str(output_root),
        name=run_name,
        exist_ok=True,
        verbose=True,
        plots=True,
    )

    run_dir = resolve_run_dir(config)
    print(f"Training finished. Configured run directory: {output_root / run_name}")
    print(f"Resolved run directory: {run_dir}")
    print(f"Best checkpoint: {resolve_weights_path(config, 'best.pt')}")
    print(f"Last checkpoint: {resolve_weights_path(config, 'last.pt')}")


if __name__ == "__main__":
    main()
