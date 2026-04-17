---
name: Hook fail-safe pattern (SessionStart / Stop / PostToolUse)
description: Hooks that gate session or process lifecycle must `set +e`, trap signals to exit 0, emit diagnostics to stderr only, and never block startup. A hook that exits non-zero degrades every subsequent session with opaque cause.
type: pattern
created: 2026-04-17
updated: 2026-04-17
---

## Rule

Any hook that gates a session or process lifecycle event
(SessionStart, Stop, PostToolUse, PreToolUse, etc.) MUST be written
fail-safe: never block startup, never exit non-zero, never leak
diagnostics into stdout where the harness may parse it. If the
hook's purpose fails (missing dependency, missing input file, etc.),
degrade to a harmless no-op and log a stderr warning.

## Why

A hook that exits non-zero or hangs breaks every subsequent session
with an opaque symptom: "Claude Code is slow" / "the session didn't
start" / "my tools are disabled" — with no visible cause, because
the hook's failure is buried in a harness log the user rarely checks.
The blast radius of a broken hook is every future session until the
user notices and disables it.

The cost of the fail-safe discipline is negligible (a few lines at
the top of the script); the cost of a non-fail-safe hook is real
user pain and support load.

## How to apply

1. **`set +e`** (NOT `-e` or `-euo pipefail`). The hook must
   continue past command failures and degrade to no-op rather than
   abort mid-script.
2. **Early signal trap** — `trap 'exit 0' ERR INT TERM` near the
   top of the script. Even if a command errors or the user
   interrupts, the hook exits cleanly.
3. **Stderr-only diagnostics** — all `echo` / `printf` for
   warnings or info go to `>&2`. Stdout is reserved for the
   structured hook payload (JSON or similar) that the harness
   parses. Mixing diagnostics into stdout corrupts the payload.
4. **Degrade, don't fail** — if the hook's purpose can't be
   fulfilled (rules dir missing, settings file absent, etc.), emit
   an empty-context JSON or the harness's documented "no-op" shape
   on stdout, log a WARN to stderr, and continue to step 6.
5. **Empty / harmless default payload** — the fall-through case
   must still emit valid hook output so the harness doesn't
   interpret the hook as broken.
6. **Unconditional final `exit 0`** — the last line of the script.
   Belt and suspenders with the trap.
7. **Dry-run / test mode** — gate real hook emission behind an
   env var (e.g. `HOOK_TEST=1` prints to stdout without emitting
   harness JSON). This makes the hook trivially testable from a
   plain shell without spinning up Claude Code.

## Example

`.claude/hooks/session-start.sh` from feature
`20260416-prompt-rules-surgery` (decisions D1, D5, D7):

```bash
#!/usr/bin/env bash
# SessionStart hook — inject .claude/rules/ digest into the prompt.
# Fail-safe: any error degrades to empty context; never blocks startup.
set +e
trap 'exit 0' ERR INT TERM

RULES_DIR="$(cd "$(dirname "$0")/../rules" 2>/dev/null && pwd -P)"

if [ ! -d "$RULES_DIR" ]; then
  echo "WARN: rules dir missing at $RULES_DIR — emitting empty digest" >&2
  printf '{"additionalContext":""}\n'
  exit 0
fi

# Build digest (elided) — if this fails, the trap catches it
DIGEST=$(build_digest "$RULES_DIR") || DIGEST=""

# Test-mode short-circuit for plain-shell smoke tests
if [ "${HOOK_TEST:-0}" = "1" ]; then
  printf '%s\n' "$DIGEST"
  exit 0
fi

# Normal path — emit harness JSON
python3 -c '
import json, sys
print(json.dumps({"additionalContext": sys.stdin.read()}))
' <<< "$DIGEST"

exit 0
```

B2 (deferred sibling feature) will apply this same pattern to Stop
and PostToolUse hooks. Any hook added later must follow this shape
or be explicitly justified in the tech doc.

Cross-reference: `.claude/rules/bash/bash-32-portability.md` — the
hook must also be bash 3.2 compatible because macOS ships
`/bin/bash` 3.2 and the harness often invokes hooks with that
interpreter.
