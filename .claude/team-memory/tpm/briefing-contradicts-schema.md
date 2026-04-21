---
name: Briefing contradicts schema — quote, don't paraphrase
description: Before writing a concrete value (name, path, key) into a task briefing, grep the governing schema and paste the actual constraint; never paraphrase.
type: feedback
created: 2026-04-18
updated: 2026-04-18
---

## Rule

When a TPM task briefing includes a concrete field value (an agent
`name:`, a file path, a frontmatter key, a schema-governed identifier),
locate the rule or schema file governing that field and paste the
constraint verbatim into the task scope. Do not paraphrase. Do not
"express it in your own words". Cross-reference the rule file so the
developer can verify the briefing matches the schema.

## Why

TPM briefings are authoritative for developers. Developers trust
them. A paraphrase that drifts — even by one word — is a silent
divergence that downstream tests may or may not catch. When tests do
catch it, the feedback loop is long: the briefing said one thing,
the developer did that thing, the test failed, someone re-reads
both the briefing and the schema to find the mismatch.

The root cause is almost always that the orchestrator rephrased the
schema constraint to fit the briefing's prose. The fix is cheap:
quote the schema block verbatim, add a one-line cross-reference to
the file.

## How to apply

When drafting `06-tasks.md` and writing a task's scope / file list /
acceptance criteria:

1. **Identify every concrete value** in the briefing that references
   a schema-governed field — agent names, frontmatter keys, file
   paths, rule slugs.
2. **Locate the governing schema** — usually `.claude/rules/README.md`
   for rule frontmatter, `.claude/team-memory/README.md` for memory
   frontmatter, an agent-template file for agent shape.
3. **Read the exact constraint.** Don't rely on memory; don't rely
   on prior tasks.
4. **Quote verbatim into the task scope.** Use a codefence if the
   constraint is multi-line. Add a cross-reference:
   ```
   Constraint: name: must match filename stem
   Source: `.claude/rules/README.md` — "Filename stem matches `name:`
   in frontmatter."
   ```
5. **If the constraint is complex**, paste the relevant schema block
   (frontmatter shape, enum values) rather than summarize.
6. **If you find yourself paraphrasing**, stop. Paste the constraint.
   Let the developer interpret it against the codebase.

## Example

Feature `review-capability` (B2.b), tasks T3-T5 (create reviewer
agent files). TPM briefing said:

> Frontmatter: `name: reviewer-<axis>`, `model: sonnet`, ...

Schema (`.claude/rules/README.md`) actually says:

> Filename stem matches `name:` in frontmatter.

Two of three developers followed the briefing literally and wrote
`name: scaff-reviewer-performance` / `name: scaff-reviewer-style`
(prefix drift from copy-pasting from neighbor agent files, not from
the briefing). Only `name: reviewer-security` happened to match
filename stem.

T12 (schema-conformance test) caught the drift. Fix landed before
archive, but the feedback loop took extra steps because the briefing
paraphrased rather than quoted. Root cause: orchestrator wrote "name:
reviewer-<axis>" as if it were a template, when the actual constraint
is "name matches filename stem". Those two formulations happen to
agree in the common case; they diverge under copy-paste drift.

The corrective pattern: TPM pastes the schema block verbatim —
"Filename stem matches `name:` in frontmatter" — and lets the
developer ensure consistency when they create the file.
