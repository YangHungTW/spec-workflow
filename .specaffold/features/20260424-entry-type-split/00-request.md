# Request

**Raw ask**: "Split scaff's single entry command into three work-type entries: /scaff:request (new feature), /scaff:bug (fix with ticket repro), /scaff:chore (maintenance/cleanup). Each with its own PM probe, PRD template, tier keyword heuristic, and slug convention. Dogfoods today's own chore commits and the missing bug-fix flow."

**Context**:

Two concrete drivers make this timely:

1. **Today's chore-heavy session** — the present working day produced several maintenance commits (removed the `.spec-workflow` compat symlink, env-var rename, retired-command stub cleanup, agent prompt sweep, GitHub Action removal). Each was forced through the single `/scaff:request` entry; the feature-shaped probe (why-now, success criteria, has-ui, out-of-scope) and the feature-shaped PRD template (Problem, Goals, Non-goals, Requirements, ACs) fit the work poorly. The intake consistently felt like filing a feature for what was really a checklist.

2. **Missing bug-fix flow** — surfaced during the QA-workflow discussion earlier today. A user receiving a bug ticket currently has to cram structured information (repro steps, expected vs actual behaviour, ticket ID, environment) into a free-form one-liner, then answer a probe that asks feature-shaped questions instead of bug-shaped ones. Ticket volume for this user is non-trivial — they explicitly chose this scoped split over a lighter `--type` flag alternative.

Specific pain points the existing single-entry shape produces:

- PM probe asks "why now / success criteria / has-ui / out-of-scope" regardless of whether the work is a feature, bug, or chore. Bug intake wants repro / expected / actual / ticket-ID; chore intake wants scope / reason / verify-assertion.
- PRD template is feature-oriented (Problem, Goals, Non-goals, Requirements R1..., Acceptance criteria). Bugs want Repro / Expected / Actual / Environment / Ticket URL. Chores want a checklist-shaped "things to do + how we verify they're done".
- Tier-proposal keyword heuristic has only feature keywords (`auth`, `secret`, `migration`, `typo`, `rename`, `readme`). It knows nothing about bug-shaped keywords (`crash`, `regression`, `data loss`, `xss`) or chore-shaped keywords (`bump dep`, `remove dead code`, `ci tweak`, `cleanup`).
- Slug convention `<date>-<body>` does not distinguish work types at a glance; browsing `.specaffold/archive/` does not reveal which archive entries were features vs bug-fixes vs chores.

Open questions the PRD stage must resolve (captured here so they are not lost):

1. **Does `/scaff:chore` skip PRD entirely?** — chore PRDs may be so skeletal (a checklist and verify assertions) that the feature-shaped PRD stage is pointless. Candidate: chore goes straight from request to plan, or from request to implement with a checklist artefact.
2. ~~**Does `/scaff:bug` require a ticket ID as mandatory argument?**~~ **RESOLVED by user 2026-04-24**: `/scaff:bug` accepts **any of three input shapes**: (a) a URL (auto-detected via `http://` or `https://` prefix), (b) a ticket ID (matches `[A-Z]+-\d+` or similar), (c) a free-form description (fallback when neither URL nor ID). One positional arg, auto-classified; PRD template's Source field records the arg verbatim plus the detected type. No external fetch (per out-of-scope); the arg is an opaque reference.
3. **Stage matrix per work-type x tier** — three types x three tiers = 9 cells to map. Example asymmetry: bug-tier=tiny likely still needs validate (for regression test), whereas feature-tier=tiny can skip design. Needs an explicit table in the PRD.
4. **Slug naming convention for backward compat** — existing archived features use `<date>-<slug>` with no type prefix. Do existing archives retroactively get type-tagged (e.g. `20260421-feat-rename-to-specaffold`), or are only new entries prefixed while history stays as-is? Default posture is "no retroactive rename" but the PRD should state this explicitly.
5. **Retrospective prompt shape per type** — archive retrospectives may want to ask different reflection questions for bug vs feature vs chore (bug: "what guardrail would have prevented this?"; chore: "could this have been automated?"; feature: the existing shape). Scope call for the PRD.

**Success looks like**:

A user with the appropriate work type can invoke `/scaff:bug` or `/scaff:chore` (or continue to use `/scaff:request` for features) and get:

- A PM probe that asks shape-appropriate questions (bug: repro / expected / actual / ticket-ID; chore: scope / reason / verify-assertion; feature: the existing probe, unchanged).
- A PRD template that matches the work shape (bug: includes Repro / Expected / Actual / Environment / Ticket URL; chore: checklist-shaped "things to do + verify assertions"; feature: the existing Problem / Goals / Non-goals / Requirements / ACs shape, unchanged).
- A slug convention that distinguishes the three types at a glance, e.g. `20260424-<body>` for feature (unchanged), `20260424-fix-<body>` for bug, `20260424-chore-<body>` for chore.
- A tier-proposal heuristic that adds bug and chore keyword sets alongside the existing feature keywords, so `/scaff:bug crash` proposes an appropriate tier without reusing feature-only keywords.
- Downstream stages (design / tech / plan / implement / validate / archive) continue to work the same across all three types, with per-type adjustments confined to intake + PRD + tier proposal + slug.

**Out of scope**:

- External ticket tracker integration (Jira / GitHub Issues / Linear API fetch) — deferred to a future feature; `/scaff:bug` accepts a ticket URL as free text, it does not fetch.
- Automated PR-opening flow triggered by `/scaff:bug` or `/scaff:chore` completion.
- Changing `/scaff:request`'s behaviour for feature intake — the existing command must stay backward-compatible; feature workflows must not regress.
- Renaming or moving any existing archived feature's slug (backward compat question 4 above resolves to "no retroactive rename" as the default posture).

**UI involved?**: false

All three entry commands are CLI-invoked slash commands; user interaction happens in the terminal. No visual mockup or design stage required. There is a string-delta aspect — the PM probe prompts and PRD template headings are user-facing text — but that is resolved in the PRD stage, not in a design stage.

## Team memory

- `pm/split-by-blast-radius-not-item-count.md` (global) — applies: this request bundles three entry commands, but all share the same blast radius (scaff intake surface). Single-feature absorption is correct; no B1/B2 split warranted.
- `pm/housekeeping-sweep-threshold.md` (local) — does not apply: this is a scoped capability, not a nit sweep.
- `pm/scope-extension-at-design-is-cheapest.md` (global) — noted for PRD stage if user extends scope before tech.
- `shared/dogfood-paradox-third-occurrence.md` (local) — applies: the feature ships the three new entry commands (`/scaff:bug`, `/scaff:chore`); they cannot be exercised on themselves during implement. Structural-only verification during this feature's validate; first runtime exercise falls to the next feature that uses one of the new entries. PRD stage must include an explicit structural/runtime AC split.
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md` (local) — does not apply: not a B1/B2 split (single feature).
