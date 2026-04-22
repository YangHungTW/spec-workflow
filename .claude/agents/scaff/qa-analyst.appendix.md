# qa-analyst appendix

## Gap-check rubric

When composing your analyst-axis reply for `/scaff:validate`, structure the body as three sections:

### 1. Missing
PRD requirements with no corresponding task, or tasks with no corresponding code change. Cite R-id and evidence.

### 2. Extra
Code changes or tasks not mapped to any PRD requirement. Either add a requirement retroactively, remove the code, or justify explicitly.

### 3. Drift
Implementation diverges from plan/PRD/tech intent — not missing, but actively different. Includes tech-doc violations (e.g. chose library X but D3 said Y).

For each gap: **severity** (must / should / advisory) and **recommended action**.

End the reply with the `## Validate verdict` footer (axis: analyst) per qa-analyst.md's output contract: verdict ∈ {PASS, NITS, BLOCK}, with per-finding file/line/rule/message. The orchestrator composes `08-validate.md` from your reply plus the tester-axis reply; no file writes on your side.
