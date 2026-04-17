from __future__ import annotations

import argparse
import json
from pathlib import Path

from scripts.training_store import DEFAULT_DB_PATH, fetch_samples, initialize_database


SYSTEM_PROMPT = (
    "You are a pediatric knowledge assistant. "
    "Answer strictly based on the provided contexts. "
    "If the evidence is insufficient, say so clearly and do not guess."
)


MODE_INSTRUCTIONS = {
    "grounded_answer": (
        "Task mode: grounded_answer.\n"
        "Give a direct answer based only on the provided contexts."
    ),
    "insufficient_evidence": (
        "Task mode: insufficient_evidence.\n"
        "If the provided contexts do not fully support a direct answer, clearly say the evidence is insufficient. "
        "Do not infer unsupported facts."
    ),
    "risk_routing": (
        "Task mode: risk_routing.\n"
        "Answer conservatively and include a clear risk-routing note when symptoms or self-medication may be unsafe."
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert annotated samples into SFT JSONL")
    parser.add_argument(
        "--input",
        default=None,
        help="Deprecated JSONL input path",
    )
    parser.add_argument(
        "--input-sqlite",
        default=str(DEFAULT_DB_PATH),
        help="Path to SQLite annotation database",
    )
    parser.add_argument(
        "--status",
        default="done",
        help="Sample status to export when reading from SQLite",
    )
    parser.add_argument(
        "--output",
        default="data/sft_train.jsonl",
        help="Path to SFT output JSONL",
    )
    parser.add_argument(
        "--format",
        choices=["plain", "messages"],
        default="messages",
        help="Output format for downstream training",
    )
    return parser.parse_args()


def build_user_prompt(question: str, contexts: list[dict], mode: str) -> str:
    context_block = "\n\n".join(
        (
            f"{item.get('ref', '')} "
            f"(source={item.get('source')}, page={item.get('page')}, chunk_id={item.get('chunk_id')})\n"
            f"{item.get('text', '')}"
        )
        for item in contexts
    )
    mode_instruction = MODE_INSTRUCTIONS.get(mode, MODE_INSTRUCTIONS["grounded_answer"])
    return (
        "Please answer the pediatric question only using the provided contexts.\n\n"
        f"{mode_instruction}\n\n"
        f"Question:\n{question}\n\n"
        f"Contexts:\n{context_block}\n\n"
        "Write a concise answer grounded in the provided contexts. "
        "If the evidence is insufficient, say so clearly and do not guess."
    )


def validate_row(row: dict, line_no: int) -> None:
    if not str(row.get("question", "")).strip():
        raise ValueError(f"Line {line_no}: missing question")
    if not isinstance(row.get("contexts"), list) or not row["contexts"]:
        raise ValueError(f"Line {line_no}: missing contexts")
    if not str(row.get("answer", "")).strip():
        raise ValueError(f"Line {line_no}: missing answer")


def load_rows_from_jsonl(input_path: Path) -> list[dict]:
    if not input_path.exists():
        raise FileNotFoundError(f"Annotation file not found: {input_path}")

    rows: list[dict] = []
    for line_no, line in enumerate(input_path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        validate_row(row, line_no)
        rows.append(row)
    return rows


def load_rows_from_sqlite(db_path: Path, status: str) -> list[dict]:
    initialize_database(db_path)
    rows: list[dict] = []
    for sample in fetch_samples(db_path, status=status, include_archived=False):
        sample.validate()
        rows.append(
            {
                "sample_id": sample.sample_id,
                "question": sample.question,
                "mode": sample.mode,
                "annotation_guideline": sample.annotation_guideline,
                "contexts": sample.contexts,
                "answer": sample.answer,
                "annotation_notes": sample.annotation_notes,
            }
        )
    return rows


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if args.input:
        rows = load_rows_from_jsonl(Path(args.input))
    else:
        rows = load_rows_from_sqlite(Path(args.input_sqlite), args.status)

    out_lines: list[str] = []
    for row in rows:
        mode = str(row.get("mode", "grounded_answer")).strip() or "grounded_answer"
        user_prompt = build_user_prompt(str(row["question"]), row["contexts"], mode)
        answer = str(row["answer"]).strip()

        if args.format == "plain":
            out_row = {
                "question": row["question"],
                "mode": mode,
                "contexts": row["contexts"],
                "answer": answer,
                "prompt": user_prompt,
            }
        else:
            out_row = {
                "mode": mode,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                    {"role": "assistant", "content": answer},
                ]
            }

        out_lines.append(json.dumps(out_row, ensure_ascii=False))

    output_path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    print(f"Wrote SFT dataset: {output_path}")
    print(f"Samples: {len(out_lines)}")


if __name__ == "__main__":
    main()
