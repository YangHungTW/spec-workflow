---
name: Threshold-suggest line count includes tests — chore tiers should weight prod-line ratio
description: When auto-upgrade SUGGESTED tiny→standard fires, decompose the diff into prod vs test line counts before accepting; if the test file dominates and prod blocks are duplicated by explicit plan decision (minimal-diff helper-deferral), the upgrade is a false positive and tier should stay tiny with a STATUS note.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When STATUS records `auto-upgrade SUGGESTED tiny→standard (diff: N lines, M files; threshold X/Y)`, the orchestrator/TPM must inspect WHICH files contributed the line count before accepting. If ≥50% of added lines are in `test/` and the production additions are explicitly-duplicated mirror blocks (per `common/minimal-diff.md` entry 2 / chore-tiny "no helper extraction"), the SUGGEST is a false positive driven by line-count alone, not complexity. Decline the upgrade and append a STATUS note explaining the asymmetry.

## Why

The threshold (200 lines / 3 files) was calibrated against feature-tier signal where prod and test lines roughly track each other. Chore-tier work that ships dual-emit-site code by explicit plan decision plus a thorough test produces inflated line counts without inflated complexity. Upgrading the tier triggers reviewer-axis runs and merge-check overhead that the work does not need; downstream parallelism reasoning becomes incorrect because the tier no longer matches the work shape.

## How to apply

1. **On SUGGEST**: compute the file-class split via `git diff --stat <base>...HEAD` and bucket additions into `bin/*` (prod), `test/*` (test), `.specaffold/*` (bookkeeping). Bookkeeping does not count toward complexity.
2. **Decline criteria** (ALL must hold):
   - test-additions ≥ 50% of (prod + test) added lines.
   - prod additions are mirror duplicates by explicit plan decision (e.g. plan §1.2 "Why one task" notes the duplication, or plan cites `minimal-diff.md` entry 2 for helper-deferral).
   - work-type is chore OR bug. Genuine features should generally accept SUGGEST; the asymmetry is most acute on chores that ship to multiple call sites.
3. **Decline action**: do NOT call `set_tier`; append STATUS note `<date> archive — tier stays tiny; SUGGEST declined per tpm/threshold-suggest-test-vs-prod-line-asymmetry pattern (test=N%, prod=mirror-dup by plan §X.Y)`.
4. **Accept criteria**: prod ≥ 50% AND prod additions are uncoupled (not mirror duplicates). Use `set_tier $feature_dir standard "<reason citing the prod-line shape>"` BEFORE archive's git mv.

## Example

This feature (`20260426-chore-seed-copies-settings`): SUGGEST fired at 4 files / 433 lines (limits 200/3). Decomposition: 161 prod lines in `bin/scaff-seed` (9 enumerator + 76 + 76 byte-identical mirror per `qa-analyst/scaff-seed-dual-emit-site-hazard`) + 270 test lines in `test/t114_seed_settings_json.sh` + 2 bookkeeping. Test = 270/431 = 63% of meaningful additions; prod was explicit-mirror by plan §1.2 ("Why one task" — duplication preserved by minimal-diff entry 2). SUGGEST declined; tier stayed tiny; STATUS note appended. Validate verdict (NITS) and archive proceeded without the standard-tier reviewer-axis runs.

Cross-references:
- `common/minimal-diff.md` entry 2 (helper-deferral discipline that drives mirror duplication).
- `qa-analyst/scaff-seed-dual-emit-site-hazard.md` (binary-specific instance of the mirror pattern).
- `bin/scaff-tier` `set_tier` and `bin/scaff-stage-matrix` (the helpers a TPM uses to act on the decision).
- Source: STATUS.md threshold note + 08-validate.md "Threshold-upgrade note" of `20260426-chore-seed-copies-settings`.
