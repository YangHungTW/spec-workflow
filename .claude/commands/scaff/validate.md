---
description: Validate a feature with qa-tester + qa-analyst in parallel; writes 08-validate.md. Usage: /scaff:validate <slug>
---

Consolidated validate stage. Replaces the retired `/scaff:gap-check` + `/scaff:verify` pair. Runs the `tester` and `analyst` axes **in parallel** (D4), aggregates their verdicts via the shared aggregator (D5/R17), writes `08-validate.md`, and advances STATUS only on PASS or NITS.

## Steps

1. **Parse args.**
   - `<slug>` is required. If missing, print usage and exit 2.
   - Validate slug format with a `case`-glob (bash 3.2 portable; no `[[ =~ ]]`):
     ```sh
     case "$slug" in
       [a-z0-9][a-z0-9-]*) : ;;
       *) printf 'validate: invalid slug "%s" (expected ^[a-z0-9][a-z0-9-]*$)\n' "$slug" >&2; exit 2 ;;
     esac
     ```

2. **Resolve feature dir.**
   - If `.specaffold/features/<slug>/` exists, use it as `FEATURE_DIR`.
   - Else print `ERROR: no feature dir found for slug '<slug>'` to stderr and exit 2.
   - (Archived features cannot be validated; use `/scaff:review` for post-archive spot checks.)

3. **Require all implement tasks checked.**
   - Read `$FEATURE_DIR/05-plan.md` if present, otherwise `$FEATURE_DIR/06-tasks.md`.
   - Search for unchecked task lines under the wave schedule section:
     ```sh
     unchecked="$(grep '^\- \[ \]' "$TASK_FILE" 2>/dev/null || true)"
     ```
   - If any unchecked task lines found: print each to stderr, print
     `ERROR: validate requires all implement tasks checked; use /scaff:implement <slug> first`
     and exit 1.
   - User may override with `--force` and an explicit reason:
     `/scaff:validate <slug> --force "reason for overriding unchecked tasks"`
     When `--force` is used, append a STATUS Notes line:
     `YYYY-MM-DD validate — override unchecked tasks: <reason>`

4. **Dispatch qa-tester and qa-analyst in parallel** — in ONE orchestrator message, fire both Agent calls concurrently (D4):

   Agent 1: **scaff-qa-tester** (axis: tester — dynamic acceptance-criterion walkthrough)
   - Provide: `FEATURE_DIR`, `03-prd.md` ACs, the full working-tree diff since feature start.
   - Task: walk each PRD AC, run or exercise the check, emit pass/fail evidence.
   - Output contract: writes its findings to its reply; reply ends with a `## Validate verdict` footer:
     ```
     ## Validate verdict
     axis: tester
     verdict: PASS | NITS | BLOCK
     findings:
       - severity: must | should
         ...
     ```

   Agent 2: **scaff-qa-analyst** (axis: analyst — static PRD-vs-diff gap analysis)
   - Provide: `FEATURE_DIR`, `03-prd.md`, `04-tech.md`, task checklist file, the full feature diff.
   - Task: compare PRD R-ids vs tasks vs diff; surface missing / extra / drifted work.
   - Output contract: writes its findings to its reply; reply ends with a `## Validate verdict` footer:
     ```
     ## Validate verdict
     axis: analyst
     verdict: PASS | NITS | BLOCK
     findings:
       - severity: must | should
         ...
     ```

   Both agents write `## Validate verdict` (NOT `## Reviewer verdict`) per PRD R18.

5. **Aggregate verdicts** — collect both agent replies. Write each reply to a per-axis file in a temp dir, then invoke the extracted aggregator CLI. The aggregator is the pure classifier; no mutation here:

   ```bash
   VERDICT_DIR="$(mktemp -d)"
   # (orchestrator writes each agent reply to $VERDICT_DIR/<axis>.txt
   #  before the next line runs; one file per axis: tester.txt, analyst.txt)

   AGG_OUTPUT="$(bin/scaff-aggregate-verdicts tester analyst \
     --dir "$VERDICT_DIR")"
   AGG_VERDICT="$(printf '%s\n' "$AGG_OUTPUT" | head -1)"
   VALIDATE_STATE="validate:${AGG_VERDICT}"
   rm -rf "$VERDICT_DIR"
   ```

   Error posture: the aggregator treats a missing or malformed `## Validate verdict` footer
   (no header, no `verdict:` key, verdict outside `{PASS, NITS, BLOCK}`) as BLOCK (fail-loud).

6. **Compose 08-validate.md** — write atomically (write to `08-validate.md.tmp`, rename):

   ```markdown
   # Validate: <slug>
   Date: YYYY-MM-DD HH:MM
   Axes: tester, analyst

   ## Consolidated verdict
   Aggregate: <PASS | NITS | BLOCK>
   Findings: <N> must, <M> should

   ## Tester axis
   <qa-tester's full reply quoted verbatim>

   ## Analyst axis
   <qa-analyst's full reply quoted verbatim>

   ## Validate verdict
   axis: aggregate
   verdict: <PASS | NITS | BLOCK>
   ```

7. **Dispatch on validate state** (mutation lives here; classify-before-mutate rule applies):

   - **`validate:BLOCK`** — do NOT advance STATUS:
     1. Print per-axis findings to stdout.
     2. Print: `BLOCK: validate failed — fix findings and re-run /scaff:validate <slug>`.
     3. Append to `$FEATURE_DIR/STATUS.md` under `## Notes`:
        `YYYY-MM-DD validate — slug=<slug> verdict=BLOCK`
     4. Exit 1.

   - **`validate:NITS`** — advance STATUS with advisory note:
     1. Check `[x] validate` in `$FEATURE_DIR/STATUS.md`.
     2. Append to `$FEATURE_DIR/STATUS.md` under `## Notes`:
        `YYYY-MM-DD validate — slug=<slug> verdict=NITS (advisory findings in 08-validate.md)`
     3. Print: `NITS: validate passed with advisory findings. Check 08-validate.md.`
     4. Print: `Next: /scaff:next <slug>`
     5. Exit 0.

   - **`validate:PASS`** — advance STATUS cleanly:
     1. Check `[x] validate` in `$FEATURE_DIR/STATUS.md`.
     2. Append to `$FEATURE_DIR/STATUS.md` under `## Notes`:
        `YYYY-MM-DD validate — slug=<slug> verdict=PASS`
     3. Print: `PASS: validate complete.`
     4. Print: `Next: /scaff:next <slug>`
     5. Exit 0.

## Failures

- **One agent times out or crashes**: treat as BLOCK (fail-loud — a missing result is indistinguishable from a suppressed finding). Write partial `08-validate.md` marking the axis as `ERROR: timeout/no-response`. Append STATUS Notes with `verdict=ERROR`.
- **Feature dir missing**: print error to stderr; exit 2. No STATUS mutation.
- **Artefact write fails** (e.g. disk full): print error to stderr; exit 1. STATUS Notes append still attempted.

## Rules

- Dispatch MUST be parallel — both agents in ONE orchestrator message (D4). Never fire them sequentially.
- `08-validate.md` write MUST be atomic: write to `08-validate.md.tmp` first, then rename. (no-force-on-user-paths rule.)
- STATUS `[x] validate` is checked ONLY if aggregate verdict is PASS or NITS. BLOCK leaves the box unchecked.
- Verdict footer header is `## Validate verdict`, never `## Reviewer verdict` (PRD R18).
- All shell pseudocode must be bash 3.2 / BSD userland portable: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic.
- The aggregator (`bin/scaff-aggregate-verdicts`) is a pure classifier; no mutation inside it. Mutation (08-validate.md write, STATUS Notes, STATUS checkbox) lives only in the dispatch arms above (step 7).
