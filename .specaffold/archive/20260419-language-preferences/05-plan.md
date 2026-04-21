# Plan — language-preferences

_2026-04-19 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` (global) — load-bearing for the wave shape. The SessionStart hook edit (D5/D7) and the guardrail CLI (D2) land in different files; they can run in the same wave. `bin/specflow-seed` receives three sub-edits (D3: new state + shim install + dispatcher hook) that all live in one file and must serialize against each other within whatever wave they land in.
- `tpm/parallel-safe-append-sections.md` (global) — applied to `.claude/rules/index.md` (one new row, append-only), `test/smoke.sh` (new test registrations, single-editor convention), `README.md` (new section append, single-editor), and `STATUS.md` Notes. Standard keep-both mechanical resolution expected; do NOT over-serialize on those grounds.
- `tpm/checkbox-lost-in-parallel-merge.md` — widest wave here is 4-way (W2: rule file + hook edit + README + index row). Low risk per the 7/9-way precedent, but the post-wave-merge checkbox audit stays in place.
- `tpm/briefing-contradicts-schema.md` — tasks-stage MUST paste verbatim: (a) the rule-file frontmatter schema from `.claude/rules/README.md`, (b) the D9 YAML schema snippet (`lang:\n  chat: zh-TW`), (c) the D6 classifier output contract and scanned Unicode ranges, (d) the D7 `awk` sniff block. No paraphrase.
- `tpm/same-file-sequential-wave-depth-accepted.md` (global) — does NOT force a per-subcommand wave depth here; `bin/specflow-lint` is a new, single-purpose CLI with only one live subcommand (`scan-staged`; `scan-paths` is an alias surface from the same dispatcher). The only same-file sequencing concern is `bin/specflow-seed` D3 edits, which are not a subcommand expansion — they're three intra-function additions.
- `shared/dogfood-paradox-third-occurrence.md` — **7th occurrence**. R9 is explicit: structural PASS during this feature's verify; runtime PASS deferred to first session after archive + restart. Plan intentionally keeps the live-mutating surface small so structural tests can cover it: one rule file (static), one hook block (integration via `HOOK_TEST=1` sandbox), one lint CLI (integration via sandbox commits), one seed-installer extension (integration via existing sandbox pattern).
- `tpm/tasks-doc-format-migration.md` — does not apply (no mid-flight format migration; fresh tasks-doc authoring next).

## 1. Goal recap

Ship one opt-in config key (`lang.chat` in `.spec-workflow/config.yml`, D1) that flips specflow subagent chat prose to zh-TW while keeping every committed artifact English. The directive lives in one new rule (`.claude/rules/common/language-preferences.md`, D4) loaded unconditionally by the existing SessionStart hook; the hook gains a ~20-line `awk` sniff that appends a `LANG_CHAT=<value>` marker to its additional-context digest when the config is set (D5/D7). Default-off is structural: absent config → no marker → rule body's conditional collapses to no-op. A new `bin/specflow-lint` CLI (D2/D6) plus a pre-commit shim wired by `bin/specflow-seed` (D3) rejects any CJK codepoint leaking into committed artifacts outside a bounded allowlist (D8). Zero edits under `.claude/agents/specflow/**` (R4). Dogfood paradox: runtime verification deferred to next feature post-archive (R9).

## 2. Building blocks

Five building blocks, mapped to PRD requirements and tech decisions. Each block is a coherent unit of work that will decompose into 1–4 tasks in `06-tasks.md`.

### B1 — Rule file and index row (directive source of truth)

- **Intent**: ship the English-only rule body that declares the conditional zh-TW chat directive; register it in the rules index.
- **PRD covers**: R2 (AC2.a–AC2.d), R3 (AC3.a, AC3.b), R4 AC4.b (coverage enumerated), R6 AC6.a/AC6.b.
- **Tech grounded**: D4 (placement + severity `should`), D5 (marker-plus-conditional-prose coupling; rule body references `LANG_CHAT=zh-TW` verbatim), scope-extension memory (one new row under existing `common` section).
- **Primary files**: `.claude/rules/common/language-preferences.md` (CREATE), `.claude/rules/index.md` (EXTEND by one row).
- **Prerequisites**: none.

### B2 — SessionStart hook config-read and marker emission

- **Intent**: extend `.claude/hooks/session-start.sh` with the ~20-line `awk` sniff block that reads `.spec-workflow/config.yml`, validates `lang.chat` against the closed enum (`zh-TW` | `en`), and appends `LANG_CHAT=<value>` to the digest when recognised. Fail-safe discipline preserved; unknown / malformed → one stderr warning + default-off; missing file → silent + default-off.
- **PRD covers**: R1 (AC1.a, AC1.b, AC1.c), R7 (AC7.a, AC7.b, AC7.c).
- **Tech grounded**: D5 (marker emission), D7 (hook edit diff sketch), D9 (schema shape), hook-fail-safe memory.
- **Primary files**: `.claude/hooks/session-start.sh` (EXTEND, single block between digest assembly and JSON-emit).
- **Prerequisites**: none at the code level; logically paired with B1 (rule body references the exact marker string — coupling validated by a static grep test in B4).

### B3 — `bin/specflow-lint` guardrail CLI

- **Intent**: create the closed-enum classifier CLI (`ok` / `cjk-hit` / `allowlisted` / `binary-skip`) per D2/D6. Bash shim dispatches `scan-staged` (default, reads `git diff --cached --name-only`) and `scan-paths <path>...`; Python 3 scanner reads file bytes and tests codepoints against the declared Unicode blocks; emits one line per path to stdout plus summary to stderr; exit 0/1/2 per §4.
- **PRD covers**: R5 (AC5.a, AC5.b, AC5.c — allowlist surfaces; AC5.d — bypass via `--no-verify` plus inline marker, neither accidental).
- **Tech grounded**: D2 (guardrail surface = pre-commit invoking `bin/specflow-lint`), D6 (Unicode ranges + classifier enum + allowlist mechanics — two surfaces: request-quote block and inline HTML-comment marker), D8 (bypass semantics; no env-var bypass).
- **Primary files**: `bin/specflow-lint` (CREATE — bash shim + Python 3 heredoc).
- **Prerequisites**: none at code level; B5 consumes this (pre-commit shim execs it).

### B4 — Pre-commit shim wiring via `bin/specflow-seed` (install surface)

- **Intent**: extend `bin/specflow-seed` so `init` and `migrate` install a `.git/hooks/pre-commit` shim that execs `bin/specflow-lint scan-staged "$@"`. Classify-before-mutate: extend the seed's installer classifier with one new state (`foreign-pre-commit`) per D3; on hit, report `skipped:foreign-pre-commit` with non-zero exit (matches existing skip-and-report convention). Idempotent: re-running over an already-specflow-shim'd hook reports `already`. Uses the specflow-lint sentinel comment to identify our own shim.
- **PRD covers**: R5 AC5.d (bypass explicit, not accidental — shim is the default commit-path gate).
- **Tech grounded**: D3 (one-line shim + classify-before-mutate state extension), `common/no-force-on-user-paths` rule (no clobber of a foreign pre-commit), `common/classify-before-mutate` rule (state enum extension).
- **Primary files**: `bin/specflow-seed` (EXTEND — three additions: new state in classifier, new dispatcher arm in install logic, updated summary-line emit).
- **Prerequisites**: B3 (the shim references `bin/specflow-lint`, so the script must exist at the ref `init/migrate` copies from). At code-edit time the dependency is schema-only (shim content is the fixed string `exec bin/specflow-lint scan-staged "$@"`); at runtime-test time B3 must exist.

### B5 — Tests, README, smoke registration (structural verification surface)

- **Intent**: land tests t51–t66 per tech §4 (static + integration); register them in `test/smoke.sh`; update `README.md` with the single canonical "Language preferences" section (R8 AC8.a/AC8.b); thread the dogfood paradox annotation into STATUS so QA-tester knows which ACs are structural-only.
- **PRD covers**: R8 (AC8.a, AC8.b), R9 (AC9.a — 08-verify.md will carry the annotation; AC9.b is a next-feature handoff, noted in STATUS), and structural coverage of every other R via the tests map.
- **Tech grounded**: tech §4 testing strategy table (t51–t66); sandbox-HOME-in-tests rule for every integration test; bash-32-portability rule for the static grep test (`t63`).
- **Primary files**: `test/t51_rule_file_shape.sh` … `test/t66_readme_doc_section.sh` (CREATE, 16 new test files), `test/smoke.sh` (EXTEND — single-editor registration pass for t51–t66), `README.md` (EXTEND — one new section).
- **Prerequisites**: B1 (static tests t51–t53, t65, t66 assert rule-file content, index row, README section). B2 (integration tests t54–t57 assert hook behaviour). B3 (integration tests t58–t62 assert lint behaviour). B4 (integration test t64 asserts shim wiring). Most tests are standalone test-file tasks; the smoke.sh edit is a single-editor task; the README edit is a single-editor task.

## 3. Wave plan

Three waves. DAG:

```
  W1 (foundation, 3 parallel blocks)
   ├── B1: rule file + index row
   ├── B2: SessionStart hook edit
   └── B3: bin/specflow-lint CLI

  W2 (installer wiring, sequential after B3)
   └── B4: bin/specflow-seed pre-commit shim install

  W3 (tests + docs, parallel after B1+B2+B3+B4)
   └── B5: t51–t66 + smoke registration + README
```

### Wave 1 — foundation (3 blocks parallel)

**Blocks**: B1, B2, B3.

**Parallelism**: all three blocks edit different files.
- B1 → `.claude/rules/common/language-preferences.md` (create) + `.claude/rules/index.md` (one append-only row).
- B2 → `.claude/hooks/session-start.sh` (extend) — different file from B1 and B3.
- B3 → `bin/specflow-lint` (create) — different file from B1 and B2.

The only shared-file append is `.claude/rules/index.md` (B1 alone edits it — no peer collision). `STATUS.md` Notes appends are the standard keep-both case.

**Gating to advance to W2**: B1's rule file passes `bash -n`-equivalent frontmatter shape (5 keys present); B2's hook still passes `bash -n .claude/hooks/session-start.sh` clean and fail-safe discipline preserved (no new `set -e` drift); B3's `bin/specflow-lint` passes `bash -n` + `python3 -c "compile(open('bin/specflow-lint').read(), 'bin/specflow-lint', 'exec')"` on the bash shim and `python3 -m py_compile` on any separate Python helper.

**Rationale**: three logically independent deliverables on three distinct files. No dispatcher-arm collision, no shared-function edits. Exactly the shape `parallel-safe-requires-different-files.md` endorses for real parallelism.

### Wave 2 — installer wiring (1 block)

**Block**: B4.

**Parallelism**: single block (single task in tasks-stage). `bin/specflow-seed` is the only file edited. W2 is serialized after W1 because B4's installed shim references `bin/specflow-lint` by path; at copy time (init/migrate), the source tree must contain that file — which B3 in W1 creates.

**Gating to advance to W3**: `bash -n bin/specflow-seed` clean; classifier extension landed (the new `foreign-pre-commit` state is emitted by a hidden probe or by `--dry-run` inspection); idempotence sentinel string lands with the shim.

**Rationale**: B4 lands alone because all three of its sub-edits touch the same file (`bin/specflow-seed`) — new state arm + dispatcher arm + summary-emit. Per `parallel-safe-requires-different-files.md`, these must serialize inside the wave anyway, so one task over one wave is the correct shape. Waves ≠ tasks; this wave has one task.

### Wave 3 — tests + docs (16 test files + smoke + README, parallel)

**Block**: B5.

**Parallelism**: high. The 16 test files (t51–t66) are each their own file — fully parallel-safe with each other. `test/smoke.sh` is a single-editor task per the B2.a / B2.b / per-project-install precedent (tests do NOT self-register). `README.md` is a single-editor task.

**Expected append-only collisions** (per `parallel-safe-append-sections.md`):
- `test/smoke.sh`: single editor — zero collision.
- `STATUS.md` Notes: every merged task appends a line; standard keep-both.
- `06-tasks.md` checkboxes: ~16 tasks merging concurrently; per `checkbox-lost-in-parallel-merge.md`, expect 1–2 checkbox losses at this width; auto-audit post-wave is the established recovery.

**Gating to archive-stage**: `bash test/smoke.sh` → green (the prior 50/50 plus 16 new = 66 total); `grep -F 'LANG_CHAT=zh-TW'` finds exactly the hook and the rule body (t53 coupling check); `README.md` contains the "Language preferences" section with the exact `lang.chat` key name and `zh-TW` example (t66); all structural ACs of R1–R8 covered with at least one test.

**Rationale**: every prerequisite has landed (rule body text from B1 is what t51/t53 grep against; hook block from B2 is what t53–t57 exercise; lint CLI from B3 is what t58–t62 exercise; installer from B4 is what t64 exercises). All test files are different, so no same-file edit collisions inside the wave. `README.md` and `smoke.sh` each get a single-editor task, sidestepping append-only collision entirely on those two files.

## 4. Critical files

Consolidated add / modify / delete table. Paths are exact from tech doc §7.

| File | Action | Block | Wave | Purpose |
|---|---|---|---|---|
| `.claude/rules/common/language-preferences.md` | **CREATE** | B1 | W1 | Directive prose. English-only, `scope: common`, `severity: should`, conditional body references `LANG_CHAT=zh-TW` marker; body documents conditional pattern per AC2.b. |
| `.claude/rules/index.md` | **EXTEND** | B1 | W1 | One new row in the `common` scope section, sorted alphabetically between `classify-before-mutate` and `no-force-on-user-paths`. |
| `.claude/hooks/session-start.sh` | **EXTEND** | B2 | W1 | ~20-line block between digest assembly and JSON-emit: `awk` sniff of `.spec-workflow/config.yml` → case-based validation of `lang.chat` against `zh-TW` \| `en` \| other → append `LANG_CHAT=<value>` to digest or emit stderr warning. Fail-safe discipline preserved. |
| `bin/specflow-lint` | **CREATE** | B3 | W1 | Bash shim + Python 3 heredoc. `scan-staged` (default) and `scan-paths <path>...` subcommands. Closed enum classifier (`ok` / `cjk-hit:<f>:<l>:<c>:U+<hex>` / `allowlisted:<f>:<reason>` / `binary-skip:<f>`). Exit 0/1/2. Allowlist surfaces: `**/00-request.md` request-quote block; `<!-- specflow-lint: allow-cjk reason="..." -->` inline marker with mandatory reason. Scans Unicode blocks per D6. Exec bit set. |
| `bin/specflow-seed` | **EXTEND** | B4 | W2 | Three edits in one file: (a) add `foreign-pre-commit` state to pre-commit classifier; (b) add pre-commit shim install step to `cmd_init` and `cmd_migrate` dispatchers (sentinel-gated, classify-before-mutate disciplined); (c) update summary-line emit to include pre-commit install outcome. No change to copy plan, manifest shape, or managed subtree list. |
| `.git/hooks/pre-commit` | **CREATE per consumer** | B4 | W2 (runtime-installed) | Two-line shim: `#!/usr/bin/env bash` + `exec bin/specflow-lint scan-staged "$@"`. Installed by `specflow-seed init/migrate`. Not versioned in the source repo. |
| `test/t51_rule_file_shape.sh` | **CREATE** | B5 | W3 | Static: rule-file frontmatter has 5 keys, body English-only (self-linted via `bin/specflow-lint scan-paths`), `## How to apply` documents conditional pattern. Covers AC2.a, AC2.b. |
| `test/t52_rule_index_row.sh` | **CREATE** | B5 | W3 | Static: `.claude/rules/index.md` contains `language-preferences` row with scope `common` + severity `should`, sorted alphabetically. Covers AC2.c. |
| `test/t53_marker_rule_coupling.sh` | **CREATE** | B5 | W3 | Static: `grep -F 'LANG_CHAT=zh-TW'` returns exactly (a) `.claude/hooks/session-start.sh` (b) `.claude/rules/common/language-preferences.md`. No drift. |
| `test/t54_hook_config_absent.sh` | **CREATE** | B5 | W3 | Integration: sandbox `$HOME` with no `.spec-workflow/config.yml`; run hook under `HOOK_TEST=1`; assert digest contains NO `LANG_CHAT=` line, stderr clean, exit 0. Covers AC1.a, AC7.c. |
| `test/t55_hook_config_zh_tw.sh` | **CREATE** | B5 | W3 | Integration: sandbox with `lang:\n  chat: zh-TW`; hook emits `LANG_CHAT=zh-TW` marker; stderr clean; exit 0. Covers AC1.b. |
| `test/t56_hook_config_unknown.sh` | **CREATE** | B5 | W3 | Integration: sandbox with `lang:\n  chat: fr`; hook emits NO marker + exactly one warning line on stderr; exit 0. Covers AC7.a. |
| `test/t57_hook_config_malformed.sh` | **CREATE** | B5 | W3 | Integration: sandbox with syntactically broken config; hook emits no marker + one warning; exit 0. Covers AC7.b. |
| `test/t58_lint_clean_diff.sh` | **CREATE** | B5 | W3 | Integration: sandbox git repo; stage ASCII-only files across `.claude/**`, `.spec-workflow/features/**`, `bin/**`; run `bin/specflow-lint scan-staged`; exit 0, no findings. Covers AC5.b. |
| `test/t59_lint_cjk_hit.sh` | **CREATE** | B5 | W3 | Integration: sandbox + one staged `.md` with a zh-TW sentence; lint exits 1 with `cjk-hit:<f>:<l>:<c>:U+<hex>` on stdout and human-readable summary on stderr. Covers AC5.a. |
| `test/t60_lint_request_quote_allowlist.sh` | **CREATE** | B5 | W3 | Integration: stage `00-request.md` with zh-TW inside the `**Raw ask**:` block only → lint exits 0, `allowlisted:…:request-quote`; move zh-TW outside the block → exit 1. Covers AC5.c. |
| `test/t61_lint_inline_marker_allowlist.sh` | **CREATE** | B5 | W3 | Integration: stage fixture with `<!-- specflow-lint: allow-cjk reason="fixture" -->` → lint exits 0 `allowlisted:…:inline-marker`; remove marker → exit 1. Covers AC5.c. |
| `test/t62_lint_archive_ignored.sh` | **CREATE** | B5 | W3 | Integration: stage zh-TW file at `.spec-workflow/archive/.../foo.md`; lint ignores (path out-of-scope); exit 0. Covers R5 Non-goals, AC5.c. |
| `test/t63_lint_no_jq_no_readlink_f.sh` | **CREATE** | B5 | W3 | Static: `grep -Fn` for `jq`, `readlink -f`, `realpath`, `mapfile`, `[[ =~`, `rm -rf`, `--force` over `bin/specflow-lint` and the new hook block returns empty. Covers bash-32-portability rule. |
| `test/t64_precommit_shim_wiring.sh` | **CREATE** | B5 | W3 | Integration: sandbox consumer; run `specflow-seed init`; assert `.git/hooks/pre-commit` exists, contains specflow-lint sentinel, is executable; stage a CJK file and attempt commit → rejected with non-zero. Covers AC5.d, D3. |
| `test/t65_subagent_diff_empty.sh` | **CREATE** | B5 | W3 | Static: `git diff --stat HEAD~<n>` (or equivalent feature-branch diff) shows zero lines changed under `.claude/agents/specflow/`. Covers AC4.a. |
| `test/t66_readme_doc_section.sh` | **CREATE** | B5 | W3 | Static: `README.md` contains "Language preferences" section with `lang.chat` key name and `zh-TW` example; `grep -l 'lang.chat\|lang:' <root-md>` returns exactly `README.md` + rule file. Covers AC8.a, AC8.b. |
| `test/smoke.sh` | **EXTEND** | B5 | W3 | Single-editor task: register t51–t66 (16 new tests). Prior count 50 → new count 66. |
| `README.md` | **EXTEND** | B5 | W3 | One new section "Language preferences" after Install, before Recovery: names the config file, the key, example value (`zh-TW`), example YAML snippet, pointer to the rule file. R8 AC8.a. |
| `.spec-workflow/config.yml` | **NOT SHIPPED** | — | — | User-authored, local-only. README instructs creation. Not in the managed subtree; `specflow-seed update` never touches it. |
| `.claude/agents/specflow/**` | **UNCHANGED** | — | — | Per R4 AC4.a; verified by t65. |

## 5. Risk log

Six feature-specific risks with mitigations.

### R1 — Dogfood paradox: feature cannot verify itself at runtime

This is the 7th occurrence in this repo. Every AC that depends on runtime subagent behaviour (the rule firing, the marker appearing in a live session's context, the pre-commit rejecting a real commit) cannot be exercised during this feature's own implement / verify cycle — the SessionStart hook reads the new config only after the session that installed the feature has ended and a new one starts.

- **Mitigation**: `08-verify.md` must annotate AC1.b, AC5.a, AC5.b, AC7.* as "structural PASS; runtime deferred to next feature after session restart." Structural coverage is strong: t51–t53 grep the files; t54–t57 drive the hook under `HOOK_TEST=1` in a sandboxed `$HOME`; t58–t62 drive the lint CLI against sandbox git commits; t64 drives the installer against a sandbox consumer. Runtime confirmation is per R9 AC9.b (next-feature handoff).

### R2 — Marker string drift between hook and rule body

The D5 design loosely couples the hook's emitted marker string (`LANG_CHAT=zh-TW`) and the rule body's conditional phrasing. A drift (e.g., hook emits `LANG=zh-TW`, rule expects `LANG_CHAT=zh-TW`) silently breaks the feature — the rule body's conditional would always evaluate false, the agent would never switch, and no test would flag it unless the coupling is machine-checked.

- **Mitigation**: t53 (`test/t53_marker_rule_coupling.sh`) is a static grep that asserts `grep -F 'LANG_CHAT=zh-TW'` finds exactly (a) `.claude/hooks/session-start.sh` and (b) `.claude/rules/common/language-preferences.md`. Any drift in either side causes t53 to fail. Tasks-stage must quote the exact marker string from D7 verbatim into both B1 and B2 task scopes per `briefing-contradicts-schema.md`.

### R3 — Pre-commit hook must not block commits of PRDs containing quoted zh-TW user asks

This feature's PRD (`.spec-workflow/features/20260419-language-preferences/03-prd.md`) quotes zh-TW in Scenarios A/B/C dialogue examples in English paraphrase, but future features' `00-request.md` files quote user input verbatim (today three `00-request.md` files carry CJK; this feature adds more). A naive guardrail would reject every commit that touches those files.

- **Mitigation**: D6 specifies two allowlist surfaces: (a) the `**Raw ask**:` block in `**/00-request.md` is allowlisted by path+block pattern; (b) any file may carry `<!-- specflow-lint: allow-cjk reason="..." -->` for surgical exemption. Both allowlists are explicit, grep-findable, and reason-required. t60 (request-quote) and t61 (inline marker) prove each allowlist path; t62 proves `.spec-workflow/archive/**` is out-of-scope entirely. Tasks-stage must quote D6's allowlist pattern verbatim into B3's scope.

### R4 — Rule body is English-only but describes a zh-TW directive

This feature's rule file is the first rule in the tree whose *content* instructs behaviour for a different language, while the rule file itself must be English. The failure mode: a developer (or agent) reflexively writes the directive in zh-TW ("當 `LANG_CHAT=zh-TW` …") thinking the rule applies "in Chinese" because it talks about Chinese.

- **Mitigation**: t51 explicitly runs `bin/specflow-lint scan-paths .claude/rules/common/language-preferences.md` against the rule file itself — if any CJK codepoint slipped into the rule body, t51 fails. PRD AC2.a makes this verifiable by the same guardrail R5 ships, closing the loop. Tasks-stage must state this explicitly in B1's scope and reference the t51 assertion.

### R5 — `awk` YAML sniff is narrower than real YAML; false-negative on legitimate variant shapes

D7's `awk` one-liner accepts only the exact shape `lang:\n  chat: <value>` with two-space indent, no inline comment on the `chat:` line, no quoted values beyond stripping double-quotes. A user who writes `lang: {chat: zh-TW}` (flow-style YAML) or `lang:\n    chat: zh-TW` (four-space indent) gets silent default-off — arguably a UX bug.

- **Mitigation**: the documented v1 schema in D9 is the exact `awk`-parseable shape; any deviation classifies unknown and emits the stderr warning path (AC7.a). README's "Language preferences" section (B5) must show the exact example YAML — the user is not expected to invent the shape. Accept this as a scope boundary for v1; D13 (`specflow config set`) is the deferred UX fix.

### R6 — `bin/specflow-seed` classifier state extension regression

B4 adds one new state (`foreign-pre-commit`) to the existing `bin/specflow-seed` classifier. Scope-extension-minimal-diff rule says this is a one-line diff, but same-file edits to a dispatcher-like classifier can trigger per `parallel-safe-requires-different-files.md` if a peer feature lands concurrently.

- **Mitigation**: B4 is the only task in W2 (serialized after W1). No peer same-file edits in this feature. Cross-feature concurrency is not currently a concern (no other feature in-flight). T64 exercises the installed shim end-to-end in a sandbox, closing the correctness loop.

## 6. Verification map

Each PRD requirement → ACs → test surface → structural vs runtime annotation.

| R | AC | Test file | Surface | Annotation |
|---|---|---|---|---|
| R1 | AC1.a (baseline English) | t54 | integration (sandbox `HOOK_TEST=1`) | Structural. Live session behaviour deferred to next feature. |
| R1 | AC1.b (opt-in emits marker) | t55 + t53 | integration + static coupling | Structural PASS; runtime deferred to next feature after session restart (R9). |
| R1 | AC1.c (opt-out = removal, not flag) | t54 (absent-file branch) | integration | Structural. |
| R2 | AC2.a (rule exists, English-only) | t51 | static (including self-lint via `bin/specflow-lint scan-paths`) | Structural — fully verifiable. |
| R2 | AC2.b (conditional pattern documented) | t51 | static grep for conditional phrasing | Structural — fully verifiable. |
| R2 | AC2.c (index row) | t52 | static | Structural. |
| R2 | AC2.d (loads unconditionally) | t51 + t53 | static (rule frontmatter valid → classifier will emit) | Structural — classifier behaviour exercised by hook integration tests t54–t57. |
| R3 | AC3.a (six carve-outs enumerated) | t51 | static grep for each of (a)–(f) | Structural — fully verifiable. |
| R3 | AC3.b (no reverse directive) | t51 | static grep — assert rule body does NOT contain inverse phrasing | Structural — fully verifiable. |
| R4 | AC4.a (no agent diff) | t65 | static `git diff --stat` | Structural — fully verifiable. |
| R4 | AC4.b (coverage enumerated) | t51 | static grep for each of 7 role names | Structural — fully verifiable. |
| R5 | AC5.a (rejection path) | t59, t64 | integration (sandbox commit) | Structural PASS in sandbox; runtime rejection on user's real commit deferred to next feature after session restart. |
| R5 | AC5.b (clean-diff passes) | t58 | integration | Structural PASS; runtime deferred. |
| R5 | AC5.c (allowlist scope) | t60, t61, t62 | integration | Structural. |
| R5 | AC5.d (bypass explicit) | t64 (shim presence + `--no-verify` docs in README) | integration + static | Structural — shim presence verifiable; live `--no-verify` bypass is standard git behaviour requiring no test. |
| R6 | AC6.a (positive scope example) | t51 | static grep | Structural. |
| R6 | AC6.b (negative scope examples ≥3) | t51 | static grep | Structural. |
| R7 | AC7.a (unknown value → default-off + warning) | t56 | integration | Structural PASS; runtime deferred. |
| R7 | AC7.b (malformed config → default-off + warning) | t57 | integration | Structural PASS; runtime deferred. |
| R7 | AC7.c (missing file → default-off, no warning) | t54 | integration | Structural PASS; runtime deferred. |
| R8 | AC8.a (README section) | t66 | static | Structural — fully verifiable. |
| R8 | AC8.b (grep-verifiable — one canonical doc) | t66 | static | Structural — fully verifiable. |
| R9 | AC9.a (structural markers in 08-verify.md) | — | documentation discipline (QA-tester) | Structural — enforced by verify-stage checklist, not by a test. |
| R9 | AC9.b (next-feature confirmation) | — | handoff AC | Next-feature handoff. Not verifiable in this feature. |

Coverage summary: **16 tests** (t51–t66) → **23 ACs across R1–R8** fully structurally covered; **R9** is the meta-AC about the paradox itself. Two test surfaces lean heavily on sandbox discipline: t54–t57 (sandbox `$HOME` + `HOOK_TEST=1`) and t58–t64 (sandbox git repo + staged fixtures). Both follow the template in `.claude/rules/bash/sandbox-home-in-tests.md`.

## 7. Constraints-from-rules carried forward (for tasks-stage)

Tasks-stage MUST surface these in each relevant task's scope:

- **Bash 3.2 portability** (`.claude/rules/bash/bash-32-portability.md`): applies to B2 (hook edit) and B4 (seed edit) and B3 (bash shim over Python 3). No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` in portability-critical logic. `case "$cfg_chat" in zh-TW|en) … ;;` per D7 — already portable. t63 is the machine-enforced backstop.
- **Sandbox-HOME-in-tests** (`.claude/rules/bash/sandbox-home-in-tests.md`): every integration test in B5 (t54, t55, t56, t57, t58, t59, t60, t61, t62, t64) must open with `mktemp -d`, export `HOME="$SANDBOX/home"`, register `trap 'rm -rf "$SANDBOX"' EXIT`, and preflight-assert `case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac` before any invocation.
- **No-force-on-user-paths** (`.claude/rules/common/no-force-on-user-paths.md`): applies to B4's pre-commit shim installer. Classify-before-mutate; `skipped:foreign-pre-commit` with exit non-zero rather than clobber. No `--force`. No silent overwrite of a non-specflow pre-commit.
- **Classify-before-mutate** (`.claude/rules/common/classify-before-mutate.md`): applies to B4's classifier extension (new `foreign-pre-commit` state) and to B3's classifier contract (`ok` / `cjk-hit` / `allowlisted` / `binary-skip` is a closed enum; no branching inside the classifier on anything else).
- **Rule file schema** (`.claude/rules/README.md`): applies to B1. Quote verbatim from README: frontmatter has `name`, `scope`, `severity`, `created`, `updated` (all five keys; filename stem matches `name:`); body has `## Rule`, `## Why`, `## How to apply` in that order. Tasks-stage must paste this block verbatim into B1's task scope per `briefing-contradicts-schema.md`.
- **Performance axis** (`.claude/rules/reviewer/performance.md`): applies to B2 (hook is on the SessionStart hot path; 200 ms budget). The `awk` one-liner is a single-pass file read; well under budget.
- **Security axis** (`.claude/rules/reviewer/security.md`): applies to B3's Python scanner (input validation at boundary: git returns staged paths; Python opens each one read-only, no shell-concatenation, no `eval`). B4's installer uses atomic write + `.bak` discipline (inherits existing seed conventions per D3).

## 8. Dogfood paradox staging plan

Per R9 and `shared/dogfood-paradox-third-occurrence.md` (now 7th occurrence):

1. **During implement (W1–W3)**: this feature's own subagents write in English regardless of any `lang.chat` setting on the machine — the hook has not yet been modified during the development session, and even once modified, the active session picked up the pre-modification hook output. This is expected; the paradox is explicit in R9 and this plan.
2. **`08-verify.md` annotation** (QA-tester, stage after implement + gap-check): verdict must distinguish structural PASS from runtime PASS. At minimum annotate AC1.b, AC5.a, AC5.b, AC7.a, AC7.b, AC7.c as "structural PASS; runtime deferred to next feature after session restart." Direct quotation from R9 AC9.a.
3. **Next-feature runtime confirmation** (R9 AC9.b): the first feature archived after this one MUST include an early STATUS Notes line confirming first-session runtime behaviour of language-preferences — either "ran with knob unset, chat English as expected" or "ran with knob set to zh-TW, chat observed in zh-TW as expected." Not verifiable in this feature; handoff AC only.
4. **Bypass discipline** (per `shared/opt-out-bypass-trace-required.md`): this feature does NOT ship an opt-out flag for its own development session (no equivalent of `--skip-inline-review`). The natural bypass is "nothing different happens until the user restarts their Claude Code session." No STATUS trace required during implement because no bypass is invoked.

## 9. Handoff to `/specflow:tasks`

Target `06-tasks.md` with **~20–23 tasks across 3 waves**:

- **W1 (3 parallel)**: 3 tasks — one per block (B1, B2, B3). Each task edits a distinct file set; fully parallel-safe with each other.
  - T-B1-rule-file-and-index (two sub-files, single task: create rule file + append index row; editor owns both since they are paired logically).
  - T-B2-hook-config-read (edit `.claude/hooks/session-start.sh`).
  - T-B3-lint-cli (create `bin/specflow-lint`).
- **W2 (1 task)**: B4 — `T-B4-precommit-install` (extend `bin/specflow-seed` with three intra-function additions: classifier state + dispatcher arm + summary-emit). Cannot parallelize within this wave (same file).
- **W3 (16–18 parallel)**: B5 decomposed per test file plus single-editor smoke + README tasks.
  - 16 test-file tasks (T-B5-t51 … T-B5-t66), each creating one test file. All parallel-safe (different files).
  - 1 smoke-register task (T-B5-smoke-register) — single editor for `test/smoke.sh`, parallel-safe with all test-file tasks.
  - 1 README task (T-B5-readme) — single editor for `README.md`, parallel-safe with all other W3 tasks.

**Tasks-stage must**:

- Paste verbatim (per `briefing-contradicts-schema.md`):
  - The rule-file frontmatter schema from `.claude/rules/README.md` into T-B1's scope.
  - The D9 YAML schema block (`lang:\n  chat: zh-TW # or "en"`) into T-B1 (rule body references it) and T-B2 (hook parses it) and T-B5-readme (README documents it) scopes.
  - The D6 classifier output contract and Unicode range list into T-B3's scope.
  - The D7 `awk` sniff block (the full ~20-line bash sketch from tech doc) into T-B2's scope.
  - The allowlist pattern (`<!-- specflow-lint: allow-cjk reason="..." -->` plus `**Raw ask**:` block matcher) into T-B3's and T-B5 (t60/t61) scopes.
- Flag R9 dogfood annotation duty for QA-tester in the task for 08-verify.md orchestration — not as a task, but as a STATUS reminder at implement handoff.
- Register **expected append-only collisions** in the tasks-doc `## Wave schedule` section: W3 has concurrent STATUS Notes appends and concurrent 06-tasks.md checkbox flips (~18 tasks); apply the post-wave checkbox audit per `tpm/checkbox-lost-in-parallel-merge.md`.
- Each task's `Acceptance:` field must be a runnable command (`bash test/t5X_<name>.sh`, `bash -n <script>`, `grep -F 'LANG_CHAT=zh-TW' <files>`, etc.) per the output contract.

---

## Summary

- **Blocks**: 5 (B1 rule, B2 hook, B3 lint CLI, B4 seed installer, B5 tests+docs).
- **Waves**: 3 (W1 foundation 3-parallel, W2 installer 1-task, W3 tests+docs 16–18-parallel).
- **Critical path**: W1 is the tight coupling point — B1's rule body and B2's hook marker must reference the same string `LANG_CHAT=zh-TW`, validated by t53 in W3. W2 depends on W1's B3 for the lint CLI file presence. W3 depends on all four prior blocks.
- **Load-bearing risks**: (R1) dogfood paradox — structural-only this feature; (R2) marker string drift — machine-checked by t53; (R4) rule-body-is-English-only while describing a zh-TW directive — machine-checked by t51 via the guardrail itself.
- **TPM memory consulted**: 5 TPM entries and 1 shared memory applied. `parallel-safe-requires-different-files` validates W1 3-parallel shape (three distinct files) and serializes W2 (same-file intra-function edits). `parallel-safe-append-sections` keeps W3 maximally parallel despite `test/smoke.sh` / `STATUS.md` / `06-tasks.md` checkbox collisions. `checkbox-lost-in-parallel-merge` flagged for W3 post-merge audit (~18-way width). `briefing-contradicts-schema` drives the verbatim-quote discipline for tasks-stage (frontmatter schema, YAML schema, `awk` block, classifier contract, allowlist pattern). `shared/dogfood-paradox-third-occurrence` drives R9 annotation duty and W3 structural-only orientation.
