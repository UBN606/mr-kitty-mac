"""Build one reproducible Windows package for Codex and Claude Code Kitty."""

import hashlib
from pathlib import Path
import sys
import zipfile


WINDOWS = Path(__file__).resolve().parent
ROOT = WINDOWS.parent
OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "Mr-Kitty-Windows-Shared-Codex-Claude.zip"
PREFIX = "Mr-Kitty-Shared-Windows"
FILES = {
    "README-FIRST.txt": WINDOWS / "shared" / "README-FIRST.txt",
    "mr-kitty/pet.json": WINDOWS / "codex-custom-pet" / "pet.json",
    "mr-kitty/spritesheet.webp": WINDOWS / "codex-custom-pet" / "spritesheet.webp",
    "controller/Mr-Kitty-Chat.py": WINDOWS / "shared" / "Mr-Kitty-Chat.py",
    "controller/Mr-Kitty-Codex-Watcher.py": WINDOWS / "shared" / "Mr-Kitty-Codex-Watcher.py",
    "controller/Mr-Kitty-Controller.ps1": WINDOWS / "shared" / "Mr-Kitty-Controller.ps1",
    "controller/Start-Mr-Kitty-Shared.cmd": WINDOWS / "shared" / "Start-Mr-Kitty-Shared.cmd",
    "controller/Start-Mr-Kitty-Shared.ps1": WINDOWS / "shared" / "Start-Mr-Kitty-Shared.ps1",
    "controller/kitty-curl.png": WINDOWS / "shared" / "kitty-curl.png",
    "controller/kitty-sit.png": WINDOWS / "shared" / "kitty-sit.png",
}


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9) as archive:
        for name, source in sorted(FILES.items()):
            info = zipfile.ZipInfo(f"{PREFIX}/{name}", date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            content = source.read_bytes()
            if source.suffix.lower() in {".txt", ".json", ".py", ".ps1", ".cmd"}:
                content = content.replace(b"\r\n", b"\n")
                if source.suffix.lower() == ".cmd":
                    content = content.replace(b"\n", b"\r\n")
            archive.writestr(info, content, compress_type=zipfile.ZIP_DEFLATED,
                             compresslevel=9)
    with zipfile.ZipFile(OUTPUT) as archive:
        bad = archive.testzip()
        if bad or len(archive.namelist()) != len(FILES):
            raise RuntimeError(f"Invalid package: {bad or 'unexpected file count'}")
    print(f"PACKAGE={OUTPUT.resolve()}")
    print(f"BYTES={OUTPUT.stat().st_size}")
    print(f"SHA256={hashlib.sha256(OUTPUT.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
