from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import fitz


@dataclass
class PageText:
    page: int
    text: str


def load_pdf_pages(pdf_path: str | Path) -> list[PageText]:
    path = Path(pdf_path)
    if not path.exists():
        raise FileNotFoundError(f"PDF not found: {path}")

    doc = fitz.open(path)
    pages: list[PageText] = []
    for i, page in enumerate(doc):
        pages.append(PageText(page=i + 1, text=page.get_text("text")))
    return pages
