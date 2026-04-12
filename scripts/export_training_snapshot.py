from __future__ import annotations

import argparse

from scripts.training_store import DEFAULT_DB_PATH, DEFAULT_SNAPSHOT_PATH, export_snapshot, initialize_database


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export SQLite training samples to JSONL snapshot")
    parser.add_argument("--db-path", default=str(DEFAULT_DB_PATH), help="Path to SQLite database")
    parser.add_argument("--output", default=str(DEFAULT_SNAPSHOT_PATH), help="Path to output JSONL snapshot")
    parser.add_argument("--status", default="done", help="Sample status to export")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    initialize_database(args.db_path)
    output_path, count = export_snapshot(args.db_path, args.output, status=args.status)
    print(f"Wrote annotation snapshot: {output_path}")
    print(f"Samples: {count}")


if __name__ == "__main__":
    main()
