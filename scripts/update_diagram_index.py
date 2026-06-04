#!/usr/bin/env python3
"""Rebuild the use-case column in docs/SEQUENCE_DIAGRAMS.md index table."""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from diagram_catalog import DIAGRAM_CATALOG, use_case  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "SEQUENCE_DIAGRAMS.md"

ORDER = [
    "UC-00", "UC-P01", "UC-P02", "UC-P03", "UC-C01", "UC-C02",
    "UC-T00", "UC-T01", "UC-T02", "UC-T03", "UC-T04", "UC-T05", "UC-T06", "UC-T07",
    "UC-A01", "UC-A02", "UC-A03", "UC-A04",
    "UC-O01", "UC-O02", "UC-O03", "UC-O04",
    "UC-PO01", "UC-PO02", "UC-PO03",
    "UC-G01", "UC-G02", "UC-G03", "UC-S01", "UC-M01", "UC-M02",
]

ANCHORS = {uid: re.search(rf"\[{uid}\]\(#([^)]+)\)", SOURCE.read_text()).group(1)
           for uid in ORDER if re.search(rf"\[{uid}\]\(#", SOURCE.read_text())}

CAT = {
    "UC-00": "Overview",
    "UC-P01": "Platform", "UC-P02": "Platform", "UC-P03": "Platform",
    "UC-C01": "Control plane", "UC-C02": "Control plane",
    "UC-T00": "Transfers", "UC-T01": "Transfers", "UC-T02": "Transfers",
    "UC-T03": "Transfers", "UC-T04": "Transfers", "UC-T05": "Transfers",
    "UC-T06": "Transfers", "UC-T07": "Transfers",
    "UC-A01": "Automation", "UC-A02": "Automation", "UC-A03": "Automation", "UC-A04": "Automation",
    "UC-O01": "Onboarding", "UC-O02": "Onboarding", "UC-O03": "Onboarding", "UC-O04": "Onboarding",
    "UC-PO01": "Portal", "UC-PO02": "Portal", "UC-PO03": "Portal",
    "UC-G01": "Agent", "UC-G02": "Agent", "UC-G03": "Agent",
    "UC-S01": "SFTP inbound", "UC-M01": "Operations", "UC-M02": "Operations",
}


def main() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    titles = {
        m.group(1): m.group(2).strip()
        for m in re.finditer(r"^#{2,3}\s+(UC-[A-Z0-9]+):\s+(.+)$", text, re.M)
    }
    rows = []
    for uid in ORDER:
        t = titles.get(uid, DIAGRAM_CATALOG[uid][0])
        summary = use_case(uid)
        if len(summary) > 80:
            summary = summary[:77] + "..."
        rows.append(
            f"| [{uid}](#{ANCHORS[uid]}) | {t} | {summary} | "
            f"[png](sequence-diagrams/png/{uid}.png) | {CAT[uid]} |"
        )
    table = (
        "| ID | Diagram | Use case (summary) | PNG | Category |\n"
        "|----|---------|-------------------|-----|----------|\n"
        + "\n".join(rows)
        + "\n"
    )
    text2 = re.sub(
        r"\| ID \| Diagram \| Use case \(summary\) \| PNG \| Category \|\n"
        r"\|[-| ]+\|\n(?:\|[^\n]+\n)+",
        table,
        text,
        count=1,
    )
    SOURCE.write_text(text2, encoding="utf-8")
    print("Index table updated.")


if __name__ == "__main__":
    main()
