from __future__ import annotations

import os
from pathlib import Path

import uvicorn
from dotenv import load_dotenv


def _candidate_roots() -> list[Path]:
    script_dir = Path(__file__).resolve().parent
    cwd = Path.cwd().resolve()
    candidates: list[Path] = [cwd, *cwd.parents, script_dir.parent, *script_dir.parent.parents]

    seen: set[Path] = set()
    ordered: list[Path] = []
    for item in candidates:
        if item not in seen:
            seen.add(item)
            ordered.append(item)
    return ordered


def discover_project_root() -> Path:
    explicit_root = os.getenv("BABY_APP_PROJECT_ROOT")
    if explicit_root:
        path = Path(explicit_root).expanduser().resolve()
        if path.exists():
            return path

    for candidate in _candidate_roots():
        if (candidate / "api").exists() and (candidate / "rag").exists() and (candidate / "requirements.txt").exists():
            return candidate

    raise RuntimeError(
        "Unable to locate project root. Set BABY_APP_PROJECT_ROOT to the repository path."
    )


def main() -> None:
    project_root = discover_project_root()
    os.chdir(project_root)
    load_dotenv(project_root / ".env")

    host = os.getenv("BABY_APP_API_HOST", "127.0.0.1")
    port = int(os.getenv("BABY_APP_API_PORT", "8765"))
    log_level = os.getenv("BABY_APP_API_LOG_LEVEL", "warning")

    uvicorn.run(
        "api.main:app",
        host=host,
        port=port,
        reload=False,
        log_level=log_level,
    )


if __name__ == "__main__":
    main()
