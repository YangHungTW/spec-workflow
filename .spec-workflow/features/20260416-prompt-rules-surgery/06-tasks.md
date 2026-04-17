# Tasks — prompt-rules-surgery (B1)

_2026-04-16 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R16), `04-tech.md` (D1–D12),
`05-plan.md` (M1–M11). Every task names the milestone, requirements, and
decisions it lands. `Verify` is a concrete command or filesystem check the
Developer runs at the end of the task; if it passes, the task is done.

All paths below are absolute under
`/Users/yanghungtw/Tools/spec-workflow/`. When this plan says "the hook",
it means `.claude/hooks/session-start.sh` per D1/D2. When it says "the
installer", it means the Python 3 `add_hook` helper from D12.

---

## T1 — Rules layer scaffolding + README + exemplar rule
- **Milestone**: M1
- **Requirements**: R1, R2, R6, R14
- **Decisions**: D3, D4
- **Scope**: Create the new rules tree:
  - `.claude/rules/common/` (directory)
  - `.claude/rules/bash/` (directory)
  - `.claude/rules/markdown/` (directory)
  - `.claude/rules/git/` (directory)
  - `.claude/rules/README.md` — short contributor guide that MUST include the D4 rules-vs-team-memory contrast table verbatim plus the D3 frontmatter schema.
  - `.claude/rules/common/classify-before-mutate.md` — the exemplar rule (M1 per plan §2), extracted from `architect/classification-before-mutation.md`. Full D3 frontmatter (5 keys: `name`, `scope`, `severity`, `created`, `updated`). Body sections in order: `## Rule`, `## Why`, `## How to apply`, `## Example` (optional but include one — classifier short sample).
  - `.claude/rules/.gitkeep`-style placeholder NOT needed in any empty subdir; T2–T5 will populate each non-empty dir. `git/` stays empty in v1 (no R3 slug targets it); add a 1-line `.gitkeep` there so the directory is tracked.
- **Deliverables**: 4 new directories; `.claude/rules/README.md`; `.claude/rules/common/classify-before-mutate.md`; `.claude/rules/git/.gitkeep`.
- **Verify**:
  - `test -d .claude/rules/common && test -d .claude/rules/bash && test -d .claude/rules/markdown && test -d .claude/rules/git` exits 0.
  - `head -1 .claude/rules/common/classify-before-mutate.md` prints `---`.
  - `grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' .claude/rules/common/classify-before-mutate.md` prints `5`.
  - `grep -E '^## (Rule|Why|How to apply)' .claude/rules/common/classify-before-mutate.md | wc -l` prints `3` or `4` (Example optional).
  - `grep -q 'hard' .claude/rules/README.md && grep -q 'soft' .claude/rules/README.md` — the contrast table loaded.
- **Depends on**: —
- **Parallel-safe-with**: —
- [x]

## T2 — Rule: bash-32-portability
- **Milestone**: M2
- **Requirements**: R3, R14
- **Decisions**: D3
- **Scope**: Create `.claude/rules/bash/bash-32-portability.md`. Frontmatter: `scope: bash`, `severity: must`. Source: migrate content from `.claude/team-memory/architect/shell-portability-readlink.md` (keep the memory entry intact — rules are additive, not a move). Body must cover: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic, BSD userland assumptions. Include one working example snippet (resolve-path loop with bare `readlink`).
- **Deliverables**: one new file `.claude/rules/bash/bash-32-portability.md`.
- **Verify**:
  - `test -f .claude/rules/bash/bash-32-portability.md`.
  - `grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' .claude/rules/bash/bash-32-portability.md` prints `5`.
  - `grep -E '^## (Rule|Why|How to apply|Example)' .claude/rules/bash/bash-32-portability.md | wc -l` prints `4`.
  - `grep -q 'scope: bash' .claude/rules/bash/bash-32-portability.md`.
  - `grep -q 'severity: must' .claude/rules/bash/bash-32-portability.md`.
  - Source memory file still exists: `test -f .claude/team-memory/architect/shell-portability-readlink.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T3, T4, T5
- [x]

## T3 — Rule: sandbox-home-in-tests
- **Milestone**: M2
- **Requirements**: R3, R14
- **Decisions**: D3
- **Scope**: Create `.claude/rules/bash/sandbox-home-in-tests.md`. Frontmatter: `scope: bash`, `severity: must`. Source: migrate content from `.claude/team-memory/qa-tester/sandbox-home-preflight-pattern.md` (keep memory entry intact). Body must cover: tests must `mktemp -d` a sandbox, `export HOME="$SANDBOX/home"`, verify `$HOME` starts with sandbox path before any mutation, refuse to run against real `$HOME`. Include one working preflight snippet.
- **Deliverables**: one new file `.claude/rules/bash/sandbox-home-in-tests.md`.
- **Verify**:
  - `test -f .claude/rules/bash/sandbox-home-in-tests.md`.
  - `grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' .claude/rules/bash/sandbox-home-in-tests.md` prints `5`.
  - `grep -E '^## (Rule|Why|How to apply|Example)' .claude/rules/bash/sandbox-home-in-tests.md | wc -l` prints `4`.
  - `grep -q 'scope: bash' .claude/rules/bash/sandbox-home-in-tests.md`.
  - `grep -q 'mktemp' .claude/rules/bash/sandbox-home-in-tests.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T2, T4, T5
- [x]

## T4 — Rule: no-force-on-user-paths
- **Milestone**: M2
- **Requirements**: R3, R14
- **Decisions**: D3
- **Scope**: Create `.claude/rules/common/no-force-on-user-paths.md`. Frontmatter: `scope: common`, `severity: must`. Source: migrate content from `.claude/team-memory/architect/no-force-by-default.md` (keep memory entry intact). Body: never `--force`, never silent clobber, classify-before-mutate pairing, always back up before overwriting user-owned files (config, dotfiles, state). Include one example — e.g. the D12 settings.json read-merge-write discipline (cross-reference both rules).
- **Deliverables**: one new file `.claude/rules/common/no-force-on-user-paths.md`.
- **Verify**:
  - `test -f .claude/rules/common/no-force-on-user-paths.md`.
  - `grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' .claude/rules/common/no-force-on-user-paths.md` prints `5`.
  - `grep -E '^## (Rule|Why|How to apply|Example)' .claude/rules/common/no-force-on-user-paths.md | wc -l` prints `4`.
  - `grep -q 'scope: common' .claude/rules/common/no-force-on-user-paths.md`.
  - `grep -q 'severity: must' .claude/rules/common/no-force-on-user-paths.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T2, T3, T5
- [x]

## T5 — Rule: absolute-symlink-targets
- **Milestone**: M2
- **Requirements**: R3, R14
- **Decisions**: D3
- **Scope**: Create `.claude/rules/common/absolute-symlink-targets.md`. Frontmatter: `scope: common`, `severity: should`. Source: the symlink-operation PRD R3 wording (archived under `.spec-workflow/archive/symlink-operation/03-prd.md`). No current team-memory entry to mirror. Body: when creating symlinks, targets MUST be absolute; relative targets break when the link is moved; `ln -s "$abs_src" "$tgt"` template. Include one example referencing the `bin/claude-symlink` convention.
- **Deliverables**: one new file `.claude/rules/common/absolute-symlink-targets.md`.
- **Verify**:
  - `test -f .claude/rules/common/absolute-symlink-targets.md`.
  - `grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' .claude/rules/common/absolute-symlink-targets.md` prints `5`.
  - `grep -E '^## (Rule|Why|How to apply|Example)' .claude/rules/common/absolute-symlink-targets.md | wc -l` prints `4`.
  - `grep -q 'scope: common' .claude/rules/common/absolute-symlink-targets.md`.
  - `grep -q 'severity: should' .claude/rules/common/absolute-symlink-targets.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T2, T3, T4
- [x]

## T6 — SessionStart hook script (pure bash, fail-safe)
- **Milestone**: M3
- **Requirements**: R4, R5 (all 4 items), R6
- **Decisions**: D1, D5, D7, D8; §4 error-handling strategy
- **Scope**: Create `.claude/hooks/session-start.sh` as a new executable file. Pure bash 3.2, BSD userland only. Structure:
  1. Shebang `#!/usr/bin/env bash`. `set +e` (NOT `-e`). `trap 'exit 0' ERR INT TERM` early.
  2. Helper `log_warn <msg>` emits `session-start.sh: WARN: <msg>` to stderr.
  3. Helper `log_info <msg>` emits `session-start.sh: INFO: <msg>` to stderr.
  4. Classifier `classify_frontmatter <file>` — per D5, `awk '/^---$/{c++; next} c==1{print}'` isolates the frontmatter block; per-key awk sniffs for `name`, `scope`, `severity`, `created`, `updated`. Returns enum string `valid | no-frontmatter | missing-name | missing-scope | missing-severity | missing-created | missing-updated | empty`. Pure function, no side effects.
  5. Helper `digest_rule <file>` — extracts `name`, `severity`, and the first non-empty line under `## Rule`; emits `• [<severity>] <name> — <rule-line>` to stdout of the digest buffer.
  6. Helper `lang_heuristic` — per D8, collects `git diff --name-only HEAD~10..HEAD 2>/dev/null` + `git status --short 2>/dev/null`; if both empty, falls back to `find . -type f -mtime -1 -maxdepth 3 2>/dev/null`. Maps extensions to subdir names: `.sh`/`.bash` → `bash`; `.md` → `markdown`; `.gitignore`/`.gitattributes` or files under `.git/` → `git`. Echoes the matched subdir names on stdout, one per line, deduplicated.
  7. Main: walk `.claude/rules/common/*.md` (always), then each subdir from `lang_heuristic` if it exists. For each file, run classifier; if valid, append `digest_rule` output to digest buffer; if not valid, log WARN and skip.
  8. JSON emission per D7 with **both** keys (fallback pattern): `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}` AND top-level `context` echoing the same digest. JSON-escape the digest string (backslash-escape `"`, `\`, `\n` for newlines).
  9. Final `exit 0` unconditional.
- **Deliverables**: new file `.claude/hooks/session-start.sh` with exec bit set (`chmod +x`). No other files touched.
- **Verify**:
  - `bash -n .claude/hooks/session-start.sh` exits 0 (syntax clean).
  - `test -x .claude/hooks/session-start.sh` succeeds.
  - `.claude/hooks/session-start.sh < /dev/null` exits 0.
  - stdout is a single JSON object (grep `hookSpecificOutput` succeeds; `python3 -c "import sys,json; json.load(sys.stdin)" < <(./.claude/hooks/session-start.sh)` parses clean).
  - `additionalContext` contains `classify-before-mutate` (the M1 exemplar rule).
  - Simulated failure: `mv .claude/rules .claude/rules.tmp; .claude/hooks/session-start.sh < /dev/null; echo $?; mv .claude/rules.tmp .claude/rules` — prints exit code `0` and emits a WARN line to stderr.
- **Depends on**: T1
- **Parallel-safe-with**: T7
- [x]

## T7 — Safe settings.json installer helper (D12)
- **Milestone**: M4
- **Requirements**: R4
- **Decisions**: D12
- **Scope**: Create `bin/specflow-install-hook` as an executable shell script that embeds the D12 Python 3 read-merge-write one-liner. Script behavior:
  1. Shebang `#!/usr/bin/env bash`. `set -u -o pipefail` (NOT `-e` — we need to probe python3 cleanly).
  2. Preflight: `command -v python3 >/dev/null 2>&1 || { echo "python3 required; hand-edit settings.json per 04-tech.md D2" >&2; exit 2; }`.
  3. Subcommand dispatch: `add <event> <command>` and `remove <event> <command>`. Arg count check; exit 2 with usage on mismatch.
  4. `add`: invoke the D12 Python 3 heredoc — load existing `settings.json` (or `{}` if missing), back up to `settings.json.bak`, idempotent append (`any(h.get("command") == cmd for h in grp.get("hooks", []))` check), write to `settings.json.tmp`, `os.replace` to `settings.json`.
  5. `remove`: mirror of `add` — find the matching command entry in the event array, drop it; if an `{"hooks": [...]}` group empties, drop the group; same backup + atomic swap.
  6. Both operations MUST preserve all unrelated top-level keys (`permissions`, `env`, other `hooks.<Event>` arrays, anything the user added).
- **Deliverables**: new file `bin/specflow-install-hook` with exec bit set. No touches to `settings.json` yet (that is T9). No touches to any other file.
- **Verify** (sandbox-HOME discipline — always run under `mktemp -d`):
  - `bash -n bin/specflow-install-hook` exits 0.
  - `test -x bin/specflow-install-hook` succeeds.
  - `bin/specflow-install-hook` (no args) exits 2 with usage.
  - Sandbox test: `SB=$(mktemp -d); cd $SB; bin/.../specflow-install-hook add SessionStart .claude/hooks/session-start.sh; test -f settings.json; python3 -c "import json; d=json.load(open('settings.json')); assert any(h['command']=='.claude/hooks/session-start.sh' for g in d['hooks']['SessionStart'] for h in g['hooks'])"`.
  - Idempotence: run `add` twice; the resulting `settings.json` has exactly one matching entry (`python3 -c "import json; d=json.load(open('settings.json')); n=sum(1 for g in d['hooks']['SessionStart'] for h in g['hooks'] if h['command']=='.claude/hooks/session-start.sh'); assert n==1, n"`).
  - Preservation: seed `settings.json` with `{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}`, run `add`, assert `permissions.allow` and `env.FOO` survive.
  - `settings.json.bak` exists after any `add`/`remove` that mutates.
- **Depends on**: T1 (actually independent of T1 but we want scaffolding committed first so paths are unambiguous)
- **Parallel-safe-with**: T6
- [x]

## T8 — Early-verify SessionStart hook against real Claude Code session [USER CHECKPOINT]
- **Milestone**: M3 (verification gate)
- **Requirements**: R4, R5, AC-rules-visible
- **Decisions**: D2, D7 (validates the JSON key uncertainty called out in tech-doc §3 and §5)
- **Scope**: Manual integration test — NOT automated. Per user decision from planning review (option A: early-verify the hook spec before downstream milestones depend on it), the Developer MUST:
  1. Manually wire the hook into their local `settings.json` using the T7 helper (`bin/specflow-install-hook add SessionStart .claude/hooks/session-start.sh`). This is a **temporary** wiring — T9 does the canonical repo-level install. It is acceptable to run T7 against the actual repo `settings.json` here because the installer is idempotent (T9 will be a no-op).
  2. Open a fresh Claude Code session in this repo (new terminal, fresh invocation).
  3. Invoke any specflow command (e.g. `/specflow:status` if available, or just ask Claude "what rules are loaded?"). Confirm the session context contains the digest from `classify-before-mutate` — the exemplar rule's `[must] classify-before-mutate — …` line should be visible.
  4. If the digest is NOT visible: STOP. Do not proceed to T9 or any downstream task. Capture the observed behavior (stdout of the hook when run standalone, contents of `settings.json`, any Claude Code diagnostic output) in a STATUS Notes line and escalate to TPM so we can amend D7 / D2 based on whichever JSON key Claude Code actually reads. Possible fixes: swap `hookSpecificOutput.additionalContext` for `context`, adjust `type: "command"` wrapper, etc. — the hook script is one-line-changeable per tech-doc §3.
  5. If the digest IS visible: record a STATUS Notes line `2026-04-16 Developer — T8 done: SessionStart hook fires; digest injection confirmed for <rule-name>` and proceed.
- **Deliverables**: NONE on-disk (this is a verification task). Evidence lives in STATUS Notes.
- **Verify**:
  - STATUS Notes contains a `T8 done: SessionStart hook fires` line, OR
  - STATUS Notes contains a `T8 blocked: <observed-behavior>` line and the feature is parked until TPM amends the tech doc and reissues T6.
- **Depends on**: T6, T7
- **Parallel-safe-with**: —
- [x]

## T9 — Wire SessionStart hook into repo-root settings.json
- **Milestone**: M5
- **Requirements**: R4
- **Decisions**: D2, D12
- **Scope**: Run the T7 helper exactly once against the repo-root `settings.json`:
  `bin/specflow-install-hook add SessionStart .claude/hooks/session-start.sh`
  This creates (or augments) `settings.json` at repo root with the SessionStart entry. NO heredoc, NO `cat >`, NO manual JSON authoring. The mutation MUST go through T7. `settings.json.bak` will be created (empty-backup case, since `settings.json` does not exist pre-feature; T7's logic handles the missing-source case).
- **Deliverables**: new file `settings.json` at repo root; `settings.json.bak` (possibly zero-byte on first install — acceptable). No touches to any other file.
- **Verify**:
  - `test -f settings.json`.
  - `grep -q 'session-start.sh' settings.json`.
  - `grep -q 'SessionStart' settings.json`.
  - `python3 -c "import json; d=json.load(open('settings.json')); assert any(h['command']=='.claude/hooks/session-start.sh' for g in d['hooks']['SessionStart'] for h in g['hooks'])"` exits 0.
  - Running the install step again is a no-op (idempotent): byte-identical `settings.json` except possibly updated `settings.json.bak`.
- **Depends on**: T7, T8
- **Parallel-safe-with**: —
- [x]

## T10 — Agent surgery: pm.md (slim + memory block)
- **Milestone**: M6+M7 (fused per plan §5)
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Rewrite `.claude/agents/specflow/pm.md` to the D10 fixed six-block template:
  1. YAML frontmatter (preserve existing `name`, `model`, `description`, `tools`).
  2. Identity line (`You are the PM …`).
  3. `## Team memory` block with the D10 wording verbatim — must contain the tokens `ls ~/.claude/team-memory/pm/` AND `none apply because` AND `dir not present:` so AC-memory-required's grep passes.
  4. `## When invoked for /specflow:<cmd>` sections (one per slash command PM handles; keep existing behavior text only — no new behavior).
  5. `## Output contract` — one short paragraph: files written, STATUS note format, required Team memory block in return.
  6. `## Rules` — role-specific only. Any cross-role rule (classify-before-mutate, no-force-on-user-paths, sandbox-home-in-tests, bash-32-portability, absolute-symlink-targets) MUST be removed. If long-form content needs to stay somewhere, lift it into `.claude/agents/specflow/pm.appendix.md` and reference with D9 literal phrase `When you need X, consult pm.appendix.md section "Y".`.
  Non-empty line count ceiling: **≤22 lines** (30% drop from baseline 32, per R9b).
- **Deliverables**: rewritten `.claude/agents/specflow/pm.md`; optionally new `.claude/agents/specflow/pm.appendix.md`. No other files touched.
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/pm.md` ≤ 22.
  - `grep -q '^## Team memory' .claude/agents/specflow/pm.md`.
  - `grep -q 'ls ~/.claude/team-memory/pm/' .claude/agents/specflow/pm.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/pm.md`.
  - `grep -q 'dir not present:' .claude/agents/specflow/pm.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/pm.md`.
  - `grep -q '^## Output contract' .claude/agents/specflow/pm.md`.
  - `grep -q '^## Rules' .claude/agents/specflow/pm.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME' .claude/agents/specflow/pm.md` returns zero matches.
  - If `pm.appendix.md` exists: every `section "X"` reference in `pm.md` core matches a `## X` or `### X` in the appendix.
- **Depends on**: T1, T2, T3, T4, T5 (all 5 rules must exist before cross-role content is removed from prompts — D11 diff-traceability)
- **Parallel-safe-with**: T11, T12, T13, T14, T15, T16
- [x]

## T11 — Agent surgery: designer.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/designer.md`. Non-empty line count ceiling: **≤22 lines** (30% drop from baseline 32). Designer's cross-role rules are mostly about output-contract hygiene and memory usage — lighter lift than backend roles.
- **Deliverables**: rewritten `.claude/agents/specflow/designer.md`; optionally `.claude/agents/specflow/designer.appendix.md`.
- **Verify**: same grep panel as T10 with `designer` substituted for `pm`:
  - `grep -cv '^$' .claude/agents/specflow/designer.md` ≤ 22.
  - `grep -q '^## Team memory' .claude/agents/specflow/designer.md`.
  - `grep -q 'ls ~/.claude/team-memory/designer/' .claude/agents/specflow/designer.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/designer.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/designer.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME' .claude/agents/specflow/designer.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T12, T13, T14, T15, T16
- [x]

## T12 — Agent surgery: architect.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/architect.md`. Non-empty line count ceiling: **≤37 lines** (30% drop from baseline 54). Architect has the most cross-role rules inlined (shell portability, no-force, classify-before-mutate); removal traceability is highest-leverage here. Every removed line MUST map to one of the 5 rule files from T2–T5 or land in the appendix.
- **Deliverables**: rewritten `.claude/agents/specflow/architect.md`; optionally `.claude/agents/specflow/architect.appendix.md`.
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/architect.md` ≤ 37.
  - `grep -q '^## Team memory' .claude/agents/specflow/architect.md`.
  - `grep -q 'ls ~/.claude/team-memory/architect/' .claude/agents/specflow/architect.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/architect.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/architect.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME|classification before|absolute symlink' .claude/agents/specflow/architect.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T11, T13, T14, T15, T16
- [x]

## T13 — Agent surgery: tpm.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/tpm.md`. Non-empty line count ceiling: **≤44 lines** (30% drop from baseline 64). TPM has the most prescriptive "when invoked" sections (plan, tasks, update-plan, update-task, archive) — keep each section, slim its body. Parallel-safe-with rule detail and retrospective protocol detail belong in the appendix, not the core.
- **Deliverables**: rewritten `.claude/agents/specflow/tpm.md`; likely `.claude/agents/specflow/tpm.appendix.md` (largest role — appendix almost certainly needed).
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/tpm.md` ≤ 44.
  - `grep -q '^## Team memory' .claude/agents/specflow/tpm.md`.
  - `grep -q 'ls ~/.claude/team-memory/tpm/' .claude/agents/specflow/tpm.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/tpm.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/tpm.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME' .claude/agents/specflow/tpm.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T11, T12, T14, T15, T16
- [x]

## T14 — Agent surgery: developer.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/developer.md`. Non-empty line count ceiling: **≤24 lines** (30% drop from baseline 35). Developer has bash-portability + sandbox-HOME language inlined today; both now live in rules and MUST be removed from the core (grep-audit will catch them in T17 or T19). TDD loop detail belongs in appendix.
- **Deliverables**: rewritten `.claude/agents/specflow/developer.md`; likely `.claude/agents/specflow/developer.appendix.md`.
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/developer.md` ≤ 24.
  - `grep -q '^## Team memory' .claude/agents/specflow/developer.md`.
  - `grep -q 'ls ~/.claude/team-memory/developer/' .claude/agents/specflow/developer.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/developer.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/developer.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME|mktemp -d' .claude/agents/specflow/developer.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T11, T12, T13, T15, T16
- [x]

## T15 — Agent surgery: qa-analyst.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/qa-analyst.md`. Non-empty line count ceiling: **≤21 lines** (30% drop from baseline 30). QA-analyst's gap-check rubric (D11 diff-traceability audit) is load-bearing for this very feature's M6+M7 — keep the rubric intact in the core or move to appendix with a clear pointer (NOT both).
- **Deliverables**: rewritten `.claude/agents/specflow/qa-analyst.md`; optionally `.claude/agents/specflow/qa-analyst.appendix.md`.
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/qa-analyst.md` ≤ 21.
  - `grep -q '^## Team memory' .claude/agents/specflow/qa-analyst.md`.
  - `grep -q 'ls ~/.claude/team-memory/qa-analyst/' .claude/agents/specflow/qa-analyst.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/qa-analyst.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/qa-analyst.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME' .claude/agents/specflow/qa-analyst.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T11, T12, T13, T14, T16
- [ ]

## T16 — Agent surgery: qa-tester.md (slim + memory block)
- **Milestone**: M6+M7
- **Requirements**: R7, R8, R9, R9b, R10, R11, R12, R14
- **Decisions**: D9, D10, D11
- **Scope**: Same shape as T10, applied to `.claude/agents/specflow/qa-tester.md`. Non-empty line count ceiling: **≤23 lines** (30% drop from baseline 33). QA-tester's sandbox-HOME preflight language now lives in the rule file (T3) — remove inline repetitions. Smoke-harness convention detail belongs in appendix.
- **Deliverables**: rewritten `.claude/agents/specflow/qa-tester.md`; optionally `.claude/agents/specflow/qa-tester.appendix.md`.
- **Verify**:
  - `grep -cv '^$' .claude/agents/specflow/qa-tester.md` ≤ 23.
  - `grep -q '^## Team memory' .claude/agents/specflow/qa-tester.md`.
  - `grep -q 'ls ~/.claude/team-memory/qa-tester/' .claude/agents/specflow/qa-tester.md`.
  - `grep -q 'none apply because' .claude/agents/specflow/qa-tester.md`.
  - `grep -q '^## When invoked' .claude/agents/specflow/qa-tester.md`.
  - Cross-role dedup: `grep -E 'readlink -f|--force|sandbox-HOME|mktemp -d' .claude/agents/specflow/qa-tester.md` returns zero matches.
- **Depends on**: T1, T2, T3, T4, T5
- **Parallel-safe-with**: T10, T11, T12, T13, T14, T15
- [x]

## T17 — Dedup audit across agent files
- **Milestone**: M8
- **Requirements**: R14
- **Decisions**: D4, D11
- **Scope**: Read-mostly audit task. Run the keyword greps from AC-no-duplication across all 7 agent files; any remaining hit is a fix-in-place (surgical removal from the agent file, with traceability back to its rule). No new files; only fixes to `.claude/agents/specflow/<role>.md` or `<role>.appendix.md` as needed.
  Audit keyword set (from AC-no-duplication + the 5 rule slugs):
  - `readlink -f` / `readlink --` / `realpath`
  - `--force` (outside of a rule-reference context)
  - `sandbox-HOME` / `mktemp -d.*HOME`
  - `classification before mutation` (prose), `classify-before-mutate` (slug)
  - `absolute symlink` / `absolute-symlink-targets`
  - `no-force-by-default` / `no-force-on-user-paths`
  Every hit gets deleted from the agent file (content now lives in the rule file) OR moved into the role's appendix if the agent really does need the detail at task-time (rare — flag for TPM review if claimed).
- **Deliverables**: zero or more small edits to `.claude/agents/specflow/*.md` / `*.appendix.md`. Audit evidence captured in STATUS Notes: `T17 done: <n> hits remediated` or `T17 done: 0 hits, clean`.
- **Verify**:
  - `grep -lE 'readlink -f|readlink --|realpath' .claude/agents/specflow/*.md` returns zero files.
  - `grep -lE '(^|[^-])--force' .claude/agents/specflow/*.md` returns zero files (or only files where it's explicitly a rule-name back-reference; inspect manually).
  - `grep -lE 'sandbox-HOME|mktemp -d.*HOME' .claude/agents/specflow/*.md` returns zero files.
  - `grep -lE 'classification before mutation|classify-before-mutate' .claude/agents/specflow/*.md` returns zero files (rule-name back-references allowed only under `## Rules` section pointing at the rule file — inspect manually).
- **Depends on**: T10, T11, T12, T13, T14, T15, T16
- **Parallel-safe-with**: —
- [x]

## T18 — test/t13_settings_json.sh + test/t14_rules_dir_structure.sh + test/t15_rules_schema.sh + test/t16_hook_exec_bit.sh
- **Milestone**: M9 (unit test batch 1)
- **Requirements**: R1, R2, R3, R4
- **Decisions**: D3, D6
- **Scope**: Four small unit test scripts (combined into one task for wave-width):
  - `test/t13_settings_json.sh` — assert `settings.json` at repo root exists, parses, references `.claude/hooks/session-start.sh`. Uses `python3` if available, `grep` fallback.
  - `test/t14_rules_dir_structure.sh` — assert each of the 4 rules subdirs exists AND each of the 5 R3 slug filenames is present under its scope subdir.
  - `test/t15_rules_schema.sh` — walk `.claude/rules/**/*.md`, for each assert 5 frontmatter keys + `## Rule` + `## Why` + `## How to apply` body sections.
  - `test/t16_hook_exec_bit.sh` — `test -x .claude/hooks/session-start.sh`.
  Each script: own file, own executable bit, own sandbox-HOME preflight (per rule `sandbox-home-in-tests` — even unit tests that don't touch HOME should carry the discipline as a template). Each prints `PASS` or `FAIL: <reason>` and exits 0/1 accordingly.
- **Deliverables**: 4 new files under `test/`.
- **Verify**:
  - `bash test/t13_settings_json.sh` exits 0.
  - `bash test/t14_rules_dir_structure.sh` exits 0.
  - `bash test/t15_rules_schema.sh` exits 0.
  - `bash test/t16_hook_exec_bit.sh` exits 0.
- **Depends on**: T1, T2, T3, T4, T5, T6, T9
- **Parallel-safe-with**: T19, T20, T21, T22
- [x]

## T19 — test/t17_hook_happy_path.sh + test/t18_hook_failsafe.sh + test/t19_hook_bad_frontmatter.sh + test/t20_hook_lang_lazy.sh
- **Milestone**: M9 (hook integration test batch)
- **Requirements**: R4, R5, R6
- **Decisions**: D5, D7, D8
- **Scope**: Four hook integration tests (combined for wave-width):
  - `test/t17_hook_happy_path.sh` — invoke hook with populated rules dir; assert stdout is valid JSON with non-empty `additionalContext`; exit 0.
  - `test/t18_hook_failsafe.sh` — `mv` rules dir temporarily, invoke hook, assert exit 0 + one stderr WARN line, restore dir.
  - `test/t19_hook_bad_frontmatter.sh` — stock a broken rule file in a sandbox rules copy, invoke hook against that copy (via env var or tempdir shim — Developer's call), assert valid files still digested, broken one skipped + WARN logged, exit 0.
  - `test/t20_hook_lang_lazy.sh` — run hook under two conditions: (a) `.sh` file in worktree diff → bash digest present; (b) no `.sh` → only common digest. Use `mktemp -d` sandbox with a minimal git repo to simulate.
  Each with sandbox-HOME preflight and `trap EXIT` cleanup.
- **Deliverables**: 4 new files under `test/`.
- **Verify**:
  - `bash test/t17_hook_happy_path.sh` exits 0.
  - `bash test/t18_hook_failsafe.sh` exits 0.
  - `bash test/t19_hook_bad_frontmatter.sh` exits 0.
  - `bash test/t20_hook_lang_lazy.sh` exits 0.
- **Depends on**: T6
- **Parallel-safe-with**: T18, T20, T21, T22
- [x]

## T20 — test/t21_agent_line_count.sh + test/t22_agent_header_grep.sh + test/t23_memory_required.sh
- **Milestone**: M9 (agent surgery test batch)
- **Requirements**: R7, R8, R9b, R10, R11
- **Decisions**: D10
- **Scope**: Three agent-core tests (combined for wave-width):
  - `test/t21_agent_line_count.sh` — for each of the 7 roles, assert `grep -cv '^$' <role>.md` ≤ R9b ceiling (pm 22, designer 22, developer 24, qa-analyst 21, qa-tester 23, architect 37, tpm 44). Table-driven.
  - `test/t22_agent_header_grep.sh` — for each of the 7 roles, assert the D10 six-block order: frontmatter (first `---...---`) → `You are the` → `## Team memory` → `## When invoked` → `## Output contract` → `## Rules`. Use `awk` to walk the file and check ordering.
  - `test/t23_memory_required.sh` — for each of the 7 roles, assert both `ls ~/.claude/team-memory/<role>/` AND `none apply because` AND `dir not present:` tokens present.
  Each with sandbox-HOME preflight.
- **Deliverables**: 3 new files under `test/`.
- **Verify**:
  - `bash test/t21_agent_line_count.sh` exits 0.
  - `bash test/t22_agent_header_grep.sh` exits 0.
  - `bash test/t23_memory_required.sh` exits 0.
- **Depends on**: T10, T11, T12, T13, T14, T15, T16
- **Parallel-safe-with**: T18, T19, T21, T22
- [x]

## T21 — test/t24_appendix_pointers.sh + test/t25_no_duplication.sh + test/t26_no_new_command.sh
- **Milestone**: M9 (cross-cutting test batch)
- **Requirements**: R9, R14, R15
- **Decisions**: D9
- **Scope**: Three cross-cutting tests (combined for wave-width):
  - `test/t24_appendix_pointers.sh` — for each `<role>.md` core that references `section "X"`, assert a matching `## X` or `### X` exists in `<role>.appendix.md`. Zero hits iff no appendix or no pointers. Uses D9 literal phrase pattern grep.
  - `test/t25_no_duplication.sh` — assert `grep -lE 'readlink -f|--force|sandbox-HOME' .claude/agents/specflow/*.md` returns zero files (the T17 audit formalized).
  - `test/t26_no_new_command.sh` — assert `ls .claude/commands/specflow/ | wc -l` equals the git-baseline count (hard-code the baseline count; capture it at first run from `git ls-tree HEAD .claude/commands/specflow/ | wc -l`).
  Each with sandbox-HOME preflight.
- **Deliverables**: 3 new files under `test/`.
- **Verify**:
  - `bash test/t24_appendix_pointers.sh` exits 0.
  - `bash test/t25_no_duplication.sh` exits 0.
  - `bash test/t26_no_new_command.sh` exits 0.
- **Depends on**: T10, T11, T12, T13, T14, T15, T16, T17
- **Parallel-safe-with**: T18, T19, T20, T22
- [x]

## T22 — test/t27_settings_json_preserves_keys.sh + test/t28_settings_json_idempotent.sh
- **Milestone**: M9 (D12 test batch)
- **Requirements**: R4
- **Decisions**: D12
- **Scope**: Two integration tests for the D12 safe-mutation invariants (combined for wave-width):
  - `test/t27_settings_json_preserves_keys.sh` — in a `mktemp -d` sandbox with HOME override: seed `settings.json` with `{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}`, run `bin/specflow-install-hook add SessionStart .claude/hooks/session-start.sh`, assert both `permissions.allow` and `env.FOO` survive AND the SessionStart entry is present. Parse via `python3`.
  - `test/t28_settings_json_idempotent.sh` — in a `mktemp -d` sandbox with HOME override: run `bin/specflow-install-hook add …` twice against a clean-then-post-install `settings.json`, assert exactly one entry (no duplicate group, no duplicate `command` field). Parse via `python3`.
  Both tests: preflight probes `command -v python3` — if missing, print `SKIP: python3 required` and exit 0 (watch-item from plan §6; CI-friendly).
  sandbox-HOME preflight + `trap EXIT` cleanup.
- **Deliverables**: 2 new files under `test/`.
- **Verify**:
  - `bash test/t27_settings_json_preserves_keys.sh` exits 0.
  - `bash test/t28_settings_json_idempotent.sh` exits 0.
- **Depends on**: T7
- **Parallel-safe-with**: T18, T19, T20, T21
- [x]

## T23 — Smoke test integration (register t13–t28 in test/smoke.sh)
- **Milestone**: M10
- **Requirements**: R16, AC-no-regression
- **Decisions**: D6
- **Scope**: Edit `test/smoke.sh` — the existing driver from the archived symlink-operation feature — to register the 16 new test scripts from T18–T22. DO NOT remove or renumber any of the existing 12 AC scenarios. The new tests run after the old ones (order doesn't matter, but keep the existing suite intact first for a clean regression signal). Tally line at the end must reflect the new total (28/28 when all pass, or whatever count lands).
- **Deliverables**: edits to `test/smoke.sh`. No new files.
- **Verify**:
  - `bash test/smoke.sh` exits 0 on a clean repo checkout (macOS).
  - Output includes `PASS` lines for each of t13…t28 plus the original 12 AC scenarios.
  - The final summary tallies 28/28 (or the actual count + zero failures).
  - Running `bash test/smoke.sh` with `HOME=/Users/yanghungtw` (real `$HOME`) still aborts with preflight exit 2 — the symlink-operation discipline is preserved.
- **Depends on**: T18, T19, T20, T21, T22
- **Parallel-safe-with**: —
- [ ]

## T24 — Docs: .claude/rules/README.md + .claude/team-memory/README.md cross-ref
- **Milestone**: M11
- **Requirements**: R1, R2, R14
- **Decisions**: D4
- **Scope**: Two doc touches:
  1. Ensure `.claude/rules/README.md` (created in T1) contains the D4 contrast table verbatim (if T1 skimped, flesh it out here). Sections: "Rules vs team-memory: layer contract", "Rule frontmatter schema", "Severity semantics", "Authoring checklist".
  2. Edit `.claude/team-memory/README.md` — append a short "Rules vs team-memory" pointer section: one paragraph + link to `.claude/rules/README.md`. Do NOT restate the contrast table here (single source of truth is the rules README).
  Zero touches to agent files.
- **Deliverables**: edits to `.claude/rules/README.md` + `.claude/team-memory/README.md`.
- **Verify**:
  - `grep -q 'soft' .claude/rules/README.md && grep -q 'hard' .claude/rules/README.md` — contrast still there.
  - `grep -q 'rules vs team-memory\|.claude/rules/' .claude/team-memory/README.md` — cross-ref landed.
  - Both files render as valid markdown (no broken tables, no unclosed code fences).
- **Depends on**: T23
- **Parallel-safe-with**: T25
- [ ]

## T25 — Docs: top-level README.md SessionStart hook note
- **Milestone**: M11
- **Requirements**: R1, R4
- **Decisions**: D4
- **Scope**: Append a short section to `/Users/yanghungtw/Tools/spec-workflow/README.md` noting that a SessionStart hook (`.claude/hooks/session-start.sh`) now injects `.claude/rules/` digests into every Claude Code session in this repo. One paragraph + a one-line code snippet showing the `settings.json` shape. Reference `.claude/rules/README.md` for details.
- **Deliverables**: edits to `README.md` (top-level only). No new files. No touches to `.claude/` trees.
- **Verify**:
  - `grep -q 'SessionStart' README.md` returns a match.
  - `grep -q '\.claude/hooks/session-start\.sh' README.md` returns a match.
  - `grep -q '\.claude/rules/' README.md` returns a match.
- **Depends on**: T23
- **Parallel-safe-with**: T24
- [ ]

---

## Sequencing notes

- **Strict spine**: T1 → {T2..T5, T6, T7} → T8 (checkpoint) → T9 → {T10..T16} → T17 → {T18..T22} → T23 → {T24, T25}.
- **T1 is the keystone** — rules dir scaffolding + exemplar rule. Blocks everything.
- **T2–T5 are fully parallel** — 4 different new rule files, different directories in some cases, same directory for T4/T5 but these are brand-new files with no shared lines. Still safe — same-directory but different-file additions do not produce textual merge conflicts (confirmed against `tpm/parallel-safe-requires-different-files.md`: the memory explicitly allows different-file same-dir edits).
- **T6 (hook) and T7 (installer)** are parallel — different files, different languages.
- **T8 is a USER CHECKPOINT** per user decision (option A early-verify). If the hook digest does NOT appear in a real Claude Code session, we STOP, amend the tech doc, and reissue T6. Do not let T9 proceed on faith.
- **T9 (wire settings.json)** depends on BOTH T7 (installer exists) AND T8 (hook spec validated). Before T8 passes, writing to `settings.json` is premature — we'd only have to undo it if D7's JSON shape turns out wrong.
- **T10–T16 (7 per-role agent surgeries)** — all parallel-safe with each other (different `<role>.md` files). All 7 depend on ALL 5 rule files (T1–T5) because D11 diff-traceability means we can't remove a line from a prompt until its rule-file home exists.
- **T17 (dedup audit)** serializes after T10–T16 — it audits the full set.
- **T18–T22 (test batches)** — 5 parallel test-writing tasks. Each batch is 3–4 small files bundled for wave-width. Different test files per task → parallel-safe. Dependencies vary: T18 (rules/settings tests) needs T9; T19 (hook tests) needs T6; T20/T21 (agent tests) need T10–T17; T22 (D12 tests) needs T7.
- **T23 (smoke.sh integration)** serializes after all test files exist.
- **T24/T25 (docs)** are parallel-safe with each other (different files). Both depend on T23 going green — docs should describe a green-passing state, not a work-in-progress.

## Task sizing

Target: each task ≤ 60 min of focused Developer work.
- **T6 (hook script)** is the largest single-file task (classifier + lang heuristic + JSON emission + fail-safe envelope). Natural split point at the classifier function if it slips; split via `/specflow:update-task` only.
- **T10–T16 (agent surgeries)** vary by baseline line count: `designer` (32→22), `pm` (32→22), `qa-analyst` (30→21) are lightest; `architect` (54→37) and `tpm` (64→44) are heaviest. Developer may want to take `architect` and `tpm` last even though they're parallel-safe, to build template-fill muscle on the smaller roles first.
- **T18–T22 (test batches)** each bundle 2–4 small scripts; the combined batch still fits inside ~60 min because each script is mostly boilerplate + one or two asserts.
- **T8 (user checkpoint)** is fast if it passes (~5 min); blocking if it fails. That's the whole point of putting it before T9.

---

## STATUS Notes

- 2026-04-16 Developer — T1 done (rules scaffold + README/index + classify-before-mutate exemplar + git/.gitkeep)
- 2026-04-16 Developer — T2 done (bash-32-portability rule created; all 6 verify checks PASS; source memory file intact; bash/ dir created as T1 missed it)
- 2026-04-16 Developer — T3 done: sandbox-home-in-tests rule created at .claude/rules/bash/sandbox-home-in-tests.md; sourced from qa-tester/sandbox-home-preflight-pattern.md (memory intact); all 7 verify checks PASS
- 2026-04-16 Developer — T5 done (absolute-symlink-targets rule created; all 5 verify checks PASS; index.md updated)
- 2026-04-16 Developer — T6 done: .claude/hooks/session-start.sh created (pure bash 3.2, fail-safe, D7 dual-key JSON); all 6 verify checks PASS
- 2026-04-16 Developer — T7 done: bin/specflow-install-hook created; all 7 verify checks pass (bash -n, exec bit, no-args exit 2, sandbox add, idempotence, preservation, .bak exists); smoke.sh 12/12 still green
- 2026-04-17 Developer — T10 done: pm.md rewritten to D10 six-block template; 22 non-empty lines (at ceiling); all 8 verify checks PASS; no appendix needed (no cross-role rules were present); PM team-memory dir exists but has no entries (only index.md with "No memories yet.")
- 2026-04-17 Developer — T11 done: designer.md surgery; 32→22 non-empty lines (exact ceiling); all 6 verify checks PASS; no appendix needed (no cross-role content to extract); dir not present token present
- 2026-04-17 Developer — T12 done: architect.md rewritten to D10 six-block template; 32 non-empty lines (ceiling 37); all 6 verify checks PASS; appendix created at architect.appendix.md with "04-tech.md section outline" section; cross-role content (readlink-f, --force, sandbox-HOME, classification-before-mutation, absolute-symlink) removed — all traced to .claude/rules/ files from T2–T5
- 2026-04-17 Developer — T13 done: tpm.md rewritten (39 non-empty lines, ceiling 44); tpm.appendix.md created; all 7 verify checks PASS; wave schedule/task format/STATUS notes/retrospective protocol moved to appendix
- 2026-04-17 Developer — T14 done: developer.md rewritten to 24 non-empty lines (≤24 ceiling); developer.appendix.md created with TDD loop and commit section; all 7 verify checks PASS; cross-role content (bash-portability, sandbox-HOME) removed
- 2026-04-17 Developer — T16 done: qa-tester.md rewritten to D10 six-block template; 21 non-empty lines (≤23 ceiling); all 6 verify checks PASS; no appendix needed (content fits in core)
- 2026-04-17 Developer — T18 done: test/t13_settings_json.sh, test/t14_rules_dir_structure.sh, test/t15_rules_schema.sh, test/t16_hook_exec_bit.sh created; all 4 tests PASS; also created .claude/rules/markdown/ (missing from T1 deliverables)
- 2026-04-17 Developer — T19 done: 4 hook integration tests created (t17_hook_happy_path.sh, t18_hook_failsafe.sh, t19_hook_bad_frontmatter.sh, t20_hook_lang_lazy.sh); all 4 pass (17 checks total); sandbox-HOME preflight in every script; chmod +x applied
- 2026-04-17 Developer — T20 done: test batch C (agent shape); t21_agent_line_count.sh + t22_agent_header_grep.sh + t23_memory_required.sh created; all 3 scripts chmod+x; all PASS (7/7 line-count, 7/7 header-order, 21/21 memory-tokens)
- 2026-04-17 Developer — T21 done: t24_appendix_pointers.sh (4 pointer checks PASS), t25_no_duplication.sh (5 dedup checks PASS), t26_no_new_command.sh (2 checks PASS; baseline 18 files); all 3 scripts chmod +x; sandbox-HOME preflight in each
- 2026-04-17 Developer — T22 done: test/t27_settings_json_preserves_keys.sh and test/t28_settings_json_idempotent.sh created; both PASS; asdf-sandbox fix applied (copy ~/.tool-versions to sandbox HOME so python3 shim resolves under overridden HOME)

---

## Wave schedule

- **Wave 1**: T1                                 (scaffold — blocks everything)
- **Wave 2**: T2, T3, T4, T5, T6, T7             (6 parallel — 4 rule files + hook + installer; all different files)
- **Wave 3**: T8                                 (USER CHECKPOINT — validate hook against real Claude Code session)
- **Wave 4**: T9                                 (wire settings.json — serial, needs T7 helper + T8 green)
- **Wave 5**: T10, T11, T12, T13, T14, T15, T16  (7 parallel — per-role agent surgery, fused slim+memory)
- **Wave 6**: T17                                (dedup audit — serial after all 7 agents land)
- **Wave 7**: T18, T19, T20, T21, T22            (5 parallel — test batches, different test files per batch)
- **Wave 8**: T23                                (serial — smoke.sh registration)
- **Wave 9**: T24, T25                           (2 parallel — docs, different README files)

**Parallel-safety analysis per wave:**

- **Wave 2 (6-wide)** — Files: `.claude/rules/bash/bash-32-portability.md`, `.claude/rules/bash/sandbox-home-in-tests.md`, `.claude/rules/common/no-force-on-user-paths.md`, `.claude/rules/common/absolute-symlink-targets.md`, `.claude/hooks/session-start.sh`, `bin/specflow-install-hook`. All disjoint — no shared file, no shared dispatcher. Tests are each task's own verify — no cross-coupling. Parallel-safe confirmed.
- **Wave 3 (size 1)** — T8 is a manual checkpoint; by design must run alone so the user can observe the outcome and make a continue-or-escalate call. Deliberate serialization.
- **Wave 4 (size 1)** — T9 writes `settings.json` at repo root; no other Wave-4 task needs that file, and nothing else should race the installer. Deliberate serialization.
- **Wave 5 (7-wide)** — Files: one `<role>.md` (+ optional `<role>.appendix.md`) per task. All disjoint: `pm.md`, `designer.md`, `architect.md`, `tpm.md`, `developer.md`, `qa-analyst.md`, `qa-tester.md`. No shared dispatcher or registry (Claude Code discovers agents by filename, not a registry file). Each task ticks its own box in THIS file — per `tpm/parallel-safe-requires-different-files.md`, the TPM/orchestrator ticks all 7 boxes in a single post-merge commit (NOT inside each task's worktree commit) so `06-tasks.md` itself is not a shared-file hazard in the Wave-5 merge. Parallel-safe confirmed subject to that box-ticking discipline.
- **Wave 6 (size 1)** — T17 may edit any of the 7 agent files in-place; can't know which until the audit runs. Safer to serialize than to speculate about which files it touches.
- **Wave 7 (5-wide)** — Files: each batch creates its OWN set of new `test/tNN_*.sh` files (T18 creates t13–t16, T19 creates t17–t20, T20 creates t21–t23, T21 creates t24–t26, T22 creates t27–t28). Zero file overlap. Each batch's tests use its own `mktemp -d` sandbox — no /tmp collision, no `$HOME` collision. Port usage: none. Parallel-safe confirmed.
- **Wave 8 (size 1)** — T23 edits `test/smoke.sh` which is the one shared driver across the whole test tree. Must serialize.
- **Wave 9 (2-wide)** — Files: `.claude/rules/README.md`+`.claude/team-memory/README.md` (T24) vs `README.md` at repo root (T25). T24 touches 2 files, T25 touches 1, no overlap. Parallel-safe confirmed.

Total tasks: **25**. Total waves: **9**. Wave widths: `1, 6, 1, 1, 7, 1, 5, 1, 2`. Widest wave: Wave 5 (7-wide per-role surgery). No wave exceeds the 7-file parallel ceiling that `tpm/parallel-safe-requires-different-files.md` would flag as risky.
