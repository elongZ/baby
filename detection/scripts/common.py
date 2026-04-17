from __future__ import annotations

import json
from pathlib import Path

import yaml


def load_config(path: str | Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def resolve_device(device_name: str) -> str:
    normalized = device_name.strip().lower()
    if normalized != "auto":
        return normalized

    try:
        import torch
    except Exception:
        return "cpu"

    if torch.cuda.is_available():
        return "0"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def ensure_ultralytics():
    try:
        from ultralytics import YOLO
    except Exception as exc:  # pragma: no cover - dependency guard
        raise RuntimeError(
            "ultralytics is required for detection. Install it with: pip install ultralytics"
        ) from exc
    return YOLO


def resolve_run_dir(config: dict) -> Path:
    output_root = Path(config["project"]["output_dir"])
    run_name = config["project"].get("run_name", "exp")

    direct = output_root / run_name
    if direct.exists():
        return direct

    ultralytics_nested = Path("runs/detect") / output_root / run_name
    if ultralytics_nested.exists():
        return ultralytics_nested

    return direct


def resolve_weights_path(config: dict, checkpoint_name: str = "best.pt") -> Path:
    return resolve_run_dir(config) / "weights" / checkpoint_name


def build_dataset_yaml(config: dict) -> Path:
    output_root = Path(config["project"]["output_dir"])
    output_root.mkdir(parents=True, exist_ok=True)
    dataset_yaml_path = output_root / "dataset.yaml"
    payload = {
        "path": str(Path.cwd().resolve()),
        "train": str(Path(config["data"]["train_dir"]).resolve()),
        "val": str(Path(config["data"]["val_dir"]).resolve()),
        "test": str(Path(config["data"]["test_dir"]).resolve()),
        "names": {idx: name for idx, name in enumerate(config["classes"]["names"])},
    }
    dataset_yaml_path.write_text(yaml.safe_dump(payload, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return dataset_yaml_path


def save_json(path: str | Path, payload: dict) -> Path:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return target
