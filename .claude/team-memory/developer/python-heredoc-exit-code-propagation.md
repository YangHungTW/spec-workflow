---
name: Pipe-into-python3-heredoc: explicitly check pipeline exit before reporting success
description: Under `set -u -o pipefail` without `set -e`, a failed `cat src | <python3-heredoc-fn> dst` silently returns non-zero while the caller still emits `created:` and increments counters. Always wrap in `if … then … else FAIL + SKIP fi`.
type: feedback
created: 2026-04-18
updated: 2026-04-18
source: 20260418-per-project-install
---

## Rule

Every dispatcher arm that pipes data into a heredoc-backed `python3`
helper MUST explicitly check the pipeline's exit status before
reporting success. Without an explicit check, the dispatcher emits
`created:` / `replaced:` and increments success counters even when
the write actually failed.

## Why

`specflow-seed` runs under `set -u -o pipefail` **without** `set -e`
(intentional — we want to classify and continue on per-file errors
rather than abort the whole run). That choice means:

- A failed `python3` inside a pipe sets `$?` non-zero after the
  pipeline.
- The very next line in the dispatcher arm is free to run anyway —
  bash does not abort.
- If that next line is `report created "$path"` or
  `CREATED=$((CREATED+1))`, the user sees a success line and a
  success count for a write that didn't happen.

Concrete failure mode observed in this feature: on a dev machine
with `asdf`-shimmed `python3`, the sandbox `HOME=$SANDBOX/home`
broke asdf's shim-lookup path → `python3` exited 126 → the
`cat src | write_atomic dst` pipeline returned non-zero →
`cmd_init` still emitted `created: .claude/agents/…` and
incremented `CREATED`. The manifest was written based on the
counter state, so the file list looked legitimate but dst paths
were missing. Silent data-shaped corruption.

## How to apply

Wrap every pipeline that writes through a heredoc-python3 helper:

```bash
if cat "$src" | write_atomic "$dst"; then
  report created "$dst"
  CREATED=$((CREATED+1))
  manifest_append "$dst" "$sha"
else
  report FAIL "$dst (write_atomic pipeline returned $?)"
  MAX_CODE=1
  SKIPPED=$((SKIPPED+1))
  # Do NOT append to manifest — the file was not written.
fi
```

Three guarantees this gives you:

1. **MAX_CODE=1** on any per-file failure — the overall run exit
   reflects the truth.
2. **Counter honesty** — `SKIPPED++` records the failure, no phantom
   `CREATED++`.
3. **Manifest integrity** — failed writes don't leak into the
   state file, so subsequent `update` runs won't treat a ghost
   entry as an existing install.

## Example

Root cause of the W2 `cmd_init` silent-clobber bug in feature
`20260418-per-project-install` (post-merge hotfix commit c621fef).
The initial implementation trusted the pipeline's exit implicitly;
the retry wrapped every write-arm in the `if … else FAIL+SKIP …` form
above.

### Relationship to the idempotent-exit pattern

An earlier symptom-fix attempt (the never-committed
`test-hash-exclude-state-files.md` proposal) tried to paper over the
visible symptom — "manifest hash drifts between otherwise-identical
runs" — by excluding the manifest from the hash baseline. That fix
addressed the measurement, not the cause. The real fixes were:

1. **This rule** — check pipeline exit before reporting success.
2. **Idempotent-exit short-circuit** — `cmd_init` and `cmd_migrate`
   bail out before the manifest rewrite + hook-wiring when nothing
   in the plan needs to change (plus a `[ -f manifest_path ]` guard
   so first-time writes still author the manifest).

Together these two fixes restored AC2.b byte-identity and made
test-hash measurements reliable. The hash-exclusion idea was
intentionally dropped as a symptom-fix — captured here as a
cross-reference so a future developer doesn't re-propose it.
