from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance


SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create simple offline augmentations for YOLO detection training data.")
    parser.add_argument("--images-dir", required=True, help="Training images directory")
    parser.add_argument("--labels-dir", required=True, help="Training labels directory")
    parser.add_argument("--class-id", required=True, type=int, help="Only augment images containing this class id")
    return parser.parse_args()


def label_contains_class(label_path: Path, class_id: int) -> bool:
    if not label_path.exists():
        return False
    for line in label_path.read_text().splitlines():
        parts = line.strip().split()
        if len(parts) == 5 and parts[0] == str(class_id):
            return True
    return False


def flip_label_line(line: str) -> str:
    parts = line.strip().split()
    if len(parts) != 5:
        return line.strip()
    class_id, x_center, y_center, width, height = parts
    flipped_x = 1.0 - float(x_center)
    return f"{class_id} {flipped_x:.6f} {float(y_center):.6f} {float(width):.6f} {float(height):.6f}"


def main() -> None:
    args = parse_args()
    images_dir = Path(args.images_dir)
    labels_dir = Path(args.labels_dir)

    created = 0
    for image_path in sorted(images_dir.iterdir()):
        if not image_path.is_file() or image_path.suffix.lower() not in SUPPORTED_SUFFIXES:
            continue

        label_path = labels_dir / f"{image_path.stem}.txt"
        if not label_contains_class(label_path, args.class_id):
            continue

        with Image.open(image_path) as image:
            image.load()
            mirrored = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            bright = ImageEnhance.Brightness(image).enhance(1.12)
            contrast = ImageEnhance.Contrast(image).enhance(1.15)

            variants = [
                ("flip", mirrored),
                ("bright", bright),
                ("contrast", contrast),
            ]

            original_label_lines = [line.strip() for line in label_path.read_text().splitlines() if line.strip()]
            for suffix, variant in variants:
                variant_image_path = images_dir / f"{image_path.stem}_aug_{suffix}{image_path.suffix.lower()}"
                variant_label_path = labels_dir / f"{image_path.stem}_aug_{suffix}.txt"
                if variant_image_path.exists() or variant_label_path.exists():
                    continue

                variant.save(variant_image_path)
                if suffix == "flip":
                    variant_lines = [flip_label_line(line) for line in original_label_lines]
                else:
                    variant_lines = original_label_lines
                variant_label_path.write_text("\n".join(variant_lines) + "\n")
                created += 1

    print(f"Created {created} augmented samples.")


if __name__ == "__main__":
    main()
