from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path

from scripts.markitdown_mcp_client import convert_file_to_markdown
from scripts.mineru_client import convert_file_to_markdown as convert_file_with_mineru

TEXT_FILE_EXTENSIONS = {".txt", ".md"}
IMAGE_EXTENSIONS = {
    ".bmp",
    ".gif",
    ".jpeg",
    ".jpg",
    ".jp2",
    ".png",
    ".tiff",
    ".webp",
}
MINERU_EXTENSIONS = IMAGE_EXTENSIONS | {".docx", ".pdf"}
MARKITDOWN_EXTENSIONS = {
    ".csv",
    ".epub",
    ".htm",
    ".html",
    ".json",
    ".pptx",
    ".xls",
    ".xlsx",
    ".xml",
}
SUPPORTED_EXTENSIONS = TEXT_FILE_EXTENSIONS | MARKITDOWN_EXTENSIONS | MINERU_EXTENSIONS
TEXT_ENCODINGS = ("utf-8", "utf-8-sig", "gb18030")
CACHE_DIR_ENV = "CONVERTED_SOURCE_CACHE_DIR"
DEFAULT_CACHE_DIR = Path("data/converted_sources")
PROJECT_ROOT_ENV = "BABY_APP_PROJECT_ROOT"


@dataclass
class SourceDocument:
    path: Path
    source: str
    pages: list[dict]


def is_supported_source(path: Path) -> bool:
    name = path.name
    if name.startswith(".") or name.startswith("~$"):
        return False
    return path.suffix.lower() in SUPPORTED_EXTENSIONS


def collect_source_files(source_dir: str | Path) -> list[Path]:
    base = Path(source_dir)
    if not base.exists():
        return []
    return sorted(path for path in base.rglob("*") if path.is_file() and is_supported_source(path))


def _read_text_file(path: Path) -> str:
    for encoding in TEXT_ENCODINGS:
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="ignore")


def _load_markitdown_document(path: Path) -> str:
    return convert_file_to_markdown(path)


def _load_mineru_document(path: Path) -> str:
    return convert_file_with_mineru(path)


def _cache_root() -> Path:
    return Path(os.getenv(CACHE_DIR_ENV, str(DEFAULT_CACHE_DIR)))


def _project_root() -> Path:
    return Path(os.getenv(PROJECT_ROOT_ENV, Path.cwd())).resolve()


def _stable_relative_path(file_path: Path) -> Path:
    resolved = file_path.resolve()
    project_root = _project_root()
    if resolved.is_relative_to(project_root):
        return resolved.relative_to(project_root)
    return Path(file_path.name)


def _cache_paths(file_path: Path) -> tuple[Path, Path]:
    relative = _stable_relative_path(file_path)

    cache_base = _cache_root() / relative
    return cache_base.with_suffix(f"{cache_base.suffix}.md"), cache_base.with_suffix(f"{cache_base.suffix}.meta.json")


def _source_fingerprint(file_path: Path, converter: str) -> dict:
    resolved = file_path.resolve()
    stat = resolved.stat()
    return {
        "converter": converter,
        "mtime_ns": stat.st_mtime_ns,
        "size": stat.st_size,
        "source_path": str(resolved),
    }


def _read_cached_conversion(markdown_path: Path, meta_path: Path, fingerprint: dict) -> str | None:
    if not markdown_path.exists() or not meta_path.exists():
        return None

    try:
        metadata = json.loads(meta_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

    if metadata != fingerprint:
        return None

    return markdown_path.read_text(encoding="utf-8")


def _write_cached_conversion(markdown_path: Path, meta_path: Path, fingerprint: dict, text: str) -> str:
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    meta_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.write_text(text, encoding="utf-8")
    meta_path.write_text(json.dumps(fingerprint, ensure_ascii=False, indent=2), encoding="utf-8")
    return text


def _load_converted_document(
    file_path: Path,
    *,
    converter: str,
) -> str:
    markdown_path, meta_path = _cache_paths(file_path)
    fingerprint = _source_fingerprint(file_path, converter)
    cached = _read_cached_conversion(markdown_path, meta_path, fingerprint)
    if cached is not None:
        print(
            f"[converted cache hit] source={_stable_relative_path(file_path)} "
            f"converter={converter} cache={markdown_path}"
        )
        return cached

    print(
        f"[converted cache miss] source={_stable_relative_path(file_path)} "
        f"converter={converter} -> building {markdown_path}"
    )

    if converter == "mineru":
        text = _load_mineru_document(file_path)
    else:
        text = _load_markitdown_document(file_path)

    return _write_cached_conversion(markdown_path, meta_path, fingerprint, text)


def load_source_document(path: str | Path, source_dir: str | Path | None = None) -> SourceDocument:
    file_path = Path(path)
    base = Path(source_dir) if source_dir is not None else file_path.parent
    source_name = str(file_path.relative_to(base)) if file_path.is_relative_to(base) else file_path.name

    if file_path.suffix.lower() in TEXT_FILE_EXTENSIONS:
        try:
            text = _load_converted_document(file_path, converter="markitdown")
        except Exception:
            print(f"[converted fallback] source={_stable_relative_path(file_path)} mode=plain-text-read")
            text = _read_text_file(file_path)
    elif file_path.suffix.lower() in MINERU_EXTENSIONS:
        text = _load_converted_document(file_path, converter="mineru")
    else:
        text = _load_converted_document(file_path, converter="markitdown")

    pages = [{"page": 1, "text": text}]

    return SourceDocument(path=file_path, source=source_name, pages=pages)
