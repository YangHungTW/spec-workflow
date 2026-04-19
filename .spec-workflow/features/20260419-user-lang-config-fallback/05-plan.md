# Plan — user-lang-config-fallback

_2026-04-19 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` (global) — load-bearing for
  Wave 2. Test files (t67–t73) are each their own file and parallel-safe with
  each other; `README.md` and `test/smoke.sh` each become single-editor tasks
  distinct from the test-file set.
- `tpm/parallel-safe-append-sections.md` (global) — applied to `test/smoke.sh`
  (append new registration lines), `STATUS.md` Notes appends, and
  `06-tasks.md` checkbox flips. Standard keep-both mechanical resolution; do
  NOT serialize Wave 2 on those grounds.
- `tpm/checkbox-lost-in-parallel-merge.md` (local) — Wave 2 width is ~10
  tasks. Within the documented 1–2 checkbox loss band. Post-wave audit stays
  in place.
- `tpm/briefing-contradicts-schema.md` (local) — tasks-stage MUST paste
  verbatim: (a) the tech D7 hook diff sketch (`sniff_lang_chat` body + the
  candidate-list loop) into T1's scope; (b) the PRD R1 ordered-list text into
  T1 and the test-task scopes; (c) the tech D8 README paragraph shape into
  T10's scope. No paraphrase.
- `tpm/same-file-sequential-wave-depth-accepted.md` (global) — does NOT force
  a multi-wave decomposition here. The hook edit (T1) is a single coherent
  edit in one file with no dispatcher-arm expansion; one task in one wave is
  the right shape.
- `tpm/tasks-doc-format-migration.md` (local) — does not apply (no format
  migration in flight; fresh tasks-doc authoring next).
- `shared/dogfood-paradox-third-occurrence.md` — **8th occurrence**
  (parent was 7th). Per R7, every runtime-observable AC (AC1.b, AC1.c,
  AC1.d, AC4.a) is structural PASS only during this feature's verify; runtime
  PASS deferred to the first feature archived after this one. Plan keeps the
  install surface tiny (one hook block edit + one README paragraph) so
  structural tests cover it completely.
- `shared/skip-inline-review-scope-confirmation.md` (global) — carries
  forward as a TPM/dev guardrail only if `--skip-inline-review` is invoked
  during implement; not applicable at plan stage.

## 1. Goal recap

Extend the parent feature's SessionStart hook (`20260419-language-preferences`)
so `lang.chat` can be authored once per user-home machine instead of once per
repo. The hook walks an ordered, ≤ 3-entry candidate list — project
`.spec-workflow/config.yml` → `$XDG_CONFIG_HOME/specflow/config.yml` (only
when the env var is set and non-empty) → `$HOME/.config/specflow/config.yml`
— and emits the parent's `LANG_CHAT=<value>` marker from the first file whose
`lang.chat` key is present. Parent's `awk` sniff is wrapped in a
`sniff_lang_chat` helper (byte-identical body) and invoked inside the loop;
first file that held the key wins (valid → emit marker; invalid → one stderr
warning + default-off + stop). All parent invariants (default-off baseline,
artefact-English, bash 3.2 portability, no per-agent toggle, team override
when both files exist) stay intact. README grows one paragraph documenting
the precedence. Zero new bin scripts, zero new rule files, zero
settings.json changes, zero agent diffs.

## 2. Building blocks

Three building blocks. All are tightly scoped; B1 is the only runtime-
behaviour change, B2 and B3 are verification + discoverability.

### B1 — SessionStart hook candidate-list walk (runtime behaviour)

- **Intent**: edit `.claude/hooks/session-start.sh` to (a) add a
  `sniff_lang_chat <path>` helper above the `Main` section that wraps the
  parent's awk block byte-identically per R2 AC2.b; (b) replace the
  parent's single-path read with an ordered candidate list and a for-loop
  that stops at the first file whose `lang.chat` key is present; (c)
  dispatch the captured value via `if/elif` (avoiding `case` inside
  subshells per bash-3.2 portability). Fail-safe frame (`set +e` +
  `trap 'exit 0'`) preserved; warning message names the source file
  (`$cfg_source: ...`).
- **PRD covers**: R1 (AC1.a, AC1.b, AC1.c, AC1.d); R2 (AC2.a, AC2.b); R4
  (AC4.a, AC4.b, AC4.c); R5 (AC5.a, AC5.b); R3 by preservation (no change
  to directive semantics, subagent coverage, commit-time guardrail, or
  English-scope invariants).
- **Tech grounded**: D1 (XDG-aware 3-path), D2 (`[ -r … ]` probe), D3
  (`[ -n "${XDG_CONFIG_HOME:-}" ]`), D4 (`sniff_lang_chat` helper), D5
  (space-separated `for` loop), D6 (stop-on-first-hit semantics), D7
  (verbatim hook-edit diff sketch).
- **Primary files**: `.claude/hooks/session-start.sh` (EXTEND — single
  coherent edit of ≈ 25 net lines split between the new helper function
  above `Main` and the rewritten candidate-read block between digest
  assembly and JSON-emit).
- **Prerequisites**: none at the code level. Parent feature is already
  merged; the hook file already contains the awk block to be wrapped.

### B2 — Structural + integration tests (verification surface)

- **Intent**: ship one test file per distinguishable runtime path through
  B1's edit, plus the two R2 structural tests (single awk definition;
  awk body byte-identical to parent). All integration tests sandbox `$HOME`
  (and `$XDG_CONFIG_HOME` where relevant) per
  `.claude/rules/bash/sandbox-home-in-tests.md`; all run the hook under
  `HOOK_TEST=1` and parse the emitted JSON digest for the marker line.
- **PRD covers**: R1 AC1.a (t67); R1 AC1.b (t68); R1 AC1.c (t69); R1 AC1.d
  (t70); R4 AC4.a (t71 — stop-on-first-hit, the reworded AC); R4 AC4.c
  (t72 — missing file does not stop iteration); R2 AC2.a + AC2.b (t73).
  R5 AC5.b (wall-clock unchanged within noise) is covered by inline
  inspection during T1 review rather than a dedicated test — measuring
  ±10ms in bash on a shared CI is noisy; the AC is satisfied by the
  structural guarantee in R5 AC5.a (no new fork per iteration), which t73
  covers via grep. Cross-ref §4 Risk R4.
- **Tech grounded**: §6 implementation hints for TPM (the t70–t78
  illustrative list, renumbered here to t67–t73). Every integration test
  follows the parent t54–t57 sandbox-`$HOME` + `HOOK_TEST=1` pattern.
- **Primary files**:
  - `test/t67_userlang_all_absent.sh` (CREATE) — AC1.a + AC4.c.
  - `test/t68_userlang_user_home_only.sh` (CREATE) — AC1.b.
  - `test/t69_userlang_project_over_user.sh` (CREATE) — AC1.c.
  - `test/t70_userlang_xdg_over_tilde.sh` (CREATE) — AC1.d.
  - `test/t71_userlang_stop_on_first_invalid.sh` (CREATE) — AC4.a
    (reworded; stop-on-first-hit-even-invalid, user's valid value NOT
    consulted).
  - `test/t72_userlang_missing_doesnt_stop.sh` (CREATE) — AC4.c
    clarification (absent early candidates do NOT stop iteration; only a
    present `chat:` key stops).
  - `test/t73_userlang_structural_grep.sh` (CREATE) — AC2.a
    (`grep -c 'in_lang=1'` returns 1) + AC2.b (awk body byte-identical
    to parent's merged commit — extract the program text and diff against
    the parent's line-range).
- **Prerequisites**: B1 (the hook edit is what every integration test
  exercises; structural tests grep the edited hook).

### B3 — README "Language preferences" section extension + smoke registration (discoverability surface)

- **Intent**: extend the existing "Language preferences" section in
  `README.md` with one paragraph naming all three candidate paths and
  stating the precedence (`project > XDG > tilde`), per tech D8 paragraph
  shape. Register the seven new tests in `test/smoke.sh`. The rule file
  `.claude/rules/common/language-preferences.md` is **untouched** per R6
  AC6.d (verified by a one-line git-diff grep, not a dedicated test — the
  diff presence or absence is visible at the final commit).
- **PRD covers**: R6 (AC6.a, AC6.b, AC6.c, AC6.d).
- **Tech grounded**: D8 (README paragraph shape — append, do not rewrite).
- **Primary files**:
  - `README.md` (EXTEND — append one paragraph to the existing "Language
    preferences" section; tech D8 provides the exact text template, no new
    section header).
  - `test/smoke.sh` (EXTEND — single-editor task to register t67–t73, 7
    new tests; prior count 66 → new count 73).
- **Prerequisites**: B2 for the test-file names (smoke.sh registration
  lines reference them by path); B1 is the behaviour the README describes.

## 3. Wave plan

Two waves. DAG:

```
  W1 (foundation — 1 task)
   └── B1: hook candidate-list edit

  W2 (tests + docs — parallel after W1)
   ├── B2: t67 … t73 (7 test files, each its own file)
   └── B3: README paragraph + smoke.sh registration (2 single-editor tasks)
```

### Wave 1 — hook edit (1 task)

**Block**: B1.

**Parallelism**: single task; single file. No peer tasks in this wave.

**Gating to advance to W2**:
- `bash -n .claude/hooks/session-start.sh` clean.
- `grep -c 'in_lang=1' .claude/hooks/session-start.sh` returns exactly `1`
  (R2 AC2.a) — this is a pre-flight check at implement time, verified
  again structurally by t73 in W2.
- Fail-safe discipline preserved: `set +e` and
  `trap 'exit 0' ERR INT TERM` framing unchanged at the top of the file.
- No new subprocess inside the loop body beyond the existing
  `sniff_lang_chat` call (which invokes awk) — static read of the diff
  satisfies R5 AC5.a.

**Rationale**: every test in W2 invokes the hook. Without the edited hook,
t67–t72 have nothing to exercise and t73 has nothing to grep. W2 cannot
usefully begin before W1 lands. The edit is one coherent ≈ 25-line change;
splitting into "add helper" + "rewrite loop" + "rewrite dispatch" would
over-decompose a diff that reviews easier as one unit (tech §6 explicit:
"Single implement task for the hook edit + helper function. Splitting is
over-decomposition for a 25-line diff.").

### Wave 2 — tests + docs (~9 parallel)

**Blocks**: B2 (seven test files) + B3 (README + smoke.sh registration).

**Parallelism**: high, at the file level. The seven test files are each
their own file — fully parallel-safe with each other. `README.md` and
`test/smoke.sh` are each single-editor tasks on files not touched by any
other task in this wave. Per `parallel-safe-requires-different-files`, all
nine tasks are parallel-safe.

**Expected append-only collisions** (per `parallel-safe-append-sections`):
- `test/smoke.sh`: single editor (T11) — zero peer collision inside the
  wave.
- `STATUS.md` Notes: every merged task appends a line; mechanical
  keep-both expected.
- `06-tasks.md` checkboxes: nine tasks flipping checkboxes concurrently;
  per `checkbox-lost-in-parallel-merge.md`, expect 1–2 checkbox losses at
  this width (9-way was the prior repo ceiling and lost ~2). Post-wave
  audit per the rule.

**Gating to advance to archive-stage**:
- `bash test/smoke.sh` green — prior 66 + 7 new = 73 total.
- R1 ACs (a–d), R2 ACs (a, b), R4 ACs (a, c) all covered by a passing
  test in t67–t73.
- `README.md` contains the three precedence strings (`grep -F` for
  `~/.config/specflow/config.yml`, `XDG_CONFIG_HOME`, and a precedence
  phrase of the shape "project > XDG > tilde" or equivalent plain-English
  ordering per AC6.c).
- `git diff` at the final commit shows zero lines under
  `.claude/rules/common/language-preferences.md` (R6 AC6.d — verified by
  inspection at verify stage, not by a dedicated test).
- `git diff` at the final commit shows zero lines under
  `.claude/agents/specflow/**` (parent R4 preservation, inherited via R3
  — verified by inspection at verify stage).

**Rationale**: every prerequisite has landed (hook block from W1 is what
t67–t72 exercise and what t73 greps; helper function signature from W1 is
what the README paragraph describes). All test files are different so no
same-file edit collisions inside the wave. `README.md` and `smoke.sh` each
get a single-editor task, sidestepping append-only collisions entirely on
those two files.

## 4. Critical files

Consolidated add / modify table. Paths are exact from tech doc §7.

| File | Action | Block | Wave | Purpose |
|---|---|---|---|---|
| `.claude/hooks/session-start.sh` | **EXTEND** | B1 | W1 | Add `sniff_lang_chat <path>` helper above `Main` section (awk body byte-identical to parent's lines 261–269); replace the single-path read block (parent lines 258–287) with an ordered candidate list + `for`-loop that stops at the first file whose `lang.chat` key is present; dispatch captured value via `if/elif` (valid token → append `LANG_CHAT=<v>` to digest; invalid → `log_warn "$cfg_source: ..."` + default-off). Fail-safe frame preserved. |
| `test/t67_userlang_all_absent.sh` | **CREATE** | B2 | W2 | Integration: sandbox `$HOME` with no project, no `$XDG_CONFIG_HOME` set, no `~/.config/specflow/config.yml`; run hook under `HOOK_TEST=1`; assert digest contains NO `LANG_CHAT=` line, stderr clean, exit 0. Covers R1 AC1.a + R4 AC4.c (missing is silent). |
| `test/t68_userlang_user_home_only.sh` | **CREATE** | B2 | W2 | Integration: sandbox with `$HOME/.config/specflow/config.yml` = `lang:\n  chat: zh-TW\n`, no project, no XDG; assert digest contains `LANG_CHAT=zh-TW`, stderr clean. Covers R1 AC1.b. |
| `test/t69_userlang_project_over_user.sh` | **CREATE** | B2 | W2 | Integration: sandbox with `.spec-workflow/config.yml` = `chat: zh-TW` AND `$HOME/.config/specflow/config.yml` = `chat: en`; assert digest contains `LANG_CHAT=zh-TW` (project wins wholesale). Covers R1 AC1.c. |
| `test/t70_userlang_xdg_over_tilde.sh` | **CREATE** | B2 | W2 | Integration: sandbox with `XDG_CONFIG_HOME=$SANDBOX/xdg`, `$XDG_CONFIG_HOME/specflow/config.yml` = `chat: zh-TW`, `$HOME/.config/specflow/config.yml` = `chat: en`, no project; assert digest contains `LANG_CHAT=zh-TW`. Covers R1 AC1.d. |
| `test/t71_userlang_stop_on_first_invalid.sh` | **CREATE** | B2 | W2 | Integration: sandbox with `.spec-workflow/config.yml` = `chat: fr` AND `$HOME/.config/specflow/config.yml` = `chat: zh-TW`; assert (i) digest contains NO `LANG_CHAT=` line (user's valid value NOT consulted), (ii) exactly one stderr warning line naming `.spec-workflow/config.yml` and the value `fr`, (iii) exit 0. Covers R4 AC4.a + R4 AC4.b (reworded per PRD [CHANGED 2026-04-19]). |
| `test/t72_userlang_missing_doesnt_stop.sh` | **CREATE** | B2 | W2 | Integration: sandbox with `.spec-workflow/config.yml` absent, `$XDG_CONFIG_HOME` unset, `$HOME/.config/specflow/config.yml` = `chat: zh-TW`; assert digest contains `LANG_CHAT=zh-TW`, stderr clean (no warnings for missing earlier candidates), exit 0. Covers R4 AC4.c (missing does NOT stop iteration; only a present key stops). |
| `test/t73_userlang_structural_grep.sh` | **CREATE** | B2 | W2 | Static: (a) `grep -c 'in_lang=1' .claude/hooks/session-start.sh` returns exactly `1` (AC2.a); (b) extract the awk program text inside `sniff_lang_chat` and diff against the parent's awk program text at lines 261–269 of the parent's merged commit — assert zero character differences (AC2.b). No fork inside the loop beyond the existing awk invocation (structural confirmation of R5 AC5.a). |
| `README.md` | **EXTEND** | B3 | W2 | Append one paragraph to the existing "Language preferences" section per tech D8 shape: three-bullet candidate list (project, XDG with env-var gating, tilde); single precedence sentence of the form "project > XDG > tilde" (or plain-English equivalent per AC6.c); all-absent = English baseline. Existing lead sentence and YAML example unchanged. No new section header. |
| `test/smoke.sh` | **EXTEND** | B3 | W2 | Single-editor task: register t67–t73 (7 new tests). Prior count 66 → new count 73. |
| `.claude/rules/common/language-preferences.md` | **UNCHANGED** | — | — | Per R6 AC6.d; verified by inspection of the final commit diff at verify stage. |
| `.claude/agents/specflow/**` | **UNCHANGED** | — | — | Parent R4 preservation, inherited via R3; verified by inspection. |
| `.spec-workflow/config.yml` | **NOT SHIPPED** | — | — | User-authored, local-only. README documents the schema; the tool never writes it. |
| `~/.config/specflow/config.yml` | **NOT SHIPPED** | — | — | User-home, authored by user per machine. README documents the location. |

## 5. Risk log

Four feature-specific risks with mitigations.

### R1 — Hook edit introduces a regression in parent's existing behaviour

The parent's single-path read is being replaced by a candidate-list loop. A
mistake in the loop's exit conditions, in the new `if/elif` dispatch, or in
the `sniff_lang_chat` helper's return shape could silently break parent AC1.a
(English baseline when all configs absent) or the project-level branch of
parent AC1.b (project-level `zh-TW` still emits marker).

- **Mitigation**: t73 asserts the awk body is byte-identical to the parent's
  merged commit (AC2.b), catching any accidental edit of the parsing layer.
  t67 re-exercises the all-absent baseline (AC1.a equivalent at the 3-path
  list). t68 and t69 together re-exercise the project-level success path
  that the parent's t55 (`t55_hook_config_zh_tw.sh`) covered — t69
  specifically asserts the project-level branch still wins when both files
  are present. The edit lives inside the existing `set +e` + `trap 'exit 0'`
  frame; unreadable or malformed files still skip silently, preserving
  parent R7 behaviour.

### R2 — `$XDG_CONFIG_HOME` detection false positive on empty-string setting

Some shell setups export `XDG_CONFIG_HOME=""` rather than unsetting it. A
naive `[ -n "$XDG_CONFIG_HOME" ]` test would still skip (non-empty check),
but the combination with `set -u` elsewhere could trigger an unbound error.

- **Mitigation**: tech D3 specifies `[ -n "${XDG_CONFIG_HOME:-}" ]` — the
  `:-` default expansion treats unset and empty identically and is safe
  under both `set +e` (current hook mode) and a hypothetical future `set -u`.
  t70 explicitly sets `XDG_CONFIG_HOME` non-empty and asserts it wins; t67,
  t68, t69, t72 each test with `XDG_CONFIG_HOME` unset to verify the
  simple-tilde path is consulted correctly in that mode. No dedicated test
  for the empty-string edge case; the POSIX `-n` idiom is well-established
  and the tech doc rationale suffices.

### R3 — Dogfood paradox (8th occurrence — still structural only)

Per R7 AC7.a and
`.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`, the
SessionStart hook logic shipped by this feature cannot fire during its own
development session (the session started before the hook change merged).
All runtime-observable ACs (AC1.b, AC1.c, AC1.d, AC4.a) are structural PASS
only during this feature's `verify` stage; runtime PASS is observed on the
first session opened after archive + session restart.

- **Mitigation**: `08-verify.md` must annotate AC1.b, AC1.c, AC1.d, AC4.a
  with "structural PASS; runtime deferred to next feature after session
  restart" per R7 AC7.a. The first feature archived after this one includes
  an early STATUS Notes line confirming first-session runtime behaviour per
  R7 AC7.b — handoff AC, not verifiable in this feature. Structural
  coverage is complete: t67–t73 plus the git-diff inspection of
  `.claude/rules/common/language-preferences.md` and `.claude/agents/`
  cover every AC except AC7.b.

### R4 — R5 AC5.b (wall-clock unchanged within noise) is not a test-enforceable AC

Measuring hook wall-clock within ±10 ms on a shared CI is noisy: container
scheduling jitter routinely exceeds that envelope. A dedicated perf test
would flake.

- **Mitigation**: R5 AC5.a (structural — no new fork per iteration) is
  the machine-checked guarantee; t73's grep for `in_lang=1` count plus the
  static inspection of the loop body confirms at most one `[ -r … ]` test,
  one shell-variable expansion, and (on present files only) one existing
  awk invocation. No new subprocess, no new fork. R5 AC5.b follows by
  construction from AC5.a and the hook's existing structure; it is
  satisfied by review at T1's merge and does not require a runtime
  measurement test. Cross-ref `.claude/rules/reviewer/performance.md`
  rules 1 + 6 (no shell-out in loops; minimise fork/exec).

## 6. Verification map

Each PRD requirement → ACs → test surface → structural vs runtime annotation.

| R | AC | Test file | Surface | Annotation |
|---|---|---|---|---|
| R1 | AC1.a (all-absent baseline) | t67 | integration (sandbox `HOOK_TEST=1`) | Structural PASS; runtime deferred (R7). |
| R1 | AC1.b (user-home-only opt-in) | t68 | integration | Structural PASS; runtime deferred (R7). |
| R1 | AC1.c (project over user) | t69 | integration | Structural PASS; runtime deferred (R7). |
| R1 | AC1.d (XDG over tilde) | t70 | integration | Structural PASS; runtime deferred (R7). |
| R2 | AC2.a (single `in_lang=1`) | t73 | static (grep on hook file) | Structural — fully verifiable. |
| R2 | AC2.b (awk body byte-identical) | t73 | static (extract + diff against parent commit) | Structural — fully verifiable. |
| R3 | (all sub-bullets — parent invariants preserved) | — | inspection at verify (no agent diff, no rule-file diff, no directive-semantics change) | Structural — enforced by diff inspection of final commit. |
| R4 | AC4.a (stop-on-first-hit-even-invalid, reworded) | t71 | integration | Structural PASS; runtime deferred (R7). |
| R4 | AC4.b (session never blocked) | t67, t68, t69, t70, t71, t72 | integration (every test asserts exit 0) | Structural. |
| R4 | AC4.c (missing is silent; does not stop iteration) | t67 (all-absent silent), t72 (missing early candidates do not warn or stop) | integration | Structural. |
| R5 | AC5.a (structural — no new fork per iteration) | t73 (single `in_lang=1` count + inspection at T1 merge) | static | Structural — fully verifiable. |
| R5 | AC5.b (wall-clock unchanged within noise) | — (no dedicated test; satisfied by construction from AC5.a, confirmed at T1 review) | static/inspection | Structural — enforced at T1 review rather than test. Cross-ref Risk R4. |
| R6 | AC6.a (simple-tilde documented) | — (inspection: `grep -F '~/.config/specflow/config.yml' README.md`) | static | Structural — verify-stage grep rather than dedicated test. |
| R6 | AC6.b (XDG documented with env-var gating) | — (inspection: `grep -F 'XDG_CONFIG_HOME' README.md`) | static | Structural — verify-stage grep. |
| R6 | AC6.c (precedence in plain words) | — (inspection: grep for "project > XDG > tilde" or equivalent) | static | Structural — verify-stage grep. |
| R6 | AC6.d (rule file unchanged) | — (inspection: `git diff` on final commit shows zero lines under `.claude/rules/common/language-preferences.md`) | static | Structural — verify-stage diff inspection. |
| R7 | AC7.a (structural markers in verify) | — | documentation discipline (QA-tester at verify stage) | Structural — enforced by verify checklist, not by a test. |
| R7 | AC7.b (next-feature handoff) | — | handoff AC | Next-feature responsibility. Not verifiable in this feature. |

**Coverage summary**: **7 new tests** (t67–t73) structurally cover **R1 (all
4 ACs), R2 (both ACs), R4 (all 3 ACs), R5 AC5.a**. R3 is preservation-by-
construction plus diff inspection at verify. R6 ACs are single-line grep
assertions over `README.md` at verify stage (no dedicated test files — the
assertions are more naturally stated as verify-stage grep checks than as
bash scripts in `test/`; this matches how parent AC8.a/b were verified
during that feature's verify stage). R5 AC5.b is satisfied by construction
from AC5.a (cross-ref Risk R4). R7 AC7.a is QA-tester verify-stage
documentation; R7 AC7.b is the next-feature handoff.

## 7. Constraints-from-rules carried forward (for tasks-stage)

Tasks-stage MUST surface these in each relevant task's scope:

- **Bash 3.2 portability** (`.claude/rules/bash/bash-32-portability.md`):
  applies to T1 (hook edit). No `readlink -f`, no `realpath`, no `jq`, no
  `mapfile`, no `[[ =~ ]]`. Tech D3 specifies `[ -n "${XDG_CONFIG_HOME:-}" ]`
  (POSIX default expansion); D5 specifies space-separated string + unquoted
  `for` loop (matches parent hook style and avoids array syntax); D6 + D7
  specify `if/elif` dispatch rather than `case` (avoids `case`-inside-
  subshell ambiguity flagged in the bash-32 rule). All three portability
  decisions are locked in tech D3/D5/D7; tasks-stage must paste the D7
  diff sketch verbatim into T1's scope per `briefing-contradicts-schema`.
- **Sandbox-HOME-in-tests** (`.claude/rules/bash/sandbox-home-in-tests.md`):
  applies to every integration test in B2 (t67–t72). Each test must open
  with `mktemp -d`, export `HOME="$SANDBOX/home"`, register
  `trap 'rm -rf "$SANDBOX"' EXIT`, and preflight-assert
  `case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac` before any hook
  invocation. t70 additionally sets `XDG_CONFIG_HOME="$SANDBOX/xdg"` and
  creates the path-prefixed config file under that root; t67, t68, t69,
  t72 each `unset XDG_CONFIG_HOME` (or never set it) to assert the simple-
  tilde path is consulted. t71 uses project-level under
  `$SANDBOX/<cwd>/.spec-workflow/` (per parent's t54–t57 pattern — tests
  `cd` into a sandbox cwd before running the hook).
- **Performance axis** (`.claude/rules/reviewer/performance.md`): applies
  to T1 (hook is on the SessionStart hot path; 200 ms budget). Rules 1
  (no shell-out in loops) and 6 (minimise fork/exec in hot paths) are
  structurally satisfied by tech D4's function-call-per-iteration shape
  (function call is in-process; awk is the only fork, bounded at ≤ 3
  invocations — same order as parent).
- **Security axis** (`.claude/rules/reviewer/security.md`): applies to T1
  only narrowly — input validation at boundary (hook classifies the
  config value against a closed enum `{zh-TW, en}`; unknown → warn +
  default-off). No shell-concatenation of untrusted input; no new path
  traversal surface (candidate paths are fixed strings and
  `$HOME`/`$XDG_CONFIG_HOME` — operator-set env vars, inside the trust
  boundary per `shared/local-only-env-var-boundary-carveout`).
- **Style axis** (`.claude/rules/reviewer/style.md`): applies to T1 (match
  neighbour convention in `session-start.sh` — `[ … ]` single-bracket
  POSIX, space-separated candidate strings per parent's `WALK_DIRS`
  pattern, helper function placed above the `Main` banner alongside other
  helpers per tech D4 rationale).

## 8. Dogfood paradox staging plan

Per R7 and `shared/dogfood-paradox-third-occurrence.md` (now 8th occurrence):

1. **During implement (W1–W2)**: this feature's own subagents write in
   English regardless of any `lang.chat` setting on the machine — the hook
   has not yet been modified during the development session, and even once
   modified, the active session picked up the pre-modification hook output.
   This is expected; the paradox is explicit in R7 and this plan.
2. **`08-verify.md` annotation** (QA-tester, stage after implement + gap-
   check): verdict must distinguish structural PASS from runtime PASS. At
   minimum annotate AC1.b, AC1.c, AC1.d, AC4.a as "structural PASS;
   runtime deferred to next feature after session restart." Direct
   quotation from R7 AC7.a.
3. **Next-feature runtime confirmation** (R7 AC7.b): the first feature
   archived after this one MUST include an early STATUS Notes line
   confirming first-session runtime behaviour of the user-home fallback —
   either "ran with `~/.config/specflow/config.yml` set, `LANG_CHAT=zh-TW`
   marker observed" or "ran with user-home config absent, no marker,
   English baseline as expected." Not verifiable in this feature; handoff
   AC only.
4. **Bypass discipline** (per
   `shared/skip-inline-review-scope-confirmation`): this feature does NOT
   ship an opt-out flag for its own development session. The natural bypass
   is "nothing different happens until the user restarts their Claude Code
   session." No STATUS trace required during implement because no bypass
   is invoked.

## 9. Handoff to `/specflow:tasks`

Target `06-tasks.md` with **~10 tasks across 2 waves**:

- **W1 (1 task)**: T1 — edit `.claude/hooks/session-start.sh`. Cannot
  parallelize (single file, single coherent ≈ 25-line diff).
- **W2 (9 parallel)**:
  - T2 — `test/t67_userlang_all_absent.sh` (CREATE).
  - T3 — `test/t68_userlang_user_home_only.sh` (CREATE).
  - T4 — `test/t69_userlang_project_over_user.sh` (CREATE).
  - T5 — `test/t70_userlang_xdg_over_tilde.sh` (CREATE).
  - T6 — `test/t71_userlang_stop_on_first_invalid.sh` (CREATE).
  - T7 — `test/t72_userlang_missing_doesnt_stop.sh` (CREATE).
  - T8 — `test/t73_userlang_structural_grep.sh` (CREATE).
  - T9 — `README.md` (single-editor, EXTEND one paragraph).
  - T10 — `test/smoke.sh` (single-editor, EXTEND with 7 registration
    lines).

All nine W2 tasks are parallel-safe (each edits a distinct file). Expected
append-only collisions on `STATUS.md` Notes and `06-tasks.md` checkboxes
are mechanical keep-both per `parallel-safe-append-sections`; post-wave
checkbox audit per `checkbox-lost-in-parallel-merge` (9-way width sits at
the prior repo ceiling where ~2 losses were observed).

**Tasks-stage must**:

- Paste verbatim (per `briefing-contradicts-schema`):
  - The tech D7 hook diff sketch (the full `sniff_lang_chat` function body
    + the candidate-list construction + the `for`-loop + the `if/elif`
    dispatch block) into T1's scope. Include the awk body byte-for-byte
    from the parent's current hook file.
  - The PRD R1 ordered candidate list (three entries, verbatim) into T1
    and into each T2–T8 test-task scope.
  - The PRD AC4.a reworded text (stop-on-first-hit-even-invalid) into
    T1's scope and T6's scope — this is the single most likely source of
    semantic drift between tech and test-fixture authoring, and
    `reviewer-blind-spot-semantic-drift` specifically flags cross-artefact
    drift as the gap-check typical surface.
  - The tech D8 README paragraph shape (three-bullet candidate list +
    precedence sentence) into T9's scope.
  - The sandbox-`$HOME` preamble template (from
    `.claude/rules/bash/sandbox-home-in-tests.md`) into each of T2–T7's
    scope; T5 additionally receives the `XDG_CONFIG_HOME="$SANDBOX/xdg"`
    export line.
- Flag R7 dogfood annotation duty for QA-tester in the task for
  `08-verify.md` orchestration — not as a task, but as a STATUS reminder
  at implement handoff.
- Register **expected append-only collisions** in the tasks-doc
  `## Wave schedule` section: W2 has concurrent STATUS Notes appends and
  concurrent `06-tasks.md` checkbox flips (~9 tasks); apply the post-wave
  checkbox audit per `tpm/checkbox-lost-in-parallel-merge.md`.
- Each task's `Acceptance:` field must be a runnable command
  (`bash test/t6X_<name>.sh`, `bash -n .claude/hooks/session-start.sh`,
  `grep -F '<string>' README.md`, etc.) per the output contract.

## 10. Out-of-scope deferrals

- **No env-var escape hatch** (e.g. `SPECFLOW_CONFIG`). Per PRD non-goal
  #1 and tech §7. Candidate-list shape in D5 leaves room to prepend one
  slot without reshaping the control flow if operators demonstrate a need
  later.
- **No per-key merge semantics.** Per PRD non-goal #2. File-level
  override (D6) is the v1 contract. Key-level merge becomes interesting
  when the schema has ≥ 2 keys.
- **No migration tooling**, no `specflow config set` CLI, no cross-
  machine sync. PRD non-goals #3, #6, #7. Users author the YAML by hand,
  same as parent model.
- **No new config keys.** Schema is exactly parent v1
  (`lang:` block → `  chat: <zh-TW|en>`).
- **No changes to parent directive semantics.** Parent R3, R4, R5, R6
  remain in force (R3 of this PRD makes them explicit and greppable).
- **No space-in-path hardening.** Tech §7 non-decision: a user with a
  space in `$HOME` or `$XDG_CONFIG_HOME` would see the candidate split
  unhelpfully and fall through to default-off. Accepted as a known edge;
  guarding would require array syntax (tech D5 option B) and breaks
  parent hook style.
- **No dedicated hook-latency test.** Risk R4 above: ±10 ms on shared CI
  is noisier than the measurement budget. R5 AC5.b satisfied by
  construction from AC5.a (structural no-new-fork guarantee) and
  confirmed at T1 review.
- **No README rewrite.** Per tech D8: append one paragraph to the
  existing "Language preferences" section; do not reorder, do not
  demote the project-level narrative.

---

## Summary

- **Blocks**: 3 (B1 hook edit, B2 tests, B3 docs + smoke registration).
- **Waves**: 2 (W1 foundation 1-task; W2 tests + docs 9-parallel).
- **Total tasks**: 10 (T1 hook; T2–T8 seven test files; T9 README;
  T10 smoke registration).
- **Critical path**: W1 → W2. W1 gates everything; W2 is maximally
  parallel at the file level.
- **Load-bearing risks**: (R1) hook-edit regression — mitigated by t73
  byte-identical assertion + t67 baseline preservation; (R3) dogfood
  paradox 8th — structural-only this feature, runtime handoff to next;
  (R4) R5 AC5.b is not test-enforceable — satisfied by construction and
  T1 review rather than a dedicated test.
- **TPM memory consulted**: 6 TPM entries and 2 shared memories applied.
  `parallel-safe-requires-different-files` validates W2's 9-parallel shape
  (distinct files). `parallel-safe-append-sections` keeps smoke.sh and
  README as single-editor tasks and accepts mechanical keep-both on
  STATUS + checkbox merges. `checkbox-lost-in-parallel-merge` flagged for
  W2 post-merge audit (9-way at prior repo ceiling). `briefing-contradicts-
  schema` drives the verbatim-quote discipline (D7 diff, R1 candidate
  list, AC4.a reworded text, D8 README shape). `same-file-sequential-
  wave-depth-accepted` confirms T1 does NOT require further sub-wave
  decomposition (single coherent edit). `shared/dogfood-paradox-third-
  occurrence` drives R7 annotation duty and W2 structural-only
  orientation.
