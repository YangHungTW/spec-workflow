# Tasks — language-preferences

_2026-04-19 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R9), `04-tech.md` (D1–D9 primary; D10–D17
deferred), `05-plan.md` (B1–B5 across W1–W3). Every task names the wave,
requirement(s), and decision(s) it lands. `Acceptance` is a runnable command
the Developer executes at task close; if it returns the specified exit code,
the task is done.

All paths below are absolute under `/Users/yanghungtw/Tools/spec-workflow/`.
Verbatim quoted contract fragments (frontmatter schema, YAML schema, `awk`
sniff block, classifier enum, allowlist pattern) are pasted from the cited
source; do not paraphrase them per `tpm/briefing-contradicts-schema.md`.

Wave schedule and R↔T trace at the bottom.

---

## T1 — Create `.claude/rules/common/language-preferences.md` + append index row
- **Block**: B1
- **Wave**: W1
- **Owner role**: developer
- **Requirements**: R2 (AC2.a, AC2.b, AC2.c, AC2.d), R3 (AC3.a, AC3.b), R4 (AC4.b coverage enumerated), R6 (AC6.a, AC6.b)
- **Decisions**: D4 (placement + severity `should`), D5 (rule body references `LANG_CHAT=zh-TW` verbatim), D9 (YAML schema shape referenced in rule body prose)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/language-preferences.md`
  - **modify**: `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md` (append one row in the `common` section, sorted alphabetically between `classify-before-mutate` and `no-force-on-user-paths`)
- **Briefing** (verbatim contract fragments — do not paraphrase):

  **Frontmatter schema (verbatim from `.claude/rules/README.md`):**
  > Each rule file **must** begin with a YAML frontmatter block between `---` fences containing exactly these five keys (in any order):
  >
  > ```yaml
  > ---
  > name: <kebab-case slug, matches filename stem>
  > scope: common | bash | markdown | git | reviewer | <lang>
  > severity: must | should | avoid
  > created: YYYY-MM-DD
  > updated: YYYY-MM-DD
  > ---
  > ```

  **Exact frontmatter values for this rule:**
  ```yaml
  ---
  name: language-preferences
  scope: common
  severity: should
  created: 2026-04-19
  updated: 2026-04-19
  ---
  ```

  **Body sections (required order, verbatim from `.claude/rules/README.md`):**
  > 1. `## Rule` — one-sentence imperative statement.
  > 2. `## Why` — 1–3 sentences explaining the rationale.
  > 3. `## How to apply` — checklist or template for the agent.
  > 4. `## Example` — optional but strongly preferred; concrete code or prose.

  **Marker string (verbatim from tech D5 / D7):** the rule body MUST reference the exact string `LANG_CHAT=zh-TW` (ASCII, upper-case key, dash before `TW`). Any drift is caught by t53 in W3.

  **D9 YAML schema (verbatim, quoted in the rule body's `## Example` or `## How to apply`):**
  ```yaml
  # .spec-workflow/config.yml
  lang:
    chat: zh-TW    # or "en" (explicit default) — any other value → warning + default-off
  ```

  **Rule body MUST** (for AC coverage — all grep-verifiable by t51):
  - State that **when** `LANG_CHAT=zh-TW` appears in the SessionStart additional-context payload, replies to the user are in zh-TW; **otherwise this rule is a no-op** (AC2.b — conditional pattern documented).
  - Enumerate the six carve-outs verbatim (AC3.a): (a) replies to the user are in zh-TW when activated; (b) every file written via any tool (`Write`, `Edit`, `NotebookEdit`, etc.) has English content; (c) every tool-call argument (paths, patterns, flags, commit messages, branch names) is English; (d) CLI stdout emitted by any `bin/specflow-*` script or hook script is English; (e) commit messages are English; (f) STATUS Notes entries and any file under `.claude/team-memory/**` are English.
  - Contain no reverse directive ("write file content in zh-TW when …") under any condition (AC3.b).
  - Name each of the seven specflow subagent roles explicitly (AC4.b): **PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer**.
  - Give at least one concrete positive example (AC6.a), e.g. "PM's brainstorm summary shown to the user in chat is zh-TW when opted in."
  - Give at least three concrete negative examples (AC6.b): (i) CLI stdout from a `bin/specflow-*` script; (ii) a STATUS Notes line; (iii) a commit message — all stay English regardless of config.
  - Be **English-only** (AC2.a): no codepoint outside ASCII + standard Latin-1 punctuation. This is the novelty of the file — the directive is in English even though it *instructs* zh-TW behaviour. t51 self-lints this file via `bin/specflow-lint scan-paths` once B3 lands.

  **Index row (append in the `common` section, sorted alphabetically between `classify-before-mutate` and `no-force-on-user-paths`):**
  ```
  | language-preferences | common | should | [common/language-preferences.md](common/language-preferences.md) |
  ```
- **Acceptance**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/language-preferences.md` returns 0.
  - `head -7 /Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/language-preferences.md | grep -E '^(name|scope|severity|created|updated):' | wc -l` equals 5.
  - `grep -c 'language-preferences' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md` ≥ 1; the row sits between `classify-before-mutate` and `no-force-on-user-paths`.
  - `grep -F 'LANG_CHAT=zh-TW' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/language-preferences.md` returns ≥ 1 line.
  - `LC_ALL=C grep -Pn '[^\x00-\x7F\xA0-\xFF]' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/language-preferences.md` returns empty (ASCII + Latin-1 only). (Note: tech §3 D6 lists the exact CJK ranges scanned by the guardrail; this grep is a pre-B3 proxy.)
- **Dependencies**: none
- **Parallel-safe-with**: T2, T3 (different files; T1 is the sole editor of both the new rule file and `.claude/rules/index.md` in W1)
- **Notes**: bundles both rule-file create and index row append because they are paired logically (new rule implies new row) and `.claude/rules/index.md` has no other editor this feature. Structural verification of AC1.b / AC5.a / AC7.* is deferred to W3 tests + post-archive manual smoke per `shared/dogfood-paradox-third-occurrence.md` (7th occurrence).
- [x] T1

---

## T2 — Extend `.claude/hooks/session-start.sh` with `lang.chat` sniff + marker emit
- **Block**: B2
- **Wave**: W1
- **Owner role**: developer
- **Requirements**: R1 (AC1.a, AC1.b, AC1.c), R7 (AC7.a, AC7.b, AC7.c)
- **Decisions**: D5 (marker emission), D7 (hook edit diff sketch), D9 (schema shape)
- **Files touched**:
  - **modify**: `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` (single block inserted between the existing digest assembly and the JSON-emit step; no other edits to the file)
- **Briefing** (verbatim contract fragments — do not paraphrase):

  **D7 hook edit block (verbatim from `04-tech.md` §3 D7, minimal diff sketch):**
  ```bash
  # ... existing digest assembly ...

  # New: read lang.chat from config, append marker line if set
  cfg_file=".spec-workflow/config.yml"
  if [ -r "$cfg_file" ]; then
    cfg_chat=$(awk '
      /^lang:/        {in_lang=1; next}
      in_lang && /^  chat:/ {
        sub(/^  chat:[[:space:]]*/, "")
        gsub(/"/, ""); gsub(/#.*$/, "")
        gsub(/[[:space:]]+$/, "")
        print; exit
      }
      /^[^ ]/         {in_lang=0}
    ' "$cfg_file" 2>/dev/null)

    case "$cfg_chat" in
      zh-TW|en)
        if [ -n "$digest" ]; then
          digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
        else
          digest="LANG_CHAT=$cfg_chat"
        fi
        ;;
      "")
        # Empty / absent key — default-off, no warning
        :
        ;;
      *)
        log_warn "config.yml: lang.chat has unknown value '$cfg_chat' — ignored"
        ;;
    esac
  fi

  # ... existing JSON-emit ...
  ```
  The block is ~20 lines; bash 3.2 + BSD safe (no `[[ =~ ]]`, no `readlink -f`, no `jq`, `case`-based state machine). Insertion point: after `digest` is fully assembled, before it is passed to the JSON-emit helper. Do not change the existing `set +e` / `trap 'exit 0' ERR INT TERM` block; the new lines inherit this fail-safe discipline.

  **Marker string (verbatim from D5 / D7):** `LANG_CHAT=zh-TW` (when `cfg_chat=zh-TW`) or `LANG_CHAT=en` (when `cfg_chat=en`). The exact literal string the rule body (T1) references is `LANG_CHAT=zh-TW`. t53 grep-checks both sides for drift.

  **Fail-safe contract (architect memory `hook-fail-safe-pattern.md`, applies to this edit):**
  - Missing `cfg_file` → silent skip (no warning, no marker). AC7.c.
  - Malformed YAML that yields empty `cfg_chat` → silent skip (no warning, no marker). AC7.b's "warning" path fires only when a value IS present but unrecognised.
  - Unknown value (e.g. `fr`) → one `log_warn` line to stderr, no marker. AC7.a.
  - Recognised value (`zh-TW` or `en`) → append marker line; no stderr. AC1.b.
  - Hook always exits 0 regardless of config state.

  **D9 YAML schema (verbatim, shape the `awk` sniff accepts — this is the exact v1 schema):**
  ```yaml
  # .spec-workflow/config.yml
  lang:
    chat: zh-TW    # or "en" (explicit default) — any other value → warning + default-off
  ```

  **Portability constraints** (cross-ref `.claude/rules/bash/bash-32-portability.md`, enforced by t63):
  - No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]`.
  - The `case "$cfg_chat" in zh-TW|en) … ;;` pattern in the block above is portable; do not rewrite as `[[ =~ ]]`.

- **Acceptance**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` returns 0.
  - `grep -F 'LANG_CHAT=' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` returns ≥ 1 line.
  - `grep -F 'awk' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh | grep -F 'lang:'` returns ≥ 1 line.
  - `grep -En 'readlink -f|realpath|jq|mapfile|\[\[ .*=~' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` returns empty.
  - `grep -F 'set +e' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` still present (fail-safe discipline preserved).
- **Dependencies**: none (T1 and T2 are paired logically via the marker string, but there is no file-edit dependency between them; t53 in W3 validates the coupling).
- **Parallel-safe-with**: T1, T3 (different files)
- **Notes**: Dogfood paradox — this hook edit cannot fire on the session that implemented it. AC1.a / AC1.b / AC7.* get structural PASS via t54–t57 in W3; runtime confirmation deferred to first session after archive + restart per `shared/dogfood-paradox-third-occurrence.md`. Performance: `awk` is single-file single-pass; well under the 200 ms hook budget per `.claude/rules/reviewer/performance.md`.
- [x] T2

---

## T3 — Create `bin/specflow-lint` (bash shim + Python 3 scanner)
- **Block**: B3
- **Wave**: W1
- **Owner role**: developer
- **Requirements**: R5 (AC5.a, AC5.b, AC5.c, AC5.d — shim presence side is T10; this task ships the scan engine that T10's shim execs)
- **Decisions**: D2 (guardrail surface = pre-commit → `bin/specflow-lint`), D6 (Unicode range + classifier enum + allowlist mechanics), D8 (no env-var bypass)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint` (bash shim + Python 3 heredoc, exec bit set)
- **Briefing** (verbatim contract fragments — do not paraphrase):

  **D6 classifier output contract (verbatim from `04-tech.md` §3 D6):**
  ```
  ok:<path>
  cjk-hit:<path>:<line>:<col>:U+<hex>
  allowlisted:<path>:<reason>
  binary-skip:<path>
  ```
  > Final exit code: 0 if every path is `ok`, `allowlisted`, or `binary-skip`; 1 if any `cjk-hit`. No mutation anywhere in the script; the classifier is pure.

  **D6 scanned Unicode ranges (v1, verbatim from `04-tech.md` §3 D6):**
  > - **U+3400–U+4DBF** CJK Unified Ideographs Extension A
  > - **U+4E00–U+9FFF** CJK Unified Ideographs (the main block)
  > - **U+3000–U+303F** CJK Symbols and Punctuation (punctuation-only; see allowlist below)
  > - **U+3040–U+309F** Hiragana (forward-compat, catches ja leaks)
  > - **U+30A0–U+30FF** Katakana (forward-compat)
  > - **U+AC00–U+D7AF** Hangul Syllables (forward-compat)
  > - **U+F900–U+FAFF** CJK Compatibility Ideographs
  > - **U+FF00–U+FFEF** Halfwidth and Fullwidth Forms

  Implementation: the Python 3 scanner iterates each decoded code point of each scanned file and tests membership against the union of these eight closed ranges. Exact predicate (suggested):
  ```python
  CJK_RANGES = (
      (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0x3000, 0x303F),
      (0x3040, 0x309F), (0x30A0, 0x30FF), (0xAC00, 0xD7AF),
      (0xF900, 0xFAFF), (0xFF00, 0xFFEF),
  )
  def is_cjk(cp: int) -> bool:
      return any(lo <= cp <= hi for (lo, hi) in CJK_RANGES)
  ```

  **D6 in-scope paths (verbatim from `04-tech.md` §3 D6):**
  > - `.spec-workflow/features/**` (all, **except** the `00-request.md` files' bounded request-quote pattern — see allowlist).
  > - `.claude/**` (agents, rules, commands, hooks, team-memory, skills).
  > - `bin/**`
  > - `test/**` (except explicitly-marked CJK fixtures — see allowlist).
  > - `*.md` at the repo root.

  **D6 out-of-scope paths (verbatim):**
  > - `.spec-workflow/archive/**` — PRD Non-goals explicitly excludes archive.
  > - `.git/**`
  > - `node_modules/**`, any binary file (`file` or extension-based probe) — `binary-skip` classification.

  **D6 allowlist mechanism (verbatim — two surfaces, both greppable):**
  > - **Path pattern allowlist** at the top of `bin/specflow-lint` (Python dict): `.spec-workflow/features/**/00-request.md` — but only within a block bounded by the markers the request-quote convention uses (a literal `**Raw ask**:` prefix line). Lines between the first `**Raw ask**:` line and the following blank line are permitted CJK. Every other line in that file is scanned.
  > - **Inline marker allowlist**: any file containing a `<!-- specflow-lint: allow-cjk reason="..." -->` HTML comment (on its own line) suppresses CJK scanning for that file entirely. Used for test fixtures (e.g., `test/fixtures/*.md` that carry deliberate CJK for the guardrail's own smoke test). The reason is mandatory and grep-verifiable; accidental use is distinguishable from intentional.

  **Subcommand surface (D2 + §4):**
  - `bin/specflow-lint scan-staged` — default subcommand invoked by pre-commit; reads `git diff --cached --name-only` to get the staged path list; for each path, reads staged content via `git show :FILE` and classifies.
  - `bin/specflow-lint scan-paths <path>...` — ad-hoc; scans the given on-disk paths directly.
  - `bin/specflow-lint --help` / `-h` / `""` → usage to stdout, exit 0.

  **Exit code contract (verbatim from `04-tech.md` §4):**
  > - `0` — every scanned path classified `ok`, `allowlisted`, or `binary-skip`.
  > - `1` — one or more `cjk-hit` findings; report printed to stderr.
  > - `2` — usage error, Python 3 missing, or internal error (e.g., the script itself was tampered with and self-check fails).

  **Stdout vs stderr split (§4 Logging):**
  - **stdout**: one line per scanned path in the classifier output contract form above. Parseable by CI/audit scripts.
  - **stderr**: only the summary / error messages (e.g., "2 cjk-hit findings", "Python 3 required").

  **Shell discipline:** `set -u -o pipefail`; NOT `-e` (accumulate findings across files). Bash 3.2 + BSD portability per `.claude/rules/bash/bash-32-portability.md`: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic. Preflight: `command -v python3 >/dev/null || { echo "python3 required" >&2; exit 2; }`.

  **Security posture** (cross-ref `.claude/rules/reviewer/security.md`):
  - Input validation at the boundary: `git diff --cached --name-only` output is the sole untrusted input; Python opens each path read-only via `git show :FILE` (or via direct file read in `scan-paths` mode). No shell-concatenation; use argv-form invocation.
  - No `rm -rf`, no `--force`, no mutation.

- **Acceptance**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint` returns 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint` returns 0.
  - `python3 -c "compile(open('/Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint').read(), 'bin/specflow-lint', 'exec')"` returns 0 (bash shim parses as bash; Python heredoc compiles as Python via `py_compile` if extracted — verify by a dry invocation below).
  - `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint --help` exits 0 and prints usage.
  - `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint scan-paths /Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/no-force-on-user-paths.md` exits 0 (ASCII rule file — no CJK; classified `ok:`).
  - `grep -En 'readlink -f|realpath|jq|mapfile|\[\[ .*=~|rm -rf| --force' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint` returns empty.
  - `grep -F 'specflow-lint: allow-cjk' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-lint` returns ≥ 1 line (allowlist marker literal present in scanner logic).
- **Dependencies**: none (B4 in W2 consumes this; t58–t62 in W3 consume this)
- **Parallel-safe-with**: T1, T2 (different files)
- **Notes**: This is the single-purpose CLI; no existing dispatcher to collide with. Scanner is pure classifier (no mutation) per `.claude/rules/common/classify-before-mutate.md`. Dogfood paradox: real-commit rejection cannot be exercised on this feature's own commits (the pre-commit shim isn't installed until T10); structural PASS via t58–t62 sandbox commits in W3.
- [x] T3

---

## T4 — Extend `bin/specflow-seed` with pre-commit shim install (classifier state + dispatcher arm + summary emit)
- **Block**: B4
- **Wave**: W2
- **Owner role**: developer
- **Requirements**: R5 (AC5.d — bypass is explicit via `--no-verify` plus the inline marker; guardrail installs by default)
- **Decisions**: D3 (one-line shim + classify-before-mutate state extension), D2 (pre-commit surface)
- **Files touched**:
  - **modify**: `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` (three intra-file additions in one pass — single-editor, serialized within this task)
- **Briefing** (verbatim contract fragments — do not paraphrase):

  **Pre-commit shim content (verbatim from D3):**
  > `.git/hooks/pre-commit` (installed per-consumer) — 2-line shim that execs `bin/specflow-lint scan-staged`.

  Exact shim bytes (the installer writes this content to `<consumer>/.git/hooks/pre-commit`, then `chmod +x`):
  ```bash
  #!/usr/bin/env bash
  # specflow-lint: pre-commit shim — installed by bin/specflow-seed init/migrate
  exec bin/specflow-lint scan-staged "$@"
  ```
  The comment line (second line) contains the sentinel string `specflow-lint: pre-commit shim` — the installer uses this to distinguish our own shim from a foreign one. Any grep-verifiable sentinel with the literal `specflow-lint` substring is acceptable; the exact wording above is recommended.

  **Classify-before-mutate discipline (verbatim from `.claude/rules/common/classify-before-mutate.md` + D3):**

  Extend the existing `bin/specflow-seed` pre-install classifier with one new state (classify inputs, dispatch mutations; never mutate inside the classifier):

  | State | Meaning | Action |
  |---|---|---|
  | `missing` | `.git/hooks/pre-commit` does not exist | write shim; `chmod +x`; report `created:.git/hooks/pre-commit` |
  | `ok` | `.git/hooks/pre-commit` exists AND contains the `specflow-lint` sentinel | no-op; report `already:.git/hooks/pre-commit` |
  | `foreign-pre-commit` | `.git/hooks/pre-commit` exists AND does NOT contain the `specflow-lint` sentinel | **skip + report**; do NOT clobber; emit `skipped:foreign-pre-commit:.git/hooks/pre-commit`; set `MAX_CODE=1` |

  **No-force discipline (verbatim from `.claude/rules/common/no-force-on-user-paths.md`):**
  > **No `--force` in v1.** Default behavior for any conflicting target is report-and-skip: emit `skipped:<reason>` per target, exit non-zero if any skip occurred.
  > **Back up before overwriting.** When a mutation must replace an existing user-owned file, write the backup first (`cp file file.bak` or `cp settings.json settings.json.bak`) before any write. Use an atomic swap (`os.replace` / `mv`) so the live file is never partially written.

  For the `missing` state's write path: use the existing `bin/specflow-seed` atomic-write helper (`write_atomic <dst> <content-on-stdin>` per its W1 library); write to `<dst>.tmp` and `os.replace(tmp, dst)`. No partial-write window. For the `foreign-pre-commit` state: **do NOT** overwrite, **do NOT** back up, **do NOT** touch the file; just report and continue.

  **Three intra-function additions inside `bin/specflow-seed`** (single-editor task — these three edits all touch the same file and must serialize within this task; per `tpm/parallel-safe-requires-different-files.md` there is no peer task in W2):
  1. **Classifier extension**: add a function `classify_pre_commit_shim <consumer_root>` that returns one of `missing` / `ok` / `foreign-pre-commit` per the table above. Pure function, no mutation.
  2. **Dispatcher arm in `cmd_init` and `cmd_migrate`**: after the managed-subtree copy loop completes and the manifest has been written, invoke the classifier, then:
     - `missing` → write the shim via `write_atomic`; `chmod +x`; append `created:.git/hooks/pre-commit` to the summary list.
     - `ok` → append `already:.git/hooks/pre-commit`.
     - `foreign-pre-commit` → append `skipped:foreign-pre-commit:.git/hooks/pre-commit`; set `MAX_CODE=1`.
  3. **Summary emit**: update the existing summary-line (`summary: created=N already=N replaced=N skipped=N (exit K)`) so the pre-commit outcome counts toward the existing verb tallies. Do not invent new verbs (per R12 of the archived per-project-install feature; the closed verb set is documented in `README.md`).

  **What NOT to change** (out of scope for T4):
  - The managed subtree list (pre-commit is NOT a managed file under `.claude/` — it lives at `.git/hooks/pre-commit`, which is per-consumer and never tracked).
  - The manifest schema (`.claude/specflow.manifest`; pre-commit is not recorded there — it is an install-side effect, not a managed artefact).
  - The copy-plan logic (`plan_copy`).
  - The `cmd_update` flow (per tech §6 Non-decisions D11: fresh-clone install of the shim alone is deferred; `update` does not install hooks).

  **Portability:** `.claude/rules/bash/bash-32-portability.md`. No `readlink -f`, `realpath`, `jq`, `mapfile`, `[[ =~ ]]`. Use `[ -f "$x" ] && grep -F 'specflow-lint' "$x" >/dev/null 2>&1` to probe the sentinel, not `[[ =~ ]]`.

- **Acceptance**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns 0.
  - `grep -F 'foreign-pre-commit' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns ≥ 1 line (classifier state landed).
  - `grep -F '.git/hooks/pre-commit' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns ≥ 1 line (dispatcher arm landed).
  - `grep -F 'specflow-lint' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns ≥ 1 line (sentinel string present in the shim content the installer writes).
  - `grep -En 'readlink -f|realpath|jq|mapfile|\[\[ .*=~|rm -rf| --force' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns empty.
  - Hidden probe (optional, per T2 precedent): `bin/specflow-seed __probe classify-pre-commit <consumer_root>` (if implemented) returns one of the three enum strings on stdout; this is an OPTIONAL addition for TDD — not a gating assertion.
- **Dependencies**: T3 (the shim content references `bin/specflow-lint` by path; at runtime-test time in W3, `bin/specflow-lint` must exist in the source tree being copied. At code-edit time the dependency is schema-only — the string `bin/specflow-lint scan-staged` is fixed.)
- **Parallel-safe-with**: — (sole task in W2; all three edits touch `bin/specflow-seed` and serialize within this task per `tpm/parallel-safe-requires-different-files.md`)
- **Notes**: **single-editor; all three intra-function edits on the same file serialize inside this task**. No parallelism possible within W2. No peer task this feature; cross-feature concurrency not currently a concern. Exit-code semantics: `MAX_CODE=1` on `foreign-pre-commit` matches existing `skipped:*` exit convention.
- [ ]

---

## T5 — `test/t51_rule_file_shape.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer (QA-tester optional — structural static test)
- **Requirements**: R2 (AC2.a, AC2.b, AC2.d), R3 (AC3.a, AC3.b), R4 (AC4.b), R6 (AC6.a, AC6.b)
- **Decisions**: D4, D6 (self-lint via `bin/specflow-lint scan-paths`)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t51_rule_file_shape.sh` (exec bit set)
- **Briefing**:

  Create an executable bash test that asserts:
  1. File exists: `.claude/rules/common/language-preferences.md`.
  2. Frontmatter has exactly the five keys `name`, `scope`, `severity`, `created`, `updated` (from `.claude/rules/README.md` schema — quoted verbatim in T1's briefing above).
  3. Frontmatter values: `name: language-preferences`, `scope: common`, `severity: should`.
  4. Body has `## Rule`, `## Why`, `## How to apply` sections in that order.
  5. Body is English-only: `bin/specflow-lint scan-paths .claude/rules/common/language-preferences.md` exits 0 (self-lint — the rule body is the first file the guardrail scans against itself; AC2.a).
  6. Conditional pattern documented: body contains both `LANG_CHAT=zh-TW` AND a phrase matching "otherwise" / "no-op" (AC2.b's conditional documentation).
  7. Six carve-outs enumerated (AC3.a): body grep-matches each of (a)–(f) concretely — file writes, tool-call arguments, commit messages, CLI stdout, STATUS Notes, team-memory.
  8. No reverse directive (AC3.b): body does NOT contain a zh-TW instruction for file content (grep-check for phrases like "write … in zh-TW" returns empty).
  9. Seven subagent roles named (AC4.b): `PM`, `Architect`, `TPM`, `Developer`, `QA-analyst`, `QA-tester`, `Designer`.
  10. Positive scope example (AC6.a) and ≥3 negative scope examples (AC6.b).

  **Test uses the pure-static form (no sandbox needed — pure filesystem grep assertions).** But — per `.claude/rules/bash/bash-32-portability.md` — no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic. Portable `grep -F` / `grep -E` / `grep -q` only.

  **Shell shape:**
  ```bash
  #!/usr/bin/env bash
  set -u -o pipefail
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  RULE="$REPO_ROOT/.claude/rules/common/language-preferences.md"
  # ... assertions ...
  echo PASS; exit 0
  ```
  On assertion failure: `echo "FAIL: <label>: <reason>" >&2; exit 1`.

- **Acceptance**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t51_rule_file_shape.sh` returns 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t51_rule_file_shape.sh` returns 0.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t51_rule_file_shape.sh` exits 0 when T1 and T3 have landed (RED pre-T1 for the right reason: rule file missing).
- **Dependencies**: T1 (rule file content), T3 (lint CLI for step 5's self-lint)
- **Parallel-safe-with**: T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20 (all W3 test files), T21 (smoke register), T22 (README)
- **Notes**: static test; no sandbox needed. Structural PASS only per R9 / `shared/dogfood-paradox-third-occurrence.md`.
- [ ]

---

## T6 — `test/t52_rule_index_row.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R2 (AC2.c)
- **Decisions**: D4 (index row placement)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t52_rule_index_row.sh` (exec bit set)
- **Briefing**:

  Assert `.claude/rules/index.md` contains a row for `language-preferences` with scope `common` + severity `should`, sorted alphabetically between `classify-before-mutate` and `no-force-on-user-paths`.

  Portable shell (bash 3.2, grep -E / grep -n / awk). Assertion set:
  1. Row present: `grep -E '^\| language-preferences \| common \| should \|' .claude/rules/index.md` returns ≥ 1 line.
  2. Alphabetical placement: use `grep -n 'language-preferences\|classify-before-mutate\|no-force-on-user-paths' .claude/rules/index.md`; confirm the three line numbers are in ascending order `classify-before-mutate < language-preferences < no-force-on-user-paths`.
  3. Row points to the correct file: the link target is `common/language-preferences.md`.

  No sandbox needed. `echo PASS; exit 0` on success; `FAIL: <label>` / exit 1 on miss.
- **Acceptance**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t52_rule_index_row.sh` returns 0; `test -x` returns 0.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t52_rule_index_row.sh` exits 0 after T1.
- **Dependencies**: T1
- **Parallel-safe-with**: T5, T7..T22 (all W3 peers)
- [ ]

---

## T7 — `test/t53_marker_rule_coupling.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: guards D5 tradeoff — marker string drift between hook and rule body (risk R2 in plan §5)
- **Decisions**: D5 (marker-plus-conditional-prose coupling)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t53_marker_rule_coupling.sh` (exec bit set)
- **Briefing**:

  Assert the exact marker string `LANG_CHAT=zh-TW` appears in exactly two files: the hook (`.claude/hooks/session-start.sh`) and the rule body (`.claude/rules/common/language-preferences.md`). Any drift in either side must fail this test.

  Implementation sketch:
  ```bash
  cd "$REPO_ROOT"
  files=$(grep -lF 'LANG_CHAT=zh-TW' .claude/hooks/session-start.sh .claude/rules/common/language-preferences.md 2>/dev/null | sort -u)
  expected=".claude/hooks/session-start.sh
  .claude/rules/common/language-preferences.md"
  expected_sorted=$(printf '%s\n' "$expected" | sort -u)
  [ "$files" = "$expected_sorted" ] || { echo "FAIL: coupling drift — got: $files" >&2; exit 1; }
  # Also scan the whole repo (excluding archive + .git) to assert no third file mentions the literal marker.
  unexpected=$(grep -rlF 'LANG_CHAT=zh-TW' . --exclude-dir=.git --exclude-dir=archive 2>/dev/null | grep -v '^\./\.claude/hooks/session-start\.sh$' | grep -v '^\./\.claude/rules/common/language-preferences\.md$' | grep -v '^\./test/t53_' | grep -v '^\./\.spec-workflow/features/20260419-language-preferences/' || true)
  [ -z "$unexpected" ] || { echo "FAIL: marker appears in unexpected files: $unexpected" >&2; exit 1; }
  echo PASS; exit 0
  ```
  (The third-file exclusion allows this test file itself and the feature spec to mention the marker for documentation without tripping the coupling check. t53's own mention is expected; feature spec files may reference the marker.)
- **Acceptance**:
  - `bash -n test/t53_marker_rule_coupling.sh` returns 0; `test -x` returns 0.
  - `bash test/t53_marker_rule_coupling.sh` exits 0 after T1 and T2.
- **Dependencies**: T1, T2
- **Parallel-safe-with**: T5, T6, T8..T22
- [ ]

---

## T8 — `test/t54_hook_config_absent.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R1 (AC1.a, AC1.c), R7 (AC7.c)
- **Decisions**: D7 (hook fail-safe), D9 (missing file = absence is ordinary)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t54_hook_config_absent.sh` (exec bit set)
- **Briefing**:

  Integration test. Sandbox `$HOME` with NO `.spec-workflow/config.yml`; run `.claude/hooks/session-start.sh` under `HOOK_TEST=1`; assert digest contains NO `LANG_CHAT=` line, stderr is clean, exit 0.

  **Sandbox preflight (verbatim from `.claude/rules/bash/sandbox-home-in-tests.md` — mandatory at the top of every integration test):**
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
  (The `set -euo pipefail` line is from the sandbox-home-in-tests.md example; specflow tests generally use `set -u -o pipefail` for accumulate-and-continue semantics — choose per neighbour convention. If the existing `test/t5*.sh` siblings use `set -u -o pipefail`, match them; otherwise use the example verbatim.)

  **Test steps:**
  1. Inside `$SANDBOX/consumer`, init a minimal repo. Do NOT create `.spec-workflow/config.yml`.
  2. Invoke `.claude/hooks/session-start.sh` under `HOOK_TEST=1` (or whatever the existing hook test-mode env var is — inspect the hook to confirm) from the sandbox consumer's cwd.
  3. Capture stdout (the JSON payload) and stderr.
  4. Assert stdout does NOT contain `LANG_CHAT=`.
  5. Assert stderr is empty (no warning — missing file is the ordinary case, AC7.c).
  6. Assert hook exit code is 0.
- **Acceptance**:
  - `bash -n test/t54_hook_config_absent.sh` returns 0; `test -x` returns 0.
  - `bash test/t54_hook_config_absent.sh` exits 0 after T2.
- **Dependencies**: T2
- **Parallel-safe-with**: T5..T7, T9..T22
- **Notes**: Dogfood paradox — structural PASS in sandbox; runtime PASS deferred to next feature after session restart per R9.
- [ ]

---

## T9 — `test/t55_hook_config_zh_tw.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R1 (AC1.b)
- **Decisions**: D5, D7, D9
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t55_hook_config_zh_tw.sh` (exec bit set)
- **Briefing**:

  Sandbox `$HOME` with a `.spec-workflow/config.yml` that matches the exact D9 schema:
  ```yaml
  lang:
    chat: zh-TW
  ```
  (Two-space indent under `lang:`; no quoting; no inline comment on the `chat:` line — this is the shape the `awk` sniff in T2 accepts.)

  Run the hook under `HOOK_TEST=1`. Assertions:
  1. Hook stdout contains `LANG_CHAT=zh-TW` somewhere in the digest / additional-context payload.
  2. Stderr is empty (recognised value → no warning).
  3. Exit code 0.

  Use the sandbox preflight block from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t55_hook_config_zh_tw.sh` returns 0; `test -x` returns 0.
  - `bash test/t55_hook_config_zh_tw.sh` exits 0 after T2.
- **Dependencies**: T2
- **Parallel-safe-with**: T5..T8, T10..T22
- **Notes**: Structural PASS only; runtime deferred per R9.
- [ ]

---

## T10 — `test/t56_hook_config_unknown.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R7 (AC7.a)
- **Decisions**: D7 (unknown value → one stderr warning + default-off)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t56_hook_config_unknown.sh` (exec bit set)
- **Briefing**:

  Sandbox config:
  ```yaml
  lang:
    chat: fr
  ```
  Invoke the hook. Assertions:
  1. Stdout does NOT contain `LANG_CHAT=`.
  2. Stderr contains exactly one warning line mentioning `lang.chat` and the invalid value `fr` (match the `log_warn` format from the hook sketch in T2; `grep -c 'lang.chat' stderr.log` should be 1).
  3. Exit code 0 (hook never blocks session start).

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t56_hook_config_unknown.sh` returns 0; `test -x` returns 0.
  - `bash test/t56_hook_config_unknown.sh` exits 0 after T2.
- **Dependencies**: T2
- **Parallel-safe-with**: T5..T9, T11..T22
- **Notes**: Structural PASS; runtime deferred per R9.
- [ ]

---

## T11 — `test/t57_hook_config_malformed.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R7 (AC7.b)
- **Decisions**: D7 (malformed YAML → default-off + one warning + exit 0)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t57_hook_config_malformed.sh` (exec bit set)
- **Briefing**:

  Sandbox config with syntactically broken YAML, e.g.:
  ```yaml
  lang
    chat zh-TW
  :::garbage:::
  ```
  (No colon after `lang`; no indent hierarchy; `awk` sniff should yield empty `cfg_chat`.)

  Run the hook. Assertions:
  1. Stdout does NOT contain `LANG_CHAT=`.
  2. Either (a) stderr is empty (because the `awk` sniff yielded empty — "" branch, silent) OR (b) stderr has at most one warning line. Accept both — the critical invariant is "no marker + no crash + exit 0".
  3. Hook exit code 0 (fail-safe discipline — session never blocked on malformed config).

  Note: because the `awk` sniff is narrow (per D7 tradeoffs), most malformed shapes produce empty `cfg_chat` and hit the `""` branch (silent). Only shapes that match the narrow pattern but produce an unrecognised value hit the warn-branch. Either outcome satisfies AC7.b as long as exit is 0 and no marker is emitted.

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t57_hook_config_malformed.sh` returns 0; `test -x` returns 0.
  - `bash test/t57_hook_config_malformed.sh` exits 0 after T2.
- **Dependencies**: T2
- **Parallel-safe-with**: T5..T10, T12..T22
- **Notes**: Structural PASS; runtime deferred per R9.
- [ ]

---

## T12 — `test/t58_lint_clean_diff.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.b — clean-diff passes silently)
- **Decisions**: D6 (classifier enum — `ok` path)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t58_lint_clean_diff.sh` (exec bit set)
- **Briefing**:

  Integration test. Set up a sandbox git repo, stage a variety of ASCII-only files across `.claude/**`, `.spec-workflow/features/**`, and `bin/**`, then run `bin/specflow-lint scan-staged` from within the sandbox consumer.

  Assertions:
  1. Exit code 0 (AC5.b: clean-diff passes).
  2. Stdout emits one `ok:<path>` line per staged path (D6 contract).
  3. Stderr is clean (no "cjk-hit" summary) or contains a benign success summary.

  Sandbox preflight from T8 verbatim, extended with `git init` + `git config user.email` + `git config user.name`.
- **Acceptance**:
  - `bash -n test/t58_lint_clean_diff.sh` returns 0; `test -x` returns 0.
  - `bash test/t58_lint_clean_diff.sh` exits 0 after T3.
- **Dependencies**: T3
- **Parallel-safe-with**: T5..T11, T13..T22
- **Notes**: Structural PASS; runtime deferred per R9.
- [ ]

---

## T13 — `test/t59_lint_cjk_hit.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.a — rejection path)
- **Decisions**: D6 (`cjk-hit:<file>:<line>:<col>:U+<hex>` output format)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t59_lint_cjk_hit.sh` (exec bit set)
- **Briefing**:

  Integration test. Sandbox git repo; stage one `.md` file containing a zh-TW sentence (e.g., `echo '這是中文' > 01-brainstorm.md; git add 01-brainstorm.md`). Run `bin/specflow-lint scan-staged`.

  Assertions:
  1. Exit code 1 (AC5.a: rejection).
  2. Stdout contains exactly one line matching `cjk-hit:<f>:<l>:<c>:U\+[0-9A-F]+` (D6 classifier output format — file, line, column, codepoint in uppercase hex).
  3. Stderr contains a human-readable summary (e.g., "1 cjk-hit finding").

  Fixture content MUST contain a codepoint inside one of the D6 scanned Unicode ranges (verbatim from `04-tech.md` §3 D6 — quoted in T3's briefing above).

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t59_lint_cjk_hit.sh` returns 0; `test -x` returns 0.
  - `bash test/t59_lint_cjk_hit.sh` exits 0 after T3 (test passes when the lint correctly rejects the fixture with exit 1).
- **Dependencies**: T3
- **Parallel-safe-with**: T5..T12, T14..T22
- **Notes**: Structural PASS; runtime deferred per R9.
- [ ]

---

## T14 — `test/t60_lint_request_quote_allowlist.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.c — allowlist scope: request-quote pattern)
- **Decisions**: D6 (allowlist surface 1 — path + `**Raw ask**:` block matcher)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t60_lint_request_quote_allowlist.sh` (exec bit set)
- **Briefing**:

  **Allowlist pattern (verbatim from D6, surface 1):**
  > **Path pattern allowlist** at the top of `bin/specflow-lint` (Python dict): `.spec-workflow/features/**/00-request.md` — but only within a block bounded by the markers the request-quote convention uses (a literal `**Raw ask**:` prefix line). Lines between the first `**Raw ask**:` line and the following blank line are permitted CJK. Every other line in that file is scanned.

  Integration test. Two sub-cases:

  **Case A (zh-TW inside the allowlist block → exit 0, `allowlisted:…:request-quote`):**
  Stage a fixture at `.spec-workflow/features/fixture/00-request.md` containing:
  ```markdown
  # Request

  **Raw ask**:
  這是一段中文請求。
  繼續多行。

  ## Normalised intent

  English-only body here.
  ```
  Run `bin/specflow-lint scan-staged`. Expect exit 0; stdout contains `allowlisted:<path>:request-quote`.

  **Case B (zh-TW outside the allowlist block → exit 1):**
  Stage a fixture with zh-TW in the `## Normalised intent` section. Expect exit 1; `cjk-hit:` emitted.

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t60_lint_request_quote_allowlist.sh` returns 0; `test -x` returns 0.
  - `bash test/t60_lint_request_quote_allowlist.sh` exits 0 after T3.
- **Dependencies**: T3
- **Parallel-safe-with**: T5..T13, T15..T22
- **Notes**: Structural PASS.
- [ ]

---

## T15 — `test/t61_lint_inline_marker_allowlist.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.c — allowlist surface 2: inline marker)
- **Decisions**: D6 (allowlist surface 2 — HTML comment with mandatory `reason=`)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t61_lint_inline_marker_allowlist.sh` (exec bit set)
- **Briefing**:

  **Allowlist pattern (verbatim from D6, surface 2):**
  > **Inline marker allowlist**: any file containing a `<!-- specflow-lint: allow-cjk reason="..." -->` HTML comment (on its own line) suppresses CJK scanning for that file entirely. Used for test fixtures (e.g., `test/fixtures/*.md` that carry deliberate CJK for the guardrail's own smoke test). The reason is mandatory and grep-verifiable; accidental use is distinguishable from intentional.

  Integration test. Two sub-cases:

  **Case A (marker present, zh-TW content → exit 0, `allowlisted:…:inline-marker`):**
  Stage a fixture, e.g. `test/fixtures/cjk_sample.md`, containing:
  ```markdown
  <!-- specflow-lint: allow-cjk reason="fixture for t61 integration test" -->

  這是測試夾具的中文內容。
  ```
  Run `bin/specflow-lint scan-staged`. Expect exit 0; stdout contains `allowlisted:<path>:inline-marker`.

  **Case B (remove marker, same zh-TW content → exit 1):**
  Rewrite the same fixture without the marker line. Expect exit 1; `cjk-hit:` emitted.

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t61_lint_inline_marker_allowlist.sh` returns 0; `test -x` returns 0.
  - `bash test/t61_lint_inline_marker_allowlist.sh` exits 0 after T3.
- **Dependencies**: T3
- **Parallel-safe-with**: T5..T14, T16..T22
- [ ]

---

## T16 — `test/t62_lint_archive_ignored.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.c — archive out of scope), PRD Non-goals (archive excluded)
- **Decisions**: D6 (out-of-scope path: `.spec-workflow/archive/**`)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t62_lint_archive_ignored.sh` (exec bit set)
- **Briefing**:

  Stage a zh-TW file under `.spec-workflow/archive/20260101-example/foo.md` in the sandbox consumer. Run `bin/specflow-lint scan-staged`. Assertions:
  1. Exit code 0 (archive is out of scope; the scanner either omits the path entirely or classifies it as `binary-skip` / similar — do not classify as `cjk-hit`).
  2. Stdout does NOT contain a `cjk-hit:` line for the archive path.

  Sandbox preflight from T8 verbatim.
- **Acceptance**:
  - `bash -n test/t62_lint_archive_ignored.sh` returns 0; `test -x` returns 0.
  - `bash test/t62_lint_archive_ignored.sh` exits 0 after T3.
- **Dependencies**: T3
- **Parallel-safe-with**: T5..T15, T17..T22
- [ ]

---

## T17 — `test/t63_lint_no_jq_no_readlink_f.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: `.claude/rules/bash/bash-32-portability.md` (all new bash)
- **Decisions**: D2, D7 (portability enforced across the new bash surfaces)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t63_lint_no_jq_no_readlink_f.sh` (exec bit set)
- **Briefing**:

  Static test. Grep over the three new / edited bash files for prohibited tokens:

  Files to scan:
  - `bin/specflow-lint` (new)
  - `.claude/hooks/session-start.sh` (edited — scan the entire file; the existing content was already portable, but reviewing the whole file is cheap and catches any accidental drift in the new block)
  - `bin/specflow-seed` (edited — scan the entire file; same justification)

  Prohibited tokens (verbatim from `.claude/rules/bash/bash-32-portability.md`):
  ```
  readlink -f
  realpath
  jq
  mapfile
  [[ .*=~
  rm -rf
   --force
  ```

  Assertion: `grep -En 'readlink -f|realpath|jq|mapfile|\[\[ .*=~|rm -rf| --force' <each-file>` returns empty for each file. If any match, fail with the file and matching line number.
- **Acceptance**:
  - `bash -n test/t63_lint_no_jq_no_readlink_f.sh` returns 0; `test -x` returns 0.
  - `bash test/t63_lint_no_jq_no_readlink_f.sh` exits 0 after T2, T3, T4 (requires all three files in their final shape).
- **Dependencies**: T2, T3, T4
- **Parallel-safe-with**: T5..T16, T18..T22
- **Notes**: This test gates the portability invariant; static test, no sandbox.
- [ ]

---

## T18 — `test/t64_precommit_shim_wiring.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R5 (AC5.d — bypass is explicit, not accidental; shim is installed by default)
- **Decisions**: D3 (shim install via `specflow-seed init/migrate`)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t64_precommit_shim_wiring.sh` (exec bit set)
- **Briefing**:

  Integration test. Sandbox a fresh consumer repo; run `bin/specflow-seed init --from /Users/yanghungtw/Tools/spec-workflow --ref HEAD` (or equivalent per the existing t39 pattern).

  Assertions:
  1. `<consumer>/.git/hooks/pre-commit` exists AND is executable.
  2. Its content contains the `specflow-lint` sentinel string (`grep -F 'specflow-lint' .git/hooks/pre-commit` returns ≥ 1 line).
  3. Stage a fixture with zh-TW content and attempt `git commit`; the commit is rejected (exit non-zero) — the shim fires the lint and the lint fires the `cjk-hit` rejection path.
  4. Clean re-run of `specflow-seed init` is idempotent: second run reports `already:.git/hooks/pre-commit`.
  5. (Optional) Pre-create a foreign `.git/hooks/pre-commit` without the sentinel BEFORE running `specflow-seed init`; assert the installer reports `skipped:foreign-pre-commit:.git/hooks/pre-commit` and exits non-zero without clobbering the foreign file.

  Sandbox preflight from T8 verbatim, extended with `git init` + `git config`.
- **Acceptance**:
  - `bash -n test/t64_precommit_shim_wiring.sh` returns 0; `test -x` returns 0.
  - `bash test/t64_precommit_shim_wiring.sh` exits 0 after T3 + T4.
- **Dependencies**: T3, T4
- **Parallel-safe-with**: T5..T17, T19..T22
- **Notes**: Structural PASS in sandbox; runtime rejection on the user's real commit deferred to next feature per R9.
- [ ]

---

## T19 — `test/t65_subagent_diff_empty.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R4 (AC4.a — zero agent diff)
- **Decisions**: — (invariant check; no decision)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t65_subagent_diff_empty.sh` (exec bit set)
- **Briefing**:

  Static test. Assert that the feature's final commit (or the union of all commits on the feature branch vs. the parent commit) shows zero lines changed under `.claude/agents/specflow/`.

  Portable implementation sketch:
  ```bash
  # Determine the base — prefer the feature branch's merge-base against main; fall back to HEAD~N if we know the commit count.
  BASE=$(git merge-base HEAD main 2>/dev/null || git rev-parse HEAD~1)
  LINES=$(git diff --numstat "$BASE"...HEAD -- .claude/agents/specflow/ | awk '{s+=$1+$2} END {print s+0}')
  [ "$LINES" = "0" ] || { echo "FAIL: .claude/agents/specflow changed by $LINES lines" >&2; exit 1; }
  ```

  Note: this test is brittle to how the feature branch is shaped at the moment it runs. If it runs mid-implement, pre-merge, `BASE=main` works. The test is primarily a gap-check / verify backstop — the developer runs it at feature close, not at every wave merge. Acceptance below allows for "green at verify stage" as the bar.
- **Acceptance**:
  - `bash -n test/t65_subagent_diff_empty.sh` returns 0; `test -x` returns 0.
  - `bash test/t65_subagent_diff_empty.sh` exits 0 at feature verify (by which time zero agent diff has been maintained throughout the feature).
- **Dependencies**: — (no implementation dep; test stands alone)
- **Parallel-safe-with**: T5..T18, T20..T22
- [ ]

---

## T20 — `test/t66_readme_doc_section.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R8 (AC8.a — single canonical doc section in README; AC8.b — grep-verifiable)
- **Decisions**: D1 (config location documented in README), D9 (YAML schema shape documented in README)
- **Files touched**:
  - **add**: `/Users/yanghungtw/Tools/spec-workflow/test/t66_readme_doc_section.sh` (exec bit set)
- **Briefing**:

  Static test. Assertions:
  1. `README.md` contains a section heading `"Language preferences"` (exact match, grep `-F`).
  2. That section mentions the config file path `.spec-workflow/config.yml`.
  3. That section mentions the config key `lang.chat`.
  4. That section mentions the example value `zh-TW`.
  5. That section contains a YAML block matching the D9 schema shape (grep for `lang:` on one line AND `chat: zh-TW` on the next, with appropriate indent).
  6. `grep -l 'lang\.chat\|lang:' <list-of-repo-root-.md-files> <rule-file>` returns exactly `README.md` AND `.claude/rules/common/language-preferences.md` — no third documentation file duplicates the opt-in instructions (AC8.b — one canonical doc surface).

  No sandbox needed. Pure `grep -F` / `grep -E` / `grep -n`.
- **Acceptance**:
  - `bash -n test/t66_readme_doc_section.sh` returns 0; `test -x` returns 0.
  - `bash test/t66_readme_doc_section.sh` exits 0 after T1 + T22.
- **Dependencies**: T1 (rule file), T22 (README edit)
- **Parallel-safe-with**: T5..T19, T21, T22 (different files; T20 creates the test file, T22 edits README — no same-file collision)
- [ ]

---

## T21 — Register t51–t66 in `test/smoke.sh`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: harness completeness (implicit across all tested ACs)
- **Decisions**: `tpm/parallel-safe-append-sections.md` (single-editor convention for `test/smoke.sh`)
- **Files touched**:
  - **modify**: `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` (append 16 test names to the existing `for t in ...` registration block; no other edits)
- **Briefing**:

  Single-editor task for `test/smoke.sh`. Append 16 new test names to the existing registration for-loop (currently ends at `t49_init_skill_bootstrap`). Tests DO NOT self-register — this is the convention from prior feature `20260418-per-project-install` T19 and `20260417-shareable-hooks` T8.

  Insert after the existing `t49_init_skill_bootstrap; do` line, extend the for-loop list to include:
  - `t51_rule_file_shape`
  - `t52_rule_index_row`
  - `t53_marker_rule_coupling`
  - `t54_hook_config_absent`
  - `t55_hook_config_zh_tw`
  - `t56_hook_config_unknown`
  - `t57_hook_config_malformed`
  - `t58_lint_clean_diff`
  - `t59_lint_cjk_hit`
  - `t60_lint_request_quote_allowlist`
  - `t61_lint_inline_marker_allowlist`
  - `t62_lint_archive_ignored`
  - `t63_lint_no_jq_no_readlink_f`
  - `t64_precommit_shim_wiring`
  - `t65_subagent_diff_empty`
  - `t66_readme_doc_section`

  Match the existing registration shape (backslash-continuation lines, indent style). Current test count 49; after this edit, 65 tests registered. (Plan §3 mentions "prior 50/50 plus 16 new = 66 total"; the prior feature deregistered t50 at the end of its W6 — actual prior count is 49. Confirmed by `ls test/t*.sh | wc -l = 49`. New total: 65.)

  **No t50 re-registration.** `t50_dogfood_staging_sentinel` was deregistered by the prior feature's T21 by design; do NOT re-add it.

- **Acceptance**:
  - `bash -n test/smoke.sh` returns 0.
  - `grep -c 't5[1-9]_\|t6[0-6]_' test/smoke.sh` ≥ 16 (all 16 new tests registered; use whichever grep pattern matches the registration form).
  - `bash test/smoke.sh` exits 0 after T1..T20, T22 have all landed (every referenced test file exists; every referenced AC is structurally met).
- **Dependencies**: T5..T20 (every test file must exist before registration; otherwise `bash test/smoke.sh` exits non-zero on a missing file)
- **Parallel-safe-with**: T5..T20, T22 (different files in the parallel set; this task edits `test/smoke.sh` alone — single-editor)
- **Notes**: **single-editor; append-only**. Per `tpm/parallel-safe-append-sections.md`, `test/smoke.sh` is a shared file but this is the only editor this feature — zero append-collision by design. The 16 test files land in parallel alongside this task; this task waits on all of them at the dependency gate.
- [ ]

---

## T22 — Add "Language preferences" section to `README.md`
- **Block**: B5
- **Wave**: W3
- **Owner role**: developer
- **Requirements**: R8 (AC8.a — single canonical doc; AC8.b — grep-verifiable)
- **Decisions**: D1 (config location documented), D9 (YAML schema documented)
- **Files touched**:
  - **modify**: `/Users/yanghungtw/Tools/spec-workflow/README.md` (append one new section "Language preferences"; placement: after the existing "Install" section, before "Recovery" if present; otherwise before the section that follows "Install")
- **Briefing**:

  **Single-editor task for `README.md`** — this feature has one README edit; zero append-collision by design.

  Section content requirements (grep-verifiable by t66 / T20):
  1. Heading: `## Language preferences` (exact text — `grep -F '## Language preferences' README.md` returns ≥ 1 line).
  2. One sentence naming the config file: `.spec-workflow/config.yml`.
  3. One sentence naming the config key: `lang.chat`.
  4. The example value `zh-TW`.
  5. A YAML code block with the **exact D9 schema** (verbatim):
     ```yaml
     # .spec-workflow/config.yml
     lang:
       chat: zh-TW    # or "en" (explicit default) — any other value → warning + default-off
     ```
  6. A pointer to the rule file: link or mention `.claude/rules/common/language-preferences.md`.
  7. A note on bypass discipline (per D8): `git commit --no-verify` is the emergency escape hatch; the inline `<!-- specflow-lint: allow-cjk reason="..." -->` marker is the surgical per-file exemption. Both are documented once in this section.
  8. A note that the file is user-authored and local-only by default (D1); users who want the setting shared across contributors can commit it deliberately.
  9. A note that the setting is opt-in; absence = default-off = today's English-only behaviour (AC1.a).

  No other README edits in this task. Do NOT touch the existing Install / verb-vocabulary / deprecation sections (those are owned by the prior feature).
- **Acceptance**:
  - `grep -F '## Language preferences' /Users/yanghungtw/Tools/spec-workflow/README.md` returns ≥ 1 line.
  - `grep -F 'lang.chat' /Users/yanghungtw/Tools/spec-workflow/README.md` returns ≥ 1 line.
  - `grep -F 'zh-TW' /Users/yanghungtw/Tools/spec-workflow/README.md` returns ≥ 1 line.
  - `grep -F '.spec-workflow/config.yml' /Users/yanghungtw/Tools/spec-workflow/README.md` returns ≥ 1 line.
  - `grep -F 'specflow-lint: allow-cjk' /Users/yanghungtw/Tools/spec-workflow/README.md` returns ≥ 1 line.
  - Spot-check: `bash test/t66_readme_doc_section.sh` passes after this task + T1 land.
- **Dependencies**: — (independent of T1..T21 at the edit level; t66 in T20 greps both this file and the rule file together, so verification of the overall doc-section AC waits until T1 + T22 both land)
- **Parallel-safe-with**: T5..T21 (different files)
- **Notes**: **single-editor; append-only new section**. Per `tpm/parallel-safe-append-sections.md`, zero append-collision by design (this task is the sole README editor this feature).
- [ ]

---

## R ↔ T trace (bidirectional)

Every PRD requirement maps to at least one task; every task maps to at least one requirement.

| R / AC | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 | T12 | T13 | T14 | T15 | T16 | T17 | T18 | T19 | T20 | T21 | T22 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| R1 AC1.a (baseline English) | | X | | | | | | X | | | | | | | | | | | | | | |
| R1 AC1.b (opt-in emits marker) | | X | | | | | X | | X | | | | | | | | | | | | | |
| R1 AC1.c (opt-out = removal) | | X | | | | | | X | | | | | | | | | | | | | | |
| R2 AC2.a (rule English-only) | X | | | | X | | | | | | | | | | | | | | | | | |
| R2 AC2.b (conditional documented) | X | | | | X | | | | | | | | | | | | | | | | | |
| R2 AC2.c (index row) | X | | | | | X | | | | | | | | | | | | | | | | |
| R2 AC2.d (loads unconditionally) | X | | | | X | | X | | | | | | | | | | | | | | | |
| R3 AC3.a (six carve-outs) | X | | | | X | | | | | | | | | | | | | | | | | |
| R3 AC3.b (no reverse) | X | | | | X | | | | | | | | | | | | | | | | | |
| R4 AC4.a (no agent diff) | | | | | | | | | | | | | | | | | | | X | | | |
| R4 AC4.b (seven roles named) | X | | | | X | | | | | | | | | | | | | | | | | |
| R5 AC5.a (rejection path) | | | X | | | | | | | | | | X | | | | | X | | | | |
| R5 AC5.b (clean-diff passes) | | | X | | | | | | | | | X | | | | | | | | | | |
| R5 AC5.c (allowlist scope) | | | X | | | | | | | | | | | X | X | X | | | | | | |
| R5 AC5.d (bypass explicit) | | | | X | | | | | | | | | | | | | | X | | | | X |
| R6 AC6.a (positive scope) | X | | | | X | | | | | | | | | | | | | | | | | |
| R6 AC6.b (negative scope) | X | | | | X | | | | | | | | | | | | | | | | | |
| R7 AC7.a (unknown value) | | X | | | | | | | | X | | | | | | | | | | | | |
| R7 AC7.b (malformed config) | | X | | | | | | | | | X | | | | | | | | | | | |
| R7 AC7.c (missing file silent) | | X | | | | | | X | | | | | | | | | | | | | | |
| R8 AC8.a (README section) | | | | | | | | | | | | | | | | | | | | X | | X |
| R8 AC8.b (grep-verifiable) | | | | | | | | | | | | | | | | | | | | X | | X |
| R9 AC9.a (structural markers) | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| R9 AC9.b (next-feature) | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| bash-32-portability (all new bash) | | X | X | X | | | | | | | | | | | | | X | | | | | |

R9 rows are dashes because R9 is enforced at the verify / post-archive stage (not implementable as a task) — per `shared/dogfood-paradox-third-occurrence.md`, QA-tester annotates `08-verify.md` with the structural-vs-runtime split; `/specflow:archive` handoff carries AC9.b forward. Bi-directional coverage: every column T1–T22 has at least one row with X; every row R1–R8 has at least one X. R9 is intentionally meta-AC and does not map to a task.

---

## STATUS Notes

_(populated by Developer as tasks complete; expected mechanical append-collisions on this section are resolved keep-both per `tpm/parallel-safe-append-sections.md`)_

---

## Wave schedule

- **Wave 1** (3 parallel): T1, T2, T3
- **Wave 2** (size 1, serial): T4
- **Wave 3** (18 parallel): T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22

**Total**: 22 tasks across 3 wave slots. Widest wave: W3 (18-way). Critical path length: 3 wave gates (W1 → W2 → W3).

### Parallel-safety analysis per wave

**Wave 1 (3 parallel)** — Files:
  - T1: `.claude/rules/common/language-preferences.md` (create) + `.claude/rules/index.md` (one append-only row — T1 is the sole editor).
  - T2: `.claude/hooks/session-start.sh` (extend — single block between digest assembly and JSON-emit).
  - T3: `bin/specflow-lint` (create).

  All three tasks write to DISJOINT files. No dispatcher-arm collision. No shared-function edits. Per `tpm/parallel-safe-requires-different-files.md`, fully parallel-safe. No append-only collision risk within this wave either.

**Wave 2 (size 1, serial)** — T4 edits `bin/specflow-seed`. Single task by design: all three intra-function edits (classifier state, dispatcher arm, summary emit) touch the same file and serialize inside this task. No peer task in W2. Waves ≠ tasks; this wave has one task. Per `tpm/parallel-safe-requires-different-files.md`, same-file intra-function additions cannot be parallelised.

  **W2 gates on W1 B3 (T3)**: the shim content the installer writes references `bin/specflow-lint` by path. At code-edit time the dependency is schema-only (the string `bin/specflow-lint scan-staged` is fixed). At runtime-test time (t64 in W3), `bin/specflow-lint` must exist in the source tree — which it does after W1.

**Wave 3 (18 parallel)** — Files:
  - T5..T20: 16 new test files (`test/t51_*.sh` through `test/t66_*.sh`), each a distinct new file.
  - T21: `test/smoke.sh` (edit — single editor; registers all 16 new tests).
  - T22: `README.md` (edit — single editor; new "Language preferences" section).

  All 18 tasks write to DISJOINT files. T5..T20 each create a brand-new test file (zero collision with existing `test/t*.sh` — t51..t66 are new slots not previously used). T21 is the sole editor of `test/smoke.sh` this feature; T22 is the sole editor of `README.md` this feature. No dispatcher-arm edits; no same-file edits between tasks in this wave.

  Per `tpm/parallel-safe-requires-different-files.md`, the wave is fully parallel-safe at the file level.

  **Expected append-only collisions** (per `tpm/parallel-safe-append-sections.md`): tasks write their own STATUS Notes lines — adjacent appends; resolve keep-both mechanically. **Expected checkbox flips**: 18 checkboxes flipped `[ ]` → `[x]` in `06-tasks.md`. Per `tpm/checkbox-lost-in-parallel-merge.md`, at 18-way wave width the precedent loss rate is 2–3 checkboxes (extrapolating from 7-way → 1–2, 9-way → 2). Orchestrator runs `grep -c '^- \[x\]' 06-tasks.md` after the wave merges and flips any silently-dropped boxes in a post-merge fix-up commit. **No surprise — this is the standard hygiene for wide waves in this repo.**

  Test isolation: all integration tests (t54, t55, t56, t57, t58, t59, t60, t61, t62, t64) use `mktemp -d` sandbox with `$HOME` preflight per `.claude/rules/bash/sandbox-home-in-tests.md`. No `/tmp` collision, no shared port, no shared fixture. Static tests (t51, t52, t53, t63, t65, t66) do not need a sandbox but do not mutate any state either.

### Wave-level collision risks (summary)

| Wave | Widest collision risk | Mitigation |
|---|---|---|
| W1 | none | 3 distinct files; no dispatcher-arm collision |
| W2 | same-file (3 edits on `bin/specflow-seed`) | serialized inside single task T4 |
| W3 | STATUS.md notes + `06-tasks.md` checkbox flips (18-way) | append-only keep-both per `tpm/parallel-safe-append-sections.md`; post-merge checkbox audit per `tpm/checkbox-lost-in-parallel-merge.md` |

### Expected append-only conflicts

- `STATUS.md` Notes — every task appends; mechanical keep-both per `tpm/parallel-safe-append-sections.md`.
- `06-tasks.md` checkbox flips — predictable loss rate 2–3 boxes per 18-way W3 merge; post-merge `grep -c '^- \[x\]' 06-tasks.md` audit per `tpm/checkbox-lost-in-parallel-merge.md`.
- `test/smoke.sh` — single-editor task (T21); zero collision.
- `README.md` — single-editor task (T22); zero collision.
- `.claude/rules/index.md` — single-editor task (T1 creates the rule and adds the index row in one pass); zero collision.
- `bin/specflow-seed` — serialized as single task T4 in W2; zero within-wave collision.

### Dogfood staging (recap)

- **W1–W3** run entirely against structural tests + sandbox integration fixtures. This feature's own subagents continue to reply in English regardless of any `lang.chat` setting on the developer machine — the hook has not yet been modified during the development session, and even once modified, the active session picked up the pre-modification hook output.
- **Runtime verification of AC1.b, AC5.a, AC5.b, AC7.a, AC7.b, AC7.c** is deferred to the first session opened after archive + session restart, per `shared/dogfood-paradox-third-occurrence.md` (7th occurrence — now includes the **cache refresh lag** clause from the 4th occurrence).
- **QA-tester duty at `08-verify.md`**: annotate each structural-only AC with "structural PASS; runtime deferred to next feature after session restart." This is a documentation discipline — not a task. Reference R9 AC9.a in the verify doc.
- **Next-feature handoff (R9 AC9.b)**: the first feature archived after this one MUST include an early STATUS Notes line confirming first-session runtime behaviour of language-preferences (either "ran with knob unset, chat English as expected" or "ran with knob set to zh-TW, chat observed in zh-TW as expected"). Not verifiable in this feature; handoff AC only.

## Team memory

- `tpm/parallel-safe-requires-different-files.md` — load-bearing for W1 (3 distinct files → 3-parallel) and W2 (same-file intra-function edits → 1 task).
- `tpm/parallel-safe-append-sections.md` — applied to W3 expected STATUS.md / 06-tasks.md checkbox-flip collisions; accept mechanical keep-both without over-serializing the 18-way wave. Also governs `test/smoke.sh` and `README.md` single-editor flags on T21 and T22.
- `tpm/checkbox-lost-in-parallel-merge.md` — W3 is 18-way; expect 2–3 checkbox losses; post-wave audit `grep -c '^- \[x\]' 06-tasks.md` is the standard recovery.
- `tpm/briefing-contradicts-schema.md` — every task's briefing pastes the governing schema verbatim (frontmatter schema in T1; D7 `awk` block in T2; D6 classifier enum + Unicode ranges + allowlist patterns in T3, T14, T15; D9 YAML schema in T1, T2, T22; sandbox preflight in T8 and referenced from T9–T18).
- `shared/dogfood-paradox-third-occurrence.md` — 7th occurrence; W3 structural-only orientation; QA-tester `08-verify.md` annotation duty called out in Dogfood staging recap.
