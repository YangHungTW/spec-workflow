---
name: Partial wiring trace — assert a test path for every emit site of a shared template
description: When a developer fixup extends scope mid-implement (e.g. patches both cmd_init and cmd_migrate emit sites of the same shim template), the analyst should trace every entry point of the affected mechanism and assert each has a corresponding test; a passing runtime + missing test path for a mirror emit site is a should-class wiring-trace gap.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a feature ships a shared template (a heredoc, a config snippet, a markdown directive) emitted from N ≥ 2 call sites in the same binary, the qa-analyst at validate must trace every emit site to a corresponding test path. A passing runtime + missing test path for a mirror emit site is a `should`-class wiring-trace gap, NOT advisory — it represents a real coverage gap that will silently regress on the next refactor of that binary.

## Why

`20260426-scaff-init-preflight` W2 fixup patched `bin/scaff-seed` at two emit sites (`cmd_init` line 733 AND `cmd_migrate` line 1314 — both heredocs that emit the pre-commit shim). The original plan T4 only named line 733; the W2 reviewer-security found the line 1314 mirror as an out-of-scope finding; the orchestrator landed a fixup commit that updated both heredocs to byte-identical two-invocation form.

But the corresponding test (`test/t108_precommit_preflight_wiring.sh`) only exercises the `cmd_init` path. A user running `scaff-seed migrate` instead of `init` would currently get the correct shim because of the fixup — but if a future refactor diverges the two heredocs again, only the `cmd_init` test fails; the `cmd_migrate` regression ships silent.

The validate-stage analyst caught this as a `should` finding. The pattern generalises: ANY aggregator/dispatcher with N ≥ 2 emit sites for the same template needs a test per emit site. Without the discipline, mid-implement scope extensions tend to land production fixes without matching test coverage; the test gap is invisible at the next merge but compounds across feature lifecycles.

## How to apply

1. **At validate time**, for any binary touched by the feature, run a coverage trace:
   ```bash
   # Find every emit site of the modified template (e.g. printf heredoc)
   grep -n 'pre-commit shim — installed by' bin/scaff-seed
   # Then find every test that exercises that binary's relevant entry-points
   grep -lF 'scaff-seed init' test/   # for cmd_init
   grep -lF 'scaff-seed migrate' test/ # for cmd_migrate
   ```
   If emit-site count > test-coverage count, the gap is a `should`-class finding regardless of whether the runtime currently works.
2. **Phrase the finding** as a wiring-trace gap, not a runtime regression. Example:
   ```
   should @ test/t108_precommit_preflight_wiring.sh:1
     rule: partial-wiring-trace-every-entry-point
     message: cmd_migrate shim path (bin/scaff-seed line 1314) updated in W2 fixup
              but not exercised by any new test; t108 A2 tests init only;
              migrate path is a coverage gap for R4/AC4.
   ```
   The `should` (not `must`) reflects: the runtime works today; the regression risk is on the NEXT refactor, not this commit.
3. **At plan-update time** (`/scaff:update-task` mid-feature), if a fixup adds a mirror site, the TPM should ALSO add a test-extension task in the same wave OR the next wave. Do not let mid-flight scope extension carry through to validate without paired test coverage.
4. **Cross-reference** `architect/by-construction-coverage-via-lint-anchor.md` step 3 ("Mirror-emit sites must update together"): the architect's plan-time decision lists every emit site by `grep -n` line number; the analyst at validate cross-checks that each line has a test.

## Example

W2 of `20260426-scaff-init-preflight` shipped this state at validate:

| Emit site | bin/scaff-seed line | Updated in W2? | Test coverage |
|---|---|---|---|
| `cmd_init` shim heredoc | 733 | yes (T4) | yes (t108 A2 — sandboxed init produces hook with both invocations) |
| `cmd_migrate` shim heredoc | 1314 | yes (W2 fixup commit) | **NO — no test exercises migrate** |

Analyst finding (verbatim from `08-validate.md`):

```yaml
- severity: should
  file: test/t108_precommit_preflight_wiring.sh
  line: 1
  rule: partial-wiring-trace-every-entry-point
  message: cmd_migrate shim path (bin/scaff-seed line 1314) updated in W2
           fixup but not exercised by any new test; t108 A2 tests init only;
           migrate path is a coverage gap for R4/AC4.
```

Recommended remediation in archive retro: open a follow-up chore (`/scaff:chore`) to extend `t108` with an `A5: scaff-seed migrate produces hook with both invocations` assertion. Bias toward "add the test now" rather than "trust runtime"; the test gap costs more on the second occurrence than authoring it once.

The pattern is not specific to shim emitters — it applies to any place where a feature adds the same byte-identical template to multiple call sites. Examples for the next time: agent-prompt skeletons emitted from multiple commands; STATUS Notes line formats emitted from multiple stage handlers; default-config blobs emitted from multiple init paths.
