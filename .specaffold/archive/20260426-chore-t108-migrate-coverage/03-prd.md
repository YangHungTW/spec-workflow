# PRD — chore: t108 migrate-path coverage

## Summary

Extend `test/t108_precommit_preflight_wiring.sh` with an A5 section that asserts `bin/scaff-seed migrate` (the `cmd_migrate` path) emits a pre-commit hook containing both `scan-staged` and `preflight-coverage` invocations — parallel in shape to the existing A2 section that covers `cmd_init`.

## Scope

- File touched: `test/t108_precommit_preflight_wiring.sh` only.
- Add a new assertion section labelled `A5` immediately after A2 (or in the section ordering convention already used in the file).
- A5 must:
  - Build a sandboxed consumer repo via `mktemp -d` (mirror A2's `make_consumer`-style setup; reuse the helper or a fresh sandbox at the author's discretion — both are in scope).
  - Run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" migrate --from "$REPO_ROOT" --ref HEAD)`.
  - Assert: `[ -x "$CONSUMER/.git/hooks/pre-commit" ]`.
  - Assert: `grep -F 'scaff-lint scan-staged' "$CONSUMER/.git/hooks/pre-commit"` matches.
  - Assert: `grep -F 'scaff-lint preflight-coverage' "$CONSUMER/.git/hooks/pre-commit"` matches.

## Reason

The W2 fixup brought `cmd_migrate`'s heredoc into byte-identical alignment with `cmd_init`, so runtime is currently correct. The risk is regression on the next refactor of `bin/scaff-seed`: a test gap that survives one merge becomes invisible on the next. Closing the gap now (one mechanical edit) is cheaper than after a regression ships. Discipline source: `.claude/team-memory/qa-analyst/partial-wiring-trace-every-entry-point.md` — when one shared template is emitted from N≥2 call sites, every emit site needs its own test path.

## Checklist

- [ ] Add A5 section to `test/t108_precommit_preflight_wiring.sh` covering the `scaff-seed migrate` path (parallel to A2) — verify: `grep -E '^# A5\b|A5:' test/t108_precommit_preflight_wiring.sh` matches; `grep -F 'scaff-seed' test/t108_precommit_preflight_wiring.sh | grep -F 'migrate'` matches.
- [ ] Confirm A5 mirrors A2's assertion shape (sandboxed consumer + `scan-staged` grep + `preflight-coverage` grep) — verify: within the A5 block, `grep -F 'scan-staged'` and `grep -F 'preflight-coverage'` both match; `bash test/t108_precommit_preflight_wiring.sh` exits 0 with a `PASS: t108` line.

## Verify assertions

Rolled-up commands a reviewer can run end-to-end:

```bash
# Test passes, including the new migrate-path assertion
bash test/t108_precommit_preflight_wiring.sh
# expect: exit 0; final line includes "PASS: t108"

# A5 section is present and exercises the migrate path
grep -E '^# A5\b|A5:' test/t108_precommit_preflight_wiring.sh
grep -F 'scaff-seed' test/t108_precommit_preflight_wiring.sh | grep -F 'migrate'

# Both shim invocations are asserted in the migrate path
grep -F 'scan-staged' test/t108_precommit_preflight_wiring.sh
grep -F 'preflight-coverage' test/t108_precommit_preflight_wiring.sh
```

## Out-of-scope

- Refactoring `t108` to share a `make_consumer` helper between A2 and A5 (defer; duplication is bounded).
- Splitting A5 into a separate `t108_migrate.sh` file (single-section addition only).
- Coverage for other `bin/scaff-seed` subcommands (`update`, etc.) — only `migrate` is in scope here.

## Team memory

- none apply because this is a tiny mechanical test-coverage extension; no PM-tier memory entry matches the shape of "add a parallel assertion section".
