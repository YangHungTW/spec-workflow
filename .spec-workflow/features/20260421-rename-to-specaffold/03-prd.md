# PRD — rename-to-specaffold

**Feature**: `20260421-rename-to-specaffold`
**Stage**: prd
**Author**: PM
**Date**: 2026-04-21
**Tier**: standard (brainstorm skipped by tier policy; design skipped, `has-ui: false`)

## 1. Summary

The product has lived under two overlapping names — `spec-workflow` (repo /
directory) and `specflow` (CLI namespace, slash-command prefix, agent-name
prefix, directory-seed path). Every contributor hits the collision on first
read. A product-naming decision selected **Specaffold** (portmanteau of "spec"
+ "scaffold") as the single canonical name, and **`scaff`** as the short CLI
alias (9-letter `specaffold` is painful to type at a shell prompt). This
feature is a **rename-only** pass: no functional changes, no new surfaces, no
retired behaviour. Every user-visible mention of `specflow` or `spec-workflow`
is replaced with the Specaffold / `scaff` pair, with archived feature
artefacts preserved verbatim as a historical record.

The feature invokes the **dogfood paradox** (ninth recurrence tracked in
`shared/dogfood-paradox-third-occurrence.md`): the renaming mechanism renames
the harness that is running the rename. Structural verification is the
archive gate; runtime verification — that a `/<new-prefix>:request` on a fresh
feature dispatches cleanly — is deferred to the next feature after archive.

## 2. Goals

- A new contributor reads the README and sees one name: **Specaffold**, with
  `scaff` as the short-form CLI actually typed at the shell.
- All user-visible surfaces (README, top-level docs, slash-command
  descriptions, agent frontmatter `name:` + `description:`) refer to
  Specaffold; old names do not appear in any user-facing surface.
- Slash commands are invoked under the new namespace (final prefix decided at
  §7 Q1); agent names no longer start with `specflow-`.
- `grep -r "spec-workflow\|specflow"` against the repo returns zero hits OR
  only intentional carryover (see R6 for the allow-list).
- CLI alias `scaff` is installed and documented as the short form.
- Self-dogfood: after the rename merges, a fresh `/<new-prefix>:request "<test
  ask>"` on a new feature works end-to-end with no `specflow-*` dispatch
  errors (runtime AC, deferred to next feature).
- Archived features retain their original slugs, STATUS history, and PRD
  text; the historical record is not rewritten.

## 3. Non-goals

- No functional changes to the workflow stages, tier model, reviewer axes,
  hook payloads, or orchestration logic.
- No new commands, agents, rules, or memories.
- No public release, package publishing, or GitHub repo rename. The in-tree
  identity changes here; any external repo-transfer is a separate operational
  step owned by the user.
- No UX / visual-identity work (logo, palette, marketing copy beyond the
  README tagline).
- No rewriting of archived features' slugs, STATUS, plan, tech, or PRD text.
  Archived artefacts are read-only history.
- No rename of the repo working-tree directory on disk
  (`/Users/yanghungtw/Tools/spec-workflow`). The user may rename the checkout
  independently; absolute-symlink targets installed globally will need a
  subsequent `claude-symlink install` pass either way, which is the same
  recovery already documented in `common/absolute-symlink-targets.md`.
- No deprecation / alias window for old names. Hard cutover at merge (see
  Decision D1 below).
- No back-compat shim for the old slash-command prefix. Users invoking the
  old prefix after merge see "unknown command" and consult the README.

## 4. Users and scenarios

**Primary users**: the Specaffold orchestrator and the 7 agent roles that run
inside it (PM, Architect, TPM, Designer, Developer, QA-analyst, QA-tester).
**Secondary users**: the human developer invoking slash commands, reading
the README, running `scaff` at the shell, and consuming agent dispatch names
in STATUS trails.

### 4.1 Scenarios

| # | Actor | Scenario | Outcome |
|---|---|---|---|
| S1 | New contributor | Clones the repo, reads the README | Sees "Specaffold" as the product name; sees `scaff` as the short CLI; no `specflow` confusion |
| S2 | Developer | Runs `/<new-prefix>:request "add login page"` in a fresh session | Command dispatches cleanly; PM agent runs under new name; `00-request.md` is seeded |
| S3 | Developer | Runs `scaff lint` (or the renamed equivalent of `specflow-lint`) | Lint binary responds under the new alias |
| S4 | Orchestrator | Dispatches the PM agent during `/<new-prefix>:prd` | Agent name resolves against the new `<new-agent-prefix>-pm` entry; no `specflow-pm` lookup leaks |
| S5 | Reviewer bot | Runs `grep -r "specflow\|spec-workflow"` against the repo | Returns zero hits, or only hits inside the R6 allow-list (archived slugs, git history, migration notes) |
| S6 | Archivist | Opens `.spec-workflow/archive/20260419-flow-monitor/03-prd.md` after the rename | File text is unchanged; historical record preserved |

## 5. Requirements

Each requirement is testable. "Old names" means the strings `specflow` and
`spec-workflow` (case-insensitive where the surface is prose; case-sensitive
where the surface is code or a path). "New names" means the strings
`specaffold` (product) and `scaff` (CLI alias).

### Surface rename

- **R1** — The top-level `README.md` refers to the product as **Specaffold**
  in its title, tagline, and every prose mention. The short CLI alias
  `scaff` is documented at the first install step.
- **R2** — [CHANGED 2026-04-21] Every slash-command file under
  `.claude/commands/` has been relocated from `.claude/commands/specflow/`
  to `.claude/commands/scaff/`. The command frontmatter `description:`
  field mentions Specaffold, not specflow.
- **R3** — [CHANGED 2026-04-21] Every agent file under `.claude/agents/`
  has its frontmatter `name:` and `description:` fields rewritten to the
  `scaff-*` prefix (e.g. `scaff-pm`, `scaff-architect`). The agent prompt
  body refers to the product as Specaffold where the old name appeared.
- **R4** — Top-level documentation files (anything matching `docs/**/*.md`
  or root-level `*.md` other than archived feature artefacts) refer to
  Specaffold, not specflow.
- **R5** — The CLI alias `scaff` is available (installed script, shell
  function, or symlink — implementation decided by Architect) and its path
  is documented in the README install section.

### Grep allow-list and internal rewrites

- **R6** — [CHANGED 2026-04-21] After the rename, `grep -r
  "spec-workflow\|specflow"` on the repo returns zero hits OR only hits
  inside this allow-list, which MUST be enumerated as a single file at
  `.claude/carryover-allowlist.txt` (path confirmed by TPM at plan time):
  - `.git/**` (git history, immutable)
  - `.specaffold/archive/**` (archived feature artefacts — historical
    record, see R11; path reflects renamed root per D6)
  - `.specaffold/archive/*/03-prd.md` body text (may reference the old
    name as historical prose)
  - Archived features' internal `.spec-workflow/…` path references that
    resolve via the compat symlink (see R17) — grep will see the string
    inside archived artefact bodies; these are R11-protected
  - The backwards-compat symlink itself (`.spec-workflow → .specaffold`,
    see R17) — the symlink name contains `spec-workflow` by design
  - Explicit migration notes authored by this feature (a new
    `docs/rename-migration.md` or equivalent; path confirmed at plan)
  - One or two retrospective bullets in this feature's own RETROSPECTIVE.md
  Any hit outside the allow-list is a grep-assertion failure.
- **R7** — [CHANGED 2026-04-21] Every `bin/specflow-*` script is renamed
  to its `scaff-*` counterpart (e.g. `bin/specflow-seed` → `bin/scaff-seed`,
  `bin/specflow-lint` → `bin/scaff-lint`). All internal references (other
  scripts invoking it, README examples, hook scripts) are updated to the
  new name.
- **R8** — Hook scripts under `.claude/hooks/` (`session-start.sh`,
  `stop.sh`) have their comments, echo strings, and path references
  updated to the new names. Hook wall-clock stays within the 200 ms budget
  from `reviewer/performance.md` entry 7 (R5 SLA).
- **R9** — Rule files under `.claude/rules/` have their body prose updated
  where they mention the old product name. Example: the shared memory
  cross-reference lines and the bash-32-portability example that cites
  `.claude/hooks/stop.sh` in feature `shareable-hooks`.
- **R10** — Team-memory files under `.claude/team-memory/` have their body
  prose updated where they mention the old product name. Filename slugs
  are NOT renamed (they are referenced by other memories and by agent
  prompts via stable paths).

### Archived-artefact preservation

- **R11** — [CHANGED 2026-04-21] Files under `.specaffold/archive/**`
  (post-rename path; formerly `.spec-workflow/archive/**`) are NOT
  modified. Archived feature slugs (`20260419-flow-monitor`, etc.), their
  `STATUS.md`, `03-prd.md`, `05-plan.md`, and all other stage artefacts
  remain byte-identical after the rename — including internal path
  references that say `.spec-workflow/…` (these resolve via the compat
  symlink per R17). This is a hard constraint; rewriting archived history
  would destroy the audit trail.
- **R12** — [CHANGED 2026-04-21] The `.spec-workflow/` root directory is
  renamed to `.specaffold/` (per D6). The archive subtree remains
  unmodified and reachable both from the new canonical path
  (`.specaffold/archive/`) and from legacy cross-references via the R17
  compat symlink.

### Self-dogfood

- **R13** — (structural) After merge, running `/<new-prefix>:request "<test
  ask>"` in a fresh session dispatches to the renamed PM agent without any
  `specflow-*` name resolution error. The structural portion of this
  requirement is: the dispatch table, agent name, and command file all
  carry consistent new-prefix strings that reference each other
  correctly. See §6 Dogfood paradox.
- **R14** — (runtime, deferred) On the next feature authored after this
  one archives, the first `/<new-prefix>:request` invocation runs
  end-to-end through at least the PRD stage with no leftover `specflow-*`
  dispatch errors. Runtime PASS recorded on the successor feature's
  STATUS; structural PASS recorded on this feature's validate.

### Migration surface

- **R15** — A single migration notes document (path TBC at plan time,
  suggested `docs/rename-migration.md`) explains: old prefix → new prefix
  table, the decision to hard-cut over with no alias window (see Decision
  D1), and the `claude-symlink install` recovery step for users with
  stale global installs (see Decision D3). This document is allowed to
  mention old names (cross-reference with R6 allow-list).
- **R16** — The global install path surface (`~/.claude/agents/specflow/`,
  `~/.claude/commands/specflow/`, etc.) is NOT renamed in this feature.
  Migration happens organically on the user's next
  `bin/claude-symlink install` or equivalent (see Decision D3). Migration
  notes call this out.
- **R17** — [CHANGED 2026-04-21] A backwards-compat symlink
  `.spec-workflow → .specaffold` is authored at the repo root during the
  rename. Authoring ownership: `bin/scaff-seed` (renamed from
  `bin/specflow-seed` per R7) is the owning binary; it creates the symlink
  on `update`/`install` runs if `.specaffold/` exists and
  `.spec-workflow` is absent or already a symlink pointing at
  `.specaffold`. Rationale: archived features (R11-protected) contain
  internal `.spec-workflow/…` path references; the symlink keeps those
  resolvable without modifying archived artefacts. The symlink target is
  absolute per `common/absolute-symlink-targets.md`. The symlink path
  itself is enumerated in the R6 allow-list.

## 6. Edge cases and open risks

### Dogfood paradox (9th+ occurrence)

This feature renames the harness during a run of the harness. While the
rename is in flight:

- The **current** session continues using the old names (agents and
  commands are resolved at session start; in-flight dispatch does not
  re-read). This is acceptable — the PM, Architect, TPM, Developer, and
  QA agents running this feature can all operate under the old prefix
  until the feature merges and the next session restart picks up the new
  prefix.
- The feature's own `/specflow:validate` (assuming it is still named
  that at merge time) runs under the old name. This is intentional: the
  validate stage verifies the rename structurally, but the validate
  command itself is one of the commands being renamed. Architect and TPM
  must sequence the validate-command rename to happen **in the last
  wave**, and the validate invocation for this feature uses the pre-
  rename command. See `shared/dogfood-paradox-third-occurrence.md` for
  the standing pattern.
- Per the ninth-occurrence discipline, TPM pre-commits the RUNTIME
  HANDOFF STATUS line as a final-wave task (not an archive-time
  afterthought). Suggested wording:
  > `RUNTIME HANDOFF (for successor feature): opening STATUS Notes line
  > must read "YYYY-MM-DD orchestrator — Specaffold rename exercised on
  > this feature's first live session". 1 runtime AC deferred; see §9
  > AC-R14.`

### AC-R14 is the only runtime-deferred AC

The rest of the ACs are verifiable structurally (file contents, grep
results, filename existence). Only the live-dispatch smoke on the next
feature is truly runtime. The structural/runtime split is therefore
lopsided toward structural — expected for a rename-only feature.

### Carryover allow-list drift

The R6 allow-list is a moving target if future work adds new migration
notes. The list lives in version control so any future addition is a
reviewable diff; at validate time, the grep assertion reads the list and
produces a PASS only if every hit is listed. QA-analyst owns the
assertion script.

### Team-memory path stability

R10 preserves team-memory filename slugs. Agents that reference memories
by stable relative path (`shared/dogfood-paradox-third-occurrence.md`)
continue to resolve after the rename. Renaming the slugs would break
cross-references and has no user-visible benefit.

## 7. Open questions (blockers — orchestrator stops here until resolved)

All blockers resolved 2026-04-21; see §8 D4–D6.

## 8. Decisions (PM-resolved, reversible)

The following decisions are baked into this PRD with rationale. Each is
reversible by a follow-up `/specflow:update-req` if the user disagrees at
plan or validate time.

- **D1 — No deprecation alias window; hard cutover at merge.** Rationale:
  this is an internal-only rename at a pre-public stage; no external
  users invoke the old names. An alias window would double the
  slash-command surface, require a deprecation-warning path in the
  dispatch table, and stretch the grep allow-list (R6) to include the
  alias files themselves — which the rename was supposed to eliminate.
  Old names become unknown commands at merge; the migration notes (R15)
  tell users to retype once.
- **D2 — Repo working-tree directory on disk is NOT renamed by this
  feature.** Rationale: the repo-dir rename is outside-repo operational
  work that the user can do independently with `git mv`-style
  checkout-path change. Absolute-symlink targets installed globally
  (`common/absolute-symlink-targets.md`) will need a `claude-symlink
  install` pass regardless of whether this feature renames the dir or
  not; the recovery step is already documented in that rule. Keeping the
  dir rename out of scope reduces blast radius to in-tree surfaces only.
- **D3 — Global `~/.claude/` install paths (`~/.claude/agents/specflow/`,
  `~/.claude/commands/specflow/`, etc.) migrate organically on the
  user's next `bin/claude-symlink install` or `bin/specflow-seed update`
  (whichever renames post-merge).** Rationale: the `claude-symlink` and
  `specflow-seed` binaries (both renamed in this feature per R7) author
  the global paths from scratch each run — the next invocation will
  write the new paths and leave the old ones orphaned. Migration notes
  (R15) document the one-line cleanup command for users who care about
  not leaving orphans. Forcing the global rename in-feature would
  couple in-tree changes to out-of-tree state we do not own.
- **D4 — [CHANGED 2026-04-21] Slash-command prefix is `/scaff:*` (CLI-aligned
  short form).** Resolves §7 Q1. Rationale (user-selected): the 6-char
  form matches the shell alias users actually type, keeps the slash
  surface consistent with the CLI surface, and reduces daily typing cost
  over the 10-char product-name form. Consequence: every
  `.claude/commands/specflow/` file relocates to `.claude/commands/scaff/`
  (R2); every doc example and STATUS stage-advance line going forward
  uses `/scaff:<stage>`.
- **D5 — [CHANGED 2026-04-21] Agent-name prefix is `scaff-*` (consistent
  with D4).** Resolves §7 Q2. Rationale (user-selected): keeps the agent
  prefix and slash prefix in lockstep so "the PM agent" dispatches as
  `scaff-pm` from the `/scaff:prd` command without cross-surface prefix
  drift. Consequence: every `.claude/agents/specflow/*` file is relocated
  and its frontmatter `name:` field rewritten to `scaff-<role>` (R3);
  cross-agent dispatch references in rules and memories are updated in
  R9/R10 passes.
- **D6 — [CHANGED 2026-04-21] Rename `.spec-workflow/` to `.specaffold/`
  WITH a backwards-compat symlink `.spec-workflow → .specaffold`
  authored during transition.** Resolves §7 Q3. Rationale (user-selected):
  clean-break identity (`.specaffold/` as the canonical root) while
  keeping R11-protected archived artefacts' internal path references
  resolvable via the symlink — archives are not modified, and legacy
  cross-references (in rules, memories, archived STATUS bodies) still
  resolve. Consequence: R6 allow-list gains the symlink path and the
  archived-feature carryover strings (see updated R6); R11 and R12 are
  updated to reflect the new canonical path; R17 is added to cover the
  symlink authoring discipline (owner: `bin/scaff-seed`; absolute target
  per `common/absolute-symlink-targets.md`).

## 9. Acceptance criteria

All ACs are structural unless tagged `[runtime]`. Structural ACs gate
archive; runtime ACs defer to the successor feature per the dogfood
paradox pattern.

### Grep assertion

- **AC1** — Running `grep -rE "spec-workflow|specflow" .` in the repo
  root returns only hits listed in `.claude/carryover-allowlist.txt` (R6
  allow-list). Any unlisted hit is a FAIL. Assertion is a shell script
  authored by QA-analyst and invoked at validate time.

### Surface ACs

- **AC2** — `README.md` line 1 heading reads exactly `# Specaffold`.
- **AC3** — `README.md` contains the string `scaff` in at least one
  install-example code block. Verified by grep.
- **AC4** — [CHANGED 2026-04-21] Every file under `.claude/commands/scaff/`
  exists and is non-empty; the old `.claude/commands/specflow/` directory
  does not exist.
- **AC5** — [CHANGED 2026-04-21] Every file under `.claude/agents/scaff/`
  has a frontmatter `name:` field that starts with `scaff-`; no agent
  file has a `name:` starting with `specflow-`.
- **AC6** — Every `bin/specflow-*` binary has been renamed to its
  counterpart with the new prefix; `ls bin/` shows no `specflow-*`
  entries.
- **AC7** — `.claude/hooks/session-start.sh` and `.claude/hooks/stop.sh`
  contain no `specflow` or `spec-workflow` string outside the R6
  allow-list. Hook wall-clock on a warm cache stays below 200 ms (per
  `reviewer/performance.md` entry 7; measured by QA-analyst).

### Archived-artefact preservation

- **AC8** — [CHANGED 2026-04-21] Every file under `.specaffold/archive/**`
  (post-rename path; formerly `.spec-workflow/archive/**`) is byte-
  identical to its pre-rename content. Verified by `git log --follow`
  on a sample archived artefact plus `git diff --stat` against the
  rename commit scoped to the archive subtree returning empty body
  changes (only path-rename entries). (TPM arranges the commit topology
  so this diff is trivially checkable.)
- **AC15** — [CHANGED 2026-04-21] The backwards-compat symlink
  `.spec-workflow` at the repo root exists, is a symlink, and resolves
  to `.specaffold/` at an absolute target (per R17 and
  `common/absolute-symlink-targets.md`). Verified by `[ -L
  .spec-workflow ] && readlink .spec-workflow` producing an absolute
  path ending in `/.specaffold`. A representative archived path (e.g.
  `.spec-workflow/archive/20260419-flow-monitor/03-prd.md`) resolves
  via the symlink to the same file as the canonical path
  (`.specaffold/archive/20260419-flow-monitor/03-prd.md`).

### Self-dogfood (structural)

- **AC9** — [CHANGED 2026-04-21] [structural] The slash-command file for
  `/scaff:request` (`.claude/commands/scaff/request.md`) references the
  PM agent name `scaff-pm` in its body. Verified by grep against the
  command file.
- **AC10** — [CHANGED 2026-04-21] [structural] The PM agent frontmatter
  `name:` field at `.claude/agents/scaff/pm.md` reads exactly `scaff-pm`,
  matching the string referenced in AC9.

### Self-dogfood (runtime, deferred)

- **AC11** — [CHANGED 2026-04-21] [runtime] In the successor feature's
  first fresh session after archive, `/scaff:request "<test ask>"`
  dispatches successfully, the PM agent (`scaff-pm`) writes
  `00-request.md`, and STATUS.md records the stage advance. Deferred to
  successor feature per dogfood paradox; this feature's validate records
  the AC as `runtime-deferred`.

### Migration notes and alias

- **AC12** — The migration notes file (path confirmed at plan time per
  R15) exists, is non-empty, and contains the old-prefix → new-prefix
  mapping table referenced in R15.
- **AC13** — The `scaff` CLI alias is invocable (exact form decided by
  Architect per R5) and its path is named in the README install
  section. Verified by shelling out to `command -v scaff` or equivalent.

### Decisions recorded

- **AC14** — [CHANGED 2026-04-21] This PRD's §8 Decisions (D1, D2, D3,
  D4, D5, D6) appear unchanged in the archived PRD; any disagreement at
  validate or archive time is surfaced as a `/scaff:update-req` cycle
  (or `/specflow:update-req` if invoked before the rename merges), not
  a silent edit.

## Team memory

- `shared/dogfood-paradox-third-occurrence.md` — applied: PRD marks AC11
  runtime-deferred and enumerates the structural/runtime split in §6
  and §9; TPM will pre-commit the RUNTIME HANDOFF STATUS line as a
  final-wave task per the ninth-occurrence discipline.
- `pm/ac-must-verify-existing-baseline.md` — applied: ACs that assert
  parity ("matches new-prefix") cite a single concrete artefact (the
  new-prefix command file body in AC9, the PM agent frontmatter in
  AC10) rather than vague "match siblings".
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md`
  — not applicable: this feature is a single rename-only feature, not a
  B1/B2 blast-radius split.
- `pm/housekeeping-sweep-threshold.md` — not applicable: this feature is
  a single-item rename, not a review-nits sweep.
- Proposed new memory (promote at archive only if the pattern holds):
  `pm/rename-only-features-hard-cutover-default.md` — rename-only
  features with no external users should hard-cut over rather than
  author an alias window; the alias doubles the grep/maintain surface
  that the rename itself is meant to eliminate. Will evaluate at archive
  whether this is general enough to promote.
