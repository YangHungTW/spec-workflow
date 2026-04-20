# Request

**Raw ask**: tier model — three-tier flow (tiny/standard/audited) with stage consolidation

**Context**:
specflow today runs one flow shape for every feature — ~10–11 stages from
`request` through `archive`. That shape fits multi-wave, cross-module work
(e.g. `20260419-flow-monitor`: 42 tasks, 5 waves, multiple reviewer BLOCKs)
but is heavy ceremony for small changes (a typo, a one-function tweak, a
copy fix pay the same planning tax as a new module). Conversely, the
current flow offers no way to dial rigour *up* for high-risk work (auth,
payment, migration, breaking API change): the same audit trail covers a
low-risk refactor and a security-sensitive surgery.

Draft design (full discussion captured at `.spec-workflow/drafts/tier-model.md`,
2026-04-19 / 2026-04-20 session, reviewed with user) proposes three tiers
plus three stage consolidations. User has confirmed:

- Three tiers named `tiny` / `standard` / `audited` (top tier is
  `audited`; `full`, `rigorous`, `compliance` explicitly rejected).
- Stage consolidations are bundled into the same feature intentionally,
  because they touch the same STATUS schema and command surface —
  splitting them is double-work on the same files:
  1. `brainstorm` → optional `## Exploration` section inside PRD
     (separate artefact retired).
  2. `plan` + `tasks` → single `plan.md` containing narrative and
     checklist.
  3. `verify` + `gap-check` → single `validate` stage with two parallel
     axes (tester + analyst), aggregated like `review`.
- Sequencing lock: `20260420-flow-monitor-control-plane` (B2) is frozen
  at `request` stage and must not advance until this feature archives —
  B2 hardcodes the pre-tier command set and will collide otherwise.

**Success looks like**:
- Every new feature created via `/specflow:request` carries a `tier:`
  field in `STATUS.md`, populated at request time (user-confirmed or
  defaulted to `standard`).
- A `tiny`-tier feature can reach `archive` without passing through
  `brainstorm`, `tech`, `design`, or `review` stages — total mandatory
  stages ≤ 5.
- An `audited`-tier feature cannot reach `archive` without all three
  reviewer axes returning PASS (or explicit override), exploration
  recorded in PRD, and fine-grained wave split in plan — total
  mandatory stages ≈ 9.
- `/specflow:next` is tier-aware and skips retired stages based on the
  feature's declared tier.
- Retired commands (`brainstorm`, `tasks`, `verify`, `gap-check`) either
  emit a deprecation notice forwarding to the successor or are removed
  outright (decision left to brainstorm; both options meet the rubric).
- Tier upgrades (never downgrades) are audit-logged in `STATUS.md` with
  date, role, old→new tier, and trigger reason.
- Archive refuses to finalise a `standard` or `audited` feature whose
  branch is not merged to main, unless `--allow-unmerged` is passed
  with a documented reason. `tiny` skips this check.
- B2 `20260420-flow-monitor-control-plane` migrates to `tier: standard`
  on rollout with zero manual intervention; archived features are not
  back-filled.
- This feature itself runs as a `standard` tier and dogfoods the new
  commands during its own `implement` (where bootstrap order permits —
  see Dogfood paradox under Open questions).

**Out of scope**:
- Agent role consolidation (7 roles stay: pm / architect / tpm / designer
  / developer / qa-analyst / qa-tester). Merging pm+tpm or
  qa-analyst+qa-tester is a separate discussion.
- Adding new reviewer axes (e.g. refactor-opportunity). Existing three
  axes (security / performance / style) unchanged.
- Back-filling `tier:` field into archived STATUS files. Archived
  features stay as-is.
- Cross-feature orchestration (e.g. "bump all stalled features one
  tier"). Out of scope.
- Auto-downgrade. Tier is monotonic (upgrade-only) by design — this is
  a rule, not a gap.

**UI involved?**: no — this is pure tooling / state-machine /
command-dispatch work. No designer stage.

**Open questions** (carry into brainstorm/PRD; a few are PM-surfaced
beyond the draft's §8):

1. Does `/specflow:validate` reuse the `/specflow:review` aggregator
   contract verbatim, or does it need its own shape? Reuse is cheaper;
   divergence is more flexible. (Draft §8 Q1.)
2. Auto-upgrade diff threshold (draft picks 200 lines for tiny →
   standard). Calibrate from archived feature histogram, or accept the
   arbitrary starting value and tune after dogfood? (Draft §8 Q3.)
3. Does `tiny` tier run inline review during implement? Default-skip
   minimises friction but removes the security axis backstop; always-
   run-security adds latency but preserves the must-tier guardrail.
   (Draft §8 Q4.)
4. When the user omits `--tier`, should PM (a) ask interactively, (b)
   infer from request keywords/scope hints, or (c) default silently to
   `standard`? Silent default risks tier sprawl; asking adds friction.
   (Draft §8 Q5.)
5. B2 migration mechanics: on rollout, does B2 auto-adopt `standard`
   via a migration pass, or does this feature's archive block on B2
   having a `tier:` field manually written first? (Draft §8 Q6.)
6. **[PM-surfaced]** Dogfood paradox — this feature ships the tier
   schema and retired-command dispatch. Parts of its own `implement`
   cannot exercise the new commands until after merge + session
   restart. Which ACs are structural-only vs runtime, and which feature
   carries the first runtime exercise? (Pattern: see
   `shared/dogfood-paradox-third-occurrence.md`.) Candidate next
   feature: B2 control-plane, which runs under the new tier schema by
   construction.
7. **[PM-surfaced]** How does `/specflow:update-req` behave when a
   feature's tier changes mid-flight in a way that invalidates prior
   stage artefacts (e.g. upgrade from `tiny` to `standard` after PRD
   is already written as a one-liner)? Does the upgrade re-seed stage
   templates, or require manual re-entry?
8. **[PM-surfaced]** The draft §9 AC7 says tier-model itself runs as
   `standard` tier. But a `standard` feature requires `brainstorm`
   folded into PRD and `plan+tasks` merged — both of which this
   feature is *introducing*. Does the self-dogfood target require a
   staged bootstrap (run `standard` under the *old* shape, then
   retrofit), or can we author artefacts in the new shape from the
   outset? Brainstorm must resolve before PRD.
9. **[PM-surfaced]** `--allow-unmerged` escape hatch scope: does it
   require a free-text reason logged to STATUS, or is the flag alone
   sufficient? Logging a reason costs nothing and aids future
   archaeology; silent flag is simpler.
