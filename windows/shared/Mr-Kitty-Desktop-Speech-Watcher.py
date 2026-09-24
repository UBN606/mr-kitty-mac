"""Queue new Codex Desktop and Claude Code final replies for one Kitty speaker.

Only new lines after launch are considered. This process never sends prompts or
reads old replies aloud. The controller owns the speaker and deletes each event
after reading it.
"""

from __future__ import annotations

import json
import os
import time
import uuid
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path


HOME = Path.home()
CODEX = HOME / ".codex" / "sessions"
CLAUDE = HOME / ".claude" / "projects"
RUNTIME = Path(__file__).resolve().parent / "runtime"
INBOX = RUNTIME / "speech-inbox"
ENABLED = RUNTIME / "desktop-reply-capture.flag"
STATUS = RUNTIME / "desktop-speech-watcher-status.json"
MAX_READ = 1024 * 1024
MAX_PENDING = 2 * MAX_READ


@dataclass
class Tail:
    path: Path
    source: str
    offset: int
    pending: bytes = b""


def codex_files() -> list[Path]:
    today = date.today()
    paths: list[Path] = []
    for delta in (-1, 0, 1):
        day = today + timedelta(days=delta)
        folder = CODEX / day.strftime("%Y") / day.strftime("%m") / day.strftime("%d")
        paths.extend(folder.glob("rollout-*.jsonl"))
    return paths


def claude_files() -> list[Path]:
    if not CLAUDE.exists():
        return []
    cutoff = time.time() - 2 * 86400
    paths: list[Path] = []
    for folder in CLAUDE.iterdir():
        if not folder.is_dir():
            continue
        for path in folder.glob("*.jsonl"):
            try:
                if path.stat().st_mtime >= cutoff:
                    paths.append(path)
            except OSError:
                pass
    return paths


def codex_is_root_desktop(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            first = json.loads(stream.readline())
        meta = first.get("payload") or {}
        return (
            first.get("type") == "session_meta"
            and not meta.get("parent_thread_id")
            and "desktop" in str(meta.get("originator", "")).lower()
        )
    except (OSError, ValueError, TypeError):
        return False


def final_reply(source: str, line: bytes) -> str:
    try:
        item = json.loads(line)
        if source == "codex":
            payload = item.get("payload") or {}
            if (
                item.get("type") != "response_item"
                or payload.get("type") != "message"
                or payload.get("role") != "assistant"
                or payload.get("phase") != "final_answer"
            ):
                return ""
            blocks = payload.get("content") or []
            return "\n".join(
                str(block.get("text", "")) for block in blocks
                if isinstance(block, dict) and block.get("type") == "output_text"
            ).strip()
        if source == "claude":
            message = item.get("message") or {}
            if (
                item.get("type") != "assistant"
                or item.get("isSidechain")
                or message.get("role") != "assistant"
                or message.get("stop_reason") != "end_turn"
            ):
                return ""
            return "\n".join(
                str(block.get("text", "")) for block in message.get("content", [])
                if isinstance(block, dict) and block.get("type") == "text"
            ).strip()
    except (ValueError, TypeError, UnicodeDecodeError):
        pass
    return ""


def queue_reply(source: str, text: str) -> None:
    if not ENABLED.exists():
        return
    INBOX.mkdir(parents=True, exist_ok=True)
    name = f"{time.time_ns()}-{source}-{uuid.uuid4().hex}.json"
    target = INBOX / name
    temporary = INBOX / f".{name}.tmp"
    temporary.write_text(
        json.dumps({"source": source, "text": text, "at": time.time()}, ensure_ascii=False),
        encoding="utf-8",
    )
    os.replace(temporary, target)


def read_new(tail: Tail) -> None:
    try:
        with tail.path.open("rb") as stream:
            length = stream.seek(0, os.SEEK_END)
            if length < tail.offset:
                tail.offset = length
                tail.pending = b""
            if length == tail.offset:
                return
            stream.seek(tail.offset)
            data = stream.read(min(MAX_READ, length - tail.offset))
        tail.offset += len(data)
        chunks = (tail.pending + data).split(b"\n")
        tail.pending = chunks.pop()
        if len(tail.pending) > MAX_PENDING:
            tail.pending = b""
        for line in chunks:
            answer = final_reply(tail.source, line)
            if answer:
                queue_reply(tail.source, answer)
    except (OSError, ValueError):
        return


def run(parent_pid: int = 0) -> None:
    parent_handle = None
    if parent_pid:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        kernel32.OpenProcess.argtypes = (ctypes.c_uint, ctypes.c_bool, ctypes.c_uint)
        kernel32.OpenProcess.restype = ctypes.c_void_p
        kernel32.WaitForSingleObject.argtypes = (ctypes.c_void_p, ctypes.c_uint)
        kernel32.WaitForSingleObject.restype = ctypes.c_uint
        kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
        parent_handle = kernel32.OpenProcess(0x1000, False, parent_pid)
        if not parent_handle:
            return
    tails: dict[Path, Tail] = {}
    for path in codex_files():
        if codex_is_root_desktop(path):
            tails[path] = Tail(path, "codex", path.stat().st_size)
    for path in claude_files():
        tails[path] = Tail(path, "claude", path.stat().st_size)
    next_discovery = 0.0
    next_status = 0.0
    try:
        while ENABLED.exists():
            if parent_handle and kernel32.WaitForSingleObject(parent_handle, 0) == 0:
                break
            if time.monotonic() >= next_discovery:
                for path in codex_files():
                    if path not in tails and codex_is_root_desktop(path):
                        tails[path] = Tail(path, "codex", 0)
                for path in claude_files():
                    if path not in tails:
                        tails[path] = Tail(path, "claude", 0)
                next_discovery = time.monotonic() + 3.0
            for tail in list(tails.values()):
                read_new(tail)
            if time.monotonic() >= next_status:
                temporary = STATUS.with_suffix(".tmp")
                temporary.write_text(json.dumps({
                    "running": True,
                    "codexFiles": sum(t.source == "codex" for t in tails.values()),
                    "claudeFiles": sum(t.source == "claude" for t in tails.values()),
                    "checkedAt": time.time(),
                }), encoding="utf-8")
                os.replace(temporary, STATUS)
                next_status = time.monotonic() + 10.0
            time.sleep(0.8)
    finally:
        if parent_handle:
            kernel32.CloseHandle(parent_handle)


if __name__ == "__main__":
    import sys
    try:
        run(int(sys.argv[1]) if len(sys.argv) > 1 else 0)
    except Exception as error:
        RUNTIME.mkdir(parents=True, exist_ok=True)
        (RUNTIME / "desktop-speech-watcher-error.txt").write_text(
            f"{type(error).__name__}: {error}", encoding="utf-8"
        )
        raise
