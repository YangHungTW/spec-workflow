# Tasks — review-nits-cleanup

_2026-04-18 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R14), `04-tech.md` (D1–D6), `05-plan.md`
(M1–M7). Every task names the milestone, requirements, and decisions it
lands. `Verify` is a concrete runnable command (or filesystem check) the
Developer runs at the end of the task; if it passes, the task is done.

All paths below are absolute under `/Users/yanghungtw/Tools/spec-workflow/`.

---

## T1 — R1 slug validator in `review.md` (Step 1)
- **Milestone**: M1
- **Requirements**: R1
- **Decisions**: D1 (POSIX `case`-glob, bash 3.2 portable; no `[[ =~ ]]`).
- **Scope**: Single-file edit to `.claude/commands/specflow/review.md`. Insert a
  new **Step 1 bullet** before the existing feature-directory resolution step
  (which becomes Step 2): validate the `<slug>` argument against the repo's
  kebab-case constraint before any filesystem or git operation runs.

  **Regex paste verbatim from PRD R1 (do not paraphrase per `briefing-contradicts-schema`)**:

  > validate `<slug>` against the regex `^[a-z0-9][a-z0-9-]*$` (kebab-case per
  > repo README frontmatter schema). On mismatch, emit a clear error to stderr
  > and exit with status 2.

  **Implementation dialect per D1** — use POSIX `case` glob, NOT `[[ =~ ]]`.
  The command body is prose pseudocode; the step should read as a
  pseudocode block that a bash-aware reader will map to `case`. Example
  shape (adapt wording to match neighbour steps in `review.md`):

  ```
  1. **Validate slug** — before any filesystem or git operation:
     case "$slug" in
       [a-z0-9][a-z0-9-]*) : ;;   # OK — kebab-case
       *) echo "review: invalid slug '$slug' (expected ^[a-z0-9][a-z0-9-]*$)" >&2; exit 2 ;;
     esac
  ```

  **Tradeoff per D1**: `case` glob enforces the same alphabet and leading-char
  constraint as the regex. This is equivalent for the stated requirement.

- **NOT changed**: other steps (resolve feature dir, resolve diff basis,
  dispatch reviewers, aggregate verdicts, report filename, STATUS notes,
  Failures, Rules). Only Step 1 is added; existing step numbers shift +1.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md`.
- **Verify** (all must pass):
  - `grep -q '\^\[a-z0-9\]\[a-z0-9-\]\*\$' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` — regex present verbatim.
  - `grep -qE 'exit 2|status 2' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` — exit-2 semantics documented.
  - `grep -qi 'stderr' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` — stderr emission documented.
  - `grep -q 'case "\$slug"' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` — D1 dialect used (not `[[ =~ ]]`).
  - Ordering: `awk '/Validate slug/{a=NR} /feature[- ]dir|resolve.*feature/{b=NR; exit} END {exit !(a>0 && b>0 && a<b)}' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` — validator precedes feature-dir resolution.
  - Not using bash-only regex: `! grep -q '\[\[ .* =~' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/review.md` inside the new step (spot-check by inspection).
- **Depends on**: —
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7, T8, T9
- [ ]

## T2 — R2 `awk`-fold refactor in `t35.sh` (R11 folded per D5)
- **Milestone**: M2
- **Requirements**: R2, R11
- **Decisions**: D5 (R11 folded into R2's deliverable; single diff hunk), D2
  (byte-identical output verification is the hard acceptance gate).
- **Scope**: Single-file refactor to
  `/Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh`.
  Per PRD R2: fold the 6+ per-rubric-file reads into **one `awk` pass per
  rubric file** that emits the frontmatter keys, body section markers, and
  checklist count in a single traversal. Three rubric files iterated; each
  opened at most once for the folded pass. Per D5 / R11: the WHAT-narrating
  comment at line 106 (`Extract line numbers of each required heading`)
  disappears as a natural consequence of the restructure — do NOT reintroduce
  it.

  **Byte-identical verification (D2, mandatory)** — before and after the edit:
  1. In a sandbox: `bash test/t35_reviewer_rubric_schema.sh 2>&1 > /tmp/t35_before.log`
  2. Apply the refactor.
  3. `bash test/t35_reviewer_rubric_schema.sh 2>&1 > /tmp/t35_after.log`
  4. `diff /tmp/t35_before.log /tmp/t35_after.log` MUST be empty. Non-empty diff
     = task fails; iterate.

  **bash 3.2 portability** per `.claude/rules/bash/bash-32-portability.md`:
  no `mapfile`, no `readarray`, no GNU-only `awk` extensions. Use the
  `while IFS= read -r line; do ... done < <(awk ...)` pattern if multi-line
  output needs to be consumed in the shell; prefer straight `awk` variables
  piped to `grep -c` / `grep -q` for single-value extraction.

- **NOT changed**: any other test file. The test's externally observable
  output (PASS/FAIL lines, axis counters, etc.) must be byte-identical.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh`.
- **Verify** (all must pass):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh` — syntax clean.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh` exits 0.
  - Byte-identical output: `diff /tmp/t35_before.log /tmp/t35_after.log` produces no output (see D2 procedure above).
  - R11 comment deleted: `! grep -q 'Extract line numbers of each required heading' /Users/yanghungtw/Tools/spec-workflow/test/t35_reviewer_rubric_schema.sh`.
  - Fork/exec reduction: the refactor folds multiple per-file reads into one `awk` (verified by code review — look for a single `awk` invocation per rubric in the inner loop body).
- **Depends on**: —
- **Parallel-safe-with**: T1, T3, T4, T5, T6, T7, T8, T9
- [x]

## T3 — R3 read-into-variable + R7 pipefail in `t34.sh` (bundled single-file)
- **Milestone**: M2 + M4
- **Requirements**: R3, R7
- **Decisions**: D2 (byte-identical output verification); R3 and R7 bundled
  into one task because they touch the same file — bundling avoids the
  shared-file parallelism hazard per `parallel-safe-requires-different-files`.
- **Scope**: Two coordinated edits to
  `/Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh`:

  1. **R7 (line 7)** — change `set -u` to `set -u -o pipefail`. One-line
     mechanical edit.
  2. **R3 (whole-file refactor)** — read each agent file **once** into a
     shell variable (e.g. `content=$(cat "$agent_file")`) and run greps
     against the variable via `printf '%s\n' "$content" | grep ...`, OR
     batch the schema-key checks into a single `awk` pass. Either approach
     is acceptable per PRD R3; the acceptance bar is materially reduced
     per-agent-file fork/exec count.

  **Byte-identical verification (D2, mandatory)** — same procedure as T2:
  1. `bash test/t34_reviewer_verdict_contract.sh 2>&1 > /tmp/t34_before.log`
  2. Apply R7 + R3 edits.
  3. `bash test/t34_reviewer_verdict_contract.sh 2>&1 > /tmp/t34_after.log`
  4. `diff /tmp/t34_before.log /tmp/t34_after.log` MUST be empty.

  **Pipefail interaction watch-out per D1**: adding `pipefail` can cause
  previously-silent mid-pipeline failures to surface. If the R3 refactor uses
  `printf | grep` pipelines, the exit status propagation must still produce
  PASS output byte-identically. If a test line now fails under pipefail that
  passed before, that is a pre-existing latent bug and escalates to PM —
  do NOT silence it.

  **bash 3.2 portability**: no `mapfile`; single-variable capture via
  `content=$(cat "$agent_file")` is fine.

- **NOT changed**: any other file.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh`.
- **Verify** (all must pass):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` — syntax clean.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` exits 0.
  - Byte-identical output: `diff /tmp/t34_before.log /tmp/t34_after.log` empty.
  - R7 in place: `grep -n '^set ' /Users/yanghungtw/Tools/spec-workflow/test/t34_reviewer_verdict_contract.sh` shows `set -u -o pipefail`.
  - R3 fork/exec reduction: code review confirms either (a) a single `cat`-to-variable per agent file, or (b) a single batched `awk` pass per agent file.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T4, T5, T6, T7, T8, T9
- [ ]

## T4 — R4 team-memory path rename in `reviewer-security.md` + R13 in-file verify (per D3)
- **Milestone**: M3
- **Requirements**: R4, R13 (partial: file-level; repo-wide in T10)
- **Decisions**: D3 (grep-before-rename / classify-before-mutate discipline);
  `common/classify-before-mutate.md` rule.
- **Scope**: Single-file edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  Replace EVERY occurrence of `~/.claude/team-memory/reviewer-security/` with
  `~/.claude/team-memory/reviewer/`. Per PRD R4: this covers line 12 and any
  additional occurrences (prose, comments, team-memory invocation block,
  checklist lines).

  **Classifier-first procedure per D3**:
  1. At task start, re-run the classifier grep on the whole file (state may
     have drifted since the tech-doc pre-check):
     `grep -n 'reviewer-security/' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`
     This produces the closed list of line numbers to edit.
  2. Also re-run the repo-wide classifier to confirm scope is still one file:
     `grep -rn 'reviewer-security/' /Users/yanghungtw/Tools/spec-workflow/.claude/`
     If any file OTHER than `reviewer-security.md` appears, stop and
     escalate to TPM/PM — R4's scope changes.
  3. Edit the enumerated lines in one commit; do not mutate incidentally.

  **Pre-check evidence (D3, from tech stage)**: exactly one file currently
  contains the token — `.claude/agents/specflow/reviewer-security.md`. R13's
  repo-wide verification (zero hits in `.claude/`) is expected to pass
  trivially once R4 lands, but it runs in T10 after Wave 1 merge to catch
  any drift.

- **NOT changed**: other reviewer agent files; rubric files; rule files.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
- **Verify** (all must pass):
  - In-file check: `grep -n 'reviewer-security/' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` returns zero hits.
  - Replacement present: `grep -q '~/.claude/team-memory/reviewer/' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - Local equivalent present: `grep -q '.claude/team-memory/reviewer/' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md`.
  - File syntactically intact — frontmatter still parses, body sections in order (visual inspection).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T5, T6, T7, T8, T9
- [ ]

## T5 — R5 team-memory invocation block reshape in `reviewer-style.md` (D6)
- **Milestone**: M3
- **Requirements**: R5
- **Decisions**: D6 (match the numbered-`ls` shape used by `reviewer-security.md`
  and `reviewer-performance.md`; do NOT invent a third shape —
  `scope-extension-minimal-diff`).
- **Scope**: Single-file edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md`.
  Rewrite the `## Team memory` invocation block so it mirrors the numbered
  checklist shape used by the sibling `reviewer-security.md` and
  `reviewer-performance.md`, with the correct rubric path swapped in
  (`~/.claude/team-memory/reviewer/` → note: after T4 lands this is the
  consistent shared path; T5 should use the same path since R5 is pure
  prose alignment).

  **Before editing**: read both sibling agent files to extract the exact
  numbered-`ls` shape (do NOT invent a unified template — per D6 / R5 this
  is pure prose alignment, no semantic behavior change):
  - `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-security.md` (use POST-T4 version if available in the merged feature branch; pre-T4 has the old `reviewer-security/` path which will not match the shared convention)
  - `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-performance.md`

  **Parallel worktree note**: T5 runs in parallel with T4; T5's worktree
  will see the pre-T4 version of `reviewer-security.md`. That's fine — T5
  only needs the STRUCTURAL shape (numbered ls checklist), not the exact
  path string. Use `reviewer-performance.md` as the canonical template
  since it's not being edited in this wave.

- **NOT changed**: rubric reference path, agent frontmatter, output
  contract, when-invoked sections, Rules section, stay-in-lane literal.
  R5 is prose alignment only.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md`.
- **Verify** (all must pass):
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md`.
  - Team-memory section present: `grep -q '^## Team memory' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md`.
  - Numbered-ls shape present (at least 2 numbered steps visible in the block):
    `awk '/^## Team memory/{flag=1; next} /^## /{flag=0} flag' /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md | grep -cE '^[0-9]+\.' ` ≥ 2.
  - Structural match with `reviewer-performance.md`: both files' Team-memory
    sections use the same number of numbered steps (side-by-side inspection).
  - Frontmatter untouched: `head -10 /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow/reviewer-style.md | grep -q '^name: reviewer-style$'`.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T6, T7, T8, T9
- [ ]

## T6 — R6 pseudocode indent normalize in `implement.md` (around line 96)
- **Milestone**: M3
- **Requirements**: R6
- **Decisions**: minimal-diff — only lines with 3-space indent inside the
  pseudocode block convert to 2-space.
- **Scope**: Single-file edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`.
  Around line 96, inside a heredoc-style pseudocode block: normalize
  indentation so any 3-space indented line becomes 2-space, consistent with
  the surrounding 2-space pseudocode convention.

  **Procedure**:
  1. Locate the pseudocode block at/near line 96.
  2. Identify the block's fence boundaries (likely backtick-fenced code
     block or ``` language pseudo ``` block).
  3. Inside the block only, convert lines matching `^   \S` (3-space +
     non-space) to `^  \S` (2-space + non-space).
  4. Do NOT touch lines outside the block. Do NOT touch prose around it.
  5. Do NOT re-wrap long lines; do NOT change punctuation.

- **NOT changed**: any other part of the file. This is a surgical indent
  normalization.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md`.
- **Verify** (all must pass):
  - Spot-check: `awk 'NR>=90 && NR<=110' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — visual inspection confirms 2-space indent throughout the block.
  - Minimal diff: `git diff .claude/commands/specflow/implement.md` shows only whitespace-only changes inside the pseudocode block.
  - No 3-space prefixes remain in the target block (manual awk check scoped to the block):
    `awk '/^```/{f=!f; next} f && /^   \S/{print NR": "$0}' /Users/yanghungtw/Tools/spec-workflow/.claude/commands/specflow/implement.md` — zero hits in the affected block (other blocks may legitimately differ; inspect narrowly).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T7, T8, T9
- [ ]

## T7 — R8 + R9 pipefail bundle (t37 + t38)
- **Milestone**: M4
- **Requirements**: R8, R9
- **Decisions**: per plan M4 — R8 + R9 bundled into one task because the
  changes are 1-line mechanical sed-class edits across two test files;
  task-overhead of splitting exceeds savings. R7 is NOT bundled here
  because it lives in t34.sh alongside R3 (same-file bundle in T3).
- **Scope**: Two coordinated one-line edits:
  1. `/Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` —
     line 8: change `set -u` to `set -u -o pipefail`.
  2. `/Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` —
     line 8: change `set -u` to `set -u -o pipefail`.

  **Pipefail regression watch-out**: as with R7 in T3, adding `pipefail` may
  surface previously-silent pipeline failures. If either test now fails
  that previously passed, that is a pre-existing latent bug — escalate to
  PM; do NOT silence it.

- **NOT changed**: any other line in either file.
- **Deliverables**: edits to two files:
  - `/Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh`
  - `/Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh`
- **Verify** (all must pass):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` — syntax clean.
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` — syntax clean.
  - `grep -n '^set ' /Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` shows `set -u -o pipefail`.
  - `grep -n '^set ' /Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` shows `set -u -o pipefail`.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t37_review_oneshot.sh` exits 0.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t38_hook_skips_reviewer.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T6, T8, T9
- [ ]

## T8 — R10 WHAT-comment delete in `t26.sh` line 57
- **Milestone**: M5
- **Requirements**: R10
- **Decisions**: PRD §3 locked decision — WHAT comments drop, don't rewrite.
- **Scope**: Single-file edit to
  `/Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh`. Delete
  the WHAT-narrating comment line at/around line 57. No replacement text.

  **Before deleting**: confirm the comment is the `Count files only (not
  directories) in the commands dir` WHAT comment per PRD AC10. If the line
  number has drifted, find it by content:
  `grep -n 'Count files only' /Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh`.

- **NOT changed**: any code line. Only the comment line is removed.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh`.
- **Verify** (all must pass):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh` — syntax clean.
  - Comment gone: `! grep -q 'Count files only' /Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh` AND `! grep -q 'Count files only (not directories) in the commands dir' /Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh`.
  - Test still passes: `bash /Users/yanghungtw/Tools/spec-workflow/test/t26_no_new_command.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T6, T7, T9
- [ ]

## T9 — R12 `to_epoch()` removal in `stop.sh` (D4 pre-check + caller grep evidence)
- **Milestone**: M6
- **Requirements**: R12
- **Decisions**: D4 (classify-before-mutate for dead-code removal; grep the
  repo for callers first, escalate if any found outside the definition
  itself); `qa-analyst/dead-code-orphan-after-simplification.md` memory.
- **Scope**: Single-file edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh`. Delete the
  orphaned `to_epoch()` function, currently at lines 108–117 per PRD (may
  have drifted; locate by content).

  **Classifier procedure per D4 (mandatory — do at task start)**:
  1. Re-run the caller grep across the whole repo:
     `grep -rn 'to_epoch' /Users/yanghungtw/Tools/spec-workflow/`
  2. Expect the matches to fall into these classes (per tech doc §3 D4):
     - **Definition** in `.claude/hooks/stop.sh` (the target of R12 — delete).
     - **Documentation** in `.claude/rules/bash/bash-32-portability.md` (stays — rule-example snippet, not a caller).
     - **Comment** in `test/t32_stop_hook_dedup.sh:7` (stays — comment, not a caller).
     - **Archive** under `.spec-workflow/archive/20260417-shareable-hooks/` (stays — historical).
     - **This feature's own docs** under `.spec-workflow/features/20260418-review-nits-cleanup/` (stays — PRD/tech/plan discuss it).
     - **Team-memory** entry at `.claude/team-memory/qa-analyst/dead-code-orphan-after-simplification.md` (stays — it's the memory about this pattern).
  3. If ANY match appears outside these classes (e.g., a live caller
     in `.claude/hooks/` or `bin/` or a currently-running feature's code),
     STOP and escalate to PM/TPM — R12 becomes a behavior question.
  4. If classifier output matches expected classes, proceed with the
     delete.

  **The edit**:
  - Locate `to_epoch()` function definition in `.claude/hooks/stop.sh`.
  - Delete the function block — its entire definition, opening line through
    closing `}` — plus any immediately-adjacent blank line that exists
    solely to separate it.
  - NO other edits. The rest of `stop.sh` stays byte-identical.

  **Caller-grep evidence preserved**: capture the pre-edit grep output
  and paste it into the task's STATUS note as the record of classifier
  evidence (per D4 discipline).

- **NOT changed**: any other function in `stop.sh`; any other file; any
  docs/rule/archive reference to `to_epoch`.
- **Deliverables**: edit to
  `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh`.
- **Verify** (all must pass):
  - Function gone: `grep -n 'to_epoch' /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh` returns zero hits (no definition, no callers).
  - Hook still syntactically valid: `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh` exits 0.
  - No other edits: `git diff /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh` shows only the `to_epoch` function block deletion.
  - Stop-hook regression: `bash /Users/yanghungtw/Tools/spec-workflow/test/t32_stop_hook_dedup.sh` exits 0 (the t32 test has a comment reference to `to_epoch` but no call — it must remain green).
  - Classifier evidence captured in STATUS note (see D4 procedure above).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T6, T7, T8
- [ ]

---

## T10 — Wave 2 verify bundle: R13 repo-wide grep + R14 smoke
- **Milestone**: M7
- **Requirements**: R13, R14
- **Decisions**: plan §5 — verify bundle serialized after Wave 1 merge;
  smoke and repo-wide greps must see the merged tree.
- **Scope**: Two verification checks; both read-only, no file edits. If
  either fails, flag the specific failing requirement back to the owning
  Wave-1 task for rework.

  1. **R13 — repo-wide `reviewer-security/` grep returns zero hits in `.claude/`**:
     ```
     grep -rn 'reviewer-security/' /Users/yanghungtw/Tools/spec-workflow/.claude/
     ```
     Expected: empty output, exit status 1 (grep "no match"). If ANY hit,
     R4 missed a reference — reopen T4 or extend its scope. Per D3
     pre-check, zero hits are expected.

  2. **R14 — full smoke suite passes at 38/38**:
     ```
     bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh
     ```
     Expected: `38/38 PASS`, exit 0. If any test fails, the failing test
     identifies which Wave-1 task regressed — reopen that task.

  3. **Report generation**: write a short summary line to STATUS Notes
     recording both check results.

- **NOT changed**: any source file. T10 is verification only.
- **Deliverables**: STATUS Notes line recording verify-bundle outcome.
  No file edits beyond STATUS.md appends.
- **Verify** (all must pass):
  - `grep -rn 'reviewer-security/' /Users/yanghungtw/Tools/spec-workflow/.claude/` returns empty (exit 1) — R13.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` exits 0, output shows `38/38 PASS` — R14.
  - STATUS Notes line appended documenting both check outcomes.
- **Depends on**: T1, T2, T3, T4, T5, T6, T7, T8, T9 (all of Wave 1 must be merged).
- **Parallel-safe-with**: —
- [ ]

---

## STATUS Notes

_(populated by Developer as tasks complete; expected mechanical
append-collisions on this section are resolved keep-both per
`tpm/parallel-safe-append-sections.md`)_

- **T2 DONE** (2026-04-17): awk-fold refactor in `test/t35_reviewer_rubric_schema.sh`. Single awk pass per rubric file replaces 7 file reads (head, frontmatter-awk, 4 grep-n, checklist-awk). R11 WHAT comment at line 106 deleted. Byte-identical output verified: `diff /tmp/t35_before.txt /tmp/t35_after.txt` empty. bash 3.2 (`/bin/bash`) passes. All verify checks green.

---

## Wave schedule

- **Wave 1 (9 parallel)**: T1, T2, T3, T4, T5, T6, T7, T8, T9
- **Wave 2 (1 serial verify)**: T10

### Parallel-safety analysis

- **Wave 1 (9-wide)** — Primary files:
  - T1: `.claude/commands/specflow/review.md`
  - T2: `test/t35_reviewer_rubric_schema.sh`
  - T3: `test/t34_reviewer_verdict_contract.sh`
  - T4: `.claude/agents/specflow/reviewer-security.md`
  - T5: `.claude/agents/specflow/reviewer-style.md`
  - T6: `.claude/commands/specflow/implement.md`
  - T7: `test/t37_review_oneshot.sh` + `test/t38_hook_skips_reviewer.sh` (two files bundled intentionally per plan M4 — both 1-line edits)
  - T8: `test/t26_no_new_command.sh`
  - T9: `.claude/hooks/stop.sh`

  **File-set check**: all 9 primary files are genuinely disjoint (per
  `parallel-safe-requires-different-files`). T7's two files do not overlap
  with any other task's file list. 9-way is the widest parallel wave in
  this repo's history (previous max was 7-way in B1 and B2.a); the file-set
  disjointness is the primary predicate and it holds.

  **Expected mechanical append collisions** (per `parallel-safe-append-sections`):
  - `06-tasks.md` STATUS Notes section — every task appends a note; resolve
    keep-both.
  - `STATUS.md` Notes — every task appends a note; resolve keep-both.
  - `06-tasks.md` checkbox flips — per `checkbox-lost-in-parallel-merge`,
    the 9-way wave WILL drop some `[ ]`→`[x]` flips during merge.
    Orchestrator MUST run `grep -c '^- \[x\]' 06-tasks.md` after Wave 1
    merges and commit `fix: check off T<n> (lost in merge)` as needed.
    Both B1 (lost T4 + T15) and B2.a (lost T1 + T2) required fix-up
    commits; 9-way at minimum matches that risk. Automate the audit.

  **Test isolation**: no two Wave-1 tasks touch the same test file. Each
  test runs under its own `mktemp -d` sandbox per the repo's sandbox-HOME
  rule (bash/sandbox-home-in-tests.md). No shared `/tmp` paths, fixtures,
  or ports. D2 byte-identical-output diffs (T2, T3) are captured locally
  in each worktree; no shared `/tmp` files cross tasks (use unique paths
  per worktree if `/tmp` collision is a concern — e.g., `/tmp/t34_$$.log`).

  **Shared infrastructure**: none. No migrations, no schema changes, no
  config files shared across primary edit paths.

- **Wave 2 (size 1)** — T10 serializes by design: R13 and R14 both read
  the fully-merged tree. Running concurrently with Wave 1 would race.
  Size-1 is intentional; overhead is trivial (two greps and a smoke run).

**Total tasks**: 10. **Total waves**: 2. Wave widths: `9, 1`. Widest wave
(9) exceeds prior-feature precedent (7-wide in B1, B2.a) because this
housekeeping sweep has exceptional file-disjointness — 9 tasks across 10
different primary files with zero shared-file logic collisions. Append
collisions on STATUS / tasks-doc are expected and mechanically resolved.
