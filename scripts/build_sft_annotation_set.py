from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from dotenv import load_dotenv

from rag.retriever import Retriever


MODE_GUIDELINES = {
    "grounded_answer": (
        "Provide a grounded answer based only on the retrieved contexts. "
        "Give a direct conclusion, summarize supporting evidence, and cite the supporting references."
    ),
    "insufficient_evidence": (
        "Do not guess. State clearly that the available evidence is insufficient. "
        "Explain what is missing and keep the answer conservative."
    ),
    "risk_routing": (
        "Answer conservatively based on the contexts and include a safety routing note. "
        "Do not provide aggressive self-medication advice. Recommend timely medical care when risk is high."
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a manual annotation set for SFT")
    parser.add_argument(
        "--questions",
        default="data/sft_questions.example.jsonl",
        help="Path to input question seed JSONL",
    )
    parser.add_argument(
        "--output",
        default="data/sft_annotations.todo.jsonl",
        help="Path to output annotation JSONL",
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=3,
        help="Number of retrieved contexts per question",
    )
    return parser.parse_args()


def load_questions(path: str | Path) -> list[dict]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Question file not found: {p}")

    rows: list[dict] = []
    for line_no, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        question = str(row.get("question", "")).strip()
        if not question:
            raise ValueError(f"Invalid row at line {line_no}: missing question")
        rows.append(
            {
                "question": question,
                "mode": str(row.get("mode", "grounded_answer")).strip() or "grounded_answer",
            }
        )
    return rows


def main() -> None:
    load_dotenv()
    args = parse_args()

    retriever = Retriever(
        embedding_model=os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5"),
        index_path=os.getenv("FAISS_INDEX_PATH", "workspace/vector_db/faiss.index"),
        chunks_path=os.getenv("CHUNKS_PATH", "workspace/vector_db/chunks.json"),
    )
    questions = load_questions(args.questions)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    for idx, item in enumerate(questions, 1):
        contexts = retriever.search(item["question"], top_k=args.top_k)
        row = {
            "sample_id": f"sft-{idx:04d}",
            "question": item["question"],
            "mode": item["mode"],
            "annotation_guideline": MODE_GUIDELINES.get(
                item["mode"],
                MODE_GUIDELINES["grounded_answer"],
            ),
            "contexts": [
                {
                    "ref": f"[{i}]",
                    "chunk_id": c.get("chunk_id"),
                    "source": c.get("source"),
                    "page": c.get("page"),
                    "text": c.get("text"),
                }
                for i, c in enumerate(contexts, 1)
            ],
            "answer": "",
            "annotation_notes": "",
        }
        lines.append(json.dumps(row, ensure_ascii=False))

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote annotation set: {out_path}")
    print(f"Samples: {len(lines)}")


if __name__ == "__main__":
    main()
