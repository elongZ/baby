from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

from rag.reranker import Reranker
from rag.retriever import Retriever


@dataclass
class EvalSample:
    question: str
    gold_chunk_ids: list[str]
    gold_pages: list[int]
    gold_substrings: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate retrieval quality (Recall@K, MRR)")
    parser.add_argument(
        "--dataset",
        default="data/eval_set.jsonl",
        help="Path to JSONL eval set",
    )
    parser.add_argument("--top-k", type=int, default=3, help="Final top-k results used for metric")
    parser.add_argument(
        "--retrieve-k",
        type=int,
        default=9,
        help="Initial retrieval size before optional reranking",
    )
    parser.add_argument(
        "--use-reranker",
        action="store_true",
        help="Enable reranker in evaluation",
    )
    parser.add_argument(
        "--show-failures",
        action="store_true",
        help="Print failed samples",
    )
    return parser.parse_args()


def _to_int_list(values: list) -> list[int]:
    out: list[int] = []
    for v in values:
        try:
            out.append(int(v))
        except (TypeError, ValueError):
            continue
    return out


def load_eval_set(path: str | Path) -> list[EvalSample]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Eval set not found: {p}")

    samples: list[EvalSample] = []
    for line_no, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        question = str(row.get("question", "")).strip()
        if not question:
            raise ValueError(f"Invalid sample at line {line_no}: missing question")

        sample = EvalSample(
            question=question,
            gold_chunk_ids=[str(x) for x in row.get("gold_chunk_ids", [])],
            gold_pages=_to_int_list(row.get("gold_pages", [])),
            gold_substrings=[str(x) for x in row.get("gold_substrings", []) if str(x).strip()],
        )
        samples.append(sample)
    return samples


def is_hit(sample: EvalSample, context: dict) -> bool:
    chunk_id = str(context.get("chunk_id", ""))
    page = context.get("page")
    text = str(context.get("text", ""))

    if sample.gold_chunk_ids and chunk_id in sample.gold_chunk_ids:
        return True

    if sample.gold_pages:
        try:
            if int(page) in sample.gold_pages:
                return True
        except (TypeError, ValueError):
            pass

    if sample.gold_substrings:
        for sub in sample.gold_substrings:
            if sub in text:
                return True
    return False


def first_hit_rank(sample: EvalSample, contexts: list[dict]) -> int | None:
    for idx, c in enumerate(contexts, 1):
        if is_hit(sample, c):
            return idx
    return None


def main() -> None:
    load_dotenv()
    args = parse_args()

    embedding_model = os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5")
    faiss_index_path = os.getenv("FAISS_INDEX_PATH", "workspace/vector_db/faiss.index")
    chunks_path = os.getenv("CHUNKS_PATH", "workspace/vector_db/chunks.json")
    reranker_model = os.getenv("RERANKER_MODEL", "BAAI/bge-reranker-base")

    retriever = Retriever(
        embedding_model=embedding_model,
        index_path=faiss_index_path,
        chunks_path=chunks_path,
    )
    reranker = Reranker(model_name=reranker_model, enabled=args.use_reranker)
    samples = load_eval_set(args.dataset)
    if not samples:
        raise RuntimeError("Empty eval set.")

    hit_count = 0
    mrr_sum = 0.0

    for i, sample in enumerate(samples, 1):
        candidates = retriever.search(sample.question, top_k=args.retrieve_k)
        ranked = reranker.rerank(sample.question, candidates, top_k=args.top_k)

        rank = first_hit_rank(sample, ranked)
        if rank is not None:
            hit_count += 1
            mrr_sum += 1.0 / rank
        elif args.show_failures:
            print(f"[FAIL #{i}] {sample.question}")
            for j, c in enumerate(ranked, 1):
                print(
                    f"  - rank={j} score={c.get('score', 0):.4f} "
                    f"rerank={c.get('rerank_score', 0):.4f} "
                    f"source={c.get('source')} page={c.get('page')} chunk_id={c.get('chunk_id')}"
                )

    total = len(samples)
    recall = hit_count / total
    mrr = mrr_sum / total

    print("=== Retrieval Evaluation ===")
    print(f"Dataset: {args.dataset}")
    print(f"Samples: {total}")
    print(f"TopK: {args.top_k} | RetrieveK: {args.retrieve_k} | Reranker: {args.use_reranker}")
    print(f"Recall@{args.top_k}: {recall:.4f}")
    print(f"MRR@{args.top_k}: {mrr:.4f}")


if __name__ == "__main__":
    main()
