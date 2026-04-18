---
name: Reviewer verdict wire format — pure-markdown key:value footer
description: Agent→orchestrator structured output uses a pure-markdown `key: value` footer, not a JSON codefence; grep-parseable, malformed = fail-loud, keeps agent prompts human-readable.
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Context

When an agent returns structured data to an orchestrator (reviewer
verdicts, classification results, gap lists), the wire format is a
design decision. The obvious choice — a JSON codefence at the end of
the message — adds a parse step, hides malformed output behind a
generic "JSON decode error", and makes the agent prompt harder to
read because the author has to mentally toggle between prose and JSON.

A flat `## Heading` section with one `key: value` pair per line is
greppable by the orchestrator, fails loud on any deviation (missing
key = missing grep match = obvious malformed verdict), and reads as
prose to the agent author. Lists indent one level under their parent
key, one item per line.

## Template

```markdown
## <Verdict-name>                      # e.g. "## Reviewer verdict"

axis: <axis-name>                      # one primitive per line
verdict: PASS | NITS | BLOCK
summary: <one-line human summary>

findings:                              # list header, items indented
  - severity: must
    file: path/to/file
    line: 42
    rule: rule-slug
    message: one-line message
  - severity: should
    file: path/to/other
    line: 7
    rule: rule-slug
    message: another one-line message
```

Parser pattern (orchestrator side):

```bash
# Grep the heading, then extract each field with grep -A N or awk
verdict=$(awk '/^## Reviewer verdict/{flag=1} flag && /^verdict:/ {print $2; exit}' "$output")
```

## When to use

- Agent → orchestrator structured output where the orchestrator
  dispatches many agents in parallel and reduces their outputs to a
  single decision (reviewers, classifiers, voters).
- Any contract that benefits from being readable in the agent's own
  prompt and in the captured transcript.

## When NOT to use

- Outputs with deeply nested structure (more than one level of list).
  Fall back to JSON for that case; the flat format loses legibility.
- Outputs that include unbounded free-text fields that may contain
  colons / list-marker characters — escape carefully or switch format.

## Why

- **Grep-parseable**: `awk '/^## X/,/^## /'` and `grep -A N '^key:'`
  are enough; no JSON dependency in the orchestrator.
- **Fail-loud**: malformed output (missing heading, missing field,
  unknown verdict value) is an obvious grep miss, not a silent parse
  success with default values.
- **Human-readable**: author the agent prompt as prose; the wire
  format *is* the prose.
- **Diff-friendly**: single-key-per-line means git diffs on captured
  transcripts show the exact field that changed.

## Example

The reviewer subagents in feature `review-capability` (B2.b) use this
shape. Each of `reviewer-security.md`, `reviewer-performance.md`,
`reviewer-style.md` ends with a `## Reviewer verdict` footer defined
by axis / verdict / summary / findings. The `/specflow:implement`
step-7 aggregator parses all 3N footers with `awk` and reduces per
task via the severity classifier (see
`architect/aggregator-as-classifier.md`).
