---
name: style
scope: reviewer
severity: should
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Flag findings against the style axis checklist; do not flag issues outside this axis.

## Why

Style drift accumulates silently across contributors: naming inconsistency, commented-out dead code, and portability regressions each lower readability and maintainability before any single change looks bad enough to reject. Reviewing style at the diff level — limited to the axis checklist below — surfaces these issues at wave merge time rather than at final gap-check, where they are more expensive to unwind.

## How to apply

1. **Match existing naming conventions in the file** (`should`) — new symbols, functions, and variables in an edited file must follow the naming convention of the surrounding code (snake_case vs camelCase, prefix conventions); drift from the file's established convention is a finding.

2. **No commented-out code** (`must`) — lines of commented-out code added by a commit as a future reference are a finding. Reviewers should not accept "I might need this later" as justification; git history preserves old versions.

3. **Comments explain WHY, not WHAT** (`should`) — a comment that merely restates what the next line does (e.g., `# increment counter`) is a finding; comments should explain rationale, constraints, or non-obvious decisions that cannot be inferred from the code itself.

4. **Match neighbour indent and quoting** (`should`) — inconsistency with the immediate file's indent style (tabs vs spaces, 2-space vs 4-space) or string-quote convention is a finding; do not introduce a new style in a file that has an established one.

5. **Bash 3.2 portability** (`must`) — when reviewing bash or shell files, cross-reference `.claude/rules/bash/bash-32-portability.md` and flag any violations (e.g., `readlink -f`, `realpath`, `mapfile`, `jq`, `[[ =~ ]]` for portability-critical logic, GNU-only `sed -i`) as `must` findings. Do not restate the portability rule body here.

6. **Sandbox-HOME in test scripts** (`must`) — when reviewing bash test scripts that invoke a CLI reading or writing under `$HOME`, cross-reference `.claude/rules/bash/sandbox-home-in-tests.md` and flag any missing sandbox, missing `trap`, or missing preflight assertion as a `must` finding. Do not restate the sandbox rule body here.

7. **`set -euo pipefail` convention** (`should`) — new bash scripts should match the strictness convention of neighbouring scripts in the same directory; do not introduce a looser error-handling mode in a directory where all existing scripts use `set -euo pipefail`. Avoid re-opening the debate when the surrounding context is already consistent.

8. **Dead imports / unused symbols** (`should`) — unused imports or declared-but-unread variables present in the diff are a finding; remove them rather than annotating them.

## Example

Diff excerpt with a `must`-severity style finding (commented-out code) and the expected verdict footer:

```diff
 classify_target() {
   local path="$1"
-  # old fallback:
-  # echo "unknown"
-  # return 1
   if [ ! -e "$path" ] && [ ! -L "$path" ]; then
     echo "missing"; return
   fi
 }
```

The three commented-out lines above are a `must` violation per entry 2 (no commented-out code). Expected reviewer output:

```
## Reviewer verdict
axis: style
verdict: BLOCK
findings:
  - severity: must
    file: bin/claude-symlink
    line: 14
    rule: reviewer-style
    message: Commented-out fallback block left in classify_target — remove or delete via git revert.
```

A diff that adds `readlink -f` in a bash script is also a `must` finding (entry 5), citing `.claude/rules/bash/bash-32-portability.md` rather than restating that rule's content.
