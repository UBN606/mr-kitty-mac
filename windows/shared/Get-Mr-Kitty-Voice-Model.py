"""Download the free local Kitty voice files after the user runs setup."""

from pathlib import Path
import hashlib
import sys
from urllib.request import Request, urlopen


BASE = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/"
FILES = {
    "voices-v1.0.bin": (28_214_398, "bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d"),
    "kokoro-v1.0.int8.onnx": (114_119_327, "ae315a79b623f244700e4afb9246c46a26066782e049ba174bf3ba433970ee9c"),
}


def verified(path: Path, size: int, digest: str) -> bool:
    if not path.is_file() or path.stat().st_size != size:
        return False
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest() == digest


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: Get-Mr-Kitty-Voice-Model.py model_directory")
    root = Path(sys.argv[1])
    root.mkdir(parents=True, exist_ok=True)
    for name, (expected, digest) in FILES.items():
        target = root / name
        if verified(target, expected, digest):
            print(f"Already present: {name}", flush=True)
            continue
        part = root / f"{name}.part"
        part.unlink(missing_ok=True)
        with part.open("wb") as output:
            for start in range(0, expected, 4 * 1024 * 1024):
                end = min(start + 4 * 1024 * 1024, expected) - 1
                request = Request(BASE + name, headers={"Range": f"bytes={start}-{end}"})
                with urlopen(request, timeout=30) as response:
                    chunk = response.read()
                    actual_range = response.headers.get("Content-Range", "")
                if (len(chunk) != end - start + 1 or
                        actual_range != f"bytes {start}-{end}/{expected}"):
                    raise RuntimeError(f"Incomplete download of {name} at byte {start}")
                output.write(chunk)
                output.flush()
                print(f"{name}: {end + 1}/{expected}", flush=True)
        if not verified(part, expected, digest):
            raise RuntimeError(f"Wrong size or SHA-256 for {name}")
        part.replace(target)
        print(f"Ready: {name}", flush=True)


if __name__ == "__main__":
    main()
