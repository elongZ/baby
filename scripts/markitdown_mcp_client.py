from __future__ import annotations

import os
import sys
from pathlib import Path


def convert_file_to_markdown(path: str | Path) -> str:
    try:
        import anyio
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
    except ImportError as exc:  # pragma: no cover - dependency error path
        raise RuntimeError(
            "markitdown MCP dependencies are missing. Install project dependencies again "
            "(for example: pip install -r requirements/base.txt)."
        ) from exc

    file_path = Path(path).expanduser().resolve()

    async def _convert() -> str:
        server = StdioServerParameters(
            command=os.getenv("MARKITDOWN_MCP_COMMAND", sys.executable),
            args=_server_args(),
        )

        async with stdio_client(server) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool(
                    "convert_to_markdown",
                    {"uri": file_path.as_uri()},
                )

        if result.isError:
            raise RuntimeError(f"markitdown MCP conversion failed for {file_path}")

        text_parts = [item.text for item in result.content if hasattr(item, "text") and item.text]
        if not text_parts:
            return ""
        return "\n".join(text_parts).strip()

    return anyio.run(_convert)


def _server_args() -> list[str]:
    extra = os.getenv("MARKITDOWN_MCP_ARGS", "").strip()
    if extra:
        return extra.split()
    return ["-m", "markitdown_mcp"]
