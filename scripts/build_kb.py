from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

import faiss
import numpy as np
from dotenv import load_dotenv

from scripts.chunk_splitter import SPLITTER_VERSION, ChunkConfig, split_pages
from scripts.embedding_builder import build_embeddings
from scripts.source_loader import collect_source_files, load_source_document
from scripts.text_cleaner import TEXT_CLEANER_VERSION, clean_text

CHUNK_CACHE_DIR_ENV = "CHUNK_CACHE_DIR"
DEFAULT_CHUNK_CACHE_DIR = Path("data/chunk_cache")
PROJECT_ROOT_ENV = "BABY_APP_PROJECT_ROOT"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build FAISS index from source files")
    parser.add_argument("--pdf", help="Optional single PDF file path for one-off builds")
    parser.add_argument(
        "--source-dir",
        default=None,
        help="Directory containing source files to index",
    )
    parser.add_argument("--chunk-size", type=int, default=500)
    parser.add_argument("--chunk-overlap", type=int, default=100)
    parser.add_argument("--force", action="store_true", help="Force rebuild even if no changes are detected")
    return parser.parse_args()


def _manifest_for_paths(source_paths: list[Path], source_dir: Path | None) -> dict:
    base = source_dir.resolve() if source_dir is not None else None
    files = []
    for path in source_paths:
        stat = path.stat()
        if base is not None:
            rel_path = str(path.resolve().relative_to(base))
        else:
            rel_path = path.name
        files.append(
            {
                "path": rel_path,
                "size": stat.st_size,
                "mtime_ns": stat.st_mtime_ns,
            }
        )
    return {"files": files}


def _load_manifest(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _source_key(source_name: str) -> str:
    digest = hashlib.sha1(source_name.encode("utf-8")).hexdigest()[:8]
    stem = "".join(ch.lower() if ch.isalnum() else "-" for ch in Path(source_name).stem).strip("-")
    stem = stem[:24] or "source"
    return f"{stem}-{digest}"


def _chunk_cache_root() -> Path:
    return Path(os.getenv(CHUNK_CACHE_DIR_ENV, str(DEFAULT_CHUNK_CACHE_DIR)))


def _project_root() -> Path:
    return Path(os.getenv(PROJECT_ROOT_ENV, Path.cwd())).resolve()


def _stable_relative_path(path: Path) -> Path:
    resolved = path.resolve()
    project_root = _project_root()
    if resolved.is_relative_to(project_root):
        return resolved.relative_to(project_root)
    return Path(path.name)


def _chunk_cache_paths(path: Path) -> tuple[Path, Path]:
    relative = _stable_relative_path(path)
    base = _chunk_cache_root() / relative
    return base.with_suffix(f"{base.suffix}.chunks.json"), base.with_suffix(f"{base.suffix}.meta.json")


def _chunk_cache_metadata(path: Path, source_name: str, config: ChunkConfig) -> dict:
    stat = path.stat()
    return {
        "source": source_name,
        "source_path": str(path.resolve()),
        "source_size": stat.st_size,
        "source_mtime_ns": stat.st_mtime_ns,
        "chunk_size": config.chunk_size,
        "chunk_overlap": config.chunk_overlap,
        "cleaner_version": TEXT_CLEANER_VERSION,
        "splitter_version": SPLITTER_VERSION,
    }


def _load_chunk_cache(cache_path: Path, meta_path: Path, metadata: dict) -> list[dict] | None:
    if not cache_path.exists() or not meta_path.exists():
        return None

    try:
        cached_meta = json.loads(meta_path.read_text(encoding="utf-8"))
        cached_chunks = json.loads(cache_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

    if cached_meta != metadata:
        return None
    if not isinstance(cached_chunks, list):
        return None
    return cached_chunks


def _write_chunk_cache(cache_path: Path, meta_path: Path, metadata: dict, chunks: list[dict]) -> list[dict]:
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    meta_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(chunks, ensure_ascii=False, indent=2), encoding="utf-8")
    meta_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return chunks


def _prepare_source_chunks(path: Path, source_dir: Path | None, config: ChunkConfig) -> list[dict]:
    document = load_source_document(path, source_dir=source_dir)
    metadata = _chunk_cache_metadata(path, document.source, config)
    cache_path, meta_path = _chunk_cache_paths(path)
    cached = _load_chunk_cache(cache_path, meta_path, metadata)
    if cached is not None:
        print(f"[chunk cache hit] source={document.source} cache={cache_path} chunks={len(cached)}")
        return cached

    print(
        f"[chunk cache miss] source={document.source} cache={cache_path} "
        f"chunk_size={config.chunk_size} chunk_overlap={config.chunk_overlap}"
    )

    source_key = _source_key(document.source)
    cleaned_pages = []
    for page_item in document.pages:
        cleaned = clean_text(page_item["text"])
        if cleaned:
            cleaned_pages.append({"page": page_item["page"], "text": cleaned})

    page_chunks = split_pages(cleaned_pages, config=config)
    chunks = []
    for idx, item in enumerate(page_chunks):
        chunks.append(
            {
                "chunk_id": f"{source_key}-p{item['page']:04d}-c{idx:03d}",
                "source": document.source,
                "page": item["page"],
                "text": item["text"],
                "text_hash": hashlib.sha1(item["text"].encode("utf-8")).hexdigest(),
            }
        )

    return _write_chunk_cache(cache_path, meta_path, metadata, chunks)


def _prepare_chunks(source_paths: list[Path], source_dir: Path | None, config: ChunkConfig) -> list[dict]:
    chunks: list[dict] = []
    for path in source_paths:
        chunks.extend(_prepare_source_chunks(path, source_dir, config))
    return chunks


def _chunk_signature(chunk: dict) -> tuple[str, str]:
    return (
        chunk.get("chunk_id", ""),
        chunk.get("text_hash") or hashlib.sha1(chunk.get("text", "").encode("utf-8")).hexdigest(),
    )


def _load_existing_vectors(
    faiss_index_path: Path,
    chunks_path: Path,
) -> tuple[dict[tuple[str, str], np.ndarray], int]:
    if not faiss_index_path.exists() or not chunks_path.exists():
        return {}, 0

    existing_chunks = json.loads(chunks_path.read_text(encoding="utf-8"))
    index = faiss.read_index(str(faiss_index_path))

    reusable: dict[tuple[str, str], np.ndarray] = {}
    limit = min(len(existing_chunks), index.ntotal)
    for idx in range(limit):
        reusable[_chunk_signature(existing_chunks[idx])] = np.asarray(index.reconstruct(idx), dtype="float32")
    return reusable, limit


def _build_vectors_incrementally(
    chunks: list[dict],
    *,
    embedding_model: str,
    faiss_index_path: Path,
    chunks_path: Path,
) -> tuple[np.ndarray, dict]:
    reusable_vectors, reusable_count = _load_existing_vectors(faiss_index_path, chunks_path)
    ordered_vectors: list[np.ndarray | None] = [None] * len(chunks)
    missing_indices: list[int] = []
    missing_texts: list[str] = []
    reused = 0

    for idx, chunk in enumerate(chunks):
        vector = reusable_vectors.get(_chunk_signature(chunk))
        if vector is None:
            missing_indices.append(idx)
            missing_texts.append(chunk["text"])
            continue
        ordered_vectors[idx] = vector
        reused += 1

    if missing_texts:
        print(
            f"[embedding] model={embedding_model} reused={reused} "
            f"new={len(missing_indices)} total={len(chunks)}"
        )
        new_vectors = build_embeddings(missing_texts, model_name=embedding_model)
        for idx, vector in zip(missing_indices, new_vectors):
            ordered_vectors[idx] = np.asarray(vector, dtype="float32")
    else:
        print(f"[embedding] model={embedding_model} reused={reused} new=0 total={len(chunks)}")

    vectors = np.asarray(ordered_vectors, dtype="float32")
    stats = {
        "reused_vectors": reused,
        "new_vectors": len(missing_indices),
        "loaded_previous_vectors": reusable_count,
    }
    return vectors, stats


def build_kb(
    *,
    source_paths: list[Path],
    embedding_model: str,
    faiss_index_path: Path,
    chunks_path: Path,
    manifest_path: Path,
    source_dir: Path | None,
    chunk_size: int,
    chunk_overlap: int,
) -> dict:
    print(
        f"[build_kb] sources={len(source_paths)} chunk_size={chunk_size} "
        f"chunk_overlap={chunk_overlap}"
    )
    chunks = _prepare_chunks(
        source_paths,
        source_dir=source_dir,
        config=ChunkConfig(chunk_size=chunk_size, chunk_overlap=chunk_overlap),
    )
    if not chunks:
        raise RuntimeError("No chunks generated from source text.")

    vectors, incremental_stats = _build_vectors_incrementally(
        chunks,
        embedding_model=embedding_model,
        faiss_index_path=faiss_index_path,
        chunks_path=chunks_path,
    )
    index = faiss.IndexFlatIP(vectors.shape[1])
    index.add(vectors)

    faiss_index_path.parent.mkdir(parents=True, exist_ok=True)
    chunks_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)

    faiss.write_index(index, str(faiss_index_path))
    chunks_path.write_text(json.dumps(chunks, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest_path.write_text(
        json.dumps(_manifest_for_paths(source_paths, source_dir), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        f"[build_kb done] index={faiss_index_path} chunks={chunks_path} "
        f"manifest={manifest_path}"
    )
    return {
        "chunks": len(chunks),
        "sources": len(source_paths),
        **incremental_stats,
    }


def ensure_kb_current(
    *,
    source_dir: str | Path,
    embedding_model: str,
    faiss_index_path: str | Path,
    chunks_path: str | Path,
    manifest_path: str | Path,
    chunk_size: int = 500,
    chunk_overlap: int = 100,
    force: bool = False,
) -> dict | None:
    base_dir = Path(source_dir)
    source_paths = collect_source_files(base_dir)
    faiss_path = Path(faiss_index_path)
    chunks_file = Path(chunks_path)
    manifest_file = Path(manifest_path)

    if not source_paths:
        if faiss_path.exists() and chunks_file.exists():
            return None
        raise RuntimeError(f"No supported source files found under: {base_dir}")

    current_manifest = _manifest_for_paths(source_paths, base_dir)
    cached_manifest = _load_manifest(manifest_file)
    needs_rebuild = force or not faiss_path.exists() or not chunks_file.exists() or cached_manifest != current_manifest
    if not needs_rebuild:
        return None

    return build_kb(
        source_paths=source_paths,
        embedding_model=embedding_model,
        faiss_index_path=faiss_path,
        chunks_path=chunks_file,
        manifest_path=manifest_file,
        source_dir=base_dir,
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
    )


def main() -> None:
    load_dotenv()
    args = parse_args()

    embedding_model = os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5")
    faiss_index_path = Path(os.getenv("FAISS_INDEX_PATH", "workspace/vector_db/faiss.index"))
    chunks_path = Path(os.getenv("CHUNKS_PATH", "workspace/vector_db/chunks.json"))
    manifest_path = Path(os.getenv("KB_MANIFEST_PATH", "workspace/vector_db/source_manifest.json"))

    if args.pdf:
        source_path = Path(args.pdf)
        result = build_kb(
            source_paths=[source_path],
            embedding_model=embedding_model,
            faiss_index_path=faiss_index_path,
            chunks_path=chunks_path,
            manifest_path=manifest_path,
            source_dir=source_path.parent,
            chunk_size=args.chunk_size,
            chunk_overlap=args.chunk_overlap,
        )
        print(f"Built index: {faiss_index_path}")
        print(f"Saved chunks: {chunks_path}")
        print(f"Sources: {result['sources']} | Total chunks: {result['chunks']}")
        print(
            "Reused vectors: "
            f"{result['reused_vectors']} | New vectors: {result['new_vectors']}"
        )
        return

    source_dir = Path(args.source_dir or os.getenv("KB_SOURCE_DIR", "workspace/kb_sources"))
    result = ensure_kb_current(
        source_dir=source_dir,
        embedding_model=embedding_model,
        faiss_index_path=faiss_index_path,
        chunks_path=chunks_path,
        manifest_path=manifest_path,
        chunk_size=args.chunk_size,
        chunk_overlap=args.chunk_overlap,
        force=args.force,
    )
    if result is not None:
        print(f"Built index from source dir: {source_dir}")
        print(f"Sources: {result['sources']} | Total chunks: {result['chunks']}")
        print(
            "Reused vectors: "
            f"{result['reused_vectors']} | New vectors: {result['new_vectors']}"
        )
    else:
        print(f"Knowledge base already up to date: {source_dir}")
    print(f"Index path: {faiss_index_path}")
    print(f"Chunks path: {chunks_path}")
    print(f"Manifest path: {manifest_path}")


if __name__ == "__main__":
    main()
