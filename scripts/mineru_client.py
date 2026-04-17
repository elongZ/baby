from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path


def convert_file_to_markdown(path: str | Path) -> str:
    file_path = Path(path).expanduser().resolve()
    output_root = Path(tempfile.mkdtemp(prefix="baby-mineru-"))
    command = _base_command()
    command.extend(
        [
            "-p",
            str(file_path),
            "-o",
            str(output_root),
            "-b",
            os.getenv("MINERU_BACKEND", "pipeline"),
        ]
    )

    extra_args = os.getenv("MINERU_ARGS", "").strip()
    if extra_args:
        command.extend(extra_args.split())

    try:
        subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as exc:  # pragma: no cover - dependency error path
        raise RuntimeError(
            "MinerU is not installed or not on PATH. Install project dependencies again "
            "(for example: pip install -r requirements/base.txt)."
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip()
        stdout = exc.stdout.strip()
        detail = stderr or stdout or "unknown MinerU error"
        raise RuntimeError(f"MinerU conversion failed for {file_path}: {detail}") from exc

    markdown_path = _find_markdown_output(output_root, file_path.stem)
    return markdown_path.read_text(encoding="utf-8").strip()


def _find_markdown_output(output_root: Path, stem: str) -> Path:
    preferred = list(output_root.glob(f"{stem}/**/{stem}.md"))
    if preferred:
        return preferred[0]

    candidates = list(output_root.glob("**/*.md"))
    if not candidates:
        raise RuntimeError(f"MinerU did not produce a markdown file under {output_root}")
    return candidates[0]


def _base_command() -> list[str]:
    raw = os.getenv("MINERU_COMMAND", "").strip()
    if raw:
        return raw.split()
    return [sys.executable, "-m", "mineru.cli.client"]
