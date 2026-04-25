---
name: --no-verify discipline when a feature ships its own pre-commit hook
description: When wave N wires a pre-commit hook before wave N+1 lands the data the hook checks for, every commit between those waves — including orchestrator bookkeeping AND developer commits in N+1 that pre-date the marker-bearing files — must use `git commit --no-verify` AND log the bypass to STATUS Notes; the plan must enumerate every bypass site explicitly before W_N starts.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a feature wires a pre-commit hook in wave N, then lands the data the hook checks for in wave N+1, every commit that lands between those two waves must use `git commit --no-verify`. The plan-narrative section must enumerate every such bypass site BEFORE W_N starts — not just the orchestrator's bookkeeping commit, but also any developer commit in W_{N+1} whose worktree branch does not yet carry the marker-bearing files. STATUS Notes must log every `--no-verify` use per the dogfood-paradox / opt-out-bypass-trace contract (`architect/opt-out-bypass-trace-required.md`).

## Why

The W2 pre-commit hook wiring on `20260426-scaff-init-preflight` made the local `.git/hooks/pre-commit` start invoking `bin/scaff-lint preflight-coverage`, which exits 1 until W3's markers land. Two commit sites hit this between W2 and W3 close:

1. The orchestrator's W2 bookkeeping commit (check off T4/T5; STATUS Notes; commit).
2. The developer's W3 T7 commit on the parallel `<slug>-T7` worktree branch — markers were on T6's worktree branch, not T7's, so T7's working tree had zero markers when the hook fired.

The plan §1.4 noted bypass site (1) explicitly. The plan did NOT enumerate site (2) — the T7 developer discovered it at commit time and used `--no-verify` correctly, but only logged it in their reply, not in STATUS Notes. The qa-analyst caught the missing STATUS Note at validate as an advisory finding.

The pattern generalises to any feature where the enforcement layer ships before its satisfier — common shape for self-shipping mechanisms (lint conventions, hook conventions, schema gates). Without the plan-time enumeration, each occurrence costs (a) one developer-time discovery + (b) one analyst-time finding at validate.

## How to apply

1. **At plan time**, when sequencing waves for a self-enforcing feature, identify every commit site that will fire between the wave that wires the enforcement (W_N) and the wave that satisfies it (W_{N+1}). Enumerate at minimum:
   - The orchestrator's W_N bookkeeping commit (always).
   - Every developer commit in W_{N+1} whose worktree branch does NOT yet carry the satisfying data — typically EVERY task in W_{N+1} except the one that produces the data itself.
2. **In the §Wave plan section**, write a sub-bullet under W_N close that says:
   > "The local pre-commit hook starts firing from W_N close. Until W_{N+1}'s data lands, the following commit sites MUST use `--no-verify`: (a) orchestrator W_N bookkeeping; (b) all W_{N+1} developer commits except T<n> (the producer task)."
3. **In each affected developer task's Scope/Verify section**, add a verbatim note: `Pre-commit hook will block your commit (markers not in this branch yet); use `--no-verify` and log in your reply.`
4. **At wave-merge time**, the orchestrator MUST append a STATUS Notes line for every `--no-verify` site:
   ```
   YYYY-MM-DD implement — --no-verify USED for <site> (reason: enforcement layer ships before satisfier; expected per plan §1.4)
   ```
   One line per site; both orchestrator and developer sites get logged.
5. **At validate**, the qa-analyst should grep the wave's commits for `--no-verify` traces (`git log --pretty=format:%B | grep -B5 'no-verify'` or check the hook's `$GIT_REFLOG` if available) and assert every bypass has a matching STATUS Notes line. A bypass without a STATUS Notes line is a `should`-class finding (silent audit hole).

## Example

The plan §1.4 dogfood-paradox sub-section on `20260426-scaff-init-preflight` correctly identified bypass site (1) but not (2):

```markdown
### 1.4 Dogfood paradox sequencing (eleventh occurrence)

> Sequencing rule applied: land the gate body and the lint **first** (W1),
> then the pre-commit hook (W2), then the markers (W3) **last**.

The orchestrator's W2 bookkeeping commit MUST use `git commit --no-verify`
because the lint will fail until W3's markers land. STATUS Notes must log
this bypass.
```

After this lesson lands, the same section should also say:

```markdown
Additionally: every developer commit in W3 EXCEPT T6 (the marker-producer)
will hit the new hook and need `--no-verify`. T7 is the only such site in
this feature; document in T7 Scope as well.
```

The next analogous feature (lint + pre-commit + N markers) ports this directly: substitute the marker count and the producer task ID. Cross-references: `shared/dogfood-paradox-third-occurrence.md` (the umbrella pattern), `architect/opt-out-bypass-trace-required.md` (the trace requirement), `architect/by-construction-coverage-via-lint-anchor.md` (the four-layer shape that creates the bypass need).
