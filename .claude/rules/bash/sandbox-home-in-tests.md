---
name: sandbox-home-in-tests
scope: bash
severity: must
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Every bash test or verify script that invokes a CLI which reads or writes under
`$HOME` must create a `mktemp -d` sandbox, point `HOME` at a subdir of it, and
assert that `$HOME` starts with the sandbox path before any mutation runs.

## Why

A CLI that expands `$HOME` without a sandbox will silently mutate the tester's
real home directory on any mistake — a misquoted variable, a missing
`--dry-run`, or an off-by-one path join. The damage is immediate, silent, and
hard to reproduce because the environment is now polluted. A sandboxed `$HOME`
with an upfront preflight check turns this class of bug into a loud, immediate
failure at assertion time instead of a silent write to `~/.claude/` or `~/.config/`.

## How to apply

1. At the top of every test script, call `mktemp -d` and store the result in
   `SANDBOX`.
2. Export `HOME="$SANDBOX/home"` and `mkdir -p "$HOME"`.
3. Register `trap 'rm -rf "$SANDBOX"' EXIT` immediately after creating the
   sandbox.
4. Before the first invocation of the CLI under test, assert
   `[[ "$HOME" == "$SANDBOX"* ]]` (or the POSIX equivalent using `case`). If the
   assertion fails, emit an error to stderr and `exit 2`. Never proceed against
   real `$HOME`.
5. Never skip the preflight even for scripts that appear read-only — the rule
   is a template discipline; carrying it uniformly makes audits trivial.

## Example

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Build sandbox
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# 2. Isolate HOME
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# 3. Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# 4. Run the CLI under test
"$SCRIPT" install --dry-run > /tmp/out

# 5. Optionally hash-verify no mutation occurred
BEFORE="$(find "$SANDBOX" -ls | sort | shasum | awk '{print $1}')"
"$SCRIPT" install --dry-run >> /tmp/out
AFTER="$(find "$SANDBOX" -ls | sort | shasum | awk '{print $1}')"
[ "$BEFORE" = "$AFTER" ] || { echo "FAIL: dry-run mutated sandbox" >&2; exit 1; }

echo "PASS"
```

Source pattern: `test/smoke.sh` in feature `symlink-operation` (T11).
The harness uses this recipe for AC1–AC12; the preflight caught one
iteration where `$HOME` wasn't being re-exported in a sub-shell during
test setup.
