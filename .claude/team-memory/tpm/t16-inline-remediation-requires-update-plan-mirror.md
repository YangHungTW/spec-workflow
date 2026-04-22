## Rule

When a plan-gap is remediated inline at wave-close time (e.g. adding allow-list entries in a bookkeeping commit to make a structural gate pass), the TPM / orchestrator MUST still run `/scaff:update-plan` afterwards to mirror the shipped state into the plan file. Skipping the mirror creates plan-drift that analyst axis catches at validate.

## Why

Inline remediation at wave-close is a legitimate response to a plan-gap — it makes the shipped feature complete without stalling the implement stage. But the plan file's task `Scope:`, `Deliverables:`, and `Verify:` fields were authored before the remediation. Without a mirror pass, those fields now describe a state that does not match what landed:

- Plan says T14 adds "exactly one narrow entry"; shipped state has 4 entries.
- Plan says T14's Verify is "count unchanged"; shipped state falsifies this.
- Any reader reconstructing the feature from the plan alone would be misled.

This is different from the rule captured in `tpm/update-plan-must-mirror-to-prd-and-tech-when-touching-acceptance-values.md` (that rule says update-plan must mirror to PRD+tech). The gap addressed here is the PRE-condition: `/scaff:update-plan` must be INVOKED in the first place, even when the remediation is already landed. Transparency in the STATUS Notes + commit message is not a substitute for plan-file accuracy.

## How to apply

1. If you add/remove/edit files outside a task's declared `Scope:` during wave-close remediation, open `/scaff:update-plan` immediately after the bookkeeping commit to mirror the change.
2. The mirror pass is cheap: it rewrites the affected task's `Scope:` / `Deliverables:` / `Verify:` to match shipped state, and optionally adds a new task (e.g. T17 post-hoc) if the remediation was out-of-scope. It is NOT a request for re-dispatch.
3. Do NOT rely on STATUS Notes and commit messages as the "source of truth" for shipped state. They are audit trail, not plan content. Downstream agents (validate, archive) read the plan file and will flag drift they find there.
4. If the remediation is small enough to mirror inline within the bookkeeping commit itself (edit `05-plan.md` in the same commit as the allow-list), that also works — the rule is "no drift between plan and shipped," not "must invoke the subcommand specifically."

## Example

`20260421-rename-flow-monitor` T16 surfaced that `bash test/t_grep_allowlist.sh` required 3 additional carve-outs beyond T14's declared scope:

- `flow-monitor/dist/**`
- `.specaffold/features/20260421-rename-flow-monitor/**`
- `.claude/team-memory/**`

The TPM added these entries inline in the wave-2 bookkeeping commit `4c8a149` and documented the plan-gap in STATUS + commit body — but did NOT invoke `/scaff:update-plan` to mirror the shipped state back into 05-plan.md T14's `Scope:` and `Verify:` fields. At validate, the analyst axis caught this as a `should`-severity plan-gap finding: T14's Verify assertion (`grep -cvE '^(#|$)' .claude/carryover-allowlist.txt returns the same count as before the edit`) is falsified by the shipped state (11 → 14 entries).

Low-risk — all 3 remediation entries are individually justified — but the plan drift is visible in the analyst report and future readers reconstructing the feature from 05-plan.md alone would be misled. Cheap to prevent; expensive to clean up retroactively.
