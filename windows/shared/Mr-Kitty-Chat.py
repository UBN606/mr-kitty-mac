"""Run one Kitty Codex message without opening the Codex desktop window.

The WPF pet controller creates a request file and polls the result file. Each
message resumes Kitty's own Codex CLI thread; it never uses the active desktop
task. No shell is used to run the user's text.
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


def main() -> int:
    request_path, result_path, state_path = map(Path, sys.argv[1:4])
    try:
        request = json.loads(request_path.read_text(encoding="utf-8"))
        message = str(request["message"]).strip()
        if not message:
            raise ValueError("Write or speak a message first.")
        codex = shutil.which("codex")
        if not codex:
            raise RuntimeError("Codex CLI was not found on PATH.")
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        thread_id = state.get("thread_id")
        project_dir = str(Path(__file__).resolve().parent.parent)
        last_message = result_path.with_suffix(".answer.txt")
        if thread_id:
            command = [codex, "exec", "resume", "--json", "--skip-git-repo-check",
                       "-o", str(last_message), thread_id, "-"]
        else:
            command = [codex, "exec", "--json", "--skip-git-repo-check",
                       "--sandbox", "read-only", "-C", project_dir,
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
            atomic_json(state_path, {"thread_id": thread_id})
        atomic_json(result_path, {"ok": True, "answer": answer})
        return 0
    except Exception as error:
        atomic_json(result_path, {"ok": False, "error": str(error)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
