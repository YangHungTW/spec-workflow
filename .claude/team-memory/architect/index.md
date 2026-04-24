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
- [Self-referencing assertion script — must self-allow-list](self-referencing-assertion-script-allow-list.md) — A script that greps for forbidden literals (e.g. `test/t_grep_allowlist.sh` with pattern `specflow|spec-workflow` in its source) will self-match; add the script to its own allow-list from day-one and document the load-bearing self-entry in the header. Source: 20260421-rename-to-specaffold T23.
- [.claude/commands/scaff/ recursively harvests every .md as a slash command — colocated templates forbidden](commands-harvest-scope-forbids-non-command-md.md) — Claude Code session-start auto-registers every `.md` under `.claude/commands/scaff/` (recursively) as a slash command; non-command markdown (templates, fragments) MUST live elsewhere — default `.specaffold/<purpose>-templates/`. Source: 20260424-entry-type-split W1 harvest leak.
