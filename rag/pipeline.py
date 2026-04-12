from __future__ import annotations

import re

from rag.generator import AnswerGenerator
from rag.reranker import Reranker
from rag.retriever import Retriever


class RagPipeline:
    PEDIATRIC_HINTS = (
        "宝宝",
        "婴儿",
        "新生儿",
        "幼儿",
        "儿童",
        "孩子",
        "小孩",
        "喂养",
        "母乳",
        "配方奶",
        "辅食",
        "发烧",
        "咳嗽",
        "腹泻",
        "疫苗",
        "睡眠",
        "湿疹",
        "儿科",
    )
    OUT_OF_SCOPE_HINTS = (
        "天气",
        "气温",
        "下雨",
        "降雨",
        "台风",
        "股价",
        "股票",
        "基金",
        "汇率",
        "新闻",
        "热点",
        "彩票",
        "足球",
        "篮球",
        "电影",
        "八卦",
    )
    MIN_RELEVANCE_SCORE = 0.42

    def __init__(
        self,
        embedding_model: str,
        faiss_index_path: str,
        chunks_path: str,
        llm_model: str,
        reranker_model: str = "BAAI/bge-reranker-base",
        enable_reranker: bool = False,
        lora_adapter_path: str | None = None,
    ) -> None:
        self.retriever = Retriever(
            embedding_model=embedding_model,
            index_path=faiss_index_path,
            chunks_path=chunks_path,
        )
        self.generator = AnswerGenerator(
            model=llm_model,
            adapter_path=lora_adapter_path,
        )
        self.reranker = Reranker(model_name=reranker_model, enabled=enable_reranker)

    @staticmethod
    def _format_references(contexts: list[dict]) -> str:
        if not contexts:
            return ""
        lines = []
        for idx, item in enumerate(contexts, 1):
            lines.append(
                f"- [{idx}] source={item.get('source')} page={item.get('page')} "
                f"chunk_id={item.get('chunk_id')}"
            )
        return "参考片段：\n" + "\n".join(lines)

    def mode_label(self) -> str:
        return self.generator.mode_label()

    @classmethod
    def _normalize_question(cls, question: str) -> str:
        return re.sub(r"\s+", "", question.lower())

    @classmethod
    def _looks_out_of_scope(cls, question: str) -> bool:
        normalized = cls._normalize_question(question)
        has_pediatric_hint = any(token in normalized for token in cls.PEDIATRIC_HINTS)
        has_out_of_scope_hint = any(token in normalized for token in cls.OUT_OF_SCOPE_HINTS)
        return has_out_of_scope_hint and not has_pediatric_hint

    @classmethod
    def _score_context(cls, item: dict) -> float:
        return item.get("dense_score", 0.0) * 0.7 + item.get("keyword_score", 0.0) * 0.3

    @classmethod
    def _has_sufficient_evidence(
        cls,
        question: str,
        contexts: list[dict],
        relevance_threshold: float | None = None,
    ) -> bool:
        if not contexts:
            return False

        if cls._looks_out_of_scope(question):
            return False

        threshold = relevance_threshold if relevance_threshold is not None else cls.MIN_RELEVANCE_SCORE
        best_score = max(cls._score_context(item) for item in contexts)
        return best_score >= threshold

    @staticmethod
    def _reject_answer(question: str) -> str:
        return "这个问题不适合直接用当前儿科知识库回答，或现有资料证据不足。"

    def ask(
        self,
        question: str,
        top_k: int = 3,
        retrieve_k: int | None = None,
        relevance_threshold: float | None = None,
    ) -> dict:
        retrieve_top_k = retrieve_k if retrieve_k is not None else min(10, max(top_k * 3, top_k))
        contexts = self.retriever.search(query=question, top_k=retrieve_top_k)
        final_contexts = self.reranker.rerank(question=question, contexts=contexts, top_k=top_k)
        threshold = relevance_threshold if relevance_threshold is not None else self.MIN_RELEVANCE_SCORE
        scored_contexts = []
        for item in final_contexts:
            enriched = item.copy()
            enriched["relevance_score"] = self._score_context(item)
            scored_contexts.append(enriched)
        best_relevance = max((item["relevance_score"] for item in scored_contexts), default=0.0)
        evidence_passed = self._has_sufficient_evidence(
            question=question,
            contexts=scored_contexts,
            relevance_threshold=threshold,
        )

        if not evidence_passed:
            return {
                "answer": self._reject_answer(question=question),
                "contexts": scored_contexts,
                "generation_mode": self.mode_label(),
                "best_relevance_score": best_relevance,
                "relevance_threshold": threshold,
                "evidence_passed": False,
            }

        base_answer = self.generator.generate(question=question, contexts=scored_contexts)
        refs = self._format_references(scored_contexts)
        answer = f"{base_answer}\n\n{refs}" if refs else base_answer
        return {
            "answer": answer,
            "contexts": scored_contexts,
            "generation_mode": self.mode_label(),
            "best_relevance_score": best_relevance,
            "relevance_threshold": threshold,
            "evidence_passed": True,
        }
