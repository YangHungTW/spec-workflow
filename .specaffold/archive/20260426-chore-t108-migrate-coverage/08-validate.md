# Validate: 20260426-chore-t108-migrate-coverage
Date: 2026-04-26 02:59
Axes: tester, analyst

## Consolidated verdict
Aggregate: PASS
Findings: 0 must, 0 should, 2 advisory (analyst — chore-tiny plan short-circuit; pre-existing A1 proximity gap)

## Tester axis

## Team memory

Applied entries:
- `sandbox-home-preflight-pattern.md` (global qa-tester): confirmed sandbox pattern is present in A5 via `make_consumer` helper.
- `runtime-verify-must-exercise-end-to-end-not-just-build-succeeds.md` (shared): test actually runs `scaff-seed migrate` end-to-end.

---

## Tester axis findings — 20260426-chore-t108-migrate-coverage

### AC1: A5 section present + exercises migrate path

Command: `grep -E '^# A5\b|A5:' test/t108_precommit_preflight_wiring.sh`
Output: `# A5 — scaff-seed migrate produces hook with both invocations`
Result: PASS

Command: `grep -F 'scaff-seed' test/t108_precommit_preflight_wiring.sh | grep -F 'migrate'`
Output: `# A5 — scaff-seed migrate produces hook with both invocations`
Result: PASS

Bonus check (line 179): `"$SEED" migrate --from "$REPO_ROOT" --ref "$SRC_REF"` — uses `migrate`, not `init`. PASS

### AC2: A5 mirrors A2 assertion shape (sandboxed + scan-staged + preflight-coverage)

Command: `grep -F 'scan-staged' test/t108_precommit_preflight_wiring.sh`
Output: includes `grep -F 'scaff-lint scan-staged' "$HOOK_M"` at line 186
Result: PASS

Command: `grep -F 'preflight-coverage' test/t108_precommit_preflight_wiring.sh`
Output: includes `grep -F 'scaff-lint preflight-coverage' "$HOOK_M"` at line 189
Result: PASS

Sandboxed consumer: `CONSUMER_M="$SANDBOX/consumer-migrate"` + `make_consumer "$CONSUMER_M"` at lines 176-177. PASS

### AC3: Full test run

Command: `bash test/t108_precommit_preflight_wiring.sh`
Exit code: 0
Final line: `PASS: t108`
Result: PASS

---

## Validate verdict
axis: tester
verdict: PASS
findings: []


## Analyst axis

# QA-analyst findings — 20260426-chore-t108-migrate-coverage
axis: analyst
date: 2026-04-26

---

## Team memory

Applied:
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — directly relevant: this chore closes the gap that entry originated from; used to verify the A5 block closes the wiring-trace gap correctly.

Not applied:
- `qa-analyst/developer-preexisting-claim-must-be-git-verified.md` — N/A (no preexisting claim made)
- `qa-analyst/manifest-sha-baseline-for-drifted-ours.md` — N/A (no manifest diff)
- `shared/*` — none match a tiny test-coverage chore

---

## 1. Coverage — checklist item trace

Checklist item 1 (PRD line 24): "Add A5 section … covering scaff-seed migrate path"
- Verify predicate: `grep -E '^# A5\b|A5:|A5 '` — satisfied at test/t108_precommit_preflight_wiring.sh:174 (`# A5 — scaff-seed migrate produces hook with both invocations`)
- Verify predicate: `grep -F 'scaff-seed' | grep -F 'migrate'` — satisfied at line 179 (`"$SEED" migrate --from "$REPO_ROOT" --ref "$SRC_REF"`)
CLOSED.

Checklist item 2 (PRD line 25): "Confirm A5 mirrors A2's assertion shape"
- sandbox via make_consumer: satisfied (line 177: `make_consumer "$CONSUMER_M"`)
- `[ -x ... ]` check: satisfied (line 183-184)
- `grep -F 'scaff-lint scan-staged'`: satisfied (lines 186-187)
- `grep -F 'scaff-lint preflight-coverage'`: satisfied (lines 189-190)
CLOSED.

Both PRD checklist items are fully satisfied by the +19-line A5 block.

---

## 2. Drift analysis

2a. make_consumer reuse vs duplicate:
PRD §Scope: "reuse the helper or a fresh sandbox at the author's discretion — both are in scope".
Developer reused make_consumer (line 177). This is the preferred path per PRD. No drift.

2b. Tests migrate, not init:
A5 runs `"$SEED" migrate --from "$REPO_ROOT" --ref "$SRC_REF"` (line 179). Not init. Correct.
A2 runs `"$SEED" init ...` (line 120). The two blocks are parallel but distinct. No drift.

2c. Production-only changes:
Diff touches exactly three files:
  - test/t108_precommit_preflight_wiring.sh — the target test file (in scope)
  - .specaffold/features/.../05-plan.md — task checkbox from [ ] to [x] (bookkeeping, expected)
  - .specaffold/features/.../STATUS.md — stage advance + Notes lines (bookkeeping, expected)
No production code (bin/, .claude/, hooks/) was touched. No drift.

2d. No spurious init step before migrate:
A5 calls make_consumer then immediately migrate — no prior init call. Matches developer's
finding that cmd_migrate works on a fresh repo (baseline_sha="" same as cmd_init). No drift.

---

## 3. Extra work / scope creep

None. The diff is minimal and entirely traceable to the two PRD checklist items. No helper
refactor, no separate t108_migrate.sh file, no update/other subcommand coverage.

---

## 4. Observations

4a. Plan stub (advisory, archive retro only):
05-plan.md §1.3 documents the chore-tiny short-circuit where /scaff:plan hard-requires
04-tech.md but tech is matrix-skipped. This plumbing gap was surfaced by the orchestrator;
not a verdict-affecting issue for this feature. Carried as advisory per task brief.

4b. A5 confirms no spurious init (advisory):
The developer's STATUS note states cmd_migrate works on a fresh repo without prior init.
The A5 block validates this: make_consumer → migrate directly → assertions pass. The test
structure itself becomes evidence that no pre-init is needed, which strengthens the
migrate path documentation.

4c. A1 proximity threshold is cmd_init-only (advisory):
The A1 anchor-line proximity check (lines 97-112) searches for the FIRST occurrence of
'scan-staged' and 'preflight-coverage' in bin/scaff-seed (head -1). Since cmd_init appears
before cmd_migrate in the file, A1 always anchors to the cmd_init heredoc. The cmd_migrate
heredoc's proximity is never checked by A1. This is not a new gap introduced by this
chore — it predates it — but noting it since A5 only tests runtime output, not proximity
of the cmd_migrate template literals. Severity: advisory (pre-existing; not introduced here).

---

## 5. Out-of-scope deferred items — verified absent

- make_consumer refactor: NOT in diff. Correctly deferred.
- Separate t108_migrate.sh: NOT in diff. Correctly deferred.
- update/other scaff-seed paths: NOT in diff. Correctly deferred.

---

## Validate verdict
axis: analyst
verdict: PASS
findings:
  - severity: advisory
    file: .specaffold/features/20260426-chore-t108-migrate-coverage/05-plan.md
    line: 26
    rule: chore-tiny-plan-shortcircuit
    message: /scaff:plan hard-requires 04-tech.md which is matrix-skipped on chore-tiny; hand-written plan stub was needed; surfaced for archive retro — no action required this cycle.
  - severity: advisory
    file: /Users/yanghungtw/Tools/specaffold/test/t108_precommit_preflight_wiring.sh
    line: 97
    rule: partial-wiring-trace-every-entry-point
    message: A1 proximity check anchors to head -1 occurrence of each literal (cmd_init heredoc); cmd_migrate heredoc proximity is untested by A1 — pre-existing gap, not introduced by this chore; noted for future t108 hardening.


## Validate verdict
axis: aggregate
verdict: PASS
