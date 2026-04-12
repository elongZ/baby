from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from scripts.pdf_loader import load_pdf_pages

SUPPORTED_EXTENSIONS = {".pdf", ".txt", ".md"}
TEXT_ENCODINGS = ("utf-8", "utf-8-sig", "gb18030")


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


def load_source_document(path: str | Path, source_dir: str | Path | None = None) -> SourceDocument:
    file_path = Path(path)
    base = Path(source_dir) if source_dir is not None else file_path.parent
    source_name = str(file_path.relative_to(base)) if file_path.is_relative_to(base) else file_path.name

    if file_path.suffix.lower() == ".pdf":
        pages = [{"page": item.page, "text": item.text} for item in load_pdf_pages(file_path)]
    else:
        pages = [{"page": 1, "text": _read_text_file(file_path)}]

    return SourceDocument(path=file_path, source=source_name, pages=pages)
