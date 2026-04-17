from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image
from torch.utils.data import Dataset

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def is_image_file(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS


def build_class_mapping(class_names: list[str]) -> tuple[dict[str, int], dict[int, str]]:
    if not class_names:
        raise ValueError("class_names must not be empty")
    class_to_idx = {name: idx for idx, name in enumerate(class_names)}
    idx_to_class = {idx: name for name, idx in class_to_idx.items()}
    return class_to_idx, idx_to_class


@dataclass(frozen=True)
class Sample:
    path: Path
    label: int
    class_name: str


def scan_samples(root_dir: str | Path, class_names: list[str]) -> list[Sample]:
    root = Path(root_dir)
    if not root.exists():
        raise FileNotFoundError(f"Dataset directory not found: {root}")

    class_to_idx, _ = build_class_mapping(class_names)
    samples: list[Sample] = []

    for class_name in class_names:
        class_dir = root / class_name
        if not class_dir.exists():
            raise FileNotFoundError(f"Class directory not found: {class_dir}")
        if not class_dir.is_dir():
            raise NotADirectoryError(f"Class path is not a directory: {class_dir}")

        class_files = sorted(path for path in class_dir.rglob("*") if is_image_file(path))
        if not class_files:
            raise ValueError(f"No image files found under class directory: {class_dir}")

        for path in class_files:
            samples.append(
                Sample(
                    path=path,
                    label=class_to_idx[class_name],
                    class_name=class_name,
                )
            )

    if not samples:
        raise ValueError(f"No samples found in dataset directory: {root}")
    return samples


class ImageClassificationDataset(Dataset):
    def __init__(
        self,
        root_dir: str | Path,
        class_names: list[str],
        transform: Callable | None = None,
    ) -> None:
        self.root_dir = Path(root_dir)
        self.class_names = list(class_names)
        self.class_to_idx, self.idx_to_class = build_class_mapping(self.class_names)
        self.samples = scan_samples(self.root_dir, self.class_names)
        self.transform = transform

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int) -> dict:
        sample = self.samples[index]
        image = Image.open(sample.path).convert("RGB")
        if self.transform is not None:
            image = self.transform(image)
        return {
            "image": image,
            "label": sample.label,
            "class_name": sample.class_name,
            "path": str(sample.path),
        }


def create_dataset(
    root_dir: str | Path,
    class_names: list[str],
    transform: Callable | None = None,
) -> ImageClassificationDataset:
    return ImageClassificationDataset(
        root_dir=root_dir,
        class_names=class_names,
        transform=transform,
    )
