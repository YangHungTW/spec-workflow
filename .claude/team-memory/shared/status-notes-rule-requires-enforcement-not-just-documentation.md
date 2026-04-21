---
name: STATUS Notes rule requires enforcement, not just documentation
description: "Every role appends one STATUS Notes line per action" only works when a hook or reviewer enforces it; reminders alone keep missing entries across features.
type: feedback
created: 2026-04-20
updated: 2026-04-20
---

## Rule

Cross-role conventions that require per-role discipline (STATUS Notes append per action, retrospective authorship, memory-entry proposals) must be enforced by a tool or hook, not by prompt reminders alone. If a rule recurs as a gap-check finding across ≥3 features, escalate it to hook-enforcement or a pre-merge reviewer check.

## Why

Observed drift across the specflow feature series:

- **20260419-flow-monitor** — multiple developers forgot STATUS Notes lines; TPM caught at archive, lines backfilled from git log.
- **20260420-tier-model W0a** — T7 developer appended a STATUS Notes line to the working tree but did NOT commit it; orchestrator had to surgically remove.
- **20260420-tier-model W3** — T21, T23, T25 developers missed STATUS Notes on retry branches; backfilled at merge.
- **20260420-tier-model W4** — T28/T29 STATUS Notes absent until reviewer BLOCK forced a retry that included bookkeeping.

Prompt text says "append a STATUS Notes line"; agent behaviour follows the text in ~70% of invocations. The missing 30% is a systemic process-compliance gap, not an agent-quality issue. Reminders in more places produce diminishing returns.

## How to apply

### Orchestrator / TPM

1. **Track recurrence**. When a role-discipline rule fails in ≥3 archives, open a feature to automate the enforcement (reviewer axis, pre-commit hook, or stage-transition check).
2. **Do not "remind harder"**. Adding another bullet to the agent prompt after the second miss is wasted work; plan for enforcement.

### Developer

1. STATUS Notes lines are part of the task deliverable, not optional. The `Acceptance:` clause should cite `grep -F "YYYY-MM-DD <role> — <action>" STATUS.md`.
2. If the acceptance does not explicitly test for the STATUS Notes line, the TPM did not scope the task correctly — flag at task start, do not silently omit.

### Reviewer (future)

A structural-reviewer axis could check: "for each task merge commit, STATUS.md diff must contain one added Notes line dated today, prefixed with the role that authored the task". Cheap grep; catches the class at merge time.

## How to apply (mitigation today, until enforcement lands)

- TPM's archive retrospective MUST diff `STATUS.md` against the git log of the feature branch and flag missing per-role Notes lines. Backfilled lines during archive are acceptable; silent omissions are not.
- This memory entry itself is a reminder; its presence does not substitute for enforcement. When a future feature ships STATUS-Notes-enforcement, this entry can be updated or retired.

## Example

`20260420-tier-model` STATUS file at archive time shows 30+ Notes lines. Three of them were backfilled during validate/archive because the original task commits missed them. All three were caught manually by the orchestrator; none by automation. This entry documents the pattern so the next feature either automates it or accepts the manual diff-check as the mitigation.
