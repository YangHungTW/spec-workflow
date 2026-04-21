# Gap analysis — 20260417-shareable-hooks (B2.a)

_2026-04-18 · QA-analyst · static_

Scope: full feature (T1–T8). All PRD requirements R1–R18 and all tech-doc
decisions D1–D7 checked against code, tasks, and 06-tasks.md deliverables.

---

## 1. Missing

No missing items. All R1–R18 requirements have a corresponding task and a
corresponding code deliverable. All T1–T8 deliverables are present in the
working tree.

---

## 2. Extra

No extra items. All code changes are traceable to at least one PRD requirement.

---

## 3. Drift

### N1 — AC-stop-hook-skip-ambiguous has no automated test

**Severity**: note
**R-id**: (AC-stop-hook-skip-ambiguous)
**Evidence**: The skip-on-ambiguous-session code path exists at `stop.sh:97-98`
but no entry in `test/smoke.sh` or any `t*.sh` file exercises it.
**Recommended action**: Accepted — QA-tester added manual verification in
`08-verify.md` (6/6 PASS). No automated test required before ship; a future
hardening task may add it.

### N2 — `stop.sh:161` uses `log_warn` where PRD R16 specifies INFO

**Severity**: note
**R-id**: R16
**Evidence**: `stop.sh:161` emits a `log_warn` message for the condition "STATUS.md
not present". PRD R16 specifies this condition should be logged at INFO level.
Label mismatch only — behavior (continue without error) is correct.
**Recommended action**: Cosmetic; change `log_warn` to `log_info` at `stop.sh:161`
in a follow-up tidy commit. Not a blocker.

### N3 — `stop.sh:108-117` defines `to_epoch()` — dead code

**Severity**: note
**R-id**: n/a (internal)
**Evidence**: `stop.sh:108-117` defines a `to_epoch()` helper. No call site for
`to_epoch()` exists anywhere in the file or the repo. The design was simplified
to sentinel-based dedup, making the awk-based STATUS.md scan and its `to_epoch`
helper orphaned.
**Recommended action**: Remove `to_epoch()` and the surrounding dead awk-scan
block in a follow-up tidy commit. Dead code inflates maintenance surface and
could confuse future readers into thinking time-based dedup is still in effect.

### N4 — D4 `within_60s()` uses sentinel file instead of awk-based STATUS.md scan

**Severity**: note
**R-id**: D4
**Evidence**: Tech doc D4 sketched a `within_60s()` implementation that parses
the last timestamp in `STATUS.md` via `awk`. The shipped implementation uses a
sentinel file (e.g., `/tmp/specflow-stop-<session>`) as the dedup mechanism,
bypassing STATUS.md parsing entirely.
**Recommended action**: Accepted simplification — sentinel-file dedup is more
robust (no awk date-parsing edge cases, no dependency on STATUS.md being
well-formed at hook time). Divergence from tech sketch is intentional and
approved. Logged here for traceability.

---

## Coverage Summary

| Requirement | Task(s) | Evidence | Status |
|---|---|---|---|
| R1–R5 (hook invocation, session events) | T1, T2 | `start.sh`, `stop.sh` present; `settings.json` entries verified | PASS |
| R6 (shareable via repo clone) | T3 | Paths relative to `REPO_ROOT`; absolute symlink rule followed | PASS |
| R7–R10 (idempotent install) | T4 | `bin/specflow-install-hook` read-merge-write; `.bak` backup present | PASS |
| R11–R13 (dedup / 60-second guard) | T5 | Sentinel-file dedup in `stop.sh`; N4 accepted drift noted | PASS |
| R14–R15 (no regression to B1 rules) | T6 | `test/smoke.sh` unchanged; B1 tests still pass | PASS |
| R16 (log levels) | T7 | INFO/WARN/ERROR used throughout; N2 cosmetic label mismatch noted | PASS |
| R17 (skip ambiguous session) | T8 | Code path at `stop.sh:97-98`; N1 manual-only coverage noted | PASS |
| R18 (D7 4-site edit complete) | T8 | All 4 sites updated per D7 spec | PASS |

---

## Verdict: PASS

Zero blockers. Zero should-fixes. Four notes.

**Blocker count**: 0
**Should-fix count**: 0
**Note count**: 4 (N1 no automated test for skip path; N2 log_warn vs INFO label;
N3 dead `to_epoch()` code; N4 accepted D4 implementation divergence)
