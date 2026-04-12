from __future__ import annotations

import json
import re
from pathlib import Path

import faiss
import numpy as np
from sentence_transformers import SentenceTransformer


class Retriever:
    def __init__(
        self,
        embedding_model: str,
        index_path: str,
        chunks_path: str,
    ) -> None:
        self.model = SentenceTransformer(embedding_model)
        self.index = faiss.read_index(index_path)
        self.chunks = json.loads(Path(chunks_path).read_text(encoding="utf-8"))
        self._chunk_terms = [self._extract_terms(item.get("text", "")) for item in self.chunks]

    @staticmethod
    def _extract_terms(text: str) -> set[str]:
        lowered = text.lower()
        tokens = set(re.findall(r"[a-z0-9]+", lowered))

        compact = re.sub(r"\s+", "", lowered)
        if len(compact) >= 2:
            tokens.update(compact[idx : idx + 2] for idx in range(len(compact) - 1))
        else:
            tokens.update(compact)

        return {token for token in tokens if token.strip()}

    def _dense_search(self, query: str, top_k: int) -> list[dict]:
        query_vector = self.model.encode([query], normalize_embeddings=True)
        query_vector = np.asarray(query_vector, dtype="float32")

        scores, indices = self.index.search(query_vector, top_k)
        results: list[dict] = []
        for rank, idx in enumerate(indices[0]):
            if 0 <= idx < len(self.chunks):
                item = self.chunks[idx]
                results.append(
                    {
                        "chunk_id": item.get("chunk_id", f"chunk-{idx}"),
                        "source": item.get("source", "unknown"),
                        "page": item.get("page", -1),
                        "text": item.get("text", ""),
                        "score": float(scores[0][rank]),
                        "dense_score": float(scores[0][rank]),
                        "retrieval_method": "dense",
                    }
                )
        return results

    def _keyword_search(self, query: str, top_k: int) -> list[dict]:
        query_terms = self._extract_terms(query)
        if not query_terms:
            return []

        scored_indices: list[tuple[float, int]] = []
        for idx, chunk_terms in enumerate(self._chunk_terms):
            overlap = query_terms & chunk_terms
            if not overlap:
                continue
            score = len(overlap) / len(query_terms)
            scored_indices.append((score, idx))

        scored_indices.sort(key=lambda item: item[0], reverse=True)

        results: list[dict] = []
        for score, idx in scored_indices[:top_k]:
            item = self.chunks[idx]
            results.append(
                {
                    "chunk_id": item.get("chunk_id", f"chunk-{idx}"),
                    "source": item.get("source", "unknown"),
                    "page": item.get("page", -1),
                    "text": item.get("text", ""),
                    "keyword_score": float(score),
                    "retrieval_method": "keyword",
                }
            )
        return results

    def search(self, query: str, top_k: int = 3) -> list[dict]:
        dense_results = self._dense_search(query=query, top_k=top_k)
        keyword_results = self._keyword_search(query=query, top_k=top_k)

        merged: dict[str, dict] = {}
        for item in dense_results + keyword_results:
            chunk_id = item["chunk_id"]
            existing = merged.get(chunk_id)
            if existing is None:
                merged[chunk_id] = item.copy()
                continue

            existing["retrieval_method"] = "hybrid"
            existing["score"] = max(existing.get("score", 0.0), item.get("score", 0.0))
            if "dense_score" in item:
                existing["dense_score"] = item["dense_score"]
            if "keyword_score" in item:
                existing["keyword_score"] = item["keyword_score"]

        ranked = sorted(
            merged.values(),
            key=lambda item: (
                item.get("dense_score", 0.0) * 0.7 + item.get("keyword_score", 0.0) * 0.3
            ),
            reverse=True,
        )
        return ranked[:top_k]
