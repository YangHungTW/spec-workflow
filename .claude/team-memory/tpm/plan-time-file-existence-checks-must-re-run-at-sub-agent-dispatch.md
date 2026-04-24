---
name: Plan-time file-existence claims must be re-run at sub-agent dispatch — write the verbatim search command into the task
description: A "file X already exists" claim made at plan time can stale-out by the time a sub-agent dispatches the task; the plan must embed the verbatim search command (`find … -name X` or `ls path/X`) so the sub-agent re-checks at its own dispatch time and reports the actual finding, not the plan's prediction.
type: feedback
created: 2026-04-24
updated: 2026-04-24
---

## Rule

When a task briefing says "file X already exists" or "the README.zh-TW.md is already in place", the plan MUST embed the verbatim search command the developer should run at task-start (e.g., `find . -name README.zh-TW.md -not -path './.git/*'`) rather than just the *claim*. Sub-agents dispatch hours or days after plan-authoring; intervening work (other waves merging, manual edits, file moves, gitignore changes) can invalidate the claim. Embedding the command makes re-verification a one-command paste, not a judgment call.

## Why

`20260424-entry-type-split` T15 surfaced this pattern as a near-miss:

- Plan authored at 2026-04-24 morning said: "T15 should not need to author README.zh-TW.md because that file was added during 20260421-rename-flow-monitor and is already in place."
- T15 dispatched at 2026-04-24 afternoon. The developer ran `find README.zh-TW.md` (no `-name` flag, no path scope) and got an empty result — `find` was treating `README.zh-TW.md` as a path, not a name pattern.
- Without the verbatim command in the plan, the developer had to interpret the plan's claim against their own search result and choose: trust the plan (skip the work) or trust the empty find (re-author the file).
- The correct behaviour was "trust your re-check"; the file did exist, but `find -name README.zh-TW.md` (with the flag) was the right command to confirm. The plan's claim was correct; the developer's search was wrong.

The structural fix is to embed the verbatim search command into the task briefing itself. Then the developer doesn't have to compose a search; they paste-and-run. If the search returns empty when the plan claimed the file exists, the plan-vs-reality gap surfaces immediately and is fixable via `/scaff:update-plan`.

This is a generalisation of `tpm/briefing-contradicts-schema.md` ("quote, don't paraphrase the schema") to file-existence claims: don't paraphrase the search; quote it.

## How to apply

1. **For every "file X exists" or "X is already in place" claim** in a task briefing, embed the verbatim shell command the developer should run to re-verify at dispatch time. Use one of these forms:
   - **Single file**: `Verify with: ls .specaffold/prd-templates/bug.md`
   - **By name pattern**: `Verify with: find . -name 'README.zh-TW.md' -not -path './.git/*' -not -path './node_modules/*'`
   - **By content pattern**: `Verify with: grep -l 'work-type: bug' .claude/agents/scaff/*.md`
   - **Multiple paths**: prefer one explicit `ls -la <path>` per file over a glob the developer must mentally expand.
2. **The claim and the command must agree.** If the plan says "file X exists" but the embedded `find` returns empty when the developer runs it, the plan is stale — the developer should `/scaff:update-plan` rather than guessing.
3. **Never assume the developer will compose the right search.** `find` semantics differ between BSD and GNU; `find . X` vs `find . -name X` vs `find . -path '*X'` all behave differently and are easy to confuse. The plan author should compose the correct command once, then every developer who reads the plan benefits.
4. **Re-verify at dispatch even when the claim seems obvious.** Inter-wave merges, manual user edits, and gitignore changes can invalidate any plan-time claim. The cost of re-verifying is one paste-and-run; the cost of acting on a stale claim is a false-negative implementation.
5. **For files authored by a prior feature**, additionally cite the source feature and the specific commit/task: `README.zh-TW.md was added by 20260421-rename-flow-monitor T8 (commit eb858c4); verify with: ls README.zh-TW.md`.

## Example

The remediated form of T15 in 05-plan.md (would have been authored as):

```markdown
- [ ] T15 — Verify README.zh-TW.md is current; do NOT re-author.
  - Files (read-only): README.zh-TW.md
  - Verify with: ls -la README.zh-TW.md && git log --oneline -1 -- README.zh-TW.md
  - Expected: file exists, last touched by 20260421-rename-flow-monitor T8.
  - If verify returns empty/missing: STOP and `/scaff:update-plan` — the
    plan's "already in place" claim is stale; re-author scope must be re-decided.
```

The original T15 wording said "README.zh-TW.md is already in place from 20260421-rename-flow-monitor; this task is a no-op verify." That phrasing forced the developer to compose a search; the verbatim form removes that compose step entirely.

Source: `20260424-entry-type-split` T15 false-negative on `find README.zh-TW.md`; surfaced during validate as a structural anomaly when t102's "no duplicate authoring of zh-TW README" check passed but the developer's STATUS Notes line said "file appears missing, but plan says skip — proceeding with skip per plan".

Cross-reference: `tpm/briefing-contradicts-schema.md` (quote-don't-paraphrase) and `tpm/task-scope-fence-literal-placeholder-hazard.md` (placeholders interpreted literally) — all three address the same root cause: developers act on the literal text of the briefing, so the briefing must contain the literal command/value/path the developer will execute.
