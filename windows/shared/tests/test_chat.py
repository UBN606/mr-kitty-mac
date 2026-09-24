"""Offline checks for the two independent Kitty chat backends."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "Mr-Kitty-Chat.py"
SPEC = importlib.util.spec_from_file_location("mr_kitty_chat", SOURCE)
CHAT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHAT)


class KittyChatTests(unittest.TestCase):
    def test_codex_uses_its_own_thread_and_read_only_first_turn(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            state = {}
            calls = []

            def fake_run(command, **kwargs):
                calls.append((command, kwargs))
                Path(command[command.index("-o") + 1]).write_text("Codex answer", encoding="utf-8")
                return subprocess.CompletedProcess(command, 0,
                    stdout='{"type":"thread.started","thread_id":"codex-123"}\n', stderr="")

            with patch.object(CHAT.shutil, "which", return_value="codex.exe"), \
                 patch.object(CHAT.subprocess, "run", side_effect=fake_run):
                answer = CHAT.run_codex("hello", state, root, root / "result.json")
                self.assertEqual(answer, "Codex answer")
                self.assertEqual(state["codex_thread_id"], "codex-123")
                self.assertIn("read-only", calls[0][0])
                self.assertEqual(calls[0][1]["input"], "hello")
                CHAT.run_codex("again", state, root, root / "result.json")
                self.assertIn("resume", calls[1][0])
                self.assertNotIn("claude_session_id", state)

    def test_claude_keeps_a_different_session_without_tools(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            state = {"codex_thread_id": "codex-123"}
            calls = []

            def fake_run(command, **kwargs):
                calls.append((command, kwargs))
                return subprocess.CompletedProcess(command, 0,
                    stdout=json.dumps({"result": "Claude answer", "session_id": "claude-456"}), stderr="")

            with patch.object(CHAT.shutil, "which", return_value="claude.exe"), \
                 patch.object(CHAT.subprocess, "run", side_effect=fake_run), \
                 patch.dict(CHAT.os.environ, {}, clear=True):
                answer = CHAT.run_claude("hello", state, root)
                self.assertEqual(answer, "Claude answer")
                self.assertEqual(state["codex_thread_id"], "codex-123")
                self.assertEqual(state["claude_session_id"], "claude-456")
                self.assertEqual(calls[0][1]["input"], "hello")
                self.assertEqual(calls[0][0][calls[0][0].index("--tools") + 1], "")
                self.assertIn("mcp__*", calls[0][0])
                CHAT.run_claude("again", state, root)
                self.assertEqual(calls[1][0][-2:], ["--resume", "claude-456"])

    def test_missing_claude_cli_gives_specific_error(self):
        with patch.object(CHAT.shutil, "which", return_value=None), \
             patch.dict(CHAT.os.environ, {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, "Claude Code CLI"):
                CHAT.run_claude("hello", {}, Path("."))


if __name__ == "__main__":
    unittest.main()
