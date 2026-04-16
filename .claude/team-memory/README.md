# Team memory protocol

Per-role memory for the specflow virtual team. Separate from per-feature artifacts under `.spec-workflow/features/` — those are work products; this is accumulated craft.

## Two-tier layout

| Tier | Location | Scope |
|------|----------|-------|
| **Global** | `~/.claude/team-memory/<role>/` | Lessons that apply across all projects |
| **Local**  | `<repo>/.claude/team-memory/<role>/` | Repo-specific conventions, decisions, patterns |

Read order: **global first, local second**. Local silently overrides same-topic global entries.

## Roles

- `pm/`           — product framing, recurring user pain, successful PRD patterns
- `designer/`     — UX patterns, component choices, color/typography decisions
- `architect/`    — decision log (D-ids with outcomes), stack rationale, architectural patterns
- `tpm/`          — planning heuristics, task-sizing, recurring risks
- `developer/`    — code/test conventions, bug patterns, refactor red lines
- `qa-analyst/`   — recurring gap types, red flags
- `qa-tester/`    — flaky tests, manual-to-automated targets, verification patterns
- `shared/`       — glossary, escalation rules, cross-role conventions

## File conventions

Each role folder has:
- `index.md` — one line per memory: `- [<title>](<file>.md) — <hook>`
- `<topic>.md` — single memory, frontmatter + body

Frontmatter:
```
---
name: <memory name>
description: <one-line — used to judge relevance>
type: feedback | pattern | decision-log | glossary
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Body:
- **feedback** — rule + **Why:** + **How to apply:**
- **pattern** — context + template + when to use / when NOT to use
- **decision-log** — decision + alternatives + outcome (updated over time)
- **glossary** — term + definition + examples

## When agents read

Every role-specific agent MUST, at the start of each invocation:
1. Read `~/.claude/team-memory/<role>/index.md` (global).
2. Read `.claude/team-memory/<role>/index.md` (local).
3. Also read `shared/index.md` from both tiers.
4. Pull in any entry whose description looks relevant to the current task.

## When agents write

Write a memory when you:
- Were corrected by the user on something that will recur.
- Made a non-obvious judgment call the user approved (validated pattern).
- Discovered a convention (naming, structure, tooling) that isn't already captured.
- As Architect, resolved a decision — log it even before outcome is known.

Do NOT write:
- Details already derivable from current code / STATUS / git history.
- One-off debugging traces.

**Scope decision** (local vs global):
- Default to **local**.
- Propose global only if the lesson is repo-agnostic (e.g., "TDD before green").
- Use `/specflow:promote <role>/<file>` to move local → global after you've seen it apply in a second repo.

## Manual entry

- `/specflow:remember <role> "<lesson>"` — user-driven memory write.
- `/specflow:promote <role>/<file>` — move local memory to global.

## Retrospective

`/specflow:archive` runs a retro: the TPM polls each role that participated in this feature, asking "any memory worth saving from this one?" and writes approved entries.
