from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

import faiss
from dotenv import load_dotenv

from scripts.chunk_splitter import ChunkConfig, split_pages
from scripts.embedding_builder import build_embeddings
from scripts.source_loader import collect_source_files, load_source_document
from scripts.text_cleaner import clean_text


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


def _prepare_chunks(source_paths: list[Path], source_dir: Path | None, config: ChunkConfig) -> list[dict]:
    chunks: list[dict] = []
    for path in source_paths:
        document = load_source_document(path, source_dir=source_dir)
        source_key = _source_key(document.source)
        cleaned_pages = []
        for page_item in document.pages:
            cleaned = clean_text(page_item["text"])
            if cleaned:
                cleaned_pages.append({"page": page_item["page"], "text": cleaned})

        page_chunks = split_pages(cleaned_pages, config=config)
        for idx, item in enumerate(page_chunks):
            chunks.append(
                {
                    "chunk_id": f"{source_key}-p{item['page']:04d}-c{idx:03d}",
                    "source": document.source,
                    "page": item["page"],
                    "text": item["text"],
                }
            )
    return chunks


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
    chunks = _prepare_chunks(
        source_paths,
        source_dir=source_dir,
        config=ChunkConfig(chunk_size=chunk_size, chunk_overlap=chunk_overlap),
    )
    if not chunks:
        raise RuntimeError("No chunks generated from source text.")

    vectors = build_embeddings([item["text"] for item in chunks], model_name=embedding_model)
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
    return {"chunks": len(chunks), "sources": len(source_paths)}


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
) -> bool:
    base_dir = Path(source_dir)
    source_paths = collect_source_files(base_dir)
    faiss_path = Path(faiss_index_path)
    chunks_file = Path(chunks_path)
    manifest_file = Path(manifest_path)

    if not source_paths:
        if faiss_path.exists() and chunks_file.exists():
            return False
        raise RuntimeError(f"No supported source files found under: {base_dir}")

    current_manifest = _manifest_for_paths(source_paths, base_dir)
    cached_manifest = _load_manifest(manifest_file)
    needs_rebuild = force or not faiss_path.exists() or not chunks_file.exists() or cached_manifest != current_manifest
    if not needs_rebuild:
        return False

    build_kb(
        source_paths=source_paths,
        embedding_model=embedding_model,
        faiss_index_path=faiss_path,
        chunks_path=chunks_file,
        manifest_path=manifest_file,
        source_dir=base_dir,
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
    )
    return True


def main() -> None:
    load_dotenv()
    args = parse_args()

    embedding_model = os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5")
    faiss_index_path = Path(os.getenv("FAISS_INDEX_PATH", "vector_db/faiss.index"))
    chunks_path = Path(os.getenv("CHUNKS_PATH", "vector_db/chunks.json"))
    manifest_path = Path(os.getenv("KB_MANIFEST_PATH", "vector_db/source_manifest.json"))

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
        return

    source_dir = Path(args.source_dir or os.getenv("KB_SOURCE_DIR", "kb_sources"))
    rebuilt = ensure_kb_current(
        source_dir=source_dir,
        embedding_model=embedding_model,
        faiss_index_path=faiss_index_path,
        chunks_path=chunks_path,
        manifest_path=manifest_path,
        chunk_size=args.chunk_size,
        chunk_overlap=args.chunk_overlap,
        force=args.force,
    )
    if rebuilt:
        print(f"Built index from source dir: {source_dir}")
    else:
        print(f"Knowledge base already up to date: {source_dir}")
    print(f"Index path: {faiss_index_path}")
    print(f"Chunks path: {chunks_path}")
    print(f"Manifest path: {manifest_path}")


if __name__ == "__main__":
    main()
