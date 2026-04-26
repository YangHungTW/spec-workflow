# Request

## Source

**Source**:
- type: description
- value: slash-command preambles source bin/* libraries from $REPO_ROOT (consumer), but bin/* only lives in the source repo — consumers init'd via scaff-seed have no bin/ so /scaff:next fails with 'No such file or directory: bin/scaff-tier'; pre-commit shim and W3 marker block (preflight.md reference) have the same flaw. Fix: command preambles resolve from $SCAFF_SRC (via the existing readlink ~/.claude/agents/scaff pattern), not $REPO_ROOT — thin-consumer architecture decision (option B from 20260426-fix-init-missing-preflight-files post-validate)

## Context

This is the architectural follow-up to the just-archived parent bug `20260426-fix-init-missing-preflight-files` (now at `.specaffold/archive/20260426-fix-init-missing-preflight-files/`). At validate of the parent, runtime exploration in a consumer repo (`llm-wiki`) revealed the deeper architectural issue: it is not just `config.yml` + `preflight.md` missing — the entire `bin/*` directory (scaff-tier, scaff-stage-matrix, scaff-lint, scaff-aggregate-verdicts, scaff-seed itself, etc.) is also not in scaff-seed's manifest.

User decision (architectural): **option B = thin consumer**. Rather than expand scaff-seed's manifest to ship `bin/*` into every consumer (option A: self-contained), commands resolve dependencies via `$SCAFF_SRC` — the source-repo path already established by the user-global symlink (`~/.claude/agents/scaff` -> source). Consumer repos stay minimal: only project state (`.specaffold/config.yml`, `.specaffold/features/`); everything tool-related stays in source and is referenced by absolute path resolved at run time.

### Surfaces affected

1. **Slash-command preambles** — all 18 files in `.claude/commands/scaff/*.md` source `$REPO_ROOT/bin/scaff-*`. In a consumer this resolves to a missing path.
2. **W3 marker block** — same 18 files reference `.specaffold/preflight.md` by relative path. Consumer has no such file (or has a stale copy from the parent bug's plan_copy entry).
3. **Pre-commit shim** — `bin/scaff-seed`'s heredoc emits `bin/scaff-lint scan-staged && bin/scaff-lint preflight-coverage` as relative paths. Hook fires from consumer repo's git root -> `bin/` does not exist.

### Severity

**High** — every consumer repo that has been `/scaff-init`'d cannot use scaff. The just-archived parent bug fixed only one symptom (`config.yml`); this is the broader architectural fix that completes the B-world thin-consumer model.

### User-recommended workaround (until this lands)

Symlink `bin/` and `.specaffold/preflight.md` from source into the consumer.

### Memory entries pulled

- `shared/orchestrator-rider-commit-recovery.md` — applies if validate-stage commits drift across parallel branches.
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md` — applicable: this feature ships the architectural other-half of the just-archived parent bug; Summary in PRD calls out the pairing.
- `pm/ac-must-verify-existing-baseline.md` — applies: AC2 / AC3 cite cross-file parity ("all 18 files"); PRD anchors on the canonical pattern in one file then asserts sweep-wide parity.
- `qa-analyst/wiring-trace-ends-at-user-goal.md` — surfaced the gap; informs R6 / AC8 (assistant-not-in-loop sandbox test).
