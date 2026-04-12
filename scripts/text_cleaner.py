from __future__ import annotations

import re


def clean_text(raw_text: str) -> str:
    text = raw_text
    text = re.sub(r"\r\n?", "\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"(?im)^page\s+\d+\s*$", "", text)
    text = text.strip()
    return text
