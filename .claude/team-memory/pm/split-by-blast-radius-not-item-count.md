---
name: Split by blast radius, not item count
description: When a request bundles multiple items, split into features by blast radius (what breaks if this ships wrong), not by item count or wave order. Items with different failure surfaces belong in different features.
type: decision-log
created: 2026-04-17
updated: 2026-04-17
---

## Rule

When a single request bundles multiple items, during brainstorm split them
into features by **blast radius** — the surface that fails if the item
ships wrong — not by item count, not by wave order, not by "what feels
related". Items with different failure surfaces belong in separate
features (B1 / B2 / ...).

## Why

Items that affect different surfaces (session-wide system prompt vs a
single-stage orchestration hook, for instance) have fundamentally
different failure modes:

- A session-wide change fails for every session across every project
  until reverted — blast radius: global.
- A single-stage orchestration change fails only during that stage's
  invocation — blast radius: local.

Bundling items with mismatched blast radii produces a PRD that is hard
to gap-check (requirements for different surfaces interleave), a plan
that is hard to sequence (different acceptance harnesses), and merge
churn (unrelated wave failures block each other). Splitting upfront
costs one extra feature-intake cycle; not splitting costs rework
across the whole pipeline.

## How to apply

1. **During brainstorm**, group the items by the question: *"what
   breaks if this ships wrong?"* — be literal about the surface, not
   the abstract concept.
2. **If groups have different failure surfaces**, propose splitting
   into separate features. Name them `B1`, `B2`, ... in the
   brainstorm doc so the PM and user can confirm.
3. **Name each feature by what it does**, not by wave order or "phase
   1 / phase 2". A name like `prompt-rules-surgery` survives reordering;
   `phase-1-harness` does not.
4. **Land the feature with the highest dogfood payoff first** — the
   one whose output improves subsequent features' development
   experience. Often this is session-wide infrastructure before
   stage-specific orchestration.

## Example

Feature `20260416-prompt-rules-surgery` arrived as a 6-item request
mixing (a) session-wide prompt/rules surgery and (b) per-stage
implement/review orchestration hooks. During brainstorm, items
grouped by blast radius:

- **B1 (session-wide)**: items 1, 2, 3 — prompt slim, rules dir,
  SessionStart hook. Failure breaks every session.
- **B2 (orchestration-local)**: items 4, 5, 6 — Stop hook, implement
  guardrails, review gates. Failure breaks only the affected stage.

The split landed B1 first (session prompt improvements pay down debt
for B2's own development). B1 shipped with 16 requirements, 25 tasks,
9 waves; B2 is deferred but has a clean scope boundary because the
cut was made at the blast-radius seam, not at an arbitrary item count.
