---
name: Batch by default when a test iterates over item lists
description: Bash tests that invoke a subprocess per item for ≥~10 items will BLOCK on reviewer perf axis; batch at author time, not after retry.
type: feedback
created: 2026-04-21
updated: 2026-04-21
---

## Rule

When writing a bash test (or any shell script on a reviewer-watched path) that iterates over a list of items and invokes a subprocess per item (python3 for JSON parse, jq for key extract, awk for string transform), batch the invocation at authoring time. Do not author the naive per-item loop even as a "draft" — the reviewer performance axis will block it with a `must` at item counts ≥ ~20, and the batch refactor is a mechanical rewrite you should do once, not twice.

## Why

`20260420-flow-monitor-control-plane` T116 (`test/t96_i18n_parity_b2_keys.sh`) authored the naive form: 26 i18n keys × one `python3 -c 'import json; …'` fork per key = 52 python3 invocations per test run. Reviewer wave-6a perf axis flagged it as `must` (citing `.claude/rules/reviewer/performance.md` rule 4 "prefer awk/sed over python3 for simple transforms"). Retry 1 batched to 2 python3 forks total plus an awk-based `map_get` helper (1 awk per key, rubric-endorsed as simple transform).

The retry landed cleanly but cost a full wave retry cycle. Had the author written the batched form from the outset — which is not meaningfully harder than the naive form once the author knows the pattern — the wave would have passed on the first pass.

The reviewer rule is explicit; the developer memory here is about the defensive posture: assume any test over an N-item list will be reviewed against the subprocess-in-loop axis, and write it batched. The extra 10 minutes at author time saves the retry cycle.

## How to apply

1. Before writing a loop in a bash test, count the list length. Any count ≥ ~10 is a batch candidate. Counts of 3–5 (a short fixed list like stage names) are fine naive.
2. The batched shape for JSON parse: load once into a bash variable via `python3 -c '...' < file`, then `awk` or bash substring over the variable. Example from T116 retry:
   ```bash
   json_en=$(python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))' < en.json)
   map_get() { echo "$json_en" | awk -v k="$1" 'index($0,k)'; }
   for key in "${keys[@]}"; do val=$(map_get "$key"); … ; done
   ```
   Two python3 forks (en + zh-TW), N awk forks — not 2N python3 forks.
3. For jq alternatives: prefer piping through `jq` once with a multi-key query, collecting to a TSV, then iterate over lines.
4. At task commit time, self-check: `grep -c 'python3\|jq\|node -e' <script>` — more than ~5 subprocess invocations in a shell test is a red flag; either they're in a loop (fixable) or the test is too big (split).

## Example

Cross-reference: `.claude/rules/reviewer/performance.md` rules 1, 4, and 6. This developer memory is the proactive flip side of the reviewer rule — the reviewer enforces at merge; the developer memory prevents the retry.
