# Tech — tier-model

**Feature**: `20260420-tier-model`
**Stage**: tech
**Author**: Architect
**Date**: 2026-04-20

PRD: `03-prd.md` (R1–R20, AC1–AC12). Brainstorm: `01-brainstorm.md`. Draft: `.spec-workflow/drafts/tier-model.md`.

This feature ships **no new language, framework, runtime, or external dependency** — it restructures bash + markdown that already exist in this repo. The architecture work here is therefore narrow: shape the new helper, classify the command surface deltas, commit the migration mechanic, and wire the four PRD carry-forward open questions to closed answers. The technology-decision section (§3) is short by design; the cross-cutting concerns section (§4) carries most of the weight.

---

## 1. Context & Constraints

### 1.1 Existing stack — what is already committed

- **Bash 3.2 / BSD userland** (per `.claude/rules/bash/bash-32-portability.md`). All shipped scripts run on macOS default shell. No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic.
- **Markdown-as-protocol**. STATUS.md is hand-edited prose with a header block and a `## Stage checklist` section; commands and agents read it line-by-line, not via a parser library. Verdict footers (`## Reviewer verdict`) are pure-markdown `key: value` per `architect/reviewer-verdict-wire-format.md`.
- **`bin/` for user-facing CLIs**, no extension, exec bit (per `architect/script-location-convention.md`). Today: `claude-symlink`, `specflow-install-hook`, `specflow-lint`, `specflow-seed`.
- **`.claude/commands/specflow/*.md`** — orchestrator slash commands; one file per command; YAML-frontmatter `description:` line, then prose+code steps. Today: 18 commands including the four to be retired.
- **`.claude/agents/specflow/*.md`** — subagent prompts (pm, architect, tpm, designer, developer, qa-analyst, qa-tester, three reviewers).
- **Aggregator pattern in two places**: `/specflow:implement` step 7 (per-task × axis aggregation, embedded inline as bash) and `/specflow:review` step 5 (whole-feature review aggregation, embedded inline as bash). Both use the same `## Reviewer verdict` parse shape and the same `BLOCK > NITS > PASS` max-reduce classifier semantic; **the code is currently copy-pasted, not factored** — see D5 below.

### 1.2 Hard constraints

- **Bash 3.2 portability** for every shell decision (`.claude/rules/bash/bash-32-portability.md`).
- **No `--force` defaults on user-owned paths** (`.claude/rules/common/no-force-on-user-paths.md`). The W0 STATUS migration in particular MUST back up before mutate.
- **Classify-before-mutate** (`.claude/rules/common/classify-before-mutate.md`). The tier reader is a pure classifier: input = feature dir, output = one of `{tiny, standard, audited, missing, malformed}` on stdout, no side effects.
- **Sequencing lock** (PRD §9.2): B2 (`20260420-flow-monitor-control-plane`) MUST NOT advance past `request` until this feature archives. The W0 migration MUST land before B2's PM advances B2 to `brainstorm`.
- **Dogfood paradox** (`shared/dogfood-paradox-third-occurrence.md`): runtime exercise of new commands is deferred to B2 (PRD R20). This feature's verify is structural-only for AC2/3/4/5/6/7.b/8/9/11/12 (PRD §9.1).

### 1.3 Soft preferences

- **Prefer extending existing files over adding new ones.** Tier dispatch tables, helper functions, and STATUS-parsing live alongside their callers when possible. Two new files only: the tier-helper sourceable library and the new `/specflow:validate` command file.
- **Prefer markdown deprecation stubs over silent removal** for retired commands. Muscle-memory invocations from users / agents are a real cost; one keystroke of feedback is cheaper than command-not-found ambiguity.
- **Reuse the review aggregator parser verbatim** (Q-CARRY-3 / D5 below). Two parsers will drift; one parameterised parser will not.

### 1.4 Forward constraints (what must not be made harder)

- **Feature-template extension.** `.spec-workflow/features/_template/STATUS.md` will gain a `tier:` field. New-shape stage checklist (no `tasks` / `gap-check` / `verify` boxes; new `validate` box) becomes the template default. Old archived features must remain readable by any tool that reads STATUS — that means the parser dispatches on field-presence, never assumes presence.
- **Tier-aware `/specflow:next`** must continue to advance one stage at a time (PRD R8 +existing convention). It does not gain a "skip multiple stages in one invocation" semantic; it auto-checks skipped boxes inline and re-reads, same as today's `has-ui: false → design skip`.
- **`/specflow:archive` merge-check** must not block features that have legitimately archived without merge in the past (those are out-of-scope per PRD §3 — not back-filled). The check fires only when `tier:` is present AND value is `standard|audited`. Absence of `tier:` (legacy) is treated as "tiny-equivalent for archive-check purposes" — archives cleanly. Documented in D7.

---

## 2. System Architecture

### 2.1 Components and responsibilities

```
                       +------------------------------------+
                       |   .spec-workflow/features/<slug>/  |
                       |     STATUS.md  (tier: <value>)     |
                       +-----------------+------------------+
                                         |
                                         v
                +------------------------+----------------------+
                |   bin/specflow-tier  (sourceable bash lib)    |
                |   - get_tier(feature_dir)  → stdout enum      |
                |   - set_tier(feature_dir, new, role, reason)  |
                |   - validate_tier_transition(old, new)        |
                |   - tier_skips_stage(tier, stage)  → 0/1      |
                +------------------------+----------------------+
                                         |
       +---------------+---------+-------+-------+---------+----------+
       |               |         |               |         |          |
       v               v         v               v         v          v
   /specflow:next  /specflow:  /specflow: /specflow:    /specflow: /specflow:
                   request     implement   archive       plan       validate
   (skips stages   (--tier flag (auto-     (merge-check  (writes    (NEW: parallel
    per matrix     + propose-   upgrade    if standard|  05-plan.md tester+analyst
    R10)           confirm)     trigger    audited)      merged)    via shared agg)
                                if diff>thr)
                                         |
                                         v
                       +-----------------+------------------+
                       |  bin/specflow-aggregate-verdicts   |
                       |  (parameterised by axis-set;       |
                       |   shared by review + validate)     |
                       +------------------------------------+
                                         ^
                                         |
                       +-----------------+------------------+
                       |     /specflow:review (existing)    |
                       +------------------------------------+
```

### 2.2 Key data flows

**Flow A — request with auto-tier proposal (PRD R5, AC12):**

```
user → /specflow:request "<ask>" [--tier <t>]
        |
        v
 request.md step 4 → invoke pm subagent
        |
        v
 pm.md (extended): if --tier set → use it; else compute proposal:
   1. Run existing intake probes (why-now, success, out-of-scope, has-ui).
   2. Apply tier-proposal heuristic (D6): keyword scan + scope signals.
   3. Emit propose-and-confirm prompt (one block, see D6 prompt template).
   4. Read user reply: blank → adopt proposed; one of {tiny,standard,audited} → override; anything else → re-prompt once, then default to proposed.
        |
        v
 STATUS.md gets `tier: <chosen>` between has-ui: and stage:.
 STATUS Notes gets the proposal record.
```

**Flow B — `/specflow:next` reads tier and skips (PRD R8):**

```
/specflow:next <slug>
        |
        v
 Read STATUS.md → next unchecked box from stage checklist.
        |
        v
 source bin/specflow-tier; tier=$(get_tier "$feature_dir")
        |
        v
 If tier_skips_stage "$tier" "$next_stage" returns 0:
   - check the box with note `skipped (tier: <t>)`
   - append STATUS Notes line: `<date> next — tier <t> skips <stage>`
   - re-read STATUS, advance again (loop until non-skipped or end).
 Else: dispatch to the matching command per existing table.
```

**Flow C — `/specflow:validate` (NEW; PRD R3, R17, R18):**

```
/specflow:validate <slug>
        |
        v
 Resolve feature dir; require all implement tasks checked.
        |
        v
 Dispatch in ONE orchestrator message (parallel — see Q-CARRY-3 / D4):
   Agent: qa-tester    (axis: tester,  task: dynamic walkthrough)
   Agent: qa-analyst   (axis: analyst, task: static PRD↔diff gap)
        |
        v
 Each writes its `## Validate verdict` footer (pure markdown).
        |
        v
 Aggregate via bin/specflow-aggregate-verdicts AXIS_SET="tester analyst"
   → emits validate:PASS | validate:NITS | validate:BLOCK on stdout.
        |
        v
 Compose 08-validate.md: header + per-axis findings + aggregated verdict footer.
 Update STATUS: check [x] validate (only if PASS or NITS); BLOCK leaves it unchecked.
```

**Flow D — implement-time auto-upgrade trigger (PRD R14):**

```
/specflow:implement <slug>  (existing, extended)
        |
        v
 After each wave merge, before reading next wave:
   diff_lines=$(git diff --shortstat <base>...<feature> | awk '{print $4}')
   diff_files=$(git diff --name-only <base>...<feature> | wc -l)
   tier=$(get_tier "$feature_dir")
   if [ "$tier" = "tiny" ] && \
      { [ "$diff_lines" -gt "${SPECFLOW_TIER_DIFF_LINES:-200}" ] || \
        [ "$diff_files" -gt "${SPECFLOW_TIER_DIFF_FILES:-3}" ]; }; then
     suggest_upgrade "tiny→standard" "diff exceeded threshold"
   fi
        |
        v
 suggest_upgrade prints a one-line WARNING + asks TPM to confirm (interactive
 if TTY; emits a STATUS Notes pending marker if non-TTY). TPM confirms by
 invoking set_tier; never fires automatically (PRD R14 says "TPM decides").
```

### 2.3 Module boundaries

- **`bin/specflow-tier`** — pure bash library, sourced (not exec'd) by callers. Single source-of-truth for `get_tier`, `set_tier`, `validate_tier_transition`, `tier_skips_stage`. Only code that reads/writes the `tier:` field (PRD R11).
- **`bin/specflow-aggregate-verdicts`** — pure bash CLI, takes axis-set as positional args + a verdict directory as `--dir`, prints aggregated verdict to stdout. Reused by `/specflow:review` step 5 and `/specflow:validate`. Both currently-inline aggregators are refactored to call this in W1 (see D5).
- **`.claude/commands/specflow/validate.md`** — NEW command file. Mirror shape of `verify.md` + `gap-check.md` combined.
- **Retired command files** — `brainstorm.md`, `tasks.md`, `verify.md`, `gap-check.md` become deprecation stubs (D8). Each stays in the registry; each prints one line then exits with note to STATUS.

---

## 3. Technology Decisions

(Short by design — no language or framework choices to make.)

### D1. Tier-helper as a sourceable bash library, not a CLI
- **Options considered**:
  - A. Standalone CLI (`bin/specflow-tier get <dir>` → stdout)
  - B. Sourceable library (`. bin/specflow-tier` then call `get_tier "$dir"`)
  - C. Python helper (`python3 -c "..."` invoked by callers)
- **Chosen**: B (sourceable library).
- **Why**: PRD R11 says "single helper, one parse site". A sourceable library satisfies that — every caller `source`s the same file and calls the same function. Standalone CLI (A) means every call forks a subprocess; on `/specflow:next` that fires twice per stage (read tier + check skip). Python (C) drags in an interpreter for a one-line grep. Bash function lookup is in-process and free.
- **Tradeoffs accepted**: Callers must `source` the lib explicitly. Convention: `source "$REPO_ROOT/bin/specflow-tier"` near top of any caller; helper itself protects against double-source with `[ "${SPECFLOW_TIER_LOADED:-0}" = "1" ] && return; SPECFLOW_TIER_LOADED=1`.
- **Reversibility**: high. Switching to a CLI later is one wrapper script; no caller-side semantic change.
- **Requirement link**: R11 (single tier-reading helper).

### D2. Tier reader is a pure classifier with five output states
- **Options considered**:
  - A. Three states (`tiny|standard|audited`) — error on any other input.
  - B. Five states (`tiny|standard|audited|missing|malformed`) — caller dispatches.
- **Chosen**: B (five states, classify-before-mutate).
- **Why**: `.claude/rules/common/classify-before-mutate.md` mandates a closed enum. `missing` is the legacy-feature case (no `tier:` field at all — pre-rollout); `malformed` is the corrupted-STATUS case. Both must dispatch to defined behaviour, not an unhandled error path.
  - `missing` → callers treat as `standard` for read purposes (forward-compat with B2-style migration), but `set_tier` MUST NOT silently fix; W0 migration is the only path that converts `missing → standard`.
  - `malformed` → fail-loud (exit 2, surface to user).
- **Tradeoffs accepted**: Two extra dispatch arms in every caller's `case` table. Worth it for fail-loud on STATUS corruption.
- **Reversibility**: high. Removing states is straightforward; adding is the harder direction.
- **Requirement link**: R11, R2.

### D3. STATUS migration is a one-shot bash script under `scripts/`, not a CLI
- **Options considered**:
  - A. New CLI `bin/specflow-tier-migrate` (user-runnable forever)
  - B. One-shot helper `scripts/tier-rollout-migrate.sh` (run once at W0)
  - C. Inline migration inside the W0 implement task (no script file)
- **Chosen**: B (one-shot script under `scripts/`).
- **Why**: `script-location-convention.md` says one-off migrations belong in `scripts/`. The migration runs exactly once per repo at rollout; making it a `bin/` CLI implies recurring use that doesn't exist. Inline (C) loses the standalone test harness and the dry-run flag.
- **Tradeoffs accepted**: Script is throwaway after rollout; archived as a `scripts/archive/` move at the end of W0 (or just left in place — its idempotence guarantees no re-run damage).
- **Reversibility**: high. The script is small; rewriting later is cheap.
- **Requirement link**: R2, AC1, AC5.

### D4. Validate axes run **in parallel** — no correctness dependency exists
- **Options considered**:
  - A. Parallel dispatch (one orchestrator message, two Agent calls)
  - B. Sequential dispatch (analyst first, tester second; tester reads analyst's gap list)
- **Chosen**: A (parallel).
- **Why** (resolves Q-CARRY-3): The two axes verify disjoint properties:
  - **qa-analyst** (static): does the diff implement every R-id in PRD? Reads PRD + git diff + 06-tasks (or merged 05-plan task checklist for new-shape). Produces a static gap list.
  - **qa-tester** (dynamic): does the running artefact pass every AC? Reads PRD ACs + invokes the running app / runs tests. Produces a runtime verdict per AC.
  - Neither writes files the other reads. Neither's output changes the other's input. The two operate on the same pre-merge diff snapshot — analyst can't mutate it, tester invokes a separate process that reads (not writes) repo state.
  - The legacy sequential pattern (gap-check before verify) carried only one weak coupling in practice: a gap-check-BLOCK historically prevented running verify, saving wasted dynamic-test cycles. That is a UX convenience, not a correctness requirement, and is preserved trivially in parallel by the BLOCK-wins aggregation: a BLOCK from analyst short-circuits the validate verdict regardless of tester.
- **Tradeoffs accepted**: Slightly more parallel agent activity (two concurrent calls instead of one then one). No real cost — the orchestrator already dispatches `3 × N_tasks` reviewers in parallel during inline review (`implement.md` step 7a). Two more is rounding error.
- **Reversibility**: medium. Falling back to sequential is a one-line change in `validate.md`, but agent prompts may have been authored under the parallel-independence assumption; revisit any "I read the analyst's findings" prose in the qa-tester prompt at plan stage.
- **Requirement link**: R3, R17. Resolves Q-CARRY-3.

### D5. Aggregator extracted to `bin/specflow-aggregate-verdicts`, parameterised by axis-set
- **Options considered**:
  - A. Reuse-by-copy: paste the existing `implement.md` step-7 aggregator into `validate.md` with `axis: tester|analyst` instead of `axis: security|...`.
  - B. Reuse-by-extract: lift the bash aggregator out of `implement.md` and `review.md` into a single sourceable script; both call sites and the new `validate.md` invoke it.
  - C. Reuse-by-pure-reference: keep existing inline copies in `implement.md` and `review.md`, write a third copy in `validate.md` with the new axis-set.
- **Chosen**: B (extract).
- **Why**: Two existing copy-pasted aggregators in the repo today (`implement.md` step 7b and `review.md` step 5) have already started to drift in field-extraction details (the `implement.md` version inspects per-finding severity; the `review.md` version only inspects top-level verdict). Adding a third copy compounds the drift. Architect memory `aggregator-as-classifier.md` already frames the aggregator as a parameterised classifier — extraction is the natural realisation. PRD R17 explicitly says "the implementation MUST parameterise the axis set so that `/specflow:review` passes `{security, performance, style}` and `/specflow:validate` passes `{tester, analyst}`".
- **Tradeoffs accepted**: Refactor cost — `implement.md` step 7b and `review.md` step 5 must be rewritten to call the extracted script. This is a plan-stage task and is in scope for this feature.
- **Reversibility**: medium. Inlining back is mechanical but loud (re-paste same code into two files).
- **Requirement link**: R17, R18.

### D6. Tier-proposal heuristic — keyword scan + scope signal, propose-and-confirm
- **Options considered** (resolves Q-CARRY-2 contract):
  - A. Always propose `standard`; let user override.
  - B. Keyword classifier: scan ask for `{typo, fix, copy, doc, comment}` → tiny; `{auth, oauth, secret, token, password, payment, migration, breaking}` → audited; else standard.
  - C. ML / LLM-classifier: pm subagent reads ask + uses judgment.
- **Chosen**: B (keyword scan) augmented by C (PM judgment as final arbiter — pm subagent is already an LLM; the keyword set is its anchor).
- **Why**: Heuristic is deterministic-enough for AC12 ("proposal is deterministic given the same raw ask input for testing") while still leveraging PM's existing scope probe. Pure-A (always standard) defeats the educational value of the propose-and-confirm prompt. Pure-C (no anchor) makes the proposal non-deterministic and unteastable.
- **Heuristic specification** (anchored to PRD R14's auto-upgrade triggers for consistency):
  - **Tiny keywords** (case-insensitive substring match in the raw ask): `typo`, `fix typo`, `rename`, `copy change`, `wording`, `comment`, `docstring`, `one-line`, `one line`, `single line`, `readme`.
  - **Audited keywords** (any one match → propose audited): `auth`, `oauth`, `secret`, `secrets`, `token`, `bearer`, `password`, `credential`, `payment`, `billing`, `migration`, `migrate db`, `breaking change`, `breaking api`, `settings.json`.
  - **Default**: `standard`.
  - PM subagent runs the keyword scan first, then has discretion to upgrade the proposal (never downgrade) based on probe answers — e.g. if the user says "this is just a copy fix on the auth modal" the keyword scan proposes audited (`auth`), but PM may downgrade to tiny based on context. Override discipline: PM logs the override reasoning to STATUS Notes.
- **Prompt contract** (the exact wording is PM-prompt-author detail, but the SHAPE is fixed by tech):
  ```
  Based on the ask, I propose tier: <proposed>.
    tiny     — <one-line definition>
    standard — <one-line definition>
    audited  — <one-line definition>
  Press Enter to accept <proposed>, or type tiny|standard|audited to override.
  ```
  Insertion point: AFTER the existing `has-ui` probe, BEFORE the slug is finalised. Same step in `request.md` flow (step 4: invoke pm subagent). PM agent prompt extension lives in `pm.md` — TPM and PM-prompt author refine the literal text at plan stage.
- **Tradeoffs accepted**: Keyword set is a known-incomplete heuristic. Tunable via PM subagent edits without changing the contract here. Wrong proposals are recoverable: PRD R12 monotonic upgrade catches under-proposed tiers; user override at the prompt catches over-proposed tiers in <1s.
- **Reversibility**: high. Keyword set lives entirely in the PM subagent; rewriting it does not touch the tier helper or any other component.
- **Requirement link**: R5, AC12. Resolves Q-CARRY-2.

### D7. Diff-threshold check fires inside `/specflow:implement`, **after wave merge, suggestion-only**
- **Options considered** (resolves Q-CARRY-1 implementation contract):
  - A. Pre-commit hook on the feature branch — fires per-commit, may upgrade mid-task.
  - B. Inside `/specflow:implement`, after each wave merge — fires at wave boundary.
  - C. Inside `/specflow:next`, when transitioning out of `implement` — fires once at end.
- **Chosen**: B (inside `/specflow:implement`, after each wave merge).
- **Why**: Wave boundary is the natural cadence — tasks within a wave are atomic, and TPM has already accepted the wave plan. Pre-commit (A) would fire on every developer subagent's intermediate commits inside worktrees, creating noise. End-of-implement (C) fires too late to influence remaining waves.
- **Action on threshold cross**: SUGGESTION ONLY (PRD R14 says "TPM decides whether to accept"). Implementation:
  1. Compute `diff_lines` and `diff_files` against `<base>` (main) for the feature branch HEAD post-merge of this wave.
  2. If `tier = tiny` AND threshold exceeded → emit a stderr WARNING + a STATUS Notes pending line: `YYYY-MM-DD implement — auto-upgrade SUGGESTED tiny→standard (diff: <N> lines, <M> files; threshold <L>/<F>); awaiting TPM confirmation`.
  3. Continue running waves. Do NOT halt. The suggestion is an out-of-band signal TPM acts on at the next planning checkpoint.
  4. TPM confirms via `set_tier <slug> standard "diff exceeded threshold"` invocation; this is the only auto-upgrade path that requires explicit human confirmation (security-must auto-upgrade, R14 bullet 2, fires immediately without confirmation per PRD).
- **Threshold tunability** (resolves Q-CARRY-1 tunability question):
  - Defaults: `SPECFLOW_TIER_DIFF_LINES=200`, `SPECFLOW_TIER_DIFF_FILES=3` (matches PRD R14).
  - **Override mechanism**: environment variables `SPECFLOW_TIER_DIFF_LINES` and `SPECFLOW_TIER_DIFF_FILES` read by `/specflow:implement` at startup. Env var, not config.yml — `.spec-workflow/config.yml` exists today (see `.spec-workflow/config.yml` in repo root) but is reserved for cross-feature config; per-run threshold override is per-invocation, which is exactly what env vars are for. Env var pattern matches existing repo conventions (no other config.yml read in any specflow command today).
- **Mid-stream behaviour**: warning, never hard upgrade. PRD R14 explicitly says "suggests" not "promotes". TPM's `set_tier` call is the only path that actually mutates the `tier:` field. Per `architect/opt-out-bypass-trace-required.md`, every `set_tier` writes a STATUS Notes audit line per R13.
- **Tradeoffs accepted**: TPM may dismiss legitimate suggestions and ship a tiny-tier feature that should have been standard. Recourse: the same feature can be upgraded at any later stage; PRD R12 monotonic guarantees the door is open.
- **Reversibility**: high. Env var defaults can change at any time without code edits.
- **Requirement link**: R14, AC9. Resolves Q-CARRY-1 (location, action, tunability).

### D8. Retired commands → deprecation stubs (per command), never silently absent
- **Options considered**:
  - A. Delete the command file entirely.
  - B. Replace contents with a deprecation stub that prints notice + exits non-zero.
  - C. Wrapper that auto-forwards to the successor (silent or with notice).
- **Chosen**: B (deprecation stub) for **all four** retired commands.
  - `/specflow:brainstorm` → stub directing user to fold exploration into PRD `## Exploration` section, suggesting `/specflow:prd <slug>` next.
  - `/specflow:tasks` → stub directing user to `/specflow:plan` (which now produces merged 05-plan.md).
  - `/specflow:verify` → stub directing user to `/specflow:validate`.
  - `/specflow:gap-check` → stub directing user to `/specflow:validate`.
- **Why**: PRD R4 says "MUST NOT cause the user to silently run an old-shape stage". Option A risks command-not-found errors that don't tell the user what to do. Option C (auto-forward) silently runs the successor — bad if the successor's output shape is meaningfully different (it is, for tasks→plan and verify+gap-check→validate). Option B is the loud, recoverable path.
- **Stub shape** (the four files have parallel structure):
  ```markdown
  ---
  description: RETIRED — see /specflow:<successor>. Usage: /specflow:<old> <slug>
  ---

  This command was retired in feature `20260420-tier-model`.
  Folded into `/specflow:<successor>`; see PRD R4 mapping.

  Action:
  - Run `/specflow:<successor> <slug>` instead.
  - The artefact `<old-file>.md` is no longer authored; <new-file>.md
    holds the merged content per the new schema.

  No STATUS mutation occurs. Exits non-zero.
  ```
- **Tradeoffs accepted**: Four files persist forever as stubs. Each is ~10 lines; total cost is negligible. Future cleanup may delete stubs after 6+ months once muscle memory adjusts (out of scope for this feature).
- **Reversibility**: high. Deleting stubs later is a per-file decision.
- **Requirement link**: R4, AC6.

### D9. `05-plan.md` is the new merged form; `06-tasks.md` is **not** authored for new-shape features
- **Options considered**:
  - A. Symlink `06-tasks.md → 05-plan.md` for backwards compat with `/specflow:implement`.
  - B. Modify `/specflow:implement` to dispatch on file presence (read 06-tasks if present, else 05-plan).
  - C. Rename existing `06-tasks.md` to `05-plan.md` across all archived features.
- **Chosen**: B (presence-based dispatch in implement).
- **Why**: PRD R7 commits this exact dispatch ("if STATUS indicates new-shape (tier field present AND `06-tasks.md` absent) → read `05-plan.md`; else fall back to `06-tasks.md`"). PRD already locked the contract; this decision is the implementation note. Symlink (A) would make `06-tasks.md` and `05-plan.md` indistinguishable to grep, hiding which shape a feature is in. Rename of archives (C) violates PRD §3 ("Archived features stay as they are").
- **Concrete dispatch in `/specflow:implement` step 1** (replaces today's "Read `06-tasks.md`"):
  ```bash
  if [ -f "$feature_dir/06-tasks.md" ]; then
    TASK_FILE="$feature_dir/06-tasks.md"           # legacy / archived feature
  elif [ -f "$feature_dir/05-plan.md" ] && \
       grep -q '^- \[ \]' "$feature_dir/05-plan.md" 2>/dev/null; then
    TASK_FILE="$feature_dir/05-plan.md"             # new merged shape
  else
    echo "ERROR: neither 06-tasks.md nor task-bearing 05-plan.md found" >&2
    exit 2
  fi
  ```
  PRD R6 already mandates `- [ ]` checkboxes remain greppable in the merged file, so the existing grep-based task scanner in `/specflow:implement` works unchanged once `TASK_FILE` is set.
- **`06-tasks.md` removal at archive**: NO. The file simply isn't authored for new-shape features. Existing archived features that have `06-tasks.md` keep it (PRD §3). No symlink, no pointer.
- **Tradeoffs accepted**: Two file shapes coexist forever. The dispatch is mechanical and tested by AC2.
- **Reversibility**: high. The dispatch is one if/elif block; future migration to a single file convention is mechanical.
- **Requirement link**: R6, R7, AC2, AC7.

### D10. `08-validate.md` replaces `07-gaps.md` + `08-verify.md`; legacy files retained on archived features
- **Options considered**: parallel to D9 — same pattern.
- **Chosen**: For new-shape features, `/specflow:validate` writes `08-validate.md` only. `07-gaps.md` and `08-verify.md` are **not** authored. Legacy archived features that have those files keep them.
- **Why**: Mirror of D9 — PRD R3 + R20 already commit the file shape. No new logic.
- **Numbering note**: `07-gaps.md` slot stays empty by convention (the number is "skipped"). Future review of feature numbering may renumber `08-validate.md` → `07-validate.md`; deferred per PRD §3 (back-fill out of scope).
- **Reversibility**: high.
- **Requirement link**: R3, R17, AC7.

---

## 4. Cross-cutting Concerns

### 4.1 Error handling

- **Tier helper** (`bin/specflow-tier`): `get_tier` emits to stdout one of `tiny|standard|audited|missing|malformed`. Never exits non-zero on classification — caller dispatches. `set_tier` exits 2 on disallowed transitions (downgrade, missing→tier-other-than-standard, malformed input). `validate_tier_transition` is a pure function (returns 0/1, no stdout).
- **Aggregator** (`bin/specflow-aggregate-verdicts`): per `architect/aggregator-as-classifier.md` — malformed verdict footer = BLOCK (fail-loud). Existing `implement.md` step-7b and `review.md` step-5 handle this today; the extracted helper inherits the same posture. Exit 0 on PASS/NITS/BLOCK (the verdict goes to stdout); exit 2 only on argument errors (no axis-set, no verdict dir, etc.).
- **Migration script** (`scripts/tier-rollout-migrate.sh`): backs up STATUS to `STATUS.md.bak` BEFORE mutate (per `no-force-on-user-paths.md`). Exits 2 on any mutation that didn't produce the expected diff (defensive — a corrupted STATUS halts the migration, doesn't compound). Idempotent: re-running on a STATUS that already has `tier: standard` is a no-op (logged as "skipped: already migrated").
- **Validate command**: per PRD R18, malformed footer = BLOCK; uses the same aggregator semantics.

### 4.2 Logging / audit

- **Tier upgrade audit** (PRD R13, AC4): `set_tier` writes one line to STATUS Notes in the format `YYYY-MM-DD <role> — tier upgrade <old>→<new>: <reason>`. `<role>` is read from a `SPECFLOW_INVOKER_ROLE` env var (set by orchestrator when invoking from agent context) or defaults to `user` if unset. This matches `architect/opt-out-bypass-trace-required.md` discipline.
- **Skip dispatch audit**: `/specflow:next` writes `<date> next — tier <t> skips <stage>` to STATUS Notes for every skipped stage. Single line per skip.
- **Auto-upgrade SUGGESTION audit** (D7): pending-confirmation suggestions are logged immediately at suggestion time, not at confirmation time. If TPM never confirms, the line stays as a record that the suggestion was emitted but not acted on.
- **`--allow-unmerged` reason** (PRD R9, AC3): logged via standard STATUS Notes line at archive time, format `<date> archive — --allow-unmerged USED: <reason>`. Matches the reviewer-bypass trace pattern.

### 4.3 Security posture

- **No new secrets, no new auth surface, no new network egress.** The feature is filesystem + STATUS.md mutations only.
- **Migration script** is the only mutation path on existing user-owned content (B2's STATUS). It backs up before write per `no-force-on-user-paths.md`. Diff after migration is asserted byte-equivalent to the expected output (one new line inserted, no other change) before commit.
- **Auto-upgrade on security-must finding** (PRD R14 bullet 2): the security reviewer's `must`-severity finding triggers immediate auto-upgrade to `audited` with no confirmation. Implementation: aggregator emits `suggest-audited-upgrade` as a side-effect signal when it sees a `severity: must` finding on `axis: security`; `/specflow:implement` step 7c catches this signal and invokes `set_tier <slug> audited "security-must finding in <task>"`. This is the one and only auto-upgrade that fires without confirmation, per PRD.

### 4.4 Testing strategy

This feature's verify is structural-only for the runtime ACs (PRD §9.1). Test layers:

- **Unit tests for `bin/specflow-tier`** (matches existing `bin/claude-symlink` test pattern from `symlink-operation`):
  - `get_tier` against fixtures: valid tier, missing field, malformed field, file-not-found.
  - `set_tier` transition matrix: every old→new pair, including disallowed.
  - `tier_skips_stage`: every (tier, stage) pair against the R10 matrix.
  - Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (the helper writes to `STATUS.md` paths under `$HOME` in the sandbox).
- **Unit tests for `bin/specflow-aggregate-verdicts`**:
  - Three reviewer-axis case (existing review aggregator parity).
  - Two validate-axis case (new).
  - Malformed-footer = BLOCK assertion.
- **Migration dry-run test**: `scripts/tier-rollout-migrate.sh --dry-run` against B2's STATUS, asserts byte-diff matches expected one-line insert.
- **Stub deprecation tests** (one per retired command): invoke the stub, assert exit non-zero + expected message text.
- **Heuristic determinism test** (D6): given a fixture set of raw asks, PM keyword scan produces the expected proposed tier deterministically.

Runtime tests deferred to B2 (PRD R20).

### 4.5 Performance / scale

Not load-bearing. Tier-helper calls are in-process bash function lookups; aggregator runs once per validate / review invocation. No hot-path concerns.

One performance note for the implement-time threshold check (D7): `git diff --shortstat <base>...<head>` and `git diff --name-only ... | wc -l` are two `git` invocations per wave. Per `.claude/rules/reviewer/performance.md` rule 3 (cache expensive operations), cache the `git diff --name-only` output to a variable and derive both counts from it:

```bash
# Compute once per wave
diff_files_list=$(git diff --name-only "$BASE...HEAD")
diff_files=$(printf '%s\n' "$diff_files_list" | wc -l)
diff_lines=$(git diff --shortstat "$BASE...HEAD" | awk '{s+=$4+$6} END {print s+0}')
```

Two `git` invocations per wave is bounded — not in a tight loop.

---

## 5. Open Questions

**None blocking.**

All four PRD carry-forward open questions are resolved at decision points D4 (Q-CARRY-3 parallel/sequential), D6 (Q-CARRY-2 prompt flow + heuristic), D7 (Q-CARRY-1 threshold check), and D9+D10 (Q-CARRY-4 mid-flight upgrade semantics). No blocker remains for `/specflow:plan`.

The §5 blocker posture rule says "only flag if PRD commits something architecturally incoherent". Nothing in PRD R1–R20 falls into that category. Several PRD requirements are non-trivial to implement but all have a clean technical path — see §6 below for the items deferred-by-design.

---

## 6. Non-decisions (deferred)

These are explicitly NOT decided here; the trigger column says when they would become decisions.

| Non-decision | Trigger to decide |
|---|---|
| Whether to renumber `08-validate.md` → `07-validate.md` | A future feature that touches the feature-numbering convention. Out of scope per PRD §3. |
| Whether to delete the four deprecation stubs (D8) after 6+ months | Retrospective sweep when stub-invocations stop appearing in STATUS Notes across a quarter of features. |
| Whether `bin/specflow-tier` should grow a `propose_tier(raw_ask)` function | Only if a non-PM caller needs to compute a proposed tier (e.g. a CI bot). PM subagent currently owns the heuristic; no second caller exists. |
| Whether `config.yml` should hold the diff thresholds instead of env vars | A future feature that introduces a `config.yml`-reading convention across multiple specflow commands. Today the file exists but no command reads it. |
| Whether to emit a third tier-helper output `legacy` distinct from `missing` | Only if a corner case appears where pre-rollout STATUS has malformed `tier:` field (typo, wrong case, etc.) and we want to distinguish "had a field but it was wrong" from "never had a field". `malformed` covers this today. |
| Whether `/specflow:validate` should support `--axis tester|analyst` to run one axis in isolation | Only if dogfood-paradox-style bootstrapping requires it (mirrors `/specflow:review --axis`). Defer until a real use case appears; the parameterised aggregator (D5) makes adding this trivial later. |
| Heuristic-keyword tuning cadence | After 3+ post-rollout features have run through `/specflow:request`. Retrospective revisits. |

## 7. Files this feature creates / modifies

For TPM's plan reference. Not exhaustive — the canonical task list lives in `05-plan.md`.

**Creates**:
- `bin/specflow-tier` (sourceable bash library; D1, D2)
- `bin/specflow-aggregate-verdicts` (extracted from existing inline aggregators; D5)
- `scripts/tier-rollout-migrate.sh` (one-shot W0 migration; D3)
- `.claude/commands/specflow/validate.md` (new command; PRD R3)
- `test/specflow-tier.sh` (unit tests; §4.4)
- `test/specflow-aggregate-verdicts.sh` (unit tests; §4.4)

**Modifies**:
- `.spec-workflow/features/_template/STATUS.md` (add `tier:` field; new stage checklist)
- `.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` (W0 migration: insert `tier: standard`)
- `.claude/commands/specflow/request.md` (parse `--tier`; invoke PM with proposal context per D6)
- `.claude/commands/specflow/next.md` (source tier helper; skip stages per matrix; per D2 dispatch table)
- `.claude/commands/specflow/implement.md` (presence-based task-file dispatch per D9; threshold check per D7; refactor step 7b to call extracted aggregator per D5)
- `.claude/commands/specflow/review.md` (refactor step 5 to call extracted aggregator per D5)
- `.claude/commands/specflow/archive.md` (merge-check + `--allow-unmerged REASON` per PRD R9)
- `.claude/commands/specflow/plan.md` (plan now produces merged 05-plan.md per PRD R6 — guidance edit; tpm subagent prompt is the load-bearing change)
- `.claude/commands/specflow/brainstorm.md` (deprecation stub per D8)
- `.claude/commands/specflow/tasks.md` (deprecation stub per D8)
- `.claude/commands/specflow/verify.md` (deprecation stub per D8)
- `.claude/commands/specflow/gap-check.md` (deprecation stub per D8)
- `.claude/agents/specflow/pm.md` (extend with tier-proposal heuristic per D6)
- `.claude/agents/specflow/tpm.md` (extend with merged-plan authoring guidance per D9)
- `.claude/agents/specflow/qa-tester.md` + `qa-analyst.md` (verdict footer header changes from `## Reviewer verdict` → `## Validate verdict` per PRD R18)

No language / framework adoption. No new third-party dependency. Total new code ≈ 1 sourceable bash lib (~120 LOC) + 1 aggregator extraction (~60 LOC of refactor) + 1 migration script (~50 LOC) + 4 deprecation stubs (~10 LOC each) + 1 new command file (~80 LOC) + tests.

---

## Team memory

Per R10/R11 — entries applied in this tech doc:

- `architect/aggregator-as-classifier.md` (local) — drives D5: extract the aggregator as a parameterised classifier rather than copy-pasting; same severity-max reduction across {security,performance,style} and {tester,analyst}.
- `architect/reviewer-verdict-wire-format.md` (local) — drives D5 and PRD R18: validate axes emit the same pure-markdown `key: value` footer shape; malformed = BLOCK is inherited.
- `shared/dogfood-paradox-third-occurrence.md` (local) — drives §1.2 and §4.4: structural-only verify in this feature, runtime exercise on B2 per PRD R20.
- `architect/script-location-convention.md` (global) — drives D1 and D3: `bin/` for the sourceable tier helper and the aggregator CLI; `scripts/` for the one-shot migration.
- `architect/classification-before-mutation.md` (global) — drives D2: tier reader is a pure five-state classifier; mutation lives only in `set_tier` dispatch.
- `architect/no-force-by-default.md` (global) — drives §4.1 and §4.3: migration script backs up STATUS before write; no `--force` flag added anywhere.
- `architect/shell-portability-readlink.md` (global) — drives §1.1 and all bash decisions: bash 3.2 / BSD discipline, no GNU coreutils dependency.
- `architect/opt-out-bypass-trace-required.md` (local) — drives §4.2: `--allow-unmerged REASON` and every `set_tier` invocation write a STATUS Notes audit line.
