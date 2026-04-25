---
description: Multi-axis review of a feature branch diff (security / performance / style); writes a timestamped report; never advances STATUS. Usage: /scaff:review <slug> [--axis security|performance|style]
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

Run a one-shot parallel review of a feature branch. Spawns security, performance, and style reviewer subagents (or a single axis via `--axis`), aggregates their verdicts, writes a timestamped report, and exits non-zero if any reviewer returned BLOCK. Never advances the STATUS stage checklist.

## Steps

1. **Parse args.**
   - `<slug>` is required. If missing, print usage and exit 2.
   - **Validate slug** against regex `^[a-z0-9][a-z0-9-]*$` — kebab-case, starts with letter/digit — before any filesystem or git operation. On mismatch emit an error to stderr and exit with status 2. Reject slugs starting with `-` (git flag risk) or containing `..`/`/`. POSIX `case`-glob (bash 3.2 portable; no `[[ =~ ]]`):
     ```
[a-z0-9][a-z0-9-]*$   ← allowed pattern (case-glob: [a-z0-9][a-z0-9-]*)
     ```
     ```sh
     case "$slug" in
       [a-z0-9][a-z0-9-]*) : ;;   # OK — kebab-case
       *) printf 'review: invalid slug "%s" (expected ^[a-z0-9][a-z0-9-]*$)\n' "$slug" >&2; exit 2 ;;
     esac
     ```
   - `--axis <security|performance|style>` is optional; if supplied, run only that single reviewer.

2. **Resolve feature dir.**
   - If `.specaffold/features/<slug>/` exists, use it as `FEATURE_DIR`.
   - Else if `.specaffold/archive/<slug>/` exists, use that path as `FEATURE_DIR`.
   - Else: print `ERROR: no feature dir found for slug '<slug>'` to stderr and exit 2.

3. **Resolve diff basis.**
   - For in-flight features (under `features/`): `git diff main...<slug>` produces the full feature-branch diff.
   - For archived features (under `archive/`): resolve the feature's commit range via `git log --format="%H" <slug>` and produce an equivalent diff. If the branch no longer exists, surface a clear error and exit 2. (Developer may supply an explicit diff basis as a fallback.)
   - Pass the full diff to each reviewer. Reviewers handle their own chunking for large diffs; do NOT pre-chunk here.

4. **Dispatch reviewers** — in ONE orchestrator message, fire Agent tool calls for all reviewers in parallel:
   - No `--axis`: invoke **reviewer-security**, **reviewer-performance**, and **reviewer-style** (3 parallel calls).
   - `--axis security`: invoke only **reviewer-security**.
   - `--axis performance`: invoke only **reviewer-performance**.
   - `--axis style`: invoke only **reviewer-style**.

   Each reviewer receives:
   - The full feature-branch diff (from step 3).
   - The path to its axis rubric: `.claude/rules/reviewer/<axis>.md`.
   - The feature's `03-prd.md` (full).
   - Its role team-memory invocation block.

5. **Aggregate verdicts (D3)** — collect all reviewer replies. Write each reply to a per-axis verdict file in a temp dir, then invoke the extracted aggregator CLI. The aggregator is the pure classifier; no mutation here:

   ```bash
   # Write each reviewer's raw output to its verdict file.
   # For single-axis runs, only the relevant file is written.
   VERDICT_DIR="$(mktemp -d)"
   # (orchestrator writes each reviewer reply to $VERDICT_DIR/<axis>.txt
   #  before the next line runs; one file per axis dispatched in step 4)

   # Invoke extracted aggregator — bash 3.2 portable argv-form invocation.
   AGG_OUTPUT="$(bin/scaff-aggregate-verdicts security performance style \
     --dir "$VERDICT_DIR")"
   AGG_VERDICT="$(printf '%s\n' "$AGG_OUTPUT" | head -1)"
   WAVE_STATE="review:${AGG_VERDICT}"
   rm -rf "$VERDICT_DIR"
   ```

   For single-axis runs (`--axis <axis>`), pass only the relevant axis name:

   ```bash
   AGG_OUTPUT="$(bin/scaff-aggregate-verdicts "$AXIS" --dir "$VERDICT_DIR")"
   AGG_VERDICT="$(printf '%s\n' "$AGG_OUTPUT" | head -1)"
   WAVE_STATE="review:${AGG_VERDICT}"
   rm -rf "$VERDICT_DIR"
   ```

   Dispatch:
   - `review:BLOCK` → write report (step 6), append STATUS Notes (step 9), exit 1.
   - `review:NITS`  → write report (step 6), append STATUS Notes (step 9), exit 0.
   - `review:PASS`  → write report (step 6), append STATUS Notes (step 9), exit 0.

   Error posture: the aggregator treats a missing or malformed verdict footer (no `## Reviewer verdict` heading, no `verdict:` line, or value outside `{PASS, NITS, BLOCK}`) as BLOCK and emits a diagnostic to stderr naming the offending file.

6. **Determine report filename (D10)** — never clobber a prior report:

   ```bash
   DATESTAMP="$(date +%Y-%m-%d-%H%M)"
   REPORT="$FEATURE_DIR/review-${DATESTAMP}.md"
   if [ -f "$REPORT" ]; then
     DATESTAMP="$(date +%Y-%m-%d-%H%M%S)"
     REPORT="$FEATURE_DIR/review-${DATESTAMP}.md"
     if [ -f "$REPORT" ]; then
       REPORT="$FEATURE_DIR/review-${DATESTAMP}-$$.md"
     fi
   fi
   ```

   The three tiers are: `review-YYYY-MM-DD-HHMM.md` → `review-YYYY-MM-DD-HHMMSS.md` → `review-YYYY-MM-DD-HHMMSS-<pid>.md`. The filename pattern documented here is `review-YYYY-MM-DD-HHMM.md` at the default tier.

7. **Write report.** Compose the report in memory; write atomically (write to `<REPORT>.tmp`, then rename to `<REPORT>`). Report structure:

   ```markdown
   # Review: <slug>
   Date: YYYY-MM-DD HH:MM
   Axis: <all | security | performance | style>

   ## Consolidated verdict
   Aggregate: <PASS | NITS | BLOCK>
   Findings: <N> must, <M> should, <K> advisory

   ## Security
   <Reviewer-security's full D1 verdict block quoted verbatim>

   ## Performance
   <Reviewer-performance's full D1 verdict block quoted verbatim>

   ## Style
   <Reviewer-style's full D1 verdict block quoted verbatim>
   ```

   For single-axis runs (`--axis`), include only the relevant per-axis section; omit the other two. The `## Consolidated verdict` block still appears at the top.

8. **Exit code (R13).**
   - Exit 1 if aggregate verdict is BLOCK (any reviewer returned BLOCK).
   - Exit 0 if aggregate verdict is PASS or NITS.
   - This exit code is informational and CI-friendly; it never auto-gates any stage.

9. **Append STATUS Notes (R11).** Append exactly one line to `$FEATURE_DIR/STATUS.md` under `## Notes`:
   ```
   YYYY-MM-DD review — <slug> axis=<all|security|performance|style> verdict=<PASS|NITS|BLOCK> report=<filename>
   ```
   Do NOT advance any stage checkbox. The stage checklist is untouched.

## Failures

- **All reviewers timeout or fail**: exit non-zero; write a partial report marking all axes as `ERROR: timeout/no-response`. The STATUS Notes line still appears with `verdict=ERROR`.
- **Single reviewer timeout**: write the report with the responding axes' verdicts and mark the timed-out axis as `ERROR: timeout`. Aggregate as BLOCK (fail-loud posture — missing reviewer result is indistinguishable from a suppressed finding).
- **Feature dir missing**: print `ERROR: no feature dir found for slug '<slug>'` to stderr; exit 2. Do not write any report or STATUS note.
- **Diff resolution fails** (e.g., archived feature branch no longer exists): print the git error to stderr; exit 2.
- **Report write fails** (e.g., disk full): print error to stderr; exit 1. STATUS Notes append is still attempted.

## Rules

- This command is READ-PLUS-REPORT only. It NEVER advances STATUS. The stage checklist (`implement`, `gap-check`, `verify`) is never touched.
- It NEVER halts or blocks any in-flight `/scaff:implement` wave. It is an independent, on-demand command.
- It works identically on in-flight features (under `.specaffold/features/`) and archived features (under `.specaffold/archive/`).
- Report files are never clobbered. The three-tier filename fallback (minute → seconds → pid) is the no-force-on-user-paths discipline applied to report files.
- All shell pseudocode in this command must be bash 3.2 / BSD userland portable: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic.
- The aggregator is a pure classifier: no mutation inside it. Mutation (report write, STATUS Notes append, exit code) lives strictly in the dispatch arms, not inside the classifier loop.
