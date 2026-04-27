# Validate: 20260426-fix-install-hook-wrong-path

Date: 2026-04-27
Axes: tester, analyst

## Consolidated verdict

Aggregate: **NITS**
Findings: 0 must, 3 should, 1 advisory

The fix correctly implements R1–R6 and meets all four acceptance criteria. The qa-tester reproduced the bug, ran every targeted test (t7/t27/t28/t39/t114 — all PASS, plus t114 A4 + A5 covering AC1–AC4) and replayed the bug repro independently against `mktemp -d` consumers. Smoke baseline against `main`: feature actually fixes 3 pre-existing failures (`AC10`, `t29`, `t51`); no regressions. The qa-analyst's NITS verdict raises three test-coverage gaps that the implementation tolerates but a reviewer should know about — none block ship; all are good candidates for a follow-up tightening chore.

---

## Tester axis

> Reply from scaff-qa-tester (axis: tester); verdict: PASS; findings: 0.

### Per-AC findings

**AC1** — No root-level `settings.json` or `settings.json.bak` after fresh `scaff-seed init`

- t114 A5 (automated): both assertions PASS.
- Independent manual replay (sandbox under `mktemp -d`, HOME isolated):
  - `(cd $CONSUMER && PATH=/usr/bin:/bin:$PATH $SRC/bin/scaff-seed init --from $SRC --ref $REF)` exited 0.
  - `[ ! -e "$CONSUMER/settings.json" ]` and `[ ! -e "$CONSUMER/settings.json.bak" ]` both PASS.
- Verdict: **PASS**

**AC2** — `<consumer>/.claude/settings.json` contains both SessionStart and Stop with canonical `bash …` form

- t114 A5 (automated): SessionStart and Stop assertions PASS.
- Manual replay: SessionStart command = `bash .claude/hooks/session-start.sh`; Stop command = `bash .claude/hooks/stop.sh`.
- Verdict: **PASS**

**AC3** — Re-running `scaff-seed init` is idempotent

- t114 A5 (automated): byte-identity check after second run PASSes.
- Code inspection: `do_add` exits early (`sys.exit(0)`) when entry already present, before any backup or write — true no-op on second run.
- Verdict: **PASS**

**AC4** — Migrate flow lands hook entries in `<consumer>/.claude/settings.json`, never at root

- Static analysis of `bin/scaff-seed` lines 1618–1624: no `settings.json` path argument is passed; helper's new default (`p = ".claude/settings.json"`) resolved against `$consumer_root`.
- Runtime exercise: t114 A4 PASS — `.claude/settings.json` exists post-migrate; SessionStart references `.claude/hooks/session-start.sh`; merge sub-case PASSes.
- Verdict: **PASS**

### Targeted test suite results

| Test | Result |
|---|---|
| `bash test/t7_scaff_install_hook.sh` | PASS (7/7 checks) |
| `bash test/t27_settings_json_preserves_keys.sh` | PASS |
| `bash test/t28_settings_json_idempotent.sh` | PASS |
| `bash test/t39_init_fresh_sandbox.sh` | PASS |
| `bash test/t114_seed_settings_json.sh` | PASS (24/24 assertions) |

### Full smoke suite comparison

- Baseline (main @ `6bcd4a7`): 75/102 PASS (27 failures)
- Feature HEAD: 77/102 PASS (25 failures)
- Regressions introduced by this feature: **NONE**
- Bonus: feature branch resolved 3 pre-existing failures (`AC10`, `t29_claude_symlink_hooks_pair`, `t51_rule_file_shape`) — collateral fix, not part of this feature's stated scope.

```
## Validate verdict
axis: tester
verdict: PASS
findings: []
```

---

## Analyst axis

> Reply from scaff-qa-analyst (axis: analyst); verdict: NITS; findings: 3 should + 1 advisory.

### Coverage matrix

| R / T / AC / D id | Diff coverage | Status |
|---|---|---|
| R1 | `bin/scaff-install-hook` lines ~67–68: `p = ".claude/settings.json"` + `os.makedirs`; do_remove line ~109 | COVERED |
| R2 | `.bak` written at `p + ".bak"` — same variable; path follows automatically | COVERED |
| R3 | `bin/scaff-seed` lines 968–969 and 1622–1623 updated; helper default change covers both call sites (no explicit `--settings-path` needed) | COVERED |
| R4 | `do_add` restructured: idempotency check fires before backup; `sys.exit(0)` on already-present entry | COVERED |
| R5 | R1+R2 together prevent any write to cwd-root `settings.json`; no separate production change required | COVERED (by R1/R2) |
| R6 | `bin/scaff-seed` lines 968–969 and 1622–1623 prepend `bash ` to command strings | COVERED |
| T1 | `test/t114_seed_settings_json.sh` A5 section: AC1 + AC2 assertions against fresh consumer | COVERED |
| T2 | t114 A5 byte-identity assertion covers semantic idempotency; **no `.bak` absence assertion** — see F1 | PARTIAL DRIFT |
| T3 | `test/t7_scaff_install_hook.sh` Check 4 verifies `.claude/settings.json` created; **no assertion `[ ! -e $SB4/settings.json ]`** — see F2 | PARTIAL |
| AC1 | t114 A5: `[ ! -e "$CONSUMER5/settings.json" ]` and `[ ! -e "$CONSUMER5/settings.json.bak" ]` | COVERED |
| AC2 | t114 A5: `python3` extracts both SessionStart and Stop, asserts `bash .claude/hooks/...` form | COVERED |
| AC3 | t114 A5: byte-identity check instead of no-`.bak` check — see F1 | DRIFT (should) |
| AC4 | t39 updated; t45 reads OLD root-level file post-migrate — see F3 | PARTIAL/DRIFT (should) |
| D1 | `bin/scaff-install-hook` default changed (Option B confirmed) | HELD |
| D2 | No `--settings-path` flag added | HELD |
| D3 | No retro-cleanup code | HELD |
| OQ1 | Answered in plan §1.1 bullet 2 and §4: migrate call sites pass no explicit settings-path; default covers both | ANSWERED |

### Deviation analysis

1. **Idempotency check moved before backup** (`do_add` restructure) — faithful interpretation of R4 ("no `.bak` written" on idempotent add); **no finding**.
2. **t114 A5 AC3: byte-identity instead of no-`.bak`** — Step 7's Python merge in `scaff-seed` unconditionally writes `.bak` whenever the destination exists, so the PRD literal "no `.bak` written anywhere" is unachievable on second run. Byte-identity is the meaningful invariant for the helper-side idempotency fix specifically. PRD text was not amended → **F1 (should)**.
3. **t114 A2c byte-equality relaxed to permissions-key presence** — Step 10's `add Stop` overwrites Step 7's `.bak` with merged content; key-presence is a sound proxy. **No finding**.
4. **t39 updated outside enumerated Scope** — `t39_init_fresh_sandbox.sh` was not in T1 Scope nor in the Risks-1 carve-out (which named t42/t44/t45/t47). The fix was correct and necessary; the plan's risk list was incomplete → **F4 (advisory)**.

### Findings

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    rid: T2 / AC3
    file: test/t114_seed_settings_json.sh:457-473
    message: AC3 asserts byte-identity instead of no-.bak-anywhere; PRD T2/AC3 literal ("no .bak written anywhere") is violated by Step 7 unconditionally writing .bak on second run — test substitution is justified but PRD text was never amended to reflect the Step 7 constraint
  - severity: should
    rid: T3
    file: test/t7_scaff_install_hook.sh:70-91
    message: Check 4 asserts .claude/settings.json was created but never asserts [ ! -e "$SB4/settings.json" ]; negative half of T3 ("never writes settings.json at the cwd root") is untested
  - severity: should
    rid: AC4
    file: test/t45_migrate_from_global.sh:212-215
    message: t45 post-migrate assertion reads CONSUMER/settings.json (old root-level file, untouched by fix) not CONSUMER/.claude/settings.json; grep passes because ~/.claude/ contains .claude/ as substring — false pass; no test correctly verifies hooks land at .claude/settings.json after migrate
  - severity: advisory
    rid: scope
    file: .specaffold/features/20260426-fix-install-hook-wrong-path/05-plan.md:102
    message: Plan §3 Risks list names t42/t44/t45/t47 as potential unenumerated casualties; t39 was also affected and updated (correct fix) but was not enumerated in either the Scope or the Risks list — risk enumeration was incomplete
```

---

## Recommended follow-up (NOT blocking ship)

A small chore could close all three `should` findings together — they all live in the test layer:

- Update `test/t114_seed_settings_json.sh` A5: either amend the PRD AC3 text to acknowledge Step 7's unconditional `.bak`, or assert byte-identity AND `[ ! -e "$CONSUMER/settings.json.bak" ]` (the root-level absence is the load-bearing AC3 invariant; the `.claude/`-side `.bak` is an unavoidable Step 7 byproduct).
- Add `[ ! -e "$SB4/settings.json" ]` to t7 Check 4 — closes F2.
- Update t45 post-migrate assertion to read `CONSUMER/.claude/settings.json` (not the root-level file) and grep with anchored regex (`-E '(^|[^~])\\.claude/'`) so the substring false-positive is ruled out — closes F3.
- Add `t39` to the §3 Risks bullet 1 enumeration in the archived plan (or accept this as documented post-hoc in the validate report).

---

## Validate verdict
axis: aggregate
verdict: NITS
