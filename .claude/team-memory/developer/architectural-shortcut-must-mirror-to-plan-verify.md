---
name: Architectural shortcut must mirror to plan Verify in the same commit
description: When a developer's implementation diverges from the plan's prescribed mechanism in a way that improves the architecture (helper extraction, single-source-of-truth, dedup) but invalidates plan Verify commands, the developer MUST `/scaff:update-plan` in the same commit so plan Verify reflects the shipped shape.
type: feedback
created: 2026-04-26
updated: 2026-04-26
---

## Rule

If the developer's implementation diverges from the plan's prescribed mechanism — typically by introducing a helper, extracting a function, or deduplicating two byte-mirrored blocks into one — and that divergence invalidates the plan's Verify section, the developer MUST run `/scaff:update-plan` in the **same commit** to mirror the new shape into the plan's Scope and Verify lines. Leaving the plan's Verify section pointing at the obsolete mechanism turns the plan into misleading documentation.

## Why

In `20260426-fix-commands-source-from-scaff-src` T3, the plan prescribed dual byte-identical heredocs at `bin/scaff-seed` lines 797 and 1384 (mirroring the parent feature's `partial-wiring-trace-every-entry-point` lesson). The developer architecturally improved on this by introducing a single `emit_pre_commit_shim` helper at line 432, called from both `cmd_init` (line 829) and `cmd_migrate` (line 1395). The improvement was correct — one source of truth eliminates the cross-surface drift risk the plan was guarding against.

But the plan's T3 Verify section still read:

```
- **Verify**: ...
  grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l   # expects 2
  diff <(awk 'NR==797' bin/scaff-seed) <(awk 'NR==1384' bin/scaff-seed)     # expects empty
```

After the helper extraction:
- `readlink "$HOME/.claude/agents/scaff"` appears exactly **once** in `bin/scaff-seed` (line 432, inside the helper), not twice.
- `awk 'NR==797'` vs `awk 'NR==1384'` is meaningless — those lines no longer hold heredoc content.

qa-analyst at validate stage flagged this as F5 (`should`): future audits running the plan's Verify commands will false-positive (or get a meaningless diff between two unrelated lines). The plan became misleading documentation for the implementation that shipped.

The improvement was correct. The mistake was leaving the plan unsynchronized with it.

## How to apply

1. When implementing a task and you realize the plan's mechanism is superseded by a better shape (helper, dedup, single-source-of-truth), **before committing**, run `/scaff:update-plan <slug>` to update both the **Scope** narrative and the **Verify** section in the task block. The update-plan commit and the implementation commit should ideally be one commit (or two adjacent commits in the same wave-task).
2. Tag the changed Verify lines `[CHANGED YYYY-MM-DD: <reason>]` per the update-plan convention so future audits see the divergence and its rationale.
3. The dev-reply mention should explicitly call out the plan-shape change and the rationale, not bury it as an implementation detail. Example: "Implemented as single `emit_pre_commit_shim` helper instead of plan's dual heredocs — supersedes plan §3 T3 Verify; `/scaff:update-plan` in same commit updates Verify to grep for `wc -l == 1` against the helper's readlink call."
4. The orchestrator at wave-merge time should diff the plan's Verify section against the actual implementation's surface; this is a reviewer-style cross-cutting concern that catches plan-vs-shipped drift before it lands.
5. If the developer suspects the architectural shortcut is bigger than a Verify edit (e.g., the plan's Risk section or §1 narrative would also need to change), STOP, surface the proposed change, and let TPM re-plan via `/scaff:update-plan` rather than ship-and-document-after.

## Example

Plan T3 Verify before implementation (this is what was shipped, but the plan was never updated):

```
- **Verify**: bash -n bin/scaff-seed (syntax). After edit:
  grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"      # expects empty
  grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l   # expects exactly 2
  diff <(awk 'NR==797' bin/scaff-seed) <(awk 'NR==1384' bin/scaff-seed)     # expects empty (byte-identity)
```

What the plan SHOULD have been updated to (in the same commit as T3's implementation):

```
- **Verify**: bash -n bin/scaff-seed (syntax). After edit:
  grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"      # expects empty
  grep -c 'emit_pre_commit_shim' bin/scaff-seed                             # expects exactly 3 (definition + 2 callers)
  grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l   # expects exactly 1 (inside helper)
  [CHANGED 2026-04-26: refactored to single emit_pre_commit_shim helper called from cmd_init + cmd_migrate; supersedes plan's dual-heredoc mitigation since helper is a single source of truth, eliminating the cross-surface drift risk by construction.]
```

The byte-identity check that the plan was guarding (two heredocs being byte-identical) is now satisfied by construction (one helper, used twice). The plan should reflect that explicitly so the audit trail makes sense.
