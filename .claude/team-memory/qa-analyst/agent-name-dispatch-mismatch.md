---
name: agent-name-dispatch-mismatch
role: qa-analyst
type: feedback
created: 2026-04-18
updated: 2026-04-18
---

## Rule

During gap-check, grep every new `.claude/agents/scaff/*.md`
agent file's `name:` frontmatter value against every command-file
dispatch identifier that references it. Any mismatch — prefix drift,
typo, stale rename — is a silent-BLOCK bug: the agent is
unfindable at runtime, the gate it protects fails closed, and the
orchestrator surfaces the closed gate as a legitimate BLOCK.

## Why

Claude Code resolves subagents by the `name:` YAML frontmatter
field, not the filename. A command file that invokes
`Agent(subagent_type=foo)` matches against `name: foo` in some agent
file. If the agent file has `name: prefix-foo` (prefix drift is
common after rename refactors or when an author mirrors `filename`
stem without checking), the dispatch silently fails to find the
agent.

Worse: the orchestrator observes the dispatch fail and interprets
the failure as the agent's own decision — the gate (review, verify,
classify) "returned BLOCK". The user sees what looks like a
legitimate halt and has no signal that the infrastructure itself is
broken. This failure mode is indistinguishable from "the reviewer
actually found a must-severity issue" until someone reads the agent
file by hand.

## How to apply

During gap-check, for every new or renamed agent file under
`.claude/agents/scaff/`:

1. Extract the `name:` value from YAML frontmatter:
   ```bash
   grep -E '^name:' .claude/agents/scaff/<file>.md | awk '{print $2}'
   ```
2. Grep every command file under `.claude/commands/scaff/` for
   any string that looks like a dispatch reference to this agent —
   including variants with and without a common prefix (`reviewer-`,
   `scaff-`, etc.):
   ```bash
   grep -rn "<name-value>\|<bare-name>\|<prefixed-name>" \
     .claude/commands/scaff/
   ```
3. For each match, read the surrounding context (the Agent tool
   call, the subagent_type= argument, the invocation list). Assert
   the string literal matches `name:` exactly — no prefix drift,
   no typo, no case mismatch.
4. Flag as a **blocker** in `07-gaps.md` if mismatch is found. The
   feature will silently fail on first dispatch; the gate it
   protects will not fire; downstream stages will misinterpret the
   failure.
5. Also grep for the agent's filename stem. If the command file
   dispatches by the filename stem but the agent's `name:` differs,
   same bug shape.

## Example

Feature `review-capability` (B2.b). D1 gap-check finding:
- `reviewer-performance.md` frontmatter: `name: scaff-reviewer-performance`
- `implement.md` step 7: `Agent(subagent_type=reviewer-performance)`
- Result: dispatch fails silently; reviewer gate appears to return
  BLOCK on every wave.

Same issue on `reviewer-style.md`. Caught at gap-check via the grep
above, fixed before archive (frontmatter updated to
`name: reviewer-performance` / `name: reviewer-style` to match
filename stem and match the dispatch identifier in `implement.md`).

Related: rule schema (`.claude/rules/README.md`) already requires
`name:` to match filename stem; see also
`tpm/briefing-contradicts-schema.md` for the upstream paraphrase-not-
quote root cause.
