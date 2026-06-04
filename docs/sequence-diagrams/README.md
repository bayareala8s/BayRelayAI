# BayRelay sequence diagram assets

| Folder | Contents |
|--------|----------|
| [`png/`](png/) | 31 PNG exports (one per use case in [SEQUENCE_DIAGRAMS.md](../SEQUENCE_DIAGRAMS.md)) |
| [`mmd/`](mmd/) | Mermaid source extracted for local rendering |

Each PNG includes a **title** (Mermaid frontmatter) and an in-diagram **Use case** note. Titles and copy live in `scripts/diagram_catalog.py`.

## Regenerate

```bash
./scripts/export_sequence_diagram_pngs.sh
```

Requires **Node.js** and **npm**. On first run, installs `@mermaid-js/mermaid-cli` under `scripts/node-tools/`. Uses system Chrome when available (`PUPPETEER_EXECUTABLE_PATH`).

## Naming

Files match diagram IDs: `UC-00.png`, `UC-P01.png`, `UC-T00.png`, etc.
