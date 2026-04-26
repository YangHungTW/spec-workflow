---
name: Universal-quantifier ACs need live enumeration, not hardcoded constants
description: When a PRD AC says "every X has property Y", the test must enumerate X via `querySelectorAll` / `Object.keys` / etc., not iterate a hardcoded constant. Constant-bound spot checks pass silently when the actual set has more (or different) members.
type: feedback
created: 2026-04-26
updated: 2026-04-26
source: 20260426-flow-monitor-graph-view
---

## Rule

When a PRD AC says **"every X has property Y"** (universal quantifier over a
set), the verifying test must enumerate the *actual* set at runtime —
`document.querySelectorAll(...)`, `Object.keys(...)`, `fs.readdirSync(...)`,
etc. — and assert Y on each member. A test that hardcodes a `KNOWN_X`
constant and iterates only the constant is a spot check, not a coverage
assertion: it passes silently when the implementation has fewer (or
different) members than the constant lists, masking real gaps.

## Why

Universal-quantifier ACs put the burden on the test to *find* every member
of the set, then assert the property. Hardcoded constants invert this: the
test asserts the property on the members it was told about, and stays silent
about members it wasn't told about. The implementation can drift
(add/remove members) and the test happily reports green. Worse, the
constant becomes a self-fulfilling prophecy: future contributors see the
constant, assume it's authoritative, and add new members without updating
the test.

## How to apply

When scoping a test task, scan the AC text for universal quantifiers:
"every", "all", "each", "no X has", "for any X". If found, the test MUST
enumerate the live set:

- DOM-side: `container.querySelectorAll('[data-stage-edge]')` not a
  hardcoded `LABELED_EDGES` array.
- Object-side: `Object.entries(STAGE_LAYOUT)` not a hardcoded `STAGES` list.
- Filesystem: `fs.readdirSync(dir)` not a hardcoded file-name list.

Reject any test draft that names members in a constant when the AC
quantifies universally. The constant pattern is acceptable only when the AC
itself names a specific finite list (e.g. "the six smoke checks must…",
where "six" pins the cardinality and the names are part of the contract).

## Example

Surfaced in `20260426-flow-monitor-graph-view` validate as F1 BLOCK:

PRD AC2 said "assert every directed edge in the DAG has a non-empty
artifact-name label visible to the user." The test had:

```ts
// BAD: spot check masquerading as coverage
const LABELED_EDGES = ["design-prd", "prd-tech"];
for (const edgeId of LABELED_EDGES) {
  const edgeEl = container.querySelector(`[data-stage-edge='${edgeId}']`);
  expect(edgeEl?.querySelector("text")?.textContent?.trim()).toBeTruthy();
}
```

The graph rendered 11 edges, but the test asserted on 2 of them. 8 of the
11 carried no label at all. Validate caught this; review at wave merge
didn't, because the test was green.

Fix template:

```ts
// GOOD: enumerate the live set
const edges = container.querySelectorAll("[data-stage-edge]");
expect(edges).toHaveLength(EXPECTED_COUNT);  // pin cardinality
for (const edge of edges) {
  const id = edge.getAttribute("data-stage-edge");
  const text = edge.closest("g")?.querySelector("text")?.textContent?.trim();
  expect(text, `empty label for edge ${id}`).toBeTruthy();
}
```

`querySelectorAll` returns whatever the implementation rendered; the
assertion runs on every member regardless of whether the test author knew
about it.
