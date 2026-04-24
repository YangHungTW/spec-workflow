# Tech — entry-type-split

- **Slug**: 20260424-entry-type-split
- **Tier**: audited
- **Has-ui**: false
- **Authored**: 2026-04-24 by Architect
- **Related**: 03-prd.md (R1–R15, AC1–AC15 + AC-runtime-deferred, D1–D8), 00-request.md, STATUS.md

## 1. Context & Constraints

### 1.1 Existing stack in this repo (what's already committed)

- **Slash commands** live under `.claude/commands/scaff/*.md` — plain-markdown instruction files interpreted by Claude Code, not executable bash. Current entry is `request.md`.
- **Agent prompts** live under `.claude/agents/scaff/*.md` (pm.md, tpm.md, architect.md, developer.md, qa-tester.md, qa-analyst.md, designer.md). Appendices (`*.appendix.md`) hold reference material kept out of the main prompt to stay under context budget.
- **Helper libraries** live under `bin/scaff-*` — sourced bash libraries, bash 3.2 / BSD-portable. Current set: `scaff-tier` (tier classification + mutation, the precedent for a sourced-library-with-public-functions), `scaff-aggregate-verdicts`, `scaff-install-hook`, `scaff-lint`, `scaff-seed`.
- **Feature scaffold template** lives at `.specaffold/features/_template/` and is a single shared skeleton (per R12 — must stay single).
- **Archive** lives at `.specaffold/archive/<slug>/`; existing slugs must not be renamed (NG1).

### 1.2 Hard constraints

- **C1 — Bash 3.2 / BSD userland portability** (`.claude/rules/bash/bash-32-portability.md`). Any new helper function must run on stock macOS without brew-installed coreutils. No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical matching.
- **C2 — Classify-before-mutate** (`.claude/rules/common/classify-before-mutate.md`). The bug `<arg>` classifier (R14) is a pure function; the STATUS `work-type` reader is a pure classifier; mutation happens only in dispatch tables.
- **C3 — No force on user paths** (`.claude/rules/common/no-force-on-user-paths.md`). STATUS edits use the temp-file + atomic mv pattern, with `.bak` before mutate. Slug-prefix violations emit a usage error and exit non-zero; no silent overwrite.
- **C4 — R15 / G3 byte-identical feature intake**. `/scaff:request` must produce the same `00-request.md` + `03-prd.md` shape as today, with the sole permitted addition of one `work-type: feature` line to STATUS (per R13 and AC3).
- **C5 — Language-preferences** (`.claude/rules/common/language-preferences.md`). All file content including this doc is English; chat replies may be zh-TW when `LANG_CHAT=zh-TW`.
- **C6 — Dogfood paradox discipline** (`shared/dogfood-paradox-third-occurrence.md`, ninth occurrence). Structural-only validate for this feature. RUNTIME HANDOFF STATUS line pre-committed as a TPM task in the final wave (D8).

### 1.3 Soft preferences

- Match the precedent set by `bin/scaff-tier`: a single sourced library owning a bounded responsibility, with public functions documented in a header comment and a double-source guard.
- Prefer duplication in slash-command instruction files over shared helpers, because these are prompts for an LLM, not bash scripts; a prompt that inlines its flow is easier for the agent to follow than one that references a sidecar.
- Prefer grep-able, greppable, explicit markers in STATUS over clever derivation from other fields.

### 1.4 Forward constraints from later backlogs

- **Future external ticket fetch** (out-of-scope per NG2) — the `Source` field in the bug PRD template must store both the `type:` and the verbatim value so a future fetcher can pattern-match without re-parsing.
- **Future retroactive type tagging** — not in scope now, but STATUS `work-type` must remain readable from archive entries, so a future sweep could migrate legacy archives by appending the field without rewriting anything else.
- **Future synthetic-exercise automation** (AC-runtime-deferred §3) — if the two-feature grace window elapses, tooling may need to auto-file a synthetic bug. This is a future concern; do not pre-build it.

## 2. System Architecture

### 2.1 Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER-FACING SURFACE                         │
│                                                                 │
│  .claude/commands/scaff/                                        │
│    ├── request.md   ──► work-type=feature                       │
│    ├── bug.md       ──► work-type=bug       (NEW)               │
│    └── chore.md     ──► work-type=chore     (NEW)               │
│                                                                 │
│  Each command: parse args → slug-gen with type prefix →         │
│                seed _template/ → write STATUS work-type →       │
│                invoke scaff-pm with work-type marker            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SHARED SCAFFOLD                              │
│                                                                 │
│  .specaffold/features/_template/   (R12 — single template)      │
│    ├── STATUS.md    (gains `work-type:` field per R13)          │
│    └── 00-request.md   (content populated by command + PM)      │
│                                                                 │
│  .claude/commands/scaff/prd-templates/    (NEW dir, D7)         │
│    ├── feature.md   (byte-identical to today's PRD shape)       │
│    ├── bug.md       (Repro/Expected/Actual/Environment/Source)  │
│    └── chore.md     (checklist-shaped per D2)                   │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                 AGENT PROMPT DISPATCH                           │
│                                                                 │
│  pm.md — three probe branches + one tier-keyword table (R7.1)   │
│    §When invoked for /scaff:request  → feature probe            │
│    §When invoked for /scaff:bug      → bug probe (NEW)          │
│    §When invoked for /scaff:chore    → chore probe (NEW)        │
│    §PRD-mode dispatch: reads STATUS work-type → selects         │
│                        prd-templates/{feature|bug|chore}.md     │
│                                                                 │
│  tpm.md — three retrospective branches (R11) keyed on           │
│           STATUS work-type                                      │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│               HELPER LIBRARIES (bash 3.2 portable)              │
│                                                                 │
│  bin/scaff-tier           (unchanged — tier classifier)         │
│  bin/scaff-work-type      (NEW — work-type classifier + setter) │
│    public fns: get_work_type, set_work_type,                    │
│                classify_bug_arg                                 │
│  bin/scaff-stage-matrix   (NEW — 3×3 matrix, D3 codified)       │
│    public fns: stage_status, is_stage_required,                 │
│                is_stage_skipped                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Key scenario data flow

**Scenario 4.2 — `/scaff:bug "https://jira.example.com/PROJ-123"`**:

```
user invokes /scaff:bug <arg> [--tier X] [slug]
  │
  ▼
bug.md command script
  ├── classify_bug_arg "<arg>" → "url" | "ticket-id" | "description"
  │     (sourced from bin/scaff-work-type; pure function; no side effects)
  ├── generate slug: "YYYYMMDD-fix-<body>" (body from ask or user-supplied)
  │     (reject user-supplied slug that violates prefix — usage error, exit 2)
  ├── mkdir .specaffold/features/<slug>/ ; seed from _template/
  ├── write 00-request.md with Source: {type, verbatim_value}
  ├── set_work_type <feature_dir> bug   (from bin/scaff-work-type)
  │     backs up STATUS.md → STATUS.md.bak; atomic mv of updated STATUS
  ├── set_tier    <feature_dir> <tier> request "user via --tier flag"
  │     (unchanged scaff-tier call path)
  └── invoke scaff-pm agent with work-type=bug
       └── pm.md reads STATUS work-type → enters bug probe branch
           → probes for repro/expected/actual/environment
           → when producing 03-prd.md, reads work-type again →
             selects prd-templates/bug.md → fills placeholders
```

Feature and chore flows are structurally identical, differing only in slug prefix, PRD template, probe questions, and tier-keyword table consulted.

### 2.3 Module boundaries

- **Command script** (`bug.md` / `chore.md` / `request.md`): owns arg parsing, slug generation, seeding, and STATUS initialisation. Does not own probe content or PRD template content.
- **`bin/scaff-work-type`**: owns `work-type` field read/write/classify. Single source of truth for the STATUS field name format. Mirrors `scaff-tier`'s shape and rules.
- **`bin/scaff-stage-matrix`**: owns the 3×3 (type × tier × stage) matrix as data-in-function. Exposes predicates used by `/scaff:next`, `/scaff:implement`, and TPM's retrospective dispatcher. Does not read STATUS itself — takes `work-type` and `tier` as arguments.
- **`pm.md`**: owns probe content and PRD-mode dispatch. Reads STATUS via helpers; does not re-parse STATUS fields itself.
- **`tpm.md`**: owns retrospective dispatch. Reads STATUS via helpers; selects prompt by `work-type`.

## 3. Technology Decisions

### tech-D1. Stage matrix carrier — new sourced library `bin/scaff-stage-matrix`

- **Options considered**:
  - **(a)** Extend `bin/scaff-tier` with a `stage_required <work-type> <tier> <stage>` function.
  - **(b)** New sourced library `bin/scaff-stage-matrix` with the predicate as a public function.
  - **(c)** YAML/JSON data file at `.claude/stage-matrix.yml`, parsed by scripts at call time.
- **Chosen**: **(b)** — new library `bin/scaff-stage-matrix`.
- **Why**: `scaff-tier` owns a single responsibility (tier read/write/transition). The 3×3 matrix is a join of two dimensions — type **and** tier — and belongs to neither alone. Adding a `stage_required` function to `scaff-tier` would overload its scope. A data file (option c) adds a parser dependency (no `jq` per C1; bash-parsed YAML is worse than bash-encoded table); data-in-function is simpler at this volume (9 cells × 8 stages ≈ 72 decisions, expressible as an `if/case` table).
- **Tradeoffs accepted**: a second `bin/scaff-*` file to discover. Mitigated by naming parallel to `scaff-tier` and following the same header/API conventions.
- **Reversibility**: high. Single consumer surface (the public-function names); folding the matrix into `scaff-tier` later is a mechanical refactor.
- **Requirement link**: R10, R10.1, D3.

### tech-D2. STATUS `work-type` field — explicit typed line, not slug-derived

- **Options considered**:
  - **(a)** Explicit `- **work-type**: feature|bug|chore` line in the STATUS header block, inserted between `has-ui` and `tier`.
  - **(b)** Derived at read-time from slug prefix (pattern-match `-fix-` → bug; `-chore-` → chore; else feature).
- **Chosen**: **(a)** — explicit field.
- **Why**: D6 binds "dispatch signal = STATUS field, not command-name sniffing." A slug-prefix match is a different form of sniffing — the body of a slug could coincidentally contain `-fix-` (e.g. a feature slug `20260501-postfix-expression-parser`). Explicit makes the dispatch surface greppable; `grep '^- \*\*work-type\*\*:' STATUS.md` is the authoritative test.
- **Tradeoffs accepted**: one more line in STATUS; a retrofit step for legacy archives (handled by tech-D3 default).
- **Reversibility**: medium. The field name is the wire contract; once templates and agents read it, renaming requires a sweep. Low volume of consumers at ship time keeps the cost bounded.
- **Requirement link**: R13, D6.

### tech-D3. Legacy `work-type` default — `feature`, no retroactive migration

- **Options considered**:
  - **(a)** Default to `feature` when the STATUS field is absent. No migration.
  - **(b)** Error / refuse if missing. Forces retrofit of every legacy archive.
  - **(c)** Return `missing` sentinel (mirrors `scaff-tier`'s `missing`/`malformed` pattern); callers dispatch.
- **Chosen**: **(a)** — default to `feature`.
- **Why**: Every pre-existing archive is a feature by construction (there was no other entry command). `feature` is therefore semantically correct for legacy archives, not a fallback stub. Defaulting at the read path means zero retroactive migration work; legacy archives browse identically to before. The `scaff-tier` precedent (option c) is right for `scaff-tier` because tier is a required invariant; `work-type` has a trivially-correct default.
- **Tradeoffs accepted**: a mistyped or malformed `work-type` line could silently be treated as feature. Mitigated by tech-D5's malformed handling: we distinguish "line absent" (default feature) from "line present, value not in enum" (malformed → surface loudly).
- **Reversibility**: high. Changing the default in one helper function propagates everywhere.
- **Requirement link**: R13 backward-compat clause.

### tech-D4. Command file code — full duplication between `request.md`, `bug.md`, `chore.md`

- **Options considered**:
  - **(a)** Three self-contained slash-command files, each with their own full flow.
  - **(b)** One shared helper sourced by all three (e.g. `_common-intake.sh`).
  - **(c)** Single file with `case` branches by command name (rejected outright — violates D6 "no command-name sniffing" if the logic branches on command name inside a single file).
- **Chosen**: **(a)** — full duplication.
- **Why**: These are Claude-Code-interpreted markdown instruction files, not executable bash. The "code" is natural-language flow steps + small inline bash blocks. An agent following an instruction file performs better with inlined flow than with "now open `_common-intake.sh` and follow it." The bash primitives that are genuinely shared (slug generation, STATUS init, classify-bug-arg, set-work-type) live in `bin/scaff-work-type` and are invoked identically from all three files — so the deep logic is not actually duplicated; only the flow narration is.
- **Tradeoffs accepted**: a change to the shared flow (e.g. a new STATUS field) must be applied to three files. Acceptable at three files; revisit if the count grows.
- **Reversibility**: medium-high. Consolidating later into a shared prompt fragment is a mechanical merge.
- **Requirement link**: R1, R2, R3.

### tech-D5. `pm.md` structure — three parallel `When invoked for /scaff:<cmd>` sections

- **Options considered**:
  - **(a)** Three separate `## When invoked for /scaff:request` / `/scaff:bug` / `/scaff:chore` sections, each with its own probe flow and exit conditions.
  - **(b)** One section with inline branches: "if work-type=feature: ask X; if bug: ask Y; if chore: ask Z".
- **Chosen**: **(a)** — three parallel sections.
- **Why**: `pm.md` already uses the `## When invoked for …` idiom for `/scaff:request`, `/scaff:prd`, `/scaff:update-req`. Parallel sections are how the agent prompt navigates. Inline branches (option b) would conflate three distinct probe shapes into one section and slow agent navigation. Parallel sections are also the grep-able unit for AC4.
- **Tradeoffs accepted**: pm.md grows by two sections. Acceptable; appendix already exists for overflow.
- **Reversibility**: high. Refactor cost is one file.
- **Requirement link**: R4, R5, AC4.

### tech-D6. Tier keyword tables — one master table with `type` column (3×3)

- **Options considered**:
  - **(a)** One master table with columns `type`, `tiny-keywords`, `audited-keywords`; rows = {feature, bug, chore}. Default = standard is a footnote.
  - **(b)** Three parallel tables, one per type, each with tiny / standard / audited rows.
- **Chosen**: **(a)** — one master table with a `type` column.
- **Why**: R7.1 explicitly binds "one shared location … a 3×3 section organised by type × severity so future maintainers do not have to update three scattered tables." A single table is the most literal reading of R7.1. It fits on one screen; the `type` column makes the intended reading pattern obvious ("find your row, read across"). Option (b) invites drift — three tables can fall out of sync on format without the diff screaming.
- **Tradeoffs accepted**: each row may grow wide. Mitigated by a wrapped-list layout where needed.
- **Reversibility**: high — text format, no code consumers.
- **Requirement link**: R6, R7, R7.1, AC5.

### tech-D7. PRD template format — plain markdown with HTML-comment placeholders

- **Options considered**:
  - **(a)** Plain markdown with `<!-- placeholder: <description> -->` comments at fill-in points; PM agent replaces placeholders inline.
  - **(b)** Mustache-style `{{placeholder}}` tokens.
  - **(c)** Inline-prompt templates embedded in pm.md itself (rejected — D7 binds "discrete files").
- **Chosen**: **(a)** — plain markdown with HTML-comment placeholders.
- **Why**: HTML comments render invisibly in markdown preview, so a partly-filled template is already legible as documentation. The PM agent already substitutes content into skeleton markdown (`00-request.md` today) without any templating engine; HTML-comment markers are the minimum cue the agent needs to locate a fill-in point. Option (b) would require templating logic that doesn't exist today; option (c) is forbidden by D7.
- **Tradeoffs accepted**: no compile-time check that all placeholders are filled. Mitigated by AC6 grep assertions on heading presence.
- **Reversibility**: medium-high.
- **Requirement link**: R8, D7.

### tech-D8. Backward-compat verification for `/scaff:request` — shape-assertion grep, not byte diff

- **Options considered**:
  - **(a)** Capture a golden snapshot of a pre-feature `/scaff:request` fixture run, byte-diff the post-feature run.
  - **(b)** Grep-based shape assertion: assert that the generated `00-request.md` + `03-prd.md` contain the canonical feature-shape headings (`## Problem`, `## Goals`, `## Non-goals`, `## Requirements`, `## Acceptance criteria`, `## Decisions`, `## Open questions`) and that `STATUS.md` differs from baseline in exactly one added line (`work-type: feature`) plus the normal date/time-varying lines.
  - **(c)** "It compiles and existing regression tests pass."
- **Chosen**: **(b)** — grep-based shape assertion, sandbox-hosted per `.claude/rules/bash/sandbox-home-in-tests.md`.
- **Why**: A byte-diff (option a) is brittle — a date stamp, a line wrap, or whitespace normalisation breaks it even when semantics are preserved. A shape assertion captures the invariants that actually matter: required sections present, headings in the right order, STATUS diff matches the single permitted R13 addition. Option (c) fails AC15's explicit "byte-identical" intent. Option (b) is the strictest assertion that remains robust. AC15 and AC3 already name this approach in the PRD.
- **Tradeoffs accepted**: a semantic regression that doesn't touch headings (e.g. a reordered probe question) would slip past the shape assertion. Mitigated by including at least one probe-content spot-check grep (e.g. `grep -q 'why now' 00-request.md`).
- **Reversibility**: high — test code.
- **Requirement link**: R3, R15, AC3, AC15.

### tech-D9. Stage-matrix consumers and ABI

- **Options considered**:
  - **(a)** Single predicate `is_stage_required <work-type> <tier> <stage>` returning 0 (required) or 1 (skip/optional).
  - **(b)** Single lister `get_required_stages <work-type> <tier>` returning a whitespace-separated list.
  - **(c)** Ternary classifier `stage_status <work-type> <tier> <stage>` emitting `required` | `optional` | `skipped` on stdout.
- **Chosen**: **(c)** — ternary classifier as the primary ABI; **(a)** as a thin wrapper; **(b)** derivable but not a core function.
- **Why**: D3's matrix has three decision values (✅ required, 🔵 optional, — skipped). A binary predicate (option a) collapses `optional` and `required` or collapses `optional` and `skipped` — both lose information. The ternary stdout classifier (option c) matches the existing `scaff-tier` pattern (`get_tier` returns one-of-enum on stdout). A derived `is_stage_skipped` / `is_stage_required` wrapper is a two-line function on top. Enumerated consumers at ship time: `/scaff:next` (whether to auto-skip a stage), `/scaff:implement` (whether design is required), `/scaff:archive` (retrospective prompt dispatch via `tpm.md` reads work-type directly, not the matrix). Future consumers discovered later: any script that walks the stage machine.
- **Tradeoffs accepted**: callers must dispatch on the classifier string output. Acceptable and matches the existing convention.
- **Reversibility**: medium. The function signature is the wire contract; renaming later means a grep-and-replace across the scaff command set.
- **Requirement link**: R10, D3.

### tech-D10. Dogfood runtime-handoff artefact location

- **Options considered**:
  - **(a)** RUNTIME HANDOFF line written only to this feature's STATUS Notes at archive time.
  - **(b)** RUNTIME HANDOFF line pre-committed by TPM in the final implement wave, written to STATUS Notes and asserted structurally by a test task.
  - **(c)** Separate `09-runtime-handoff.md` artefact.
- **Chosen**: **(b)** — pre-committed STATUS Notes line, asserted structurally by a test task in the final wave.
- **Why**: D8 and the ninth-occurrence discipline in `shared/dogfood-paradox-third-occurrence.md` explicitly bind pre-commit in the final wave, not archive-time afterthought. A separate artefact (option c) would be a new file not served by any existing tool; STATUS Notes is already the audit trail. The structural assertion (grep the sentinel line from STATUS Notes) is the runtime-deferred equivalent of a compile check: it doesn't verify the command fires, but it verifies the handoff contract is in place for the next feature to honour.
- **Tradeoffs accepted**: the handoff line is prose; a typo could leak past the grep. Mitigated by a tight regex: `^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):`.
- **Reversibility**: high — test task.
- **Requirement link**: AC-runtime-deferred (§6.2), D8, shared/dogfood-paradox-third-occurrence.md ninth-occurrence sub-pattern.

## 4. Cross-cutting Concerns

### 4.1 Error handling strategy

- **Usage errors** (unknown arg, missing required positional, slug-prefix mismatch, unknown tier): print a single-line usage message to stderr, exit 2. Same convention as `scaff-tier`'s `set_tier` usage error path.
- **STATUS mutation failures** (STATUS.md absent, `.bak` write failure): print error to stderr, exit 2, leave STATUS untouched. The `cp … .bak` before the temp-file + mv flow guarantees no partial write state.
- **Malformed `work-type` value** (line present, value not in `feature|bug|chore`): `get_work_type` emits `malformed` on stdout; callers must surface to user and refuse to dispatch (no silent fallback to `feature` in the malformed case — only the absent case defaults).
- **Classify-bug-arg ambiguity**: by construction none — the classifier is a cascade (url → ticket-id → description fallback). Every input maps to exactly one type.

### 4.2 Logging / observability

- STATUS Notes remains the single audit trail. Every mutation appends a `YYYY-MM-DD <role> — <action>` line, matching the existing `scaff-tier` `set_tier` convention.
- No structured logging. No metrics. CLI stdout is kept English for log-parsing (per `.claude/rules/common/language-preferences.md` carve-out d).

### 4.3 Security posture — architect-gate sign-off (tier=audited)

This feature's blast radius is **entirely internal to the scaff workflow surface**: new slash commands, new bash helper libraries, new PRD template files, new STATUS field. There is:

- **No new authn/authz surface** — commands run with the invoking user's existing permissions on local files only.
- **No network I/O** — NG2 explicitly excludes external ticket fetches; `/scaff:bug` accepts the URL as opaque text.
- **No process spawning from untrusted input** — the bug arg is stored verbatim as text; never interpolated into a shell command. The classifier is a pure POSIX-string-match pipeline.
- **No path traversal risk on new surfaces** — slug generation constrains output to `.specaffold/features/<slug>/` under REPO_ROOT; the existing `scaff-tier` `_tier_resolve_and_check` boundary-check pattern is reused by `scaff-work-type` for feature-dir arguments (explicit requirement for the new helper, not optional).
- **STATUS mutation follows the no-force pattern** (C3): `.bak` before mutate, atomic temp-file + mv, never interactive prompt, never silent clobber.

**Architect-gate sign-off**: **APPROVED for tier=audited**. The audited designation is correct because the feature touches the authoring surface for every future work item — a regression here would be felt across every `/scaff:*` invocation going forward. That is a blast-radius concern, not a security-surface concern. The security axis (R14 classifier input validation, R12 template isolation, no-force discipline) is materially light: all input stays local, all writes go to feature-dir paths already gated by the existing `REPO_ROOT` boundary check, and no new executable surface is exposed. Reviewer axis coverage at wave-merge time (performance + style + security per `.claude/rules/reviewer/*`) is sufficient; no additional security review gate is warranted at tech stage.

### 4.4 Testing strategy (feeds Developer's TDD)

- **Unit** — pure functions in `bin/scaff-work-type` and `bin/scaff-stage-matrix` are unit-testable (`classify_bug_arg`, `get_work_type` read-only, `stage_status`). Fixture-driven: input → expected enum output. Matches `scaff-tier`'s existing fixture pattern.
- **Integration** — one end-to-end fixture per command (feature/bug/chore) invoking the flow in a sandboxed HOME (per `.claude/rules/bash/sandbox-home-in-tests.md`): sandbox → invoke command → assert feature dir exists, STATUS has correct `work-type`, slug has correct prefix, PRD template was copied.
- **Regression** — AC15: sandboxed `/scaff:request "<ask>"` invocation must produce the feature-shape `00-request.md` + STATUS that differs from baseline in exactly the R13 `work-type: feature` line and the normal date/time-varying lines. Asserted via grep shape check (tech-D8) plus a tight diff allowlist.
- **Structural for self-shipped commands** — per dogfood paradox, `/scaff:bug` and `/scaff:chore` are exercised only structurally in this feature's validate: file existence, grep assertions, classify-function fixtures. Runtime handoff per tech-D10.

### 4.5 Performance / scale

No performance requirements from PRD. New code paths run at most once per `/scaff:*` invocation; none are on a tight loop, none are in a hook. Reviewer-performance axis checks will apply at wave merge to any loop-shaped code that emerges during implement, but the design above does not anticipate any.

## 5. Open Questions

None. Every decision point surfaced by the 03-prd.md hand-off and every architect-specific gap named in the `/scaff:tech` brief has been bound in §3 as tech-D1..tech-D10.

## 6. Non-decisions (deferred)

- **External ticket fetch** — NG2. Trigger to revisit: a later feature that wants `/scaff:bug` to auto-populate `Source` from a live API. Requires a secret-handling decision (credential storage), which is why it is deferred.
- **Retroactive slug/`work-type` migration for archived features** — NG1 + tech-D3 default. Trigger to revisit: a future reporting or analytics feature that needs to aggregate by work-type across history. A sweep script can retrofit `- **work-type**: feature` into each legacy STATUS.md at that point without any other mutation; out of scope now.
- **`--force` override on slug-prefix validation** — per `.claude/rules/common/no-force-on-user-paths.md` and architect global memory (no-force-by-default). Trigger to revisit: reported friction where a user legitimately needs a slug prefix that conflicts with the type convention. Not anticipated; do not pre-build.
- **Consolidation of the three command files into a shared fragment** — tech-D4 accepts duplication at N=3. Trigger to revisit: a fourth or fifth entry command, or a cross-cutting flow change that requires three-file edits repeatedly.
- **Data-file carrier for the stage matrix** — tech-D1 chose a sourced library. Trigger to revisit: the matrix grows beyond ~10 cells or needs to be consumed by a non-bash tool (e.g. a Python reporting script).

## Team memory

- `architect/shell-portability-readlink.md` (global) — applied: `bin/scaff-work-type` and `bin/scaff-stage-matrix` must follow the bash 3.2 portability discipline and the `resolve_path` pattern used by `scaff-tier`.
- `architect/no-force-by-default.md` (global) — applied: STATUS mutation discipline (backup before mutate, atomic mv, no `--force`); slug-prefix violation rejected as usage error, not silently corrected.
- `architect/script-location-convention.md` (global) — applied: new helpers land at `bin/scaff-work-type` and `bin/scaff-stage-matrix` (no extension, exec bit on library scripts matches `scaff-tier` precedent).
- `architect/classification-before-mutation.md` (global) — applied: `classify_bug_arg` and `get_work_type` are pure classifiers; mutation lives only in command-script dispatch and `set_work_type`.
- `shared/dogfood-paradox-third-occurrence.md` (local) — applied: tech-D10 binds the ninth-occurrence pre-commit-in-final-wave discipline for the RUNTIME HANDOFF STATUS line.

## STATUS note

- 2026-04-24 Architect — 04-tech.md authored: 10 tech-Ds (stage-matrix carrier, work-type field, legacy default, command-file duplication, pm.md structure, keyword table layout, template format, backward-compat verification, matrix ABI, runtime-handoff artefact); §5 empty; architect-gate sign-off = APPROVED for tier=audited (security surface light — no network, no new auth, all writes under REPO_ROOT).
