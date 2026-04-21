# architect — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Aggregator as classifier — reduce parallel verdicts by severity max](aggregator-as-classifier.md) — Reducing N parallel agent verdicts to one outcome is a severity max-reduce classifier; the same classify-before-mutate discipline applies to agent output reduction.
- [Opt-out bypass flag — STATUS Notes trace required on use](opt-out-bypass-trace-required.md) — Any safety-gate bypass flag (--skip-X, --force, --no-verify) must append a STATUS Notes entry when used; silent bypasses create audit black holes.
- [Reviewer verdict wire format — pure-markdown key:value footer](reviewer-verdict-wire-format.md) — Agent→orchestrator structured output uses a pure-markdown `key: value` footer, not a JSON codefence; grep-parseable, malformed = fail-loud, keeps agent prompts human-readable.
- [Scope extension — minimal diff, not re-taxonomy](scope-extension-minimal-diff.md) — Extend a closed enum (scope, severity, state) by appending one value; never re-cut the taxonomy to accommodate one new case.
- [Tier auto-upgrade on security-must is a wave-merge-time boundary check](tier-auto-upgrade-on-security-must-is-a-wave-merge-time-boundary-check.md) — Tier auto-upgrade standard→audited must fire at wave-verdict-aggregation time, not at plan (too early) or archive (too late). First observed clean in-flight upgrade: `20260420-flow-monitor-control-plane` W2 on T109/T110 security-must.
- [Setup-hook wiring commitment must be an explicit plan task](setup-hook-wired-commitment-must-be-explicit-plan-task.md) — Tech D-ids promising "called from setup hook" must mark `**Wiring task**` so the TPM scopes the hook edit; otherwise the function lands as a dead-code orphan (observed: `purge_stale_temp_files()` in `20260420-flow-monitor-control-plane`).
