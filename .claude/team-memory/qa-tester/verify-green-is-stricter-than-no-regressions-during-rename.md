## Rule

For rename / refactor features where the test suite has known pre-existing failures, a strict "green = zero-failures" verdict produces avoidable NITS cycles. Prefer a harness that records the baseline failure count on the target branch and fails only if the feature branch strictly worsens it.

## Why

Rename features are mechanical string substitutions — they should not introduce new test failures. But if the target branch (`main`) already has failing tests — e.g. pre-existing test-env or mocking issues — a strict "all tests green" gate will always fail for a rename feature, forcing the developer to manually diff failure lists against baseline to argue "these 11 failures are pre-existing, not regressions."

This ceremony has a cost in turns. A harness that encodes "no regressions vs baseline" directly would PASS on evidence rather than require manual argument. It would also catch the converse case: a feature that happens to fix some pre-existing failures doesn't distort its own gate verdict.

This rule is complementary to `qa-analyst/developer-preexisting-claim-must-be-git-verified.md`: that rule is about verifying claimed pre-existing failures; this rule is about structuring the harness so the claim is mechanically enforced.

## How to apply

1. When authoring a test gate (e.g. T15 vitest gate, T8 cargo-test gate) for a rename feature, consider adding a baseline-comparison step instead of absolute-green:
   ```bash
   # Compute baseline failures (once, cached)
   baseline=$(git stash && git checkout main && npm test --silent 2>&1 | grep -c 'FAIL') || baseline=0
   git checkout -
   actual=$(npm test --silent 2>&1 | grep -c 'FAIL')
   [ "$actual" -le "$baseline" ] || { echo "REGRESSION: $actual > baseline $baseline"; exit 1; }
   ```
2. If the harness already runs absolute-green, record the baseline failure count in PRD §9 or tech §testing-strategy at feature-start time so the verify-stage reviewer has an explicit anchor.
3. When documenting a NITS caveat on a pre-existing failure, cite the baseline evidence in the STATUS Notes line, not in a retrospective-afterthought: `2026-04-22 Developer — T15 vitest: 11 failures (baseline 11); 5 fewer failing files than main; 0 regressions`.
4. Treat "absolute-green gate on rename feature" as a code-smell to surface at plan time — if the repo has a baseline of non-green tests, the gate should be baseline-relative from the start.

## Example

`20260421-rename-flow-monitor` T15 vitest gate surfaced 11 failing tests. Investigation (checkout `main`, re-run vitest) confirmed the same 11 failures existed pre-feature — all Tauri `@tauri-apps/api/core` mocking issues in non-rename-related test files. The feature branch actually improved the baseline: 6 failing files vs 11 on main (5 files moved from fail to pass as a side-effect of T12's TSX test updates).

The strict "all-green" gate forced a NITS verdict with explicit user acceptance. A baseline-relative gate would have returned clean PASS on the evidence. Noted at validate tester axis: AC7 NITS with rationale "pre-existing Tauri test-env failures, not rename regressions".
