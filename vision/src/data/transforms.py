from __future__ import annotations

from torchvision import transforms


def get_default_normalization() -> tuple[list[float], list[float]]:
    return [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]


def build_train_transforms(image_size: int, augmentation_cfg: dict | None = None):
    mean, std = get_default_normalization()
    augmentation_cfg = augmentation_cfg or {}
    enable_augmentation = augmentation_cfg.get("enable", True)

    steps = [transforms.Resize((image_size, image_size))]
    if enable_augmentation:
        flip_prob = float(augmentation_cfg.get("horizontal_flip", 0.5))
        rotation_degree = float(augmentation_cfg.get("rotation_degree", 10))
        color_jitter_cfg = augmentation_cfg.get("color_jitter", {})
        steps.extend(
            [
                transforms.RandomHorizontalFlip(p=flip_prob),
                transforms.RandomRotation(degrees=rotation_degree),
                transforms.ColorJitter(
                    brightness=float(color_jitter_cfg.get("brightness", 0.2)),
                    contrast=float(color_jitter_cfg.get("contrast", 0.2)),
                    saturation=float(color_jitter_cfg.get("saturation", 0.2)),
                    hue=float(color_jitter_cfg.get("hue", 0.05)),
                ),
            ]
        )
    steps.extend([transforms.ToTensor(), transforms.Normalize(mean=mean, std=std)])
    return transforms.Compose(steps)


def build_eval_transforms(image_size: int):
    mean, std = get_default_normalization()
    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=mean, std=std),
        ]
    )


def build_infer_transforms(image_size: int):
    return build_eval_transforms(image_size=image_size)
