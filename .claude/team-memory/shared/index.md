# shared — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Dogfood paradox — structural verify during bootstrap, runtime exercise next feature](dogfood-paradox-third-occurrence.md) — Features that deliver the tool they would themselves use need structural-only verification; live runtime exercise happens on the next feature.
- [STATUS Notes rule requires enforcement, not just documentation](status-notes-rule-requires-enforcement-not-just-documentation.md) — "Every role appends one STATUS Notes line per action" only works when a hook or reviewer enforces it; recurring gap across ≥3 features. Escalate to enforcement rather than reminding harder.
- [CSS classname rename requires consumer grep](css-classname-rename-requires-consumer-grep.md) — CSS selectors and `className` attributes are both untyped strings; neither side compiler-checks the other. Rename either side → grep the old classname across the repo before merge. Centralise classnames as TS constants where feasible. Source: 20260422-monitor-ui-polish AC17 italic never rendered because stylesheet rule and component class disagreed silently.
- [Auto-classify argv by pattern cascade — URL → ticket-id → fallback description](auto-classify-argv-by-pattern-cascade.md) — Polymorphic positional args (URL / ticket-id / free-text) classify via a deterministic specificity-ordered cascade at the entry point; never ask the user to disambiguate. Reusable shape across `/scaff:bug` and other argv-polymorphic commands. Source: 20260424-entry-type-split D1.
- [Cross-feature commits leak into a feature branch](cross-feature-commits-leak-into-feature-branch.md) — Branch-vs-plan deliverables diff at validate / pre-archive. Catch sibling-feature commits that hitchhiked via worktree reuse before the merge-to-main lands them under the wrong feature.
- [Rider-commit recovery — orchestrator commits to wrong parallel branch](orchestrator-rider-commit-recovery.md) — When an orchestrator accidentally commits to a parallel feature's branch (multi-terminal sessions on one checkout), do NOT cherry-pick or reset; let the errant commit ride forward and annotate the merge `(carries <other-feature> commits as riders)`. Both branches' work lands on main without history rewrite. Source: 20260426-fix-init-missing-preflight-files validate commit 6cf2b76.
