# Validate: 20260426-fix-commands-source-from-scaff-src
Date: 2026-04-26 (re-run after fixup commit 2392322)
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 4 should (PRD AC2 overclaim, W2 skip-inline-review process gap, T3 helper-vs-plan-verify drift, t113 missing A7 assertion)

The single `must` finding from the prior BLOCK run (commit 5df5ffc) — t113 `printf '--- ...\n'` bash-3.2 bug at lines 95/124/154 — is RESOLVED by fixup commit 2392322. One advisory (t113 A4 sandbox/asdf interaction) is also resolved by the PATH=/usr/bin:/bin pin. The remaining four advisories are unchanged: PRD wording, historical W2 process gap, plan Verify drift after T3 architectural improvement (single helper vs dual heredocs), and the missing A7 assertion in t113.

`bash test/t113_scaff_src_resolver.sh` exits 0; all A1, A4, A5, A8 assertions pass.

## Tester axis

## Re-validation summary

- **AC1 (3-tier resolver)**: t113 A1a, A1b, A1c all PASS under `/bin/bash` 3.2.57. The prior BLOCK finding (bash 3.2 `printf '--'` crash at lines 95/124/154) is resolved; argv-form `printf '%s\n' '---...'` is now in place.
- **AC2 (18 preambles from SCAFF_SRC)**: Zero `REPO_ROOT/bin/scaff-` refs remain. All 18 files have the `$SCAFF_SRC` resolver block. Prior advisory still applies: PRD's verifiable predicate (`grep -l 'SCAFF_SRC/bin/scaff-' ... returns 18 paths`) returns 3, not 18 — only 3 of the 18 commands actually invoke `bin/scaff-*` executables; the other 15 use the resolver only for preflight. The underlying requirement is met; the AC2 verification formula is overclaimed. Advisory carries forward.
- **AC3 (W3 marker blocks via SCAFF_SRC)**: All 18 files reference `$SCAFF_SRC/.specaffold/preflight.md`. No bare relative `preflight.md` refs. `bin/scaff-lint preflight-coverage` exits 0.
- **AC4 (pre-commit shim hook-run resolution)**: t113 A4 all 4 assertions PASS. Hook contains resolver readlink call, uses `$SCAFF_SRC/bin/scaff-lint`, exits 0 under SCAFF_SRC.
- **AC5 (sandboxed consumer no bin/)**: t113 A5/A5a/A5b all PASS. Thin-consumer invariant holds; gate exits 70 without config.yml, exits 0 with it. The `rm -f config.yml` precondition fix correctly isolates A5a from A4's side effect.
- **AC6 (dogfood regression)**: `bin/scaff-lint preflight-coverage` exits 0, all 18 ok lines.
- **AC7 (plan_copy removed)**: `grep "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty. Prior advisory (t113 has no A7 assertion) still applies — AC7 is met structurally but has no executable check in t113.
- **AC8 (assistant-not-in-loop)**: t113 exits 0 with all assertions passing, zero failures. Test is subprocess-only, no LLM in loop.

## Team memory

Applied entries:
- `qa-tester/prd-ac-wording-superseded-by-tech-decision.md` — checked whether any AC literal wording was superseded; not applicable here.
- `qa-tester/validate-artefact-filename-is-08-validate-not-08-verify.md` — reminder not to write file; complied (no file written).
- `qa-tester/probe-anchor-spot-checks-should-span-spelling-variants.md` — applied to AC3 grep (used `SCAFF_SRC.*preflight` to catch variants).
- `qa-tester/universal-quantifier-acs-need-querySelectorAll-not-constants.md` — drove enumeration of all 18 files live rather than trusting constant `18`.
- `shared/dogfood-paradox-third-occurrence.md` — noted AC8 dogfood path runs as subprocess, consistent with pattern.

---

## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    file: /Users/yanghungtw/Tools/specaffold/test/t113_scaff_src_resolver.sh
    line: 1
    rule: missing-a7-assertion
    message: t113 has no executable assertion for AC7 (plan_copy preflight.md removed from bin/scaff-seed); AC7 is structurally met but untested by this harness — add a grep assertion in the A7 block before archiving.
  - severity: should
    file: /Users/yanghungtw/Tools/specaffold/.specaffold/features/20260426-fix-commands-source-from-scaff-src/03-prd.md
    line: 77
    rule: prd-ac2-overclaim
    message: AC2 verifiable predicate states "grep -l 'SCAFF_SRC/bin/scaff-' ... returns 18 paths" but only 3 of 18 command files invoke bin/scaff-* executables; the remaining 15 use the resolver for preflight only, so the grep returns 3 — the underlying requirement is met but the stated verification formula is wrong; carried forward from prior validate as advisory.

## Analyst axis

## Team memory

Applied entries with relevance:

- `qa-analyst/wiring-trace-ends-at-user-goal.md` — confirmed t113 now terminates at the user goal (A8 asserts `bin/scaff-tier` sources successfully from consumer CWD). F1 is resolved.
- `qa-analyst/tech-doc-named-risk-with-plan-claimed-mitigation-must-verify-wiring.md` — re-applied to F5/F6: T3 Verify commands are still invalid (plan §3 T3 Verify line 272 prescribes `wc -l` returns 2, but implementation has 1 readlink call). F5 (plan-verify drift) remains a should.
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — the `cmd_migrate` path is still not tested. F6 (t113 missing A7 / cmd_migrate untested) remains an advisory. The helper-function refactor does reduce actual risk but the test gap persists.
- `shared/skip-inline-review-scope-confirmation.md` — F4 (W2 skip-inline-review process gap) unchanged; STATUS.md line 32 still records the skip with no plan authorization.
- `qa-analyst/task-acceptance-stricter-than-prd-allowance.md` — F2 (PRD AC2 "18 paths" overclaim) unchanged; PRD text was not edited in the fixup.
- `qa-analyst/dead-code-orphan-after-simplification.md` — scanned the fixup diff; no dead code or orphan helpers introduced. Clean.

---

## Re-validation analysis

### F1 (must — bash-32-portability printf bug): RESOLVED

`/bin/bash test/t113_scaff_src_resolver.sh` now exits 0 with 20 PASS lines and `PASS: t113`. The three `printf '--- ...\n'` calls at lines 95, 124, 154 were switched to the argv form `printf '%s\n' '--- ...'`. All four assertion blocks (A1, A4, A5, A8) run and pass.

The fixup also included two PATH pins (`PATH=/usr/bin:/bin:$PATH` at lines 224 and 254) and one `rm -f` before A5a (line 290). These address the F3 advisory (asdf interaction). The PATH pins are correctly scoped inside `(cd "$CONSUMER" && ...)` subshells and do not mutate the outer test environment. The `rm -f` has a justifying WHY comment ("Remove any config.yml left over from A4's scaff-seed init; A5a's 'no config.yml' precondition was being broken by it"). No style violations introduced.

### F2 (should — PRD AC2 "18 paths" overclaim): UNCHANGED

`03-prd.md` line 77 still reads "returns 18 paths." The fixup commit modifies only `test/t113_scaff_src_resolver.sh`; PRD text was not touched. `grep -l 'SCAFF_SRC/bin/scaff-'` still returns 3 files (archive, implement, next). Advisory still stands.

### F3 (should — t113 A4 sandbox/asdf interaction): RESOLVED

The PATH pin at `test/t113_scaff_src_resolver.sh:224` and `:254` resolves the asdf-shim interaction. A4 now runs and passes all four assertions:
- `PASS: A4: pre-commit hook installed and executable`
- `PASS: A4: hook contains resolver readlink call`
- `PASS: A4: hook uses $SCAFF_SRC/bin/scaff-lint (absolute-path form)`
- `PASS: A4: hook exited 0 when SCAFF_SRC set (passthrough)`

The commit message accurately describes the escalation (was advisory, became blocking after printf fix allowed the test to reach A4). Now resolved.

### F4 (should — W2 skip-inline-review process gap): UNCHANGED

`STATUS.md` line 32 still records the skip. No plan authorization exists for W2. The fixup does not retroactively authorize the W2 skip. T4's content (18 `.md` files, resolver block with D4 exit-65 + remediation text) was never reviewer-security reviewed through the formal wave-merge channel. Process gap remains a should.

### F5 (should — T3 helper-vs-plan Verify drift): UNCHANGED

`05-plan.md` line 272 still prescribes:
- `grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l` returns exactly 2
- `diff <(awk 'NR==797' bin/scaff-seed) <(awk 'NR==1384' bin/scaff-seed)` returns empty

Actual state: `grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l` returns 1 (single `emit_pre_commit_shim` helper at line 432). The awk line-number diff is meaningless. The plan Verify commands are now misleading to any future audit using them. Advisory still stands.

### F6 (should — t113 missing A7 assertion): UNCHANGED

`grep -n "A7\|preflight.*scaff-seed" test/t113_scaff_src_resolver.sh` returns nothing. No A7 section was added by the fixup. Plan `05-plan.md:226-228` specifies T2 scope requires A7: `grep -n 'preflight.md' bin/scaff-seed | grep -v 'preflight-coverage'` returns empty. AC7 is structurally verifiable by direct grep (returns empty, PASS) but the test harness does not automate it. Advisory still stands.

---

## Summary

The fixup commit resolves the single `must` (F1) and one of the five `should` findings (F3). The remaining four `should` findings (F2, F4, F5, F6) are unchanged and remain advisory. No new must-severity issues introduced by the fixup.

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/03-prd.md
    line: 77
    rule: prd-ac-verifiable-overclaim
    message: AC2 second clause still claims "returns 18 paths" but only 3 command files have preamble source statements for $SCAFF_SRC/bin/scaff-*; PRD text was not updated by the fixup; implementation is correct — PRD should read "returns 3 paths (those identified in plan §1.2)"
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/STATUS.md
    line: 32
    rule: skip-inline-review-scope-confirmation
    message: W2 merge (6f6e800) skipped inline reviewer-style + reviewer-security review with no plan authorization; plan §1 states "every wave merge runs reviewer-style + reviewer-security"; T4's D4 exit-65 security posture and remediation text were not reviewed through the formal wave-merge channel; fixup commit did not retroactively authorize this skip
  - severity: should
    file: .specaffold/features/20260426-fix-commands-source-from-scaff-src/05-plan.md
    line: 272
    rule: plan-verify-drift
    message: T3 Verify prescribes "wc -l returns exactly 2" and "diff <(awk 'NR==797') <(awk 'NR==1384')" — both invalid after T3 implemented a single emit_pre_commit_shim helper (1 readlink occurrence at line 432, not 2); plan Verify section was not updated by the fixup and will mislead future audits
  - severity: should
    file: test/t113_scaff_src_resolver.sh
    line: 1
    rule: t2-scope-under-ship
    message: T2 scope required A7 assertion (grep -n 'preflight.md' bin/scaff-seed | grep -v 'preflight-coverage' returns empty) per plan §3 T2 spec line 226-228; no A7 section exists in t113 after the fixup; AC7 passes by manual grep but is not automated in the test harness

## Validate verdict
axis: aggregate
verdict: NITS
