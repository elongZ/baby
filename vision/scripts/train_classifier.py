from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import torch
import yaml
from torch import nn
from torch.optim import Adam
from torch.utils.data import DataLoader

from vision.src.data.dataset import create_dataset
from vision.src.data.transforms import build_eval_transforms, build_train_transforms
from vision.src.models.classifier import build_classifier


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train an image classifier")
    parser.add_argument(
        "--config",
        default="vision/configs/classification.yaml",
        help="Path to YAML config",
    )
    return parser.parse_args()


def load_config(path: str | Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def set_seed(seed: int) -> None:
    random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def resolve_device(device_name: str) -> torch.device:
    normalized = device_name.strip().lower()
    if normalized == "auto":
        if torch.cuda.is_available():
            return torch.device("cuda")
        if torch.backends.mps.is_available():
            return torch.device("mps")
        return torch.device("cpu")
    return torch.device(normalized)


def build_dataloaders(config: dict) -> tuple[DataLoader, DataLoader, list[str]]:
    class_names = list(config["classes"]["names"])
    image_size = int(config["data"]["image_size"])
    num_workers = int(config["data"].get("num_workers", 4))
    batch_size = int(config["train"]["batch_size"])

    train_dataset = create_dataset(
        root_dir=config["data"]["train_dir"],
        class_names=class_names,
        transform=build_train_transforms(image_size=image_size, augmentation_cfg=config.get("augmentation")),
    )
    val_dataset = create_dataset(
        root_dir=config["data"]["val_dir"],
        class_names=class_names,
        transform=build_eval_transforms(image_size=image_size),
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=num_workers,
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=num_workers,
    )
    return train_loader, val_loader, class_names


def train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: Adam,
    device: torch.device,
) -> tuple[float, float]:
    model.train()
    total_loss = 0.0
    total_correct = 0
    total_samples = 0

    for batch in loader:
        images = batch["image"].to(device)
        labels = batch["label"].to(device)

        optimizer.zero_grad()
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * labels.size(0)
        predictions = logits.argmax(dim=1)
        total_correct += (predictions == labels).sum().item()
        total_samples += labels.size(0)

    return total_loss / total_samples, total_correct / total_samples


@torch.no_grad()
def validate_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
) -> tuple[float, float]:
    model.eval()
    total_loss = 0.0
    total_correct = 0
    total_samples = 0

    for batch in loader:
        images = batch["image"].to(device)
        labels = batch["label"].to(device)
        logits = model(images)
        loss = criterion(logits, labels)

        total_loss += loss.item() * labels.size(0)
        predictions = logits.argmax(dim=1)
        total_correct += (predictions == labels).sum().item()
        total_samples += labels.size(0)

    return total_loss / total_samples, total_correct / total_samples


def save_checkpoint(output_dir: Path, checkpoint_name: str, payload: dict) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint_path = output_dir / checkpoint_name
    torch.save(payload, checkpoint_path)
    return checkpoint_path


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    set_seed(int(config["split"]["random_seed"]))

    output_dir = Path(config["project"]["output_dir"])
    device = resolve_device(config["train"].get("device", "auto"))

    train_loader, val_loader, class_names = build_dataloaders(config)

    model = build_classifier(
        model_name=config["train"]["model_name"],
        num_classes=len(class_names),
        pretrained=bool(config["train"].get("pretrained", True)),
    ).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = Adam(
        model.parameters(),
        lr=float(config["train"]["learning_rate"]),
        weight_decay=float(config["train"].get("weight_decay", 0.0)),
    )

    best_val_acc = -1.0
    history: list[dict] = []
    epochs = int(config["train"]["epochs"])
    checkpoint_name = config["train"].get("checkpoint_name", "best_model.pt")

    for epoch in range(1, epochs + 1):
        train_loss, train_acc = train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_loss, val_acc = validate_one_epoch(model, val_loader, criterion, device)
        history.append(
            {
                "epoch": epoch,
                "train_loss": train_loss,
                "train_acc": train_acc,
                "val_loss": val_loss,
                "val_acc": val_acc,
            }
        )

        print(
            f"Epoch {epoch}/{epochs} "
            f"train_loss={train_loss:.4f} train_acc={train_acc:.4f} "
            f"val_loss={val_loss:.4f} val_acc={val_acc:.4f}"
        )

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            save_checkpoint(
                output_dir=output_dir,
                checkpoint_name=checkpoint_name,
                payload={
                    "model_state_dict": model.state_dict(),
                    "class_names": class_names,
                    "model_name": config["train"]["model_name"],
                    "image_size": int(config["data"]["image_size"]),
                },
            )

    output_dir.mkdir(parents=True, exist_ok=True)
    summary_path = output_dir / "train_summary.json"
    summary_path.write_text(
        json.dumps(
            {
                "best_val_acc": best_val_acc,
                "history": history,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Training finished. Best val_acc={best_val_acc:.4f}")
    print(f"Artifacts saved under: {output_dir}")


if __name__ == "__main__":
    main()
