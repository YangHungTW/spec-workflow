---
description: Run all remaining waves in parallel until done or blocked. Usage: /scaff:implement <slug> [--one-wave] [--task T<n>] [--serial] [--skip-inline-review] [--inline-review]
---

Wave-based parallel execution. Default behaviour: run **every remaining wave** end-to-end, stopping only on task failure, merge conflict, or user interrupt. TPM's dependency graph is the plan — no reason to pause between healthy waves.

`--skip-inline-review` — bypasses reviewer dispatch entirely for this run (emergency / debug / dogfood-paradox use only). Every use is logged to STATUS Notes as `YYYY-MM-DD implement — skip-inline-review flag USED for wave <N>` so the skip is visible in the archive. Default is OFF (inline review runs), EXCEPT on `tiny`-tier features where the default is to skip (R16).

`--inline-review` — opt in to inline review on a `tiny`-tier feature. On `standard` and `audited`, inline review runs by default; this flag is a no-op on those tiers.

## Steps

1. Locate task file:
   ```bash
   TASK_FILE="$feature_dir/05-plan.md"
   if [ ! -f "$TASK_FILE" ] || ! grep -q '^- \[ \]' "$TASK_FILE" 2>/dev/null; then
     echo "ERROR: 05-plan.md missing or has no task checklist" >&2
     exit 2
   fi
   ```
   Parse the **Tasks** list and **Wave schedule** from `$TASK_FILE`.
2. **Select mode**:
   - `--task T<n>` → run only that task (debug / retry single task in its own worktree).
   - `--serial` → run the next unchecked task serially in the main working tree (fallback if worktrees aren't usable).
   - `--one-wave` → run just the next wave, then stop and report.
   - Default: loop waves until all tasks done or something stops us.
3. **Pre-flight** (once, before the loop):
   - Verify git repo. If not, fall back to `--serial`.
   - Ensure feature branch `<slug>` exists; create from current HEAD if missing.
   - Confirm clean working tree.
   - Ensure `.worktrees/` is in `.gitignore`.

## Per-wave loop

4. Identify the **current wave** = first wave whose tasks are all either checked OR unchecked-with-all-deps-checked.
5. **Spawn parallel developers**:
   - For each task T<n> in the wave:
     - `git worktree add .worktrees/<slug>-T<n> -b <slug>-T<n> <slug>` (note branch name: `<slug>-T<n>`, flat — **not** `<slug>/T<n>`, which collides with the `<slug>` leaf ref)
     - Invoke **scaff-developer** subagent with parameters `WORKTREE`, `TASK_ID`, `SLUG`.
     - All developer invocations in **one message with multiple Agent tool calls** → concurrent execution.
6. **Wave collection** (after all developers return):
   - `git checkout <slug>`
   - All developer branches are now ready (`<slug>-T<n>`); do NOT merge yet.
7. **Inline review** (pre-merge gate):

   **Tier-based default (R16):** Before dispatching reviewers, resolve the feature tier:
   ```bash
   source "$REPO_ROOT/bin/scaff-tier"
   FEATURE_TIER="$(get_tier "$feature_dir")"
   ```
   Determine whether inline review runs for this wave:
   - If `--inline-review` flag is set → always run inline review (opt-in for tiny).
   - Else if `--skip-inline-review` flag is set → skip inline review (emergency bypass).
   - Else if `FEATURE_TIER = tiny` → default to skip (R16); log and skip to step 8.
   - Else → run inline review (default for standard and audited).

   If skipping: append `YYYY-MM-DD implement — skip-inline-review USED for wave <N> (reason: <tiny-default|flag>)` to STATUS Notes and skip to step 8.

   Otherwise:

   **7a. Dispatch reviewers** — in a single orchestrator message, fire `3 × N_tasks` Agent tool calls (one per task-axis pair) — all parallel:
   - For each completed task T<n>, spawn three reviewer subagents:
     - `reviewer-security` — security axis
     - `reviewer-performance` — performance axis
     - `reviewer-style` — style axis
   - Each reviewer receives **only**:
     - The task-local diff: `git diff <slug>...<slug>-T<n>`
     - The PRD R-ids linked to that task (read from `$TASK_FILE`, `Requirements:` field)
     - Its rubric path (`.claude/rules/reviewer/<axis>.md`) — the reviewer loads this itself per its own instructions
   - Do NOT pass the whole-repo contents or the whole-feature diff. Per D5, task-local context only for inline review.
   - Log to STATUS Notes: `YYYY-MM-DD review dispatched — slug=<slug> wave=<N> tasks=<T1,T2,...> axes=security,performance,style`

   **7b. Aggregate verdicts** (pure classifier — no mutation here; apply classify-before-mutate rule):

   After all `3 × N_tasks` reviewers return, invoke `bin/scaff-aggregate-verdicts` with the
   `security performance style` axis-set and the scratch dir holding the reviewer output files.
   The CLI emits the aggregated verdict (`PASS`, `NITS`, or `BLOCK`) on stdout line 1, and
   optionally `suggest-audited-upgrade: security` on line 2 when a security-axis `must`-severity
   finding is present (tech §4.3). All mutation (merge or halt) lives in step 7c, not here.

   ```bash
   # Invoke the extracted aggregator CLI (bin/scaff-aggregate-verdicts).
   # Input:  $VERDICT_DIR — scratch dir where each reviewer's raw output was written
   #         as <task>-<axis>.txt before this block runs.
   # Output: $WAVE_STATE        — wave:PASS | wave:NITS | wave:BLOCK (consumed by step 7c)
   #         $SUGGEST_AUDITED_UPGRADE — non-empty when aggregator emits suggest-audited-upgrade
   #         (tech §4.3: step 7c invokes set_tier on this signal; see dispatch block below)

   AGG_OUTPUT="$(bin/scaff-aggregate-verdicts security performance style \
     --dir "$VERDICT_DIR")"
   AGG_VERDICT="$(printf '%s\n' "$AGG_OUTPUT" | head -1)"
   WAVE_STATE="wave:$AGG_VERDICT"

   SUGGEST_AUDITED_UPGRADE=""
   case "$AGG_OUTPUT" in
     *suggest-audited-upgrade:*)
       SUGGEST_AUDITED_UPGRADE="$(printf '%s\n' "$AGG_OUTPUT" \
         | grep '^suggest-audited-upgrade:' | head -1)"
       ;;
   esac
   ```

   **7c. Dispatch on wave state** (mutation lives here, not in the classifier above):

   - **Security-must auto-upgrade** — if `$SUGGEST_AUDITED_UPGRADE` is non-empty, invoke
     `set_tier` immediately and unconditionally before any other dispatch arm runs:
     ```bash
     if [ -n "$SUGGEST_AUDITED_UPGRADE" ]; then
       # Derive task id from the suggest-audited-upgrade signal for the audit reason.
       # Sanitise: strip prefix, restrict to safe chars [A-Za-z0-9._-], bound to 64 chars
       # (reviewer-supplied external data must be validated at the boundary — security rule 3).
       UPGRADE_TASK="$(printf '%s\n' "$SUGGEST_AUDITED_UPGRADE" \
         | sed 's/^suggest-audited-upgrade: *//' \
         | tr -cd 'A-Za-z0-9._-' \
         | cut -c1-64)"
       set_tier "$feature_dir" audited "security-must finding in ${UPGRADE_TASK}"
       # set_tier writes the R13 audit line to STATUS Notes automatically
     fi
     ```
     No confirmation required; this is the immediate auto-upgrade path (PRD R14 bullet 2).
     If `tier` is already `audited`, `set_tier` is a no-op (idempotent; valid self-transition
     is handled by the helper).

   - **`wave:BLOCK`** — do NOT run the `git merge --no-ff` loop:
     1. Write per-task findings to STATUS Notes: `YYYY-MM-DD review result — wave <N> verdict=BLOCK blocking-tasks=<list>`
     2. For each blocked task, surface the findings and the recovery command: `/scaff:implement <slug> --task T<n>`
     3. STOP the implement loop. Do not proceed to step 8 or 9.
     4. Leave the `<slug>-T<n>` branches and worktrees intact so the developer can inspect them.

   - **`wave:NITS`** — proceed with the merge loop (step 8) but with enriched commit messages:
     1. Log to STATUS Notes: `YYYY-MM-DD review result — wave <N> verdict=NITS`
     2. For each task merge commit, append a `## Reviewer notes` section to the commit body listing all `should`/`advisory` findings for that task, grouped by axis.

   - **`wave:PASS`** — proceed silently with the merge loop (step 8).

8. **Merge loop** (runs only when wave state is `wave:NITS` or `wave:PASS`):
   - For each completed task (any order):
     - `git merge --no-ff <slug>-T<n> -m "Merge T<n>: <title>[## Reviewer notes section if NITS]"`
     - On conflict: STOP the whole loop. Surface conflicting files. TPM's parallel-safety analysis was wrong → recommend `/scaff:update-task`.
     - `git worktree remove .worktrees/<slug>-T<n>`
     - `git branch -d <slug>-T<n>`
9. **Status update** (orchestrator):
   - In main tree, check off `[x]` for every completed task in `$TASK_FILE`.
   - Append STATUS Notes: `YYYY-MM-DD implement wave <N> done — T<a>, T<b>, …`.
   - Commit: `wave <N>: check off completed tasks`.

   **Threshold check (D7, R14)** — after the wave-merge commit, before starting the next wave:
   ```bash
   # Resolve BASE once per wave (merge-base of feature branch with main)
   BASE="$(git merge-base HEAD main)"

   # Single git diff --shortstat — one fork derives both file count and line count
   # (performance rule 3: cache expensive operations; no separate --name-only call)
   read -r diff_files diff_lines <<EOF
$(git diff --shortstat "$BASE...HEAD" | awk '{files=$1; s+=$4+$6} END {print files+0, s+0}')
EOF

   # FEATURE_TIER set at step 7 (line ~53); reuse here — no re-fork needed.
   if [ "$FEATURE_TIER" = "tiny" ]; then
     TIER_DIFF_LINES="${SPECFLOW_TIER_DIFF_LINES:-200}"
     TIER_DIFF_FILES="${SPECFLOW_TIER_DIFF_FILES:-3}"
     if [ "$diff_lines" -gt "$TIER_DIFF_LINES" ] || \
        [ "$diff_files" -gt "$TIER_DIFF_FILES" ]; then
       printf 'WARNING: tiny-tier feature exceeds threshold after wave %s: %s lines, %s files (limits: %s lines, %s files). TPM should confirm or upgrade tier via set_tier.\n' \
         "$WAVE_N" "$diff_lines" "$diff_files" "$TIER_DIFF_LINES" "$TIER_DIFF_FILES" >&2
       STATUS_NOTE="$(printf '%s implement — auto-upgrade SUGGESTED tiny→standard (diff: %s lines, %s files; threshold %s/%s); awaiting TPM confirmation\n' \
         "$(date '+%Y-%m-%d')" "$diff_lines" "$diff_files" "$TIER_DIFF_LINES" "$TIER_DIFF_FILES")"
       cp "$feature_dir/STATUS.md" "$feature_dir/STATUS.md.bak"
       { cat "$feature_dir/STATUS.md"; printf '%s\n' "$STATUS_NOTE"; } \
         > "$feature_dir/STATUS.md.tmp"
       mv "$feature_dir/STATUS.md.tmp" "$feature_dir/STATUS.md"
     fi
   fi
   ```
   Do NOT halt; continue running remaining waves. TPM acts via `set_tier` — not auto-promoted here.

10. **Continue or stop**:
    - If `--one-wave` → stop. Report current state + preview next wave.
    - If any task failed or merge conflicted → stop. Report failure + recovery command.
    - Else if more waves remain → loop to step 4 for the next wave.
    - Else all done → check `[x] implement` in STATUS, commit, tell user next is `/scaff:next <slug>`.

## Retry semantics

When a task is blocked by the review step and the developer re-runs it via `--task T<n>`:

1. The developer fixes the flagged issue and commits to `<slug>-T<n>`.
2. Orchestrator re-invokes **all 3 reviewers** on the new commit — not just the reviewer(s) that flagged originally.
3. The aggregator runs from scratch on the new verdicts. No shortcuts based on prior verdicts (D6: classify the new state fresh).
4. Max retries = 2 per task. If a task is still blocked after 2 retries, escalate to TPM via `/scaff:update-task`.

## Failures

- **One developer fails** → stop the wave loop immediately (other completed tasks in this wave still merged). Report which task failed + how to retry: `/scaff:implement <slug> --task T<n>`.
- **Merge conflict** → stop. Conflicts during a wave = TPM's parallel-safety analysis was wrong. Don't auto-resolve.
- **Interrupted mid-wave** → clean up any hanging worktrees before exiting.
- **Reviewer timeout or crash** → treat as BLOCK (fail-loud per D2 error posture). User can retry or invoke `--skip-inline-review`.
- **All reviewers blocked after 2 retries** → escalate to TPM. Do not bypass the reviewer step silently.

## Rules
- Never skip `Parallel-safe-with:` constraints.
- Never run two waves concurrently — wave N+1 depends on wave N's merged state.
- Clean up worktrees even on failure. No orphan `.worktrees/<slug>-T<n>/`.
- Branch naming: **flat** `<slug>-T<n>` to avoid colliding with the feature branch `<slug>` leaf ref.
- The reviewer step (step 7 above) fires before the per-task merge; the per-task merge command (`git merge --no-ff`) runs only after all reviewers return a non-blocking result.
- On `tiny`-tier features, inline review is OFF by default (R16); use `--inline-review` to enable it.
- The only legitimate bypass of the reviewer step on non-tiny features is `--skip-inline-review`.
- All other runs must complete the reviewer step without a BLOCK verdict before executing `git merge --no-ff`.
- Retry re-runs **all 3 reviewers**, never just the one that flagged. Prior verdict state is discarded; classify from scratch.
