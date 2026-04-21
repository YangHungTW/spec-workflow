---
name: security
scope: reviewer
severity: must
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Flag findings against the security axis checklist; do not flag issues outside this axis.

## Why

A narrowly-scoped security rubric applied at diff review time catches the runtime-class bugs — hardcoded paths, path traversal, injection — that gap-check typically surfaces only after the full feature has landed. Reviewing at task-diff granularity bounds the blast radius: a `must` finding blocks only the offending task's wave merge, not the entire feature, so security debt is paid immediately rather than accumulating across waves.

## How to apply

Review the diff against exactly these 8 checks. For each finding, emit a structured entry per the output contract. Do not flag issues outside this axis.

1. **Hardcoded secrets or tokens** (`must`) — reject any commit that adds a literal secret, API key, token, or bearer string. Expected pattern: reads from environment variable, keychain, or secrets manager at runtime; no literal credential in source.

2. **Path traversal** (`must`) — any path join on user-supplied or external input must be resolved through an absolute-path resolver with a boundary check (the target must sit under an explicit allowed root). Relative traversal (`..`) without a boundary check is a `must` finding.

3. **Input validation at boundaries** (`must`) — untrusted input (CLI args, env vars, file contents from external sources) must be validated at the first point of entry into the call tree, not deep inside a helper. Missing validation at a boundary is a `must` finding.

4. **Injection attacks** (`must`) — no string-concatenation into a shell command or SQL statement. Parameterised queries and argv-form command invocation (`exec`, array-based subprocess calls) are required. Any string-built command that includes a variable is a `must` finding.

5. **Untrusted YAML / JSON parsing** (`should`) — parsing external YAML with a full loader (e.g. Python's `yaml.load` rather than `yaml.safe_load`) is a `should` finding. JSON parsers should be standard-library only. No eval-based parsing of external data.

6. **Secure defaults** (`must`) — any CLI that touches user-owned paths must default to non-destructive behaviour: no silent clobber, backup before mutate, atomic swap. Cross-reference: `.claude/rules/common/no-force-on-user-paths.md`. Do NOT restate that rule here; flag violations by pointing to it.

7. **Atomic file writes and backups** (`should`) — writes to user-owned paths should use write-temp-then-rename with a prior `.bak` backup before the rename. Non-atomic writes (write directly to the target path) are a `should` finding. Cross-reference: `.claude/rules/common/no-force-on-user-paths.md` (backup discipline) and `.claude/rules/common/classify-before-mutate.md` (reads-first, writes-second).

8. **Sentinel-file race conditions** (`should`) — check-then-write patterns on sentinel files (lock files, state markers) should use atomic creation primitives (`O_EXCL` flag, `set -C` noclobber, or equivalent) or an explicit mutex. A plain `-e` / `[ -f ]` check followed immediately by a write is a `should` finding.

## Example

The following diff snippet illustrates a `must` finding (string-built shell command — injection attack, check 4) and the expected verdict footer shape:

```diff
-  run_cmd "git diff ${BASE}...${BRANCH}"
+  git diff "${BASE}...${BRANCH}"
```

The first form passes an externally-influenced string to a shell-string interpreter; `${BASE}` or `${BRANCH}` could contain shell metacharacters. The second form invokes `git` directly with argv arguments — no injection surface.

**Verdict footer for this finding:**

```
## Reviewer verdict
axis: security
verdict: BLOCK
findings:
  - severity: must
    file: bin/scaff-run
    line: 42
    rule: injection-attacks
    message: String-built shell command includes variables BASE and BRANCH; use argv-form invocation instead.
```

The orchestrator's verdict parser (D2) treats any malformed footer — missing `## Reviewer verdict`, missing `verdict:` key, or verdict value outside `{PASS, NITS, BLOCK}` — as `BLOCK` per the fail-loud posture.
