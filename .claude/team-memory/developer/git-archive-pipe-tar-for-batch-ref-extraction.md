---
name: git archive | tar -xC for batch git-ref extraction
description: When a test must extract N≥10 files at a single git ref into a sandbox for diffing or content comparison, use `git archive <ref> -- <paths> | tar -xC <sandbox>` rather than per-file `git show <ref>:<path>` in a loop — one fork instead of N, no shell-string escaping, works on bash 3.2.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a test (or any non-hot-path script) must extract N ≥ 10 files at a single git ref into a sandbox directory for per-file diffing or content comparison, use:

```bash
git archive "$BASELINE_REF" -- <path1> <path2> ... | tar -xC "$BASELINE_DIR"
```

Not:

```bash
for f in <files>; do
  git show "$BASELINE_REF:$f" > "$BASELINE_DIR/$f"
done
```

The first form is one git fork + one tar fork = two subprocesses total. The second is N git invocations + N redirect-write operations + N intermediate path builds.

## Why

`test/t111_baseline_diff_shape.sh` (in `20260426-scaff-init-preflight` W4) needed to compare each of 18 `.claude/commands/scaff/*.md` files against their pre-W3 baseline content. The developer chose `git archive | tar -xC` to extract all 18 baseline files into a `mktemp -d` sandbox in a single git invocation. The reviewer-performance NITS that landed on T10's A1 loop (~145 forks for diff/sed/grep on the local files) reinforces that the loop body itself should be in-process (e.g. a single `awk`); but the baseline-extraction step was correctly batched.

Three reasons this beats the per-file loop:
1. **Performance**: one git fork instead of N, on a path that may run in CI or pre-commit. Even outside hot paths, batching is the default per `developer/batch-by-default-when-test-iterates-over-item-lists.md` for N ≥ ~10.
2. **Correctness with binary content**: `git show` writes to stdout with no encoding awareness; concatenating into a redirect can corrupt UTF-8 BOMs or binary blobs. `git archive` produces a tar stream that preserves byte-exact content.
3. **Bash 3.2 portability**: avoids the more complex `git cat-file --batch` byte-offset parsing that bash 3.2 makes painful. `git cat-file --batch` is faster (single persistent process for arbitrary lookups) and right for hook-budget paths (`developer/git-cat-file-batch-for-staged-file-scan.md`); `git archive | tar` is right for full-file extraction in tests.

## How to apply

1. **For tests that compare each of N files against a baseline ref**:
   ```bash
   BASELINE_DIR="$SANDBOX/baseline"
   mkdir -p "$BASELINE_DIR"
   git archive "$BASELINE_REF" -- "${PATHS[@]}" | tar -xC "$BASELINE_DIR"
   ```
   After this, every baseline file is present at `$BASELINE_DIR/<original-relative-path>`. Iterate the local checkout and `diff` / `cmp` against the sandbox copy.
2. **Resolving `BASELINE_REF`**: a robust pattern is to find the commit by message rather than position. The plan-time `git log --pretty=format:%H -- <file> | head -2 | tail -1` is brittle (other features may touch the same file later). Prefer:
   ```bash
   T6_COMMIT="$(git log --pretty=format:'%H %s' -- .claude/commands/scaff/archive.md \
     | grep -F 'T6: 18 .claude/commands/scaff/' \
     | head -1 \
     | awk '{print $1}')"
   BASELINE_REF="$T6_COMMIT^"
   ```
3. **Path argument quoting**: the `-- <paths>` argument uses argv form; quote each path explicitly to avoid glob expansion in the calling shell. Alternative: pass the directory itself (`-- .claude/commands/scaff/`) and let `tar -xC` recreate the tree.
4. **Cleanup**: the sandbox is `mktemp -d`-managed via the script's top-level `trap 'rm -rf "$SANDBOX"' EXIT`. No additional cleanup needed for the extracted tree.
5. **When to prefer `git cat-file --batch` instead**: hook-budget paths that need staged-file content lookup against many refs (cross-reference `developer/git-cat-file-batch-for-staged-file-scan.md`). When the test is a single-shot full-file extraction at one ref, `git archive | tar -xC` is simpler and equally fast.

## Example

`test/t111_baseline_diff_shape.sh` lines 95–110 (verbatim shape):

```bash
# Resolve T6 commit by message — robust against later commits touching the same files
T6_COMMIT="$(git log --pretty=format:'%H %s' -- .claude/commands/scaff/archive.md \
  | grep -F 'T6: 18 .claude/commands/scaff/' \
  | head -1 \
  | awk '{print $1}')"
[ -n "$T6_COMMIT" ] || { printf 'FAIL: cannot resolve T6 commit (message anchor)\n' >&2; exit 1; }

BASELINE_REF="$(git log --pretty=format:%H "${T6_COMMIT}^" -1)"
[ -n "$BASELINE_REF" ] || { printf 'FAIL: cannot resolve T6 parent\n' >&2; exit 1; }

# Batch-extract all 18 baseline files into the sandbox in ONE git invocation
BASELINE_DIR="$SANDBOX/baseline"
mkdir -p "$BASELINE_DIR"
git archive "$BASELINE_REF" -- .claude/commands/scaff/ | tar -xC "$BASELINE_DIR"

# Now iterate locally; no further git forks
for name in "${GATED[@]}"; do
  old="$BASELINE_DIR/.claude/commands/scaff/${name}.md"
  new=".claude/commands/scaff/${name}.md"
  diff "$old" "$new" > /dev/null && continue
  ...
done
```

The pattern is reusable for any test that needs per-file content from a fixed historical ref. Source: `20260426-scaff-init-preflight` T10 developer reply; pattern was self-discovered during T10 implementation.
