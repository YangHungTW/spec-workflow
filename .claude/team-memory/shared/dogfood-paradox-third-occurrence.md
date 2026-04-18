---
name: Dogfood paradox — structural verify during bootstrap, runtime exercise next feature
description: Features that deliver the tool they would themselves use need structural-only verification; live runtime exercise happens on the next feature.
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

<!-- NOTE: filename says "third-occurrence" but file now records 4+ occurrences (2026-04-18); kept filename stable to avoid breaking refs. -->

## Rule

When a feature ships the mechanism it would invoke (SessionStart
hook, Stop hook, inline reviewers, self-verification agent), it
cannot exercise its own deliverables during `implement` — the
mechanism doesn't exist until after merge. All ACs covered by that
mechanism must be verified **structurally** during the feature's own
verify stage. **Runtime** verification happens on the **next** feature
after archive. Document this explicitly in STATUS Notes so neither
the PM nor the QA-tester mistakes structural coverage for full
coverage.

## Why

Third-occurrence pattern across the specflow harness upgrade series:

- **B1 (prompt-rules-surgery)** — shipped SessionStart hook. Hook
  itself doesn't fire during the feature's own session (was already
  open). Structural verification was all the feature could offer.
  First real exercise: user manually opened a fresh session after
  merge.
- **B2.a (shareable-hooks)** — shipped Stop hook. Same paradox:
  the hook would fire on `/specflow:implement` stopping, but the
  hook was installed only at the end of implement. Deferred first
  exercise.
- **B2.b (review-capability)** — shipped inline reviewers. `--skip-
  inline-review` flag exists explicitly for bootstrapping this
  feature, because the reviewer agents and rubrics land during the
  feature they would protect.

Without the structural / runtime split, the QA-tester sees "AC maps
to a runtime mechanism that does not exist yet" and is forced into
an awkward choice: block verify (blocks archive; blocks the next
feature that can actually exercise the mechanism), or silently
assume runtime will work (creates a deferred failure).

## How to apply

### PM (writing 03-prd.md)

- Write acceptance criteria with an explicit **structural** vs
  **runtime** split when the mechanism is self-shipping.
- Mark AC coverage as "structural-only during same-feature verify"
  where applicable.
- Add a `## Dogfood paradox` section to Edge Cases enumerating
  which ACs are structural-only and why.

### Architect (writing 04-tech.md)

- Design an opt-out or skip flag that lets the feature's own
  `/specflow:implement` run cleanly during bootstrapping.
- Ensure the flag's use writes a STATUS Notes trace (see
  `architect/opt-out-bypass-trace-required.md`).

### TPM (writing 05-plan.md / 06-tasks.md)

- Document the dogfood paradox explicitly in STATUS Notes when
  planning: "This feature ships X; X cannot be exercised on itself."
- When sequencing, do not plan a task that depends on the
  self-shipping mechanism being already active.

### QA-tester (writing 08-verify.md)

- Distinguish structural PASS vs runtime PASS per AC. Structural
  PASS means "the code / prompt / file exists and conforms to
  contract"; runtime PASS means "the mechanism was exercised
  end-to-end and produced the expected effect".
- Flag each structural-only AC with a note: "Runtime verification
  deferred to <next-feature>."

### Next feature after a dogfood-paradox feature

- Include an early STATUS Notes line confirming the prior feature's
  deliverable actually ran on this feature's first real exercise.
  Examples:
  - After B1 archives: "2026-04-17 — B1 SessionStart hook fired on
    this feature's first session, rule digest visible."
  - After B2.a archives: "2026-04-18 — B2.a Stop hook fired on
    first implement halt, STATUS sync confirmed."
  - After B2.b archives: "<date> — B2.b inline reviewers fired on
    this feature's first wave merge; aggregated verdict = PASS."

## When to use

- Any feature that ships a session-wide, lifecycle-wide, or
  flow-wide mechanism (hooks, interceptors, reviewers, validators,
  agents that are invoked by infrastructure the feature itself
  delivers).

## When NOT to use

- Features that ship self-contained tools invocable directly
  (CLI utilities, one-shot commands). Those can run themselves
  during implement if the user invokes the CLI manually.

## Example

Examples in this repo:

- **B1 SessionStart hook** (feature `prompt-rules-surgery`): hook
  digest content verified structurally; first real session exercise
  was manual after merge.
- **B2.a Stop hook** (feature `shareable-hooks`): hook script
  verified structurally; first real exercise deferred.
- **B2.b inline reviewers** (feature `review-capability`):
  reviewer agents + rubrics verified structurally; first real
  exercise will fire on B2.c (next feature after archive).

Third occurrence confirms this is a pattern, not a one-off; promoted
to `shared/` from the three role-specific observations accumulated
in B1/B2.a/B2.b retrospectives.

### Fourth occurrence (2026-04-18)

Feature `20260418-review-nits-cleanup` skipped inline review because
the B2.b reviewer subagents weren't yet in session dispatch cache
(the session hadn't restarted since B2.b merged, so the newly-shipped
agent files weren't yet resolvable as subagent targets).

This is a **dispatch-layer variant** distinct from the original
"mechanism not yet installed" failure mode: the file exists, the hook
would fire, but the orchestrator's agent-dispatch cache hasn't
refreshed to include the new reviewer names. Same root pattern —
newly-shipped deliverable not yet live for the next feature — but
here the failure mode is **cache refresh lag**, not install gap.

Implication: the "next feature after archive" clause in *How to apply*
should read "next feature after **session restart** following archive",
not merely after archive. The opt-out flag (`--skip-inline-review`)
and STATUS Notes trace are already in place and handled this cleanly.

