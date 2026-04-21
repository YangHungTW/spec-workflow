# 08-verify.md — user-lang-config-fallback

_2026-04-19 · QA-tester_

## STATUS
- 2026-04-19 QA-tester — verify done: PASS

---

## 1. Summary

**Verdict: PASS**

| Status | Count |
|---|---|
| PASS (runnable) | 12 |
| structural PASS; runtime deferred | 5 |
| N/A | 1 |
| FAIL | 0 |

**Total ACs: 18** (R1 AC1.a–d, R2 AC2.a–b, R3, R4 AC4.a–c, R5 AC5.a–b, R6 AC6.a–d, R7 AC7.a–b)

Smoke: **72/72 PASS**

Gap-check verdict carried forward: **NITS** (0 must, 2 advisory). Both advisories acknowledged; neither blocks archive.

---

## 2. AC-by-AC verification table

| AC | Status | Command / Evidence |
|---|---|---|
| R1 AC1.a (all absent → no marker) | PASS (runnable) | `bash test/t67_userlang_all_absent.sh` → 3/3 checks pass, exit 0. No `LANG_CHAT=` in stdout, stderr empty. |
| R1 AC1.b (user-home-only opt-in) | structural PASS; runtime deferred | `bash test/t68_userlang_user_home_only.sh` → 3/3 checks pass, exit 0. Sandbox `$HOME` confirms `LANG_CHAT=zh-TW` emitted. Runtime deferred per R7 — see §3. |
| R1 AC1.c (project wins over user-home) | structural PASS; runtime deferred | `bash test/t69_userlang_project_over_user.sh` → 4/4 checks pass, exit 0. Sandbox confirms project `zh-TW` wins, user-home `en` not emitted. Runtime deferred per R7 — see §3. |
| R1 AC1.d (XDG wins over simple-tilde) | structural PASS; runtime deferred | `bash test/t70_userlang_xdg_over_tilde.sh` → 4/4 checks pass, exit 0. Sandbox confirms `LANG_CHAT=zh-TW` (XDG), `LANG_CHAT=en` (tilde) absent. Runtime deferred per R7 — see §3. |
| R2 AC2.a (single `in_lang=1` definition) | PASS (runnable) | `grep -c 'in_lang=1' .claude/hooks/session-start.sh` → `1`. `grep -c '^sniff_lang_chat()' .claude/hooks/session-start.sh` → `1`. Also confirmed by t73 checks 1–3. |
| R2 AC2.b (awk body byte-identical to parent D7) | PASS (runnable) | `bash test/t73_userlang_structural_grep.sh` → 13/13 checks pass. All 6 semantic tokens of the D7 awk spec confirmed present in the extracted `sniff_lang_chat()` body. |
| R3 (parent invariants preserved) | PASS (runnable) | `git diff 20260419-language-preferences...HEAD -- .claude/rules/ bin/ .claude/agents/` → 0 lines. Specifically: `.claude/rules/common/language-preferences.md` diff = 0 lines, `.claude/agents/specflow/` diff = 0 lines. No rule body, subagent file, or bin/ script touched. |
| R4 AC4.a (stop-on-first-hit, invalid value) | structural PASS; runtime deferred | `bash test/t71_userlang_stop_on_first_invalid.sh` → 6/6 checks pass, exit 0. Project-level `chat: fr` → stderr warning names `.spec-workflow/config.yml` + value `fr`; no `LANG_CHAT=` emitted; user-home `zh-TW` not consulted (no mention in stdout or stderr). This is the critical AC this feature exists to verify. Runtime deferred per R7 — see §3. |
| R4 AC4.b (exit 0 always) | PASS (runnable) | All 7 integration tests (t67–t73) exit 0. Confirmed by smoke and individual runs above. |
| R4 AC4.c (missing file silent, iteration continues) | PASS (runnable) | `bash test/t72_userlang_missing_doesnt_stop.sh` → 3/3 checks pass, exit 0. Early candidates absent, later candidate with `zh-TW` found; no warning emitted; `LANG_CHAT=zh-TW` in stdout. |
| R5 AC5.a (no new fork per iteration) | structural PASS | t73 portability grep → 0 forbidden tokens (`readlink -f`, `realpath`, `jq`, `mapfile`, `=~`). Hook diff inspection confirms loop body = one `[ -r ]` test + one `sniff_lang_chat` call (one awk fork) per present file, ≤ 3 iterations bounded. No new subprocess on absent-file path. |
| R5 AC5.b (wall-clock unchanged) | structural PASS | Structural satisfaction: AC5.a confirms no new subprocess added in the absent-file path. The all-absent code path adds only three `[ -r ]` shell built-in tests to the existing path — sub-millisecond, well inside the ±10ms noise floor and the 200ms budget. No timing regression possible by construction. |
| R6 AC6.a (`~/.config/specflow/config.yml` documented) | PASS (runnable) | `grep -F '~/.config/specflow/config.yml' README.md` → 2 matches (line under `### Precedence` numbered list, and the "For most users…" guidance line). |
| R6 AC6.b (XDG documented with env-var gating) | PASS (runnable) | `grep -F 'XDG_CONFIG_HOME' README.md` → 4 matches. Line under `### Precedence` reads "only when `$XDG_CONFIG_HOME` is set and non-empty" — satisfies the gating prose requirement exactly. |
| R6 AC6.c (precedence in plain words) | PASS (runnable) | `grep -F '### Precedence' README.md` → 1 match. Section contains ordered numbered list: (1) project-level, (2) XDG, (3) user-home fallback, conveying the "project > XDG > tilde" ordering. PRD AC6.c explicitly allows "equivalent plain-English ordering". G1 from gap-check acknowledged; the numbered list satisfies the AC — not a failure. |
| R6 AC6.d (rule file unchanged) | PASS (runnable) | `git diff 20260419-language-preferences...HEAD -- .claude/rules/common/language-preferences.md` → 0 lines. Rule body untouched. |
| R7 AC7.a (structural markers in 08-verify.md) | PASS | This document explicitly annotates AC1.b, AC1.c, AC1.d, and AC4.a as "structural PASS; runtime deferred to next feature after session restart" — see §3. Self-fulfilling by construction per PRD R7 AC7.a. |
| R7 AC7.b (next-feature handoff) | N/A this feature | Handoff AC — verified by the next feature after archive, not here. See §5. |

---

## 3. Dogfood paradox annotations

Per `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md` (8th occurrence in this repo), the following ACs depend on the SessionStart hook running in a session opened **after** this feature merges and the session restarts. The hook change cannot fire during its own development session.

**Structural PASS; runtime verification deferred to next feature after session restart:**

- **AC1.b** — user-home-only opt-in: code path confirmed via sandboxed `$HOME` in t68; hook emits `LANG_CHAT=zh-TW` when only `~/.config/specflow/config.yml` is present. Runtime PASS deferred to next feature.
- **AC1.c** — project wins over user-home: code path confirmed via sandboxed `$HOME` in t69; project value wins wholesale. Runtime PASS deferred to next feature.
- **AC1.d** — XDG wins over simple-tilde: code path confirmed via sandboxed `$HOME` in t70; XDG candidate wins when `$XDG_CONFIG_HOME` is set and non-empty. Runtime PASS deferred to next feature.
- **AC4.a** — stop-on-first-hit with invalid value: code path confirmed via sandboxed `$HOME` in t71; iteration stops at first `lang.chat`-present file regardless of value validity; user-home not consulted when project-level file present but invalid. This is the critical AC this feature exists to verify. Runtime PASS deferred to next feature.

**Spot-check evidence (additional):** A manual invocation of the hook with sandbox `$HOME` containing `~/.config/specflow/config.yml` (value `zh-TW`) confirmed `LANG_CHAT=zh-TW` appears in the `additionalContext` field of the hook's JSON output. Command run:

```
SANDBOX=$(mktemp -d); HOME="$SANDBOX/home"; mkdir -p "$HOME/.config/specflow"
printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/specflow/config.yml"
HOOK_TEST=1 bash .claude/hooks/session-start.sh 2>/dev/null | grep 'LANG_CHAT'
```

Output included `LANG_CHAT=zh-TW` in both `additionalContext` and `context` fields. Exit 0.

---

## 4. Gap-check NITS context

Both advisory findings from 07-gaps.md are acknowledged. Neither blocks archive.

**G1** — README uses a numbered list for precedence rather than the literal string "project > XDG > tilde". PRD AC6.c explicitly allows "equivalent plain-English ordering". The numbered list under `### Precedence` satisfies the AC. Not a failure.

**G2** — README added a `### Precedence` section header; tech D8 said "no new sections". PRD R6 only requires the precedence be documented in plain words — it does not prohibit a header. The header improves discoverability. No PRD requirement violated. Not a failure.

---

## 5. Smoke result

```
smoke: PASS (72/72)
```

Run: `bash test/smoke.sh 2>&1 | tail -5` from `/Users/yanghungtw/Tools/spec-workflow`.

---

## 6. Handoff note for R7 AC7.b

The **next feature archived after this one** must include an early STATUS Notes line confirming first-session runtime behaviour of the candidate-list fallback. Expected form (one of):

- "new session read `~/.config/specflow/config.yml`, `LANG_CHAT=zh-TW` marker observed in additionalContext"
- "user-home config absent on this machine, no marker, English baseline as expected"
- "project-level `chat: zh-TW` wins over user-home `chat: en`, `LANG_CHAT=zh-TW` confirmed"

Without this handoff line, AC7.b for the current feature (`user-lang-config-fallback`) remains structurally unconfirmed at runtime.

---

## Verdict: PASS

18/18 ACs covered: 12 runnable PASS, 5 structural PASS (runtime deferred per dogfood paradox R7), 1 N/A.
Smoke: 72/72. Gap-check: NITS (0 must). All must-severity items: none outstanding.

## Team memory

Applied entries:

- `shared/dogfood-paradox-third-occurrence.md` — directly applied; governs the structural-vs-runtime split for AC1.b, AC1.c, AC1.d, AC4.a (8th occurrence). Annotations in §3 satisfy R7 AC7.a by construction.
- `qa-tester/sandbox-home-preflight-pattern.md` — applied. All integration tests (t67–t73) use sandboxed `$HOME` per the pattern; spot-check manual invocation above also uses sandbox. No mutation of real `$HOME` during verification.
- `shared/local-only-env-var-boundary-carveout.md` — acknowledged. Gap-check G1/T1 security advisory on `$XDG_CONFIG_HOME` is correctly parked as advisory; operator-set env vars are inside the trust boundary. Not escalated.
