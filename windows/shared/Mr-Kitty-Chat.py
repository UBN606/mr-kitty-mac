"""Answer from Kitty's separate Codex or Claude CLI conversation.

The WPF controller writes a request file and polls the result file. User text
is passed as process input, never through a shell command. The two providers
keep independent session IDs in one local state file.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def atomic_json(path: Path, value: dict) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    os.replace(temp, path)


def run_codex(message: str, state: dict, project_dir: Path, result_path: Path) -> str:
    codex = shutil.which("codex")
    if not codex:
        raise RuntimeError("Codex CLI was not found on PATH.")
    thread_id = state.get("codex_thread_id") or state.get("thread_id")
    last_message = result_path.with_suffix(".codex-answer.txt")
    last_message.unlink(missing_ok=True)
    if thread_id:
        command = [codex, "exec", "resume", "--json", "--skip-git-repo-check",
                   "-o", str(last_message), thread_id, "-"]
    else:
        command = [codex, "exec", "--json", "--skip-git-repo-check",
                   "--sandbox", "read-only", "-C", str(project_dir),
                   "-o", str(last_message), "-"]
    completed = subprocess.run(command, input=message, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               cwd=project_dir, timeout=300, check=False)
    for line in completed.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "thread.started" and event.get("thread_id"):
            thread_id = event["thread_id"]
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout[-1000:].strip()
        raise RuntimeError(detail or f"Codex exited with code {completed.returncode}.")
    if not last_message.exists():
        raise RuntimeError("Codex did not return a message.")
    answer = last_message.read_text(encoding="utf-8").strip()
    if not answer:
        raise RuntimeError("Codex returned an empty message.")
    if thread_id:
        state["codex_thread_id"] = thread_id
        state.pop("thread_id", None)
    return answer


def run_claude(message: str, state: dict, project_dir: Path) -> str:
    claude = os.environ.get("MR_KITTY_CLAUDE_CLI") or shutil.which("claude")
    if not claude:
        raise RuntimeError("Claude Code CLI was not found on PATH. Install and sign in to it for Kitty's Claude chat.")
    command = [claude, "-p", "Reply to the user's message provided on stdin.",
               "--output-format", "json", "--tools", "",
               "--disallowedTools", "mcp__*", "--setting-sources", "user"]
    session_id = state.get("claude_session_id")
    if session_id:
        command += ["--resume", session_id]
    completed = subprocess.run(command, input=message, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               cwd=project_dir, timeout=300, check=False)
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        payload = {}
    if completed.returncode or payload.get("is_error"):
        detail = payload.get("result") or completed.stderr.strip() or completed.stdout[-1000:].strip()
        raise RuntimeError(str(detail) or f"Claude exited with code {completed.returncode}.")
    answer = str(payload.get("result", "")).strip()
    if not answer:
        raise RuntimeError("Claude did not return a message.")
    if payload.get("session_id"):
        state["claude_session_id"] = str(payload["session_id"])
    return answer


def main() -> int:
    request_path, result_path, state_path = map(Path, sys.argv[1:4])
    try:
        request = json.loads(request_path.read_text(encoding="utf-8"))
        message = str(request["message"]).strip()
        if not message:
            raise ValueError("Write or speak a message first.")
        provider = str(request.get("provider", "codex")).lower()
        if provider not in ("codex", "claude"):
            raise ValueError("Choose Codex or Claude first.")
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        project_dir = Path(__file__).resolve().parent.parent
        if provider == "codex":
            answer = run_codex(message, state, project_dir, result_path)
        else:
            answer = run_claude(message, state, project_dir)
        atomic_json(state_path, state)
        atomic_json(result_path, {"ok": True, "provider": provider, "answer": answer})
        return 0
    except Exception as error:
        atomic_json(result_path, {"ok": False, "error": str(error)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
