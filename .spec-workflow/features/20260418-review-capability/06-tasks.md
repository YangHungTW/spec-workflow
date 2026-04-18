# Tasks — review-capability (B2.b)

_2026-04-18 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R28), `04-tech.md` (D1–D12),
`05-plan.md` (M1–M7). Every task names the milestone, requirements, and
decisions it lands. `Verify` is a concrete runnable command (or
filesystem check) the Developer runs at the end of the task; if it
passes, the task is done.

All paths below are absolute under
`/Users/yanghungtw/Tools/spec-workflow/`. When this plan says "the
SessionStart hook" it means `.claude/hooks/session-start.sh` (B1). When
it says "the implement command" it means
`.claude/commands/specflow/implement.md`. When it says "rubric file" it
means one of `.claude/rules/reviewer/{security,performance,style}.md`.
When it says "reviewer agent" it means one of
`.claude/agents/specflow/reviewer-{security,performance,style}.md`.

---

## T1 — Schema extension: admit `reviewer` scope + seed dir
- **Milestone**: M1
- **Requirements**: R22
- **Decisions**: D12 (minimal-diff: one enum value, one table row, one checklist bullet)
- **Scope**: Three small coordinated edits to a single markdown file plus one directory seed:
  1. **`.claude/rules/README.md` scope enum** — in the frontmatter schema YAML example block, change the `scope:` line from `common | bash | markdown | git | <lang>` to `common | bash | markdown | git | reviewer | <lang>`. Exactly one token insertion; do NOT reorder existing values.
  2. **`.claude/rules/README.md` directory-layout section** — add one new row under the `.claude/rules/` tree that reads:
     ```
     reviewer/          ← scope: reviewer — agent-triggered, NOT session-loaded
     ```
     Insert after the `git/` row. Keep the pseudo-tree formatting identical to neighbouring rows (two-space indent, `←` arrow, tab spacing).
  3. **`.claude/rules/README.md` authoring checklist** — the scope-check bullet currently reads `- [ ] scope: is one of the four established dirs (or a new dir created to match).` Update to `- [ ] scope: is one of the five established dirs (common/bash/markdown/git/reviewer) or a new dir created to match.` — one word change + five-dir enumeration.
  4. **Seed `.claude/rules/reviewer/` with `.gitkeep`** — create the directory and add an empty `.gitkeep` placeholder so M2 tasks can target the dir cleanly in parallel worktrees without racing on directory creation. The `.gitkeep` is temporary — it will be removed by M2 when rubric files land (or left in place; either is acceptable).
- **NOT changed**: severity semantics table; body-sections list; rules-vs-team-memory contract table. No edits outside the three sites above.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/README.md` (three sites) + new file `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/.gitkeep` (empty).
- **Verify**:
  - `grep -q 'common | bash | markdown | git | reviewer | <lang>' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/README.md` — scope enum extended.
  - `grep -q 'reviewer/' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/README.md` — dir-layout row present.
  - `grep -q 'five established dirs' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/README.md` — authoring checklist updated.
  - `test -d /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer` — subdir exists.
- **Depends on**: —
- **Parallel-safe-with**: T2
- [x]

## T2 — SessionStart hook: skip `reviewer/` subdir in walk
- **Milestone**: M1
- **Requirements**: R23
- **Decisions**: D7 (early-`continue` inside walk loop with `SKIP_SUBDIRS` guard); `.claude/rules/bash/bash-32-portability.md`; architect `hook-fail-safe-pattern` memory (preserve `set +e`, trap, `exit 0`).
- **Scope**: Single-file edit to `.claude/hooks/session-start.sh`. Preserve EVERY existing fail-safe envelope — no change to shebang, `set +e`, `trap 'exit 0' ERR INT TERM`, `log_warn`/`log_info` helpers, the final `exit 0`. Pure bash 3.2 / BSD userland: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic. Exactly one insertion inside the main `while IFS= read -r subdir; do … done` walk loop (currently at lines ~217–245):
  1. Declare `SKIP_SUBDIRS="reviewer"` as a module-level string variable immediately above the walk loop's `digest=""` line (so future additions can extend the list space-separated).
  2. Inside the loop body, as the first executable line after `[ -z "$subdir" ] && continue`, add a POSIX-safe skip-check using `case` (not `[[ =~ ]]`):
     ```
     case " $SKIP_SUBDIRS " in
       *" $subdir "*) continue ;;
     esac
     ```
     Two-element dispatch. The space-padding on both sides of the match makes `reviewer` match only as a whole word (no false-positive on a hypothetical `reviewer-extra` sibling). Pure string check — cannot fail in any way that affects the fail-safe posture.
- **NOT changed**: `classify_frontmatter`, `digest_rule`, `lang_heuristic`, `json_escape`, the JSON emission block, the `RULES_DIR` constant, the fail-safe outer envelope. The guard is additive; no existing line edited.
- **Deliverables**: one edited file, `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh`. No new files; no other edits.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` — syntax clean.
  - `grep -q 'SKIP_SUBDIRS=' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/session-start.sh` — variable declared.
  - B1 regression — `bash /Users/yanghungtw/Tools/spec-workflow/test/t17_session_start_happy_path.sh` (or the B1 hook happy-path test matching current smoke registration) exits 0.
  - B1 fail-safe regression — `bash /Users/yanghungtw/Tools/spec-workflow/test/t18_session_start_failsafe.sh` (or the B1 fail-safe test) exits 0.
  - Smoke floor — `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` — all existing 33 B1+B2.a tests stay green.
  - Manual dry-run with populated reviewer subdir (pre-M2, empty subdir existing from T1): `cd /Users/yanghungtw/Tools/spec-workflow && bash .claude/hooks/session-start.sh </dev/null 2>/dev/null | grep -c 'reviewer/'` — must output `0`.
- **Depends on**: —
- **Parallel-safe-with**: T1

  File-set check: T1 edits `.claude/rules/README.md` + creates `.claude/rules/reviewer/.gitkeep`. T2 edits `.claude/hooks/session-start.sh`. Disjoint. The T2 manual dry-run step reads but does not write the subdir T1 created; sequencing inside Wave 1 resolves this when both land.
- [ ]

---

## T3 — Rubric: `.claude/rules/reviewer/security.md`
- **Milestone**: M2
- **Requirements**: R18, R21
- **Decisions**: D12 (reviewer scope), no-duplication (cross-reference `common/no-force-on-user-paths.md` rather than restate).
- **Scope**: Create `.claude/rules/reviewer/security.md` with the standard rule-file schema (5 frontmatter keys + `## Rule` / `## Why` / `## How to apply` / `## Example` body in that order). Frontmatter:
  ```yaml
  ---
  name: security
  scope: reviewer
  severity: must
  created: 2026-04-18
  updated: 2026-04-18
  ---
  ```
  Body:
  - `## Rule` — one-sentence imperative: "Flag findings against the security axis checklist; do not flag issues outside this axis."
  - `## Why` — 1–3 sentences on why a narrowly-scoped security rubric for diff-level review catches the runtime-class bugs (hardcoded paths, traversal, injection) that gap-check typically surfaces late.
  - `## How to apply` — opinionated checklist with exactly the 8 entries from PRD R18, each marked with its severity:
    1. Hardcoded secrets or tokens (`must`)
    2. Path traversal (`must`)
    3. Input validation at boundaries (`must`)
    4. Injection attacks (`must`)
    5. Untrusted YAML / JSON parsing (`should`)
    6. Secure defaults — cross-reference `.claude/rules/common/no-force-on-user-paths.md` (`must`) — one-line pointer, do NOT restate the no-force rule body.
    7. Atomic file writes and backups (`should`)
    8. Sentinel-file race conditions (`should`)
  - `## Example` — at least one concrete diff snippet illustrating a `must` finding (a hardcoded path or string-built shell command) and the expected structured-finding emission matching D1's verdict footer shape.
  - Also append one new row to `.claude/rules/index.md` at the correct sorted position (scope=reviewer rows land after `markdown`, before the existing `bash`/`common` blocks per scope-then-name sort):
    ```
    | security | reviewer | must | [reviewer/security.md](reviewer/security.md) |
    ```
- **NOT changed**: README.md (T1's job); agent files (T6–T8's job); other rubric files (T4/T5).
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/security.md`; one-row append to `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/security.md` — file exists.
  - Frontmatter schema — `awk '/^---$/{c++; next} c==1{print} c==2{exit}' .claude/rules/reviewer/security.md | grep -c '^\(name\|scope\|severity\|created\|updated\):'` returns `5`.
  - Scope check — `grep -q '^scope: reviewer$' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/security.md`.
  - Checklist count — `awk '/^## How to apply/{flag=1; next} /^## /{flag=0} flag' .claude/rules/reviewer/security.md | grep -cE '^[0-9]+\.' ` returns ≥ `6`.
  - Body-heading order — `grep -n '^## ' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/security.md` emits `Rule` then `Why` then `How to apply` then `Example` in that order.
  - Index row — `grep -q '| security | reviewer | must |' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
  - No-duplication — rubric entry 6 references `no-force-on-user-paths` by path, not by restated text: `grep -q 'common/no-force-on-user-paths.md' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/security.md`.
- **Depends on**: T1 (scope enum must admit `reviewer` before the file's `scope: reviewer` frontmatter is syntactically valid per the schema).
- **Parallel-safe-with**: T4, T5, T6, T7, T8

  File-set check: T3 writes `.claude/rules/reviewer/security.md` (new) + appends one row to `.claude/rules/index.md`. T4/T5 write sibling rubric files (disjoint). T6–T8 write agent files in `.claude/agents/specflow/` (different dir). Expected append-only collision on `index.md` across T3/T4/T5 — mechanical keep-both resolution per `tpm/parallel-safe-append-sections.md`; do NOT serialize.
- [x]

## T4 — Rubric: `.claude/rules/reviewer/performance.md`
- **Milestone**: M2
- **Requirements**: R19, R21
- **Decisions**: D12; `performance.md` entry 7 cross-references B1's R5 hook-latency SLA (do not restate the SLA body).
- **Scope**: Same shape as T3 but for the performance axis. Create `.claude/rules/reviewer/performance.md` with frontmatter:
  ```yaml
  ---
  name: performance
  scope: reviewer
  severity: should
  created: 2026-04-18
  updated: 2026-04-18
  ---
  ```
  (Default severity `should` reflects the axis posture — most perf findings are `should`, the `must` entries call out runtime-class issues.) Body sections `## Rule` / `## Why` / `## How to apply` / `## Example` in that order. `## How to apply` checklist contains exactly the 8 entries from PRD R19:
  1. No shell-out in tight loops (`must`)
  2. Avoid O(n²) where O(n) works (`must`)
  3. Cache expensive operations (`should`)
  4. Prefer `awk`/`sed` over `python3` for simple transforms (`should`)
  5. No re-reading the same file (`should`)
  6. Minimise fork/exec in hot paths (`should`)
  7. Hook latency budget < 200ms (`must`) — one-line cross-reference to B1's R5 SLA.
  8. Avoid eager loads of unused data (`should`)
  `## Example` — one diff snippet showing a shell-out-in-loop finding and the expected verdict footer emission.
  Append one row to `.claude/rules/index.md`:
  ```
  | performance | reviewer | should | [reviewer/performance.md](reviewer/performance.md) |
  ```
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/performance.md`; one-row append to `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/performance.md`.
  - Frontmatter 5-key count and `scope: reviewer` (same awk+grep checks as T3).
  - Checklist ≥ 6 entries under `## How to apply`.
  - Body-heading order (Rule/Why/How to apply/Example).
  - Index row — `grep -q '| performance | reviewer |' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T3, T5, T6, T7, T8

  File-set check: disjoint new rubric file; append-only collision on `index.md` is expected and mechanically resolvable.
- [x]

## T5 — Rubric: `.claude/rules/reviewer/style.md`
- **Milestone**: M2
- **Requirements**: R20, R21
- **Decisions**: D12; entries 5–6 cross-reference `bash/bash-32-portability.md` and `bash/sandbox-home-in-tests.md` respectively (do not restate).
- **Scope**: Same shape as T3/T4 but for the style axis. Create `.claude/rules/reviewer/style.md` with frontmatter:
  ```yaml
  ---
  name: style
  scope: reviewer
  severity: should
  created: 2026-04-18
  updated: 2026-04-18
  ---
  ```
  Body sections in required order. `## How to apply` checklist contains exactly the 8 entries from PRD R20:
  1. Match existing naming conventions in the file (`should`)
  2. No commented-out code (`must`)
  3. Comments explain WHY, not WHAT (`should`)
  4. Match neighbour indent and quoting (`should`)
  5. Bash 3.2 portability — cross-reference `.claude/rules/bash/bash-32-portability.md` (`must`). One-line pointer; do NOT restate the portability rule body.
  6. Sandbox-HOME in test scripts — cross-reference `.claude/rules/bash/sandbox-home-in-tests.md` (`must`). One-line pointer.
  7. `set -euo pipefail` convention (`should`)
  8. Dead imports / unused symbols (`should`)
  `## Example` — one diff snippet showing a `must`-severity style finding (e.g., commented-out code block or `readlink -f` usage flagged via the cross-referenced bash-32 rule) plus the verdict footer shape.
  Append one row to `.claude/rules/index.md`:
  ```
  | style | reviewer | should | [reviewer/style.md](reviewer/style.md) |
  ```
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/style.md`; one-row append to `/Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/style.md`.
  - Frontmatter 5-key count and `scope: reviewer`.
  - Checklist ≥ 6 entries.
  - Body-heading order.
  - Index row — `grep -q '| style | reviewer |' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/index.md`.
  - Cross-reference links — `grep -q 'bash/bash-32-portability.md' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/style.md` AND `grep -q 'bash/sandbox-home-in-tests.md' /Users/yanghungtw/Tools/spec-workflow/.claude/rules/reviewer/style.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T3, T4, T6, T7, T8
- [x]

## T6 — Reviewer agent: `.claude/agents/specflow/reviewer-security.md`
- **Milestone**: M3
- **Requirements**: R14, R15, R16, R17
- **Decisions**: D1 (markdown verdict footer output contract), D4 (stay-in-lane literal + rubric reiteration), D5 (task-local inline vs feature-wide one-shot input contract), D8 (Sonnet), D9 (flat layout). Reference template: `.claude/agents/specflow/qa-analyst.md` (post-B1 shape).
- **Scope**: Create `.claude/agents/specflow/reviewer-security.md` using the B1 D10 six-block core template:
  1. **YAML frontmatter**: `name: reviewer-security`, `model: sonnet`, `description: <short — security-axis reviewer for diff-level review>`, `tools: <as appropriate — Read, Grep, Bash for diff inspection>`.
  2. **Role identity** — single line declaring the reviewer role.
  3. **`## Team memory` invocation block** — standard shape (read global then local `~/.claude/team-memory/<role>/index.md` and `.claude/team-memory/<role>/index.md`; shared/index.md both tiers; pull relevant entries). Per R15, extend with an explicit instruction to ALSO read `.claude/rules/reviewer/security.md` before acting. If the rubric file is missing or malformed, emit a stderr diagnostic and return `verdict: PASS` per PRD §6 edge-case #7.
  4. **`## When invoked for /specflow:implement`** — task-local inline-review invocation per R1–R2 / D5. Inputs: task branch diff (`git diff <slug>...<slug>-T<n>`), PRD R-ids linked to the task from `06-tasks.md`, the rubric (loaded via step 3). DO NOT read the whole repo or the whole feature diff.
  5. **`## When invoked for /specflow:review`** — feature-wide one-shot invocation per R8–R9 / D5. Inputs: full feature-branch diff (`git diff main...<slug>`, or archived-feature commit-range equivalent), the PRD, the rubric. Reviewer may chunk its own reading for large diffs.
  6. **`## Output contract`** — the canonical D1 verdict-footer shape (pure-markdown `key: value` lines, NOT JSON-in-codefence). Exact structure:
     ```
     ## Reviewer verdict
     axis: security
     verdict: PASS | NITS | BLOCK
     findings:
       - severity: must | should | advisory
         file: <path>
         line: <n>
         rule: <rule-slug>
         message: <one-line>
     ```
     Include a note that the parser (D2) treats malformed footers as BLOCK per the fail-loud posture.
  7. **`## Rules`** — contains THE LITERAL stay-in-lane sentence required by R17 / AC-stay-in-your-lane, verbatim:

     > Comment only on findings against your axis rubric. Do not flag issues outside your axis even if you notice them — the other reviewers cover those axes.
- **NOT changed**: existing agent files; other reviewer agents (T7/T8); rubric files (T3–T5).
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`. No other files.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - `grep -q '^model: sonnet$' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` — Sonnet tier (D8).
  - `grep -q '^name: reviewer-security$' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` — frontmatter name matches filename stem.
  - Stay-in-lane literal — `grep -q 'Comment only on findings against your axis rubric' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - Rubric reference — `grep -q '.claude/rules/reviewer/security.md' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - Verdict footer template — `grep -q '^## Reviewer verdict' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` AND `grep -q 'axis: security' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - Two when-invoked sections — `grep -c '^## When invoked' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` returns `2`.
- **Depends on**: — (independent of T3–T5; file references the rubric location by path, doesn't require the rubric to exist at author time)
- **Parallel-safe-with**: T3, T4, T5, T7, T8

  File-set check: T6 writes a new file in `.claude/agents/specflow/`. T3–T5 write new rubric files in `.claude/rules/reviewer/`. T7/T8 write sibling agent files. All disjoint. No shared-file collisions.
- [ ]

## T7 — Reviewer agent: `.claude/agents/specflow/reviewer-performance.md`
- **Milestone**: M3
- **Requirements**: R14, R15, R16, R17
- **Decisions**: D1, D4, D5, D8, D9.
- **Scope**: Same six-block template as T6 but for the performance axis:
  - Frontmatter `name: reviewer-performance`, `model: sonnet`.
  - Team-memory block extended to read `.claude/rules/reviewer/performance.md` per R15.
  - Two when-invoked sections (inline + one-shot) describing task-local vs feature-wide inputs.
  - Output contract: D1 verdict footer with `axis: performance`.
  - Rules: verbatim stay-in-lane sentence (same wording as T6).
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-performance.md`.
- **Verify**: same grep set as T6 but with `performance` substituted for `security` in `name:`, `axis:`, and rubric path.
- **Depends on**: —
- **Parallel-safe-with**: T3, T4, T5, T6, T8
- [ ]

## T8 — Reviewer agent: `.claude/agents/specflow/reviewer-style.md`
- **Milestone**: M3
- **Requirements**: R14, R15, R16, R17
- **Decisions**: D1, D4, D5, D8, D9.
- **Scope**: Same six-block template as T6/T7 but for the style axis:
  - Frontmatter `name: reviewer-style`, `model: sonnet`.
  - Team-memory block extended to read `.claude/rules/reviewer/style.md` per R15.
  - Two when-invoked sections.
  - Output contract: D1 verdict footer with `axis: style`.
  - Rules: verbatim stay-in-lane sentence.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md`.
- **Verify**: same grep set as T6/T7 with `style` substituted.
- **Depends on**: —
- **Parallel-safe-with**: T3, T4, T5, T6, T7
- [ ]

---

## T9 — `/specflow:implement` inline-review injection
- **Milestone**: M4
- **Requirements**: R1, R2, R3, R4, R5, R6, R7
- **Decisions**: D1 (verdict wire format), D2 (pure-bash classifier; mutation strictly outside the classifier per `classify-before-mutate` rule), D6 (retry re-runs all 3), D11 (flag-only opt-out, no env var).
- **Scope**: Single-file edit to `.claude/commands/specflow/implement.md`. Multi-site but all sites in the same file — do NOT split across tasks (same-file sites force serialization per `tpm/parallel-safe-requires-different-files.md`). All aggregator logic is prompt pseudocode executed via the Bash tool; stays bash 3.2 / BSD userland portable.
  1. **Frontmatter / usage line** — add `--skip-inline-review` flag documentation to the command's usage block (R7 / D11). Describe: default OFF (inline review runs); when set, skips reviewer dispatch for this run and appends a diagnostic line to STATUS Notes (`YYYY-MM-DD implement — skip-inline-review flag USED for wave <N>`).
  2. **New inline-review step** — insert between the existing "collect wave commits" step and the existing `git merge --no-ff` per-task loop step. The new step block contains:
     - **Dispatch** (R1, R9): in ONE orchestrator message, fire `3 × N_tasks` Agent tool calls — one per (task, axis) pair. Reviewers are `reviewer-security`, `reviewer-performance`, `reviewer-style` by name.
     - **Per-reviewer input** (R2, D5): task branch diff (`git diff <slug>...<slug>-T<n>`), PRD R-ids linked to the task (read from this `06-tasks.md`), and that's it. NOT the whole repo, NOT the whole feature diff.
     - **Aggregator** (D2): pure-bash `while read | case` loop that parses each reviewer's D1 verdict footer. Classifier emits exactly ONE of `wave:BLOCK | wave:NITS | wave:PASS` on stdout. No mutation inside the classifier; all mutation lives in the dispatch `case` below it.
     - **Dispatch** (R4): on `wave:BLOCK`, halt the implement loop, write aggregated per-task findings to STATUS Notes, surface the blocking tasks with recovery command `/specflow:implement <slug> --task T<n>`, and do NOT run the `git merge --no-ff` per-task loop. On `wave:NITS`, proceed with the merge loop BUT append a `## Reviewer notes` section to the wave-merge commit body per R6 with one line per finding grouped by task. On `wave:PASS`, proceed silently as today.
  3. **Retry semantics** (R5 / D6) — when developer re-runs a flagged task (`--task T<n>`), orchestrator MUST re-invoke all 3 reviewers on the new commit, not just the reviewer that flagged. Classify the new state from scratch; no shortcut based on prior verdicts.
  4. **Error posture** (tech-doc §4, PRD §6 edge-case #1) — missing or malformed verdict footer → treat entire reviewer result as BLOCK (fail-loud). Rubric file malformed → the reviewer agent returns PASS with diagnostic per its own contract (fail-safe at the agent boundary; orchestrator does not special-case this).
  5. **`--skip-inline-review` flag handling** (R7 / D11) — if the flag is set, skip the entire inline-review step (no reviewer dispatch, no aggregator). Append diagnostic line to STATUS Notes so the skip is visible in archive.
  6. **Where NOT to put the step** — do NOT put it after the per-task merge; the entire point of R1 is pre-merge blocking. Do NOT gate on it via a feature flag other than `--skip-inline-review`. Do NOT read the whole feature diff (that's `/specflow:review`'s contract).
- **NOT changed**: other specflow commands (`tasks.md`, `plan.md`, `archive.md`, etc.); developer-subagent files; reviewer agent files (T6–T8's job).
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`. No new files.
- **Verify**:
  - `grep -q -- '--skip-inline-review' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — flag documented.
  - `grep -q 'reviewer-security' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — all three reviewers named.
  - `grep -q 'reviewer-performance' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`.
  - `grep -q 'reviewer-style' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`.
  - `grep -q '## Reviewer verdict' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — D1 footer shape referenced.
  - Injection-point check — the inline-review step appears BEFORE any `git merge --no-ff` line in the prompt body: `awk '/inline.?review/{a=NR} /git merge --no-ff/{b=NR} END {exit !(a>0 && b>0 && a<b)}' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`.
  - `grep -q 'wave:BLOCK\|wave:NITS\|wave:PASS' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — aggregator emits the canonical state set.
  - Retry-reruns-all — `grep -q 'all 3 reviewers' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` (or the exact phrasing the Developer chose; spirit: retry re-runs all three).
  - Integration test t36 (T13) exits 0 once merged (deferred — T9 doesn't need to run t36 locally; gap-check will).
- **Depends on**: T6, T7, T8 (the agents it dispatches must exist before the command references them by name); implicitly T3–T5 (rubrics referenced via the agents).
- **Parallel-safe-with**: T10

  File-set check: T9 edits `.claude/commands/specflow/implement.md`; T10 creates a new file `.claude/commands/specflow/review.md`. Different files. No shared-file collision.
- [ ]

## T10 — `/specflow:review` one-shot command
- **Milestone**: M5
- **Requirements**: R8, R9, R10, R11, R12, R13
- **Decisions**: D1 (wire format), D3 (inline-duplicate aggregator — same classifier shape as D2, different dispatch: write report + exit code instead of merge-gate), D5 (feature-wide diff for one-shot), D10 (minute-granular filename + seconds + pid fallbacks on collision).
- **Scope**: Create a new file `.claude/commands/specflow/review.md` following the conventional shape of other specflow slash commands (frontmatter `description`, ordered `## Steps`, `## Failures`, `## Rules` sections). All shell pseudocode stays bash 3.2 / BSD userland portable.
  1. **Frontmatter** — `description: multi-axis review of a feature branch diff (security / performance / style); writes a timestamped report; never advances STATUS`. Document `--axis <security|performance|style>` flag for single-axis mode (R12).
  2. **Step — resolve feature dir** — if `.spec-workflow/features/<slug>/` exists, use it. Else if `.spec-workflow/archive/<slug>/` exists, use that path (archived feature support per PRD §6 edge case). Else fail with a clear error.
  3. **Step — resolve diff basis** — `git diff main...<slug>` for in-flight features; for archived features, the equivalent commit-range resolved via `git log` (deferred to Developer's judgement if needed, or accept that archived features may require an explicit diff basis). Full-feature diff, NOT chunked (D5). Reviewer decides its own chunking for large diffs.
  4. **Step — dispatch reviewers** (R9) — ONE orchestrator message with 3 Agent tool calls (or 1 under `--axis`). Each reviewer receives: the full feature-branch diff, its rubric path, the feature's `03-prd.md`, and its role team-memory invocation.
  5. **Step — aggregate verdicts** (D3) — inline duplicate of the D2 aggregator shape: pure-bash classifier that emits one of `review:BLOCK | review:NITS | review:PASS` on stdout. No mutation inside classifier. Dispatch writes the report file and sets exit code.
  6. **Step — report filename** (R10 / D10):
     - Default: `<feature-dir>/review-YYYY-MM-DD-HHMM.md`.
     - If exists: `<feature-dir>/review-YYYY-MM-DD-HHMMSS.md`.
     - If that also exists: `<feature-dir>/review-YYYY-MM-DD-HHMMSS-<pid>.md`.
     - NEVER clobber a prior report. This honors `no-force-on-user-paths` discipline for the report-write path.
  7. **Step — report body** — per-axis sections (Security / Performance / Style) each with the reviewer's verdict and findings quoted verbatim from the D1 footer. Top-level `## Consolidated verdict` block summarizing the aggregator output (`PASS | NITS | BLOCK`, count of findings per severity).
  8. **Step — exit code** (R13) — non-zero iff any reviewer returned BLOCK. Informational; never auto-gates any stage.
  9. **Step — STATUS Notes** (R11) — append ONE line per invocation (`YYYY-MM-DD review — <slug> axis=<all|...> verdict=<...>`). No checkbox mutation; stage checklist untouched.
  10. **`## Failures` section** — document: all-reviewers-timeout → non-zero exit + partial report; single reviewer timeout → partial report with missing axis marked; feature dir missing → fail loud with error.
  11. **`## Rules` section** — command is READ-PLUS-REPORT only; NEVER advances STATUS; NEVER halts any in-flight stage; works identically on in-flight and archived features.
- **NOT changed**: existing commands; STATUS handling conventions outside the single append line.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md`. No other files.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md`.
  - Frontmatter present — `head -1 /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md | grep -q '^---$'`.
  - Required sections — `grep -c '^## \(Steps\|Failures\|Rules\)' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` returns `3`.
  - Axis flag documented — `grep -q -- '--axis' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md`.
  - Three reviewers named — `grep -q 'reviewer-security' && grep -q 'reviewer-performance' && grep -q 'reviewer-style'` on the file.
  - Report filename template — `grep -q 'review-.*-.*-.*\.md' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` (some form of timestamp pattern).
  - Never-advances-STATUS spelled out — `grep -qi 'never advance\|never advances' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md`.
  - Integration test t37 (T14) exits 0 once merged (deferred).
- **Depends on**: T6, T7, T8.
- **Parallel-safe-with**: T9
- [ ]

---

## T11 — Test: `test/t34_reviewer_verdict_contract.sh`
- **Milestone**: M6
- **Requirements**: R24 (contract-shape test per reviewer agent); covers AC-verdict-shape.
- **Decisions**: D1 (verdict footer is the contract under test); `.claude/rules/bash/sandbox-home-in-tests.md`.
- **Scope**: Create `test/t34_reviewer_verdict_contract.sh` — contract-shape unit test per reviewer agent. Structure:
  1. **Sandbox header** — mktemp + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + case-pattern preflight (`case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac`). NON-NEGOTIABLE.
  2. For each axis in `security performance style`:
     - Construct a canonical D1 verdict-footer fixture (the exact shape from the agent file's output contract section) containing ONE finding with all required keys (`severity`, `file`, `line`, `rule`, `message`).
     - Parse it with the same awk/grep logic the D2 aggregator uses (aggregator lives in `implement.md` — pull the pseudocode inline, or duplicate the parse pattern in the test).
     - Assert the parsed result has `verdict` in `{PASS, NITS, BLOCK}`.
     - Assert the parsed result has `findings` as a list of zero or more entries.
     - Assert each finding has all 5 required keys.
  3. Also assert a ROUND-TRIP through severity classification: a fixture with one `must` finding classifies to `BLOCK`; with one `should` only classifies to `NITS`; with zero findings classifies to `PASS`.
  4. Print `PASS` / exit 0 on success; `FAIL: <axis>: <reason>` / exit 1 on any miss.
  5. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` (exec bit set). No edits to `smoke.sh` — registration is T16's job per single-editor discipline.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` — syntax clean.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` — exec bit set.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` exits 0 (runs standalone; no dependency on implement.md or review.md — this is a pure parser contract test).
- **Depends on**: T6, T7, T8 (agent files must exist so the test can reference their output-contract sections when building fixtures).
- **Parallel-safe-with**: T12, T13, T14, T15

  File-set check: T11 creates one new test file. T12–T15 each create their own new test file. Disjoint. No smoke.sh edits here.
- [ ]

## T12 — Test: `test/t35_reviewer_rubric_schema.sh`
- **Milestone**: M6
- **Requirements**: R18, R19, R20, R21; covers AC-rubric-files-exist.
- **Decisions**: sandbox-HOME template; schema conformance against `.claude/rules/README.md`.
- **Scope**: Create `test/t35_reviewer_rubric_schema.sh` — rubric file schema test. Structure:
  1. Sandbox header (same preflight as T11).
  2. For each rubric file `security.md`, `performance.md`, `style.md` under `.claude/rules/reviewer/`:
     - Assert file exists.
     - Extract frontmatter via the B1 awk pattern (`awk '/^---$/{c++; next} c==1{print} c==2{exit}'`); assert 5 required keys present (`name`, `scope`, `severity`, `created`, `updated`).
     - Assert `scope: reviewer`.
     - Assert `name` matches filename stem.
     - Assert `## Rule`, `## Why`, `## How to apply`, `## Example` body headings present IN THAT ORDER (grep with line numbers and sort check).
     - Assert `## How to apply` section contains ≥ 6 checklist entries (numbered or bulleted).
  3. Print `PASS` / exit 0 on success; `FAIL: <file>: <reason>` / exit 1 on miss.
  4. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh` (exec bit set).
- **Verify**:
  - Syntax clean; exec bit set.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh` exits 0 (requires T3–T5 merged).
- **Depends on**: T3, T4, T5 (rubric files must exist for the test to pass green; red-first authoring is fine in parallel worktrees).
- **Parallel-safe-with**: T11, T13, T14, T15
- [ ]

## T13 — Test: `test/t36_inline_review_integration.sh`
- **Milestone**: M6
- **Requirements**: R25; covers AC-integration-block-and-retry, AC-block-on-must, AC-retry-reruns-all, AC-advisory-logs, AC-skip-flag-works.
- **Decisions**: D2 (aggregator under test), D6 (retry re-runs all 3), D11 (skip-flag behavior); sandbox-HOME rule.
- **Scope**: Create `test/t36_inline_review_integration.sh` — inline-review integration test (sandboxed). Structure:
  1. Sandbox header + preflight.
  2. Seed a sandbox git worktree: `cd "$SANDBOX"; git init -q; git checkout -q -b fake-feature-20260418; git config user.email t@example.com; git config user.name t`. Create `.spec-workflow/features/fake-feature-20260418/` with minimal `03-prd.md`, `06-tasks.md`, and `STATUS.md` (with `## Notes` heading).
  3. Create two fake task branches: `fake-feature-20260418-T1` with an intentional `must`-severity violation (e.g., a commented-out code block per style rubric entry 2, or a hardcoded path per security rubric entry 2); `fake-feature-20260418-T2` with a clean diff.
  4. **Scenario A — BLOCK halts merge**:
     - Simulate inline-review dispatch: call the aggregator pseudocode from `implement.md` against pre-made reviewer output fixtures (fixtures simulate a D1 footer with one `must` finding on T1, PASS on T2).
     - Assert the aggregator classifies to `wave:BLOCK`.
     - Assert NO `git merge --no-ff` command was invoked (check via process trace or a stubbed merge wrapper).
     - Assert STATUS Notes contains a line documenting the BLOCK.
  5. **Scenario B — retry re-runs all 3**:
     - Simulate developer fix on T1 (amend commit).
     - Simulate orchestrator retry dispatch: assert the retry fires 3 reviewer invocations (all axes), not 1.
     - Assert aggregator now classifies to `wave:PASS`; assert merge proceeds.
  6. **Scenario C — NITS merge with notes** (AC-advisory-logs):
     - Fresh sandbox; reviewer fixture returns one `should` finding, no `must`.
     - Assert aggregator classifies to `wave:NITS`.
     - Assert the merge commit body contains a `## Reviewer notes` section with the finding (check via `git log -1 --pretty=%B` after merge).
  7. **Scenario D — --skip-inline-review** (AC-skip-flag-works):
     - Fresh sandbox; invoke implement pseudocode with the flag set.
     - Assert zero reviewer invocations.
     - Assert STATUS Notes contains the skip diagnostic line.
  8. Print `PASS` / exit 0 on all scenarios passing; `FAIL: <scenario>: <reason>` / exit 1 on first miss.
  9. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t36_inline_review_integration.sh` (exec bit set).
- **Verify**:
  - Syntax clean; exec bit set.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t36_inline_review_integration.sh` exits 0 (requires T9 merged for the aggregator pseudocode; red-first pre-T9-merge is acceptable in worktree).
- **Depends on**: T9 (aggregator under test lives in `implement.md`).
- **Parallel-safe-with**: T11, T12, T14, T15
- [ ]

## T14 — Test: `test/t37_review_oneshot.sh`
- **Milestone**: M6
- **Requirements**: R26; covers AC-review-*, in particular AC-review-report-written, AC-review-no-clobber, AC-review-axis-flag, AC-review-no-stage-advance, AC-review-exit-code.
- **Decisions**: D3 (one-shot aggregator), D10 (filename collision fallbacks); sandbox-HOME rule.
- **Scope**: Create `test/t37_review_oneshot.sh` — one-shot command integration test. Structure:
  1. Sandbox header + preflight.
  2. Seed a sandbox feature dir under `.spec-workflow/features/fake-slug/` with a minimal `03-prd.md` and a pre-made diff blob (fake git history not strictly required if the test stubs the diff source).
  3. **Scenario A — full-axis report written** (AC-review-report-written):
     - Invoke the `/specflow:review fake-slug` pseudocode with all 3 axes.
     - Assert a file matching `review-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}\.md` exists under the feature dir.
     - Assert the file contains 3 per-axis sections (one each for Security, Performance, Style) AND a top-level `## Consolidated verdict` block.
  4. **Scenario B — no-clobber** (AC-review-no-clobber):
     - Immediately invoke again (same minute).
     - Assert a SECOND distinct file exists (collision fallback kicks in — either `-HHMMSS.md` suffix per D10 tier 2, or `-HHMMSS-<pid>.md` per tier 3).
     - Assert the first file is byte-identical to its pre-second-invocation state.
  5. **Scenario C — single-axis mode** (AC-review-axis-flag):
     - Invoke with `--axis security`.
     - Assert the resulting report contains ONLY the Security section (no Performance or Style sections).
  6. **Scenario D — no-stage-advance** (AC-review-no-stage-advance):
     - Snapshot STATUS.md's stage checklist before invocation.
     - Invoke `/specflow:review`.
     - Assert stage checklist is byte-identical after.
  7. **Scenario E — exit code on BLOCK** (AC-review-exit-code):
     - Seed reviewer fixture to return BLOCK.
     - Invoke; assert non-zero exit.
     - Seed reviewer fixture to return PASS; invoke; assert zero exit.
  8. Print `PASS` / exit 0 on all scenarios; `FAIL: <scenario>: <reason>` / exit 1 on miss.
  9. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` (exec bit set).
- **Verify**:
  - Syntax clean; exec bit set.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` exits 0 (requires T10 merged).
- **Depends on**: T10.
- **Parallel-safe-with**: T11, T12, T13, T15
- [ ]

## T15 — Test: `test/t38_hook_skips_reviewer.sh`
- **Milestone**: M6
- **Requirements**: R27; covers AC-reviewer-not-in-digest.
- **Decisions**: D7 (hook skip under test); sandbox-HOME rule.
- **Scope**: Create `test/t38_hook_skips_reviewer.sh` — SessionStart hook skip verification. Structure:
  1. Sandbox header + preflight.
  2. Set up a sandbox repo mirror that contains a populated `.claude/rules/reviewer/` dir with the M2 rubric files (copy from the real repo at test time: `cp -r /Users/yanghungtw/Tools/spec-workflow/.claude/rules "$SANDBOX/rules_snapshot"`). Also copy the hook `session-start.sh`. Do NOT invoke the real hook against the real `$HOME`.
  3. Force lang-heuristic to match (so `bash`/`markdown` would normally walk): `cd "$SANDBOX" && mkdir -p repo && cd repo && git init -q && touch test.sh test.md && git add . && git commit -qm init`.
  4. Invoke the hook: `bash "$SANDBOX/session-start.sh" </dev/null 2>/dev/null 1>stdout.log`.
  5. **Assertion A** — hook exits 0.
  6. **Assertion B** — `grep -c 'reviewer/' stdout.log` returns EXACTLY `0`. No file under `reviewer/` mentioned in the digest.
  7. **Assertion C** — `grep -c '\[' stdout.log` returns ≥ 1 (sanity: the digest DID emit rules from `common/`, so the hook isn't broken in the opposite direction).
  8. **Assertion D** — B1 hook happy path still works: re-invoke with a non-populated reviewer subdir; assert existing `common/` rules still emitted.
  9. Print `PASS` / exit 0 on all assertions; `FAIL: <step>: <reason>` / exit 1 on miss.
  10. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` (exec bit set).
- **Verify**:
  - Syntax clean; exec bit set.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` exits 0 (requires T2 merged for the hook patch; T3–T5 merged for populated reviewer dir).
- **Depends on**: T2, T3, T4, T5.
- **Parallel-safe-with**: T11, T12, T13, T14
- [ ]

---

## T16 — Smoke integration + README docs + dogfood diagnostic
- **Milestone**: M7
- **Requirements**: R28; covers AC-smoke-green, AC-no-regression, PRD §6 edge-case #5 (dogfood paradox docs).
- **Decisions**: Plan §5 "M7 bundle" (single-task serial per B2.a precedent — avoids 5-way smoke.sh append collision); D6/D7 testing-strategy sign-off.
- **Scope**: Three coordinated edits, bundled into a single serial task to eliminate append-collision risk against the T11–T15 test-file creations:
  1. **`test/smoke.sh` — register t34–t38** (R28 / AC-smoke-green): extend the smoke driver to register the five new test scripts after the existing 33. Follow the current registration pattern (append rows; do not renumber). Final expected tally: ≥ 38/38. The existing B1+B2.a tests (t1–t33) must remain intact.
  2. **Top-level `README.md` — document the feature**: add a short paragraph (placement up to Developer — near the existing harness docs if they exist, else a new "Review capability" section). Must mention:
     - `/specflow:implement` now includes inline multi-axis review (security / performance / style) between wave collection and per-task merge.
     - `/specflow:review <slug>` is a new one-shot command that produces timestamped reports without advancing any stage.
     - Rubrics live under `.claude/rules/reviewer/` and are NOT session-loaded (agent-triggered only).
     - `--skip-inline-review` is the emergency escape hatch; uses are logged to STATUS Notes.
  3. **STATUS Notes dogfood-paradox diagnostic**: append a note to this feature's `STATUS.md` explicitly documenting that this feature's own `/specflow:implement` runs execute under `--skip-inline-review` (bootstrapping — the reviewers and rubrics are landing in this feature's waves). First real use of inline review is the next feature after B2.b.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh`, `/Users/yanghungtw/Tools/spec-workflow/README.md`, and `/Users/yanghungtw/Tools/spec-workflow/.spec-workflow/features/20260418-review-capability/STATUS.md`. Zero new files.
- **Verify**:
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` exits 0; output includes PASS lines for t34–t38; final tally ≥ 38.
  - `grep -q '/specflow:review' /Users/yanghungtw/Tools/spec-workflow/README.md` — new command documented.
  - `grep -q 'reviewer' /Users/yanghungtw/Tools/spec-workflow/README.md` — review capability mentioned.
  - `grep -q -- '--skip-inline-review' /Users/yanghungtw/Tools/spec-workflow/README.md` — escape hatch documented.
  - `grep -q 'dogfood' /Users/yanghungtw/Tools/spec-workflow/.spec-workflow/features/20260418-review-capability/STATUS.md` (or equivalent paradox note).
  - B1+B2.a regression — all 33 pre-feature tests still green (implicit in the smoke-0 above).
- **Depends on**: T11, T12, T13, T14, T15 (all five test files must exist to register); T9, T10 (commands must exist for README to describe accurately).
- **Parallel-safe-with**: —
- [ ]

---

## Sequencing notes

- **T1 and T2 are independent** — different files (`.claude/rules/README.md` + a new `.gitkeep` vs `.claude/hooks/session-start.sh`). Parallel-safe as Wave 1.
- **T3–T5 (three rubric files) and T6–T8 (three agent files)** are six distinct files across two directories. All six can run in Wave 2 with zero shared-file interference beyond the expected append-only collisions on `.claude/rules/index.md` (T3/T4/T5 each append one row) and on STATUS Notes (every task appends). These collisions are **mechanically resolvable keep-both** per `tpm/parallel-safe-append-sections.md` — do NOT over-serialize on these grounds.
- **T9 and T10** edit/create different command files (`implement.md` vs new `review.md`). Parallel-safe as Wave 3.
- **T11–T15** each create their own new `test/tNN_*.sh` file. Five distinct files, zero shared-file surface among them. TDD-compatible: tests can be written red-first alongside their dependencies (`t34` independent of T9/T10 because it's a parser contract test; `t35` needs T3–T5 merged to go green; `t36` needs T9; `t37` needs T10; `t38` needs T2 + T3–T5). Authoring happens in Wave 4; green runs require prior waves merged.
- **T16 serializes after everything** — edits `test/smoke.sh` (single registration editor — avoids append-collisions with T11–T15 per plan §5 / B2.a precedent), `README.md`, and STATUS.md. Depends on T9–T15 having landed. Size-1 Wave 5 is intentional.
- **Known mechanical append collisions** (per `tpm/parallel-safe-append-sections.md`):
  - `.claude/rules/index.md`: T3/T4/T5 each append one row → 3-way append collision; mechanical keep-both.
  - `STATUS.md` Notes: every task appends a completion note → standard keep-both across waves 1–5.
  - `06-tasks.md` checkbox flips: wave 2 is 6-way parallel and WILL drop some `[ ]` → `[x]` flips during merge per `tpm/checkbox-lost-in-parallel-merge.md`. Orchestrator MUST run `grep -c '^- \[x\]' 06-tasks.md` post-merge and commit `fix: check off T<n> (lost in merge)` as needed. B1 (lost T4+T15) and B2.a (lost T1+T2) precedents make this predictable; automate the audit.
- **Worktree safety** — tests that depend on specific merged artifacts (t35/T12 needs T3–T5; t36/T13 needs T9; t37/T14 needs T10; t38/T15 needs T2 + T3–T5) will run RED in isolated pre-merge worktrees. This is expected TDD discipline; the tests go GREEN once the wave they depend on is merged into the feature branch. Gap-check verifies end-to-end greenness after all waves land.

## Task sizing

Target: each task ≤ 60 min focused work.
- **T1** — 3-site markdown edit + empty directory creation. ~15 min.
- **T2** — one-line variable declaration + 3-line `case` skip guard inside an existing loop. ~15 min; the care is in running B1 regression tests (t17/t18 from B1) to confirm no fail-safe regression.
- **T3–T5 (three rubric files)** — each is a standard rule-file authoring task with 8 checklist entries + example + index row. ~25–35 min per file. The second and third are faster due to uniform shape.
- **T6–T8 (three agent files)** — each is a D10 six-block core template with two when-invoked sections + stay-in-lane literal + D1 output contract. Reference shape is `qa-analyst.md`. ~30–40 min per file; consistent template speeds up siblings.
- **T9 (implement.md edit)** — the largest single task. Multi-site edit to a command prompt with aggregator pseudocode, retry semantics, NITS-notes-in-commit-body, and the opt-out flag. ~50–60 min. Single-file discipline is non-negotiable per the plan's sequencing analysis.
- **T10 (review.md new file)** — new command prompt with aggregator duplicate, collision fallback filename, per-axis report structure, exit-code dispatch. ~40–50 min.
- **T11–T15 (five test files)** — each ~25–40 min of sandbox scaffolding + fixtures + scenarios + asserts. t36 and t37 are the heaviest (multi-scenario integration tests); t34 and t38 are smallest.
- **T16 (smoke + README + STATUS)** — ~20–30 min; five smoke registrations + README paragraph + STATUS note.

---

## STATUS Notes

_(populated by Developer as tasks complete; expected mechanical append-collisions on this section are resolved keep-both per `tpm/parallel-safe-append-sections.md`)_

- 2026-04-17 T1 DONE — scope enum admits `reviewer`; dir `.claude/rules/reviewer/` seeded with `.gitkeep`; all 4 verify checks PASS.
- 2026-04-18 T3 DONE — `.claude/rules/reviewer/security.md` created (8-entry checklist, cross-refs no-force-on-user-paths + classify-before-mutate); index row appended; all 7 verify checks PASS.
- 2026-04-18 T4 DONE — `.claude/rules/reviewer/performance.md` created; index.md row appended; all 6 verify checks PASS.
- 2026-04-18 T5 DONE — `.claude/rules/reviewer/style.md` created (8 checklist entries, scope=reviewer, 2 cross-refs); index.md row appended; all verify checks PASS.

---

## Wave schedule

- **Wave 1 (2 parallel)**: T1, T2
- **Wave 2 (6 parallel)**: T3, T4, T5, T6, T7, T8
- **Wave 3 (2 parallel)**: T9, T10
- **Wave 4 (5 parallel)**: T11, T12, T13, T14, T15
- **Wave 5 (1 serial)**: T16

**Parallel-safety analysis per wave:**

- **Wave 1 (2-wide)** — Files:
  - T1: `.claude/rules/README.md` (3 sites) + new `.claude/rules/reviewer/.gitkeep`.
  - T2: `.claude/hooks/session-start.sh` (one variable declaration + one skip-guard insertion).

  Disjoint file sets. T2's manual dry-run verify step touches the `reviewer/` directory T1 creates, but this happens after T1 merges; sequencing inside the wave resolves cleanly. Expected append-only collisions on `06-tasks.md` STATUS Notes when each task ticks its box — resolve mechanically keep-both per `tpm/parallel-safe-append-sections.md`. No other shared files.

- **Wave 2 (6-wide)** — Files:
  - T3: new `.claude/rules/reviewer/security.md` + append one row to `.claude/rules/index.md`.
  - T4: new `.claude/rules/reviewer/performance.md` + append one row to `.claude/rules/index.md`.
  - T5: new `.claude/rules/reviewer/style.md` + append one row to `.claude/rules/index.md`.
  - T6: new `.claude/agents/specflow/reviewer-security.md`.
  - T7: new `.claude/agents/specflow/reviewer-performance.md`.
  - T8: new `.claude/agents/specflow/reviewer-style.md`.

  All six new files are disjoint. The ONE shared file is `.claude/rules/index.md`, appended by T3/T4/T5 — 3-way append-only collision. Per `tpm/parallel-safe-append-sections.md`, this is the MAY-stay-parallel case: each task adds a new row at the end of the table; mechanical keep-both resolves cleanly. Expected append collisions also on `STATUS.md` Notes and on `06-tasks.md` checkbox flips.

  **Checkbox-flip audit required** (per `tpm/checkbox-lost-in-parallel-merge.md`): this 6-wide wave is precisely the width where B1 (7-wide, lost T4 + T15) and B2.a (7-wide, lost T1 + T2) dropped checkbox flips during merge. Orchestrator MUST run `grep -c '^- \[x\]' 06-tasks.md` after Wave 2 merges and commit `fix: check off T<n> (lost in merge)` to flip any silently-dropped boxes.

  Test isolation: n/a — no tests run in this wave. Shared infrastructure: index.md (append-only, resolved).

- **Wave 3 (2-wide)** — Files:
  - T9: `.claude/commands/specflow/implement.md` (single-file multi-site edit).
  - T10: new `.claude/commands/specflow/review.md`.

  Disjoint files. No shared-file collision except the standard STATUS Notes append.

- **Wave 4 (5-wide)** — Files:
  - T11: new `test/t34_reviewer_verdict_contract.sh`.
  - T12: new `test/t35_reviewer_rubric_schema.sh`.
  - T13: new `test/t36_inline_review_integration.sh`.
  - T14: new `test/t37_review_oneshot.sh`.
  - T15: new `test/t38_hook_skips_reviewer.sh`.

  All five new files are disjoint. NO edits to `test/smoke.sh` in this wave — registration is deferred to T16 per the single-editor convention. Test isolation: each test uses its own `mktemp -d` sandbox per the sandbox-HOME rule; no shared `/tmp` paths, no shared fixtures, no shared ports. Expected append collisions on `06-tasks.md` STATUS Notes / checkbox flips — same post-merge audit as Wave 2.

- **Wave 5 (size 1)** — T16 edits `test/smoke.sh` (sole registration editor by design), `README.md`, and this feature's `STATUS.md`. Depends on T9–T15 having landed. Size-1 is intentional per plan §5 / B2.a precedent to avoid append-collision on `smoke.sh` across multiple editors. No parallelism lost — the task is small.

**Total tasks**: 16. **Total waves**: 5. Wave widths: `2, 6, 2, 5, 1`. Widest wave: Wave 2 (6-wide), narrower than B1/B2.a's 7-wide widest — no new process risk vs. prior features.
