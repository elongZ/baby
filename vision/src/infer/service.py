"""Vision 在线推理与状态查询服务。

本模块负责加载分类模型与 prototype 产物，提供单图预测、运行状态查询和评测样本构建能力。
它面向 API 与桌面应用调用，不负责训练流程本身。
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import torch
import yaml
from PIL import Image
from torch.nn import functional as F

from vision.src.data.dataset import scan_samples
from vision.src.data.transforms import build_infer_transforms
from vision.src.models.classifier import build_classifier, load_classifier_state_dict


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


@dataclass
class VisionArtifacts:
    """聚合 Vision 在线推理所需模型、配置和缓存产物。"""

    config_path: Path
    config: dict
    checkpoint_path: Path
    prototype_path: Path
    checkpoint: dict
    class_names: list[str]
    image_size: int
    device: torch.device
    model: torch.nn.Module
    prototype_payload: dict | None


_artifacts_cache: dict[str, VisionArtifacts] = {}


def load_artifacts(config_path: str | Path = "vision/configs/classification.yaml") -> VisionArtifacts:
    """加载并缓存在线推理所需的模型与配置产物。"""

    resolved = str(Path(config_path).expanduser().resolve())
    cached = _artifacts_cache.get(resolved)
    if cached is not None:
        return cached

    path = Path(resolved)
    config = load_config(path)
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

    prototype_path = Path(config["infer"].get("prototype_path", output_dir / "prototypes.json"))
    artifacts = VisionArtifacts(
        config_path=path,
        config=config,
        checkpoint_path=checkpoint_path,
        prototype_path=prototype_path,
        checkpoint=checkpoint,
        class_names=class_names,
        image_size=image_size,
        device=device,
        model=model,
        prototype_payload=load_prototype_payload(prototype_path),
    )
    _artifacts_cache[resolved] = artifacts
    return artifacts


def build_status(config_path: str | Path = "vision/configs/classification.yaml") -> dict:
    """构建当前 Vision 模块的可运行状态摘要。"""

    path = Path(config_path).expanduser().resolve()
    config = load_config(path)
    output_dir = Path(config["project"]["output_dir"])
    checkpoint_path = output_dir / config["train"].get("checkpoint_name", "best_model.pt")
    prototype_path = Path(config["infer"].get("prototype_path", output_dir / "prototypes.json"))

    payload = load_prototype_payload(prototype_path)
    class_names = []
    image_size = None
    model_name = None
    if checkpoint_path.exists():
        checkpoint = torch.load(checkpoint_path, map_location="cpu")
        class_names = list(checkpoint.get("class_names", []))
        image_size = int(checkpoint.get("image_size", 0)) or None
        model_name = checkpoint.get("model_name")

    rejection_mode = str(config["infer"].get("rejection_mode", "softmax")).strip().lower()
    current_threshold = float(
        config["infer"].get(
            "prototype_similarity_threshold" if rejection_mode == "prototype" else "reject_threshold",
            payload.get("recommended_threshold", 0.0) if payload else 0.0,
        )
    )
    return {
        "ready": checkpoint_path.exists(),
        "config_path": str(path),
        "checkpoint_path": str(checkpoint_path),
        "checkpoint_exists": checkpoint_path.exists(),
        "prototype_path": str(prototype_path),
        "prototype_exists": prototype_path.exists(),
        "class_names": class_names,
        "image_size": image_size,
        "model_name": model_name,
        "rejection_mode": rejection_mode,
        "current_threshold": current_threshold,
        "recommended_threshold": payload.get("recommended_threshold") if payload else None,
        "sample_counts": payload.get("sample_counts") if payload else None,
    }


@torch.no_grad()
def predict_image(image_path: str | Path, config_path: str | Path = "vision/configs/classification.yaml") -> dict:
    """对单张图片执行分类与拒识判断。"""

    artifacts = load_artifacts(config_path=config_path)
    path = Path(image_path).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {path}")

    image = Image.open(path).convert("RGB")
    tensor = build_infer_transforms(image_size=artifacts.image_size)(image).unsqueeze(0).to(artifacts.device)
    logits = artifacts.model(tensor)
    probabilities = torch.softmax(logits, dim=1)[0].cpu()

    scored_predictions = [
        {"label": label, "score": float(score)}
        for label, score in sorted(
            zip(artifacts.class_names, probabilities.tolist(), strict=False),
            key=lambda item: item[1],
            reverse=True,
        )
    ]

    predicted_label = scored_predictions[0]["label"]
    max_probability = float(scored_predictions[0]["score"])
    rejection_mode = str(artifacts.config["infer"].get("rejection_mode", "softmax")).strip().lower()

    if rejection_mode == "prototype":
        payload = artifacts.prototype_payload
        if payload is None:
            raise FileNotFoundError(f"Prototype file not found: {artifacts.prototype_path}")

        threshold = float(
            artifacts.config["infer"].get(
                "prototype_similarity_threshold",
                payload.get("recommended_threshold", 0.9),
            )
        )
        feature = F.normalize(artifacts.model.extract_features(tensor), dim=1)[0].cpu()
        prototype_scores = []
        for class_name, values in payload["prototypes"].items():
            prototype = torch.tensor(values, dtype=feature.dtype)
            similarity = float(torch.dot(feature, prototype).item())
            prototype_scores.append({"label": class_name, "score": similarity})

        prototype_scores.sort(key=lambda item: item["score"], reverse=True)
        best_similarity = float(prototype_scores[0]["score"])
        best_label = prototype_scores[0]["label"]
        accepted = best_similarity >= threshold
        final_label = best_label if accepted else "other"
        explanation = (
            f"最高 prototype similarity 为 {best_similarity:.4f}，阈值为 {threshold:.2f}，"
            + ("达到阈值，所以保留为已知类。" if accepted else "低于阈值，所以拒识为 other。")
        )
        concept = "Prototype similarity 用于判断图片是否足够接近已知类中心，这比只看 softmax 更适合拒识。"
        return {
            "image_path": str(path),
            "predicted_label": predicted_label,
            "final_label": final_label,
            "accepted": accepted,
            "rejection_mode": rejection_mode,
            "threshold": threshold,
            "max_probability": max_probability,
            "top_predictions": scored_predictions,
            "prototype_scores": prototype_scores,
            "best_similarity": best_similarity,
            "best_similarity_label": best_label,
            "explanation": explanation,
            "concept": concept,
        }

    threshold = float(artifacts.config["infer"].get("reject_threshold", 0.75))
    accepted = max_probability >= threshold
    final_label = predicted_label if accepted else "other"
    explanation = (
        f"最高 softmax 概率为 {max_probability:.4f}，阈值为 {threshold:.2f}，"
        + ("达到阈值，所以保留预测结果。" if accepted else "低于阈值，所以拒识为 other。")
    )
    concept = "Softmax confidence 反映模型在已知类别之间的偏好，但不能完全代表它是否真的见过这类样本。"
    return {
        "image_path": str(path),
        "predicted_label": predicted_label,
        "final_label": final_label,
        "accepted": accepted,
        "rejection_mode": rejection_mode,
        "threshold": threshold,
        "max_probability": max_probability,
        "top_predictions": scored_predictions,
        "prototype_scores": [],
        "best_similarity": None,
        "best_similarity_label": None,
        "explanation": explanation,
        "concept": concept,
    }


def build_evaluation_samples(config_path: str | Path = "vision/configs/classification.yaml") -> dict:
    """批量生成测试集样本的预测结果，供界面或 API 展示。"""

    artifacts = load_artifacts(config_path=config_path)
    test_dir = Path(artifacts.config["data"]["test_dir"])
    samples = scan_samples(test_dir, artifacts.class_names)

    rows = []
    error_count = 0
    for sample in samples:
        prediction = predict_image(sample.path, config_path=config_path)
        is_error = prediction["final_label"] != sample.class_name
        if is_error:
            error_count += 1
        rows.append(
            {
                "image_path": str(sample.path),
                "file_name": sample.path.name,
                "true_label": sample.class_name,
                "predicted_label": prediction["predicted_label"],
                "final_label": prediction["final_label"],
                "is_error": is_error,
                "accepted": prediction["accepted"],
                "max_probability": prediction["max_probability"],
                "best_similarity": prediction["best_similarity"],
                "explanation": prediction["explanation"],
            }
        )

    return {
        "sample_count": len(rows),
        "error_count": error_count,
        "samples": rows,
    }
