---
name: Aggregator as classifier — reduce parallel verdicts by severity max
description: Reducing N parallel agent verdicts to one outcome is a severity max-reduce classifier; the same classify-before-mutate discipline applies to agent output reduction.
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Context

When the orchestrator dispatches N agents in parallel (reviewers per
task, voters on a decision, multi-axis classifiers) and must commit
to a single outcome (PROCEED / HOLD / STOP, or PASS / NITS / BLOCK),
the reduction is a decision, not an average. Any hidden coalescing
("take the first PASS", "majority wins", "skip malformed") creates
silent bias and is unreviewable six months later.

The rule: treat the reducer as a classifier whose input is the
tuple of agent outputs and whose output is one enum value. Same
discipline as `architect/classification-before-mutation.md` — but
applied to agent outputs instead of filesystem targets.

## Template

1. **Define a closed severity enum.** PASS < NITS < BLOCK (or
   PROCEED < HOLD < STOP). Three values typically suffice; if you
   need more, ensure they are totally ordered.
2. **Reducer is a pure max.** Iterate over all agent outputs; keep
   the highest severity seen. No tie-breaking by order, no "take
   the first non-PASS", no "drop malformed". ANY highest-severity
   finding wins.
3. **Malformed verdict = max severity.** A missing footer, an
   unknown verdict value, or a parse failure is treated as BLOCK
   (the highest). Fail-loud is always safer than fail-open on a
   decision point.
4. **Two-phase reduce.** For nested dispatches (reviewer × task),
   reduce per-task first (fold axes into one wave-per-task verdict),
   then across tasks (fold tasks into one wave verdict). Each phase
   is the same max-reduce.
5. **Emit the aggregated verdict in the same wire format as inputs.**
   Consistency across layers — an aggregated verdict is consumable
   by a further reduction if one appears later.

## When to use

- Orchestrator aggregating parallel-reviewer outputs per task, then
  per wave.
- Multi-axis classifiers where each axis returns an independent
  verdict and a single gate decision is needed.
- Any dispatch where "proceed" must strictly require all agents to
  agree at the lowest severity.

## When NOT to use

- Truly additive outputs (e.g., concatenated reports, summed
  metrics). Those are map operations, not classifier reductions.
- Decisions where vote-weighting or confidence-scoring matters
  (rare in the specflow context; cite a specific need before
  deviating).

## Why

- **Reviewability**: one function, one enum, one max — a reviewer
  can audit the reduction rule in 30 seconds.
- **Safety**: fail-loud on malformed = a parse bug becomes a BLOCK,
  not a silent PASS.
- **Composability**: same shape across dispatch layers means nested
  dispatches compose without special cases.

## Example

`/specflow:implement` step 7 aggregator in feature `review-capability`
(B2.b). Three reviewers × N tasks per wave return `## Reviewer verdict`
footers. The aggregator:

1. For each task, reduce 3 axis verdicts → one per-task verdict
   (max severity).
2. Reduce N per-task verdicts → one wave verdict (max again).
3. Branch on wave verdict: PASS → merge wave; NITS → merge + log
   findings to commit message; BLOCK → halt merge, STATUS-Notes
   the blocking tasks, surface to user.

Specialization of `architect/classification-before-mutation.md`
(which covers filesystem targets); this memory covers agent outputs.
Both obey the same discipline: enumerate states, max-reduce, never
mutate inside the classifier.
