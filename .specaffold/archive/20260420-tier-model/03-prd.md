# PRD — tier-model

**Feature**: `20260420-tier-model`
**Stage**: prd
**Author**: PM
**Date**: 2026-04-20

## 1. Summary

specflow today runs a single ~10-stage flow for every feature, regardless of
size or risk. Small changes (typo, one-function tweak, copy fix) pay the same
planning tax as cross-module work; high-risk changes (auth, payment, breaking
API) get no extra audit surface above the default. This feature introduces a
**three-tier model** — `tiny` / `standard` / `audited` — declared at request
time and threaded through every stage dispatch. It also bundles three stage
consolidations that share the same STATUS schema and command surface:
`brainstorm` folds into PRD, `plan`+`tasks` merge into a single `05-plan.md`,
and `verify`+`gap-check` merge into a new `/specflow:validate` stage with two
parallel axes.

The feature itself runs as `standard` tier under a **hybrid self-bootstrap**:
earliest stages (request / brainstorm / prd / tech) use the old-shape
artefacts because the consolidated tooling does not yet exist; later stages
(plan / validate) author under the new merged shape as a convention-adoption
exercise. Runtime exercise of the new `/specflow:next`, `/specflow:plan`,
`/specflow:validate`, `/specflow:archive --allow-unmerged`, and the tier
dispatch table is **deferred to the next feature after archive** —
`20260420-flow-monitor-control-plane` (B2), which is frozen at `request` until
this feature archives.

## 2. Goals

- Every new feature declares a tier at `/specflow:request` time; tier is
  persisted in `STATUS.md` and read by `/specflow:next` to decide which stages
  apply.
- `tiny` tier reaches archive in ≤ 5 mandatory stages; `standard` in ≈ 7;
  `audited` in ≈ 9.
- Retired commands (`brainstorm`, `tasks`, `verify`, `gap-check`) stop
  appearing as mandatory stages; their content lives in the consolidated
  artefacts.
- Tier upgrades are one-way, audit-logged, and never silently re-seed prior
  stage artefacts.
- `standard` / `audited` features cannot archive on an unmerged branch without
  an explicit `--allow-unmerged REASON` escape hatch.
- This feature dogfoods the new **authoring shape** for plan + validate
  artefacts within its own directory (structural dogfood); the next feature
  exercises the new **dispatch** at runtime.

## 3. Non-goals

- Agent role consolidation (7 roles remain: pm / architect / tpm / designer /
  developer / qa-analyst / qa-tester). Merging pm+tpm or
  qa-analyst+qa-tester is explicitly deferred.
- New reviewer axes (e.g. `refactor-opportunity`). Existing three axes
  (security / performance / style) unchanged.
- Back-filling the `tier:` field into archived STATUS files. Archived features
  stay as they are.
- Cross-feature orchestration (e.g. "upgrade all stalled features one tier").
- Auto-downgrade. Tier is monotonic by design — a rule, not a gap.
- Calibrating the auto-upgrade thresholds from archive data (see §6 Q-CARRY-1).
  Starting values committed here; retrospective-driven tuning is out of scope
  for this feature.
- Inventing a new aggregator for `/specflow:validate` divergent from the
  review aggregator contract. Reuse with parameterised axis set is the only
  shape this PRD admits (see R17).

## 4. Users and scenarios

**Primary users**: the specflow orchestrator and the 7 agent roles that run
inside it. Secondary users: the human developer invoking commands and reading
STATUS.

### 4.1 Scenarios

| # | Actor | Scenario | Tier outcome |
|---|---|---|---|
| S1 | Developer | `/specflow:request "fix typo in README"` without `--tier` | PM proposes `tiny`; one-key confirm; feature skips tech/design/review |
| S2 | Developer | `/specflow:request --tier audited "rotate OAuth secrets"` | `tier: audited` written at request; exploration section required in PRD; all three reviewer axes mandatory before archive |
| S3 | Developer | `/specflow:request "add dashboard page"` (no `--tier`) | PM proposes `standard`; confirmed silently; default path |
| S4 | TPM | At plan stage sees feature will need 20+ tasks across 4 waves; current tier is `tiny` | TPM upgrades to `standard`; STATUS note logs role, date, old→new, reason |
| S5 | Reviewer (security axis) | Emits `must` finding on a `standard` feature | Auto-upgrade to `audited`; STATUS note logs trigger |
| S6 | Developer | `/specflow:archive` on a `standard` feature whose branch isn't merged | Archive refuses; prints error; exit non-zero |
| S7 | Developer | `/specflow:archive --allow-unmerged "multi-PR split"` on same feature | Archive accepts; `--allow-unmerged` reason logged to STATUS Notes |
| S8 | Developer | Runs `/specflow:brainstorm` after retirement | Either deprecation notice forwarding to `/specflow:prd`, or command absent entirely (architect picks; R10) |
| S9 | Developer | B2 (in-flight at `request`) is touched for the first time after this feature archives | B2's STATUS already has `tier: standard` from W0 migration pass; no manual edit needed |
| S10 | Developer | Upgrades a `tiny` feature to `standard` mid-flight after PRD was a one-liner | Upgrade writes STATUS note; PRD artefact is NOT re-seeded; developer manually fleshes out PRD via `/specflow:update-req` |

## 5. Requirements

Grouped by surface: **Schema** (R1–R2), **Commands — new** (R3), **Commands —
retired** (R4), **Commands — modified** (R5–R9), **Dispatch contract**
(R10–R11), **Governance** (R12–R16), **Validate contract** (R17–R18),
**Dogfood** (R19–R20).

### 5.1 Schema

**R1 — `tier:` field on STATUS**
Every `STATUS.md` authored by `/specflow:request` on or after rollout MUST
include a `tier:` field in the header block, with value in the closed set
`{tiny, standard, audited}`. The field lives between `has-ui:` and `stage:` in
the header block. Absence of the field on a feature created after rollout is a
schema violation.

**R2 — Migration of in-flight features**
On rollout (W0 of this feature's implement), any feature currently under
`.spec-workflow/features/` whose STATUS lacks a `tier:` field MUST have
`tier: standard` inserted automatically. Archived features MUST NOT be
touched. At time of rollout the only in-flight feature besides tier-model
itself is `20260420-flow-monitor-control-plane` (B2), which migrates to
`tier: standard` by this rule.

### 5.2 Commands — new

**R3 — `/specflow:validate`**
A new command `/specflow:validate <slug>` MUST exist that fires `qa-tester`
(dynamic axis) and `qa-analyst` (static axis) **in parallel**, collects their
verdict footers, and aggregates to a single stage verdict per the aggregator
contract in R17. Output artefact is `08-validate.md` containing both axes'
findings and the aggregated verdict. Verdict values: `PASS` / `NITS` /
`BLOCK`, matching the review aggregator semantic.

### 5.3 Commands — retired

**R4 — Retirement of `brainstorm`, `tasks`, `verify`, `gap-check`**
The four commands `/specflow:brainstorm`, `/specflow:tasks`,
`/specflow:verify`, `/specflow:gap-check` MUST be retired as mandatory stages.
Each MUST either (a) emit a deprecation notice pointing to its successor and
exit non-zero, or (b) be absent from the command registry entirely. Architect
picks per command at tech stage; the PRD contract is only that invoking any of
these MUST NOT cause the user to silently run an old-shape stage. Mapping:
- `/specflow:brainstorm` → folded into `/specflow:prd` `## Exploration` section
- `/specflow:tasks` → folded into `/specflow:plan`
- `/specflow:verify` → folded into `/specflow:validate`
- `/specflow:gap-check` → folded into `/specflow:validate`

### 5.4 Commands — modified

**R5 — `/specflow:request --tier`**
`/specflow:request` MUST accept an optional `--tier <tiny|standard|audited>`
flag. When the flag is omitted, PM MUST propose a tier based on the raw ask
(plus the existing intake probes for why-now / success / out-of-scope) and
present it as a **propose-and-confirm** default. Silent acceptance adopts the
proposed tier; the user may type a different tier to override. PM MUST NOT
silently default without proposing; PM MUST NOT block indefinitely on user
input. Inference heuristics are a tech-stage concern (see §6 Q-CARRY-4).

**R6 — `/specflow:plan` absorbs tasks**
`/specflow:plan` MUST produce a single `05-plan.md` artefact containing both
the wave narrative and the task checklist. `06-tasks.md` MUST NOT be authored
for new-shape features. The checklist section MUST remain greppable by
`/specflow:implement` (i.e. `- [ ]` checkboxes at the task level).

**R7 — `/specflow:implement` reads merged plan**
`/specflow:implement` MUST read the task checklist from `05-plan.md` when the
feature's STATUS indicates a new-shape feature (tier field present AND
`06-tasks.md` absent). For archived or legacy features that still have
`06-tasks.md`, `/specflow:implement` MUST fall back to reading from
`06-tasks.md`. The dispatch MUST be deterministic (no guessing heuristic; key
off presence/absence of `06-tasks.md` + `tier:` field).

**R8 — `/specflow:next` is tier-aware**
`/specflow:next` MUST read the feature's `tier:` field and skip stages
retired for that tier per the stage matrix in §5.5. For `tiny`, stages
`brainstorm`, `tech`, `design`, `review` MUST be skipped. For `standard`,
stage `brainstorm` is folded into PRD (skipped as a standalone stage); `design`
is conditional on `has-ui: true`. For `audited`, all stages in the matrix are
mandatory. `/specflow:next` MUST write a STATUS note indicating which stages
were skipped and why (tier `<t>` skips `<stage>`).

**R9 — `/specflow:archive` merge-check**
`/specflow:archive` MUST refuse to archive a `standard` or `audited` feature
whose current branch is not merged to `main` (as determined by
`git merge-base --is-ancestor <branch> main`). The refusal MUST print the
current branch and the main ref, exit non-zero, and leave the feature
unmodified. `tiny` tier MUST NOT trigger the merge-check. The escape hatch
`--allow-unmerged REASON` MUST accept a required positional REASON argument;
invoking `--allow-unmerged` without a reason MUST exit non-zero with a usage
error. The REASON string MUST be appended to STATUS Notes with date and role.

### 5.5 Dispatch contract

**R10 — Stage matrix**
The tier→stage dispatch table MUST match this matrix (✅ required, 🔵
optional, ⚫ conditional on `has-ui: true`, — skipped):

| Stage | tiny | standard | audited |
|---|:---:|:---:|:---:|
| request | ✅ | ✅ | ✅ |
| brainstorm | — | — (folded into PRD) | ✅ (PRD `## Exploration` mandatory) |
| prd | ✅ (1-liner allowed) | ✅ | ✅ |
| tech | — | ✅ | ✅ |
| plan | 🔵 | ✅ | ✅ (fine-grained wave split) |
| design | — | ⚫ | ✅ |
| implement | ✅ | ✅ | ✅ |
| validate | ✅ (tester-only default) | ✅ (both axes) | ✅ (both axes) |
| review | 🔵 | 🔵 | ✅ (all 3 axes mandatory) |
| archive | ✅ | ✅ (merge-check) | ✅ (merge-check strict) |

**R11 — Single tier-reading helper**
A single helper function MUST be the only code path that reads the `tier:`
field from `STATUS.md`. All other scripts, agents, and commands MUST route
through this helper. This is enforced by code-review discipline, not a
runtime check. Architect names the helper at tech stage; the contract is one
function, one parse site.

### 5.6 Governance

**R12 — Monotonic upgrade**
Tier upgrades MUST be one-way: `tiny → standard → audited`. Downgrade MUST be
refused by every command that could write the `tier:` field. Attempts to
downgrade MUST print an error and exit non-zero.

**R13 — Upgrade audit trail**
Every tier change MUST write a STATUS Notes line with the format:
`YYYY-MM-DD <role> — tier upgrade <old>→<new>: <trigger-reason>`. The
trigger-reason is free-text; common values include `TPM veto at plan`,
`security BLOCK auto-upgrade`, `diff exceeded threshold`. No tier change is
valid without this note.

**R14 — Auto-upgrade triggers**
The following triggers MUST apply:
- `/specflow:implement` detects diff exceeding **200 lines OR > 3 files**
  against the feature's base branch → suggests `tiny → standard`. TPM decides
  whether to accept. (Starting values; see §6 Q-CARRY-1 for tuning cadence.)
- Any reviewer returns a `must`-severity finding on the **security** axis →
  auto-upgrade to `audited`. No confirmation; upgrade is written immediately
  with trigger reason `security-must finding`.
- PRD touches paths in the security-sensitive set (auth, secrets,
  `settings.json`) → PM suggests `audited` at PRD time. The path set is
  enumerated at tech stage; PRD only mandates the trigger exists.

**R15 — Mid-flight upgrade does not re-seed artefacts**
A tier upgrade MUST NOT automatically re-author, re-template, or delete any
existing stage artefact (`03-prd.md`, `05-plan.md`, etc.). Artefact alignment
with the new tier is the responsibility of the next stage author, via
`/specflow:update-req` for PRD or `/specflow:update-tech` for tech. Rationale:
automatic re-seeding would either destroy existing content or produce
merge-conflict-style artefacts that nobody wants to resolve.

**R16 — `tiny` inline review default**
`/specflow:implement` on a `tiny`-tier feature MUST default to
`--skip-inline-review`. Users may opt in with `--inline-review`. On `standard`
and `audited`, the default MUST be to run inline review.

### 5.7 Validate contract

**R17 — Aggregator reuse**
`/specflow:validate` MUST aggregate its axis verdicts using the **same
aggregator contract** as `/specflow:review` (see
`architect/aggregator-as-classifier.md` and
`architect/reviewer-verdict-wire-format.md`). The implementation MUST
parameterise the axis set so that `/specflow:review` passes
`{security, performance, style}` and `/specflow:validate` passes
`{tester, analyst}`. Any divergence from the review aggregator's classifier
semantic (any BLOCK → BLOCK; all PASS → PASS; else NITS) MUST be treated as
a BLOCK (fail-loud) per the existing wire-format rule.

**R18 — Validate verdict wire format**
The `08-validate.md` artefact MUST include a `## Validate verdict` footer
with `axis: <name>` and `verdict: PASS|NITS|BLOCK` for each axis, plus an
aggregated top-level verdict. Malformed footers (missing header, missing
verdict key, verdict outside the closed set) MUST parse as BLOCK.

### 5.8 Dogfood (hybrid self-bootstrap)

**R19 — Hybrid self-bootstrap shape**
This feature's own artefacts MUST be authored under a **hybrid** shape:
earliest stages under old shape (because the new tooling does not yet
exist), later stages under new merged shape (because these are pure-authoring
disciplines that need no runtime tooling). The explicit mapping:

| Artefact | Shape | Rationale |
|---|---|---|
| `00-request.md` | old | `/specflow:request` ran before any new-shape tooling existed |
| `01-brainstorm.md` | old (standalone) | Last standalone brainstorm in the repo; serves as the exploration input for PRD |
| `03-prd.md` (this file) | old | PRD authored before `/specflow:plan` exists; no `## Exploration` section needed since `01-brainstorm.md` carries that content |
| `04-tech.md` | old | Architect stage predates new tooling |
| `05-plan.md` | **new merged shape** | Narrative + checklist in one file; no `06-tasks.md`. TPM authors manually; no `/specflow:plan` required |
| `08-validate.md` | **new merged shape** | Tester + analyst axes in one file; no separate `07-gaps.md` + `08-verify.md`. QA authors manually; no `/specflow:validate` required |
| `STATUS.md` stage checklist | **new shape** | Retire `tasks`, `gap-check`, `verify` boxes; add `validate` |

**R20 — Runtime exercise deferred to B2**
Runtime verification of the retired-command dispatch, tier-aware
`/specflow:next`, `/specflow:plan` command, `/specflow:validate` command,
`/specflow:archive` merge-check, and the interactive tier-proposal prompt
MUST be deferred to the next feature after archive
(`20260420-flow-monitor-control-plane`, B2). B2's archive notes MUST confirm
that each of the above fired end-to-end on B2's first real session and
produced the expected effect. Failure of any runtime exercise on B2 is a
signal to issue a follow-up fix feature, not to re-open this feature.

## 6. Acceptance criteria

Every AC traces to at least one R and is annotated
`[Verification: structural | runtime | both]`. Structural coverage is
discharged by this feature's own verify stage; runtime coverage is discharged
by B2 (see R20 and §9 Dogfood paradox).

**AC1** — STATUS schema present [R1, R2] [structural]
Opening any feature's `STATUS.md` created by `/specflow:request` after
rollout shows a `tier:` field in the header with a value from
`{tiny, standard, audited}`. Running the W0 migration pass against
`.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md`
results in a `tier: standard` line being present in that file with no other
content changed.

**AC2** — Tier-aware dispatch [R8, R10] [both]
*Structural*: a unit-test table driven off `get_tier` for each tier value
produces the expected next-stage output per the R10 matrix. `tiny` never
returns `brainstorm|tech|design|review` as next; `audited` never returns any
of those as skipped. *Runtime*: B2 runs `/specflow:next` at each stage
transition and the stage sequence observed matches the standard-tier column
of R10.

**AC3** — Archive merge-check [R9] [both]
*Structural*: a mock git repo unit test with a `standard` feature on an
unmerged branch causes `/specflow:archive` to exit non-zero with a
branch-vs-main diagnostic; the same test with `--allow-unmerged "test"`
passes and writes the reason to STATUS Notes. A `tiny` feature on the same
unmerged branch archives cleanly. *Runtime*: B2's archive runs the
merge-check on a real branch.

**AC4** — Upgrade audit log [R12, R13] [both]
*Structural*: invoking the tier-upgrade helper with `standard → audited`
appends a STATUS Note in the R13 format. Invoking with `standard → tiny`
exits non-zero with no STATUS mutation. *Runtime*: any real tier upgrade in
B2 or subsequent features produces a parseable audit line.

**AC5** — B2 migration zero-touch [R2] [both]
*Structural*: running the W0 migration pass with B2's current STATUS as
input produces a STATUS with `tier: standard` inserted between `has-ui:` and
`stage:` and no other diff. *Runtime*: first `/specflow:next` invocation on
B2 after rollout reads `tier: standard` via the helper (R11) and routes to
the standard-tier column of the matrix.

**AC6** — Retired commands dispatch [R4] [both]
*Structural*: each retired command (`brainstorm`, `tasks`, `verify`,
`gap-check`) either is absent from the command registry or its entry
contains a deprecation notice pointing to the successor. The mapping matches
R4. *Runtime*: user invokes each retired command name in B2's session; the
observed behaviour matches the architect's chosen disposition per command
(deprecation notice or command-not-found).

**AC7** — Self-bootstrap hybrid dogfood [R19, R20] [structural only;
runtime deferred to B2]
This feature's own directory on archive MUST contain:
- `00-request.md`, `01-brainstorm.md`, `03-prd.md`, `04-tech.md` in old shape
- `05-plan.md` in **new merged shape** (narrative + task checklist in one
  file; no `06-tasks.md` present in this feature's directory)
- `08-validate.md` in **new merged shape** (tester + analyst axes in one
  file; no `07-gaps.md` + separate `08-verify.md`)
- `STATUS.md` stage checklist showing `plan` and `validate` boxes (no
  `tasks`, `gap-check`, `verify` boxes)

Runtime exercise of `/specflow:plan` and `/specflow:validate` commands is
**deferred to B2** per R20 — B2 is the first feature authored by the
commands rather than by hand under the new shape. Archive of this feature
MUST note this deferral in STATUS.

**AC8** — Validate aggregator contract [R17, R18] [both]
*Structural*: a unit test passes three scripted axis replies
(`{PASS, PASS}`, `{PASS, BLOCK}`, `{NITS, PASS}`, `{malformed, PASS}`) to
the parameterised aggregator and confirms the aggregate verdicts match the
classifier semantic (`BLOCK`, `BLOCK`, `NITS`, `BLOCK` — malformed counts as
BLOCK). *Runtime*: B2's first `/specflow:validate` run emits a
`08-validate.md` whose header and per-axis verdict footers parse cleanly
under the wire-format rule.

**AC9** — Auto-upgrade triggers [R14] [both]
*Structural*: three independent unit tests fire each trigger (diff
>200-lines-OR->3-files, security-must finding, PRD in sensitive path) and
observe a STATUS upgrade note. The diff-trigger test MUST cover both
sub-conditions (a 250-line single-file diff and a 100-line diff across 5
files). *Runtime*: any B2 implement that crosses a threshold surfaces the
suggestion in TPM's session output.

**AC10** — Mid-flight upgrade non-destructive [R15] [structural]
After an upgrade from `tiny` to `standard` on a mock feature with a
one-line PRD, the PRD file on disk is byte-identical to its pre-upgrade
contents. The STATUS file has exactly one line added (the audit note) and
exactly one field mutated (`tier:`).

**AC11** — `tiny` inline review default [R16] [both]
*Structural*: `/specflow:implement` dry-run on a `tiny` feature without an
explicit `--inline-review` flag prints that inline review is skipped.
`/specflow:implement` dry-run on a `standard` feature without flag prints
that inline review will run. *Runtime*: any B2 `tiny`-tier follow-up would
confirm.

**AC12** — Interactive tier-proposal prompt [R5] [both]
*Structural*: `/specflow:request` invoked without `--tier` produces a PM
prompt text that contains a proposed tier value and an invitation for
confirmation or override. The proposal is deterministic given the same raw
ask input for testing. *Runtime*: B2's original request (already at
`request` stage before rollout) is a pre-rollout case and does not exercise
this AC at runtime; the first post-rollout feature request does.

## 7. Open questions (PRD-blocking)

**None.**

All four carry-forward open questions from brainstorm §7 are either
architect/tech-stage concerns or starting-value tunables that do not block
PRD. They are recorded in §8 below rather than as blockers.

## 8. Carry-forward open questions (not PRD-blocking)

These are resolved at downstream stages; listed here for continuity. PM does
not need further input to finalise PRD.

- **Q-CARRY-1** (from brainstorm Q-LB-3) — Exact diff-threshold numbers.
  PRD commits `200 lines OR > 3 files` as starting values (R14). Tuning
  cadence: retrospective-driven review after 3 `tiny`-intent features have
  shipped. Tech stage MAY refine; retrospective-stage review MUST revisit.
- **Q-CARRY-2** (from brainstorm Q-LB-1 Option 3 hybrid) — Resolved in
  PRD at R19 via the artefact-shape table. TPM and QA have the explicit
  list of which files this feature's own directory authors under which
  shape. Not a blocker.
- **Q-CARRY-3** (from brainstorm stress-test of consolidation 3) —
  Architect's call at tech stage: can `qa-tester` and `qa-analyst` run
  truly in parallel, or does any correctness dependency force sequential
  dispatch? PRD is neutral: R17 only mandates aggregator reuse and axis
  parameterisation; whether the two agents run concurrently or sequentially
  is an implementation detail. If architect finds a dependency, document it
  in `04-tech.md`.
- **Q-CARRY-4** (from brainstorm Q-LB-4) — PM tier-proposal heuristics
  (keyword set, scope-probe phrasing). PRD commits the shape
  (propose-and-confirm) at R5; the specific heuristics are tech-stage
  territory.

## 9. Edge cases

### 9.1 Dogfood paradox

This feature ships the tier schema, the tier-aware `/specflow:next`
dispatch, the new `/specflow:plan` / `/specflow:validate` commands, the
retired-command dispatch, the archive merge-check, and the tier-proposal
prompt. All of these are mechanisms the feature would invoke — and none
exist until after merge. Per
`shared/dogfood-paradox-third-occurrence.md`:

**Structural-only coverage in this feature** (verified at this feature's
own validate stage):
- AC1 (schema field present on STATUS)
- AC3 (mock-repo merge-check)
- AC4 (upgrade helper STATUS note format)
- AC5 (B2 migration pass dry-run)
- AC6 (retired-command file present/absent checks)
- AC7 (self-bootstrap artefact-shape checks — structural only by design;
  AC7 is the canonical structural dogfood AC)
- AC8 (aggregator unit tests with scripted inputs)
- AC9 (auto-upgrade unit tests)
- AC10 (mid-flight upgrade byte-diff check)
- AC11 (dry-run flag inspection)
- AC12 (prompt text inspection)

**Runtime coverage deferred to B2** (`20260420-flow-monitor-control-plane`,
first feature after archive):
- AC2 (tier-aware `/specflow:next` on a real standard-tier run)
- AC3 (real merge-check on B2's branch at archive)
- AC4 (any real upgrade event in B2 flow)
- AC5 (B2's first `/specflow:next` after migration)
- AC6 (user invokes retired commands in session)
- AC7 (first feature authored by the new commands rather than by hand —
  this is structural-only in THIS feature by construction; runtime is B2's
  whole lifecycle)
- AC8 (B2's first `/specflow:validate` emits parseable footer)
- AC9 (any trigger fires in B2)
- AC11 (B2 `tiny`-tier follow-up, if any)
- AC12 (B2's original request is pre-rollout; first post-rollout feature
  exercises this)

Failure of any runtime exercise on B2 is a signal for a follow-up fix
feature, NOT for re-opening this feature's verdict. Follows the third-
occurrence pattern precedent (B1 SessionStart, B2.a Stop hook, B2.b inline
reviewers).

### 9.2 B2 frozen at request — sequencing lock

B2 (`20260420-flow-monitor-control-plane`) is currently at `request` stage
and MUST NOT advance past `request` until this feature archives. B2's
eventual advance will exercise the new shape end-to-end; advancing B2 on
the old shape would leave a stale one-off in the repo and undermine AC7's
runtime handoff. The freeze is a process rule, not a code-enforced rule;
relied on PM/user discipline.

### 9.3 First-time dogfood execution state

Per the sixth occurrence of the dogfood-paradox memory: dogfood execution
always reveals something that synthetic sandboxes miss. Plan for at least
one dogfood-surfaced fix feature after B2 exercises the new commands; do
not treat such a fix as a process failure.

### 9.4 Monotonic upgrade and misclassification

If PM's tier proposal is wrong at request time (e.g. proposed `tiny` for
what turns out to be a module-scale change), the monotonic upgrade rule
(R12) means the misclassification is always recoverable: TPM, reviewer, or
auto-trigger (R14) bumps the tier up. There is no downgrade path — scope
shrinks do not dial ceremony back down. Rationale: downgrade would enable
gaming (shrink the PRD at the last minute to skip review).

### 9.5 Retired-command collision with muscle memory

Users who invoke `/specflow:brainstorm` or `/specflow:tasks` out of habit
after rollout will either see a deprecation notice (R4 option a) or a
command-not-found error (R4 option b). Neither silently runs the old
stage. Architect picks per command at tech stage.

## 10. Out of scope (recap)

Carried from intake §Out of scope and draft §7; brainstorm added no new
exclusions. Repeated here for a single canonical list:

- Agent role consolidation (pm+tpm, qa-analyst+qa-tester, etc.).
- New reviewer axes beyond the current three.
- Back-filling `tier:` into archived STATUS files.
- Cross-feature orchestration (bulk tier-bump across features).
- Auto-downgrade of tier (monotonic-upgrade rule R12 is a design, not a gap).
- Calibrating auto-upgrade thresholds from archived-feature histogram
  (starting values in R14 are explicit commitments; tuning is
  retrospective-driven, not PRD-driven).
- Inventing a distinct aggregator for `/specflow:validate` beyond the
  parameterised-reuse contract in R17.
- Re-seeding stage artefacts on tier upgrade (R15 is a design commitment to
  NOT do this; any re-seeding tooling is out of scope).
