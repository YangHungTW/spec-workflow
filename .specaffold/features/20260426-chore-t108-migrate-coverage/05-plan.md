# Plan — chore: t108 migrate-path coverage

- **Feature**: `20260426-chore-t108-migrate-coverage`
- **Stage**: plan
- **Author**: orchestrator (hand-written; chore-tiny short-circuit — see §1.3)
- **Date**: 2026-04-26
- **Tier**: tiny
- **Work-type**: chore

PRD: `03-prd.md` (chore checklist, 2 items rolled up).

---

## 1. Approach

### 1.1 Scope

Single mechanical edit: append an A5 assertion section to `test/t108_precommit_preflight_wiring.sh` covering `bin/scaff-seed migrate` (cmd_migrate path), parallel to the existing A2 section that covers `cmd_init`. No production code touched; no other test touched; no docs touched.

### 1.2 Why one task, not two

The chore PRD lists 2 checklist items (add A5 + confirm A5 mirrors A2). They are not separable — adding A5 IS confirming-it-mirrors-A2, because the assertion shape is the only output. Splitting into two tasks would create a same-file dependency with no parallelism gain. Folded into one task `T1`.

### 1.3 Chore-tiny short-circuit (why no Architect/TPM dispatch)

The stage matrix for `chore × tiny` reports: `design = skipped`, `tech = skipped`, `plan = optional`. The `/scaff:plan` command hard-requires `04-tech.md` (its step 1: "Require 03-prd.md AND 04-tech.md exist"), but tech is matrix-skipped on this tier. Rather than (a) error out at /scaff:plan dispatch or (b) have TPM short-circuit on missing prereq, the orchestrator hand-writes this minimal plan from the chore PRD's checklist. This file exists primarily to satisfy `/scaff:implement`'s contract (it requires `05-plan.md` with at least one `- [ ]` line).

Surfaced as a finding for archive retro: `/scaff:plan` should either accept missing `04-tech.md` when work-type=chore, or `/scaff:implement` should also accept reading the checklist from `03-prd.md` directly when work-type=chore-tiny. Until that's reconciled, the chore-tiny pathway needs this hand-written plan stub.

### 1.4 Wave shape

Single wave (W1), single task (T1). No inline review (R16 default for tier=tiny). No worktree; --serial mode acceptable, or a single chore branch.

---

## 2. Tasks

## T1 — Append A5 section to test/t108_precommit_preflight_wiring.sh covering scaff-seed migrate path

- **Milestone**: M1
- **Requirements**: chore PRD checklist items 1 + 2 (folded)
- **Decisions**: chore PRD §Scope
- **Scope**: Append a new A5 assertion section to `test/t108_precommit_preflight_wiring.sh`, parallel in shape to the existing A2 section. The A5 section must:
  1. Build a fresh sandboxed consumer repo via `mktemp -d` (mirror A2's `make_consumer`-style setup; reuse the helper or copy the relevant lines — duplication is in scope per chore PRD §Out-of-scope).
  2. Run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" migrate --from "$REPO_ROOT" --ref HEAD)`.
  3. Assert `[ -x "$CONSUMER/.git/hooks/pre-commit" ]`.
  4. Assert `grep -F 'scaff-lint scan-staged' "$CONSUMER/.git/hooks/pre-commit"` matches.
  5. Assert `grep -F 'scaff-lint preflight-coverage' "$CONSUMER/.git/hooks/pre-commit"` matches.
  6. Use a clear section header convention matching A2's existing style (e.g. `# A5 — scaff-seed migrate produces hook with both invocations`).
  Bash 3.2 / BSD-portable. English-only (per `.claude/rules/common/language-preferences.md`).
- **Deliverables**: `test/t108_precommit_preflight_wiring.sh` (edit; appended A5 block; no other content modified).
- **Verify**:
  - `bash -n test/t108_precommit_preflight_wiring.sh` exits 0.
  - `bash test/t108_precommit_preflight_wiring.sh` exits 0 with `PASS: t108` final line.
  - `grep -E '^# A5\b|A5:|A5 ' test/t108_precommit_preflight_wiring.sh` matches at least one line.
  - `grep -F 'scaff-seed' test/t108_precommit_preflight_wiring.sh | grep -F 'migrate'` matches.
  - In the diff: `git diff --stat HEAD~1 -- test/t108_precommit_preflight_wiring.sh` shows additions only (no deletions to existing assertions).
- **Depends on**: —
- **Parallel-safe-with**: — (single task in single wave)
- [x]

---

## 3. Risks

1. **A2 helper reuse vs duplicate** — A2 may use a `make_consumer` helper function. If reusing, ensure A5's invocation matches the helper's contract. If duplicating, keep the duplicate small and don't refactor (out of scope per chore PRD).
2. **`scaff-seed migrate` semantics** — `migrate` requires a pre-existing scaff install in the consumer repo (it migrates an old install to the current shape). A2 uses `init` which creates a fresh install. A5's `make_consumer` may need to first `init`, then `migrate`, to be valid input — read `bin/scaff-seed` to confirm whether `migrate` works on a vanilla repo or requires a prior `init`. If the pre-init step is non-trivial, the developer adjusts the test setup accordingly.

---

## 4. Open questions

None.
