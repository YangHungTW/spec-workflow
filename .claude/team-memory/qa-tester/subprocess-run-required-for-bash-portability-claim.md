---
name: Subprocess-run is required to issue any bash-portability verdict
description: Reviewer-style and qa-tester MUST execute the script under `/bin/bash` before issuing PASS/NITS on a bash file. Static review of the diff against the known anti-pattern checklist catches the head; only an actual run catches the long tail (e.g. `printf '--' …` parsed as an option flag).
type: feedback
created: 2026-04-26
updated: 2026-04-26
---

## Rule

Whenever a reviewer (any axis that touches bash files) or qa-tester is about to mark a bash script as PASS or NITS for the bash-32-portability rule, they MUST execute the script under `/bin/bash` (which is 3.2 on macOS) — not just static-read the diff against the anti-pattern checklist in `.claude/rules/bash/bash-32-portability.md`.

## Why

In `20260426-fix-commands-source-from-scaff-src` W1 inline review, reviewer-style cleared `test/t113_scaff_src_resolver.sh` after flagging some dead code (`run_resolver` helper + orphan `resolver_exit.$$`), but missed three lines of `printf '--- A1a: ...\n'`. On bash 3.2 the leading `--` is parsed as an option terminator by the `printf` builtin, and the script crashes at line 95 with `printf: --: invalid option`. With `set -euo pipefail` the test exits 2 before any assertion runs, gating zero AC coverage.

The portability rule lists the head of the failure distribution — `[[ =~ ]]`, `readlink -f`, `realpath`, `mapfile`, GNU-only flags, `case` inside subshells. It cannot enumerate every BSD/3.2 quirk (`printf '--`, weird `printf '%-2.3s'` parsing, `read -d ''` differences, etc.). The validate stage caught this only because qa-tester actually ran the test on bash 3.2; W1 inline review's static read missed it.

The cost: one fixup commit (`2392322`) post-merge instead of inline-fix during W1, plus an extra qa-tester + qa-analyst dispatch cycle (BLOCK → re-validate → NITS).

## How to apply

1. **Reviewer-style on bash files**: before issuing the verdict, run `/bin/bash <script>` (or `/bin/bash -n <script>` at minimum, but a real run beats syntax-only). If the script needs sandbox setup the reviewer cannot easily build, expand the task scope with a "smoke-runnable" requirement: the script must be able to run end-to-end against the source repo's own state.
2. **qa-tester at validate stage**: every newly-added test script must be executed under `/bin/bash`, not trusted on its structural shape. A test that exits non-zero (or, worse, exit 2 from a parser crash) is a `must`-severity finding regardless of how much of the AC it claims to cover.
3. **`bash -n` is not enough**: it only checks syntax. The `printf '--'` failure passes `bash -n` and crashes at runtime.

## Example

W1 reviewer-style verdict on T2 (incorrectly cleared a crashing test):

```
## Reviewer verdict
axis: style
verdict: NITS
findings:
  - severity: should
    file: test/t113_scaff_src_resolver.sh
    line: 18
    rule: dead-code
    message: run_resolver helper is unused; remove or call it
```

The diff containing `printf '--- A1a: env var override ---\n'` was right there, but the reviewer never ran the test. Validate caught it as F1 must:

```
- severity: must
  file: test/t113_scaff_src_resolver.sh
  line: 95
  rule: bash-32-portability
  message: printf '--- A1a: env var override ---\n' treats leading '--' as an option flag on bash 3.2 (exit 2)
```

Fix at lines 95, 124, 154 was the argv form `printf '%s\n' '--- A1a: ...'`. One real subprocess invocation during W1 review would have caught this in the same window the dead-code finding came from.
