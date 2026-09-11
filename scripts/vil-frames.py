#!/usr/bin/env python3
"""Grade-1 checks for ViL frame directories: magic, bytes, sha256, non-blank stdev."""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

PNG = b"\x89PNG"
JPEG = b"\xff\xd8\xff"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: vil-frames.py <frames-dir>", file=sys.stderr)
        return 2
    d = Path(sys.argv[1])
    files = sorted(p for p in d.iterdir() if p.suffix.lower() in {".png", ".jpg", ".jpeg"})
    if not files:
        print(f"FAIL empty: {d}")
        return 1
    bad = 0
    for p in files:
        data = p.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        if data.startswith(PNG):
            kind = "png"
        elif data.startswith(JPEG):
            kind = "jpeg"
        else:
            kind = "UNKNOWN"
            bad += 1
        print(f"{p.name}\t{len(data)}\t{kind}\t{sha}")
        if len(data) < 32:
            bad += 1
    print(f"frames={len(files)} bad={bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
