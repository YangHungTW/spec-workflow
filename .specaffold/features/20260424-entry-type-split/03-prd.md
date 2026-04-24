# PRD — entry-type-split

- **Slug**: 20260424-entry-type-split
- **Tier**: audited
- **Has-ui**: false
- **Authored**: 2026-04-24 by PM
- **Related**: 00-request.md (intake), STATUS.md

## 1. Problem / background

Specaffold's single `/scaff:request` intake conflates three distinct work shapes — new features, bug fixes, and maintenance/chore items — under a feature-oriented probe and a feature-oriented PRD template. Two recent drivers make the mismatch acute:

1. **Chore-heavy day (2026-04-24)** — five maintenance commits (compat-symlink removal, env-var rename, retired-command stub cleanup, agent prompt sweep, GitHub Action removal) were each squeezed through the feature intake. Each intake collected feature-shaped answers (why-now / success criteria / has-ui / out-of-scope) for work that is structurally a checklist.

2. **Missing bug-fix flow** — bug intake currently requires the user to cram repro steps, expected vs actual, ticket ID, and environment into a free-form one-liner, then answer feature-shaped probe questions. Ticket volume is non-trivial for the primary operator.

The probe questions, the PRD template, the tier-proposal keyword set, and the archive slug convention are all feature-shaped. Downstream stages (tech / plan / implement / validate / archive) work reasonably across all three work types; only the intake surface and the PRD shape need to branch.

## 2. Goals

- **G1** — Offer three work-typed entry commands (`/scaff:request` for features, `/scaff:bug` for fixes, `/scaff:chore` for maintenance) so operators do not have to translate bug or chore work into feature-shaped answers.
- **G2** — Per-type PM probe questions, per-type PRD template, per-type tier-proposal keyword set, per-type slug convention, and per-type retrospective prompt.
- **G3** — Keep `/scaff:request` byte-identical for existing feature intake; no regression on the feature happy-path.
- **G4** — Shared downstream contract: tech / plan / implement / validate / archive stages do not branch on type; only intake and PRD shape branch.
- **G5** — Shared scaffold: all three commands write `00-request.md` + `STATUS.md` to the same feature directory shape; the only thing that differs is content (probe questions + PRD template).

## 3. Non-goals

- **NG1** — **No retroactive slug rename.** Existing archives under `.specaffold/archive/` are immutable snapshots; they stay with their current slugs. Only newly-authored features (after this feature ships) adopt the type-prefixed convention.
- **NG2** — **No external ticket fetch.** `/scaff:bug` accepts a URL, a ticket ID, or a free-form description verbatim; it does not call Jira / GitHub / Linear APIs.
- **NG3** — **No change to feature workflow shape.** `/scaff:request`'s PM probe, PRD template, and slug convention must be byte-identical to today. Every downstream consumer (tech / plan / archive) must see the feature branch unchanged.
- **NG4** — **No PR-opening automation.** Neither `/scaff:bug` nor `/scaff:chore` opens PRs or interacts with SCM beyond what `/scaff:request` already does.
- **NG5** — **No new stages.** The stage machine keeps the same eight stages (request / design / prd / tech / plan / implement / validate / archive). Per-type behaviour shows up as per-cell skip/conditional decisions in the 3×3 matrix (D3), not new stages.
- **NG6** — **No runtime exercise of `/scaff:bug` or `/scaff:chore` during this feature's own validate.** Dogfood paradox per `shared/dogfood-paradox-third-occurrence.md`: the commands ship in this feature; they cannot be invoked on themselves. Structural ACs only in this feature's validate; first runtime exercise happens on the next real bug or chore ticket (see AC-runtime-deferred).

## 4. Users / scenarios

One user: the primary operator, invoking scaff in three modes.

- **Scenario 4.1 (feature intake)** — Operator has a new capability to build. Runs `/scaff:request "<one-line ask>"` exactly as today. Gets the same probe questions (why-now / success / has-ui / out-of-scope), the same feature-shaped PRD template, the same `YYYYMMDD-<body>` slug. No behavioural change.
- **Scenario 4.2 (bug intake)** — Operator has a bug to fix. Input may be a URL (from a ticket tracker), a ticket ID (e.g. `PROJ-123`), or a free-form description. Runs `/scaff:bug "<arg>"` with one positional arg. The arg is auto-classified (URL / ticket-id / description) and stored verbatim; PM probes for repro / expected / actual / environment.
- **Scenario 4.3 (chore intake)** — Operator has a maintenance item (dep bump, dead-code removal, CI tweak, comment cleanup). Runs `/scaff:chore "<one-line ask>"`. PM probes for scope / reason / verify-assertion; PRD shape is a checklist, not R1..Rn + AC1..ACn.

## 5. Requirements

Requirements are grouped by surface for readability. Each R maps to at least one AC in §6.

### 5.1 New slash commands

- **R1** — Create `.claude/commands/scaff/bug.md` implementing `/scaff:bug`. Argument shape: `/scaff:bug "<arg>" [--tier tiny|standard|audited] [slug]`. Semantics mirror `request.md` except: (a) classify `<arg>` into `{url, ticket-id, description}` per D1, (b) invoke the bug branch of the PM probe (R4), (c) route through the bug slug convention (R8), (d) apply the bug tier-keyword set (R6).
- **R2** — Create `.claude/commands/scaff/chore.md` implementing `/scaff:chore`. Argument shape: `/scaff:chore "<ask>" [--tier tiny|standard|audited] [slug]`. Semantics mirror `request.md` except: (a) invoke the chore branch of the PM probe (R5), (b) route through the chore slug convention (R8), (c) apply the chore tier-keyword set (R7), (d) use the chore PRD shape per D2.
- **R3** — `.claude/commands/scaff/request.md` must remain byte-identical to its pre-change state for feature intake. Diff-check at merge must show zero content changes to this file (see AC3).

### 5.2 PM probe branches

- **R4** — `pm.md` gains a **bug probe branch**. When invoked for `/scaff:bug`, the probe elicits: (a) repro steps (ordered list), (b) expected behaviour, (c) actual behaviour, (d) environment (OS, version, relevant config), (e) the verbatim source value + detected type (per D1). No has-ui probe for bugs unless explicitly UI-related (UI is rare for bug tickets in this repo; default has-ui=false).
- **R5** — `pm.md` gains a **chore probe branch**. When invoked for `/scaff:chore`, the probe elicits: (a) scope (which files / dirs / surfaces), (b) reason (why now), (c) verify-assertion (how we know the chore is done — grep-assertion, test output, visual inspection). No has-ui probe for chores (default has-ui=false by construction per D3).

### 5.3 Tier-proposal keyword sets

- **R6** — `pm.md`'s tier-proposal section gains a **bug keyword set**:
  - **Tiny bug keywords**: `typo`, `wording`, `copy change`, `off-by-one`, `wrong label`.
  - **Audited bug keywords**: `crash`, `data loss`, `data corruption`, `regression`, `security`, `xss`, `csrf`, `sql injection`, `auth bypass`, `privilege escalation`, `memory leak`, `race condition`.
  - **Default**: `standard`.
- **R7** — `pm.md`'s tier-proposal section gains a **chore keyword set**:
  - **Tiny chore keywords**: `comment`, `docstring`, `readme`, `rename`, `cleanup`, `dead code`, `formatting`, `lint`.
  - **Audited chore keywords**: `bump dep`, `dependency update`, `security patch`, `ci migration`, `settings.json`, `migration`.
  - **Default**: `standard`.
- **R7.1** — The tier-keyword tables MUST live in one shared location in `pm.md` (a 3×3 section organised by type × severity) so future maintainers do not have to update three scattered tables. Concrete layout left to architect; PRD binds the requirement.

### 5.4 PRD templates per type

- **R8** — Per-type PRD templates authored under `.claude/commands/scaff/prd-templates/` (new directory):
  - `feature.md` — byte-identical to the current PRD template (Problem / Goals / Non-goals / Users / Requirements / ACs / Decisions / Open questions).
  - `bug.md` — sections: Problem, Source (type + verbatim value per D1), Repro, Expected, Actual, Environment, Root cause (when known), Fix requirements (R1..Rn), Regression test requirements, Acceptance criteria (AC1..ACn), Decisions, Open questions.
  - `chore.md` — **checklist-shaped** per D2: Summary, Scope, Reason, Checklist items (`- [ ] <item> — verify: <assertion>`), Verify assertions (rolled up), Out-of-scope.
- **R8.1** — `pm.md`'s PRD-mode flow dispatches to the correct template based on the command that seeded the feature directory. The dispatch signal lives in STATUS (a `work-type: feature | bug | chore` field added at request time); `pm.md` reads it and selects template accordingly.

### 5.5 Slug conventions per type

- **R9** — Slug shape per type (per D4):
  - feature: `YYYYMMDD-<body>` (unchanged).
  - bug: `YYYYMMDD-fix-<body>` (new).
  - chore: `YYYYMMDD-chore-<body>` (new).

  The slug-generation logic in `request.md` / `bug.md` / `chore.md` enforces the correct prefix; a user-supplied slug that omits or conflicts with the required prefix is rejected with a usage error. Existing archives retain their current slugs (NG1).

### 5.6 Stage matrix (type × tier)

- **R10** — The 3×3 stage matrix (D3) is codified as **data** (not as scattered conditionals in command files). Architect's choice of carrier: extend `bin/scaff-tier` with a `stage_required <work-type> <tier> <stage>` predicate, OR introduce `bin/scaff-stage-matrix`, OR a data file read by both. PRD binds: the matrix MUST be a single source of truth readable by both command dispatchers and the archive retrospective flow.
- **R10.1** — The matrix MUST preserve the current feature behaviour byte-identically. Feature-tiny, feature-standard, feature-audited cells must reproduce today's skip semantics (see `bin/scaff-tier:tier_skips_stage` current logic).

### 5.7 Retrospective prompts per type

- **R11** — `tpm.md` gains per-type retrospective prompts (per D5). When `/scaff:archive` invokes the retrospective, TPM reads the work-type from STATUS and asks the type-appropriate reflection question:
  - **feature**: "What technical decisions surprised you? Architecture patterns worth extracting into memory?"
  - **bug**: "What guardrail (test, review axis, rule) would have caught this bug before release? Where in the pipeline did it slip through?"
  - **chore**: "Could this cleanup have been automated? Does it indicate a broader tech-debt pattern worth naming?"

### 5.8 Shared scaffold — no forking file structure

- **R12** — All three commands write the same file skeleton: `00-request.md` + `STATUS.md` (seeded from `.specaffold/features/_template/`). The `_template/` directory remains a single template; only its *content* is populated differently per command (e.g. `00-request.md` gains type-appropriate section labels). The file layout and filenames must not fork per type.
- **R13** — STATUS.md gains one new field (`work-type: feature | bug | chore`) inserted between `has-ui` and `tier`. The field is set by the originating command (`/scaff:request` → `feature`, `/scaff:bug` → `bug`, `/scaff:chore` → `chore`). Legacy archives without the field are treated as `work-type: feature` by any reader for backward compat.

### 5.9 Bug `<arg>` classification

- **R14** — `/scaff:bug` classifies its single positional argument into one of three types per D1:
  1. `type: url` if the arg matches `^https?://` (anchored at start).
  2. `type: ticket-id` if the arg matches the pattern `^[A-Z]+-[0-9]+$` (all-caps prefix, hyphen, digits).
  3. `type: description` (fallback) otherwise.
  The classifier is a pure function (string in, type string out) and lives in the command script. The detected type and verbatim arg are written to the PRD's Source field (see R8 bug template).

### 5.10 Documentation surface updates

- **R15** — Update `.claude/commands/scaff/next.md`, the repo `README.md` command reference, and any contributor doc that enumerates scaff commands, to mention the two new entries. The feature workflow doc (scenario 4.1) is unchanged; the two new entries are added alongside.

## 6. Acceptance criteria

Per `shared/dogfood-paradox-third-occurrence.md`, ACs distinguish **structural** (verifiable during this feature's own validate) from **runtime** (deferred to the next real bug or chore ticket after archive).

### 6.1 Structural ACs (verified in this feature's validate)

- **AC1** (structural) — `.claude/commands/scaff/bug.md` exists, parses `<arg>` + optional `--tier` + optional `<slug>`, classifies the arg per R14, and invokes `scaff-pm` with work-type=bug. Verify: file exists; `grep -E '^description:.*scaff:bug' bug.md` matches; command body references all three classification branches (`url`, `ticket-id`, `description`).
- **AC2** (structural) — `.claude/commands/scaff/chore.md` exists, parses `<ask>` + optional `--tier` + optional `<slug>`, invokes `scaff-pm` with work-type=chore. Verify: file exists; command body references the chore PRD template and the chore slug convention.
- **AC3** (structural) — `.claude/commands/scaff/request.md` content is byte-identical to the pre-change state for every line *except* the one line that writes `work-type: feature` to STATUS (the minimal required addition for R13). Verify: `git diff pre-change..HEAD -- .claude/commands/scaff/request.md` shows only the single work-type line addition, no other diff.
- **AC4** (structural) — `pm.md` contains two new probe branches (R4, R5) that are discoverable by reading the file: distinct sub-sections under "When invoked for /scaff:bug" and "When invoked for /scaff:chore". Verify: `grep` finds both section headers.
- **AC5** (structural) — `pm.md`'s tier-proposal section contains all three keyword sets (feature: existing; bug: R6; chore: R7) organised as a single 3×type table or three clearly-labelled sub-sections. Verify: all keyword-set section headers present; at least one keyword from each of R6's and R7's tiny and audited lists is grep-findable in pm.md.
- **AC6** (structural) — Three PRD template files exist under `.claude/commands/scaff/prd-templates/` (`feature.md`, `bug.md`, `chore.md`). `bug.md` includes a Source section with `type: url | ticket-id | description`. `chore.md` is checklist-shaped (contains `- [ ] <item> — verify:` pattern in its skeleton). `feature.md` preserves the current feature PRD shape (Problem / Goals / Non-goals / Users / Requirements / ACs / Decisions / Open questions headings all present). Verify: grep headings in each file.
- **AC7** (structural) — The slug-generation logic in `request.md`, `bug.md`, `chore.md` produces the right prefix per R9. Verify: static inspection of each command file shows the correct prefix (`<date>-<body>` for feature, `<date>-fix-<body>` for bug, `<date>-chore-<body>` for chore); usage-error branches reject an explicitly-passed slug that violates the prefix.
- **AC8** (structural) — The 3×3 stage matrix (D3) is codified in a single source-of-truth location (architect choice per R10), and that location contains all nine cells with the exact skip / required / optional decisions from D3. Verify: static inspection of the chosen carrier (bin script or data file) enumerates all 9 cells.
- **AC9** (structural) — Feature-tier stage skipping (R10.1) is preserved byte-identically: the current `tier_skips_stage` semantics (tiny: brainstorm/tech/design; standard: brainstorm; audited: none) still apply for `work-type: feature`. Verify: unit-test the predicate for all nine (tier × stage) feature cells; all match the current `bin/scaff-tier` outputs.
- **AC10** (structural) — `tpm.md` contains all three per-type retrospective prompts (R11) with the exact wording from D5. Verify: grep each prompt string in tpm.md.
- **AC11** (structural) — `STATUS.md` template (`.specaffold/features/_template/STATUS.md`) gains a `work-type:` field (R13). Verify: `grep '^- \*\*work-type\*\*:' .specaffold/features/_template/STATUS.md` matches.
- **AC12** (structural) — The `_template/` directory remains a single template (R12). Verify: no per-type subdirectories under `.specaffold/features/_template/`; only the type-conditional behaviour lives in command scripts and pm.md.
- **AC13** (structural) — Documentation surface updates (R15): README (or equivalent contributor doc) lists all three entry commands. Verify: grep `/scaff:bug` and `/scaff:chore` in the doc file.
- **AC14** (structural — baseline) — Existing archived features under `.specaffold/archive/**` are not renamed. Verify: `git ls-tree` of `.specaffold/archive/` before and after this feature matches for archive entries (no slug changes). Per `pm/ac-must-verify-existing-baseline.md`, baseline snapshot captured at PRD-lock time.

### 6.2 Runtime ACs (deferred)

- **AC-runtime-deferred** — The first runtime exercises of `/scaff:bug` and `/scaff:chore` cannot happen during this feature's own validate (dogfood paradox — this feature ships the commands). Verification is deferred to the **next real bug or chore ticket after archive**. Concrete handoff requirements:

  1. At archive time, TPM writes a STATUS Notes line: `YYYY-MM-DD archive — RUNTIME HANDOFF (for successor bug/chore): first real /scaff:bug or /scaff:chore invocation must open its STATUS Notes with "exercised entry-type-split commands on this feature's first live session".`
  2. The next feature whose origin is a bug ticket OR a chore sweep MUST include an opening STATUS Notes line confirming the command fired end-to-end and produced the expected per-type probe, PRD template, slug, and retrospective prompt.
  3. If no bug or chore ticket arises within two subsequent features, the operator may stage a synthetic exercise (a dummy bug ticket `/scaff:bug "test runtime exercise of bug command"` followed by immediate abandon) to close the runtime loop.

### 6.3 Regression test requirement

- **AC15** (structural) — Feature intake flow regression: a fixture invocation of `/scaff:request "<sample ask>"` (run in a sandboxed HOME per `.claude/rules/bash/sandbox-home-in-tests.md`) produces a feature directory whose file names, STATUS layout, and probe prompts are byte-identical to the pre-change baseline, with the sole exception of the single-line `work-type: feature` addition (R13 baseline carveout). Verify: diff the generated `00-request.md` and `STATUS.md` against a golden snapshot captured before this feature's implementation.

## 7. Open questions

None. Q1, Q3, Q4, Q5 from 00-request.md are resolved as decisions D2, D3, D4, D5; Q2 was resolved by the user at request time and is recorded as D1. No new ambiguities surfaced during PRD drafting.

## 8. Decisions

- **D1** — **Bug `<arg>` auto-classification** (resolves Q2, user-supplied at request time). `/scaff:bug` accepts exactly one positional argument, classified as:
  - `type: url` — arg starts with `http://` or `https://` (anchored `^https?://` match).
  - `type: ticket-id` — arg matches `^[A-Z]+-[0-9]+$` (all-caps prefix, hyphen, digits).
  - `type: description` — fallback for anything else.
  The detected type and verbatim value populate the PRD's Source field. No external fetch is performed; the arg is an opaque reference.

- **D2** — **Chore PRD shape = checklist, stored as `03-prd.md`** (resolves Q1). Chore features DO produce an `03-prd.md` file (for grep-ability and archive browsing), but the file's shape is a checklist ("items to do + verify assertions"), not the R1..Rn + AC1..ACn feature shape. Rationale: explicit beats absent; an empty/missing `03-prd.md` confuses the stage machine and downstream readers more than a short checklist does. The file uses the `chore.md` template (R8).

- **D3** — **3×3 stage matrix (type × tier)** (resolves Q3). Nine cells codify which stages run for each combination. Legend: ✅ required, 🔵 conditional / optional, — skipped.

  | Stage       | feature-tiny | feature-standard | feature-audited | bug-tiny | bug-standard | bug-audited | chore-tiny | chore-standard | chore-audited |
  |-------------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
  | request     | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  |
  | design      | —   | 🔵  | 🔵  | —   | 🔵  | 🔵  | —   | —   | —   |
  | prd         | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  |
  | tech        | —   | ✅  | ✅  | —   | 🔵  | ✅  | —   | —   | 🔵  |
  | plan        | 🔵  | ✅  | ✅  | 🔵  | ✅  | ✅  | 🔵  | ✅  | ✅  |
  | implement   | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  |
  | validate    | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  |
  | archive     | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  | ✅  |

  Key asymmetries (justification):
  - **design always — for chore**: chores are mechanical by construction; has-ui=false is a default invariant per R5, so the Designer stage has nothing to produce.
  - **tech — for chore-tiny / chore-standard**: most chores are single-author, mechanical (rename, dep bump, cleanup); architect review adds no value at those tiers. chore-audited re-enables tech as 🔵 because a dep bump touching security-sensitive surface may still warrant architect sign-off.
  - **validate ✅ for bug-tiny (not — as feature-tiny)**: bugs need a regression test regardless of tier; skipping validate lets the bug re-land. This is the most important asymmetry against feature-tiny.
  - **plan 🔵 for all -tiny cells**: a single-task checklist does not need wave scheduling. TPM may skip plan for tiny; `05-plan.md` may be a one-liner or absent (per tier-model's existing tiny convention).
  - **tech 🔵 for bug-standard**: architect review is optional for medium-severity bugs; must-run only when the fix touches contract surface (escalation gate left to PM's judgement at plan time).

- **D4** — **Slug convention per type + no retroactive rename** (resolves Q4).
  - feature: `YYYYMMDD-<body>` (unchanged).
  - bug: `YYYYMMDD-fix-<body>`.
  - chore: `YYYYMMDD-chore-<body>`.
  Existing archives keep their current slugs (NG1); only new features authored after this PR adopt the type-prefixed convention. Slug-generation logic in each command rejects user-supplied slugs that conflict with the required prefix.

- **D5** — **Per-type retrospective prompts** (resolves Q5). TPM's archive retrospective reads STATUS `work-type:` and asks the appropriate question:
  - feature: "What technical decisions surprised you? Architecture patterns worth extracting into memory?"
  - bug: "What guardrail (test, review axis, rule) would have caught this bug before release? Where in the pipeline did it slip through?"
  - chore: "Could this cleanup have been automated? Does it indicate a broader tech-debt pattern worth naming?"

- **D6** — **Dispatch signal = STATUS `work-type` field, not command-name sniffing.** The three entry commands each set `work-type: feature | bug | chore` in STATUS at intake. Every downstream consumer (pm.md for PRD template dispatch, tpm.md for retrospective dispatch, stage-matrix helper for per-cell decisions) reads STATUS rather than guessing the type from context or command history. This keeps the dispatch surface explicit and greppable.

- **D7** — **Template files colocated under `.claude/commands/scaff/prd-templates/`** (R8). Rationale: templates are a sibling concern to the commands that consume them; grouping them under `commands/scaff/` keeps the discoverable surface together rather than scattering templates across a second tree. Architect may override with a different layout if there is a compelling reason (e.g. existing convention); PRD binds the requirement that templates exist as discrete files, not inlined branches in pm.md.

- **D8** — **Structural-only validate for this feature.** Per `shared/dogfood-paradox-third-occurrence.md` (ninth occurrence documented). Every AC in §6.1 is structural; AC-runtime-deferred in §6.2 explicitly hands off runtime verification. The TPM will pre-commit the RUNTIME HANDOFF STATUS line in the final wave, not as an archive-time afterthought (discipline from the ninth occurrence).

## 9. Dogfood paradox

This feature ships the `/scaff:bug` and `/scaff:chore` commands it would invoke. The commands cannot be exercised against themselves during implement or validate — the commands do not exist until this feature merges. Per the shared memory's discipline:

- All §6.1 ACs are **structural** — they verify files exist, grep patterns match, command scripts are well-formed, and per-type branches are discoverable.
- §6.2 `AC-runtime-deferred` makes the handoff explicit: the next real bug or chore ticket after archive is the first runtime exercise.
- The TPM will author a task in the final wave that commits the RUNTIME HANDOFF STATUS Notes line (per the ninth-occurrence discipline promoted in the shared memory).
- The QA-tester's validate must not mark runtime ACs as PASS from "build succeeds"; it must explicitly mark them deferred with a pointer to AC-runtime-deferred.

## 10. Constraints

- **Bash 3.2 / BSD userland portability** for any command-script additions (`.claude/rules/bash/bash-32-portability.md`).
- **Sandbox HOME in tests** for any fixture or regression test (`.claude/rules/bash/sandbox-home-in-tests.md`) — AC15's golden-snapshot diff runs in a `mktemp -d` sandbox.
- **No force on user paths** (`.claude/rules/common/no-force-on-user-paths.md`) — slug-prefix rejection is a usage error, never a silent overwrite.
- **Classify before mutate** (`.claude/rules/common/classify-before-mutate.md`) — the bug `<arg>` classifier (R14) is a pure function; no side effects.
- **Language-preferences** (`.claude/rules/common/language-preferences.md`) — all file content is English regardless of `LANG_CHAT` setting; chat replies to the user during probe are zh-TW when `LANG_CHAT=zh-TW`.
