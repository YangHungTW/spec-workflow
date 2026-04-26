# Validate: 20260426-fix-commands-source-from-scaff-src
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: BLOCK
Findings: 1 must (`bash-32-portability` printf bug at test/t113 lines 95/124/154 — flagged by both axes), 5 should (PRD AC2 overclaim, t113 A4 sandbox/asdf interaction, W2 skip-inline-review process gap, T3 helper-vs-plan-verify drift, t113 missing A7 assertion)

The single `must` finding is the only blocking item. The five `should` findings are advisory; the implementation is functionally correct (AC1, AC3, AC5, AC6, AC7 all PASS via subprocess evidence; AC2 PASSes its first verifiable clause; AC4 PASSes its structural code-inspection check; AC8 evidence is gated by the same printf bug).

## Tester axis

## Team memory

Applied entries:
- `~/.claude/team-memory/qa-tester/sandbox-home-preflight-pattern.md` — applied: verified t113 correctly builds sandbox, exports HOME to sandbox, registers trap, and has preflight case assertion at lines 32–42. Pattern followed correctly by the test author.
- `~/.claude/team-memory/shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds.md` — applied: this feature has `has-ui: false`, so the runtime-walkthrough requirement does not apply. Structural + subprocess test evidence is the appropriate verification surface.
- `/Users/yanghungtw/Tools/specaffold/.claude/team-memory/shared/cross-feature-commits-leak-into-feature-branch.md` — the 23 files changed are all within this feature's declared scope (18 command files + bin/scaff-lint + bin/scaff-seed + test/t113 + feature docs). No cross-feature leakage detected.
- `/Users/yanghungtw/Tools/specaffold/.claude/team-memory/qa-tester/prd-ac-wording-superseded-by-tech-decision.md` — applied to AC2 second check: plan §1.2/T4 scope explicitly says "NOT all 18 — only files that source bin/ get the rewrite", superseding the PRD's "18 paths" claim. Marked PARTIAL per the rule.

---

## AC Walkthrough

### AC1 — Resolver resolves correctly from (a) env-var override, (b) readlink symlink fallback, (c) fails loudly exit 65

**Check method:** Patched t113 run from `/Users/yanghungtw/Tools/specaffold/test/` (patch replaces the 3 broken `printf '---'` lines with `printf '%s\n' '---...'` to isolate the AC1 logic from the bash 3.2 printf bug).

```
PASS: A1a: resolver exited 0
PASS: A1a: SCAFF_SRC resolved to REPO_ROOT (/Users/yanghungtw/Tools/specaffold)
PASS: A1b: resolver exited 0
PASS: A1b: SCAFF_SRC resolved to REPO_ROOT via symlink
PASS: A1c: resolver exited 65 (EX_DATAERR)
PASS: A1c: stderr contains 'cannot resolve SCAFF_SRC'
PASS: A1c: stderr contains 'claude-symlink install'
PASS: A1c: no stdout output on failure
```

**Verdict: PASS** (all three resolver tiers verified via subprocess invocation)

---

### AC2 — All 18 command files' preambles source from `$SCAFF_SRC/bin/scaff-*`, not `$REPO_ROOT/bin/scaff-*`

**Check 1 (authoritative — PRD's first verifiable):**
```
$ grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md
(empty — exit 1)
```
PASS.

**Check 2 (PRD's second verifiable: "returns 18 paths"):**
```
$ grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md
archive.md, next.md, implement.md
(3 files, not 18)
```
PARTIAL. Plan §1.2 and T4 scope both explicitly state "NOT all 18 — only files that source bin/ get the rewrite". The developer re-ran the grep at T4 dispatch and correctly found 3 (not the plan's original estimate of 5 — review.md and validate.md never had `source "$REPO_ROOT/bin/scaff-"` statements). The functional goal is met. The "18 paths" in AC2 is a PRD authoring error superseded by plan T4 scope language.

**Verdict: PARTIAL** (first check passes; second check literal count wrong; superseded by plan T4 scope language citing "NOT all 18")

---

### AC3 — All 18 command files' W3 marker blocks reference preflight body via `$SCAFF_SRC`

```
$ grep -l 'SCAFF_SRC/.specaffold/preflight.md' .claude/commands/scaff/*.md | wc -l
18
```

PASS. All 18 files carry `Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.`

**Verdict: PASS**

---

### AC4 — `bin/scaff-seed`'s pre-commit shim emits a hook that resolves `$SCAFF_SRC` at run time

**Structural checks (code inspection):**
- `/Users/yanghungtw/Tools/specaffold/bin/scaff-seed` line 432: `_scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)` — resolver present in shim heredoc. PASS.
- Line 437: `"$SCAFF_SRC/bin/scaff-lint" scan-staged "$@"` — absolute-path form. PASS.
- Line 438: `"$SCAFF_SRC/bin/scaff-lint" preflight-coverage` — absolute-path form. PASS.
- Both `cmd_init` (line 829) and `cmd_migrate` (line 1395) delegate to the single `emit_pre_commit_shim` function — single source of truth, no drift risk. PASS.

**Runtime check (t113 A4):** FAIL. The t113 test exits 2 at line 95 before reaching A4 (primary bug — see F1 below). When run with the printf fix applied, A4 still FAILS because `scaff-seed init` cannot install the hook: `write_atomic` calls `python3`, and on this machine `asdf` resolves `python3` by searching for `.tool-versions` in the CWD hierarchy; the consumer directory (a freshly-created `mktemp -d` subdirectory) has no `.tool-versions`, and the sandbox HOME has none either, so `asdf` returns exit 126 ("No version is set for command python3"). The hook file is never written. This is a test-environment interaction, but the effect is that t113's A4 runtime assertion does not produce evidence.

**Verdict: PARTIAL** (structural code checks pass; runtime subprocess evidence blocked by printf bug + asdf environment interaction)

---

### AC5 — Sandboxed consumer with NO `bin/` can extract and run gate body via `$SCAFF_SRC`

**Check (patched t113, A5):**
```
PASS: A5: consumer has no bin/ (thin-consumer invariant holds)
PASS: A5: preflight.md present in source repo at $SCAFF_SRC
PASS: A5a: gate exited 70 (REFUSED) when no config.yml
PASS: A5b: gate exited 0 (passthrough) when config.yml present
```

**Verdict: PASS** (both branches verified via subprocess)

---

### AC6 — Source repo `bin/scaff-lint preflight-coverage` still passes

```
$ bin/scaff-lint preflight-coverage; echo "exit=$?"
ok:.claude/commands/scaff/archive.md
... (18 lines)
ok:.claude/commands/scaff/validate.md
exit=0
```

Wall clock: 18ms (well under 100ms budget). All 18 files PASS byte-identity check against canonical block.

**Verdict: PASS**

---

### AC7 — `bin/scaff-seed`'s `plan_copy` entry for `.specaffold/preflight.md` is removed

```
$ grep "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"
(empty — exit 1)
```

The 3-line `if [ -f "${src_root}/.specaffold/preflight.md" ]...` block (original lines 440–442) and its comment block (lines 437–439) were deleted. `emit_default_config_yml` helper remains intact (lines 382–410).

**Verdict: PASS**

---

### AC8 — Integration test (assistant-not-in-loop) covers end-to-end consumer flow

The test exists at `/Users/yanghungtw/Tools/specaffold/test/t113_scaff_src_resolver.sh`, is executable, contains `# AC8: assistant-not-in-loop` header comment, and every assertion is a literal subprocess invocation. However:

```
$ /bin/bash test/t113_scaff_src_resolver.sh; echo "EXIT=$?"
=== A1: AC1 — 3-tier resolver ===
/Users/yanghungtw/Tools/specaffold/test/t113_scaff_src_resolver.sh: line 95: printf: --: invalid option
printf: usage: printf [-v var] format [arguments]
EXIT=2
```

Exit 2 at line 95 due to bash 3.2 treating `'--- A1a: env var override ---\n'` as `printf --...` (flag character). Same error at lines 124 and 154. `set -euo pipefail` causes immediate abort; zero assertions run. This is the primary BLOCK finding.

**Verdict: FAIL** — the test script itself is broken on bash 3.2. Executable check exists but produces no evidence (exit 2 = hard crash before assertions).

---

## Finding details

**F1 (BLOCK — AC8/AC1/AC4/AC5 affected):** `/Users/yanghungtw/Tools/specaffold/test/t113_scaff_src_resolver.sh` lines 95, 124, 154 contain `printf '--- ...\n'` where the leading `--` is parsed as an option flag by bash 3.2's `printf` builtin, producing exit 2. With `set -euo pipefail` the script aborts before any assertion runs. The fix is `printf '%s\n' '--- ...'`. This is a `must`-severity bash-32-portability violation per `.claude/rules/bash/bash-32-portability.md`.

**F2 (should — AC2 secondary check):** PRD AC2 says `grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns 18 paths, but only 3 files have that pattern (archive.md, next.md, implement.md). The plan §1.2 / T4 scope text explicitly supersedes this with "NOT all 18 — only files that source bin/ get the rewrite". The functional goal is complete; this is a PRD wording drift versus shipped architecture.

**F3 (advisory — AC4 runtime gap):** Even with the printf bug fixed, t113 A4 cannot install the pre-commit hook in the sandbox because `write_atomic` requires `python3`, and `asdf` fails to resolve python3 when CWD is an empty `mktemp` directory with no `.tool-versions` AND HOME is sandboxed. The structural code inspection confirms the hook content is correct, but no subprocess-executed evidence of a functioning installed hook exists on this platform.

---

## Validate verdict
axis: tester
verdict: BLOCK
findings:
  - severity: must
    file: test/t113_scaff_src_resolver.sh
    line: 95
    rule: bash-32-portability
    message: printf '--- A1a: env var override ---\n' treats leading '--' as an option flag on bash 3.2 (exit 2); same at lines 124 and 154; set -euo pipefail aborts before any assertion runs — fix to printf '%s\n' '--- ...'
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/03-prd.md
    line: 77
    rule: prd-ac-wording-superseded-by-tech-decision
    message: AC2 second verifiable says "returns 18 paths" but only 3 files have SCAFF_SRC/bin/scaff- references; plan §1.2/T4 scope explicitly supersedes with "NOT all 18 — only files that source bin/ get the rewrite"; PRD wording should be updated post-archive
  - severity: should
    file: test/t113_scaff_src_resolver.sh
    line: 221
    rule: sandbox-home-in-tests
    message: AC4 runtime assertion (A4) cannot install the pre-commit hook in the sandbox because write_atomic requires python3 which fails when CWD is an empty mktemp dir and HOME is sandboxed under asdf; structural code checks pass but no subprocess evidence of a functional installed hook is available on this platform

## Analyst axis

## Team memory

Applied entries:
- `qa-analyst/dead-code-orphan-after-simplification.md` — scanned `bin/scaff-lint` and `bin/scaff-seed` for orphan function definitions; no orphans found post-fixup-commit 647a76a (the `run_resolver` helper and `resolver_exit.$$` orphans were cleaned up there). Pattern applied but no new finding.
- `qa-analyst/task-acceptance-stricter-than-prd-allowance.md` — invoked when assessing AC2's second clause ("returns 18 paths"). PRD text overclaims the expected count; plan §1.2 correctly contradicts it. The implementation follows the plan (3 files, not 18); classified as a PRD authoring inconsistency (advisory), not a blocking gap per this memory entry's guidance. See F2 below.
- `qa-analyst/tech-doc-named-risk-with-plan-claimed-mitigation-must-verify-wiring.md` — applied to plan §3 Risk #3 (mirror-emit sites). The plan's mitigation was "two byte-identical heredocs at lines 797+1384"; implementation took the stronger mitigation (one `emit_pre_commit_shim` helper). Carry-state invariant satisfied by construction. Named verification command in T3 Verify is now invalid (see F4).
- `qa-analyst/wiring-trace-ends-at-user-goal.md` — confirmed PRD R6/AC8 require the test to exercise the end-to-end path. `test/t113_scaff_src_resolver.sh` exists but exits 2 (crash) on the target platform, so the wiring trace does NOT terminate at the user goal. See F1.
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — plan Risk #3 named t113 does NOT exercise `cmd_migrate` path. This known gap is pre-acknowledged in plan §3. With the helper-function refactor, both emit sites now call the same function; the gap is mitigated but not by a separate test. The advisory stands; not a new finding.
- `shared/skip-inline-review-scope-confirmation.md` — entry exists at `~/.claude/team-memory/shared/` (global). W2 merged with `--skip-inline-review` per STATUS.md line 32 and merge commit 6f6e800. The plan states `tier=standard` which requires reviewer per wave; no plan authorization for W2 skip exists. Per this memory entry: if scope ≥ "this feature," flag at gap-check as a known hole. See F3.
- `shared/dogfood-paradox-third-occurrence.md` — twelfth occurrence, as planned. No new failure mode surfaced; umbrella pattern held. Structural verify at validate, runtime on next feature. No finding generated.

---

## Gap-check analysis

### R-id → Task → Diff mapping

**R1** (18 command preambles use `$SCAFF_SRC/bin/scaff-*`): T4 → 18 `.claude/commands/scaff/*.md` edits. Of the 18 files, 3 had `source "$REPO_ROOT/bin/scaff-*"` preamble statements (archive, implement, next); T4 replaced these with `$SCAFF_SRC/bin/scaff-*`. The other 15 never had preamble source statements for `bin/*` — correctly left untouched. Verified: `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` returns empty (AC2 first clause PASS); `grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns 3 (not 18 — PRD AC2 second clause inconsistency, see F2).

**R2** (resolver helper, bash 3.2, env-var/readlink/fail order): T1 embedded the canonical block in `bin/scaff-lint:438–449`; T3 embedded it in `emit_pre_commit_shim` heredoc `bin/scaff-seed:430–436`; T4 embedded it in all 18 command files. The resolver is inline at all surfaces per tech-D1a. Verified: the 7-line resolver text (`# Resolve $SCAFF_SRC:...` through `unset _scaff_src_link` through the `[ -d ... ] || { printf ... exit 65; }` line) is byte-identical across `bin/scaff-lint:439–445`, `bin/scaff-seed:430–436`, and all 18 command files' line 6–12 blocks (diff confirms). Exit code 65 per tech-D4c. Bash 3.2 portability confirmed: uses `%` parameter expansion (not `readlink -f`, not `realpath`, not `[[ =~ ]]`).

**R3** (pre-commit shim uses `$SCAFF_SRC` at hook-run time): T3 → `bin/scaff-seed`. T3 deviated from plan spec (two duplicate heredocs at lines 797 and 1384) by introducing a single `emit_pre_commit_shim()` helper function at `bin/scaff-seed:418–453`. Both `cmd_init` (line 829) and `cmd_migrate` (line 1395) call `emit_pre_commit_shim "$consumer_root"`. The shim heredoc at lines 426–439 contains the resolver and `"$SCAFF_SRC/bin/scaff-lint"` calls. Hook-run-time resolution confirmed per tech-D2b. See F4 for the plan-Verify drift.

**R4** (W3 marker block references `$SCAFF_SRC/.specaffold/preflight.md`): T4 → 18 files. Verified: `grep -l '$SCAFF_SRC/.specaffold/preflight.md' .claude/commands/scaff/*.md` returns 18 files (AC3 PASS). `bin/scaff-lint preflight-coverage` exits 0 with 18 `ok:` lines (AC6 PASS).

**R5** (`plan_copy` preflight.md branch removed): T3 → `bin/scaff-seed`. Verified: `grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty (AC7 PASS).

**R6** (regression test, assistant-not-in-loop, consumer with no `bin/`): T2 → `test/t113_scaff_src_resolver.sh`. The file exists, contains A1–A5 + A8 assertion sections, and covers AC1 (A1a/A1b/A1c), AC4 (A4), AC5 (A5), AC8 (A8). However, `bash test/t113_scaff_src_resolver.sh` exits **2** on bash 3.2.57 (the target platform). Failure occurs at line 95 — the `printf '--- A1a: ...'` format string. This is acknowledged in STATUS.md (2026-04-26 final line) as "pre-existing T2 deliverable bug not caught by W1 NITS review." The test never reaches A1a assertion; no R6 assertions complete. See **F1**.

**R7** (source repo continues to work): No dedicated task; covered by T1's lint canonical block + AC6 regression. `bin/scaff-lint preflight-coverage` exits 0 on source repo: PASS. Dogfood path (`$SCAFF_SRC == $REPO_ROOT`) confirmed functional.

---

### Finding detail

#### F1 — Missing: AC8 / R6 regression test broken on target platform (bash 3.2)

`test/t113_scaff_src_resolver.sh` exits with code 2 on bash 3.2.57. Command run: `bash test/t113_scaff_src_resolver.sh; echo "exit=$?"` → `exit=2`. The script prints `=== A1: AC1 — 3-tier resolver ===` then immediately crashes with:

```
/Users/yanghungtw/Tools/specaffold/test/t113_scaff_src_resolver.sh: line 95: printf: --: invalid option
```

Line 95 is `printf '--- A1a: env var override ---\n'`. The `---` prefix is treated by bash 3.2's built-in `printf` as an option flag. No assertions from A1 onward complete. The PRD R6 requirement states "The test must NOT pass while still relying on consumer-local `bin/`" — currently the test neither passes nor fails assertions; it crashes. AC8 evidence: the integration test exists but does not execute. Severity: **must** — the only regression-test deliverable for the feature's core fix is non-functional on the target platform.

Fix: replace `printf '--- ... ---\n'` section headers with `printf '%s\n' '--- A1a: env var override ---'` (argv-form, not format-string form) at lines 95, 124, 154 of `test/t113_scaff_src_resolver.sh`. This is a bash 3.2 portability violation of the rule in `.claude/rules/bash/bash-32-portability.md` — the `printf` builtin on bash 3.2 interprets strings beginning with `-` as option flags when passed as the format argument.

#### F2 — Drifted: PRD AC2 second clause over-claims 18 files; implementation ships 3 (correct)

PRD `03-prd.md:77` states: "`grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns 18 paths." Actual post-T4 result: 3 paths (archive.md, implement.md, next.md). The other 15 command files never had preamble `source` statements for `bin/*` — only the W3 marker block — so no substitution was needed or made. Plan §1.2 correctly identifies exactly these 3 files ("5" in the plan's Expected list was also wrong; review.md and validate.md only had bare `bin/scaff-aggregate-verdicts` in markdown body pseudo-code, not `$REPO_ROOT/bin/scaff-*` preamble source statements, confirmed by `git show main:.claude/commands/scaff/review.md`).

The implementation is correct; the PRD text is the error. Per `qa-analyst/task-acceptance-stricter-than-prd-allowance.md`, resolve against the PRD allowance when the task correctly implements the requirement. R1's first clause ("preamble source statements") is satisfied. Severity: **advisory** — PRD text is an overclaim in its verifiable grep; the shipped behaviour is correct.

#### F3 — Extra: W2 merge skipped inline review without plan authorization

`shared/skip-inline-review-scope-confirmation.md` states: "If scope ≥ 'this feature', flag it at gap-check time as a known hole that the QA-analyst should weigh extra heavily." W2 merge commit `6f6e800` body reads: "(skipped per W2 fast-merge — T4 is the dogfood-paradox satisfier; reviewers can re-verify post-merge if needed)". STATUS.md line 32 confirms: "skip-inline-review USED for wave 2". Plan `05-plan.md:7` states: "every wave merge runs reviewer-style + reviewer-security per `.claude/rules/reviewer/*.md`." No plan text authorizes a W2 skip. The merge commit `3be7f59` (retroactive bookkeeping) confirms the skip was logged after the fact, not authorized in advance.

W2 is a markdown-only sweep (18 `.md` files, no new bash code). However, the standard-tier contract applies regardless. The W3 marker block content is what the resolver's security posture (D4 exit 65, `bin/claude-symlink install` remediation pointer) rests on — reviewer-security for W2 is not purely cosmetic. Severity: **should** — process gap, not a code correctness issue; T4's content is greppably verifiable post-hoc (and AC3/AC6 pass), but the safety net was skipped.

#### F4 — Drifted: T3 implementation uses single `emit_pre_commit_shim` helper vs plan's prescribed dual-heredoc approach; plan Verify command is now invalid

Plan `05-plan.md:272-273` T3 Verify prescribes:
```
grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l  # returns exactly 2
diff <(awk 'NR==797' bin/scaff-seed) <(awk 'NR==1384' bin/scaff-seed)     # returns empty
```
T3 implementation factored the shim into `emit_pre_commit_shim()` at `bin/scaff-seed:418`. There is now exactly **1** occurrence of `readlink "$HOME/.claude/agents/scaff"` in `bin/scaff-seed` (line 432 inside the helper), not 2. The `awk 'NR==797'`/`awk 'NR==1384'` diff is meaningless (those lines no longer contain heredoc content).

The implementation is architecturally superior (single source of truth eliminates the dual-site drift risk the plan was guarding against), and both `cmd_init:829` and `cmd_migrate:1395` call the same helper. However, the plan's Risk #4 cross-surface byte-identity check (lint canonical block ↔ scaff-seed resolver text) relied on the "two sites" model; the new model has one site, which is simpler but undocumented as a plan amendment. Severity: **should** — implementation is correct; plan Verify tests are now inaccurate. Should be noted so that future plan-based gap checks don't flag a false "missing" for the second heredoc.

#### F5 — Missing: t113 lacks A7 assertion (T2 scope required AC7 cross-check)

Plan `05-plan.md:226-228` T2 scope specifies:

> "A7 (AC7 cross-check — `plan_copy` removed `.specaffold/preflight.md` entry): `grep -n 'preflight.md' bin/scaff-seed | grep -v 'preflight-coverage'` returns empty."

`test/t113_scaff_src_resolver.sh` section headers found: A1, A4, A5, A8. No A7 section exists (confirmed: `grep -n "A7\|A6\|grep.*preflight.md.*scaff-seed" test/t113_scaff_src_resolver.sh` returns nothing). The AC7 structural check passes independently (the grep against `bin/scaff-seed` returns empty), but the T2 deliverable under-ships the required assertion. Severity: **should** — AC7 is verifiable by manual grep, but the test harness does not automate it, violating T2's explicit scope.

---

### No-extra-code check

All diff hunks accounted for:
- `bin/scaff-lint` — T1 scope (R6, R7, D5). Justified.
- `bin/scaff-seed` — T3 scope (R3, R5, D2b, D6a). Justified. The `emit_pre_commit_shim` helper is the T3 implementation choice; no scope creep (it replaces two duplicate inline blocks, not adds new logic).
- `test/t113_scaff_src_resolver.sh` — T2 scope (R6, D7). Justified. The fixup commit `647a76a` cleaned up W1 NITS-review findings (dead `run_resolver` + orphan `resolver_exit.$$`) per the inline-review result.
- `.claude/commands/scaff/*.md` (18 files) — T4 scope (R1, R4, D1a, D3a). Justified. 18 files × (5-line → 12-line marker block) + 3 files × `REPO_ROOT` → `SCAFF_SRC` substitution.
- `STATUS.md` — bookkeeping commits. Justified.
- `05-plan.md` — checkbox updates by orchestrator. Justified.

No unscoped edits detected.

---

## Validate verdict
axis: analyst
verdict: BLOCK
findings:
  - severity: must
    file: test/t113_scaff_src_resolver.sh
    line: 95
    rule: bash-32-portability
    message: printf '--- A1a: env var override ---\n' passes leading '---' as format string; bash 3.2 treats it as option flag and exits 2 before any R6/AC8/AC1 assertion runs — fix with printf '%s\n' '--- A1a: ...' at lines 95, 124, 154
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/03-prd.md
    line: 77
    rule: prd-ac-verifiable-overclaim
    message: AC2 second clause claims grep returns 18 paths but only 3 command files have preamble source statements for bin/scaff-*; 15 files have no such statement — implementation correct, PRD text should read "returns 3 paths (those identified in plan §1.2)"
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/STATUS.md
    line: 32
    rule: skip-inline-review-scope-confirmation
    message: W2 merge (6f6e800) skipped inline review with no plan authorization; plan §1 states every wave merge runs reviewer-style + reviewer-security; T4 is markdown-only but the resolver's D4 security posture (exit 65, remediation text) was not reviewer-security reviewed
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/05-plan.md
    line: 272
    rule: plan-verify-drift
    message: T3 Verify commands ("wc -l returns exactly 2" and "diff <(awk 'NR==797') <(awk 'NR==1384')") are now invalid — T3 implemented a single emit_pre_commit_shim helper (1 heredoc, not 2); plan Verify should reflect the helper-function approach; readlink count is 1, not 2
  - severity: should
    file: test/t113_scaff_src_resolver.sh
    line: 1
    rule: t2-scope-under-ship
    message: T2 scope required A7 assertion (grep -n 'preflight.md' bin/scaff-seed | grep -v 'preflight-coverage' returns empty) per plan §3 T2 A7 spec; no A7 section exists in t113; AC7 is structurally verifiable by grep but not automated in the test harness

## Validate verdict
axis: aggregate
verdict: BLOCK
