# qa-analyst appendix

## Gap-check rubric

When writing `07-gaps.md`, structure it as three sections:

### 1. Missing
PRD requirements with no corresponding task, or tasks with no corresponding code change. Cite R-id and evidence.

### 2. Extra
Code changes or tasks not mapped to any PRD requirement. Either add a requirement retroactively, remove the code, or justify explicitly.

### 3. Drift
Implementation diverges from plan/PRD/tech intent — not missing, but actively different. Includes tech-doc violations (e.g. chose library X but D3 said Y).

For each gap: **severity** (blocker / should-fix / note) and **recommended action**.

End with:
- `## Verdict: PASS` if zero blockers, OR
- `## Verdict: BLOCKED` with the list of blocking gaps.
