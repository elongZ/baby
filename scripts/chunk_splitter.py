from __future__ import annotations

from dataclasses import dataclass

from langchain_text_splitters import RecursiveCharacterTextSplitter


@dataclass
class ChunkConfig:
    chunk_size: int = 500
    chunk_overlap: int = 100


def split_text(text: str, config: ChunkConfig | None = None) -> list[str]:
    cfg = config or ChunkConfig()
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=cfg.chunk_size,
        chunk_overlap=cfg.chunk_overlap,
        separators=["\n\n", "\n", "。", "！", "？", ".", "!", "?", "；", ";", "，", ",", " "],
    )
    return splitter.split_text(text)


def split_pages(pages: list[dict], config: ChunkConfig | None = None) -> list[dict]:
    chunks: list[dict] = []
    for page_item in pages:
        page_num = page_item["page"]
        page_text = page_item["text"]
        page_chunks = split_text(page_text, config=config)
        for idx, chunk_text in enumerate(page_chunks):
            chunks.append(
                {
                    "chunk_id": f"p{page_num:04d}-c{idx:03d}",
                    "page": page_num,
                    "text": chunk_text,
                }
            )
    return chunks
