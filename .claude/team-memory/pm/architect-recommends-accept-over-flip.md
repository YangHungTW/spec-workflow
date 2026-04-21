---
name: When architect blocker proposes a resolution, default to accept
description: When architect's §5 blocker paragraph offers a specific resolution (usually PRD AC rewording), the PM's default is accept — flipping the architect's semantic is the more expensive path and should require user-visible evidence.
type: decision-record
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When architect flags a `§5 Blocker question` with a specific
resolution paragraph (typically: "propose rewording PRD AC<n>.x
to …"), the PM's default decision is **accept verbatim** via
`/scaff:update-req`. Flipping the architect's decision via
`/scaff:update-tech` should require concrete user-visible
evidence — usually a regression the architect's semantic would
introduce that was not considered at the tech stage.

## Why

Architects evaluate implementation cost and contract precedence
with information that PM did not have at PRD time. When architect
proposes a resolution, they have already:
- Weighed the cost of both alternatives.
- Considered which side sets contract (usually the higher-level R).
- Chosen the form that minimises downstream rework.

The PM's first-pass analysis at PRD time cannot match that
information. Defaulting to accept preserves architect's cost-aware
judgment and avoids the "flip-flop" pattern where PM overrides,
TPM locks tasks, then reviewers/QA surface the exact issue the
architect warned about.

## How to apply

When architect's `04-tech.md §5` contains a blocker:

1. **Read architect's rationale paragraph in full.** They almost
   always name the concrete cost asymmetry.
2. **Default to accept** unless one of the following holds:
   - The reworded AC introduces a user-visible regression the
     architect did not evaluate (e.g. a scenario in the PRD user-
     scenarios table breaks under the new semantic).
   - The PM has fresh user-facing evidence that the original AC
     matters (often: a user conversation that clarifies intent).
   - The architect explicitly invited flipping as a viable
     option.
3. **If accepting**: run `/scaff:update-req <slug>`, append
   `[CHANGED YYYY-MM-DD]` to the reworded AC, update parent
   requirement body for coherence, confirm PRD↔tech alignment
   with a single `STATUS Notes` line.
4. **If flipping**: run `/scaff:update-tech <slug>`, write
   the concrete counter-evidence into the PRD or a new `§7
   Clarifications` section so future readers see the rationale.

## Example

Feature `20260419-user-lang-config-fallback`:

- Architect §5 flagged: PRD AC4.a's "cascade past invalid" conflicts
  with D6's "stop-on-first-hit". Proposed resolution: reword AC4.a
  to stop-on-first-hit + add rationale about file-level override
  being the semantic R1 actually encodes.
- PM's analysis at PRD time: user would prefer cascade for maximal
  helpfulness.
- Architect's counter-analysis at tech: cascade dilutes R1's
  "project wins when present" semantic — if project has `fr`,
  that's a deliberate project signal, not a typo to route around.
- PM decision: **accept**. No user-scenario breaks under stop-on-
  first-hit; the "fix your typo" UX is arguably better. Zero
  downstream rework.

Contrast: a PM-flip would have required changing T1's loop
structure (remove the `break`), adjusted T6 test expectations, and
still left the semantic-dilution concern architect flagged. Accept
was 1-sentence AC change; flip would have been a ~10-line loop
edit + test re-author.
