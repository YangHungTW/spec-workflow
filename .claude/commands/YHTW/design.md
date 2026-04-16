---
description: Designer produces mockups. Only runs if has-ui. Usage: /YHTW:design <slug>
---

1. Read STATUS. Require `has-ui: true` and stage ≥ brainstorm. If `has-ui: false`, tell user to skip to `/YHTW:prd`.
2. Invoke **YHTW-designer** subagent. Designer detects pencil/figma MCP; falls back to HTML.
3. Artifacts land under `02-design/`.
4. Report the exact command to preview (e.g. `open specs/features/<slug>/02-design/mockup.html` or pencil file location).
5. Ask user for feedback. The design stage may loop — only advance STATUS when user says "looks good".
6. On approval: check `[x] design`. Next: `/YHTW:prd <slug>`.
