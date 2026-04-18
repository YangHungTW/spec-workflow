# Plan — review-nits-cleanup

**Slug**: `20260418-review-nits-cleanup`
**Date**: 2026-04-18
**Author**: TPM
**Stage**: plan

---

## Shape

Small housekeeping sweep. 14 requirements across 8 files, near-mechanical per PRD §9 traceability and tech decisions D1–D6. Target: ≤10 tasks, 2 waves (wide-parallel edits → verification bundle).

## Milestones

- **M1** — R1 slug validator in `review.md` (D1: `case`-glob, bash 3.2 portable; no `[[ =~ ]]`).
- **M2** — R2 `awk`-fold in `t35.sh` with R11 folded in (D5); R3 read-once refactor in `t34.sh`. Both gated by byte-identical output diff (D2).
- **M3** — R4 path rename in `reviewer-security.md` with pre-edit classifier grep (D3); R5 invocation-block reshape in `reviewer-style.md`; R6 indent normalize in `implement.md`. Three different files — parallel-safe.
- **M4** — R7 + R8 + R9 pipefail adds. Three different test files, trivial sed-class edit. Bundled into **one** task: overhead of three tasks exceeds savings for a 3-line mechanical change.
- **M5** — R10 WHAT-comment delete in `t26.sh` (R11 already folded into M2).
- **M6** — R12 delete `to_epoch()` in `stop.sh` (D4: developer re-runs `grep -rn 'to_epoch' .` at task start; abort to PM if any new live caller surfaces; pre-check at tech stage confirmed zero live callers).
- **M7** — Verification bundle: R13 repo-wide grep for `reviewer-security/` → 0 hits; R14 `bash test/smoke.sh` → 38/38 PASS. Serialized after all edits.

## Sequencing rationale

- **Wave 1 (wide parallel)** runs M1–M6 concurrently. Every task touches a distinct file per PRD Traceability + tech §2 file map. Per `parallel-safe-requires-different-files`: file-disjointness is the primary safety predicate, and it holds here (t34.sh is R3+R7 — bundled into one task; t35.sh is R2+R11 — folded into one task per D5).
- **Wave 2 (serial verify)** runs M7 after Wave 1 merge. `smoke.sh` and repo-wide greps must see the merged tree.
- No dependency chains between M1–M6: each is a self-contained edit with its own acceptance gate. Wave 1 width is maximal for the given file map.

## Risks

- **Dogfood paradox** — this feature's `/specflow:implement` will be the FIRST run with inline-review reviewers actually wired up (shipped in the just-archived `review-capability` feature). Two sub-risks:
  - If native-subagent cache is cold in the session, reviewer dispatch may no-op; fallback is `--skip-inline-review`.
  - If cache is warm, reviewers run per merge and may flag our own edits. That's signal, not noise — log findings in STATUS and decide live. Per shared memory `dogfood-paradox-third-occurrence.md`, structural verification is the bootstrap bar; runtime reviewer exercise becomes meaningful on the next feature regardless of this run's outcome.
- **R2/R3 output drift** (P1/P2 refactors) — `awk`-fold and read-into-variable can silently shift whitespace or ordering. Mitigation: per D2, developer captures `bash test/tXX.sh 2>&1` into a sandbox pre-refactor and `diff`s against post-refactor. Empty diff is the hard acceptance gate (AC2, AC3). Not optional.
- **Append-section collisions** — per `parallel-safe-append-sections`: STATUS Notes lines and any shared index will collide across six concurrent Wave-1 merges. Accept mechanical keep-both resolution; do not re-serialize the wave.
- **Checkbox loss post-merge** — per `checkbox-lost-in-parallel-merge`: orchestrator must audit `06-tasks.md` checkboxes after each wave merge and auto-flip any that lost their `[x]` during conflict resolution. Known pattern; not a new risk but must be on the checklist.
- **Stale path references outside `reviewer-security.md`** — D3 pre-check at tech time showed exactly one file contains `reviewer-security/`. State may have drifted; R4 task starts with a re-run of the classifier grep to confirm before editing (classify-before-mutate rule).
- **`to_epoch` surprise caller** — D4 pre-check showed zero live callers; task must re-grep at start and escalate to PM if any appears.

## Out of scope for v1

Per PRD §3 / Tech §6 non-decisions:

- No rubric, verdict-contract, or agent-frontmatter schema edits beyond R1.
- No WHAT→WHY comment rewrites (locked decision: drop, don't rewrite).
- No repo-wide `set -u` → `set -u -o pipefail` audit beyond R7/R8/R9.
- No repo-wide `[[ =~ ]]` audit.
- No `case`-glob-as-convention promotion. Triggers for each are listed in Tech §6.
- Findings discovered during the sweep log to a future feature — not absorbed here.
