---
name: bin/scaff-seed has two parallel emit sites — every shared template needs a test path per site
description: bin/scaff-seed contains byte-identical mirror blocks in cmd_init and cmd_migrate; any feature touching one must touch both, and any new test must exercise both paths. Two consecutive features (T108 shim, T114 settings.json merge) shipped with init-only test coverage and got partial-wiring-trace findings at validate.
type: reference
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a task modifies `bin/scaff-seed`, immediately grep for the same modification site in BOTH `cmd_init` and `cmd_migrate`; treat the two as a single emit pair. Any new test file under `test/t1*.sh` that exercises `bin/scaff-seed` must include at least one assertion against `scaff-seed migrate` (not just `init`), or the analyst at validate will flag a `should`-class wiring-trace gap (cross-references `qa-analyst/partial-wiring-trace-every-entry-point.md`). Third occurrence in this binary should escalate to `must` severity per the established escalation pattern.

## Why

`cmd_init` (lines ~470–1100 in current HEAD) and `cmd_migrate` (lines ~1300–1600) maintain parallel manifest-driven copy logic. Every shared template — pre-commit shim (T108 of `20260426-scaff-init-preflight`), settings.json merge block (T1 of `20260426-chore-seed-copies-settings`) — gets emitted twice. The `test/t108_*` and `test/t114_*` files both shipped with init-only coverage; both got partial-wiring-trace findings at validate. The pattern is now empirically confirmed across two consecutive features.

## How to apply

1. **At plan time on any `bin/scaff-seed` task**: `grep -n '<keyword-from-task>' bin/scaff-seed` and confirm to TPM that ≥2 emit sites are visible. Plan task §Scope must enumerate both call sites by line range.
2. **At task authoring time**: write A1/A2 (init paths) AND A4 (migrate path) in the same test file. The migrate-path A4 should pre-seed a manifest matching a prior init, run `scaff-seed migrate`, and assert the same end-state shape as the init paths.
3. **At validate time (qa-analyst axis)**: cross-grep `grep -lF 'scaff-seed migrate' test/t<NEW>*.sh` — empty result is the finding. Report as `partial-wiring-trace-every-entry-point` with this file as a binary-specific cross-reference.
4. **Plumbing-fix posture**: a future feature can collapse the mirror by extracting a shared dispatch helper, but until then this rule is the workaround; do not retroactively rewrite the mirror outside an explicit feature.

## Example

This feature (`20260426-chore-seed-copies-settings`): T1 added the merge arm to both `bin/scaff-seed:760` (cmd_init) and `bin/scaff-seed:1396` (cmd_migrate) — byte-identical 76-line Python heredoc blocks. `test/t114_seed_settings_json.sh` covers init (A1, A2) and update (A3) but not migrate. analyst Finding 1 flagged `partial-wiring-trace-every-entry-point` for the migrate-arm. The follow-up chore (filed at archive retro) extends t114 with an A4 migrate-path assertion.

Cross-references:
- `qa-analyst/partial-wiring-trace-every-entry-point.md` (the general rule this file specialises).
- Parent feature archive `20260426-scaff-init-preflight` (first occurrence — T108 shim emit, init-only test coverage).
- Source: `08-validate.md` Finding 1 of `20260426-chore-seed-copies-settings`.
