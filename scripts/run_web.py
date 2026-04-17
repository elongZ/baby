from __future__ import annotations

import os
import shutil
import socket
import subprocess
import sys
from pathlib import Path

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
        if (candidate / "rag" / "api").exists() and (candidate / "rag" / "web").exists() and (candidate / "requirements" / "base.txt").exists():
            return candidate

    raise RuntimeError(
        "Unable to locate project root. Set BABY_APP_PROJECT_ROOT to the repository path."
    )


def _is_port_open(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.5)
        return sock.connect_ex((host, port)) == 0


def main() -> None:
    project_root = discover_project_root()
    os.chdir(project_root)
    load_dotenv(project_root / ".env")

    host = os.getenv("BABY_APP_API_HOST", "127.0.0.1")
    port = int(os.getenv("BABY_APP_API_PORT", "8765"))
    api_base = os.getenv("API_BASE", f"http://{host}:{port}")

    if not _is_port_open(host, port):
        print(
            f"Local API is not running at {api_base}. "
            "Start it first with `python -m scripts.run_local_api`, or open the SwiftUI app.",
            file=sys.stderr,
        )
        raise SystemExit(1)

    env = os.environ.copy()
    env["BABY_APP_PROJECT_ROOT"] = str(project_root)
    env["BABY_APP_API_HOST"] = host
    env["BABY_APP_API_PORT"] = str(port)
    env["API_BASE"] = api_base

    streamlit_launcher = shutil.which("streamlit")
    try:
        import streamlit  # type: ignore  # noqa: F401
    except ImportError:
        if streamlit_launcher is None:
            print(
                "Streamlit is not installed in the current Python environment, and no `streamlit` executable was found in PATH.",
                file=sys.stderr,
            )
            print("Install it with `pip install -r requirements/base.txt`.", file=sys.stderr)
            raise SystemExit(1)
        cmd = [streamlit_launcher, "run", "rag/web/app.py"]
    else:
        cmd = [sys.executable, "-m", "streamlit", "run", "rag/web/app.py"]

    try:
        subprocess.run(cmd, cwd=project_root, env=env, check=True)
    except KeyboardInterrupt:
        raise SystemExit(130)


if __name__ == "__main__":
    main()
