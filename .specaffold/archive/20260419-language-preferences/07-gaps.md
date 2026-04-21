# 07 — Gap Check: language-preferences

_2026-04-19 · QA-analyst_

## STATUS note
- 2026-04-19 qa-analyst — gap-check complete — verdict NITS, 2 findings (0 must, 2 should)

---

## 1. Summary

**Verdict: NITS.** 28 of 28 non-dogfood ACs are fully traced in the diff; the two dogfood ACs (R9 AC9.a, AC9.b) are correctly deferred to verify / next-feature handoff. No `must` findings. Two `should` findings: (G1) README line 93 describes `lang.chat` as accepting "any BCP-47 tag" which implies forward-compat activation, but the hook only recognises `zh-TW` and `en` in v1 — all other values warn and default-off; (G2) PRD R7 AC7.b says "malformed config produces one warning line," but the implementation silently ignores most malformed shapes (awk returns empty → `case ""` → no warning). Both are documented architectural decisions (D7 tradeoff block), not regressions. Gap-fix commits (t53 + t66) are within PRD scope. Smoke 65/65 confirmed live. Zero agent-file diff confirmed live. Advancement to `/specflow:verify` is clear.

---

## 2. Coverage matrix

| R / AC | Tasks | Diff location | Status |
|---|---|---|---|
| R1 AC1.a (baseline English) | T2, T8 | `.claude/hooks/session-start.sh:259-288`; `test/t54_hook_config_absent.sh` | ✅ |
| R1 AC1.b (opt-in emits marker) | T2, T7, T9 | `session-start.sh:274-276`; `test/t55_hook_config_zh_tw.sh` | ✅ structural |
| R1 AC1.c (opt-out = removal) | T2, T8 | `session-start.sh:260` (`if [ -r "$cfg_file" ]` — absent = no marker) | ✅ |
| R2 AC2.a (rule English-only, frontmatter) | T1, T5 | `.claude/rules/common/language-preferences.md:1-7` | ✅ |
| R2 AC2.b (conditional pattern documented) | T1, T5 | `language-preferences.md:11` ("otherwise this rule is a no-op") | ✅ |
| R2 AC2.c (index row, sorted) | T1, T6 | `.claude/rules/index.md:13` (between classify-before-mutate and no-force-on-user-paths) | ✅ |
| R2 AC2.d (loads unconditionally) | T1, T5, T7 | Hook walks `common/` unconditionally; marker is separate from load path | ✅ |
| R3 AC3.a (six carve-outs a–f) | T1, T5 | `language-preferences.md:29-34` | ✅ |
| R3 AC3.b (no reverse directive) | T1, T5 | `language-preferences.md:36` ("No reverse directive applies") | ✅ |
| R4 AC4.a (zero agent diff) | T19 | `git diff main...HEAD -- .claude/agents/specflow/` = empty | ✅ |
| R4 AC4.b (seven roles named) | T1, T5 | `language-preferences.md:15` (all seven listed) | ✅ |
| R5 AC5.a (rejection path) | T3, T13, T18 | `bin/specflow-lint`; `test/t59_lint_cjk_hit.sh`; `test/t64_precommit_shim_wiring.sh` | ✅ structural |
| R5 AC5.b (clean-diff passes) | T3, T12 | `test/t58_lint_clean_diff.sh` | ✅ structural |
| R5 AC5.c (allowlist scope) | T3, T14, T15, T16 | `bin/specflow-lint` path allowlist + inline marker; `test/t60-t62` | ✅ |
| R5 AC5.d (bypass explicit) | T4, T18, T22 | `bin/specflow-seed` `foreign-pre-commit`; README bypass section | ✅ |
| R6 AC6.a (positive scope example) | T1, T5 | `language-preferences.md:42` ("PM's brainstorm summary…") | ✅ |
| R6 AC6.b (negative scope, 3 examples) | T1, T5 | `language-preferences.md:46,52,58` (CLI stdout, STATUS Notes, commit msg) | ✅ |
| R7 AC7.a (unknown value → warning) | T2, T10 | `session-start.sh:284` (`log_warn`); `test/t56_hook_config_unknown.sh` | ✅ structural |
| R7 AC7.b (malformed config → warning) | T2, T11 | `session-start.sh:282` (most malformed → silent; see G2) | ⚠️ partial |
| R7 AC7.c (missing file silent) | T2, T8 | `session-start.sh:260` (`if [ -r …]` guard; no else branch) | ✅ |
| R8 AC8.a (README section) | T20, T22 | `README.md:85-115` ("Language preferences" section with key + zh-TW example + rule link) | ✅ |
| R8 AC8.b (grep-verifiable, only README + rule file) | T20, T22 | `grep -rl lang.chat` outside feature/archive dirs → README only; rule file also contains the key | ✅ |
| R9 AC9.a (structural markers in 08-verify.md) | — | Deferred to QA-tester verify stage; not a task | — deferred |
| R9 AC9.b (next-feature confirmation) | — | Deferred to next feature after archive | — deferred |

---

## 3. Findings

### G1 — `should` · drifted · README line 93 claims "any BCP-47 tag" but v1 recognises only `zh-TW` and `en`

- **Severity**: should
- **Category**: drifted
- **R/AC**: R8 AC8.a (discoverability — README must name the config key and example value accurately); R1 (single opt-in config key)
- **Task**: T22
- **Diff file**: `README.md:93`
- **Evidence**: "Set `lang.chat` to `zh-TW` (or any BCP-47 tag) to enable chat-reply localisation." The hook (`session-start.sh:272`) recognises only `zh-TW|en`; any other BCP-47 tag (e.g. `ja`, `ko`) produces a warning and default-off, not activation. PRD Non-goals explicitly say "two values only in v1: `zh-TW` for chat, `en` fixed for artefacts. Additional languages (ja, ko, etc.) are explicit future work."
- **Recommendation**: Change "or any BCP-47 tag" to "other values produce a warning and default to English in v1" (or similar phrasing that accurately describes the v1 boundary). Advisory only — does not block verify because the config key, example value, and rule-file link in AC8.a are all correct; only the forward-compat phrasing overstates v1 scope. Alternatively, accept the README's forward-leaning phrasing as intentional product communication and annotate in 08-verify.md.

---

### G2 — `should` · drifted · PRD AC7.b requires a warning on malformed config; implementation silently degrades

- **Severity**: should
- **Category**: drifted
- **R/AC**: R7 AC7.b ("A syntactically broken config file produces default-off behaviour plus one warning line")
- **Task**: T2, T11
- **Diff file**: `.claude/hooks/session-start.sh:281-283`; `test/t57_hook_config_malformed.sh:120-126`
- **Evidence**: PRD R7 AC7.b (`03-prd.md:234`): "A syntactically broken config file produces default-off behaviour plus one warning line." The awk sniff is narrow: most malformed YAML shapes produce empty `cfg_chat`, which hits the `""` branch at `session-start.sh:281` — a silent no-op, no warning. A warning fires only if awk extracts a non-empty but unrecognised value from a partially-matching malformed file. The t57 test asserts "at most one line" on stderr (0 or 1), accepting the silent outcome. This is explicitly documented as a tradeoff in tech D7 ("Malformed YAML that yields empty `cfg_chat` → silent skip (no warning, no marker)") and in the T2 briefing (line 152) and t57 notes. The T11 task spec also clarifies: "Either outcome satisfies AC7.b as long as exit is 0 and no marker is emitted." However, the PRD says a warning is required, not optional.
- **Recommendation**: Advisory — the silent degradation is documented and the session is never blocked (exit 0 guaranteed), so the risk is low. The QA-tester's `08-verify.md` should explicitly annotate: "AC7.b: structural PASS for exit-0 and no-marker; warning on malformed YAML is not emitted for most broken shapes (awk returns empty → silent); acknowledged as D7 tradeoff." If a warning is desired for better operator debuggability, a one-line fix: emit `log_warn "config.yml: could not parse lang.chat — ignored"` before the `case` block when `cfg_chat` is empty AND the file is readable (distinguishing from the missing-file case via the `if [ -r "$cfg_file" ]` guard already in place). Not blocking advancement.

---

## 4. Gap-fix commits audit

Two gap-fix changes landed in commit `9ee0be1` (wave 3 checkpoint):

1. **t53 allowlist expansion** — `test/t53_marker_rule_coupling.sh` excluded `README.md` and `test/t51_rule_file_shape.sh` and `test/t55_hook_config_zh_tw.sh` from the unexpected-marker scan. These files legitimately reference `LANG_CHAT=zh-TW` for documentation or test purposes. This is within PRD scope (D5 coupling test; AC2.d). Not extra work.

2. **t66 YAML prefix-match** — `test/t66_readme_doc_section.sh` relaxed exact-match `"  chat: zh-TW"` to prefix-match `"  chat: zh-TW"*` to accommodate the trailing D9 comment (`# or "en" ...`). This is a test-fidelity fix within PRD scope (AC8.a). Not extra work.

Both fixes are traceable to the original tasks (T7/T20) and do not introduce new PRD scope.

---

## 5. Extra-work scan

All 30 changed files in the diff (per `git diff --stat`) trace to tasks T1–T22. No file outside the PRD-scoped impact map was touched except `.spec-workflow/features/20260419-language-preferences/` (the spec docs themselves, expected). No agent file was changed. No undocumented binary was added. No extra work found.

---

## 6. Dogfood paradox annotation (R9)

Per `shared/dogfood-paradox-third-occurrence.md` (7th occurrence), the following ACs are structural-only during this feature's verify stage and must be annotated as such in `08-verify.md`:

- **AC1.b**: hook emits marker — verifiable structurally (t55 sandbox); runtime subagent zh-TW reply deferred.
- **AC5.a, AC5.b**: guardrail fires / passes — verifiable structurally (t59/t58 sandbox commits); real pre-commit on live session commit deferred.
- **AC7.a, AC7.b, AC7.c**: warning / silent behaviors — verifiable structurally (t56/t57/t54 sandboxes); live hook stderr deferred.
- **AC9.b**: next-feature STATUS Notes confirmation — handoff AC, not verifiable in this feature.

The verify stage must not treat structural PASS as full runtime PASS for the above ACs.

---

## 7. Verdict

## Verdict: NITS

No `must` findings. Two `should` findings (G1, G2), both advisory and traceable to documented architectural decisions. Advancement to `/specflow:verify` is unblocked.

**Recommendation**: Proceed to `/specflow:verify`. QA-tester must annotate AC1.b, AC5.a, AC5.b, AC7.a, AC7.b, AC7.c as "structural PASS; runtime deferred to next feature after session restart" per R9 AC9.a. G2 (malformed-config silent) should be noted in 08-verify.md under AC7.b. G1 (BCP-47 README phrasing) is advisory; accept or fix at QA-tester's discretion.
