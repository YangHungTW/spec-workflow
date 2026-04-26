---
name: Threshold-suggest false positives — test-line dominance and bookkeeping-floor variants
description: When auto-upgrade SUGGESTED tiny→standard fires, decompose the diff before accepting. Two false-positive patterns: (1) test-line-dominance (test ≥ 50% of additions, prod is explicit-mirror by plan); (2) bookkeeping-floor (05-plan.md + STATUS.md account for ≥ 50% of file count, lines well under threshold). Both decline; tier stays tiny with a STATUS note.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When STATUS records `auto-upgrade SUGGESTED tiny→standard (diff: N lines, M files; threshold X/Y)`, the orchestrator/TPM must inspect WHAT contributed to the trigger before accepting. Two false-positive variants:

- **Test-line-dominance**: ≥50% of added lines are in `test/` and the production additions are explicitly-duplicated mirror blocks (per `common/minimal-diff.md` entry 2 / chore-tiny "no helper extraction").
- **Bookkeeping-floor**: bookkeeping files (`05-plan.md` + STATUS.md, similar) account for ≥50% of the file count AND total prod+test line additions are well under the line threshold (e.g. <50 lines on a 200-line threshold) — files-count-only trigger.

Either variant ⇒ decline the upgrade and append a STATUS note naming the variant.

## Why

The threshold (200 lines / 3 files) was calibrated against feature-tier signal where prod and test lines roughly track each other AND substantive file count dominates bookkeeping. Two distinct chore-tier scenarios subvert the calibration:

1. Chore-tier work that ships dual-emit-site code by explicit plan decision plus a thorough test produces inflated line counts without inflated complexity (test-line-dominance).
2. Even the smallest chore that touches more than one substantive file will trip the files-count threshold (3) once the two bookkeeping files (`05-plan.md`, `STATUS.md`) are added — a `1 substantive + 1 memory + 2 bookkeeping = 4 files` shape is the floor. Bookkeeping files contribute 0 complexity but 100% of the marginal file-count overage (bookkeeping-floor).

Upgrading the tier on either false-positive triggers reviewer-axis runs and merge-check overhead that the work does not need; downstream parallelism reasoning becomes incorrect because the tier no longer matches the work shape.

## How to apply

1. **On SUGGEST**: compute the file-class split via `git diff --stat <base>...HEAD` and bucket additions into `bin/*` (prod), `test/*` (test), `.specaffold/*` (bookkeeping). Bookkeeping does not count toward complexity.
2a. **Test-line-dominance decline criteria** (ALL must hold):
   - test-additions ≥ 50% of (prod + test) added lines.
   - prod additions are mirror duplicates by explicit plan decision (e.g. plan §1.2 "Why one task" notes the duplication, or plan cites `minimal-diff.md` entry 2 for helper-deferral).
   - work-type is chore OR bug. Genuine features should generally accept SUGGEST; the asymmetry is most acute on chores that ship to multiple call sites.
2b. **Bookkeeping-floor decline criteria** (ALL must hold):
   - Bookkeeping files (`05-plan.md`, `STATUS.md`, similar) account for ≥50% of the changed file count.
   - Total prod+test line additions are well under the line threshold (e.g. <50 lines on a 200-line threshold — clear false positive on lines, files-count-only trigger).
   - work-type is chore OR bug.
3. **Decline action**: do NOT call `set_tier`; append STATUS note `<date> archive — tier stays tiny; SUGGEST declined per tpm/threshold-suggest-test-vs-prod-line-asymmetry pattern (variant=<test-line-dominance|bookkeeping-floor>; <one-line decomposition>)`.
4. **Accept criteria**: prod ≥ 50% AND prod additions are uncoupled (not mirror duplicates) AND bookkeeping is < 50% of file count. Use `set_tier $feature_dir standard "<reason citing the prod-line shape>"` BEFORE archive's git mv.

## Example

**Variant 1 — test-line-dominance** (`20260426-chore-seed-copies-settings`): SUGGEST fired at 4 files / 433 lines (limits 200/3). Decomposition: 161 prod lines in `bin/scaff-seed` (9 enumerator + 76 + 76 byte-identical mirror per `qa-analyst/scaff-seed-dual-emit-site-hazard`) + 270 test lines in `test/t114_seed_settings_json.sh` + 2 bookkeeping. Test = 270/431 = 63% of meaningful additions; prod was explicit-mirror by plan §1.2 ("Why one task" — duplication preserved by minimal-diff entry 2). SUGGEST declined per criterion 2a; tier stayed tiny; STATUS note appended. Validate verdict (NITS) and archive proceeded without the standard-tier reviewer-axis runs.

**Variant 2 — bookkeeping-floor** (`20260426-chore-status-template-skip-stages`): SUGGEST fired at 4 files / 9 lines (limits 200/3). Decomposition: substantive = `.claude/commands/scaff/next.md` (+8/-2) + `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md` (+1/-1) = 9 prod lines spread across 2 files; bookkeeping = `05-plan.md` + `STATUS.md` = 2 files; bookkeeping is 50% of file count and contributes 0 lines toward complexity. Lines (9) are 22× under the 200 threshold — clean files-count-floor false positive. SUGGEST declined per criterion 2b; tier stayed tiny; STATUS note appended.

Cross-references:
- `common/minimal-diff.md` entry 2 (helper-deferral discipline that drives mirror duplication).
- `qa-analyst/scaff-seed-dual-emit-site-hazard.md` (binary-specific instance of the mirror pattern).
- `bin/scaff-tier` `set_tier` and `bin/scaff-stage-matrix` (the helpers a TPM uses to act on the decision).
- Source: STATUS.md threshold note + 08-validate.md "Threshold-upgrade note" of `20260426-chore-seed-copies-settings`.
