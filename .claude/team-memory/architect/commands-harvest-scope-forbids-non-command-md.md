---
name: .claude/commands/scaff/ recursively harvests every .md as a slash command — colocated templates forbidden
description: Any .md file under .claude/commands/scaff/ is registered as a slash command by Claude Code at session start; non-command markdown (templates, fragments, examples) MUST live elsewhere or it gets exposed as `/scaff:<filename>`.
type: feedback
created: 2026-04-24
updated: 2026-04-24
---

## Rule

When designing the file layout for a new entry-point or template family that lives near `.claude/commands/scaff/`, place every non-command markdown file outside that directory. The Claude Code session-start harvest walks `.claude/commands/scaff/` recursively and registers every `*.md` it finds as a user-invocable slash command, even nested ones (e.g., `.claude/commands/scaff/prd-templates/bug.md` becomes `/scaff:prd-templates:bug`). There is no opt-out flag, no nominal subdirectory, and no naming convention that excludes a file from the harvest.

## Why

During `20260424-entry-type-split` W1, the architect placed three PRD templates under `.claude/commands/scaff/prd-templates/{feature,bug,chore}.md` so the new `/scaff:request | /scaff:bug | /scaff:chore` commands could load them by relative path. After W1 merged, the Claude Code session-start harvest auto-registered three new slash commands — `/scaff:prd-templates:bug`, `/scaff:prd-templates:chore`, `/scaff:prd-templates:feature` — that the user never asked for and that did the wrong thing if invoked (they returned the raw template body, not a stage handler).

This was caught by the QA-tester at validate (probe surfaced the spurious slash commands in `/help` output). Remediation cost was high: PRD R8 / AC6 / D7 had to be amended, tech-D7 needed an addendum block (see `tpm/tech-doc-addendum-pattern-for-mid-flight-decision-refinement.md`), plan T3 / T5 / T7 needed scope-fence updates, pm.md briefing referred to the old path, and t103_prd_templates_shape.sh asserted against the wrong location. All of this would have been zero-cost if the architect had known the harvest scope at design time.

The harvest behavior is a Claude Code platform constraint, not a Specaffold convention; it cannot be worked around by adding a `_README.md` exclude marker, prefixing files with `_`, or nesting deeper. The only durable fix is "don't put non-command markdown in `.claude/commands/scaff/`".

## How to apply

1. **At tech time**, if a deliverable includes markdown templates or fragments that the slash-command files will read, locate those files outside `.claude/commands/scaff/`. Default location: `.specaffold/<purpose>-templates/` (e.g., `.specaffold/prd-templates/`, `.specaffold/probe-templates/`). The slash-command file references them by absolute or repo-root-relative path.
2. **In tech-D-id wording**, name the file location as a deliberate decision: e.g., `D7: PRD templates live under .specaffold/prd-templates/, NOT under .claude/commands/scaff/, because the latter directory is auto-harvested by Claude Code session-start hook into slash-command names.` This documents the constraint for future architects who might "tidy up" by colocating templates with their consumers.
3. **At plan-time grep audit**, the TPM should grep for `.claude/commands/scaff/.*[^.]md$` patterns in the proposed file layout and flag any non-command files. A file in that tree must be a slash command (or be moved).
4. **At review time**, the style-axis reviewer should treat any new `.md` file under `.claude/commands/scaff/` whose first line is not a slash-command frontmatter block as a `must` finding — call out the harvest leak.

## Example

The remediation diff that landed at W1 (commit `8f60a55`):

```diff
- .claude/commands/scaff/prd-templates/feature.md
- .claude/commands/scaff/prd-templates/bug.md
- .claude/commands/scaff/prd-templates/chore.md
+ .specaffold/prd-templates/feature.md
+ .specaffold/prd-templates/bug.md
+ .specaffold/prd-templates/chore.md
```

The slash-command files (`request.md`, `bug.md`, `chore.md`) were updated to reference the new location:

```bash
# In .claude/commands/scaff/bug.md
TEMPLATE_PATH="$REPO_ROOT/.specaffold/prd-templates/bug.md"
```

After the move, `/help` no longer listed the spurious `prd-templates` namespace. t103 was updated to assert `.specaffold/prd-templates/` shape and to assert NO `.md` files exist under `.claude/commands/scaff/prd-templates/` — a structural anti-regression check.

Source: `20260424-entry-type-split` W1 plan-gap remediation, STATUS Notes line `2026-04-24 W1-fix — moved prd-templates out of .claude/commands/scaff/ to avoid harvest`.
