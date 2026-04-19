# Tasks — user-lang-config-fallback

_2026-04-19 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1..R7), `04-tech.md` (D1..D8), `05-plan.md`
(B1..B3, W1..W2). Every task names its Wave, Requirements, and Decisions.
`Acceptance` is a concrete runnable command (or filesystem check) the
developer runs at the end; when it passes, the task is done.

All paths below are absolute under `/Users/yanghungtw/Tools/spec-workflow/`.

This feature layers on the parent `20260419-language-preferences`. T1
references parent-hook lines (helper awk block at lines 261–269 of the
parent's merged `.claude/hooks/session-start.sh`); parent merges before W1
runs. `sniff_lang_chat` wraps that block byte-identically (R2 AC2.b).

Wave schedule lives at the bottom; R↔T trace table immediately below it.
Dogfood paradox staging (8th occurrence) is captured at the very end.

---

## Team memory

- `tpm/briefing-contradicts-schema.md` (local) — applied: T1's Briefing
  quotes the tech D7 diff sketch verbatim (full `sniff_lang_chat` body +
  candidate-list construction + for-loop + if/elif dispatch). T6's
  Briefing quotes the reworded AC4.a verbatim. T9's Briefing quotes the
  D8 README paragraph shape verbatim. No paraphrase anywhere the schema
  is load-bearing.
- `tpm/parallel-safe-requires-different-files.md` (global) — applied:
  T2..T10 all edit distinct files (seven test files, `README.md`,
  `test/smoke.sh`). Wave 2's 9-way parallelism is correct.
- `tpm/parallel-safe-append-sections.md` (global) — applied: append-
  only collisions on STATUS.md Notes and 06-tasks.md checkbox flips
  are expected at W2 merge; mechanical keep-both is the resolution.
- `tpm/checkbox-lost-in-parallel-merge.md` (local) — applied: W2 is
  9-parallel (prior repo ceiling); post-wave audit `grep -c '^- \[x\]'
  06-tasks.md` runs once immediately after merge per the rule.
- `shared/dogfood-paradox-third-occurrence.md` — applied, 8th
  occurrence. All runtime-observable ACs (AC1.b, AC1.c, AC1.d, AC4.a)
  are structural PASS only this feature; runtime PASS deferred to
  R7 AC7.b next-feature handoff. See §"Dogfood paradox staging" below.

---

## T1 — Edit `.claude/hooks/session-start.sh`: add `sniff_lang_chat` helper + candidate-list walk
- **Block**: B1
- **Wave**: W1
- **Owner role**: developer (bash; hook edit)
- **Requirements**: R1 AC1.a, AC1.b, AC1.c, AC1.d; R2 AC2.a, AC2.b; R4
  AC4.a (reworded — see Briefing), AC4.b, AC4.c; R5 AC5.a, AC5.b; R3
  (all parent invariants preserved by non-touch of their code paths).
- **Decisions**: D1 (XDG-aware 3-path), D2 (`[ -r … ]`), D3
  (`[ -n "${XDG_CONFIG_HOME:-}" ]` POSIX default expansion), D4
  (`sniff_lang_chat <path>` helper wrapping parent awk byte-identically),
  D5 (space-separated string + unquoted `for` loop), D6 (stop-on-first-
  hit even when invalid), D7 (diff sketch — paste verbatim below).
- **Files touched**:
  - MODIFY: `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    — single coherent edit (≈ 25 net lines). Two edit regions:
    (a) add `sniff_lang_chat()` helper above the `# Main` section banner
    (alongside peer helpers `classify_frontmatter`, `digest_rule`,
    `lang_heuristic`, `json_escape`, `log_warn`, `log_info`);
    (b) replace the parent's single-path read block (parent lines
    258–287 in the merged parent hook) with the candidate-list + for-
    loop + if/elif dispatch from D7 below.

- **Briefing**:

  **Per `tpm/briefing-contradicts-schema.md`: D7's diff sketch, D4's
  helper signature, D5's loop form, D3's XDG probe, and the AC4.a
  reworded text are all quoted VERBATIM below. Do not paraphrase. Do
  not rewrite. Paste as-is; let the sketch shape the code.**

  ### R1 candidate list (PRD verbatim, 03-prd.md §4 R1)

      1. `.spec-workflow/config.yml` (project — wins when present)
      2. `$XDG_CONFIG_HOME/specflow/config.yml` (user-home XDG;
         evaluated only when `$XDG_CONFIG_HOME` is set **and non-empty**)
      3. `~/.config/specflow/config.yml` (user-home final fallback)

  ### D3 XDG env check (verbatim from 04-tech.md §3 D3)

  `[ -n "${XDG_CONFIG_HOME:-}" ]` — the `:-` default expansion treats
  unset and empty identically.

  ### D4 helper signature (verbatim from 04-tech.md §3 D4)

  `sniff_lang_chat <path>` — echoes the sniffed value on stdout; empty
  string if key absent or file unreadable. Awk body is byte-identical
  to the parent D7 block (parent lines 261–269 in the merged parent
  hook). One-phrase: **awk block becomes a `sniff_lang_chat <path>`
  helper; awk body byte-identical to parent**.

  ### D5 loop form (verbatim from 04-tech.md §3 D5)

  Space-separated string + unquoted `for`:

  ```bash
  CANDIDATES=".spec-workflow/config.yml"
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specflow/config.yml"
  fi
  CANDIDATES="$CANDIDATES $HOME/.config/specflow/config.yml"

  for cfg_file in $CANDIDATES; do
    [ -r "$cfg_file" ] || continue
    cfg_chat="$(sniff_lang_chat "$cfg_file")"
    if [ -n "$cfg_chat" ]; then
      cfg_source="$cfg_file"
      break
    fi
  done
  ```

  Do NOT quote `$CANDIDATES` in the `for … in` line — the unquoted
  expansion is what splits the string into three iterations.

  ### D6 stop-on-first-hit semantics (verbatim from 04-tech.md §3 D6)

  The loop visits candidates in order. First file whose `chat:` line
  is present (regardless of whether the token is `zh-TW`/`en` or
  something else) terminates the walk. Valid → emit marker. Invalid
  → one stderr warning + default-off. Empty key (no `chat:` under
  `lang:`) → continue to next candidate. Implementation: set
  `cfg_chat` + `cfg_source` on first non-empty sniff and `break`.

  ### D7 hook diff sketch (verbatim from 04-tech.md §3 D7)

  The diff targets `.claude/hooks/session-start.sh` lines 258–287
  (the parent's existing config-read block) and adds one helper
  function above the main section. Existing imports, traps, and JSON-
  emit path are unchanged.

  ```diff
  @@ -190,6 +190,28 @@ json_escape() {
     END { printf "" }'
   }

  +# sniff_lang_chat <path>
  +# Sniffs the lang.chat value from a YAML config file.
  +# Echoes the token on stdout (empty string if key absent or file unreadable).
  +# Awk body is byte-identical to the parent D7 block.
  +sniff_lang_chat() {
  +  local cfg_file="$1"
  +  awk '/^lang:/        {in_lang=1; next}
  +    in_lang && /^  chat:/ {
  +      sub(/^  chat:[[:space:]]*/, "")
  +      gsub(/"/, ""); gsub(/#.*$/, "")
  +      gsub(/[[:space:]]+$/, "")
  +      print; exit
  +    }
  +    /^[^ ]/         {in_lang=0}
  +  ' "$cfg_file" 2>/dev/null
  +}
  +
   # ---------------------------------------------------------------------------
   # Main
   # ---------------------------------------------------------------------------
  @@ -255,30 +277,40 @@ if [ -z "$digest" ]; then
     log_info "no valid rules found in $RULES_DIR"
   fi

  -# New: read lang.chat from config, append marker line if set
  -cfg_file=".spec-workflow/config.yml"
  -if [ -r "$cfg_file" ]; then
  -  cfg_chat=$(awk '/^lang:/        {in_lang=1; next}
  -    in_lang && /^  chat:/ {
  -      sub(/^  chat:[[:space:]]*/, "")
  -      gsub(/"/, ""); gsub(/#.*$/, "")
  -      gsub(/[[:space:]]+$/, "")
  -      print; exit
  -    }
  -    /^[^ ]/         {in_lang=0}
  -  ' "$cfg_file" 2>/dev/null)
  -
  -  case "$cfg_chat" in
  -    zh-TW|en)
  +# Read lang.chat from an ordered candidate list; first file with the key wins.
  +# 1. .spec-workflow/config.yml  (project — wins when present)
  +# 2. $XDG_CONFIG_HOME/specflow/config.yml  (only if env var set and non-empty)
  +# 3. $HOME/.config/specflow/config.yml  (final tilde fallback)
  +CANDIDATES=".spec-workflow/config.yml"
  +if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  +  CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specflow/config.yml"
  +fi
  +CANDIDATES="$CANDIDATES $HOME/.config/specflow/config.yml"
  +
  +cfg_chat=""
  +cfg_source=""
  +for cfg_file in $CANDIDATES; do
  +  [ -r "$cfg_file" ] || continue
  +  cfg_chat="$(sniff_lang_chat "$cfg_file")"
  +  if [ -n "$cfg_chat" ]; then
  +    cfg_source="$cfg_file"
  +    break
  +  fi
  +done
  +
  +if [ -n "$cfg_chat" ]; then
  +  if [ "$cfg_chat" = "zh-TW" ] || [ "$cfg_chat" = "en" ]; then
  +    if [ -n "$digest" ]; then
  +      digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
  +    else
  +      digest="LANG_CHAT=$cfg_chat"
  +    fi
  +  else
  +    log_warn "$cfg_source: lang.chat has unknown value '$cfg_chat' — ignored"
  +  fi
  +fi
  +
  -      if [ -n "$digest" ]; then
  -        digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
  -      else
  -        digest="LANG_CHAT=$cfg_chat"
  -      fi
  -      ;;
  -    "")
  -      # Empty / absent key — default-off, no warning
  -      :
  -      ;;
  -    *)
  -      log_warn "config.yml: lang.chat has unknown value '$cfg_chat' — ignored"
  -      ;;
  -  esac
  -fi
  ```

  ### R4 AC4.a reworded text (verbatim from 03-prd.md §4 R4 AC4.a [CHANGED 2026-04-19])

  > For each candidate path (project, XDG, simple-tilde), when that
  > file is present with `chat: fr` (or any value outside
  > `{zh-TW, en}`), the hook emits exactly one stderr warning line that
  > names the candidate file path and the invalid value, and default-
  > off behaviour obtains for the session (no `LANG_CHAT=` marker
  > emitted). **Iteration stops at the first candidate whose
  > `lang.chat` key is present — regardless of whether the value is
  > valid — per tech D6 file-level-override semantics; an invalid
  > early candidate is NOT cascaded past to a later one. [CHANGED
  > 2026-04-19]** A user with a project-level typo (`chat: fr`) is
  > expected to fix it rather than rely on a global fallback taking
  > over silently.

  ### Constraints carried forward

  - **Bash 3.2 portability** (`.claude/rules/bash/bash-32-portability.md`):
    no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no
    `[[ =~ ]]`. Dispatch validity via `if/elif` (per D7); do NOT put
    a `case` inside a `$(…)` subshell.
  - **Fail-safe frame preserved**: the existing `set +e` and
    `trap 'exit 0' ERR INT TERM` at the top of the file stay
    untouched. Awk errors silently via `2>/dev/null` inside
    `sniff_lang_chat`. Unreadable files skipped via `[ -r ]`.
  - **Style** (`.claude/rules/reviewer/style.md` rule 7): match
    neighbour convention — `[ … ]` single-bracket POSIX, space-
    separated strings, helper placed alongside peer helpers above
    the `# Main` banner.
  - **Performance** (`.claude/rules/reviewer/performance.md` rules
    1 + 6): no shell-out in the loop beyond the existing
    `sniff_lang_chat` call (which invokes awk, bounded ≤ 3
    iterations). No new fork per iteration.

- **Acceptance** (runnable):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    exits 0.
  - `grep -c 'in_lang=1' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    returns exactly `1` (R2 AC2.a pre-flight; re-verified structurally
    by T8).
  - `grep -c '^sniff_lang_chat()' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    returns exactly `1` (helper defined exactly once).
  - `grep -q 'trap .exit 0. ERR INT TERM' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    succeeds (fail-safe frame preserved).
  - `grep -Ec 'readlink -f|realpath|jq|mapfile| =~ ' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    returns `0` (bash 3.2 portability).
  - `grep -c 'log_warn "\$cfg_source:' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
    returns at least `1` (warning names the source file per AC4.a).
- **Dependencies**: none at the code level (parent feature merges
  before W1 opens, supplying lines 258–287 that this task rewrites).
- **Parallel-safe-with**: — (solo in W1; single-file coherent edit).
- **Notes**:
  - Solo wave. No peer collision. No STATUS append-race possible at
    W1.
  - Dogfood paradox: T1's own merge does NOT activate the new logic
    during the development session. All runtime behaviour is observed
    in structural tests (W2) only; live runtime on next feature after
    session restart per R7 AC7.b.
- [ ]

---

## T2 — `test/t67_userlang_all_absent.sh` (CREATE) — AC1.a + AC4.c
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R1 AC1.a (all-absent baseline); R4 AC4.c (missing
  file silent, does not stop iteration); R4 AC4.b (exit 0 regardless).
- **Decisions**: D1 (3-path exercised with all absent), D3
  (`$XDG_CONFIG_HOME` unset → XDG candidate skipped).
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t67_userlang_all_absent.sh`
    (exec bit set).

- **Briefing**:

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  # 1. Build sandbox
  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  # 2. Isolate HOME
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  # 3. Preflight — refuse to run against real HOME
  case "$HOME" in
    "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### R1 candidate list (PRD verbatim, 03-prd.md §4 R1)

      1. `.spec-workflow/config.yml` (project — wins when present)
      2. `$XDG_CONFIG_HOME/specflow/config.yml` (user-home XDG;
         evaluated only when `$XDG_CONFIG_HOME` is set **and non-empty**)
      3. `~/.config/specflow/config.yml` (user-home final fallback)

  ### Fixture shape

  - Sandbox `$HOME="$SANDBOX/home"` (empty — no `.config/specflow/`
    directory at all).
  - `unset XDG_CONFIG_HOME` explicitly before invoking the hook.
  - `cd` into a fresh sandbox cwd that has NO `.spec-workflow/`
    directory (e.g., `mkdir -p "$SANDBOX/repo" && cd "$SANDBOX/repo"`).
  - Invoke the hook under `HOOK_TEST=1` (parent's harness convention
    — present in parent's t54 shape, inherited here).

  ### Expected assertions

  - Exit code `0`.
  - Stdout (JSON digest) contains NO `LANG_CHAT=` substring (grep -q
    negation).
  - Stderr is empty (no warnings — missing files are silent per AC4.c).

- **Acceptance** (runnable):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t67_userlang_all_absent.sh`
    exits 0; `test -x .../t67_userlang_all_absent.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t67_userlang_all_absent.sh`
    exits 0 after T1 merges (RED before T1; GREEN after).
- **Dependencies**: T1 (runtime test of the edited hook).
- **Parallel-safe-with**: T3, T4, T5, T6, T7, T8, T9, T10 (distinct
  new files / single-editor tasks).
- **Notes**:
  - Sandbox-HOME preflight is NON-NEGOTIABLE per the rule file.
  - Structural PASS only during this feature's verify; runtime PASS
    deferred to next-feature handoff per R7.
- [ ]

---

## T3 — `test/t68_userlang_user_home_only.sh` (CREATE) — AC1.b
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R1 AC1.b (user-home-only opt-in emits marker);
  R4 AC4.b (exit 0).
- **Decisions**: D1 (tilde fallback hit), D4 (helper-based sniff
  returns `zh-TW`).
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t68_userlang_user_home_only.sh`
    (exec bit set).

- **Briefing**:

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  case "$HOME" in
    "$SANDBOX"*) ;;
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### Fixture shape

  - `mkdir -p "$HOME/.config/specflow"`.
  - Write `$HOME/.config/specflow/config.yml` with exactly:

    ```yaml
    lang:
      chat: zh-TW
    ```

    (use `printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/specflow/config.yml"`
    — two-space indent, LF line endings).
  - `unset XDG_CONFIG_HOME`.
  - `cd "$SANDBOX/repo"` with no `.spec-workflow/config.yml` present.
  - Invoke the hook under `HOOK_TEST=1`.

  ### Expected assertions

  - Exit code `0`.
  - Stdout digest contains `LANG_CHAT=zh-TW` (grep -q for the exact
    marker line in the `additionalContext` string).
  - Stderr empty (no warnings — `zh-TW` is valid).

- **Acceptance** (runnable):
  - `bash -n test/t68_userlang_user_home_only.sh` exits 0; exec bit set.
  - `bash test/t68_userlang_user_home_only.sh` exits 0 after T1.
- **Dependencies**: T1.
- **Parallel-safe-with**: T2, T4, T5, T6, T7, T8, T9, T10.
- **Notes**: R7 structural PASS only; runtime deferred.
- [ ]

---

## T4 — `test/t69_userlang_project_over_user.sh` (CREATE) — AC1.c
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R1 AC1.c (project wins over user-home file-level);
  R4 AC4.b.
- **Decisions**: D6 (stop-on-first-hit: project slot wins), D1.
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t69_userlang_project_over_user.sh`
    (exec bit set).

- **Briefing**:

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  case "$HOME" in
    "$SANDBOX"*) ;;
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### Fixture shape

  - Write `$HOME/.config/specflow/config.yml` with
    `printf 'lang:\n  chat: en\n'` (user-level says English).
  - `cd "$SANDBOX/repo"`, `mkdir -p .spec-workflow`, write
    `.spec-workflow/config.yml` with `printf 'lang:\n  chat: zh-TW\n'`
    (project-level says zh-TW — and must win wholesale).
  - `unset XDG_CONFIG_HOME`.
  - Invoke the hook under `HOOK_TEST=1` from inside `$SANDBOX/repo`.

  ### Expected assertions

  - Exit code `0`.
  - Stdout digest contains `LANG_CHAT=zh-TW` (project wins).
  - Stdout does NOT contain `LANG_CHAT=en` (user-home value not
    cascaded to).
  - Stderr empty.

- **Acceptance** (runnable):
  - `bash -n test/t69_userlang_project_over_user.sh` exits 0; exec bit set.
  - `bash test/t69_userlang_project_over_user.sh` exits 0 after T1.
- **Dependencies**: T1.
- **Parallel-safe-with**: T2, T3, T5, T6, T7, T8, T9, T10.
- **Notes**: Re-exercises parent's project-over-user semantics across
  the new 3-path shape (cross-ref Plan §5 Risk R1 mitigation). R7
  structural PASS only.
- [ ]

---

## T5 — `test/t70_userlang_xdg_over_tilde.sh` (CREATE) — AC1.d
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R1 AC1.d (XDG wins over simple-tilde when both
  present); R4 AC4.b.
- **Decisions**: D1, D3 (XDG env gate), D6.
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t70_userlang_xdg_over_tilde.sh`
    (exec bit set).

- **Briefing**:

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  case "$HOME" in
    "$SANDBOX"*) ;;
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### Fixture shape — XDG-aware

  In addition to the preflight above, this test also exports
  `XDG_CONFIG_HOME` pointing at a sandbox subdir:

  ```bash
  export XDG_CONFIG_HOME="$SANDBOX/xdg"
  mkdir -p "$XDG_CONFIG_HOME/specflow"
  printf 'lang:\n  chat: zh-TW\n' > "$XDG_CONFIG_HOME/specflow/config.yml"

  mkdir -p "$HOME/.config/specflow"
  printf 'lang:\n  chat: en\n' > "$HOME/.config/specflow/config.yml"
  ```

  - `cd "$SANDBOX/repo"` with no `.spec-workflow/config.yml` present.
  - Invoke the hook under `HOOK_TEST=1`.

  ### Expected assertions

  - Exit code `0`.
  - Stdout digest contains `LANG_CHAT=zh-TW` (XDG wins).
  - Stdout does NOT contain `LANG_CHAT=en` (tilde not consulted).
  - Stderr empty.

- **Acceptance** (runnable):
  - `bash -n test/t70_userlang_xdg_over_tilde.sh` exits 0; exec bit set.
  - `bash test/t70_userlang_xdg_over_tilde.sh` exits 0 after T1.
- **Dependencies**: T1.
- **Parallel-safe-with**: T2, T3, T4, T6, T7, T8, T9, T10.
- **Notes**: Only test that exercises the XDG branch. R7 structural
  PASS only.
- [ ]

---

## T6 — `test/t71_userlang_stop_on_first_invalid.sh` (CREATE) — AC4.a (reworded)
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R4 AC4.a (reworded — stop-on-first-hit-even-
  invalid; see Briefing verbatim); R4 AC4.b.
- **Decisions**: D6 (stop-on-first-hit — the load-bearing semantic of
  this feature); D4 (warning message names `$cfg_source`).
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t71_userlang_stop_on_first_invalid.sh`
    (exec bit set).

- **Briefing**:

  **This test is the load-bearing guard against semantic drift on
  D6. Per `tpm/briefing-contradicts-schema.md`, the reworded AC4.a
  is pasted VERBATIM below; assertions must match the literal text,
  not a paraphrase.**

  ### R4 AC4.a reworded text (verbatim from 03-prd.md §4 R4 AC4.a [CHANGED 2026-04-19])

  > For each candidate path (project, XDG, simple-tilde), when that
  > file is present with `chat: fr` (or any value outside
  > `{zh-TW, en}`), the hook emits exactly one stderr warning line that
  > names the candidate file path and the invalid value, and default-
  > off behaviour obtains for the session (no `LANG_CHAT=` marker
  > emitted). **Iteration stops at the first candidate whose
  > `lang.chat` key is present — regardless of whether the value is
  > valid — per tech D6 file-level-override semantics; an invalid
  > early candidate is NOT cascaded past to a later one. [CHANGED
  > 2026-04-19]** A user with a project-level typo (`chat: fr`) is
  > expected to fix it rather than rely on a global fallback taking
  > over silently.

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  case "$HOME" in
    "$SANDBOX"*) ;;
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### Fixture shape

  - Write `$HOME/.config/specflow/config.yml` with
    `printf 'lang:\n  chat: zh-TW\n'` (user-level is VALID).
  - `cd "$SANDBOX/repo"`, `mkdir -p .spec-workflow`, write
    `.spec-workflow/config.yml` with `printf 'lang:\n  chat: fr\n'`
    (project-level is INVALID — `fr` is outside `{zh-TW, en}`).
  - `unset XDG_CONFIG_HOME`.
  - Invoke the hook under `HOOK_TEST=1` from inside `$SANDBOX/repo`,
    capturing stdout and stderr separately.

  ### Expected assertions (per the reworded AC4.a verbatim above)

  1. Exit code `0` (AC4.b — session never blocked).
  2. Stdout digest contains NO `LANG_CHAT=` substring whatsoever
     (stop-on-first-hit: project held the key and was invalid →
     default-off; user's valid `zh-TW` is NOT consulted).
  3. Stderr contains EXACTLY ONE line that mentions both
     `.spec-workflow/config.yml` (the candidate file path) AND the
     token `fr` (the invalid value).
     - Assertion: `stderr_count=$(grep -c '.spec-workflow/config.yml'
       <stderr-file>)`; assert `[ "$stderr_count" = "1" ]`.
     - Additional: `grep -q "'fr'" <stderr-file>` succeeds.
  4. Stderr contains NO mention of `$HOME/.config/specflow/config.yml`
     (user-home file was never consulted; iteration stopped at
     project).
  5. Stderr contains NO mention of `zh-TW` (the user's valid value
     was not cascaded to).

- **Acceptance** (runnable):
  - `bash -n test/t71_userlang_stop_on_first_invalid.sh` exits 0; exec
    bit set.
  - `bash test/t71_userlang_stop_on_first_invalid.sh` exits 0 after T1.
- **Dependencies**: T1.
- **Parallel-safe-with**: T2, T3, T4, T5, T7, T8, T9, T10.
- **Notes**:
  - This is the single test where a semantic-drift failure between
    tech D6 and test authoring would be most likely; the verbatim
    AC4.a quote above is the anchor. Do NOT rewrite the assertions
    in the developer's own words.
  - R7 structural PASS only; runtime deferred.
- [ ]

---

## T7 — `test/t72_userlang_missing_doesnt_stop.sh` (CREATE) — AC4.c clarification
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; integration test)
- **Requirements**: R4 AC4.c (missing candidate produces no warning
  AND does not stop iteration; only a file whose `lang.chat` key is
  present stops).
- **Decisions**: D6 (empty/absent file ≠ "held the key" — iteration
  continues past), D2 (`[ -r ]` probe skips absent).
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t72_userlang_missing_doesnt_stop.sh`
    (exec bit set).

- **Briefing**:

  ### Sandbox-HOME preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md`)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SANDBOX="$(mktemp -d)"
  trap 'rm -rf "$SANDBOX"' EXIT

  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"

  case "$HOME" in
    "$SANDBOX"*) ;;
    *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
  esac
  ```

  ### Fixture shape

  - `cd "$SANDBOX/repo"` — do NOT create `.spec-workflow/config.yml`
    (project-level absent).
  - `unset XDG_CONFIG_HOME` (XDG candidate absent via env gate).
  - `mkdir -p "$HOME/.config/specflow"`; write
    `printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/specflow/config.yml"`
    (tilde fallback — the third candidate; earlier candidates are
    absent but the iteration must reach it).
  - Invoke the hook under `HOOK_TEST=1`.

  ### Expected assertions (this test is the companion to T6 that
  confirms the two "stop" conditions are distinct: "file holds key"
  stops; "file absent" does NOT)

  - Exit code `0`.
  - Stdout digest contains `LANG_CHAT=zh-TW` (iteration reached the
    third candidate).
  - Stderr is empty (no warnings about the absent project/XDG
    candidates — AC4.c "missing file silent").

- **Acceptance** (runnable):
  - `bash -n test/t72_userlang_missing_doesnt_stop.sh` exits 0; exec
    bit set.
  - `bash test/t72_userlang_missing_doesnt_stop.sh` exits 0 after T1.
- **Dependencies**: T1.
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T8, T9, T10.
- **Notes**: R7 structural PASS only; runtime deferred.
- [ ]

---

## T8 — `test/t73_userlang_structural_grep.sh` (CREATE) — AC2.a + AC2.b
- **Block**: B2
- **Wave**: W2
- **Owner role**: developer (bash; static/structural test)
- **Requirements**: R2 AC2.a (`grep -c 'in_lang=1'` returns exactly
  1); R2 AC2.b (awk body byte-identical to parent's merged commit).
  Structural confirmation of R5 AC5.a (no new fork per iteration
  beyond the existing awk).
- **Decisions**: D4 (helper wraps awk byte-identically).
- **Files touched**:
  - CREATE: `/Users/yanghungtw/Tools/spec-workflow/test/t73_userlang_structural_grep.sh`
    (exec bit set).

- **Briefing**:

  This is a STATIC test — no sandbox `$HOME` mutation, no hook
  invocation. It greps the hook file and diffs the awk body against
  the parent's merged commit.

  ### Assertions (R2)

  1. **AC2.a — single awk definition**.
     - `grep -c 'in_lang=1' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
       must return exactly `1`.
     - Rationale: `in_lang=1` is the awk program's distinctive state-
       machine token; counting it pins the parser's identity more
       reliably than a flimsy grep on the token `awk`.

  2. **AC2.b — awk body byte-identical to parent D7**.
     - Extract the awk program text from `sniff_lang_chat` (the
       multi-line string between `awk '` and the closing `'` inside
       the helper function body).
     - Extract the corresponding awk program text from the parent's
       merged hook at
       `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
       lines 261–269 as the parent shipped them (resolvable via
       `git log --oneline .claude/hooks/session-start.sh` + `git show
       <parent-merge-sha>:.claude/hooks/session-start.sh | sed -n '261,269p'`).
     - Diff the two. Assert zero character differences.
     - Implementation hint (bash 3.2 portable — no `mapfile`, no
       `jq`): use `awk` to print the block between two known
       anchors (`/^sniff_lang_chat/` to `/^}/`) into a temp file and
       `diff` against the extracted parent block. Alternatively,
       assert an exact byte count + exact match of each awk rule
       line (`/^lang:/`, `in_lang && /^  chat:/`, each `sub`/`gsub`,
       `print; exit`, `/^[^ ]/`).

  3. **R5 AC5.a structural confirmation**.
     - `grep -Ec '\$\(.*awk |\|awk | awk '
       /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`
       returns a count that does NOT exceed the parent's count plus 1
       (the plus-1 is the `sniff_lang_chat` helper wrapping the
       parent's single awk invocation; no awk calls are added inside
       the loop body itself).
     - Also grep the loop body between `for cfg_file in $CANDIDATES`
       and its closing `done`: within that block, there should be
       exactly one `sniff_lang_chat` call and no direct `awk`,
       `python3`, `jq`, or `readlink -f` tokens.

  ### Constraints

  - **Bash 3.2 portability** (`.claude/rules/bash/bash-32-portability.md`):
    no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no
    `[[ =~ ]]`. Use `awk` / `sed` / `diff` for the extraction and
    comparison.
  - No sandbox-`$HOME` preflight needed — this test does NOT mutate
    the filesystem beyond writing to a temp file under `mktemp` (for
    the extracted awk block), which is OK without `$HOME`
    isolation.

- **Acceptance** (runnable):
  - `bash -n test/t73_userlang_structural_grep.sh` exits 0; exec bit set.
  - `bash test/t73_userlang_structural_grep.sh` exits 0 after T1.
- **Dependencies**: T1 (greps the edited hook file).
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7, T9, T10.
- **Notes**: This test is structural and fully verifiable at this
  feature's verify stage (no dogfood paradox applies — it inspects
  source, not runtime behaviour). Cross-ref Plan §6 verification
  map.
- [ ]

---

## T9 — `README.md` "Language preferences" section — append candidate-list paragraph
- **Block**: B3
- **Wave**: W2
- **Owner role**: developer (markdown; single-editor doc edit)
- **Requirements**: R6 AC6.a (simple-tilde path documented); AC6.b
  (XDG path documented with env-var gating); AC6.c (precedence in
  plain words); AC6.d (rule file unchanged — inferred by this task
  NOT touching `.claude/rules/common/language-preferences.md`).
- **Decisions**: D8 (append one paragraph; do not rewrite existing
  section; keep parent's YAML schema intact).
- **Files touched**:
  - MODIFY: `/Users/yanghungtw/Tools/spec-workflow/README.md` — extend
    the existing "Language preferences" section by appending one
    paragraph with the three-bullet candidate list + precedence
    sentence. No new section header; no reorder of existing prose.

- **Briefing**:

  **Per `tpm/briefing-contradicts-schema.md`, the D8 paragraph shape
  is pasted VERBATIM below. Use it (and the precedence-list block)
  as the text template. Developer finalises wording only for
  transitions, not for the three bullets' content or the precedence
  sentence.**

  ### D8 README paragraph shape (verbatim from 04-tech.md §3 D8)

  Insert AFTER the existing YAML example snippet in the "Language
  preferences" section (do NOT insert before; do NOT insert inside
  another section). The existing lead sentence ("Create
  `.spec-workflow/config.yml` with `lang:\n  chat: zh-TW`") stays
  unchanged. The existing warning about malformed/unknown values
  stays unchanged. The new paragraph is the only addition.

  ```
  The hook consults an ordered list of candidate paths and uses
  the first readable file whose `lang.chat` value is recognised:

  1. `.spec-workflow/config.yml` — project-level, committed to the
     repo, wins when present.
  2. `$XDG_CONFIG_HOME/specflow/config.yml` — consulted only when
     `$XDG_CONFIG_HOME` is set and non-empty.
  3. `~/.config/specflow/config.yml` — user-home fallback; set
     once per machine for personal preference across all repos.

  Precedence: project > XDG > tilde. All three absent → English
  baseline (no change from default).
  ```

  ### Additional precedence framing (verbatim — for the stop-on-first-hit explanation)

  Immediately after the block above, append this short paragraph
  explaining why an invalid early candidate does not cascade:

  > Precedence is file-level, not key-level: the first file whose
  > `lang.chat` key is present wins — even if its value is invalid.
  > This is deliberate. A project `.spec-workflow/config.yml` with
  > `chat: fr` is treated as a firm (if misspelled) project
  > declaration, not a typo to cascade past; fix the offending file
  > rather than rely on a global fallback taking over silently.
  > Missing files do not stop iteration; only a present `lang.chat`
  > key does.

  ### Constraints

  - Do NOT touch `.claude/rules/common/language-preferences.md`
    (R6 AC6.d — rule file unchanged, verified by diff inspection at
    verify stage).
  - Do NOT rewrite or reorder the parent's "Language preferences"
    section; append only.
  - Do NOT add a new section header. The new paragraph sits under
    the existing header.
  - Do NOT change the parent's YAML example snippet (`lang:` block
    → `  chat: <zh-TW|en>`).

- **Acceptance** (runnable):
  - `grep -F '~/.config/specflow/config.yml' /Users/yanghungtw/Tools/spec-workflow/README.md`
    returns at least one line (R6 AC6.a).
  - `grep -F 'XDG_CONFIG_HOME' /Users/yanghungtw/Tools/spec-workflow/README.md`
    returns at least one line (R6 AC6.b).
  - `grep -F 'project > XDG > tilde' /Users/yanghungtw/Tools/spec-workflow/README.md`
    returns at least one line (R6 AC6.c — the exact precedence
    string).
  - `git diff -- .claude/rules/common/language-preferences.md`
    returns empty at final commit (R6 AC6.d — inspected at verify
    stage, not by this test; included here as a reminder).
- **Dependencies**: none (independent of T2..T8; only logically
  references T1's behaviour).
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7, T8, T10.
- **Notes**:
  - Single-editor on `README.md`; no peer collision inside W2.
  - No code; documentation-only. No test registration needed.
- [ ]

---

## T10 — `test/smoke.sh` — append t67..t73 registration (single-editor)
- **Block**: B3
- **Wave**: W2
- **Owner role**: developer (bash; single-editor smoke registration)
- **Requirements**: Feature-wide — every new test (t67..t73) must be
  exercised by `bash test/smoke.sh` (gating check at Plan §3 W2).
- **Decisions**: Plan §2 B3 (single-editor task on `test/smoke.sh`;
  avoids append-only collisions on this file inside W2).
- **Files touched**:
  - MODIFY: `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` —
    append seven new test slugs to the existing backslash-continued
    for-loop that dispatches `t<N>.sh` files. No other edit.

- **Briefing**:

  Tests t67..t73 do NOT self-register. This is the single-editor
  task that adds them to the loop. Parent feature's `20260419-
  language-preferences` merges t54..t66 into the same loop BEFORE
  this feature's W1 opens, so the loop's baseline count grows from
  49 → 66 (the exact new tests added by parent) before this feature
  starts; this task takes it from 66 → 73 by appending seven more.

  ### The existing loop shape (reference — already present in
  `test/smoke.sh` after parent merges; see the parent's T23 + this
  feature's source-of-truth)

  The loop uses a space-separated + backslash-continued list of
  test slugs inside `for t in … ; do …`. Append the seven new slugs
  at the end of the list, preserving the existing line-continuation
  style and indentation.

  ### Exact additions (copy verbatim)

  Append these seven tokens to the existing `for t in` list in the
  order shown, each on its own continuation line using the same
  backslash-continuation + indentation pattern the surrounding
  entries use:

  ```
  t67_userlang_all_absent \
  t68_userlang_user_home_only \
  t69_userlang_project_over_user \
  t70_userlang_xdg_over_tilde \
  t71_userlang_stop_on_first_invalid \
  t72_userlang_missing_doesnt_stop \
  t73_userlang_structural_grep
  ```

  (Note: the last entry has no trailing backslash; it is the new
  terminus of the list. Move the terminus as appropriate — whichever
  entry was last in the parent-merged version loses its trailing
  backslash-absence to `t73_userlang_structural_grep`.)

  ### Constraints

  - Single-editor. Only T10 edits `test/smoke.sh` in this wave.
  - Do NOT reorder existing entries. Do NOT move unrelated lines.
  - Do NOT add any other bash to `test/smoke.sh` (no new assertion
    scaffolding; the existing loop body already runs each test and
    increments PASS/FAIL counters).

- **Acceptance** (runnable):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh`
    exits 0.
  - `grep -c 't6[7-9]_userlang\|t7[0-3]_userlang' /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh`
    returns exactly `7`.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` exits
    0 after T1..T8 merge; prior count 66 (post-parent) + 7 new = 73
    total registered tests exercised.
- **Dependencies**: T2, T3, T4, T5, T6, T7, T8 (registration lines
  reference the new test files by basename; files must exist in the
  worktree before this task's verify step succeeds). T1 is a
  transitive dependency via those tests.
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7, T8, T9.
- **Notes**:
  - Append-only collision on `test/smoke.sh` is SUPPRESSED in W2
    because T10 is the sole editor. Parent-merge collisions on this
    file happened in a prior feature; this wave does not re-open
    them.
  - The per-test `exit 0` verify step may be RED until all of
    T2..T8's Acceptance pass; that is expected and matches parent
    T19's shape.
- [ ]

---

## Wave schedule

### W1 — foundation (1 task)
- **Members**: T1.
- **Serialisation**: T1 is solo. No peer tasks in W1.
- **Gating to W2**: T1 merged AND its Acceptance grep set passes
  (`bash -n` clean, `grep -c 'in_lang=1'` returns 1, fail-safe frame
  preserved, no forbidden tokens added).
- **Parallel-safety analysis**: N/A — one task.

### W2 — tests + docs (9 parallel)
- **Members**: T2, T3, T4, T5, T6, T7, T8, T9, T10.
- **Parallelism**: 9-way. Each task edits a DISTINCT file:
  - T2 → `test/t67_userlang_all_absent.sh` (new)
  - T3 → `test/t68_userlang_user_home_only.sh` (new)
  - T4 → `test/t69_userlang_project_over_user.sh` (new)
  - T5 → `test/t70_userlang_xdg_over_tilde.sh` (new)
  - T6 → `test/t71_userlang_stop_on_first_invalid.sh` (new)
  - T7 → `test/t72_userlang_missing_doesnt_stop.sh` (new)
  - T8 → `test/t73_userlang_structural_grep.sh` (new)
  - T9 → `README.md` (single-editor)
  - T10 → `test/smoke.sh` (single-editor)
- **Parallel-safety analysis** (per
  `tpm/parallel-safe-requires-different-files.md`): every task writes
  its own file; no two tasks share a target. All nine are parallel-
  safe with each other.
- **Expected append-only collisions** (per
  `tpm/parallel-safe-append-sections.md`): STATUS.md Notes appends
  and 06-tasks.md checkbox flips WILL collide — mechanical keep-both
  is the resolution. Do NOT serialise the wave on these grounds.
- **Checkbox-loss expectation** (per
  `tpm/checkbox-lost-in-parallel-merge.md`): W2 is 9-parallel, which
  sits at the prior repo ceiling (same width as feature
  `20260418-review-nits-cleanup` W1 which lost 2 checkboxes).
  Expected loss: 1–2 checkboxes. Mitigation: orchestrator runs
  `grep -c '^- \[x\]' /Users/yanghungtw/Tools/spec-workflow/.spec-workflow/features/20260419-user-lang-config-fallback/06-tasks.md`
  immediately after the W2 merge; if the count is short (expected
  10 all-done at end of W2 — T1 from W1 plus T2..T10 from W2), scan
  each Tn block and flip `[ ]` → `[x]` for any merged task that
  silently reverted. Commit as `fix: check off T<n> (lost in
  merge)`. Do NOT defer to end-of-feature audit.
- **Gating to implement-done**:
  - `bash test/smoke.sh` green (73 total registered tests pass).
  - All W2 task Acceptance commands pass.
  - `git diff -- .claude/rules/common/language-preferences.md` is
    empty (R6 AC6.d).
  - `git diff -- .claude/agents/specflow/` is empty (parent R4
    preservation, inherited via R3).

---

## R ↔ T trace matrix

Rows = ACs (as they appear in 03-prd.md). Columns = tasks. `X`
means the task structurally covers that AC's assertion surface.
`—` means the AC is meta/handoff and not task-implementable (same
treatment as parent feature).

| AC | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| R1 AC1.a (all-absent baseline) | X | X |   |   |   |   |   |   |   |   |
| R1 AC1.b (user-home-only opt-in) | X |   | X |   |   |   |   |   |   |   |
| R1 AC1.c (project wins over user) | X |   |   | X |   |   |   |   |   |   |
| R1 AC1.d (XDG wins over tilde) | X |   |   |   | X |   |   |   |   |   |
| R2 AC2.a (single `in_lang=1`) | X |   |   |   |   |   |   | X |   |   |
| R2 AC2.b (awk body byte-identical) | X |   |   |   |   |   |   | X |   |   |
| R3 (parent invariants preserved) | X |   |   |   |   |   |   |   |   |   |
| R4 AC4.a (stop-on-first-hit, reworded) | X |   |   |   |   | X |   |   |   |   |
| R4 AC4.b (session never blocked; exit 0) | X | X | X | X | X | X | X |   |   |   |
| R4 AC4.c (missing silent, does not stop) | X | X |   |   |   |   | X |   |   |   |
| R5 AC5.a (no new fork per iteration) | X |   |   |   |   |   |   | X |   |   |
| R5 AC5.b (wall-clock within noise) | X |   |   |   |   |   |   | X |   |   |
| R6 AC6.a (simple-tilde path documented) |   |   |   |   |   |   |   |   | X |   |
| R6 AC6.b (XDG path documented) |   |   |   |   |   |   |   |   | X |   |
| R6 AC6.c (precedence in plain words) |   |   |   |   |   |   |   |   | X |   |
| R6 AC6.d (rule file unchanged) | — | — | — | — | — | — | — | — | — | — |
| R7 AC7.a (structural markers in verify) | — | — | — | — | — | — | — | — | — | — |
| R7 AC7.b (next-feature handoff) | — | — | — | — | — | — | — | — | — | — |

Notes on the trace:

- R5 AC5.b is not test-enforceable (±10 ms measurement noise
  exceeds budget on shared CI, per Plan §5 Risk R4). Satisfied by
  construction from AC5.a — T1 (structural guarantee) and T8
  (structural grep confirmation) cover it together. The row carries
  `X` for both tasks to reflect that satisfaction-by-construction;
  no dedicated perf test exists.
- R3 (parent invariants preserved) is covered by T1 through non-
  touch: T1's diff affects only the candidate-list read block and
  the helper region above `# Main`. No parent-invariant code path
  is modified. Verified at verify stage by diff inspection of the
  final commit.
- R6 AC6.d (rule file unchanged) is a non-mutation assertion; no
  task edits `.claude/rules/common/language-preferences.md`. The
  row's `—` marks this as a "no task owns this; verified by diff
  at verify stage" AC. Plan §3 W2 gating check enforces it.
- R7 AC7.a is QA-tester verify-stage documentation discipline —
  verdict must distinguish structural PASS from runtime PASS and
  annotate AC1.b, AC1.c, AC1.d, AC4.a accordingly. Not task-
  implementable.
- R7 AC7.b is the next-feature handoff AC — the first feature
  archived after this one includes an early STATUS Notes line
  confirming first-session runtime behaviour. Not verifiable in
  this feature.

---

## Dogfood paradox staging (8th occurrence)

Per R7 and `shared/dogfood-paradox-third-occurrence.md` (now 8th
occurrence in this repo; parent `20260419-language-preferences` was
the 7th):

1. **During implement (W1–W2)**: this feature's own development
   session was started BEFORE the new hook logic merged. The
   running session's `SessionStart` output was computed under the
   pre-modification hook; no runtime activation of the user-home
   fallback occurs during implement, regardless of what tests
   fixture into `$HOME/.config/specflow/config.yml` on disk. This
   is expected and is the paradox's definition.

2. **Structural PASS only during this feature's verify**. All
   runtime-observable ACs — AC1.b, AC1.c, AC1.d, AC4.a — are
   PASS only at the structural level this feature. QA-tester at
   verify stage MUST annotate `08-verify.md` for each of those
   four ACs with the exact phrase:

   > "structural PASS; runtime verification deferred to next
   > feature after session restart"

   per R7 AC7.a. This is a verbatim requirement; paraphrasing it
   is itself a verify-stage finding.

3. **Next-feature runtime confirmation (R7 AC7.b)**. The first
   feature archived after this one MUST include an early STATUS
   Notes line confirming first-session runtime behaviour — either:
   - "new session read `~/.config/specflow/config.yml`,
     `LANG_CHAT=zh-TW` marker observed"; or
   - "user-home config absent, no marker, English baseline as
     expected".
   Not verifiable in this feature; handoff AC only. TPM at
   implement-stage handoff logs a STATUS Notes reminder so the
   next feature's PM/orchestrator sees the handoff discipline.

4. **Bypass discipline** (per
   `shared/skip-inline-review-scope-confirmation.md`): this
   feature does NOT ship an opt-out flag for its own development
   session. The natural bypass is "nothing different happens until
   the user restarts their Claude Code session." No STATUS trace
   required during implement because no bypass is invoked. If
   `--skip-inline-review` IS invoked during W1 or W2, the on-first-
   use prompt triggers per the shared memory; carry forward to
   STATUS Notes with reason.
