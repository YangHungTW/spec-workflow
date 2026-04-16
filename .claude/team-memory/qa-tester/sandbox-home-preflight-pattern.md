---
name: Sandbox-HOME preflight for bash CLI verify
description: When verifying a bash CLI that reads `$HOME`, always build a `mktemp -d` sandbox and export `HOME=<sandbox>/home` before the first invocation. Hash the tree before/after dry-run to confirm zero mutation.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Context

Any CLI that reads or writes under `$HOME` (config managers, symlink
installers, dotfile tools) is a landmine during verification: a single
forgotten `--dry-run` or an off-by-one path expansion will touch the
tester's real home directory. Logs scroll, real files get clobbered,
and the bug becomes un-reproducible because the tester's environment
is now polluted.

## Recipe

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Build sandbox
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# 2. Isolate HOME
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# 3. Preflight — fail loudly if isolation didn't take
[ "$HOME" = "$SANDBOX/home" ] || { echo "HOME not isolated" >&2; exit 2; }

# 4. Hash before
BEFORE="$(find "$SANDBOX" -ls | sort | shasum | awk '{print $1}')"

# 5. Run dry-run invocation(s)
"$SCRIPT" install --dry-run > /tmp/out
"$SCRIPT" update  --dry-run >> /tmp/out
"$SCRIPT" uninstall --dry-run >> /tmp/out

# 6. Hash after
AFTER="$(find "$SANDBOX" -ls | sort | shasum | awk '{print $1}')"

# 7. Assert equal
[ "$BEFORE" = "$AFTER" ] || { echo "dry-run mutated sandbox" >&2; exit 1; }
```

## Why

- **Catches real-HOME mutation bugs.** Preflight check + sandboxed
  `$HOME` means a botched path expansion fails at `step 3` with a
  clear message instead of silently writing to `~/.claude/…`.
- **Catches silent dry-run violations.** A hash-based before/after
  assertion finds writes that the CLI itself didn't report.
- **Reproducible.** `mktemp -d` + `trap rm` means every test run
  starts from the same empty state; nothing leaks between runs.

## When to use

- Any verify stage for a bash CLI that touches user config.
- Any symlink / dotfile / install-style tool.

## When NOT to use

- Pure-read tools (linters, reporters) — no mutation surface to
  guard.
- Tools that legitimately need to touch `$HOME` for a test (rare;
  then point `$HOME` at a sandbox subdir explicitly and verify
  inside it).

## Example

`test/smoke.sh` in feature `symlink-operation` (T11). The harness
uses this recipe for AC1–AC12; the preflight caught one iteration
where `$HOME` wasn't being re-exported in a sub-shell during test
setup.
