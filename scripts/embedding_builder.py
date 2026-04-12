from __future__ import annotations

from typing import Iterable

import numpy as np
from sentence_transformers import SentenceTransformer


def build_embeddings(chunks: Iterable[str], model_name: str) -> np.ndarray:
    model = SentenceTransformer(model_name)
    vectors = model.encode(list(chunks), normalize_embeddings=True, show_progress_bar=True)
    return np.asarray(vectors, dtype="float32")
