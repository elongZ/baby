from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_DB_PATH = Path("data/training_data.sqlite3")
DEFAULT_SNAPSHOT_PATH = Path("data/sft_annotations.done.jsonl")

SUPPORTED_MODES = {"grounded_answer", "insufficient_evidence", "risk_routing"}
SUPPORTED_STATUSES = {"draft", "done", "archived"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(slots=True)
class TrainingSample:
    sample_id: str
    question: str
    mode: str
    annotation_guideline: str
    contexts: list[dict[str, Any]]
    answer: str
    annotation_notes: str
    status: str
    source_type: str
    created_at: str
    updated_at: str
    deleted_at: str | None = None
    version: int = 1

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "TrainingSample":
        return cls(
            sample_id=row["sample_id"],
            question=row["question"],
            mode=row["mode"],
            annotation_guideline=row["annotation_guideline"],
            contexts=json.loads(row["contexts_json"] or "[]"),
            answer=row["answer"],
            annotation_notes=row["annotation_notes"],
            status=row["status"],
            source_type=row["source_type"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            deleted_at=row["deleted_at"],
            version=row["version"],
        )

    def validate(self) -> None:
        if not self.sample_id.strip():
            raise ValueError("sample_id is required")
        if not self.question.strip():
            raise ValueError(f"{self.sample_id}: question is required")
        if self.mode not in SUPPORTED_MODES:
            raise ValueError(f"{self.sample_id}: unsupported mode {self.mode}")
        if self.status not in SUPPORTED_STATUSES:
            raise ValueError(f"{self.sample_id}: unsupported status {self.status}")
        if not isinstance(self.contexts, list) or not self.contexts:
            raise ValueError(f"{self.sample_id}: contexts are required")
        if not self.answer.strip():
            raise ValueError(f"{self.sample_id}: answer is required")

    def to_snapshot_row(self) -> dict[str, Any]:
        return {
            "sample_id": self.sample_id,
            "question": self.question,
            "mode": self.mode,
            "annotation_guideline": self.annotation_guideline,
            "contexts": self.contexts,
            "answer": self.answer,
            "annotation_notes": self.annotation_notes,
        }


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS training_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sample_id TEXT NOT NULL UNIQUE,
    question TEXT NOT NULL,
    mode TEXT NOT NULL,
    annotation_guideline TEXT NOT NULL DEFAULT '',
    contexts_json TEXT NOT NULL DEFAULT '[]',
    answer TEXT NOT NULL DEFAULT '',
    annotation_notes TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'draft',
    source_type TEXT NOT NULL DEFAULT 'manual',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    version INTEGER NOT NULL DEFAULT 1,
    CHECK (mode IN ('grounded_answer', 'insufficient_evidence', 'risk_routing')),
    CHECK (status IN ('draft', 'done', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_training_samples_active
ON training_samples(deleted_at, status, updated_at);
"""


def connect(db_path: str | Path) -> sqlite3.Connection:
    path = Path(db_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def initialize_database(
    db_path: str | Path = DEFAULT_DB_PATH,
    snapshot_path: str | Path = DEFAULT_SNAPSHOT_PATH,
) -> Path:
    db_path = Path(db_path)
    snapshot_path = Path(snapshot_path)
    with connect(db_path) as conn:
        conn.executescript(SCHEMA_SQL)
        count = conn.execute("SELECT COUNT(*) AS count FROM training_samples").fetchone()["count"]
        if count == 0 and snapshot_path.exists():
            _import_snapshot_into_db(conn, snapshot_path)
            conn.commit()
    return db_path


def _import_snapshot_into_db(conn: sqlite3.Connection, snapshot_path: Path) -> None:
    timestamp = utc_now()
    for line in snapshot_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        sample = TrainingSample(
            sample_id=str(row.get("sample_id", "")).strip(),
            question=str(row.get("question", "")).strip(),
            mode=str(row.get("mode", "grounded_answer")).strip() or "grounded_answer",
            annotation_guideline=str(row.get("annotation_guideline", "")).strip(),
            contexts=list(row.get("contexts", [])),
            answer=str(row.get("answer", "")).strip(),
            annotation_notes=str(row.get("annotation_notes", "")).strip(),
            status="done" if str(row.get("answer", "")).strip() else "draft",
            source_type="snapshot_import",
            created_at=timestamp,
            updated_at=timestamp,
        )
        conn.execute(
            """
            INSERT OR IGNORE INTO training_samples (
                sample_id, question, mode, annotation_guideline, contexts_json, answer,
                annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 1)
            """,
            (
                sample.sample_id,
                sample.question,
                sample.mode,
                sample.annotation_guideline,
                json.dumps(sample.contexts, ensure_ascii=False),
                sample.answer,
                sample.annotation_notes,
                sample.status,
                sample.source_type,
                sample.created_at,
                sample.updated_at,
            ),
        )


def fetch_samples(
    db_path: str | Path = DEFAULT_DB_PATH,
    *,
    status: str | None = None,
    include_archived: bool = False,
) -> list[TrainingSample]:
    initialize_database(db_path)
    where = ["deleted_at IS NULL"]
    params: list[Any] = []
    if status:
        where.append("status = ?")
        params.append(status)
    elif not include_archived:
        where.append("status != 'archived'")

    sql = f"""
        SELECT sample_id, question, mode, annotation_guideline, contexts_json, answer,
               annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
        FROM training_samples
        WHERE {' AND '.join(where)}
        ORDER BY CAST(SUBSTR(sample_id, 5) AS INTEGER) DESC, updated_at DESC
    """
    with connect(db_path) as conn:
        rows = conn.execute(sql, params).fetchall()
    return [TrainingSample.from_row(row) for row in rows]


def get_sample(db_path: str | Path, sample_id: str) -> TrainingSample:
    initialize_database(db_path)
    with connect(db_path) as conn:
        row = conn.execute(
            """
            SELECT sample_id, question, mode, annotation_guideline, contexts_json, answer,
                   annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
            FROM training_samples
            WHERE sample_id = ? AND deleted_at IS NULL
            """,
            (sample_id,),
        ).fetchone()
    if row is None:
        raise KeyError(f"Sample not found: {sample_id}")
    return TrainingSample.from_row(row)


def update_sample_contexts(
    db_path: str | Path,
    sample_id: str,
    contexts: list[dict[str, Any]],
) -> TrainingSample:
    initialize_database(db_path)
    updated_at = utc_now()
    with connect(db_path) as conn:
        conn.execute(
            """
            UPDATE training_samples
            SET contexts_json = ?, updated_at = ?, version = version + 1
            WHERE sample_id = ? AND deleted_at IS NULL
            """,
            (json.dumps(contexts, ensure_ascii=False), updated_at, sample_id),
        )
        conn.commit()
    return get_sample(db_path, sample_id)


def export_snapshot(
    db_path: str | Path = DEFAULT_DB_PATH,
    output_path: str | Path = DEFAULT_SNAPSHOT_PATH,
    *,
    status: str = "done",
) -> tuple[Path, int]:
    samples = fetch_samples(db_path, status=status, include_archived=False)
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(sample.to_snapshot_row(), ensure_ascii=False) for sample in samples]
    output_path.write_text(("\n".join(lines) + "\n") if lines else "", encoding="utf-8")
    return output_path, len(samples)
