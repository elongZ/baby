"""本地 FastAPI 服务入口。

本模块负责暴露 RAG、Vision、Detection 和 Robotics 相关的 HTTP 接口，
并在进程内组装运行时配置、知识库状态和模型服务调用。
它不负责训练实现或底层算法细节，只负责在线请求编排与状态查询。
"""

from __future__ import annotations

import json
import os
import shutil
import threading
from base64 import b64decode
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

from detection.opencv_preprocess import PreprocessConfig, preprocess_frame
from detection.service import build_status as build_detection_status
from detection.service import predict_frame as predict_detection_frame
from detection.service import predict_image as predict_detection_image
from rag.pipeline import RagPipeline
from robotics.vision_logic import build_robot_decision_payload
from scripts.build_kb import ensure_kb_current
from scripts.source_loader import SUPPORTED_EXTENSIONS, collect_source_files
from vision.src.infer.service import build_evaluation_samples as build_vision_evaluation_samples
from vision.src.infer.service import build_status as build_vision_status
from vision.src.infer.service import predict_image as predict_vision_image

load_dotenv()

app = FastAPI(title="Pediatrics RAG API", version="0.1.0")

pipeline: RagPipeline | None = None
runtime_config: dict | None = None
build_lock = threading.Lock()
build_state = {
    "status": "idle",
    "last_error": None,
    "last_started_at": None,
    "last_completed_at": None,
}


class ImportDocumentRequest(BaseModel):
    """导入单个知识库源文件时使用的请求体。"""

    source_path: str


class ReplaceDocumentRequest(BaseModel):
    """替换已有知识库文件时使用的请求体。"""

    source_path: str


class VisionPredictRequest(BaseModel):
    """Vision 单图预测请求体。"""

    image_path: str


class DetectionPredictRequest(BaseModel):
    """Detection 单图预测请求体。"""

    image_path: str
    confidence_threshold: float | None = None
    iou_threshold: float | None = None


class DetectionFramePredictRequest(BaseModel):
    """Detection 实时帧预测请求体。"""

    image_base64: str
    confidence_threshold: float | None = None
    iou_threshold: float | None = None


def _env_bool(key: str, default: bool = False) -> bool:
    val = os.getenv(key)
    if val is None:
        return default
    return val.strip().lower() in {"1", "true", "yes", "on"}


def _read_adapter_base_model(adapter_dir: Path) -> str | None:
    readme_path = adapter_dir / "README.md"
    if not readme_path.exists():
        return None

    for line in readme_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("base_model:"):
            return line.split(":", 1)[1].strip()
    return None


def _detect_local_lora() -> tuple[str, str] | None:
    candidates = [
        Path("workspace/outputs/lora-qwen2.5-0.5b-full"),
        Path("workspace/outputs/lora-qwen2.5-0.5b-smoke"),
    ]
    for path in candidates:
        if not (path / "adapter_model.safetensors").exists():
            continue
        base_model = _read_adapter_base_model(path) or "Qwen/Qwen2.5-0.5B-Instruct"
        return base_model, str(path.resolve())
    return None


def _adapter_display_name(adapter_path: str) -> str | None:
    if not adapter_path:
        return None
    return Path(adapter_path).expanduser().resolve().name


def _decode_base64_frame(image_base64: str):
    try:
        import cv2
        import numpy as np
    except Exception as exc:
        raise RuntimeError("opencv-python and numpy are required for frame prediction.") from exc

    payload = image_base64.split(",", 1)[-1]
    image_bytes = b64decode(payload)
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    frame_bgr = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if frame_bgr is None:
        raise ValueError("Failed to decode frame bytes.")
    return frame_bgr, cv2


def get_runtime_config() -> dict:
    """解析并缓存当前 API 进程的运行时配置。"""

    global runtime_config
    if runtime_config is not None:
        return runtime_config

    llm_model = os.getenv("LLM_MODEL", "").strip()
    lora_adapter_path = os.getenv("LORA_ADAPTER_PATH", "").strip()
    source = "env"

    if not lora_adapter_path:
        detected = _detect_local_lora()
        if detected is not None:
            llm_model, lora_adapter_path = detected
            source = "auto_detected_local_lora"

    if not llm_model:
        llm_model = "qwen2.5:7b-instruct"

    runtime_config = {
        "embedding_model": os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5"),
        "faiss_index_path": os.getenv("FAISS_INDEX_PATH", "workspace/vector_db/faiss.index"),
        "chunks_path": os.getenv("CHUNKS_PATH", "workspace/vector_db/chunks.json"),
        "llm_model": llm_model,
        "reranker_model": os.getenv("RERANKER_MODEL", "BAAI/bge-reranker-base"),
        "enable_reranker": _env_bool("ENABLE_RERANKER", False),
        "lora_adapter_path": lora_adapter_path,
        "config_source": source,
    }
    return runtime_config


def get_pipeline() -> RagPipeline:
    """按需初始化并复用全局 RAG pipeline。"""

    global pipeline
    if pipeline is None:
        config = get_runtime_config()
        pipeline = RagPipeline(
            embedding_model=config["embedding_model"],
            faiss_index_path=config["faiss_index_path"],
            chunks_path=config["chunks_path"],
            llm_model=config["llm_model"],
            reranker_model=config["reranker_model"],
            enable_reranker=config["enable_reranker"],
            lora_adapter_path=config["lora_adapter_path"],
        )
    return pipeline


def _project_path(value: str | Path) -> Path:
    return Path(value).expanduser().resolve()


def _kb_paths() -> dict[str, Path]:
    config = get_runtime_config()
    return {
        "source_dir": _project_path(os.getenv("KB_SOURCE_DIR", "workspace/kb_sources")),
        "manifest_path": _project_path(os.getenv("KB_MANIFEST_PATH", "workspace/vector_db/source_manifest.json")),
        "chunks_path": _project_path(config["chunks_path"]),
        "faiss_index_path": _project_path(config["faiss_index_path"]),
    }


def _iso_timestamp(path: Path) -> str | None:
    if not path.exists():
        return None
    return datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc).isoformat()


def _load_json(path: Path) -> dict | list | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _current_manifest(source_dir: Path) -> dict:
    files = []
    for path in collect_source_files(source_dir):
        rel_path = str(path.resolve().relative_to(source_dir.resolve()))
        stat = path.stat()
        files.append({"path": rel_path, "size": stat.st_size, "mtime_ns": stat.st_mtime_ns})
    return {"files": files}


def _manifest_diff(current_manifest: dict, cached_manifest: dict | None) -> dict[str, list[str]]:
    cached_map = {item["path"]: item for item in (cached_manifest or {}).get("files", [])}
    current_map = {item["path"]: item for item in current_manifest.get("files", [])}

    added = sorted(path for path in current_map if path not in cached_map)
    deleted = sorted(path for path in cached_map if path not in current_map)
    modified = sorted(
        path
        for path, current in current_map.items()
        if path in cached_map
        and (
            current.get("size") != cached_map[path].get("size")
            or current.get("mtime_ns") != cached_map[path].get("mtime_ns")
        )
    )
    return {"added": added, "modified": modified, "deleted": deleted}


def _chunk_counts(chunks: list[dict] | None) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in chunks or []:
        source = item.get("source")
        if not source:
            continue
        counts[source] = counts.get(source, 0) + 1
    return counts


def _document_records() -> list[dict]:
    paths = _kb_paths()
    source_dir = paths["source_dir"]
    source_dir.mkdir(parents=True, exist_ok=True)

    current_manifest = _current_manifest(source_dir)
    cached_manifest = _load_json(paths["manifest_path"])
    chunks = _load_json(paths["chunks_path"])
    chunk_counts = _chunk_counts(chunks if isinstance(chunks, list) else None)
    diff = _manifest_diff(current_manifest, cached_manifest if isinstance(cached_manifest, dict) else None)
    dirty_paths = set(diff["added"]) | set(diff["modified"]) | set(diff["deleted"])
    cached_files = cached_manifest.get("files", []) if isinstance(cached_manifest, dict) else []
    cached_paths = {item["path"] for item in cached_files}

    records = []
    for path in collect_source_files(source_dir):
        rel_path = str(path.resolve().relative_to(source_dir.resolve()))
        in_manifest = rel_path in cached_paths
        if build_state["status"] == "building":
            index_status = "building"
        elif rel_path in diff["added"]:
            index_status = "not_indexed"
        elif rel_path in diff["modified"] or (dirty_paths and in_manifest):
            index_status = "stale"
        elif in_manifest and chunk_counts.get(rel_path, 0) > 0:
            index_status = "indexed"
        elif in_manifest:
            index_status = "indexed"
        else:
            index_status = "not_indexed"

        records.append(
            {
                "id": rel_path,
                "relative_path": rel_path,
                "absolute_path": str(path.resolve()),
                "name": path.name,
                "extension": path.suffix.lower(),
                "size": path.stat().st_size,
                "modified_at": _iso_timestamp(path),
                "in_manifest": in_manifest,
                "chunk_count": chunk_counts.get(rel_path, 0),
                "last_indexed_at": _iso_timestamp(paths["chunks_path"]) if in_manifest else None,
                "index_status": index_status,
            }
        )

    return records


def _index_status() -> dict:
    config = get_runtime_config()
    paths = _kb_paths()
    source_dir = paths["source_dir"]
    source_dir.mkdir(parents=True, exist_ok=True)

    current_manifest = _current_manifest(source_dir)
    cached_manifest = _load_json(paths["manifest_path"])
    chunks = _load_json(paths["chunks_path"])
    diff = _manifest_diff(current_manifest, cached_manifest if isinstance(cached_manifest, dict) else None)
    chunk_counts = _chunk_counts(chunks if isinstance(chunks, list) else None)
    dirty = any(diff.values())
    cached_files = (cached_manifest or {}).get("files", []) if isinstance(cached_manifest, dict) else []

    build_status = build_state["status"]
    if build_status == "idle":
        if build_state["last_error"]:
            build_status = "failed"
        elif dirty:
            build_status = "stale"
        elif paths["faiss_index_path"].exists() and paths["chunks_path"].exists() and paths["manifest_path"].exists():
            build_status = "ready"
        else:
            build_status = "missing"

    return {
        "source_dir": str(source_dir),
        "manifest_path": str(paths["manifest_path"]),
        "chunks_path": str(paths["chunks_path"]),
        "faiss_index_path": str(paths["faiss_index_path"]),
        "embedding_model": config["embedding_model"],
        "answer_model": config["llm_model"],
        "lora_adapter_path": config["lora_adapter_path"] or None,
        "lora_adapter_name": _adapter_display_name(config["lora_adapter_path"]),
        "generation_mode": get_pipeline().mode_label(),
        "document_count": len(current_manifest["files"]),
        "indexed_document_count": len(cached_files),
        "total_chunks": sum(chunk_counts.values()),
        "index_exists": paths["faiss_index_path"].exists(),
        "chunks_exists": paths["chunks_path"].exists(),
        "manifest_exists": paths["manifest_path"].exists(),
        "index_modified_at": _iso_timestamp(paths["faiss_index_path"]),
        "manifest_modified_at": _iso_timestamp(paths["manifest_path"]),
        "chunks_modified_at": _iso_timestamp(paths["chunks_path"]),
        "last_build_at": build_state["last_completed_at"] or _iso_timestamp(paths["faiss_index_path"]),
        "dirty": dirty,
        "build_status": build_status,
        "last_error": build_state["last_error"],
        "diff": diff,
    }


def _resolve_document_path(document_id: str) -> Path:
    source_dir = _kb_paths()["source_dir"]
    candidate = (source_dir / document_id).resolve()
    try:
        candidate.relative_to(source_dir.resolve())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid document id.") from exc
    return candidate


def _clear_index_files(paths: dict[str, Path]) -> None:
    for key in ("faiss_index_path", "chunks_path", "manifest_path"):
        try:
            paths[key].unlink(missing_ok=True)
        except TypeError:
            if paths[key].exists():
                paths[key].unlink()


def _ensure_kb_materialized(force: bool) -> None:
    paths = _kb_paths()
    if collect_source_files(paths["source_dir"]):
        ensure_kb_current(
            source_dir=paths["source_dir"],
            embedding_model=os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5"),
            faiss_index_path=paths["faiss_index_path"],
            chunks_path=paths["chunks_path"],
            manifest_path=paths["manifest_path"],
            chunk_size=int(os.getenv("CHUNK_SIZE", "500")),
            chunk_overlap=int(os.getenv("CHUNK_OVERLAP", "100")),
            force=force,
        )
    else:
        paths["source_dir"].mkdir(parents=True, exist_ok=True)
        _clear_index_files(paths)


def _rebuild_index(force: bool = True) -> dict:
    global pipeline, runtime_config
    paths = _kb_paths()

    if not build_lock.acquire(blocking=False):
        raise HTTPException(status_code=409, detail="Index rebuild already in progress.")

    build_state["status"] = "building"
    build_state["last_error"] = None
    build_state["last_started_at"] = datetime.now(timezone.utc).isoformat()

    try:
        _ensure_kb_materialized(force=force)
        pipeline = None
        runtime_config = None
        build_state["status"] = "idle"
        build_state["last_completed_at"] = datetime.now(timezone.utc).isoformat()
        return _index_status()
    except Exception as exc:
        build_state["status"] = "idle"
        build_state["last_error"] = str(exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        build_lock.release()


@app.on_event("startup")
def startup() -> None:
    global pipeline, runtime_config
    _ensure_kb_materialized(force=_env_bool("FORCE_REBUILD_KB", False))
    pipeline = None
    runtime_config = None


@app.get("/health")
def health() -> dict:
    config = get_runtime_config()
    return {
        "status": "ok",
        "generation_mode": get_pipeline().mode_label(),
        "llm_model": config["llm_model"],
        "lora_adapter_path": config["lora_adapter_path"],
        "config_source": config["config_source"],
    }


@app.get("/ask")
def ask(
    question: str = Query(..., min_length=2),
    top_k: int = Query(3, ge=1, le=10),
    retrieve_k: int | None = Query(None, ge=1, le=30),
    relevance_threshold: float = Query(0.42, ge=0.0, le=1.0),
) -> dict:
    try:
        return get_pipeline().ask(
            question=question,
            top_k=top_k,
            retrieve_k=retrieve_k,
            relevance_threshold=relevance_threshold,
        )
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/admin/documents")
def list_documents() -> dict:
    return {"documents": _document_records()}


@app.post("/admin/documents/import")
def import_document(request: ImportDocumentRequest) -> dict:
    source_path = Path(request.source_path).expanduser().resolve()
    if not source_path.exists() or not source_path.is_file():
        raise HTTPException(status_code=404, detail="Source file not found.")

    if source_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        allowed = ", ".join(sorted(SUPPORTED_EXTENSIONS))
        raise HTTPException(status_code=400, detail=f"Unsupported extension. Allowed: {allowed}")

    source_dir = _kb_paths()["source_dir"]
    target_dir = source_dir / "uploads"
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / source_path.name

    if target_path.exists():
        raise HTTPException(status_code=409, detail="A document with the same name already exists in uploads.")

    shutil.copy2(source_path, target_path)
    return {"document": str(target_path.relative_to(source_dir.resolve())), "status": "imported"}


@app.delete("/admin/documents/{document_id:path}")
def delete_document(document_id: str) -> dict:
    target_path = _resolve_document_path(document_id)
    if not target_path.exists():
        raise HTTPException(status_code=404, detail="Document not found.")

    target_path.unlink()
    return {"deleted": document_id}


@app.post("/admin/documents/{document_id:path}/replace")
def replace_document(document_id: str, request: ReplaceDocumentRequest) -> dict:
    target_path = _resolve_document_path(document_id)
    if not target_path.exists():
        raise HTTPException(status_code=404, detail="Document not found.")

    source_path = Path(request.source_path).expanduser().resolve()
    if not source_path.exists() or not source_path.is_file():
        raise HTTPException(status_code=404, detail="Replacement source file not found.")

    if source_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        allowed = ", ".join(sorted(SUPPORTED_EXTENSIONS))
        raise HTTPException(status_code=400, detail=f"Unsupported extension. Allowed: {allowed}")

    if source_path.suffix.lower() != target_path.suffix.lower():
        raise HTTPException(status_code=400, detail="Replacement file must use the same extension as the existing document.")

    shutil.copy2(source_path, target_path)
    return {"replaced": document_id}


@app.get("/admin/index/status")
def index_status() -> dict:
    return _index_status()


@app.post("/admin/index/rebuild")
def rebuild_index() -> dict:
    return _rebuild_index(force=True)


@app.get("/vision/status")
def vision_status() -> dict:
    try:
        return build_vision_status()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/vision/predict")
def vision_predict(request: VisionPredictRequest) -> dict:
    try:
        return predict_vision_image(request.image_path)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/vision/evaluation/samples")
def vision_evaluation_samples() -> dict:
    try:
        return build_vision_evaluation_samples()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/detection/status")
def detection_status() -> dict:
    try:
        return build_detection_status()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/detection/predict")
def detection_predict(request: DetectionPredictRequest) -> dict:
    try:
        payload = predict_detection_image(
            request.image_path,
            confidence_threshold=request.confidence_threshold,
            iou_threshold=request.iou_threshold,
        )
        payload["robotics"] = build_robot_decision_payload(payload.get("detections", []))
        return payload
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/detection/predict_frame")
def detection_predict_frame(request: DetectionFramePredictRequest) -> dict:
    try:
        frame_bgr, cv2 = _decode_base64_frame(request.image_base64)
        preprocess_config = PreprocessConfig.from_yaml("detection/configs/preprocess.yaml")
        processed_bgr, preprocess_summary = preprocess_frame(frame_bgr, preprocess_config)
        frame_rgb = cv2.cvtColor(processed_bgr, cv2.COLOR_BGR2RGB)
        payload = predict_detection_frame(
            frame_rgb,
            confidence_threshold=request.confidence_threshold,
            iou_threshold=request.iou_threshold,
        )
        payload["robotics"] = build_robot_decision_payload(payload.get("detections", []))
        payload["preprocess"] = preprocess_summary
        return payload
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
