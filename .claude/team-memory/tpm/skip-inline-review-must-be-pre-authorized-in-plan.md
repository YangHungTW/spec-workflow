---
name: Skip-inline-review on a wave must be pre-authorized in the plan
description: Whenever a wave will be merged with `--skip-inline-review`, the plan MUST enumerate the skip in §1.4 (or equivalent) BEFORE the merge. Logging it retroactively in a STATUS bookkeeping commit is not equivalent — it falsifies the plan's "every wave merge runs reviewer-style + reviewer-security" promise at execution time.
type: feedback
created: 2026-04-26
updated: 2026-04-26
---

## Rule

If the orchestrator anticipates merging any wave of a `standard` or `audited`-tier feature with `--skip-inline-review`, the plan must contain an explicit authorization clause naming the wave, the reason, and which reviewer axes are deferred — written **at plan time**, not added to STATUS Notes after the merge has happened. A retroactive STATUS bookkeeping line that documents the skip is not a substitute; the plan's enforcement contract has already been falsified by the time the bookkeeping lands.

## Why

In `20260426-fix-commands-source-from-scaff-src` W2 (T4: 18-file marker sweep) was merged in commit `6f6e800` with the merge-commit body line `(skipped per W2 fast-merge — T4 is the dogfood-paradox satisfier; reviewers can re-verify post-merge if needed)`. Plan §1.4 enumerated `--no-verify` sites for the dogfood-paradox sequencing but said nothing about skipping inline review for any wave. The plan's tier-line declaration `every wave merge runs reviewer-style + reviewer-security per .claude/rules/reviewer/*.md` became literally false at execution time. Two commits later the orchestrator added a retroactive STATUS Notes line in `3be7f59`: `2026-04-26 implement — skip-inline-review USED for wave 2 (reason: W2 fast-merge — T4 dogfood-paradox satisfier; …)`.

qa-analyst at validate stage flagged this as F4 (`should`): T4 included the D4 exit-65 security posture and the `bin/claude-symlink install` remediation text, neither of which were reviewed through the formal reviewer-security channel. The retroactive log captured the fact but did not retroactively review the content. Process gap was real even though the markdown content turned out to be benign.

The retroactive pattern is also a memory hazard: anyone reading the plan months later sees "every wave merge runs reviewer-style + reviewer-security" and trusts that the audit chain is intact. Only by reading STATUS Notes in commit-history order do they discover the skip. Pre-authorization in the plan keeps the audit trail single-sourced.

## How to apply

1. **At plan write time**, if any wave is anticipated to skip inline review (e.g., a bulk mechanical sweep where the canonical content is reviewed at a different surface, a fast-merge satisfier in a dogfood-paradox scenario, an emergency hotfix), add an explicit clause in plan §1.4 (or a dedicated §1.5) listing:
   - The wave number.
   - The reason for skipping.
   - Which reviewer axes are deferred (`security`, `performance`, `style`, or `all`).
   - Where the equivalent review IS performed (e.g., "the canonical block IS reviewer-security reviewed at W1 merge against `bin/scaff-lint`'s `CANONICAL_BLOCK` constant; W2 byte-mirrors that constant verbatim").
2. **The merge-commit body** for the skipped wave must reference the authorizing plan section (e.g., "skip authorized per plan §1.5 W2 clause").
3. **If the orchestrator decides mid-flight** to skip without plan authorization, they MUST `/scaff:update-plan` to add the authorization clause **before** running the merge, not after. The update-plan commit precedes the wave-merge commit in `git log`.
4. **qa-analyst at validate stage** flags any wave merge that used `--skip-inline-review` without a corresponding plan-authorization clause as a `should`-severity process-gap finding (this rule's enforcement surface).
5. **Tiny tier** features: skip is the default per implement.md R16; no plan authorization needed because the tier itself is the authorization.

## Example

Authorized skip clause in plan §1.5 (illustrative — what should have been written for W2 of `20260426-fix-commands-source-from-scaff-src`):

```
### §1.5 Inline review skips

W2 (T4 18-file marker sweep) MERGES WITH --skip-inline-review.

Reason: T4 is a mechanical paste of the canonical 12-line resolver block 18 times,
byte-identical across all 18 files. The canonical block is reviewer-style and
reviewer-security reviewed at W1 merge against bin/scaff-lint's CANONICAL_BLOCK
constant (T1 deliverable); T4 byte-mirrors that constant verbatim.

Deferred axes: style, security, performance (all three).

Equivalent review surface: W1 merge of T1 (bin/scaff-lint extension) — the canonical
block IS reviewed there. T4 is a copy operation, not a content-authoring operation.

Lint enforcement: post-W2 merge, `bin/scaff-lint preflight-coverage` asserts
byte-identity of all 18 files against CANONICAL_BLOCK; any drift fails the lint.
```

Merge commit body:

```
Merge T4 (W2): T4: 18 .claude/commands/scaff/*.md — sweep W3 marker block to
canonical $SCAFF_SRC resolver shape

## Reviewer notes

Inline review skipped for this wave per plan §1.5 authorization. Canonical block
reviewed at W1 merge of T1; this commit is a byte-mirror operation enforced by
post-merge lint.
```

This is what the audit trail should look like; what the actual W2 produced (no plan clause + retroactive STATUS line) is the failure mode this memory entry exists to prevent.
