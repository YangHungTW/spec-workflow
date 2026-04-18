# 08-verify — per-project-install

_2026-04-18 · QA-tester_

## STATUS note
- 2026-04-18 QA-tester — verify done: PASS

---

## 1. Scope

Verification run on 2026-04-18 against HEAD (post-gap-fix commit 60237a2 included).
Platform: macOS Darwin 25.3.0 / bash 3.2 / Python 3 available via asdf.
All tests run as standalone invocations and via `bash test/smoke.sh`.
Dogfood state spot-checked via `bin/specflow-seed migrate --dry-run --from . --ref HEAD`.
This repo is operating as its own per-project consumer (option-B variant per T21/STATUS.md).

---

## 2. Per-R verification

### R1 — Copy at a pinned source-repo ref

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC1.a — all consumer files are regular files, byte-identical to source at captured ref | `test/t39_init_fresh_sandbox.sh` | PASS | exit 0; `summary: created=58 already=0 replaced=0 skipped=0` |
| AC1.b — ref is machine-readable, real commit SHA | manifest read: `python3 -c "import json,sys; d=json.load(sys.stdin); print('specflow_ref:', d['specflow_ref'])"` on `.claude/specflow.manifest` | PASS | `specflow_ref: 94fa3ac48b52e0d45f21c0b02903cd1c80a1afae` |
| AC1.c — no path under consumer `.claude/` is a symlink | `test/t39_init_fresh_sandbox.sh` (asserts `find .claude -type l` is empty) | PASS | exit 0 |

### R2 — `init` seeds a fresh consumer repo

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC2.a — fresh init exits 0, produces self-contained install, settings.json wired | `test/t39_init_fresh_sandbox.sh` | PASS | exit 0; `summary: created=58` |
| AC2.b — second init on same ref reports `already` for every file, byte-identical state | `test/t40_init_idempotent.sh` | PASS | exit 0 |
| AC2.c — pre-existing conflicting paths go through classifier, never silently overwritten | `test/t41_init_preserves_foreign.sh` | PASS | exit 0 |

### R3 — `init` is the single global entry point

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC3.a — deleting source repo clone does not break consumer session | structural: t39 produces all regular files (no source-relative symlinks); manifest SHA table enables offline update | PASS (structural) | t39 exit 0; AC1.c confirmed |
| AC3.b — init skill footprint outside consumer is enumerable and bounded | `test/t49_init_skill_bootstrap.sh` (asserts `find .claude/skills/specflow-init -type f \| wc -l` == 2) | PASS | exit 0 |

### R4 — Team-memory starts as an empty skeleton

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC4.a — post-init team-memory shows only role dirs + index files, no lesson content | `test/t39_init_fresh_sandbox.sh` (asserts no non-index `.md` files in team-memory) | PASS | exit 0 |
| AC4.b — no flow writes to source-repo or `~/.claude/team-memory/` | `test/t44_update_never_touches_team_memory.sh` | PASS | exit 0 |

### R5 — Rules copied fresh per consumer

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC5.a — `.claude/rules/` exists with same file tree as source, byte-identical | `test/t39_init_fresh_sandbox.sh` (byte-identity check on rules subtree) | PASS | exit 0; rules files listed in `created:` output |
| AC5.b — user edits to rules preserved across update | `test/t41_init_preserves_foreign.sh` + R7 conflict policy tested in t43 | PASS | both tests exit 0 |

### R6 — Closed state enum + classify-before-mutate

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC6.a — `--dry-run` produces full plan without touching any file; hash-verified | `test/t46_migrate_dry_run.sh` (three-root hash identity) | PASS | exit 0 |
| AC6.b — dispatcher takes exactly one branch per state; no fall-through silent mutation | `test/t48_seed_rule_compliance.sh` (static grep for prohibited tokens; no `--force`, no `rm -rf`) | PASS | exit 0 |

### R7 — Update conflict policy: skip-and-report with backup-before-replace

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC7.a — hand-edited file: `update` exits non-zero, reports `skipped:user-modified`, file unchanged | `test/t43_update_user_modified.sh` | PASS | exit 0 |
| AC7.b — drifted-ours file: `.bak` written, file atomically replaced, reports `replaced:drifted` | `test/t42_update_no_conflict.sh` | PASS | exit 0; bak content == pre-update bytes; consumer hash == ref-B source hash |
| AC7.c — exit-code contract: 0 iff every path converged | t39/t41/t42/t43 | PASS | non-zero on conflict (t43), zero on clean (t42) |
| AC7.d — no `--force`, `rm -rf`, or unconditional overwrite in any flow | `test/t48_seed_rule_compliance.sh` (grep) | PASS | exit 0 |

### R8 — `update` re-copies at newly-chosen ref

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC8.a — after clean update, recorded ref = newly-chosen ref | `test/t42_update_no_conflict.sh` (line 188: `MANIFEST_REF != REF_B` assertion) | PASS | exit 0; D1 fix confirmed: idempotent-exit now guarded by `previous_ref = TO_REF` check (bin/specflow-seed:985) — only short-circuits when same ref, not when different-ref produces all-ok |
| AC8.b — after update with conflict, recorded ref unchanged, exit non-zero | `test/t43_update_user_modified.sh` | PASS | exit 0 |
| AC8.c — no team-memory path read/written/deleted during update | `test/t44_update_never_touches_team_memory.sh` | PASS | exit 0 |

### R9 — `migrate` converts single consumer from global-symlink model

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC9.a — migrate produces post-init shape; removes only corresponding `~/.claude/` symlinks; unrelated `~/.claude/` content unaffected | `test/t45_migrate_from_global.sh` | PASS | exit 0 |
| AC9.b — re-running migrate exits 0, all-`already`, byte-identical state | `test/t45_migrate_from_global.sh` step 9 | PASS | exit 0 |
| AC9.c — `migrate --dry-run` hash-identical before/after on three roots | `test/t46_migrate_dry_run.sh` | PASS | exit 0 |
| AC9.d — user-modified destination: migrate skips, reports `skipped:user-modified`, symlink untouched, exits non-zero | `test/t47_migrate_user_modified.sh` | PASS | exit 0 |

### R10 — This source repo migrated last (dogfood-paradox)

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC10.a — `bin/claude-symlink install/uninstall/update` still exit 0 with pre-feature contract; `~/.claude/` symlinks still resolve into source repo | N/A (option-B variant) | N/A | This machine had no pre-existing global install; t50 was deregistered from smoke.sh per T21 design. `bin/claude-symlink` scripts exist and are structurally intact (t38 references claude-symlink; `bash -n bin/claude-symlink` exits 0). The "migrate-from-active-global" runtime path is covered by fixture-based t45; live verification deferred to next feature after session restart per `shared/dogfood-paradox-third-occurrence.md`. |
| AC10.b — final task runs migrate; removes corresponding `~/.claude/` symlinks; repo is self-contained | verified via STATUS.md + manifest | PASS (structural) | `.claude/specflow.manifest` at ref `94fa3ac...`; `settings.json` wired to local hooks (`.bak` present); D10 abstention holds (no `~/.claude/` mutations when no global install exists). |
| AC10.c — verify stage distinguishes structural vs runtime PASS per dogfood-paradox pattern | this document | PASS (structural) | Structural PASS is gate for archive; runtime PASS deferred to next feature after session restart. |

### R11 — README documents new flow and deprecates old one

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC11.a — README has top-level "Install" section describing `init` as first command; no `~/.claude/` symlink model in primary flow | `grep -n "Install" README.md` | PASS | `## Install` at line 5; describes `cp -R .claude/skills/specflow-init ~/.claude/skills/` (one-time global bootstrap) then `/specflow-init` as first consumer command |
| AC11.b — `bin/claude-symlink` and `bin/specflow-install-hook` sections carry deprecation notice with link to `migrate` | `grep -n "Deprecated" README.md` | PASS | Lines 153 and 173 both carry `> **Deprecated** —` notices with `migrate` pointer |
| AC11.c — `grep -l "migrate"` and `grep -l "deprecated"` find `README.md`; init command surface appears verbatim | grep checks | PASS | `migrate` at line 60; `deprecated` (case-insensitive) at lines 153, 173 |

### R12 — Conflict-verb vocabulary documented

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC12.a — every verb emitted by any flow appears in verb table with explanation | grep for each verb against `README.md` | PASS | All verified: `created`, `already`, `replaced:drifted`, `skipped:user-modified`, `skipped:real-file-conflict`, `skipped:foreign`, `skipped:unknown-state`, `would-create`, `would-replace:drifted`, `would-skip` — all found. D2 fix confirmed: README now has `would-create` (not `would-created`) and `skipped:unknown-state`. |
| AC12.b — no flow emits a verb not in the documented closed set | `grep -n "would-created"` returns nothing; `grep -n "would-create\b"` shows README uses correct form | PASS | `grep -n "would-created" README.md` returns 0 lines; code emits `would-create:` at `bin/specflow-seed:624,898,1171` consistent with README. |

### R13 — Rule compliance

| AC | Test / check | Result | Evidence |
|---|---|---|---|
| AC13.a — all bash scripts pass `bash -n`; no `readlink -f`, `realpath`, `jq`, `mapfile` | `test/t48_seed_rule_compliance.sh` (static grep) | PASS | exit 0 |
| AC13.b — all test scripts that invoke flows use mktemp sandbox + preflight pattern | `test/t48_seed_rule_compliance.sh` (static grep over test files) | PASS | exit 0 |
| AC13.c — no `rm -rf`, `--force`, or unconditional overwrite in any flow | `test/t48_seed_rule_compliance.sh` (static grep) | PASS | exit 0 |

---

## 3. Smoke aggregate

```
bash test/smoke.sh
smoke: PASS (49/49)
```

All 49 registered tests pass. t50 (`t50_dogfood_staging_sentinel.sh`) was intentionally deregistered from smoke.sh during T21 (option-B variant; no pre-existing global install on this machine).

---

## 4. Dogfood state spot-check

```
bin/specflow-seed migrate --dry-run --from . --ref HEAD
# → 58 × would-skip:already lines (all managed files already match HEAD)
# → summary: would-create=0 would-replace=0 would-skip=58 exit=0
exit: 0
```

This repo is its own per-project consumer. Dry-run shows a clean idempotent state: no files would be created or replaced, all 58 managed paths report `already`. Exit 0 as required.

---

## 5. Gap-fix verification (D1 / D2 / N1)

All three gap-check findings resolved in commit 60237a2:

**D1 (R8 AC8.a ref-advance on zero-mutation run):**
`bin/specflow-seed:983–988` idempotent-exit now guarded by `&& [ "$previous_ref" = "$TO_REF" ]` — fires only when the same ref is re-requested, not when a different ref happens to produce all-`ok` classifications.
Directly tested: t42 line 188 asserts `MANIFEST_REF = REF_B` after a cross-ref update. PASS.

**D2 (R12 verb mismatch `would-created` → `would-create` + `skipped:unknown-state` undocumented):**
`README.md:286` now reads `would-create` (not `would-created`). `skipped:unknown-state` appears in the verb table.
Directly tested: all-verb grep — both found. PASS.

**N1 (`resolve_path` dead-code orphan):**
`grep "resolve_path" bin/specflow-seed` returns empty. Function removed. PASS.

---

## Verdict: PASS

All 13 requirements (R1–R13) verified. R10 AC10.a is N/A (option-B dogfood variant — no pre-existing global install on this machine; fixture-based t45 covers the code path; live runtime exercise deferred to next feature after session restart per `shared/dogfood-paradox-third-occurrence.md`). No FAIL findings.
