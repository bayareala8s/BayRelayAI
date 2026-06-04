"""Add Mermaid title frontmatter and use-case note to sequence diagrams."""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from diagram_catalog import DIAGRAM_CATALOG, full_title, use_case  # noqa: E402

FRONTMATTER_RE = re.compile(r"^---\s*\ntitle:.*?\n---\s*\n", re.DOTALL)
USE_CASE_NOTE_RE = re.compile(
    r"^\s*Note over [^:]+: Use case:.*\n", re.MULTILINE
)
PARTICIPANT_RE = re.compile(r"^\s*participant\s+(\w+)\s", re.MULTILINE)
HEADING_RE = re.compile(r"^(#{2,3})\s+(UC-[A-Z0-9]+):\s+(.+)$", re.MULTILINE)
BLOCK_RE = re.compile(r"```mermaid\n(.*?)```", re.DOTALL)


def strip_decorations(body: str) -> str:
    body = FRONTMATTER_RE.sub("", body)
    body = USE_CASE_NOTE_RE.sub("", body)
    return body.strip()


def participant_aliases(body: str) -> list[str]:
    return PARTICIPANT_RE.findall(body)


def decorate_mermaid(uc_id: str, body: str) -> str:
    body = strip_decorations(body)
    if uc_id not in DIAGRAM_CATALOG:
        return body

    aliases = participant_aliases(body)
    lines = body.splitlines()
    if aliases:
        last_p = -1
        for i, line in enumerate(lines):
            if PARTICIPANT_RE.match(line):
                last_p = i
        note = f"  Note over {aliases[0]},{aliases[-1]}: Use case: {use_case(uc_id)}"
        lines.insert(last_p + 1, note)

    inner = "\n".join(lines)
    return f"---\ntitle: {full_title(uc_id)}\n---\n{inner}"


def sync_markdown(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    updated = text

    for block in reversed(list(BLOCK_RE.finditer(updated))):
        start, end = block.span(1)
        uc_id = _uc_id_before(updated, block.start())
        if not uc_id:
            continue
        old = block.group(1).strip()
        new = decorate_mermaid(uc_id, old)
        if new != old:
            updated = updated[:start] + new.rstrip() + "\n" + updated[end:]

    for match in reversed(list(HEADING_RE.finditer(updated))):
        uc_id = match.group(2)
        if uc_id not in DIAGRAM_CATALOG:
            continue
        line_end = match.end()
        use_line = f"\n\n> **Use case:** {use_case(uc_id)}"
        rest = updated[line_end:]
        existing = re.match(r"\n+> \*\*Use case:\*\*[^\n]*", rest)
        if existing:
            updated = updated[:line_end] + use_line + rest[existing.end() :]
        else:
            updated = updated[:line_end] + use_line + rest

    if updated != text:
        path.write_text(updated, encoding="utf-8")
        return 1
    return 0


def _uc_id_before(text: str, pos: int) -> str | None:
    hid = None
    for m in re.finditer(r"^#{2,3}\s+(UC-[A-Z0-9]+)\b", text, re.MULTILINE):
        if m.start() < pos:
            hid = m.group(1)
        else:
            break
    return hid


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    target = root / "docs" / "SEQUENCE_DIAGRAMS.md"
    changed = sync_markdown(target)
    print("Updated SEQUENCE_DIAGRAMS.md" if changed else "No changes needed")
