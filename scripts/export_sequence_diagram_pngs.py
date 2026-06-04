#!/usr/bin/env python3
"""Extract Mermaid blocks from docs/SEQUENCE_DIAGRAMS.md and export PNGs."""

from __future__ import annotations

import base64
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from diagram_catalog import DIAGRAM_CATALOG  # noqa: E402
from mermaid_diagram_decorate import decorate_mermaid  # noqa: E402

SOURCE = ROOT / "docs" / "SEQUENCE_DIAGRAMS.md"
OUT_DIR = ROOT / "docs" / "sequence-diagrams" / "png"
MMD_DIR = ROOT / "docs" / "sequence-diagrams" / "mmd"

HEADING_RE = re.compile(r"^#{2,3}\s+(UC-[A-Z0-9]+)\b", re.MULTILINE)
BLOCK_RE = re.compile(r"```mermaid\n(.*?)```", re.DOTALL)


def diagram_ids_and_blocks(text: str) -> list[tuple[str, str]]:
    """Pair each mermaid block with the nearest preceding UC-* heading."""
    headings = [(m.start(), m.group(1)) for m in HEADING_RE.finditer(text)]
    pairs: list[tuple[str, str]] = []
    for block in BLOCK_RE.finditer(text):
        pos = block.start()
        uc_id = "UC-UNKNOWN"
        for hpos, hid in headings:
            if hpos < pos:
                uc_id = hid
            else:
                break
        pairs.append((uc_id, block.group(1).strip()))
    return pairs


def mmdc_bin() -> Path | None:
    local = ROOT / "scripts" / "node-tools" / "node_modules" / ".bin" / "mmdc"
    if local.is_file():
        return local
    return None


def export_via_mmdc(mmd_path: Path, png_path: Path) -> None:
    mmdc = mmdc_bin()
    if not mmdc:
        raise RuntimeError("mmdc not installed")
    subprocess.run(
        [
            str(mmdc),
            "-i",
            str(mmd_path),
            "-o",
            str(png_path),
            "-b",
            "white",
            "-w",
            "1920",
            "-H",
            "1080",
            "--scale",
            "2",
        ],
        check=True,
        capture_output=True,
        text=True,
    )


def export_via_mermaid_ink(mermaid: str, png_path: Path) -> None:
    encoded = base64.urlsafe_b64encode(mermaid.encode("utf-8")).decode("ascii")
    url = f"https://mermaid.ink/img/{encoded}?type=png&bgColor=!white"
    last_err: Exception | None = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "BayRelay-export/1.0"}
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            if len(data) < 500:
                raise RuntimeError(f"unexpected small response ({len(data)} bytes)")
            png_path.write_bytes(data)
            return
        except urllib.error.HTTPError as exc:
            last_err = exc
            if exc.code in (429, 503) and attempt < 4:
                import time

                time.sleep(2 ** attempt)
                continue
            raise
    if last_err:
        raise last_err


def main() -> int:
    if not SOURCE.is_file():
        print(f"Missing {SOURCE}", file=sys.stderr)
        return 1

    text = SOURCE.read_text(encoding="utf-8")
    pairs = diagram_ids_and_blocks(text)
    if not pairs:
        print("No mermaid blocks found", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    MMD_DIR.mkdir(parents=True, exist_ok=True)

    use_mmdc = mmdc_bin() is not None
    ok, fail = 0, 0
    seen: dict[str, int] = {}

    for uc_id, mermaid in pairs:
        seen[uc_id] = seen.get(uc_id, 0) + 1
        suffix = f"-{seen[uc_id]}" if seen[uc_id] > 1 else ""
        stem = f"{uc_id}{suffix}"
        mmd_path = MMD_DIR / f"{stem}.mmd"
        png_path = OUT_DIR / f"{stem}.png"
        if uc_id in DIAGRAM_CATALOG:
            mermaid = decorate_mermaid(uc_id, mermaid)
        mmd_path.write_text(mermaid + "\n", encoding="utf-8")

        try:
            if use_mmdc:
                export_via_mmdc(mmd_path, png_path)
            else:
                export_via_mermaid_ink(mermaid, png_path)
            print(f"OK  {png_path.relative_to(ROOT)}")
            ok += 1
        except Exception as exc:
            print(f"FAIL {stem}: {exc}", file=sys.stderr)
            fail += 1

    print(f"\nExported {ok} PNG(s) to {OUT_DIR.relative_to(ROOT)} ({fail} failed)")
    print(f"Source .mmd files: {MMD_DIR.relative_to(ROOT)}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
