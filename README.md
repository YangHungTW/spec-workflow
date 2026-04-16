# spec-workflow

Role-based spec-driven development workflow for Claude Code. A small virtual team (PM, Designer, Architect, TPM, Developer, QA-analyst, QA-tester) drives every feature through numbered markdown artifacts.

## Flow

```
/YHTW:request      → PM intake
/YHTW:brainstorm   → PM explores approaches
/YHTW:design       → Designer (only if has-ui: true) — uses pencil/figma MCP if available, else HTML mockup
/YHTW:prd          → PM writes requirements
/YHTW:tech         → Architect picks tech + designs system architecture
/YHTW:plan         → TPM produces implementation plan
/YHTW:tasks        → TPM decomposes into ordered tasks
/YHTW:implement    → Developer runs each wave of tasks in parallel via git worktrees (TDD per task)
/YHTW:gap-check    → QA-analyst: PRD/tech ↔ tasks ↔ diff
/YHTW:verify       → QA-tester: runs acceptance criteria
/YHTW:archive      → TPM closes out
```

Shortcut — advance one stage at a time based on STATUS:

```
/YHTW:next <slug>
```

Revisions:

```
/YHTW:update-req    /YHTW:update-tech    /YHTW:update-plan    /YHTW:update-task
```

Team memory:

```
/YHTW:remember <role> "<lesson>"   # manual save
/YHTW:promote <role>/<file>        # local → global
```

Two-tier memory: `~/.claude/team-memory/<role>/` (global) + `<repo>/.claude/team-memory/<role>/` (local). Agents read both on every invocation. `/YHTW:archive` runs a retro that polls each role for lessons. See `.claude/team-memory/README.md` for the full protocol.

## Layout

```
.claude/
  agents/   pm.md designer.md architect.md tpm.md developer.md qa-analyst.md qa-tester.md
  commands/ request.md brainstorm.md design.md prd.md tech.md plan.md tasks.md
            implement.md gap-check.md verify.md archive.md
            update-req.md update-tech.md update-plan.md update-task.md
.spec-workflow/
  features/<slug>/
    00-request.md
    01-brainstorm.md
    02-design/           # only if has-ui
    03-prd.md
    04-tech.md
    05-plan.md
    06-tasks.md
    07-gaps.md
    08-verify.md
    STATUS.md
  archive/<slug>/
```

## Using in another project

Symlink or copy `.claude/` and `.spec-workflow/features/_template/` into the target repo.
