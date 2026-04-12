from __future__ import annotations

import argparse
import os

from dotenv import load_dotenv

from rag.retriever import Retriever
from scripts.training_store import DEFAULT_DB_PATH, get_sample, initialize_database, update_sample_contexts


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh retrieved contexts for a training sample")
    parser.add_argument("--db-path", default=str(DEFAULT_DB_PATH), help="Path to SQLite database")
    parser.add_argument("--sample-id", required=True, help="Training sample id")
    parser.add_argument("--top-k", type=int, default=3, help="Number of contexts to retrieve")
    return parser.parse_args()


def main() -> None:
    load_dotenv()
    args = parse_args()
    initialize_database(args.db_path)
    sample = get_sample(args.db_path, args.sample_id)

    retriever = Retriever(
        embedding_model=os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5"),
        index_path=os.getenv("FAISS_INDEX_PATH", "vector_db/faiss.index"),
        chunks_path=os.getenv("CHUNKS_PATH", "vector_db/chunks.json"),
    )

    contexts = retriever.search(sample.question, top_k=args.top_k)
    saved = update_sample_contexts(
        args.db_path,
        sample.sample_id,
        [
            {
                "ref": f"[{index}]",
                "chunk_id": item.get("chunk_id"),
                "source": item.get("source"),
                "page": item.get("page"),
                "text": item.get("text"),
            }
            for index, item in enumerate(contexts, 1)
        ],
    )

    print(f"Refreshed contexts for {saved.sample_id}")
    print(f"Contexts: {len(saved.contexts)}")


if __name__ == "__main__":
    main()
