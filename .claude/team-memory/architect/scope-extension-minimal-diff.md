---
name: Scope extension — minimal diff, not re-taxonomy
description: Extend a closed enum (scope, severity, state) by appending one value; never re-cut the taxonomy to accommodate one new case.
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Context

When a new feature needs a slot in an existing enum (scope values,
severity levels, classification states), the instinct is to
reconsider the whole taxonomy — "should we split this into a parent
category and sub-axes?". That refactor touches every existing entry,
every dependent doc, every downstream grep. Ten times the churn for
one times the benefit.

A flat enum that carries meaning (not hierarchy) stays legible at 5,
6, 7 values. Only at 8+ should re-taxonomy even be on the table.

## Template

1. **Locate the enum declaration.** Usually one line in a README or
   schema doc (`scope: common | bash | markdown | git | <lang>`).
2. **Append the new value.** One-line diff. End of the pipe list.
3. **Add directory / file support.** One new row in the directory
   layout section; one new subdir. No changes to existing rows.
4. **Update the authoring checklist.** One bullet adjustment to say
   the new value is a legal choice. No rewriting.
5. **Document the extension in a single commit.** Don't bundle with
   a taxonomy rethink or a generalization refactor.

## When to use

- Existing enum has < 8 values and a new use case fits as a sibling.
- The new value is conceptually on the same axis as existing values
  (same dimension of categorization).
- No cross-cutting concerns make the new value awkward at the flat
  level.

## When NOT to use

- The enum is approaching 8+ values AND the new value feels
  orthogonal to existing ones. At that point, consider a two-axis
  split; but only then.
- The new value represents a fundamentally different concept (e.g.,
  adding `runtime` to a set of `build-time` scopes). Stop and
  re-frame before extending.

## Why

- **Minimal diff = minimal review surface.** Reviewers see one
  line change; no risk of unrelated drift.
- **No downstream churn.** Existing docs, grep patterns, tests keep
  working unchanged.
- **Preserves git-blame utility.** Taxonomy refactors rewrite every
  existing file's last-touched metadata.

## Example

Feature `review-capability` (B2.b) added `reviewer` to
`.claude/rules/README.md`'s scope enum. One-line diff:

```diff
-scope: common | bash | markdown | git | <lang>
+scope: common | bash | markdown | git | reviewer | <lang>
```

Plus one new directory-layout row and one authoring-checklist tweak.
Total schema edit: ~3 lines.

Rejected alternative: splitting `scope:` into a two-axis schema
(`session-scope: session-wide | agent-triggered` × `domain: common
| bash | markdown | ...`). Cascading updates across README, all
existing rule files' frontmatter, the SessionStart hook's walk
logic, and the authoring checklist. Never got past the architect
desk. Flat enum prevailed.
