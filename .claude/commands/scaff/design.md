---
description: Designer produces mockups. Only runs if has-ui. Usage: /scaff:design <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Read STATUS. Require `has-ui: true` and stage ≥ brainstorm. If `has-ui: false`, tell user to skip to `/scaff:prd`.
2. Invoke **scaff-designer** subagent. Designer detects pencil/figma MCP; falls back to HTML.
3. Artifacts land under `02-design/`.
4. Report the exact command to preview (e.g. `open .specaffold/features/<slug>/02-design/mockup.html` or pencil file location).
5. Ask user for feedback. The design stage may loop — only advance STATUS when user says "looks good".
6. On approval: check `[x] design`. Next: `/scaff:prd <slug>`.
