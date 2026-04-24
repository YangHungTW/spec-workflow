---
name: Dogfood paradox — structural verify during bootstrap, runtime exercise next feature
description: Features that deliver the tool they would themselves use need structural-only verification; live runtime exercise happens on the next feature.
type: pattern
created: 2026-04-18
updated: 2026-04-24
---

<!-- 2026-04-18 update: added fifth and sixth occurrences from
feature 20260418-per-project-install — the sixth reinforces that
dogfood execution starts at whatever state the dev machine happens
to hold, which synthetic sandboxes cannot model. -->

<!-- 2026-04-19 update: 7th occurrence = 20260419-language-preferences
(SessionStart hook reads lang.chat config, emits LANG_CHAT marker);
8th occurrence = 20260419-user-lang-config-fallback (same hook
extended to ordered candidate list: project → XDG → ~/.config). Both
structurally verified only — runtime handoff from the 7th was
carried by the 8th's own T1 hook edit; runtime handoff from the 8th
falls to the NEXT feature archived. Neither surfaced a new dogfood-
exposed bug, so no new pattern is added — the entries below (4th and
6th occurrences) still cover the observed failure modes. -->

<!-- 2026-04-20 update: 9th occurrence = 20260420-tier-model (the
three-tier workflow ships the `/scaff:validate` aggregator + new
merged 05-plan.md shape + retired-command stubs that THIS feature's
own implement would have to dispatch through). Three tier-model
archive-stage symptoms surfaced, each a dogfood-paradox variant:

1. **06-tasks.md symlink bridge** — the feature authored only
   `05-plan.md` (new shape per R19) but `/scaff:implement` and
   the developer-agent briefing flow still read `06-tasks.md`. A
   bootstrap symlink `06-tasks.md → 05-plan.md` was installed to
   let this feature run through its own implement; removed at
   archive. Classic "mechanism not yet installed on itself" mode.

2. **archive.md expected `08-verify.md`** — the stage-transition
   check in `/scaff:archive` grep'd for `08-verify.md` verdict=PASS,
   but this feature authored `08-validate.md` (new name per R15).
   Dispatch code was updated in W3 (T21), but the archive command's
   own contract still referenced the old name. Surfaced as a
   stage-advance refusal at archive attempt.

3. **aggregator expected `## Reviewer verdict`** — the new-shape
   `/scaff:validate` emits `## Validate verdict` footers (R17),
   but `bin/scaff-aggregate-verdicts` (extracted in W1 T7) still
   accepted only `## Reviewer verdict` at line 137. All validate
   footers were rejected as malformed, forcing a BLOCK verdict.
   Fixed during validate-cycle by accepting both headers (orchestrator
   surgical fix noted in STATUS 2026-04-20 line 22).

Common failure mode across all three: the feature redefines a
contract (task-doc filename, verify artefact name, verdict-footer
header), and at least one consumer of the old contract survives the
migration because it was not explicitly enumerated in the plan.
Implication for next dogfood-paradox feature: TPM should grep-enumerate
every consumer of a renamed contract BEFORE planning the rename wave
(cross-reference `tpm/tasks-doc-format-migration.md`). Symptom
severity is "archive-blocker" not "runtime surprise", because the
self-shipping mechanism collides with itself during its own archive
sequence, not on the next feature. -->

<!-- Discipline at archive time: every feature that invokes the
dogfood paradox in its PRD/tech/plan should bump the occurrence log
above with one sentence each. Do NOT rewrite the body entries unless
a new failure mode surfaces. -->

<!-- NOTE: filename says "third-occurrence" but file now records 8
occurrences (2026-04-19); kept filename stable to avoid breaking
refs. -->


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

Third-occurrence pattern across the Specaffold harness upgrade series:

- **B1 (prompt-rules-surgery)** — shipped SessionStart hook. Hook
  itself doesn't fire during the feature's own session (was already
  open). Structural verification was all the feature could offer.
  First real exercise: user manually opened a fresh session after
  merge.
- **B2.a (shareable-hooks)** — shipped Stop hook. Same paradox:
  the hook would fire on `/scaff:implement` stopping, but the
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
  `/scaff:implement` run cleanly during bootstrapping.
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

### Fifth and sixth occurrences (2026-04-18)

**Fifth occurrence** — feature `20260418-per-project-install`: the
entire plan was dogfood-staged. This repo stayed on the
global-symlink model through W0–W5 and migrated to per-project only
in W6 as the feature's final act. The structural-vs-runtime split
held cleanly: structural verification was the archive gate
(08-verify.md verdict PASS with 1 N/A for the option-B dogfood
variant), and runtime confirmation is deferred to the next feature's
first session after restart.

**Sixth occurrence** — same feature, option-B execution variant:
the developer's machine had no pre-existing global install of
Specaffold, so running `migrate --from .` meant consumer == source
tree. This surfaced a bug invisible to all synthetic sandboxes: the
W2-hotfix idempotent-exit short-circuit fired when ALL files
classified as `ok` AND the manifest didn't yet exist (the
first-time-dogfood case). Net effect: migrate succeeded, but no
manifest was written — the consumer looked like an unmanaged tree
on the next run. Fix: add `[ -f "${consumer_root}/.claude/scaff.manifest" ]`
to the short-circuit condition in both `cmd_init` and `cmd_migrate`,
so first-time writes still author the manifest.

Lesson reinforced: **dogfood execution always reveals something
synthetic sandboxes miss**, because sandboxes start empty and
dogfood starts at whatever state the dev machine happens to hold.
The starting state distribution for dogfood runs is the set
{never-installed, installed-at-current-ref, installed-at-stale-ref,
partial-install}; test sandboxes only model the first and
(sometimes) the second. Plan for at least one dogfood-surfaced fix
per self-shipping feature; don't treat it as a process failure.


---

## Ninth occurrence (2026-04-21, `20260420-flow-monitor-control-plane`)

No new failure mode — the pattern held. Nine occurrences confirms the
structural-only / runtime-deferred split is stable at scale:

- 03-prd.md §9 Acceptance summary tagged every AC `[Verification: structural|runtime|both]`.
- 05-plan.md §2.3 listed 16 structural ACs covered in this feature's validate, 15 runtime deferred.
- RUNTIME HANDOFF STATUS line was pre-committed at T113 (W6) before archive — not an afterthought.
- Validate §Runtime-deferral summary enumerated 15 deferred ACs by number.
- qa-tester correctly deferred the 15 runtime ACs without attempting to PASS them from build-success alone.
- T121 / t101_runtime_handoff_note.sh structurally asserts the handoff sentinel line is present.

Sub-pattern promoted to discipline: **pre-commit the RUNTIME HANDOFF line as a TPM-owned task
in the final wave**, not as an archive-time afterthought. The handoff line reads:

> `RUNTIME HANDOFF (for successor feature): opening STATUS Notes line must read "YYYY-MM-DD orchestrator — B2 control plane exercised on this feature's first live session". 15 runtime ACs deferred; list at .specaffold/archive/<slug>/03-prd.md §9.`

If the feature invokes the paradox, the TPM should reference this shared memory
at plan time (not just the PM at PRD time). The ninth occurrence's 05-plan.md §1.2
did this explicitly.

## Tenth occurrence (2026-04-24, `20260424-entry-type-split`)

New variant — **work-type split (`/scaff:request` vs `/scaff:bug` vs
`/scaff:chore`) is itself a self-shipping mechanism**. The feature could
not exercise its own dispatch via the new entry commands during implement
because the commands didn't exist until merge. Validate was
structural-only (3×3 stage-matrix table assertions, slash-command file
shape, PM/TPM probe-anchor presence) per the established discipline.

Three reinforcements observed, no new failure mode:

1. **Pre-commit RUNTIME HANDOFF line held clean** — T17 authored a
   `RUNTIME HANDOFF (for successor feature):` sentinel into STATUS
   before W3 closed; t106 structurally asserted the sentinel line via
   `grep -q "RUNTIME HANDOFF"`. Discipline from 9th occurrence carried
   forward without drift.
2. **Bootstrapped entry must dispatch through existing entry** — this
   feature's own `/scaff:request` invocation predated the split, so
   intake ran via the legacy single-entry path. Documented in PRD R2
   ("backward compat: legacy `/scaff:request` continues to accept all
   work-types until the next major bump"). No special bootstrap flag
   needed because the legacy path remained valid.
3. **Tier matrix asymmetry caught structurally** — t102_stage_matrix.sh
   asserts the full 72-cell ternary (work-type × tier × stage →
   required|optional|skipped). Structural assertion of the dispatch
   table is the dogfood-paradox-safe equivalent of "actually dispatch a
   bug feature end-to-end" — the next bug feature will be the runtime
   exercise.

Cumulative pattern at 10 occurrences: structural verify + RUNTIME
HANDOFF sentinel + grep-anchored test of the sentinel line is now the
**default** dogfood-paradox handling. The split was novel only as a
data-shape change (3 entry commands instead of 1); the discipline did
not need to evolve.

RUNTIME HANDOFF (this feature):
> `2026-04-25 (or first day with a new bug/chore) — bug feature exercised /scaff:bug end-to-end via auto-classify branch; chore feature exercised /scaff:chore end-to-end with tier=tiny default.`
