# pm — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [ac-must-verify-existing-baseline](ac-must-verify-existing-baseline.md) — 
- [housekeeping-sweep-threshold](housekeeping-sweep-threshold.md) — 
- [B1/B2 split validates blast radius but leaves functional gap](b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md) — When splitting a user's one-sentence request into B1/B2 by blast radius (e.g. read-only vs control-plane), PM must acknowledge B1 alone ships only half the promise and pre-commit the B2 slug in the B1 archive notes.
- [PRD §Scope "mirror of <existing-block>" must itemise that block's full assertion set in §Checklist](scope-mirror-of-X-must-itemize-X-in-checklist.md) — When PRD §Scope says "mirror of A2c", §Checklist (binding text) must enumerate every assertion the referenced block makes; Developer writes to the checklist, not the prose, so partial-mirror gaps become should-class drift at validate. Source: 20260426-chore-t114-migrate-coverage analyst Finding 1.
- [PRD acceptance must scope to the helper, not "anywhere" — upstream callers may defeat literal contracts](prd-acceptance-must-account-for-upstream-side-effects.md) — When writing AC for a fix inside a helper, scope the quantifier to that helper's own execution. "no .bak written anywhere" is structurally false if any upstream caller has its own atomic-write-with-backup discipline. Trace upstream callers first; prefer "the helper does not write X on no-op" over "X is never written". Source: 20260426-fix-install-hook-wrong-path validate F1 (AC3 unachievable as written; Step 7 unconditionally writes .bak).
