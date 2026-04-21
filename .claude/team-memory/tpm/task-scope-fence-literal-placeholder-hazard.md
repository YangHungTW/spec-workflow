---
name: Task scope-fence literal placeholder hazard
description: Placeholders like `tN_` or `<fill>` inside a task's Files:/Acceptance: field are interpreted literally by developers; pre-fill or flag with a MUST-REPLACE marker.
type: feedback
created: 2026-04-20
updated: 2026-04-20
---

## Rule

Never leave a placeholder token (e.g. `tN_`, `<slug>`, `<fill>`, `tX_fooXYZ.sh`) inside a task's `Files:` or `Acceptance:` line in 06-tasks.md / 05-plan.md. Either pre-fill the real value or prefix the line with `MUST-REPLACE:` so the developer agent treats it as a hard stop.

## Why

Observed in 20260420-tier-model W2: tasks T11 and T16 carried `Files: test/tN_<name>.sh` as a scaffold from the plan template. Developers interpreted `tN` literally and wrote files named `test/tN_retired_brainstorm.sh` and `test/tN_retired_tasks.sh` to disk. Cleanup cost: rename to t78/t79 at wave-bookkeeping time, re-run tests, amend commit.

The failure mode is: a placeholder looks like prose to a human author but looks like a literal string to the developer agent. Developer agents do not heuristically replace `tN` with `t78` — they honour the spec verbatim. This is the correct behaviour (see `developer/test-script-path-convention.md` re: test files follow an established naming convention) but it interacts badly with unfilled placeholders.

## How to apply

1. **Before publishing any tasks doc, grep for placeholder markers**:
   ```
   grep -nE 'tN_|<[a-z-]+>|<new |<fill>' 05-plan.md 06-tasks.md
   ```
   Every hit is a planning bug to fix before developer dispatch.
2. **Pre-fill the tNN counter** using `ls test/ | grep -oE '^t[0-9]+' | sort -t t -k2 -n | tail -1` + 1.
3. **If the value genuinely cannot be known at plan time** (rare), prefix the line: `MUST-REPLACE: Files: <path>` and document in the task briefing what the developer should compute. Developer agents are trained to refuse a task with `MUST-REPLACE:` and bounce to TPM.
4. **Cross-reference** `tpm/pre-declare-test-filenames-in-06-tasks.md` for the same-wave collision angle.

## How to apply (checklist for the retrospective)

- If a developer committed a file matching `/tN_|<.*>/` pattern, it is a TPM planning miss, not a developer miss.
- Add the offending placeholder to the plan-review grep list for the next feature.
