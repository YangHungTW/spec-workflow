## Test-authoring tasks must not add production code

A task scoped to "write tests for function X" must not also add function X to the
production library, even when the function is small and directly related.

### What happened

T25 (scope: write `test/t80_tier_proposal_heuristic.sh`) also added `propose_tier()`
and `_ask_contains()` to `bin/specflow-tier`. The reviewer correctly blocked this as
scope creep — the production implementation belongs to the task that owns the
production file, which is a separate future task (per pm.md T19 keyword-scan spec).
Adding production code in a test task also skips the red→green discipline: the test
was green on its first commit because the function it tested was in the same commit.

### Rule

When the test's `type propose_tier > /dev/null 2>&1` guard would trigger SKIP
because the function doesn't exist yet, that is the correct state for a test-only
task. Do not "fix" the SKIP by adding the production function — let the test SKIP
until the production task lands.

### How to identify scope creep at author time

Check whether any change touches a production file (under `bin/`) when the task's
`Files:` declaration lists only test files (under `test/`). If so, stop and raise
to TPM.

### Fix pattern

```bash
# Revert the library file to the pre-task state:
git checkout <base-sha> -- bin/specflow-tier

# Update the test guard to SKIP gracefully:
if ! type propose_tier > /dev/null 2>&1; then
  printf 'SKIP: propose_tier() not found — production code not yet authored; re-run post-wave.\n' >&2
  exit 0
fi
```

Remove any dead variable assignments (e.g. `SPECFLOW_TIER_LOADED=0`) that were
introduced alongside the scope-crept guard logic.
