from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import seaborn as sns
import torch
import yaml
from sklearn.metrics import classification_report, confusion_matrix
from torch.utils.data import DataLoader

from vision.src.data.dataset import create_dataset
from vision.src.data.transforms import build_eval_transforms
from vision.src.models.classifier import build_classifier


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate an image classifier")
    parser.add_argument(
        "--config",
        default="vision/configs/classification.yaml",
        help="Path to YAML config",
    )
    return parser.parse_args()


def load_config(path: str | Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def resolve_device(device_name: str) -> torch.device:
    normalized = device_name.strip().lower()
    if normalized == "auto":
        if torch.cuda.is_available():
            return torch.device("cuda")
        if torch.backends.mps.is_available():
            return torch.device("mps")
        return torch.device("cpu")
    return torch.device(normalized)


@torch.no_grad()
def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    output_dir = Path(config["project"]["output_dir"])
    checkpoint_path = output_dir / config["train"].get("checkpoint_name", "best_model.pt")
    if not checkpoint_path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {checkpoint_path}")

    checkpoint = torch.load(checkpoint_path, map_location="cpu")
    class_names = list(checkpoint["class_names"])
    image_size = int(checkpoint["image_size"])
    device = resolve_device(config["train"].get("device", "auto"))

    test_dataset = create_dataset(
        root_dir=config["data"]["test_dir"],
        class_names=class_names,
        transform=build_eval_transforms(image_size=image_size),
    )
    test_loader = DataLoader(
        test_dataset,
        batch_size=int(config["train"]["batch_size"]),
        shuffle=False,
        num_workers=int(config["data"].get("num_workers", 4)),
    )

    model = build_classifier(
        model_name=checkpoint["model_name"],
        num_classes=len(class_names),
        pretrained=False,
    ).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    y_true: list[int] = []
    y_pred: list[int] = []

    for batch in test_loader:
        images = batch["image"].to(device)
        labels = batch["label"]
        logits = model(images)
        predictions = logits.argmax(dim=1).cpu()
        y_true.extend(labels.tolist())
        y_pred.extend(predictions.tolist())

    report = classification_report(
        y_true,
        y_pred,
        target_names=class_names,
        output_dict=True,
        zero_division=0,
    )
    report_path = output_dir / config["eval"].get("report_name", "classification_report.json")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if bool(config["eval"].get("save_confusion_matrix", True)):
        matrix = confusion_matrix(y_true, y_pred)
        plt.figure(figsize=(8, 6))
        sns.heatmap(matrix, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names)
        plt.xlabel("Predicted")
        plt.ylabel("True")
        plt.tight_layout()
        plt.savefig(output_dir / config["eval"].get("confusion_matrix_name", "confusion_matrix.png"))
        plt.close()

    print(f"Evaluation report saved to: {report_path}")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
