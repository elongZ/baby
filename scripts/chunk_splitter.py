"""文本切块工具。

本模块负责把清洗后的页面文本按统一规则切分成适合向量索引和检索的 chunk，
并保留页码与 chunk 编号等基础元数据。
"""

from __future__ import annotations

from dataclasses import dataclass

from langchain_text_splitters import RecursiveCharacterTextSplitter

SPLITTER_VERSION = "2026-04-13-a"


@dataclass
class ChunkConfig:
    """控制 chunk 大小与重叠范围的配置。"""

    chunk_size: int = 500
    chunk_overlap: int = 100


def split_text(text: str, config: ChunkConfig | None = None) -> list[str]:
    """按当前切块策略拆分纯文本。"""

    cfg = config or ChunkConfig()
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=cfg.chunk_size,
        chunk_overlap=cfg.chunk_overlap,
        separators=["\n\n", "\n", "。", "！", "？", ".", "!", "?", "；", ";", "，", ",", " "],
    )
    return splitter.split_text(text)


def split_pages(pages: list[dict], config: ChunkConfig | None = None) -> list[dict]:
    """按页切块，并生成带页码和 chunk_id 的结果。"""

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
