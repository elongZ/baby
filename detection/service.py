from __future__ import annotations

from pathlib import Path

from detection.scripts.common import (
    build_dataset_yaml,
    ensure_ultralytics,
    load_config,
    resolve_device,
    resolve_run_dir,
    resolve_weights_path,
)


def _format_detection_ratio(value: float) -> str:
    return f"{value * 100:.1f}%"


def _summarize_label_counts(detections: list[dict]) -> str:
    counts = _count_labels(detections)
    return "，".join(
        f"{label} {count} 个"
        for label, count in sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))
    )


def _count_labels(detections: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in detections:
        label = str(item["label"])
        counts[label] = counts.get(label, 0) + 1
    return counts


def _build_detection_explanation(
    detections: list[dict],
    confidence_threshold: float,
    iou_threshold: float,
) -> tuple[str, str]:
    if not detections:
        explanation = (
            f"当前没有保留下来的检测框。先确认图里是否确实没有目标；如果目标存在，"
            f"说明现有特征没能稳定超过置信度阈值 {_format_detection_ratio(confidence_threshold)}。"
        )
        inspection_tip = (
            f"可以先把 confidence 从 {_format_detection_ratio(confidence_threshold)} 再下调一点，"
            "观察是否出现零散候选框；如果一放宽就冒出很多杂框，通常说明背景纹理在干扰。"
        )
        return explanation, inspection_tip

    sorted_detections = sorted(detections, key=lambda item: float(item["confidence"]), reverse=True)
    top_detection = sorted_detections[0]
    confidences = [float(item["confidence"]) for item in sorted_detections]
    average_confidence = sum(confidences) / len(confidences)
    near_threshold_limit = min(confidence_threshold + 0.15, 0.95)
    near_threshold_count = sum(conf < near_threshold_limit for conf in confidences)
    label_counts = _count_labels(sorted_detections)
    repeated_label_count = sum(1 for count in label_counts.values() if count > 1)

    explanation_parts = [
        (
            f"当前保留了 {len(sorted_detections)} 个框，主要结果是 {top_detection['label']} "
            f"({_format_detection_ratio(float(top_detection['confidence']))})。"
        ),
        (
            f"本次输出里有 {_summarize_label_counts(sorted_detections)}，"
            f"平均置信度 {_format_detection_ratio(average_confidence)}。"
        ),
    ]

    if near_threshold_count > 0:
        explanation_parts.append(
            f"其中 {near_threshold_count} 个框贴近当前 confidence 阈值 {_format_detection_ratio(confidence_threshold)}，"
            "这些框更需要警惕局部纹理、遮挡或边界不完整造成的误检。"
        )
    else:
        explanation_parts.append(
            f"所有保留框都明显高于当前 confidence 阈值 {_format_detection_ratio(confidence_threshold)}，"
            "这次结果更像稳定命中，而不是阈值边缘留下来的候选框。"
        )

    inspection_parts = [
        "先核对最高分框是否完整覆盖主体，而不是只框到局部结构。",
    ]
    if repeated_label_count > 0:
        inspection_parts.append(
            f"同类目标被保留了多个框，接着要看它们到底是真有多个目标，还是 IoU 阈值 {_format_detection_ratio(iou_threshold)} 下留下来的重复框。"
        )
    else:
        inspection_parts.append(
            f"这次同类重复框不多，下一步主要看框的位置是否偏小、偏移，尤其是主体边缘是否被截断。"
        )
    if near_threshold_count > 0:
        inspection_parts.append("优先复查低分框附近的背景区域，那里最容易出现伪目标。")
    else:
        inspection_parts.append("如果肉眼仍觉得不准，问题更可能出在类别区分而不是简单阈值设置。")

    return " ".join(explanation_parts), " ".join(inspection_parts)


def build_status(config_path: str | Path = "detection/configs/detection.yaml") -> dict:
    path = Path(config_path).expanduser().resolve()
    config = load_config(path)
    run_dir = resolve_run_dir(config)
    weights_path = resolve_weights_path(config, "best.pt")
    eval_summary_path = run_dir / "evaluation_summary.json"
    return {
        "ready": weights_path.exists(),
        "config_path": str(path),
        "run_dir": str(run_dir),
        "weights_path": str(weights_path),
        "weights_exists": weights_path.exists(),
        "class_names": list(config["classes"]["names"]),
        "model_name": str(config["train"].get("model_name", "")),
        "image_size": int(config["train"].get("image_size", 640)),
        "device": resolve_device(config["train"].get("device", "auto")),
        "confidence_threshold": float(config["infer"].get("confidence_threshold", 0.25)),
        "iou_threshold": float(config["infer"].get("iou_threshold", 0.7)),
        "evaluation_summary_path": str(eval_summary_path),
        "evaluation_summary_exists": eval_summary_path.exists(),
    }


def predict_image(
    image_path: str | Path,
    config_path: str | Path = "detection/configs/detection.yaml",
    confidence_threshold: float | None = None,
    iou_threshold: float | None = None,
) -> dict:
    image = Path(image_path).expanduser().resolve()
    if not image.exists():
        raise FileNotFoundError(f"Image not found: {image}")

    config = load_config(config_path)
    YOLO = ensure_ultralytics()
    build_dataset_yaml(config)
    weights_path = resolve_weights_path(config, "best.pt")
    if not weights_path.exists():
        raise FileNotFoundError(f"Weights not found: {weights_path}")

    save_dir = (Path.cwd() / Path(config["infer"].get("save_dir", "detection/outputs/predict"))).resolve()
    effective_confidence = (
        float(confidence_threshold)
        if confidence_threshold is not None
        else float(config["infer"].get("confidence_threshold", 0.25))
    )
    effective_iou = (
        float(iou_threshold)
        if iou_threshold is not None
        else float(config["infer"].get("iou_threshold", 0.7))
    )
    model = YOLO(str(weights_path))
    results = model.predict(
        source=str(image),
        conf=effective_confidence,
        iou=effective_iou,
        imgsz=int(config["train"].get("image_size", 640)),
        device=resolve_device(config["train"].get("device", "auto")),
        project=str(save_dir.parent),
        name=save_dir.name,
        exist_ok=True,
        save=True,
        verbose=False,
    )

    result = results[0]
    names = result.names
    detections = []
    if result.boxes is not None:
        for cls_id, conf, xyxy in zip(
            result.boxes.cls.tolist(),
            result.boxes.conf.tolist(),
            result.boxes.xyxy.tolist(),
        ):
            detections.append(
                {
                    "label": names[int(cls_id)],
                    "confidence": float(conf),
                    "box": [float(value) for value in xyxy],
                }
            )

    rendered_path = save_dir / image.name
    explanation, concept = _build_detection_explanation(
        detections,
        confidence_threshold=effective_confidence,
        iou_threshold=effective_iou,
    )
    return {
        "image_path": str(image),
        "rendered_image_path": str(rendered_path) if rendered_path.exists() else None,
        "weights_path": str(weights_path),
        "confidence_threshold": effective_confidence,
        "iou_threshold": effective_iou,
        "detection_count": len(detections),
        "detections": detections,
        "explanation": explanation,
        "concept": concept,
    }
