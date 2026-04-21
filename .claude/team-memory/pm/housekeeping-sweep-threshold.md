---
name: housekeeping-sweep-threshold
role: pm
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Bundle review-generated nits into a dedicated housekeeping sweep when
post-ship nit count crosses ~10 items, all advisory.

## Why

10+ accumulated nits crosses a threshold where in-stream absorption
(folding fixes into the next functional feature) costs more than a
scoped sweep — context-switch overhead, PRD churn, and review noise
start to exceed the value of keeping them rolling. But fewer than
~10, or any mix including a `must`-severity finding, does not justify
its own PRD/plan/tasks lifecycle: promote those to a real feature or
absorb in-stream.

## How to apply

1. After a feature's `/scaff:review` returns a NITS verdict with
   ≥10 findings, consider bundling into a housekeeping sweep feature.
2. Sources may be combined: current review output + deferred findings
   from earlier gap-checks (keep the X-tag identifiers so traceability
   is preserved back to the originating feature).
3. Shape as **one** feature, **one** PRD, group items by concern
   (security / perf / style / carryover / dead-code), emit **one R per
   item**. Every R gets an AC.
4. All-advisory + zero-blocker is the ceiling: if any `must`-severity
   finding is in the pool, promote it to its own feature and let the
   rest wait for the next sweep.
5. Expected shape: ~10 tasks, 2 waves (parallel edits + one verify
   bundle). Wider than that → split; narrower → absorb in-stream.

## Example

Feature `20260418-review-nits-cleanup` swept 13 B2.b review findings +
1 B2.a deferred `to_epoch` dead-code carryover = 14 items. Shape
delivered: one PRD with R1–R14, 10 tasks across 2 waves (9 parallel
edits + 1 verify), byte-identical for refactors, smoke 38/38
throughout. Confirmed the ~10-item threshold as a working default.
