from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
import yaml
from PIL import Image
from torch.nn import functional as F

from vision.src.data.transforms import build_infer_transforms
from vision.src.models.classifier import build_classifier, load_classifier_state_dict


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run single-image classifier inference")
    parser.add_argument(
        "--config",
        default="vision/configs/classification.yaml",
        help="Path to YAML config",
    )
    parser.add_argument("--image", required=True, help="Path to the image to classify")
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


def load_prototype_payload(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


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

    model = build_classifier(
        model_name=checkpoint["model_name"],
        num_classes=len(class_names),
        pretrained=False,
    ).to(device)
    load_classifier_state_dict(model, checkpoint["model_state_dict"])
    model.eval()

    image_path = Path(args.image)
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    image = Image.open(image_path).convert("RGB")
    tensor = build_infer_transforms(image_size=image_size)(image).unsqueeze(0).to(device)
    logits = model(tensor)
    probabilities = torch.softmax(logits, dim=1)[0].cpu()
    max_prob = float(probabilities.max().item())

    top_k = min(int(config["infer"].get("top_k", 3)), len(class_names))
    scores, indices = torch.topk(probabilities, k=top_k)

    print(f"Image: {image_path}")
    predicted_index = int(indices[0].item())
    predicted_label = class_names[predicted_index]
    final_label = predicted_label
    rejection_mode = str(config["infer"].get("rejection_mode", "softmax")).strip().lower()
    if rejection_mode == "prototype":
        prototype_path = Path(config["infer"].get("prototype_path", output_dir / "prototypes.json"))
        payload = load_prototype_payload(prototype_path)
        if payload is None:
            raise FileNotFoundError(f"Prototype file not found: {prototype_path}")
        threshold = float(
            config["infer"].get(
                "prototype_similarity_threshold",
                payload.get("recommended_threshold", 0.9),
            )
        )
        feature = F.normalize(model.extract_features(tensor), dim=1)[0].cpu()
        similarities = {}
        best_similarity = -1.0
        best_label = predicted_label
        for class_name, values in payload["prototypes"].items():
            prototype = torch.tensor(values, dtype=feature.dtype)
            similarity = float(torch.dot(feature, prototype).item())
            similarities[class_name] = similarity
            if similarity > best_similarity:
                best_similarity = similarity
                best_label = class_name
        final_label = "other" if best_similarity < threshold else best_label
        print(
            f"Final prediction: {final_label} "
            f"(best_similarity={best_similarity:.4f}, threshold={threshold:.2f}, mode=prototype)"
        )
        for class_name, similarity in sorted(similarities.items(), key=lambda item: item[1], reverse=True):
            print(f"{class_name}: {similarity:.4f}")
        print(f"softmax_max_prob: {max_prob:.4f}")
        return

    reject_threshold = float(config["infer"].get("reject_threshold", 0.75))
    final_label = "other" if max_prob < reject_threshold else predicted_label
    print(f"Final prediction: {final_label} (max_prob={max_prob:.4f}, threshold={reject_threshold:.2f}, mode=softmax)")
    for score, index in zip(scores.tolist(), indices.tolist(), strict=False):
        print(f"{class_names[index]}: {score:.4f}")


if __name__ == "__main__":
    main()
