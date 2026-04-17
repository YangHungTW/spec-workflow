# PRD — prompt-rules-surgery (B1)

_2026-04-16 · PM_

## 1. Overview

Specflow eats its own dogfood: the `.claude/agents/specflow/`, `.claude/commands/specflow/`, and `.claude/team-memory/` subtrees in this repo are the harness that runs specflow itself. Today's prompts are monolithic (rules, examples, and core behavior interleaved in a single file per role), cross-role guardrails are duplicated inside individual agent bodies with no single source of truth, and the "read your team memory first" step — while documented in the protocol and every prompt — is invisible in agent output, so memory drift goes undetected. This feature is **B1 of a two-feature split**: it delivers three harness self-upgrades — (1) progressive disclosure of every agent prompt, (2) a new `.claude/rules/` layer injected via a SessionStart hook, and (3) mandatory, machine-visible team-memory invocation — sequenced so the rules layer lands first and the slim-prompt refactor is a single pass. Items (4) per-task reviewer, (5) Stop hook for STATUS sync, and (6) `/specflow:review` parallel reviewers are **deferred to feature B2** (separate PRD, opens after B1 archives); this PRD does not design for them but must not make them harder.

## 2. Goals / Non-goals

### Goals
- **(1) Progressive disclosure** — every specflow agent prompt has a slim core-behavior file plus an on-demand appendix; steady-state token load per invocation drops measurably versus today's monolithic prompts (target: each agent core file slims by >=30% in non-empty line count).
- **(2) Rules layer + SessionStart hook** — cross-role guardrails currently duplicated across agent prompts live in `.claude/rules/` (`common/` + per-language) and are injected via a SessionStart hook so every session sees them with one source of truth.
- **(3) Mandatory memory invocation** — every role invocation either lists the memory entries it pulled in, or explicitly states "none apply because &lt;reason&gt;" — team-memory drift is visible in agent output rather than silent.
- **Meta outcome** — the next feature run against this harness is noticeably cheaper (lower token spend) and future features find fewer late-stage should-fixes because more guardrails are enforced up front.

### Non-goals
- Items (4) (5) (6) deferred to feature B2 — not designed for here.
- Porting Superpowers skills, wshobson plugin-marketplace format, or everything-claude-code MCP configs wholesale.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- TDD enforcement, strategic compaction hooks, `/specflow:extract` command.
- A dashboard / GUI for specflow runs.
- Migrating specflow to the Claude plugin-marketplace format.
- Versioning the `.claude/rules/` tree (a rule edit mid-feature does NOT force a re-run; rules apply to sessions, not feature artifacts).
- Per-rule priority / ordering system (flat set for v1).

## 3. User stories

1. **Slim invocation.** As a specflow agent (any role) invoked mid-feature, I want my prompt to expose only the core behavior plus a pointer to an appendix, so I don't pay token cost for edge-case recipes I'm not about to use.
2. **One source of truth for guardrails.** As a contributor updating a cross-role rule (e.g. "absolute symlink targets"), I want to edit one file under `.claude/rules/` and have every future session pick it up, rather than grepping for every agent prompt that duplicates the rule.
3. **Visible memory reads.** As a feature owner running `/specflow:next`, I want each agent's return to state which team-memory entries it applied (or say "none apply because &lt;reason&gt;"), so I can see drift — silent-memory-reader agents are indistinguishable from agents that skipped the step.
4. **Fresh-session context.** As any agent starting work in a new Claude Code session, I want the repo's common rules auto-injected at session start so I don't have to re-read them from seven different prompt files.

## 4. Functional requirements

### Rules layer + SessionStart hook (item 2 — lands first in sequencing)

**R1 — Rules directory structure.** Create `.claude/rules/` with at least these subdirectories:
- `.claude/rules/common/` — applies to every session regardless of language.
- `.claude/rules/bash/` — bash-specific rules, loaded when recent context signals bash work.
- `.claude/rules/markdown/` — markdown authoring rules, loaded when markdown files are in recent edits.
- `.claude/rules/git/` — git-workflow rules, loaded when git operations are in recent context.

Additional language subdirs may be added later by the same convention; the hook (R5) discovers subdirs by filesystem, not a hard-coded list. Rule files use **kebab-case filenames** with `.md` extension (e.g. `bash-32-portability.md`).

**R2 — Rules file format.** Every rule file opens with YAML frontmatter:
```
---
name: <human-readable rule title>
scope: common | bash | markdown | git | <lang>
severity: must | should | avoid
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```
Body sections (required, in this order):
- **Rule** — one-sentence imperative statement.
- **Why** — 1-3 sentences of rationale.
- **How to apply** — concrete checklist or template.
- **Example** (optional but strongly preferred) — at least one working snippet.

Rules are **HARD** (enforced on every matching session). Team-memory entries are **SOFT** (advisory craft). The frontmatter is deliberately close to but distinct from team-memory frontmatter (no `type`/`description`; adds `severity`/`scope`) so the two layers don't get conflated.

**R3 — Initial common rules.** At minimum, these rules must exist under `.claude/rules/` on feature archive. TPM turns each into a task; Architect will confirm exact shape.

| rule-slug | scope | severity | source to migrate from |
|-----------|-------|----------|-----|
| `bash-32-portability` | bash | must | `team-memory/architect/shell-portability-readlink.md` + the bash-3.2 line scattered across `developer.md` and `qa-tester.md` |
| `sandbox-home-in-tests` | bash | must | `team-memory/qa-tester/sandbox-home-preflight-pattern.md` + any smoke-test convention currently inlined in `qa-tester.md` |
| `no-force-on-user-paths` | common | must | `team-memory/architect/no-force-by-default.md` + any "never --force" line in `architect.md` / `developer.md` |
| `absolute-symlink-targets` | common | should | `symlink-operation` PRD R3 wording; currently not in any agent prompt but load-bearing for link-manager class tools |
| `classify-before-mutate` | common | must | `team-memory/architect/classification-before-mutation.md`; today only lives in architect memory, not surfaced to other roles |

The list is a **floor, not a ceiling** — TPM/Architect may add more during planning if a migration pass surfaces additional cross-role duplications. Rules copied from team-memory remove duplication in prompts; the original team-memory entries stay (memory is soft craft; rules are hard guardrails — same topic, different severity).

**R4 — Hook script location and entry.** The SessionStart hook is a shell script at `.claude/hooks/session-start.sh`, with executable bit set. It is wired via a new `settings.json` at the repo root (this file does not exist today — the feature creates it) with the hook registered under the key pattern Claude Code expects for SessionStart hooks. The script is written in pure bash (no Node.js or Python dependency — zero install footprint on macOS + Linux, per architect memory `shell-portability-readlink`).

**R5 — Hook behavior.** On session start, the hook:
1. Always emits the digest of every `.md` file under `.claude/rules/common/` (name + severity + Rule line from body).
2. Additionally emits the digest of language-scoped rules under `.claude/rules/<lang>/` when the session context signals that language. v1 signal: a simple heuristic checking file extensions of recently-edited paths in the current worktree (e.g. `.sh` → bash, `.md` → markdown). If no signal, skip language-scoped rules for that session.
3. Completes within 200 ms of real time on a warm cache (target; not a hard assertion, but an SLA Architect tunes against).
4. **Fails safe**: any internal error — missing rule dir, malformed frontmatter, walk failure — causes the hook to log a single diagnostic line to stderr and `exit 0`. The hook must never block a session from starting.

**R6 — Common rules always load; language rules lazy-load.** `common/` is unconditional (every session). `<lang>/` is conditional per R5-item-2. This is the v1 loading policy; a more sophisticated matcher is out of scope.

### Progressive disclosure (item 1 — lands after rules)

**R7 — Two-layer structure per agent.** For each of the seven roles (`pm`, `designer`, `architect`, `tpm`, `developer`, `qa-analyst`, `qa-tester`), split `.claude/agents/specflow/<role>.md` into:
- **Core file** — `.claude/agents/specflow/<role>.md` (retains the existing path and YAML frontmatter so Claude Code still discovers the agent). Contains: role identity, mandatory first-action (memory invocation per R10), when-invoked sections, output contract (what files it touches, what STATUS note format it emits), and the short rules section. Nothing else.
- **Appendix file** — `.claude/agents/specflow/<role>.appendix.md`. Contains: long-form examples, edge-case recipes, anti-patterns, templates too long for the core file. The appendix is not auto-loaded; the core file references it with explicit pointers.

Appendix is a single file per role (`<role>.appendix.md`), not a subdirectory, for simplicity. A role may have no appendix if nothing needed moving out (core stays whole).

**R8 — Core prompt mandatory header.** Every `<role>.md` core file opens with (order matters; grep-verifiable):
1. YAML frontmatter (existing shape: `name`, `model`, `description`, `tools`).
2. Role identity line ("You are the X…").
3. **Team memory invocation block** (per R10).
4. **When-invoked** sections (one per slash command the role handles).
5. **Output contract** — one short paragraph per slash command: which files are written, which STATUS note format is emitted.
6. **Rules** — short, role-specific. Cross-role rules MUST have moved to `.claude/rules/` (R1) by this point; if it's cross-role, it is NOT in the core file.

**R9 — Appendix reference style.** When the core file needs to point at an appendix, it uses the exact literal phrase pattern `When you need X, consult <role>.appendix.md section "Y".` — a pointer, not a bulk dump. Grep can verify appendix references resolve to real sections.

**R9b — Slimming target.** Each agent core file's non-empty line count drops by **>=30%** vs. the pre-feature baseline. Baseline (2026-04-16 non-empty line counts):

| role | baseline lines | >=30% target ceiling |
|------|---------------|----------------------|
| pm | 32 | <=22 |
| designer | 32 | <=22 |
| developer | 35 | <=24 |
| qa-analyst | 30 | <=21 |
| qa-tester | 33 | <=23 |
| architect | 54 | <=37 |
| tpm | 64 | <=44 |

Content pulled OUT of a core file goes into either `.claude/rules/` (if cross-role) or `<role>.appendix.md` (if role-specific long-form). Nothing is deleted outright unless it is already fully captured in a rule file — this is refactor, not rewrite.

### Mandatory team-memory invocation (item 3 — lands alongside item 1)

**R10 — Team-memory invocation block (required in every core file).** Every `<role>.md` opens (after frontmatter + identity line) with a block that instructs the agent to, at the start of every invocation:
1. `ls ~/.claude/team-memory/<role>/` and `ls .claude/team-memory/<role>/` (global first, local second, per protocol).
2. Also `ls` both tiers' `shared/`.
3. In the agent's returned output, emit a short (3-5 line max) memory discovery block listing either (a) the entries pulled in with one-phrase relevance, or (b) the explicit phrase `none apply because <reason>` when nothing from the indexes fits the current task.

**R11 — Discovery output shape.** The agent's return to the orchestrator MUST include a clearly delimited "Team memory" section (e.g. a markdown heading or labeled block) containing either the applied-entries list or the `none apply because …` line. This makes memory usage grep-visible in STATUS notes and artifacts, not just implied. Format details are the TPM's call in plan/tasks; this PRD only requires the section exists and is machine-visible.

**R12 — Missing team-memory directory.** If `~/.claude/team-memory/<role>/` or `.claude/team-memory/<role>/` does not exist, the agent reports `dir not present: <path>` in the memory section and proceeds without memory. This is distinct from "dir exists but no entry applies"; do not conflate the two messages.

**R13 — No auto-enforcement in v1.** There is no automated linter that blocks an agent whose memory section is missing or obviously performative (e.g. "none apply" when the index has matching keywords). Enforcement is prompt-level (R10 instructs the agent) and review-level (gap-check may flag suspicious cases qualitatively). A heuristic linter is explicitly deferred to B2 or later.

### Cross-cutting (all three items)

**R14 — No content duplication between rules and appendices.** A guardrail that is migrated into `.claude/rules/` (R1-R3) MUST NOT also appear in an agent appendix — the rule file is the single source of truth. Appendices may _reference_ a rule by name, but never restate it.

**R15 — No new slash command in this feature.** Items (1) (2) (3) are pure refactor + additive infra (rules dir, hook, settings.json). No `.claude/commands/specflow/*.md` is added or renamed by this feature. Existing commands continue to work unchanged. (B2 may add `/specflow:review`; this feature must not preempt that naming.)

**R16 — Backward compatibility with existing features.** The feature under `symlink-operation` (archived) and its `test/smoke.sh` remain green post-refactor — no regression in the existing harness's delivered tooling.

## 5. Acceptance criteria

Each criterion is checkable end-to-end by QA-tester. IDs are `AC-<short-tag>` and map to requirement IDs.

- **AC-rules-dir.** `.claude/rules/common/`, `.claude/rules/bash/`, `.claude/rules/markdown/`, and `.claude/rules/git/` all exist as directories. Verified by `test -d`. Maps to R1.
- **AC-rules-count.** `.claude/rules/common/` contains >=3 `.md` rule files AND `.claude/rules/` (any subdir) contains >=5 total `.md` rule files that match the five mandated slugs from R3. Verified by `find .claude/rules -name '*.md' | wc -l` and explicit filename check for the R3 slugs. Maps to R3.
- **AC-rules-schema.** Every `.md` file under `.claude/rules/` has valid frontmatter with keys `name`, `scope`, `severity`, `created`, `updated`, and a body containing at least the `Rule`, `Why`, and `How to apply` section headings. Verified by a small schema-check script (may live in `test/`). Maps to R2.
- **AC-hook-exists.** `.claude/hooks/session-start.sh` exists and has the executable bit set. Verified by `test -x`. Maps to R4.
- **AC-hook-wired.** Repo-root `settings.json` exists and contains a SessionStart hook entry pointing at `.claude/hooks/session-start.sh`. Verified by parsing `settings.json` (grep or jq) for the hook path. Maps to R4.
- **AC-hook-failsafe.** Running the hook with `.claude/rules/` temporarily renamed (simulated missing-dir state) exits 0 and emits a diagnostic to stderr. Verified by a dedicated test script under `test/` that renames, invokes, asserts exit 0, and restores. Maps to R5-item-4.
- **AC-hook-bad-frontmatter.** Running the hook with one rule file containing malformed frontmatter exits 0, skips that file, emits a single diagnostic line, and still digests the remaining valid files. Verified in the same `test/` script. Maps to R5-item-4.
- **AC-hook-lang-lazy.** Running the hook in a worktree where recent edits include a `.sh` file loads `bash/` rules in addition to `common/`; running it with no `.sh` in recent edits loads only `common/`. Verified by capturing hook stdout under each condition. Maps to R5-item-2, R6.
- **AC-slim-line-count.** Every `.claude/agents/specflow/<role>.md` core file's non-empty line count is <= the per-role ceiling in R9b. Verified by `grep -cv '^$'` per file. Maps to R7, R9b.
- **AC-core-header-grep.** Every agent core file contains, in order, the YAML frontmatter, a "You are the" identity line, a "Team memory" section heading, and at least one "When invoked" section heading. Verified by a grep-based structural check. Maps to R8.
- **AC-memory-required.** Every agent core file's Team memory block contains the exact tokens `ls ~/.claude/team-memory/<role>/` (with the role substituted) AND either `none apply because` or equivalent required-phrase pattern that the agent must emit. Verified by grep per file. Maps to R10, R11.
- **AC-appendix-pointers-resolve.** Every `<role>.appendix.md` file, if it exists, has a first-level or second-level heading matching each section referenced from `<role>.md` core. Verified by cross-grep: core-file pointers "section "X"" must each match an `## X` or `### X` in the appendix. Maps to R9.
- **AC-no-duplication.** No cross-role rule (identified by the set of slugs in R3) appears verbatim in any `.md` file under `.claude/agents/specflow/` after the refactor. Verified by keyword grep per rule (e.g. "readlink -f", "--force", "sandbox-HOME") showing zero hits in agent files. Maps to R14.
- **AC-rules-visible.** Running any specflow-invoking command in a fresh session produces visible evidence that the hook ran (e.g. a "rules loaded:" line or equivalent diagnostic) containing at least one rule name. Verified by manual invocation captured as evidence in `08-verify.md` under R15. Maps to R4, R5.
- **AC-memory-section-visible.** When any agent is invoked, its return (and any artifact it writes to STATUS Notes) contains a delimited Team memory section per R11. Verified by inspecting this feature's own STATUS Notes post-implement: at least two role notes must include the section. Maps to R11.
- **AC-missing-memory-dir.** With `.claude/team-memory/pm/` temporarily removed, invoking PM emits `dir not present: .claude/team-memory/pm/` in the memory section and still completes its task. Verified by a targeted manual check captured in `08-verify.md`. Maps to R12.
- **AC-no-new-command.** `.claude/commands/specflow/` has the same file list post-feature as pre-feature (18 files, no additions, no renames). Verified by `ls` diff against the git baseline. Maps to R15.
- **AC-no-regression.** `bash test/smoke.sh` (from the archived symlink-operation feature) still exits 0 after this feature lands. Verified by running the smoke test as the last AC gate. Maps to R16.

## 6. Edge cases

- **Rule file has malformed YAML frontmatter.** Hook logs one diagnostic line to stderr, skips that file, continues with the rest; hook exit code is still 0 (R5, AC-hook-bad-frontmatter).
- **`.claude/rules/common/` is empty.** Hook emits an empty digest (no rules listed), logs an info line, exits 0. Agents proceed without common rules. Not a blocker — a missing body is the author's problem, not the hook's.
- **`.claude/team-memory/<role>/` directory does not exist.** Agent reports `dir not present: <path>` in its Team memory section and proceeds (R12). Distinct output from "no entry applies".
- **Agent appendix file referenced by core is missing.** Core file contains pointers to `<role>.appendix.md` that doesn't exist. The agent notes "appendix missing" in its return and proceeds with core-only behavior. Not a blocker — appendix content is by definition non-essential.
- **Hook digest exceeds session context budget.** Hook output is capped implicitly by how many `.md` files live under `common/`; if the set grows large, a future revision may add truncation. v1: trust the author to keep rules short; no automatic truncation logic.
- **Language heuristic misfires.** A session working in a `.md` repo gets `markdown/` rules even if the task is not authoring markdown. Acceptable false-positive: cost is a few extra tokens, harm is minimal. Stricter matching deferred.
- **Two agents run concurrently in waves and both emit Team memory sections into STATUS.** STATUS note append is orchestrator-owned (today); the per-agent memory section lives in each agent's return, not in STATUS directly. No concurrency hazard introduced by R10. (The broader STATUS race is B2's Stop hook territory.)
- **settings.json at repo root conflicts with a user's personal settings.** Claude Code's precedence rules govern here; the repo's `settings.json` only adds hook entries, no overrides of user-scoped settings. If a user has their own SessionStart hook already registered, behavior is undefined in this PRD — call it out as a known limitation, not a blocker.
- **Rule slug collision between `common/` and a `<lang>/` subdir.** Both hook-load; both appear in the digest; duplicate names signal an author bug, not a runtime error. Rule-naming convention (kebab-case, no two rules share a slug across subdirs) is a contributor guideline, not a runtime check.

## 7. Open questions / blockers

None. All candidate questions resolved inline:

- Appendix file vs directory — **file** (`<role>.appendix.md`), resolved in R7 for simplicity; single role has single appendix.
- Hook script language — **pure bash**, resolved in R4 per architect memory `shell-portability-readlink` (zero dependency on macOS + Linux).
- Rule priority / ordering — **flat v1**, no priority system; deferred per Non-goals.
- Rule-loading granularity — **common always-load, language lazy-load by file-ext heuristic**, resolved in R5-R6.
- Hook invocation failure mode — **fail-safe `exit 0`** with stderr diagnostic (R5-item-4).
- Automated enforcement of memory invocation — **no auto-linter in v1**, resolved in R13; prompt-level enforcement only.

Nice-to-clarify (not blocking, Architect's call in `04-tech.md`):
- Exact JSON shape of `settings.json` SessionStart hook entry — follows Claude Code's current documented format.
- Whether to colocate the hook schema-check script under `test/` or `bin/` — follows architect memory `script-location-convention` (test-only helpers under `test/`; repo tools under `bin/`).

## 8. Out of scope

- Items (4) per-task reviewer, (5) Stop hook for STATUS sync, (6) `/specflow:review` parallel reviewers — all **deferred to feature B2** (opens after B1 archives).
- Claude plugin-marketplace format migration.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- AgentShield-grade security scanning.
- Dashboard / GUI / TUI for specflow runs.
- TDD enforcement (third-tier; revisit after B1+B2 land).
- Strategic compaction hooks (third-tier).
- `/specflow:extract` knowledge-extraction command (third-tier).
- Versioning of `.claude/rules/` — rule edits do not re-run features; rules apply per-session.
- Priority / ordering system across rules.
- Automated "performative 'none apply'" linter in gap-check.
- Any new slash command (R15).
