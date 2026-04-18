# 07 — Gap Check: per-project-install

_2026-04-18 · QA-analyst_

## STATUS note
- 2026-04-18 qa-analyst — gap-check complete — verdict NITS, 5 findings (2 drift, 3 notes)

---

## 1. Scope of review

Files read in full: `03-prd.md`, `04-tech.md`, `05-plan.md`, `06-tasks.md`, `STATUS.md`,
`bin/specflow-seed` (1457 LOC), `.claude/skills/specflow-init/SKILL.md`, `.claude/skills/specflow-init/init.sh`,
`test/t39_init_fresh_sandbox.sh` through `test/t50_dogfood_staging_sentinel.sh` (12 test files),
`test/smoke.sh`, `README.md`, `.claude/specflow.manifest`, `settings.json`.

Feature-branch diff stat: 26 files, +5691 lines (net). All commits from W0 through W6 (T21) reviewed.

Key greps run: verb-emission patterns in `bin/specflow-seed`, function-reference counts
for orphan detection, README verb table vs code output, `idempotent-exit` condition
logic, `manifest_tsv` accumulation in `cmd_update`, `cmd_init`, `cmd_migrate`.

---

## 2. PRD R-by-R trace (R1–R13)

**R1 — Copy at a pinned source-repo ref**
Covered-fully. `specflow.manifest` created with `schema_version:1`, `specflow_ref`, per-file SHA map.
AC1.a: bytes verified in t39. AC1.b: ref readable via `awk -F'"' '/"specflow_ref"/'` and confirmed
in live manifest (`94fa3ac...`). AC1.c: `find .claude -type l` returns empty post-init (t39 asserts).

**R2 — `init` seeds fresh consumer**
Covered-fully. t39/t40/t41 cover AC2.a/AC2.b/AC2.c. W2 post-merge hotfix resolved the `write_atomic`
failure-swallowing bug and the idempotent-exit byte-identity issue for AC2.b.

**R3 — Single global artefact**
Covered-fully. `.claude/skills/specflow-init/` is the one global artefact (two files: `SKILL.md` + `init.sh`).
AC3.a: satisfied structurally — manifest's per-file SHA table enables update without source-repo
reachability. AC3.b: t49 asserts `find .claude/skills/specflow-init -type f | wc -l` == 2.

**R4 — Team-memory starts as empty skeleton**
Covered-fully. `plan_copy` `init|migrate` modes synthesize index.md per role + shared/README.md +
shared/index.md. t39 AC4.a asserts no non-index `.md` files. t44 AC4.b asserts update never
walks team-memory.

**R5 — Rules copied fresh per consumer**
Covered-fully. `.claude/rules/` included in `plan_copy` static subtrees. t39 AC5.a asserts
byte-identity. R7 conflict policy covers AC5.b (user-modified rules preserved on update).

**R6 — Closed state enum + classify-before-mutate**
Covered-fully. `classify_copy_target` is pure (no side effects), emits five states matching D4
pseudocode branch-for-branch (comment at `bin/specflow-seed:289-291` confirms the 5-vs-6 note).
`--dry-run` early-return implemented identically in all three commands (AC6.a). One-branch dispatch
table (no fall-through default) per AC6.b. W1 BLOCK security finding (path-traversal on
classify_copy_target + manifest_read) was fixed in T2 retry.

**R7 — Update conflict policy: skip-and-report with backup-before-replace**
Covered-fully. AC7.a covered by t43; AC7.b by t42; AC7.c by t39/t41/t43 (exit codes);
AC7.d by t48 static grep + code review (no `--force` / `rm -rf`). Versioned `.bak` (timestamp
suffix on collision) added via W2 T3 NITS hotfix — exceeds PRD minimum.

**R8 — `update` re-copies at newly-chosen ref**
Covered-with-note — see **Drift D1** below.
AC8.a: verified for the common case (files change between refs → `_CNT_REPLACED > 0` → manifest
advances). Not verified for the edge case where `--to <new-ref>` produces all-`ok` classifications
(content identical between old and new ref). AC8.b: t43 verifies ref NOT advanced on conflict.
AC8.c: t44 (mtime tree stable) + code review (`plan_copy update` explicitly omits team-memory).

**R9 — `migrate` converts single consumer from global-symlink**
Covered-fully. AC9.a: t45 asserts `~/.claude/` symlinks and unrelated marker byte-identical
after migrate (D10 abstention). AC9.b: idempotent re-run tested in t45 step 9.
AC9.c: t46 three-root byte-identity on dry-run. AC9.d: t47 user-modified skip, settings.json
NOT rewired, symlinks UNTOUCHED, exit non-zero.

Note: PRD R9 body text says `migrate` "removes only the ~/.claude/ symlinks that this particular
migration replaced" — this is the D10 N1 body-text note from tech stage. Implementation
correctly follows D10 and AC9.a; R9 body text was identified as needing cleanup (architect
flagged as non-blocking note, no blocker here).

**R10 — This source repo migrated last**
Covered-structurally (per dogfood-paradox pattern; runtime exercise deferred to next feature
after session restart). See **Dogfood-paradox section** below.
AC10.a: t50 was the pre-W6 sentinel. t50 FAILED because no global install existed on this
machine (option B variant) — this is the "third variant" of the dogfood paradox
(no-global-install state vs the expected migrate-from-active-global shape). Structural
markers verified: `bin/claude-symlink install/uninstall/update` still exist and are unchanged.
AC10.b: `specflow.manifest` created at ref `94fa3ac`, `settings.json` rewired to local hooks
(`.bak` produced), global `~/.claude/` symlinks left in place per D10.
AC10.c: structural PASS confirmed; runtime PASS deferred.

**R11 — README documents new flow**
Covered-fully. AC11.a: "Install" section present; describes `init` as first command; no `~/.claude/`
symlink model in primary flow. AC11.b: deprecation banners on `bin/claude-symlink` section and
`bin/specflow-install-hook` section with links to new flow. AC11.c: `grep -l 'migrate' README.md`
and `grep -l -i 'deprecated' README.md` both pass (verified).

**R12 — Conflict-verb vocabulary documented**
Covered-with-note — see **Drift D2** below.
AC12.a: vocabulary table present in README. AC12.b: closed-set claim violated by (a) the
`would-created` vs `would-create` mismatch and (b) `skipped:unknown-state` not in the table.

**R13 — Rule compliance**
Covered-fully. AC13.a: `bash -n bin/specflow-seed` passes; t48 static grep confirms no
`readlink -f`, `realpath`, `jq`, `mapfile`, `rm -rf`, `--force`. AC13.b: all 12 new test
files include mktemp sandbox + case-pattern preflight (t48 is a static test with no HOME
mutation, per its design — correctly exempted). AC13.c: grep confirms no prohibited tokens
in implementation.

---

## 3. Tech D-by-D trace (D1–D12 primary)

| Decision | Status | Note |
|---|---|---|
| D1 — SKILL.md + init.sh under `~/.claude/skills/specflow-init/` | Covered | `cp -R` bootstrap documented in README; 2-file footprint verified in t49 |
| D2 — `bin/specflow-seed` single multi-subcommand script | Covered | 1457 LOC; all three verbs + `--probe` implemented |
| D3 — `specflow.manifest` schema v1 JSON | Covered | Schema v1 with `schema_version`, `specflow_ref`, `source_remote`, `applied_at`, `files` map present in live artifact |
| D4 — Classifier per-file SHA baseline | Covered | D4 pseudocode implemented branch-for-branch; traversal guards added at W1 BLOCK finding |
| D5 — `classify_copy_target` ported from `classify_target` | Covered | Pure function, stdout-only, no side effects |
| D6 — `update --to <ref>` required, no default-HEAD | Covered | `[ -n "$TO_REF" ] || die "--to <ref> required"` at `bin/specflow-seed:784` |
| D7 — Source discovery layered fallback | Covered | arg > env > readlink > die; in all three commands |
| D8 — Hook wiring via `<src>/bin/specflow-install-hook` | Covered | Invoked from `cmd_init` step 10 and `cmd_migrate` step 10; consumer-local paths only |
| D9 — Committed `.claude/` + manifest | Covered | No `.gitignore` additions by init; documented in README |
| D10 — Migrate symlink-teardown abstention | Covered | `cmd_migrate` rewires settings.json only; no write/rm on `$HOME/.claude/`; verified in t45/t47 |
| D11 — Per-file write via write-temp + rename | Covered | `write_atomic` Python3 heredoc; `os.replace` atomic; used in all three commands |
| D12 — Smoke-test harness | Covered | t39–t49 registered; t50 deregistered after T21 per design |

D13–D20 were deferred per architect; none were silently over-expanded.

---

## 4. Drift findings

### Drift D1 (NITS-level): `cmd_update` idempotent-exit does not advance manifest ref when all files already match TO_REF

- **File**: `bin/specflow-seed:1011-1013`
- **R/AC**: R8 AC8.a
- **Description**: The idempotent-exit short-circuit in `cmd_update` (introduced during T7
  as "lesson #3") exits early when `_CNT_CREATED == 0 && _CNT_REPLACED == 0`. This covers
  the intended re-run-at-same-ref case, but it also fires when `--to <new-ref>` produces
  an all-`ok` classification (i.e., source content at `TO_REF` is byte-identical to content
  at the previous ref). In that case the manifest `specflow_ref` is NOT advanced to `TO_REF`,
  violating AC8.a: "After an `update` run with no conflicts, the consumer's recorded ref
  matches the newly-chosen ref."
- **Why not caught by tests**: t42 always synthetically modifies one file (ref-B changes
  architect.md), so `_CNT_REPLACED >= 1` always and the idempotent-exit never fires in tests.
  The all-`ok` edge case is not exercised.
- **Contrast with cmd_init**: `cmd_init`'s idempotent-exit adds a `[ -f manifest ]` guard (T21
  fix) that ensures first-time writes still author the manifest. `cmd_update` does not need
  that guard (manifest is required precondition) but does need a guard against advancing
  past the ref check: `if [ "$TO_REF" = "$previous_ref" ] && ...` would be the correct shape.
- **Severity**: NITS / should. The edge case requires two refs with byte-identical content —
  unusual in practice but violates a stated AC. Does not block common-case operation.

### Drift D2 (NITS-level): README verb table documents `would-created` but code emits `would-create`; `skipped:unknown-state` not in table

- **File A**: `README.md:285` (documents `would-created`)
- **File B**: `bin/specflow-seed:624,898,1171` (emits `would-create`)
- **File C**: `bin/specflow-seed:716,990,1265` (emits `skipped:unknown-state`)
- **R/AC**: R12 AC12.a (every verb in table), R12 AC12.b (no verb outside the documented set)
- **Description**:
  1. The README verb table row reads `` `would-created` / `would-replaced:drifted` / `would-skipped:*` ``.
     The code emits `would-create:` (no trailing `d`). T3's task scope correctly specifies
     `would-create` and the code is internally consistent — the README carries a T20 authoring
     error (T20's task scope also wrote `would-created` in the table template, inheriting the
     discrepancy from the 06-tasks.md verbatim paste).
  2. `skipped:unknown-state` is emitted by all three dispatch tables for the wildcard `*)` arm
     (`bin/specflow-seed:716`, `:990`, `:1265`) but does not appear in the README vocabulary table.
     AC12.b requires the closed set to be documented; this is an omission.
- **Severity**: NITS / should. Both are doc-only corrections; no user-facing behavior is broken
  today because `skipped:unknown-state` only fires if an impossible state leaks through (defensive
  arm) and `would-create` works correctly even though the README names it differently.

---

## 5. NITS accumulation (carried-forward from W0–W5 reviews)

All NITS from wave reviews that were not fixed before merge:

| Wave | Task | Finding | Status | Severity |
|---|---|---|---|---|
| W1 | T2 (retry) | `__probe manifest-roundtrip` `mpath` arg not validated for absolute path (hidden internal verb; low user-facing risk) | Not fixed — merged as NITS | should |
| W3 | T7 | Two WHAT-comments at Step 5/Step 7 banners; numbering gap (Step 3 → Step 5) vs cmd_init 1–10 | Not fixed | should |
| W3 | T10 | `LESSON_MTIME` dead assignment at `test/t44_update_never_touches_team_memory.sh:96` — assigned but never read | Not fixed | should |
| W4 | T11 | Step-banner periods inconsistency in cmd_migrate; WHY-truncation on two comments | Not fixed | should |
| W5 | T15 | `SPECFLOW_SRC` not asserted to be an absolute path in `init.sh` before `exec "$SRC/bin/specflow-seed"` — relative-path input would produce a confusing error | Not fixed | should |
| W5 | T20 | Missing explicit `{#anchor}` IDs on README section headers | Not fixed | advisory |

**N1: `resolve_path` dead-code orphan** (`bin/specflow-seed:69–93`).
Function is defined and ported from `bin/claude-symlink` but is never called in `specflow-seed`.
The three `cmd_*` functions use `(cd "$path" 2>/dev/null && pwd -P)` inline. This is the
dead-code-orphan-after-simplification pattern (team-memory entry): the architect's tech doc
noted resolve_path as a helper to port; the implementation achieved the same result inline.
Recommendation: remove `resolve_path` (lines 66–94) in a follow-up cleanup task.

**Cluster assessment**: the NITS span comment quality, one dead variable in tests, one dead
function in the CLI, and one weak input validation in the skill bootstrap script.
None cluster into a behavioral drift. Collectively they are tech-debt items appropriate for
a post-archive cleanup pass. No individual finding rises to BLOCKED severity.

---

## 6. Post-merge hotfix audit

**W0 NITS hotfix** (`20260418-per-project-install-T1-hotfix`): 5 style comment findings on
`bin/specflow-seed` — comment-restates-what violations. Fix: comment-only edits. Fully
addressed. No residual.

**W2 post-merge hotfix** (`c621fef`): Three bugs fixed:
1. `cmd_init` swallowed `write_atomic` failures (dispatched `created:` without checking pipe
   exit). Fix: pipe-exit check added. Fully addressed in `cmd_init`.
   — Sister-code check: `cmd_update` and `cmd_migrate` received the same fix pattern
   (both use `if cat ... | write_atomic ...; then ... else FAIL ...`). Confirmed by code review.
2. `asdf` + sandbox-HOME broke Python3 shim in t39/t40/t41. Fix: real-HOME copy of
   `.tool-versions` before sandbox. Fully addressed.
3. Idempotent-exit added to `cmd_init` to restore AC2.b byte-identity. Correct for
   `cmd_init`'s re-run-at-same-ref case.
   — Sister-code check: `cmd_update` received the same idempotent-exit shape but WITHOUT the
   manifest-presence guard. This is the source of **Drift D1** above (the guard was added
   only to `cmd_init` and `cmd_migrate` during T21, not to `cmd_update`). The T21 fix
   correctly scoped the guard to the first-time-write problem; `cmd_update` never has the
   first-time problem (manifest required as precondition), but does have the all-`ok`-at-new-ref
   problem that `cmd_init` does not face.

**W3 T9 manifest-path hotfix** (`da2a109`): `t43` used wrong manifest path
(`.spec-workflow/manifest.json`). Fix: corrected to `.claude/specflow.manifest` per D3.
Fully addressed. No residual.

**T21 idempotent-exit fix**: Fixed `cmd_init` and `cmd_migrate` to add
`[ -f "${consumer_root}/.claude/specflow.manifest" ]` guard so first-time-byte-identical runs
(dogfood case: source == consumer) still author the manifest. `cmd_update` was intentionally
not modified here (correct — `cmd_update` requires the manifest as a precondition; first-time
case never applies). However, the all-`ok`-at-new-ref variant is a residual gap (Drift D1).

---

## 7. Dogfood-paradox note

T21 ran as **option B variant**: no pre-existing global install (`~/.claude/agents/specflow`
symlink absent on this machine), so t50 (the pre-W6 staging sentinel that verified AC10.a's
global-install state) failed and was skipped. This is the "no-global-install" variant of the
dogfood paradox.

**Structural satisfaction**: AC10.b is satisfied — `specflow.manifest` created at ref `94fa3ac`,
`settings.json` rewired to local hooks (Stop entry added; SessionStart was already local from
prior session work; `settings.json.bak` produced). D10 abstention trivially holds (no
`~/.claude/` mutations possible when global symlinks don't exist).

**Runtime gap**: R10 AC10.a's "migrate-from-active-global-install" shape was NOT exercised on
this machine. t45 (`t45_migrate_from_global.sh`) sandboxes a pre-staged global install and
does pass, so the code path is tested — but with a fixture, not a live migration from a real
`bin/claude-symlink install` state. This is a **structural-PARTIAL** for R10 AC10.a: the
fixture-based test is GREEN but the live migration from a real global install has not been
exercised. The fix is deferred to the next feature after session restart, per
`shared/dogfood-paradox-third-occurrence.md`'s "next feature after session restart" clause.

**Per `shared/dogfood-paradox-third-occurrence.md`**: runtime PASS on `init`/`update`/`migrate`
against a fresh external consumer is the next-feature verification. This repo's own
`specflow.manifest` + local hooks are the first proof-of-life; fuller runtime exercise
on a second consumer repo confirms correctness.

---

## 8. Extra work

No files or functions added beyond what was called for by any R/AC.
The `__probe` hidden subcommand is explicitly planned in T2 as a TDD harness; it is not
scope creep.
`resolve_path` (lines 66–94 of `bin/specflow-seed`) is a dead-code orphan (never called) and
constitutes minor extra code — addressed as N1 above. Not a blocker.

---

## Verdict: NITS

**Justification**: Two drift findings exist (D1: `cmd_update` AC8.a idempotent-exit ref-advance
gap for the all-`ok`-at-new-ref edge case; D2: README verb table names `would-created` where
code emits `would-create`, and `skipped:unknown-state` is undocumented). Neither blocks correct
operation under the tested scenarios. All 49/49 registered smoke tests pass. The feature's
core contracts (classify-before-mutate, backup-before-replace, D10 abstention, single global
artefact) are correctly implemented. A follow-up cleanup pass addressing D1, D2, and the N1
dead-code orphan is recommended before the next feature that relies on `cmd_update`'s ref-advance
guarantee under adversarial conditions.
