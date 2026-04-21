---
name: checkbox-lost-in-parallel-merge
role: tpm
type: pattern
created: 2026-04-18
updated: 2026-04-19
---

## Rule

After every wave-parallel merge, audit `06-tasks.md` for task-completion
checkboxes that were silently dropped during conflict resolution, and
auto-flip any `[ ]` back to `[x]` for tasks the wave merged.

## Why

During wide waves (e.g. 7-way parallel in B1, 7-way in B2.a), each
developer's worktree flips its own checkbox `- [ ] Tn` → `- [x] Tn`.
The merge presents these as content conflicts (line-level) adjacent
to append-only additions in STATUS Notes / index rows. Mechanical
"keep both" resolution for append conflicts works correctly, but
the checkbox flips for the OTHER wave tasks get silently discarded
because the resolver treats them as conflicting-not-additive. Result:
the all-tasks-done wave appears only partially complete until a
manual fix-up commit.

This is a sibling failure to `parallel-safe-append-sections.md`
(same root cause, different symptom: append lines survive, checkbox
flips do not).

## How to apply

1. After any wave merge, orchestrator runs
   `grep -c '^- \[x\]' 06-tasks.md` and compares to the expected
   checked count for all tasks merged in that wave (plus prior waves).
2. If the count is short, scan each merged `Tn` block and flip any
   `[ ]` to `[x]` for tasks the wave actually completed.
3. Commit the fix-up as `fix: check off T<n> T<m> ... (lost in merge)`
   so the provenance is clear in git log.
4. Do this once per wave — do not defer to end-of-feature audit, or
   the downstream `/scaff:implement` / gap-check commands may
   mis-report progress.

## Example

- Feature `20260416-prompt-rules-surgery` (B1) — wave merge lost T4 +
  T15 checkboxes. Required commit `fix: check off T4 (lost in merge)`
  and a separate T15 fix-up.
- Feature `20260417-shareable-hooks` (B2.a) — 7-way wave merge lost
  T1 + T2 checkboxes. STATUS note at 2026-04-18 records
  "T1/T2 checkboxes manually flipped" as the fix-up.

Both features required dedicated fix-up commits after the wave
merge; the pattern is predictable enough to automate as a post-merge
audit step.

Third instance: feature `20260418-review-nits-cleanup` Wave 1 (9
parallel — widest wave ever in this repo). T5 (reviewer-style.md)
and T7 (pipefail bundle) checkboxes lost during the merge; fix-up
commit re-checked them per this rule. Pattern held; prediction
confirmed at the new wave-width ceiling (9-way still loses ~2
checkboxes, consistent with 7-way losing 1–2).

Fourth occurrence: feature `20260419-flow-monitor` — W4 (T25-T29,
5-way) and W5 (T30-T42, 13-way) both lost 5+ checkbox flips during
sequential merge-after-parallel-dispatch. W5 at 13 parallel is now
the widest wave observed in this repo; the loss count scales roughly
linearly with wave width. The fix-up commits this time were painful
enough (multiple tasks lost per wave) to warrant promoting the
post-merge audit from a human-remembered discipline to an automated
step.

**Recommended automation**: add a mechanical post-merge audit step
to the wave-rollup flow in `bin/scaff-*` or the orchestrator:

1. After the wave merge commit lands, grep `- \[ \] T<n>` in
   `06-tasks.md` for every Tn in the merged wave.
2. If any `[ ]` matches appear for merged-wave tasks, flip them in
   a dedicated commit `fix: check off T<n> ... (lost in merge)`
   BEFORE the "wave done" marker lands in STATUS.md.
3. This makes the rollup atomic: either the wave is fully checked
   off or the audit blocks the marker.

Without the automation, the fourth-occurrence data point confirms
the pattern is now a predictable tax on every parallel wave ≥5
wide; manual vigilance is not catching it.
