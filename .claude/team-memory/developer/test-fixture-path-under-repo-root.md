---
name: Test fixture paths must sit under REPO_ROOT, not /tmp
description: SANDBOX directories for test fixtures must live under $REPO_ROOT (e.g. `.test-<slug>.XXX`) so REPO_ROOT boundary guards accept them; mktemp -d under /tmp fails boundary checks.
type: feedback
created: 2026-04-20
updated: 2026-04-20
---

## Rule

When a CLI under test enforces a `$REPO_ROOT` path-boundary guard (canonical `cd dirname && pwd -P` + prefix assert), the test harness's SANDBOX must be created **under** `$REPO_ROOT`, not under `/tmp` or `/var/folders`. The conventional call is:

```bash
SANDBOX="$(mktemp -d "${REPO_ROOT}/.test-<slug>.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
```

Not:

```bash
SANDBOX="$(mktemp -d)"   # defaults to /tmp on macOS, /var on Linux
```

## Why

Observed in 20260420-tier-model W0a T3: the test `test/t75_tier_rollout_migrate.sh` built fixtures in `/tmp/tmp.XXXX`. The CLI under test (`scripts/tier-rollout-migrate.sh`) rejected every fixture path because its REPO_ROOT boundary guard — `[[ "$canonical" = "$REPO_ROOT"/* ]]` — returned false. Tests failed with "path outside repo" on every single assertion.

Orchestrator fix: move SANDBOX into `$REPO_ROOT/.test-t75.XXX`, add `.test-*` to `.gitignore`. All assertions then passed.

The root cause is a collision between two correct patterns:
- Shared bash rule `sandbox-home-in-tests.md` says "use `mktemp -d`" (which defaults outside the repo).
- Developer memory `envvar-file-path-boundary-check.md` says "CLI under test must boundary-check every input path against REPO_ROOT".

Both are correct; they compose if and only if the sandbox sits under REPO_ROOT. The test harness must handle the composition.

## How to apply

1. **Default the sandbox template to `${REPO_ROOT}/.test-<testname>.XXXXXX`** whenever the CLI under test enforces a REPO_ROOT boundary guard.
2. **Add `.test-*/` (or equivalent) to `.gitignore`** so test sandboxes don't pollute `git status`. Cross-reference the repo's existing gitignore pattern.
3. **Keep the `trap 'rm -rf "$SANDBOX"' EXIT`** — sandbox cleanup discipline is unchanged.
4. **Preflight assertion** (per `.claude/rules/bash/sandbox-home-in-tests.md`) must still run:
   ```
   case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac
   ```
5. **If the CLI does NOT enforce a boundary guard**, the /tmp-based mktemp is fine. This rule is a compose-with-boundary-guard discipline, not a universal override.

## Example

Bad:

```bash
SANDBOX="$(mktemp -d)"                    # /tmp/tmp.abc123
export HOME="$SANDBOX/home"
"$CLI" init "$SANDBOX/consumer"           # CLI rejects: path outside REPO_ROOT
```

Good:

```bash
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SANDBOX="$(mktemp -d "${REPO_ROOT}/.test-t75.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac
"$CLI" init "$SANDBOX/consumer"           # Accepted: path under REPO_ROOT
```

Cross-reference: `.claude/rules/bash/sandbox-home-in-tests.md` (base template), `developer/envvar-file-path-boundary-check.md` (boundary guard on the CLI side).
