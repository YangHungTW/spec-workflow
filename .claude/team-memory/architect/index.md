# architect — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Shell portability — no GNU readlink on macOS](shell-portability-readlink.md) — macOS bash 3.2 has no `readlink -f`; write a pure-bash `resolve_path` helper instead of depending on GNU coreutils.
- [No --force by default on user-owned paths](no-force-by-default.md) — Tools that touch user-owned paths default to report-and-skip on conflict; no `--force` in v1.
- [Script location convention — bin vs scripts](script-location-convention.md) — Repo executables go in `bin/<name>` (no extension, exec bit); `scripts/` is for dev-time helpers.
- [Classification before mutation](classification-before-mutation.md) — Filesystem tools that can destroy data — classify every target into a closed enum first, then dispatch via a table. Never mutate inside the classifier.
- [Safe mutation of user-owned config files](settings-json-safe-mutation.md) — Any tool modifying user-owned config (settings.json, .gitconfig, package.json fragments) must read-merge-write with atomic swap and backup; never `cat >`, never heredoc-clobber.
- [Hook fail-safe pattern](hook-fail-safe-pattern.md) — Hooks gating session/process lifecycle must `set +e`, trap signals to exit 0, stderr-only diagnostics, never block startup; a broken hook degrades every subsequent session opaquely.
- [Reviewer verdict wire format — pure-markdown key:value footer](reviewer-verdict-wire-format.md) — Agent→orchestrator structured output uses a pure-markdown `key: value` footer, not a JSON codefence; grep-parseable, malformed = fail-loud, keeps agent prompts human-readable.
- [Aggregator as classifier — reduce parallel verdicts by severity max](aggregator-as-classifier.md) — Reducing N parallel agent verdicts to one outcome is a severity max-reduce classifier; the same classify-before-mutate discipline applies to agent output reduction.
- [Scope extension — minimal diff, not re-taxonomy](scope-extension-minimal-diff.md) — Extend a closed enum (scope, severity, state) by appending one value; never re-cut the taxonomy to accommodate one new case.
- [Opt-out bypass flag — STATUS Notes trace required on use](opt-out-bypass-trace-required.md) — Any safety-gate bypass flag (--skip-X, --force, --no-verify) must append a STATUS Notes entry when used; silent bypasses create audit black holes.
- [Byte-identical refactor gate](byte-identical-refactor-gate.md) — Pure-refactor tasks (zero behavior change) use byte-identical before/after diff as the acceptance gate — NOT "tests still pass".
