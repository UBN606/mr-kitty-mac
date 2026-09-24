"""Contract checks for selecting only finished visible desktop replies."""

import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "Mr-Kitty-Desktop-Speech-Watcher.py"
SPEC = importlib.util.spec_from_file_location("kitty_desktop_speech_watcher", SCRIPT)
WATCHER = importlib.util.module_from_spec(SPEC)
import sys
sys.modules[SPEC.name] = WATCHER
SPEC.loader.exec_module(WATCHER)


def line(value):
    return json.dumps(value).encode("utf-8")


class DesktopSpeechSelectionTests(unittest.TestCase):
    def test_codex_reads_final_only(self):
        message = {
            "type": "response_item",
            "payload": {
                "type": "message", "role": "assistant", "phase": "final_answer",
                "content": [{"type": "output_text", "text": "Kitty says hello."}],
            },
        }
        self.assertEqual(WATCHER.final_reply("codex", line(message)), "Kitty says hello.")
        message["payload"]["phase"] = "commentary"
        self.assertEqual(WATCHER.final_reply("codex", line(message)), "")

    def test_claude_reads_only_non_sidechain_end_turn_text(self):
        message = {
            "type": "assistant", "isSidechain": False,
            "message": {
                "role": "assistant", "stop_reason": "end_turn",
                "content": [{"type": "thinking", "thinking": "private"},
                            {"type": "text", "text": "Finished reply."}],
            },
        }
        self.assertEqual(WATCHER.final_reply("claude", line(message)), "Finished reply.")
        message["isSidechain"] = True
        self.assertEqual(WATCHER.final_reply("claude", line(message)), "")
        message["isSidechain"] = False
        message["message"]["stop_reason"] = "tool_use"
        self.assertEqual(WATCHER.final_reply("claude", line(message)), "")

    def test_existing_history_is_not_read_aloud(self):
        old = {"type": "response_item", "payload": {
            "type": "message", "role": "assistant", "phase": "final_answer",
            "content": [{"type": "output_text", "text": "old reply"}],
        }}
        fresh = {"type": "response_item", "payload": {
            "type": "message", "role": "assistant", "phase": "final_answer",
            "content": [{"type": "output_text", "text": "new reply"}],
        }}
        with TemporaryDirectory() as directory:
            path = Path(directory) / "session.jsonl"
            path.write_bytes(line(old) + b"\n")
            tail = WATCHER.Tail(path, "codex", path.stat().st_size)
            heard = []
            original = WATCHER.queue_reply
            WATCHER.queue_reply = lambda source, text: heard.append((source, text))
            try:
                WATCHER.read_new(tail)
                with path.open("ab") as stream:
                    stream.write(line(fresh) + b"\n")
                WATCHER.read_new(tail)
            finally:
                WATCHER.queue_reply = original
            self.assertEqual(heard, [("codex", "new reply")])


if __name__ == "__main__":
    unittest.main()
