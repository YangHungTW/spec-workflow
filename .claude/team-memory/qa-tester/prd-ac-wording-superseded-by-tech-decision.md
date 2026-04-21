## Rule

When validating, if a PRD AC's literal wording is unmet but a tech decision (04-tech.md) deliberately supersedes that wording, mark the AC **PARTIAL**, cite the superseding decision by D-id in the finding message, and let the validate aggregate carry the drift as a `should`-severity finding — not PASS, not FAIL.

## Why

A silent PASS erases the drift and sets a precedent that PRD wording is optional. A hard FAIL blocks archive on an architect-approved decision. PARTIAL + D-id citation preserves the signal without blocking the feature, and signals to PM/TPM that a future PRD revision should align wording with the shipped design.

In the rename-to-specaffold feature (2026-04-21), AC13 was literally "CLI alias `scaff` is invocable". Tech §D3 deliberately chose `scaff-*` sibling binaries (no bare `scaff` wrapper) on the grounds that the sibling topology is cleaner and a wrapper adds no value. AC13 tested `command -v scaff` and found no bare binary; qa-tester marked PARTIAL with message "no bare `scaff` binary; `scaff-*` sibling topology per tech D3 supersedes PRD R5 wording". Aggregate stayed NITS — archive proceeded, and the AC-vs-tech mismatch is preserved in 08-validate.md for PM follow-up.

## How to apply

1. When an AC is literally unmet during walkthrough, search `04-tech.md` for a D-id whose body scopes the AC's literal out (e.g. "we deliberately chose X over Y").
2. If such a D-id exists: mark PARTIAL in the AC table; in the findings block, emit `severity: should`, `ac: AC<n>`, `message: <one line citing superseded by tech D<N>>`.
3. If no D-id exists: mark FAIL and escalate — this is a real gap, not a superseded wording.
4. Do not PARTIAL a failing AC just because the diff is small or the feature feels done; the point of the citation is that an explicit architect decision exists.
