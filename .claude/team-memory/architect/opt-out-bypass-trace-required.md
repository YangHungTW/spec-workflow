---
name: Opt-out bypass flag — STATUS Notes trace required on use
description: Any safety-gate bypass flag (--skip-X, --force, --no-verify) must append a STATUS Notes entry when used; silent bypasses create audit black holes.
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Context

Safety gates (review, verification, hook enforcement) exist for a
reason. They also sometimes legitimately need bypass — bootstrapping,
emergency, debugging. But a bypass flag that triggers silently is
indistinguishable from the gate not firing at all. Six months later,
when a regression surfaces, no one knows whether the check was
skipped deliberately or if the infrastructure silently failed.

The fix is cheap: every bypass flag writes one line to STATUS Notes
on use. Audit becomes trivial: `grep "skip" STATUS.md` surfaces every
bypass in the feature's history with timestamp, user, and (if
required) reason.

## Template

1. **Every bypass flag has a name starting with `--skip-`, `--no-`,
   or `--force`.** The user can recognize the semantic category at
   a glance.
2. **Every flag appends a one-line STATUS Notes entry on use**:
   ```
   - YYYY-MM-DD <role-or-user> — <flag> USED for <scope> (<reason>)
   ```
   Example: `2026-04-18 Orchestrator — --skip-inline-review USED for
   wave 3 (dogfood-paradox: this feature ships the reviewers)`.
3. **The flag parser captures or requires a reason.** Either an
   inline argument (`--skip-inline-review "bootstrapping"`) or a
   convention that the reason goes in the STATUS Notes line manually
   by the invoking human.
4. **A gap-check grep validates.** For every `--skip-*` / `--force`
   / `--no-*` occurrence in the command-line / CI history, there must
   be a corresponding STATUS Notes trace within 1 minute of the
   invocation. Missing trace = bug.
5. **Archive-time audit.** Before archiving a feature, surface every
   bypass use in 08-verify.md or 07-gaps.md so the user sees the
   trail one last time.

## When to use

- Any CLI flag that bypasses a safety gate, verification step,
  review mechanism, or rule-enforcement hook.
- Any `--force` flag on a mutating CLI (paired with
  `no-force-on-user-paths` rule).
- Any `--no-verify` / `--skip-checks` / `--ignore-*` flag.

## When NOT to use

- Flags that merely select among equivalent behaviors (e.g.,
  `--output-json` vs `--output-yaml`). Those are not bypasses.
- Read-only / query flags. No gate to bypass; no trace needed.

## Why

- **Audit trail**: every bypass is visible in feature history;
  no silent regressions.
- **Accountability**: the trace entry names a reason, so six-months-
  later retrospectives have context.
- **Distinguishes intent from bug**: a broken safety gate plus a
  missing trace is a bug; a trace plus bypass is intent.

## Example

`/specflow:implement <slug> --skip-inline-review` (from feature
`review-capability`, B2.b, R7). Each use appends:

```
- 2026-04-18 Orchestrator — --skip-inline-review USED for
  bootstrap wave (dogfood paradox: reviewer agents ship in this feature)
```

Adjacent to `architect/no-force-by-default.md` (that memory covers
defaults on user-owned paths; this one covers escape-hatch
accountability across all bypass flags).
