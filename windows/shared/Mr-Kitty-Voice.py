"""Render one explicitly requested Kitty reply with the local Kokoro voice."""

import json
from pathlib import Path
import re
import sys


def plain_speech(text: str) -> str:
    text = re.sub(r"```.*?```", " Code is shown in the chat. ", text, flags=re.S)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"https?://\S+", " a link ", text)
    text = re.sub(r"[`*_#>]", "", text)
    return " ".join(text.split())


def chunks(text: str, limit: int = 240) -> list[str]:
    sentences = re.split(r"(?<=[.!?])\s+", text)
    result: list[str] = []
    current = ""
    for sentence in sentences:
        words = sentence.split()
        for word in words:
            candidate = f"{current} {word}".strip()
            if len(candidate) > limit and current:
                result.append(current)
                current = word
            else:
                current = candidate
    if current:
        result.append(current)
    return result


def main() -> int:
    if len(sys.argv) != 5:
        print("Usage: Mr-Kitty-Voice.py request.json output.wav result.json model_dir", file=sys.stderr)
        return 2
    request_path, wav_path, result_path, model_dir = map(Path, sys.argv[1:])
    try:
        import numpy as np
        import soundfile as sf
        from kokoro_onnx import Kokoro

        request = json.loads(request_path.read_text(encoding="utf-8"))
        text = plain_speech(str(request["text"]))
        if not text:
            raise ValueError("There is no reply to read.")
        text = text[:4000]
        voice = str(request.get("voice", "af_heart"))
        if voice not in {"af_heart", "af_sky"}:
            raise ValueError("Unknown Kitty voice.")
        model = Kokoro(str(model_dir / "kokoro-v1.0.int8.onnx"),
                       str(model_dir / "voices-v1.0.bin"))
        pieces = []
        sample_rate = None
        for phrase in chunks(text):
            audio, rate = model.create(phrase, voice=voice, speed=1.05)
            if sample_rate is not None and rate != sample_rate:
                raise RuntimeError("Voice sample rate changed within a reply.")
            sample_rate = rate
            pieces.append(np.asarray(audio, dtype=np.float32))
            pieces.append(np.zeros(int(rate * 0.12), dtype=np.float32))
        samples = np.concatenate(pieces)
        if not np.isfinite(samples).all() or len(samples) < sample_rate // 4:
            raise RuntimeError("The voice model returned invalid or empty audio.")
        wav_path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(str(wav_path), samples, sample_rate, subtype="PCM_16")
        result = {"ok": True, "seconds": round(len(samples) / sample_rate, 3),
                  "sample_rate": sample_rate, "voice": voice, "characters": len(text)}
    except Exception as exc:
        result = {"ok": False, "error": str(exc)}
    result_path.write_text(json.dumps(result), encoding="utf-8")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
