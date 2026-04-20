# Brainstorm — tier-model

**Feature**: `20260420-tier-model`
**Stage**: brainstorm
**Author**: PM
**Date**: 2026-04-20

Context is in `00-request.md` + `.spec-workflow/drafts/tier-model.md` (full
discussion). This brainstorm does not restate the draft; it **stress-tests
the draft's assumptions** and explores alternatives where the draft committed
without exploring.

Five questions are load-bearing for PRD (Q-LB-1…Q-LB-5). Four are
non-load-bearing (Q-NLB-1…Q-NLB-4) and get short-form recommendations.

---

## 1. Summary of the draft's shape (recap for orientation)

Three tiers (`tiny` / `standard` / `audited`), declared at `/specflow:request`
time, monotonic upgrade-only. Three consolidations bundled in: `brainstorm`
folds into PRD `## Exploration`; `plan`+`tasks` merge into one `05-plan.md`;
`verify`+`gap-check` merge into `/specflow:validate` with parallel
tester+analyst axes. Seven user-visible command changes, one STATUS schema
change.

**Blast radius**: single `features/` subsystem, plus `.claude/commands/specflow/`
and `.claude/agents/specflow/`. No reviewer-axis changes. No agent-role
consolidation.

**Sequencing lock**: `20260420-flow-monitor-control-plane` (B2) is frozen at
`request` stage. This feature must archive before B2 enters brainstorm.

The draft is well-developed. Brainstorm's job is to validate the tier count,
pressure-test the consolidations, and pick explicit postures for the open
questions the draft deferred to this stage.

## 2. Alternative shapes considered (and rejected)

### Shape A — status quo + `--light` flag (rejected)

Keep one flow, add `/specflow:request --light` that skips brainstorm / tech /
review. Smaller diff; no schema change.

*Why rejected*: Doesn't address the rigour-dial-up need (`audited` tier has no
home). Flag semantics drift — `--light` at request time doesn't bind
`/specflow:next`, `/specflow:archive`, etc. Ends up re-inventing the tier
field under a worse name.

### Shape B — two tiers only (`light` / `default`) (rejected)

Drop `audited`. Rationale the draft considered: maybe nobody actually needs a
stricter tier; `standard` + mandatory `/specflow:review` is already strict.

*Why rejected*: The rigour-dial-up axis is the **other half** of the stated
problem. Shipping only a dial-down erases half the user ask. Same pattern as
the B1-only shipment of flow-monitor — see
`pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md`. Draft
is right to ship all three tiers.

### Shape C — continuous rigour knobs instead of discrete tiers (rejected)

`--brainstorm=on/off`, `--tech=on/off`, `--review=mandatory/on-demand/off`.
More flexible; no tier lock-in.

*Why rejected*: Combinatorial explosion in `/specflow:next` dispatch, worse
discoverability, and auto-upgrade triggers (security BLOCK → `audited`) lose
their anchor — what does "upgrade" mean with continuous knobs? The tier
abstraction is the thing that lets `/specflow:next` be a simple enum switch
and audit-log upgrades as a single-field delta. Keep discrete tiers.

### Shape D — adopt OpenSpec's 3-stage flow as the new `tiny` (confirmed)

This is what the draft already does. Explicitly validating: `tiny` =
OpenSpec-equivalent shape (`request` → `prd` 1-liner → `plan` → `implement` →
`archive`). No separate `tech`, no `brainstorm`, no `review`, no `validate`
(verify-only).

*Verdict*: Confirm. No alternative considered.

---

## 3. Load-bearing open questions

### Q-LB-1 — Self-bootstrap paradox (Q8 from intake)

**Problem**: This feature ships the tier schema + consolidated commands. AC7
of the draft says tier-model itself runs as `standard`. But `standard`
requires:

- `brainstorm` folded into PRD `## Exploration` — the very convention this
  feature introduces.
- `plan` + `tasks` merged into one `05-plan.md` — the very convention this
  feature introduces.

We cannot author under the new shape before the new shape exists. Or can we?

**Option 1: Author under the OLD shape throughout, retrofit at archive.**

Run the feature using today's `00-request.md` / `01-brainstorm.md` / `03-prd.md`
/ `04-tech.md` / `05-plan.md` / `06-tasks.md` split. At implement time, ship
the new commands. At archive time, the feature's artefacts are frozen in the
old shape.

- **Pro**: Zero chicken-and-egg risk. Every stage can run under known tooling.
- **Pro**: No retroactive edits to this feature's own artefacts — clean git
  history.
- **Con**: The feature ships the consolidation but does not demonstrate it on
  itself. AC7 ("dogfood standard tier") becomes structural-only.
- **Con**: The PR diff is "ship new shape; old shape still in use for this
  feature" which is a weird signal.

**Option 2: Author under the NEW shape from the outset.**

Write `03-prd.md` with `## Exploration` section (absorbing this brainstorm).
Write `05-plan.md` with tasks checklist in one file (no separate `06-tasks.md`).
Don't write `07-gaps.md` + `08-verify.md` separately — write `08-validate.md`.

- **Pro**: Dogfoods the new shape end-to-end. AC7 becomes literal.
- **Pro**: Clean "new way or nothing" signal in the PR.
- **Con**: `/specflow:plan` doesn't exist yet — TPM has to author by hand.
- **Con**: `/specflow:validate` doesn't exist yet — QA stages have to run
  manually.
- **Con**: If the feature fails mid-flight, restart under old shape is
  awkward — artefacts are in new shape, but the tools expect old shape.
- **Con**: Pure paradox — no `/specflow:next` in the feature's own session
  knows how to skip the retired stages because the retirements ship AS PART
  of this feature.

**Option 3: Hybrid — author under old shape, BUT introduce the new artefact
names in parallel.**

Write `00-request.md` + `01-brainstorm.md` + `03-prd.md` + `04-tech.md` under
old shape. At plan stage, write `05-plan.md` **in the new merged shape**
(narrative + checklist in one file) rather than splitting into `05-plan.md`
and `06-tasks.md`. At QA stage, write a single `08-validate.md` rather than
split `07-gaps.md` + `08-verify.md`. The commands `/specflow:plan` and
`/specflow:validate` don't exist yet when this feature's own plan/QA stages
run, so TPM/QA compose those artefacts **manually** under the new names,
referencing the schema this feature defines.

- **Pro**: Artefacts in the repo show the new shape in action — future
  features have a reference example.
- **Pro**: No new tooling needed for stages that run BEFORE the tooling lands
  (request / brainstorm / PRD / tech — all use existing commands).
- **Pro**: Stages that run AFTER their own implement (plan written, then
  developer implements, then QA runs) can use the new shape because by the
  time QA runs, the feature's own W1 has landed the new commands. But
  practically, TPM can author `05-plan.md` by hand without needing
  `/specflow:plan` to exist — it's just a markdown file.
- **Con**: Slightly inconsistent — some artefacts new-shape, some old-shape.
- **Con**: Requires STATUS checklist to be hand-edited to reflect the new
  stage names for this feature (but STATUS is hand-edited anyway per
  stage-bookkeeping discipline).

**Recommendation: Option 3 (hybrid).** Reasoning:

1. The earliest stages (`request`, `brainstorm`, `prd`, `tech`) **must** run
   under old shape because this feature's tooling doesn't exist yet. No way
   around that. Option 2 is literally unbuildable for those stages.
2. The later stages (`plan`, QA, `archive`) are pure markdown authoring — no
   tool is strictly required. TPM writing `05-plan.md` with the new merged
   shape is a typing exercise, not a tooling dependency.
3. The key insight: the dogfood discipline this feature is introducing is a
   **convention about which file holds which content**, not a runtime behaviour.
   Conventions can be adopted by authoring-discipline without the tooling
   having shipped.
4. Keeps the dogfood paradox aligned with the shared memory
   `shared/dogfood-paradox-third-occurrence.md`: structural verification
   this feature, runtime exercise next feature (B2).

**PRD implication**: AC7 should split into AC7.a (structural — new-shape
artefacts present in this feature's own directory) and AC7.b (runtime —
next feature `/specflow:request --tier standard` succeeds and
`/specflow:plan` produces a merged `05-plan.md`). AC7.b is deferred to B2.

**Flagged to PRD**: list which specific artefacts this feature authors under
new shape vs old shape. Proposal:

| Artefact | Shape |
|---|---|
| `00-request.md` | old |
| `01-brainstorm.md` | old (this file) |
| `03-prd.md` | old (no `## Exploration` section — this `01-brainstorm.md` stands) |
| `04-tech.md` | old |
| `05-plan.md` | **new merged shape** (narrative + checklist, no `06-tasks.md`) |
| `08-validate.md` | **new merged shape** (analyst + tester axes, no separate `07-gaps.md`) |
| `STATUS.md` stage checklist | **new** (retire `tasks`, `gap-check`, `verify` boxes; add `validate`) |

### Q-LB-2 — Dogfood paradox split: which ACs are structural vs runtime (Q6)

**Problem**: Same as Q-LB-1 from a different angle. The draft's AC list (AC1–AC7)
mixes structural ACs ("STATUS has `tier:` field") with runtime ACs ("`/specflow:next`
skips retired stages"). Which ACs can verify on this feature's own artefacts
(structural), vs which require the next feature (B2) actually running the new
commands to confirm (runtime)?

**Approach**: apply the shared dogfood-paradox rule explicitly — for each AC,
say structural, runtime, or both.

| AC (from draft §9) | Structural coverage | Runtime coverage |
|---|---|---|
| AC1: STATUS schema with `tier:` populated | this feature's STATUS + B2's STATUS after migration | — |
| AC2: tiny reaches archive without tech/design/brainstorm/review; audited requires all 3 reviewer axes | helper `get_tier` unit tests + `/specflow:next` dispatch table tests | **B2 (standard tier)** exercises standard-tier dispatch; tiny/audited exercised by next two features after B2 |
| AC3: archive merge-check for standard/audited | mock git repo unit test (fake unmerged branch) | **B2** will hit this on its own archive |
| AC4: upgrade audit log | unit test — invoke upgrade helper, assert STATUS note format | runtime: any future upgrade event |
| AC5: B2 migrates to standard with no manual intervention | script runs against B2's STATUS, asserts `tier: standard` field appears | **B2's own request-to-brainstorm transition** validates runtime |
| AC6: retired commands (deprecation vs removal) | file present/absent + deprecation message tests | runtime: user invokes retired command, sees expected behaviour |
| AC7: dogfooding — tier-model runs as standard | **structural**: this feature's own new-shape artefacts present (see Q-LB-1 table) | **runtime deferred to B2** — B2 is the first feature authored fresh under `--tier standard` with `/specflow:plan` available |

**Recommendation**: In PRD, annotate each AC with a `Verification:
structural | runtime | both` tag and an owner. `## Edge cases / Dogfood
paradox` section enumerates structural-only ACs and states explicitly "runtime
coverage handed off to `20260420-flow-monitor-control-plane`".

**PRD implication**: add a standalone `## Dogfood paradox` section to PRD,
following the shared-memory template. List AC2, AC3, AC6, AC7 as having a
runtime component that B2 will satisfy.

### Q-LB-3 — Tiny diff threshold for auto-upgrade (Q3 / draft §8 Q3)

**Problem**: Draft picks 200 lines as the tiny→standard auto-upgrade trigger.
Arbitrary. Calibrate from archive?

**Archive histogram attempt**: no per-feature diff-line count stored in STATUS
or RETROSPECTIVE. A real histogram would require
`git log --stat` over each archived branch, which is available but not yet
compiled. Representative data points pulled from memory / archive notes:

- `20260418-review-nits-cleanup`: 14-item housekeeping sweep, ~10 tasks, 2
  waves — small. Likely <500 LOC.
- `20260418-per-project-install`: `bin/specflow-seed` alone is 1457 LOC
  (post-retry). Feature total well over 2000 LOC. Clearly `standard` or
  `audited`.
- `20260419-language-preferences`: 18 tasks across 3 waves + subagent
  delegation — several hundred LOC. Clearly `standard`.
- `20260419-flow-monitor`: 42 tasks across 5 waves, multiple reviewer BLOCKs,
  Rust/Tauri new module. Easily `standard`, arguably `audited`.
- `20260416-prompt-rules-surgery`: session-start hook + rule-file taxonomy —
  maybe 500–800 LOC.
- `symlink-operation`: `bin/claude-symlink` + tests — moderate,
  few-hundred LOC.

**Observation**: no archived feature looks like a plausible `tiny`. The
current flow has been used for real features only; the `tiny` tier is a
future shape, not a backfill target. A histogram of the current archive is
poor calibration data for the tier boundary because the archive is
selection-biased — small changes (typo fixes, single-function tweaks) never
entered the specflow flow at all.

**Option 1: Set threshold at 200 lines per the draft; tune after dogfood.**

- **Pro**: Simple, non-zero, round number. Easy to communicate.
- **Con**: Arbitrary. Likely wrong.

**Option 2: Set threshold at 100 lines; let it be aggressive.**

- **Pro**: Surfaces the auto-upgrade early, so the signal fires often enough
  to validate the mechanism.
- **Con**: Might auto-upgrade features that are genuinely small-but-changed
  (e.g. a config-only migration that touches 150 config lines — no real
  complexity).

**Option 3: Threshold on "files touched", not "lines".**

E.g. `tiny`-upgrade if >3 files edited. Rationale: blast radius scales with
number of surfaces touched, not sheer LOC. Matches the architect memory
`scope-extension-minimal-diff` in spirit.

- **Pro**: Closer to blast-radius semantic the tier system encodes.
- **Pro**: Harder to game (splitting a 300-line edit across files doesn't
  reduce count).
- **Con**: A single-file 800-line rewrite stays `tiny` under this rule.
- **Con**: Different from what reviewers / architects already think about.

**Option 4: Two-factor: >200 lines OR >3 files.**

- **Pro**: Covers both failure modes (big diff single file, many small edits).
- **Con**: More moving parts in the auto-upgrade trigger.

**Recommendation: Option 4 (two-factor, 200 lines OR >3 files).**

Reasoning: the tier system is about ceremony-proportionate-to-risk. Both LOC
and file-count correlate weakly but independently with risk. The OR is
forgiving — small diffs across many files (e.g. a cross-cutting rename) still
upgrade, as do large single-file rewrites. The threshold numbers are tunable
after dogfood; the **structure** (two-factor OR) is what PRD should commit.

Review cadence: plan to revisit thresholds after 3 `tiny`-intent features
have shipped, per TPM's implementer sense. Not a PRD commitment — a
RETROSPECTIVE note.

**PRD implication**: R-auto-upgrade says "tiny → standard suggested if
implement diff exceeds 200 lines OR touches more than 3 files". Tunability
noted in PRD out-of-scope or edge-cases.

### Q-LB-4 — Interactive tier prompt default (Q5 / draft §8 Q5)

**Problem**: If user runs `/specflow:request "foo"` without `--tier`, PM
should: (a) ask interactively, (b) infer from keywords, (c) default silently
to `standard`.

**Option 1: Silent default to `standard`.**

- **Pro**: Zero friction. Power users who want something else pass `--tier`.
- **Con**: Tier sprawl — everyone gets `standard` because nobody bothers.
  `tiny` becomes effectively dead.
- **Con**: No signal at request time that tier is a choice. Users who would
  have picked `tiny` for a typo fix never learn the option exists.

**Option 2: Ask interactively if omitted.**

- **Pro**: Forces explicit choice. Educates users about tier existence.
- **Pro**: Aligns with existing PM-probes-for-missing-context pattern at
  request stage.
- **Con**: Adds one prompt per request. For a team running 3+ requests a day,
  cumulative friction.
- **Con**: The prompt requires user input, which blocks the orchestrator
  thread.

**Option 3: Infer from keywords in the raw ask, ask only if ambiguous.**

- **Pro**: Most requests are self-classifying ("typo in X" → tiny; "new
  dashboard" → standard; "auth surface" → audited).
- **Pro**: Fast when confidence is high; asks when not.
- **Con**: Keyword classifiers are unreliable without careful curation.
- **Con**: False inferences are worse than silent defaults — "I auto-classified
  your feature as tiny" creates a wrong prior that's hard to overturn.

**Option 4: Infer-and-ask-for-confirmation.**

PM proposes a tier based on the raw ask plus brief scope probes (the same
probes PM already runs for `why now / success / out-of-scope`). The tier is
presented as a proposed default with one-key confirmation. Silent accept =
adopt; user types a different tier = override.

- **Pro**: Keeps PM's existing probe pattern.
- **Pro**: Educates the user about tier without blocking.
- **Pro**: Wrong inferences are cheap to correct (one keystroke).
- **Con**: Slightly more PM prompt text.

**Recommendation: Option 4 (infer-and-confirm).** Reasoning:

1. PM already probes for request context at intake. Adding "tier proposal" to
   the probe is incremental, not new friction.
2. The one-key confirmation path is basically the cost of option 1 (silent
   default) when PM proposes `standard`, which is the majority case.
3. Educates users organically — after seeing the prompt a few times, power
   users start passing `--tier` explicitly.
4. Wrong PM inference is recoverable — upgrade is always available mid-flight
   per the monotonic-upgrade rule.

**PRD implication**: R for `/specflow:request` says "PM proposes tier based on
raw ask; user confirms or overrides; silent acceptance allowed". Inference
heuristics are a TPM/architect concern at tech stage — PRD just says
"proposes a tier".

### Q-LB-5 — Validate aggregator contract (Q1 / draft §8 Q1)

**Problem**: Does `/specflow:validate` reuse the `/specflow:review` aggregator
verbatim, or get its own shape?

**Today**: `/specflow:review` fires three reviewers (security / performance /
style) in parallel, each emits `## Reviewer verdict` + `verdict: PASS|NITS|BLOCK`
footer. Orchestrator aggregates per the classifier pattern (see
`architect/aggregator-as-classifier.md`): any BLOCK → wave BLOCK; all PASS →
PASS; otherwise NITS.

`/specflow:validate` would fire two agents (qa-tester dynamic, qa-analyst
static) in parallel, each emits a similar verdict footer. Aggregation rule:
likely the same (BLOCK wins, all-PASS PASS, mixed NITS).

**Option 1: Reuse the review aggregator verbatim, just with 2 axes instead of 3.**

- **Pro**: Cheapest — one aggregator, two call sites.
- **Pro**: Pattern already proven at 3 waves of flow-monitor and multiple
  other features.
- **Pro**: Same wire format (`## Validate verdict` header, `axis:`, `verdict:`)
  — parseable by the same grep-parseable format from
  `architect/reviewer-verdict-wire-format.md`.
- **Con**: Nothing to diverge on yet, but future QA-axis changes (e.g. adding
  a static-analysis sub-axis, or weighting analyst vs tester differently)
  would require re-architecting the shared aggregator.

**Option 2: Build a fresh aggregator for validate.**

- **Pro**: Room to evolve — e.g. per-axis severity weighting, tester-only
  runtime, analyst-only static.
- **Con**: Cost is non-trivial — a second aggregator means two parsers, two
  test suites, two sets of "malformed footer = BLOCK" fail-loud rules.
- **Con**: Divergence without a triggering reason is speculative design.

**Option 3: Reuse the aggregator, parameterise the axis set.**

The aggregator becomes `aggregate_verdicts(axes: Set[str], replies: Map[axis,
verdict])`. `/specflow:review` passes `{security, performance, style}`;
`/specflow:validate` passes `{tester, analyst}`. One aggregator, two callers,
no per-call parser changes.

- **Pro**: Matches the architect memory `aggregator-as-classifier.md` which
  frames aggregation as a closed-state classifier.
- **Pro**: Adding an axis later (e.g. a `refactor-opportunity` axis in review)
  is a one-line change at the call site.
- **Con**: Slight extra parameter on the function signature — trivial.

**Recommendation: Option 3 (parameterised reuse).** Reasoning:

1. The architect memory `aggregator-as-classifier.md` is already a pattern;
   parameterising the axis set is the natural next refinement.
2. Option 1 works today but creates a latent divergence risk — two call sites
   with copy-pasted aggregator logic always drift.
3. Option 2 pays cost now for speculative future flexibility.

**PRD implication**: R for `/specflow:validate` says "aggregates qa-tester +
qa-analyst verdicts per the existing review aggregator contract
(`architect/reviewer-verdict-wire-format.md` footer format, PASS/NITS/BLOCK
semantics). Axis set is `{tester, analyst}`." Architect can pick Option 1 vs
Option 3 implementation at tech stage — PRD cares only that the wire format
and aggregation semantic match.

---

## 4. Non-load-bearing open questions

### Q-NLB-1 — `tiny` tier inline review default (Q-intake-3 / draft §8 Q4)

**Recommendation**: `tiny` tier defaults to `--skip-inline-review` because the
whole point of `tiny` is low-ceremony, and tiny changes almost by definition
don't cross the security axis's risk threshold. Users can explicitly opt in
with `--inline-review` if they know a tiny change touches something sensitive.
Auto-upgrade rule catches the cases where tiny was the wrong call (security
BLOCK → auto-upgrade to audited per draft §4.2).

**PRD implication**: R says "tiny tier implements with inline review off by
default; `--inline-review` opt-in available". Half-line requirement, no
extended rationale needed.

### Q-NLB-2 — `--allow-unmerged` requires reason? (Q-intake-9)

**Recommendation**: Require a reason (free-text, one line, written into STATUS
Notes). Cost of typing 10 words is trivial; archaeological value six months
later is large. Precedent: `/specflow:update-req` and `/specflow:update-tech`
both require a reason.

**PRD implication**: R says "`/specflow:archive --allow-unmerged REASON` — REASON
is a required positional argument, logged to STATUS Notes". Any attempt to
pass `--allow-unmerged` without a reason exits non-zero.

### Q-NLB-3 — Mid-flight tier upgrade re-seeding (Q-intake-7)

**Recommendation**: Upgrade does NOT re-seed stage artefacts. It writes a
STATUS note and changes the `tier:` field. If a `tiny` feature upgraded mid-
flight to `standard` has a one-line PRD, PM manually fleshes out the PRD
under `/specflow:update-req` semantics. Rationale: automatic re-seeding would
either (a) destroy the existing content or (b) produce merge-conflict-style
artefacts nobody wants to resolve. Manual is cleaner.

**PRD implication**: R says "tier upgrade does not re-seed stage artefacts;
artefact alignment with new tier is the responsibility of the next stage
author (`/specflow:update-req` for PRD, etc.)". Short requirement.

### Q-NLB-4 — B2 migration mechanics (Q-intake-5 / draft §8 Q6)

**Recommendation**: Auto-migrate B2 via the schema-rollout pass that runs at
W0 of this feature's implement. B2's STATUS gains `tier: standard` as part
of the schema migration, same pass that adds the field to the STATUS
template. No manual intervention on B2. This pattern matches the migration
discipline from per-project-install (manifest authoring runs automatically
for in-flight features).

**PRD implication**: AC5 already says this. No change.

---

## 5. Stress-tests of the draft's consolidations

### Consolidation 1: `brainstorm` into PRD `## Exploration`

**Draft position**: fold brainstorm into PRD as an optional section.

**Stress test**: brainstorm is usually 200–500 lines of exploration — multiple
options, recommendations, rejected alternatives. If this lands as a PRD
section, PRD length roughly doubles. Future readers skimming PRD for
requirements have to skip past exploration.

**Resolution**: the consolidation is sound, but PRD template should put
`## Exploration` at the END, not the beginning. Requirements are what
implementers read; exploration is what reviewers read for rationale. Not a
brainstorm blocker; flag for TPM at plan stage.

### Consolidation 2: `plan` + `tasks` into single `05-plan.md`

**Draft position**: single file, narrative (plan) at top, checklist (tasks)
at bottom.

**Stress test**: `06-tasks.md` today is consumed by `/specflow:implement`
which greps for `- [ ]` checkboxes. If the checklist moves into `05-plan.md`,
the implement command needs to grep a different file. Either rename `06-tasks.md`
to `05-plan.md` across all commands, or have `/specflow:implement` fall back
to `05-plan.md` when `06-tasks.md` is absent.

**Resolution**: sound. Recommend: `/specflow:implement` reads from `05-plan.md`
when feature's STATUS indicates `standard` or `audited` tier with consolidated
plan; old-shape fallback to `06-tasks.md` for archived features being
re-opened. Clean dispatch, no magic. Architect will detail at tech stage.

### Consolidation 3: `verify` + `gap-check` into single `validate`

**Draft position**: parallel axes (tester dynamic, analyst static), aggregated
like review.

**Stress test**: today's gap-check and verify happen in SEQUENCE (gap-check
first, then verify) because verify's findings sometimes depend on gaps
surfaced at gap-check. If they become parallel, verify can't leverage
gap-check findings.

**Counter**: in practice gap-check is static (does the code exist? does it
match the PRD?) while verify is dynamic (does running the test pass? does
the artefact match the acceptance criterion?). The information-flow
dependency is weak or absent — they usually verify independent aspects.
Running in parallel is a minor optimisation, not a correctness risk.

**Resolution**: sound, with a note for PRD: if any real dependency is
discovered at architect stage (tech), this consolidation may need to revert
to sequential. Flag Q-NLB-5 (new, not in intake) at architect tech review:
are there any correctness-critical dependencies between analyst and tester
verdicts that forbid parallel execution?

---

## 6. Questions flipped by brainstorm

None of the intake questions are **flipped** — all nine get recommendations
aligned with the draft's direction, with one refinement:

- **Q3 (diff threshold)**: draft says "200 lines". Brainstorm refines to
  "200 lines OR >3 files" (Option 4, two-factor). Not a flip; an augmentation.
- **Q8 (self-bootstrap)**: draft says "run as standard tier" without
  committing to hybrid vs pure-old-shape. Brainstorm commits to Option 3
  (hybrid — plan + validate in new shape, earlier stages in old). Not a
  flip; a concretion.

## 7. Open questions remaining for PRD stage (carry-forward)

1. **Q-CARRY-1** (from Q-LB-3): exact diff-threshold numbers are a
   tunable; PRD commits "200 lines OR >3 files" as starting values with
   tuning deferred to retrospective-driven review after 3 `tiny`-intent
   shipments.

2. **Q-CARRY-2** (from Q-LB-1 Option 3 hybrid): PRD must enumerate the
   artefact-shape table explicitly so TPM / QA know which files to author
   under which shape during this feature's own implement.

3. **Q-CARRY-3** (new, stress-test of consolidation 3): architect at tech
   stage must confirm no correctness dependency between analyst and tester
   verdicts that forbids parallel execution. If dependency exists, fold
   back to sequential.

4. **Q-CARRY-4** (from Q-LB-4): PM tier-proposal heuristics are tech-stage
   territory — keyword set, scope-probe phrasing. PRD commits the shape
   (propose-and-confirm), not the heuristics.

## 8. Memory applied

See Team memory block in return message.

## 9. Recommendation summary (to carry into PRD)

- Keep three tiers (`tiny` / `standard` / `audited`). Draft confirmed.
- Keep three consolidations (brainstorm-into-PRD, plan+tasks, verify+gap-check
  into validate). Draft confirmed, with architect-stage check on sequential
  vs parallel for validate.
- Self-bootstrap: **hybrid** (Q-LB-1 Option 3). Plan + validate artefacts
  in new shape; earlier stages in old shape. AC7 split into structural (this
  feature) + runtime (B2).
- Dogfood paradox: explicit `## Dogfood paradox` PRD section annotating
  structural-vs-runtime per AC (Q-LB-2).
- Auto-upgrade trigger: 200 lines OR >3 files (Q-LB-3 Option 4).
- `tiny` inline review: off by default, opt-in flag (Q-NLB-1).
- Interactive tier prompt: propose-and-confirm (Q-LB-4 Option 4).
- Validate aggregator: parameterised reuse of review aggregator (Q-LB-5
  Option 3).
- `--allow-unmerged`: requires a free-text reason (Q-NLB-2).
- Mid-flight upgrade: does not re-seed artefacts; manual alignment via
  `/specflow:update-req` (Q-NLB-3).
- B2 migration: auto via W0 schema pass (Q-NLB-4).

---

## Stage checklist update proposal (deferred to TPM)

This feature's own STATUS.md stage checklist should be updated at plan time
to reflect the new-shape artefacts:

```markdown
- [x] request       (00-request.md)              — PM
- [x] brainstorm    (01-brainstorm.md)           — PM  [last use of standalone brainstorm in this repo]
- [ ] prd           (03-prd.md)                  — PM
- [ ] tech          (04-tech.md)                 — Architect
- [ ] plan          (05-plan.md)                 — TPM  [NEW: narrative + checklist merged]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [NEW: verify + gap-check merged]
- [ ] archive       (moved to .spec-workflow/archive/) — TPM
```

Not binding on this brainstorm — TPM writes the definitive STATUS checklist
at plan stage.
