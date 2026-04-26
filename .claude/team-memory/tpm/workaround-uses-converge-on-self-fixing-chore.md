---
name: workaround-uses-converge-on-self-fixing-chore
description: Workaround memories accrue an empirical use-count; when the count reaches the threshold where the cost of remembering the workaround exceeds the cost of plumbing, the next chore that hits the workaround should land the fix as its own T1 — making that chore "self-fixing". The plan §1.3 should name the count, mark "final occurrence", and the memory disposition is update-not-retire (legacy step stays referenceable from archived precedents).
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a TPM-axis workaround memory's `How-to-apply` step has been applied N times across N archived features (typically N≥3), the next feature that would hit the workaround is a candidate to BECOME the plumbing fix rather than apply the workaround a (N+1)th time. The pattern: the chore's T1 lands the fix; the same chore's `05-plan.md` is itself produced by the (now-final) workaround application. Plan §1.3 names this self-reference explicitly ("Nth and final occurrence — T1 lands the fix that retires this workaround"). The memory disposition is update-not-retire: mark step 1 `[LEGACY — applicable only when reading the N archived precedents]` and add a `[CURRENT]` step pointing at the new wired path.

## Why

Observed in `20260426-chore-scaff-plan-chore-aware`: the workaround memory `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` had been applied four times (`t108-migrate-coverage`, `seed-copies-settings`, `t114-migrate-coverage`, `status-template-skip-stages`); the fifth occurrence's plan §1.3 explicitly stated "fifth and final" and T1 landed the Option A plumbing fix. The chore is structurally self-referential — its own 05-plan.md required hand-writing under the very workaround it eliminates. The bootstrap recursion is uncomfortable but legitimate; calling it out in §1.3 is the readability fix.

Counter-pattern (worth flagging): if a workaround has been applied <3 times, the empirical evidence of stability is weak and templating it into the codebase is premature. The convergence threshold is "the workaround's recipe has stopped evolving across uses"; until then, bias toward continuing the workaround and refining the recipe.

Cross-reference: `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` is the canonical instance; `shared/dogfood-paradox-third-occurrence.md` is the adjacent self-referential class (tool delivers itself).

## How to apply

1. **Track the use count** in the workaround memory's §Why section ("As of <date>, N features have shipped under this workaround"). Bump on each new occurrence.
2. **At threshold (N≥3 stable applications)**: the next feature that would hit the workaround is a candidate to land the plumbing fix instead. PM proposes Option A / Option B; TPM plans the chore.
3. **Plan §1.3 (or equivalent) MUST name the self-reference**: "this 05-plan.md is itself produced by the workaround on its (N+1)th and final use; T1 lands the fix; future features will not need this stub". Without this paragraph, a reader cold to the feature will try to "fix" the hand-written plan.
4. **Memory disposition = update, not retire**. Mark legacy step `[LEGACY — applicable only when reading the N archived precedents]`; add `[CURRENT]` step pointing at the new wired path; preserve the rejected-options block as `[ARCHIVED]` for future readers asking why this option was chosen.
5. **Do NOT backfill** the N archived features' artefacts to use the new path. Archive immutability — the convention applies forward only.
6. **At the chore's archive retro**: confirm the use-count update in the memory, and verify any sibling workarounds that referenced "until plumbing lands" no longer use that wording.

## Example

`20260426-chore-scaff-plan-chore-aware` 05-plan.md §1.3 (lines 26–32):

> This is the fifth and final occurrence of the workaround — T1 of this feature lands the plumbing fix that means future chore × any-tier features will have TPM auto-generate this shape. After this feature archives, the orchestrator's next.md pseudocode for chore-tiny matrix-skip will delegate to /scaff:plan (which TPM short-circuits) instead of hand-writing. This file is the sentinel boundary — it exists to record that the workaround was used and is now retired.

Memory `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` after the fix landed:
- Frontmatter `updated: 2026-04-26`.
- §Why: "As of 2026-04-26, three chore-tiny shipped under hand-write, plus one chore × standard variant ... The Option A plumbing fix landed in 20260426-chore-scaff-plan-chore-aware".
- §How-to-apply: step 1 marked `[LEGACY ...]`; step 2 marked `[CURRENT]` and points at TPM's chore-tiny short-circuit; step 3 marked `[ARCHIVED]` preserving the Option A/B rationale.
