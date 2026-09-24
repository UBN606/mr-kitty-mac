"""Mirror Codex Desktop task lifecycle into the one running CoPet cat.

Codex Desktop can skip hooks on some builds, so this reads newly appended
root-task messages from Codex's own local JSONL session files. It never
opens a chat window or sends prompts to a model.
"""

from __future__ import annotations

import ctypes
import json
import os
import re
import time
import urllib.request
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path


HOME = Path.home()
SESSIONS = HOME / ".codex" / "sessions"
RUNTIME = HOME / ".copet" / "runtime"
STATUS = Path(__file__).resolve().parent / "runtime" / "codex-watcher-status.json"
MAX_READ = 1024 * 1024
POLL_SECONDS = 0.8


@dataclass
class Session:
    path: Path
    offset: int
    pending: bytes
    session_id: str
    last_user: str = ""
    last_commentary_at: float = 0.0


def session_meta(path: Path) -> dict | None:
    try:
        with path.open("rb") as stream:
            first = json.loads(stream.readline())
        payload = first.get("payload", {})
        if first.get("type") != "session_meta" or payload.get("parent_thread_id"):
            return None
        if "desktop" not in str(payload.get("originator", "")).lower():
            return None
        return payload
    except (OSError, ValueError, UnicodeDecodeError):
        return None


def recent_files() -> list[Path]:
    today = date.today()
    paths = []
    for delta in (-1, 0, 1):
        day = today + timedelta(days=delta)
        folder = SESSIONS / day.strftime("%Y") / day.strftime("%m") / day.strftime("%d")
        try:
            paths.extend(folder.glob("rollout-*.jsonl"))
        except OSError:
            pass
    return paths


def summarize_prompt(payload: dict) -> str:
    parts = [
        block.get("text", "")
        for block in payload.get("content", [])
        if isinstance(block, dict) and block.get("type") == "input_text"
    ]
    raw = " ".join(parts)
    if "## My request:" in raw:
        raw = raw.rsplit("## My request:", 1)[-1]
    raw = re.sub(r"<in-app-browser-context.*?</in-app-browser-context>", "", raw, flags=re.S)
    raw = re.sub(r"\s+", " ", raw).strip()
    return raw[:56]


def summarize_assistant(payload: dict) -> str:
    raw = " ".join(
        block.get("text", "")
        for block in payload.get("content", [])
        if isinstance(block, dict) and block.get("type") == "output_text"
    )
    raw = re.sub(r"[`*_#]", "", raw)
    return re.sub(r"\s+", " ", raw).strip()[:56]


def send_event(kind: str, session_id: str, subject: str = "") -> bool:
    try:
        endpoint = (RUNTIME / "event-endpoint").read_text(encoding="utf-8").strip()
        token = (RUNTIME / "event-token").read_text(encoding="utf-8").strip()
        if not endpoint.startswith("http://127.0.0.1:") or not endpoint.endswith("/v1/events"):
            return False
        payload: dict = {"agent": "codex", "kind": kind, "sessionId": session_id}
        if subject:
            payload["toolInput"] = {"subject": subject}
        request = urllib.request.Request(
            endpoint,
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=0.8) as response:
            return response.status == 202
    except (OSError, ValueError, TimeoutError):
        return False


def process_line(session: Session, line: bytes) -> bool:
    try:
        item = json.loads(line)
        payload = item.get("payload", {})
        if item.get("type") != "response_item" or payload.get("type") != "message":
            return False
        role = payload.get("role")
        if role == "user":
            summary = summarize_prompt(payload)
            if not summary or summary == session.last_user:
                return False
            session.last_user = summary
            return send_event("user.prompt", session.session_id, summary)
        if role == "assistant" and payload.get("phase") == "commentary":
            now = time.monotonic()
            if now - session.last_commentary_at < 8:
                return False
            summary = summarize_assistant(payload)
            if summary:
                session.last_commentary_at = now
                return send_event("thinking", session.session_id, summary)
        if role == "assistant" and payload.get("phase") == "final_answer":
            return send_event("session.stop", session.session_id)
    except (ValueError, TypeError, UnicodeDecodeError):
        pass
    return False


def read_new(session: Session) -> int:
    try:
        with session.path.open("rb") as stream:
            length = stream.seek(0, os.SEEK_END)
            if length < session.offset:
                session.offset = 0
                session.pending = b""
            if length == session.offset:
                return 0
            stream.seek(session.offset)
            data = stream.read(min(MAX_READ, length - session.offset))
        session.offset += len(data)
        chunks = (session.pending + data).split(b"\n")
        session.pending = chunks.pop()
        if len(session.pending) > MAX_READ:
            session.pending = b""
        return sum(process_line(session, chunk) for chunk in chunks if chunk)
    except OSError:
        return 0


def write_status(watched: int, forwarded: int) -> None:
    STATUS.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATUS.with_suffix(".tmp")
    temporary.write_text(
        json.dumps({"running": True, "watchedRootTasks": watched,
                    "forwardedEvents": forwarded, "checkedAt": time.time()}),
        encoding="utf-8",
    )
    temporary.replace(STATUS)


def run() -> None:
    kernel32 = ctypes.windll.kernel32
    kernel32.CreateMutexW.argtypes = (ctypes.c_void_p, ctypes.c_bool, ctypes.c_wchar_p)
    kernel32.CreateMutexW.restype = ctypes.c_void_p
    kernel32.ReleaseMutex.argtypes = (ctypes.c_void_p,)
    kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
    mutex = kernel32.CreateMutexW(None, True, "Local\\MrKittyCodexWatcher")
    if kernel32.GetLastError() == 183:
        return
    sessions: dict[Path, Session] = {}
    forwarded = 0
    last_status = 0.0
    try:
        # Existing history is not replayed onto the desktop when Kitty starts.
        for path in recent_files():
            meta = session_meta(path)
            if meta:
                sessions[path] = Session(path, path.stat().st_size, b"", str(meta.get("session_id", path.stem)))
        while True:
            for path in recent_files():
                if path not in sessions:
                    meta = session_meta(path)
                    if meta:
                        sessions[path] = Session(path, 0, b"", str(meta.get("session_id", path.stem)))
                session = sessions.get(path)
                if session:
                    forwarded += read_new(session)
            if time.monotonic() - last_status > 10:
                write_status(len(sessions), forwarded)
                last_status = time.monotonic()
            time.sleep(POLL_SECONDS)
    finally:
        kernel32.ReleaseMutex(mutex)
        kernel32.CloseHandle(mutex)


if __name__ == "__main__":
    run()
