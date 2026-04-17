from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
import yaml
from torch.nn import functional as F
from torch.utils.data import DataLoader

from vision.src.data.dataset import create_dataset
from vision.src.data.transforms import build_eval_transforms
from vision.src.models.classifier import build_classifier, load_classifier_state_dict


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build class prototypes from a trained classifier")
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

    dataset = create_dataset(
        root_dir=config["data"]["train_dir"],
        class_names=class_names,
        transform=build_eval_transforms(image_size=image_size),
    )
    loader = DataLoader(
        dataset,
        batch_size=int(config["train"]["batch_size"]),
        shuffle=False,
        num_workers=int(config["data"].get("num_workers", 0)),
    )

    model = build_classifier(
        model_name=checkpoint["model_name"],
        num_classes=len(class_names),
        pretrained=False,
    ).to(device)
    load_classifier_state_dict(model, checkpoint["model_state_dict"])
    model.eval()

    feature_buckets: dict[int, list[torch.Tensor]] = {idx: [] for idx in range(len(class_names))}
    sample_counts = {name: 0 for name in class_names}

    for batch in loader:
        images = batch["image"].to(device)
        labels = batch["label"]
        features = F.normalize(model.extract_features(images), dim=1).cpu()
        for feature, label in zip(features, labels.tolist(), strict=False):
            feature_buckets[label].append(feature)
            sample_counts[class_names[label]] += 1

    prototypes: dict[str, list[float]] = {}
    similarity_values: list[float] = []
    class_stats: dict[str, dict[str, float | int]] = {}
    for idx, class_name in enumerate(class_names):
        if not feature_buckets[idx]:
            raise RuntimeError(f"No features collected for class: {class_name}")
        stacked = torch.stack(feature_buckets[idx])
        prototype = F.normalize(stacked.mean(dim=0), dim=0)
        similarities = torch.matmul(stacked, prototype)
        prototypes[class_name] = prototype.tolist()
        class_stats[class_name] = {
            "count": int(similarities.numel()),
            "mean_similarity": float(similarities.mean().item()),
            "min_similarity": float(similarities.min().item()),
            "p10_similarity": float(torch.quantile(similarities, 0.10).item()),
        }
        similarity_values.extend(similarities.tolist())

    similarities_tensor = torch.tensor(similarity_values, dtype=torch.float32)
    recommended_threshold = float(torch.quantile(similarities_tensor, 0.10).item())
    prototype_path = Path(config["infer"].get("prototype_path", output_dir / "prototypes.json"))
    payload = {
        "class_names": class_names,
        "metric": "cosine_similarity",
        "recommended_threshold": recommended_threshold,
        "sample_counts": sample_counts,
        "class_stats": class_stats,
        "prototypes": prototypes,
    }
    prototype_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved prototypes to: {prototype_path}")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
