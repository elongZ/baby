from __future__ import annotations

from sentence_transformers import CrossEncoder


class Reranker:
    def __init__(self, model_name: str, enabled: bool = False) -> None:
        self.enabled = enabled
        self.model_name = model_name
        self.model: CrossEncoder | None = None
        if enabled and model_name:
            try:
                self.model = CrossEncoder(model_name)
            except Exception:
                self.enabled = False
                self.model = None

    def rerank(self, question: str, contexts: list[dict], top_k: int) -> list[dict]:
        if not contexts:
            return []
        if not self.enabled or self.model is None or len(contexts) <= 1:
            return contexts[:top_k]

        pairs = [(question, item.get("text", "")) for item in contexts]
        scores = self.model.predict(pairs)

        for idx, score in enumerate(scores):
            contexts[idx]["rerank_score"] = float(score)

        sorted_contexts = sorted(
            contexts,
            key=lambda x: x.get("rerank_score", x.get("score", 0.0)),
            reverse=True,
        )
        return sorted_contexts[:top_k]
