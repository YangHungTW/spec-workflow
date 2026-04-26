# orchestrator — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [set_tier auto-upgrade on security-must finding](set-tier-auto-upgrade-on-security-must-finding.md) — Reviewer security-axis `must` finding during wave review auto-triggers tier upgrade standard→audited via `set_tier`. `set_tier` takes **4** args (dir, tier, role, reason); passing 3 silently no-ops with only a usage banner. Always verify STATUS.md shows the `tier upgrade` note before continuing. Source: 20260422-monitor-ui-polish T18 security review.
- [Defer the `review dispatched` STATUS Notes line to post-merge bookkeeping](status-notes-append-collision-defer-dispatch-log.md) — Orchestrator writing dispatch lines on the parent branch races worktree STATUS.md edits at merge-time; defer the dispatch log to the post-merge bookkeeping commit so STATUS.md has a single writer per wave-window. Eliminates the trailing-region append race regardless of developer compliance. Source: 20260426-chore-scaff-plan-chore-aware T2 single-task-wave merge conflict.
