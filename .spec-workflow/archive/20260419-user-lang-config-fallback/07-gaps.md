# 07-gaps.md — user-lang-config-fallback

_2026-04-19 · QA-analyst_

## STATUS
- 2026-04-19 qa-analyst — gap-check complete; verdict NITS; 0 must, 2 advisory findings

---

## 1. Summary

**Verdict: NITS**  
**Coverage: 18/18 ACs traced** (R1 AC1.a–d, R2 AC2.a–b, R3, R4 AC4.a–c, R5 AC5.a–b, R6 AC6.a–d, R7 AC7.a–b)  
**Smoke: 72/72 PASS** (verified by direct run)

The implementation is correct and structurally complete. All runtime-observable ACs (AC1.b, AC1.c, AC1.d, AC4.a) have structural coverage via sandbox-`$HOME` + `HOOK_TEST=1` integration tests. Two advisory findings: one is a task-acceptance-field misconfiguration that the PRD's own allowance resolves; the other is a tech-spec deviation (new README subsection header) that improves discoverability without violating any PRD requirement. Neither blocks archive.

---

## 2. Coverage matrix

| R | AC | Test / evidence | Gap? |
|---|---|---|---|
| R1 | AC1.a (all-absent baseline) | t67 integration + zero-agent-diff | none |
| R1 | AC1.b (user-home-only opt-in) | t68 integration | none (structural only per R7) |
| R1 | AC1.c (project over user) | t69 integration | none (structural only per R7) |
| R1 | AC1.d (XDG over tilde) | t70 integration | none (structural only per R7) |
| R2 | AC2.a (single `in_lang=1`) | `grep -c 'in_lang=1'` → 1; t73 | none |
| R2 | AC2.b (awk body byte-identical) | t73 (6-token grep-structural) | none |
| R3 | (parent invariants preserved) | 0-diff on `.claude/rules/`, `.claude/agents/`, `bin/` | none |
| R4 | AC4.a (stop-on-first-hit, reworded) | t71 (6 assertions incl. user-home not consulted) | none (structural only per R7) |
| R4 | AC4.b (exit 0 always) | all t67–t72 assert exit 0 | none |
| R4 | AC4.c (missing file silent) | t67 (all absent), t72 (missing early candidates) | none |
| R5 | AC5.a (no new fork per iteration) | t73 portability grep; hook diff inspection | none |
| R5 | AC5.b (wall-clock unchanged) | satisfaction by construction from AC5.a; T1 review | none |
| R6 | AC6.a (`~/.config/specflow/config.yml` documented) | `grep -F '~/.config/specflow/config.yml' README.md` → match | none |
| R6 | AC6.b (XDG documented with env-var gating) | README line 108: "only when `$XDG_CONFIG_HOME` is set and non-empty" | none |
| R6 | AC6.c (precedence in plain words) | README §Precedence ordered list 1/2/3 | **G1 (advisory)** |
| R6 | AC6.d (rule file unchanged) | `git diff … -- .claude/rules/common/language-preferences.md` → 0 lines | none |
| R7 | AC7.a (structural markers in verify) | verify-stage discipline — 08-verify.md forthcoming | none (verify-stage) |
| R7 | AC7.b (next-feature handoff) | handoff AC — not verifiable here | none (handoff) |

---

## 3. Findings

### G1 — R6 AC6.c: README has ordered list but not the exact "project > XDG > tilde" string

- **Severity**: advisory
- **Category**: drift (task acceptance vs PRD allowance)
- **Evidence**: T9 Acceptance required `grep -F 'project > XDG > tilde' README.md` (06-tasks.md T9 Acceptance, line 884). Running that exact command returns nothing (`README.md` does not contain the literal string). The README instead contains a numbered list under `### Precedence` (README.md line 105–109) that enumerates the three candidates in order.
- **PRD resolution**: PRD R6 AC6.c (`03-prd.md` line 239) reads "or equivalent plain-English ordering — e.g. 'the project file wins when present; otherwise the XDG path is consulted'". The ordered numbered list is unambiguously an equivalent plain-English ordering; the AC is satisfied at the PRD level.
- **Recommendation**: No code change required. The T9 acceptance field was drafted too strictly relative to the PRD's own allowance clause. If the verify-stage QA-tester runs the acceptance command literally, flag this as a T9 acceptance-field authoring error, not an AC failure.

### G2 — tech D8 / T9 constraint deviation: README added a new `### Precedence` section header

- **Severity**: advisory
- **Category**: extra (implementation added beyond tech spec)
- **Evidence**: Tech D8 (`04-tech.md` line 629) says "No new sections". T9 Briefing (06-tasks.md line 869) says "Do NOT add a new section header." The diff at `README.md` adds `### Precedence` at line 103 — a new `###`-level subsection header not present in the parent.
- **PRD resolution**: PRD R6 body (`03-prd.md` R6) only requires "documents the full candidate-list precedence in plain words" — it does not prohibit a section header. The added header improves discoverability (a user searching the README can jump directly to "Precedence"). No PRD requirement is violated.
- **Recommendation**: No change required. The deviation is an upgrade in discoverability quality. Document as an advisory in verify. If the TPM wants to enforce tech D8's "no new header" constraint in future features, that belongs in a team-memory entry, not a revert here.

---

## 4. Specific verifications requested

**R1 AC1.a–d candidate list**: hook diff confirms three-path ordered list per PRD R1; XDG conditional uses `[ -n "${XDG_CONFIG_HOME:-}" ]` (D3); space-separated `for` loop (D5); stop-on-first-non-empty `break` (D6). Tests t67–t70 each cover one path through the matrix. PASS.

**R2 AC2.a single awk**: `grep -c 'in_lang=1' .claude/hooks/session-start.sh` → 1. PASS.

**R2 AC2.b awk body byte-identical**: t73 extracts the `sniff_lang_chat()` block and asserts six semantic tokens against the D7 spec verbatim. 13/13 assertions pass. PASS.

**R3 parent invariants**: `git diff 20260419-language-preferences…HEAD -- .claude/rules/` → 0 lines. `git diff … -- .claude/agents/specflow/` → 0 lines. `git diff … -- bin/` → 0 lines. No change to rule body, subagent files, or specflow-lint. PASS.

**R4 AC4.a stop-on-first-hit**: t71 (`.spec-workflow/config.yml` = `chat: fr`, `~/.config/specflow/config.yml` = `chat: zh-TW`) — all 6 assertions pass: exit 0, no `LANG_CHAT=`, one stderr warning naming `.spec-workflow/config.yml` with value `fr`, no mention of `zh-TW` in stderr, no mention of user-home path. User's valid value was never consulted. PASS (structural only per R7).

**R4 AC4.b/c**: every integration test asserts exit 0; t67 and t72 confirm missing files produce no warning. PASS.

**R5 latency preserved**: t73 portability grep finds 0 forbidden tokens; loop body contains exactly one `[ -r ]` probe and one `sniff_lang_chat` call (one awk fork) per present file, bounded at ≤ 3 iterations. No new subprocess in the absent-file path. PASS (structural).

**R6 README**: `grep -F '~/.config/specflow/config.yml' README.md` hits line 109. `grep -F 'XDG_CONFIG_HOME' README.md` hits lines 108 and 3 others; line 108 states "only when `$XDG_CONFIG_HOME` is set and non-empty" (AC6.b). Ordered list conveys "project > XDG > tilde" (AC6.c, see G1). Rule file diff = 0 lines (AC6.d). PASS with G1 advisory on exact-string form.

**Smoke 72/72**: executed locally; PASS.

**t53 exclusion-list integrity**: new exclusions cover `t68`, `t69`, `t70`, `t71`, `t72` (which contain `LANG_CHAT=zh-TW` as fixture values), plus the feature's spec directory and `README.md`. `t73` and `t67` contain no `LANG_CHAT=zh-TW` and need no exclusion. The drift-detection invariant (any file unexpectedly containing the literal marker) is preserved; no legitimate-signal file is silently hidden. t53 PASS confirmed by run.

**T1 NITS status**: the T1 review flagged (a) security advisory on `$XDG_CONFIG_HOME` path — this is an operator-set env var, inside the trust boundary per `shared/local-only-env-var-boundary-carveout`; correctly parked as advisory, not `must`; (b) style should on `CANDIDATES` naming — `CANDIDATES` follows the existing hook convention (`WALK_DIRS`, `RULES_DIR` are both uppercase globals); advisory was misidentified even as a `should`; no upgrade warranted.

**Zero agent diff**: confirmed above.

---

## 5. Verdict

## Verdict: NITS

**0 must findings. 2 advisory findings (G1, G2). 18/18 ACs traced.**

Both advisory findings are resolvable by documentation at verify stage — no code changes required before archive.

---

## 6. Recommendation for next stage

Advance to `/specflow:verify`. QA-tester **must**:

1. Annotate AC1.b, AC1.c, AC1.d, and AC4.a in `08-verify.md` with "structural PASS; runtime verification deferred to next feature after session restart" per R7 AC7.a.
2. Run T9's acceptance greps against the PRD's allowance for equivalent plain-English ordering (G1); the numbered list satisfies AC6.c — do not report as a failure.
3. Note G2 (advisory section header deviation from tech D8) in verify findings.
4. Confirm R7 AC7.b handoff discipline is visible in STATUS Notes for the next feature after archive.

## Team memory

Applied entries:

- `shared/dogfood-paradox-third-occurrence.md` — directly relevant. R7 AC7.a and AC7.b are correctly handled as structural-only / handoff ACs in the tasks doc and confirmed in the coverage matrix above. Runtime verification of AC1.b, AC1.c, AC1.d, AC4.a deferred per this pattern (8th occurrence).
- `qa-analyst/dead-code-orphan-after-simplification.md` — not applicable; no simplification removed helper code that is still invoked.
- `qa-analyst/dry-run-double-report-pattern.md` — not applicable; no dry-run path in this feature.
- `qa-analyst/agent-name-dispatch-mismatch.md` — not applicable; no new agents shipped.
- `~/.claude/team-memory/qa-analyst/manifest-sha-baseline-for-drifted-ours.md` — not applicable; no manifest in scope.
- `~/.claude/team-memory/qa-analyst/partial-wiring-trace-every-entry-point.md` — applied: traced all three candidate paths (project, XDG, tilde) in the hook diff; verified the XDG conditional gate, the `break` on first-hit, and the `if/elif` dispatch outside the loop.
