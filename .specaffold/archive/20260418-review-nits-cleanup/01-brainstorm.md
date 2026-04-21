# Brainstorm — review-nits-cleanup

**Date**: 2026-04-18
**PM**: decisions already locked in `00-request.md` (team-memory path = shared `reviewer/`, include `to_epoch()` carryover → 14 items, WHAT-comments drop). This doc is intentionally short — no shape debate, just confirming the shape and sketching a grouping hint for TPM.

## Shape — one feature, one PRD

14 items, all `should`/`advisory`, all housekeeping. Same blast radius across the board: **zero behavior change**, text-only edits or dead-code removal. `pm/split-by-blast-radius-not-item-count.md` confirms — splitting is only warranted when failure surfaces differ, and here they do not. Ship-together is obviously right.

No separate B1/B2 carve-out. Single PRD, single plan, single verify run.

## Grouping hint for TPM (not prescriptive)

TPM owns task decomposition; this is just a sighting to save a read-through:

| Group | Items | Nature | Likely task count |
|---|---|---|---|
| A — cross-file convention | St1, St2, St8 | Reviewer agent team-memory path alignment + `implement.md` indent. Agent/command files. | 1–2 |
| B — `set -o pipefail` on tests | St3, St4, St5 | Mechanical `set -euo pipefail` fix, 3 test files. One task. | 1 |
| C — comment drops | St6, St7 | One-line deletions, 2 test files. One task. | 1 |
| D — security | S1 | Slug-input validation, single command file. | 1 |
| E — perf | P1, P2 | `awk` folding + read-into-variable. Two test files, each a real refactor. | 2 |
| F — carryover | `to_epoch()` removal from `.claude/hooks/stop.sh:108-117` | Single file, dead-code delete. | 1 |

Natural consolidations suggested to TPM: **St3+St4+St5** in one task (same fix, 3 files), **St6+St7** in one task (same pattern, 2 files), **St1+St2** in one task (same file-family). S1, P1, P2, and the `to_epoch()` carryover each plausibly their own task. Rough estimate: **~7 tasks**, mostly S/M, fits one wave or two parallel waves.

## Risks

Low overall. Two worth naming:

1. **P1/P2 behavior drift** — `awk` folding can miss a case that the original loop caught; read-into-variable can change shell-expansion timing. Mitigation: diff test output before/after in each P-task.
2. **St1 converging `reviewer-security/` → `reviewer/`** — if any prompt or path reference still points at the old dir, it breaks silently at reviewer-agent load. Grep for `reviewer-security` after the rename; verify index entries and any agent frontmatter references.

Everything else is pure text edits; revertable in one commit.

## Dogfooding opportunity

This is the **first real feature after the reviewer capability shipped**. The inline review gate will actually fire during its own implement stage — first non-structural exercise of B2.b. Flag as a live test: if the reviewers produce friction or their own nits, that is immediate signal worth logging.

Escape hatch: if the SessionStart hook cache means native reviewer subagents aren't picked up in this session, `--skip-inline-review` is the documented bypass. Implement stage can fall back without blocking the feature.

## Open questions

None. All decisions locked at request stage.

## Recommendation

Proceed straight to PRD. Single feature, 14 requirements (one per item, IDs mirror source: S1, P1, P2, St1–St8, plus X1 for the `to_epoch()` carryover). Each requirement is a testable "this file/line now reads … / no longer contains …" assertion — perfect fit for PRD acceptance criteria format.
