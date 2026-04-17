from __future__ import annotations

import argparse
import random
import shutil
from pathlib import Path

import yaml


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Split raw classification images into train/val/test")
    parser.add_argument(
        "--config",
        default="vision/configs/classification.yaml",
        help="Path to YAML config",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy files instead of creating symlinks",
    )
    return parser.parse_args()


def load_config(path: str | Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def list_images(path: Path) -> list[Path]:
    return sorted(
        file_path
        for file_path in path.iterdir()
        if file_path.is_file() and file_path.suffix.lower() in IMAGE_SUFFIXES
    )


def reset_split_dir(split_root: Path, class_names: list[str]) -> None:
    split_root.mkdir(parents=True, exist_ok=True)
    for split_name in ("train", "val", "test"):
        split_dir = split_root / split_name
        if split_dir.exists():
            shutil.rmtree(split_dir)
        for class_name in class_names:
            (split_dir / class_name).mkdir(parents=True, exist_ok=True)


def assign_items(
    files: list[Path],
    *,
    train_ratio: float,
    val_ratio: float,
) -> dict[str, list[Path]]:
    total = len(files)
    train_count = int(total * train_ratio)
    val_count = int(total * val_ratio)
    test_count = total - train_count - val_count

    if train_count == 0 or val_count == 0 or test_count == 0:
        raise ValueError(
            "Split ratios produce an empty split. Increase image count or adjust ratios."
        )

    return {
        "train": files[:train_count],
        "val": files[train_count : train_count + val_count],
        "test": files[train_count + val_count :],
    }


def materialize_split(
    assignments: dict[str, list[Path]],
    *,
    split_root: Path,
    class_name: str,
    copy_files: bool,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for split_name, files in assignments.items():
        target_dir = split_root / split_name / class_name
        for source_path in files:
            target_path = target_dir / source_path.name
            if copy_files:
                shutil.copy2(source_path, target_path)
            else:
                target_path.symlink_to(source_path.resolve())
        counts[split_name] = len(files)
    return counts


def main() -> None:
    args = parse_args()
    config = load_config(args.config)

    class_names = list(config["classes"]["names"])
    raw_root = Path(config["data"]["raw_dir"])
    split_root = Path(config["data"]["split_dir"])
    train_ratio = float(config["split"]["train_ratio"])
    val_ratio = float(config["split"]["val_ratio"])
    test_ratio = float(config["split"]["test_ratio"])
    seed = int(config["split"]["random_seed"])

    if abs((train_ratio + val_ratio + test_ratio) - 1.0) > 1e-6:
        raise ValueError("train_ratio + val_ratio + test_ratio must equal 1.0")

    rng = random.Random(seed)
    reset_split_dir(split_root, class_names)

    for class_name in class_names:
        class_dir = raw_root / class_name
        if not class_dir.exists():
            raise FileNotFoundError(f"Raw class directory not found: {class_dir}")
        files = list_images(class_dir)
        if len(files) < 3:
            raise ValueError(f"Need at least 3 images to split class '{class_name}'")
        rng.shuffle(files)
        assignments = assign_items(
            files,
            train_ratio=train_ratio,
            val_ratio=val_ratio,
        )
        counts = materialize_split(
            assignments,
            split_root=split_root,
            class_name=class_name,
            copy_files=args.copy,
        )
        print(
            f"{class_name}: total={len(files)} "
            f"train={counts['train']} val={counts['val']} test={counts['test']}"
        )

    print(f"Split dataset created under: {split_root}")


if __name__ == "__main__":
    main()
