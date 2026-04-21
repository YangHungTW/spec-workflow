---
name: absolute-symlink-targets
scope: common
severity: should
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Always pass an absolute path as the symlink target when creating symlinks; never use a relative path as the link source.

## Why

Relative symlink targets are resolved relative to the directory containing the link, not the working directory at creation time. If the link is later moved to a different directory, the relative target silently points to a wrong or missing path. Absolute targets make every `ls -l` immediately diagnosable and survive any rearrangement of the link's location. (Source: symlink-operation PRD R3.)

## How to apply

1. Before calling `ln -s`, resolve the source to an absolute path. Use the repo-root-relative pattern `abs_src="$REPO_ROOT/$rel_src"` or the BSD-safe loop:
   ```bash
   abs_src="$target_file"
   while [ -L "$abs_src" ]; do abs_src=$(readlink "$abs_src"); done
   ```
2. Always call `ln` in the form `ln -s "$abs_src" "$tgt"` — never `ln -s "../relative/path" "$tgt"`.
3. After creation, verify with `readlink "$tgt"` and assert the result starts with `/`.
4. Document in user-facing output: if the repo is moved, managed links must be refreshed (`update` / `install`) because the absolute targets will no longer resolve.

## Example

The `bin/claude-symlink` convention from the `symlink-operation` feature:

```bash
# Resolve repo root as the absolute parent of the script's own directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build absolute source path
abs_src="$REPO_ROOT/.claude/agents/scaff"

# Create the symlink with an absolute target — never relative
ln -s "$abs_src" "$HOME/.claude/agents/scaff"

# Verification
readlink "$HOME/.claude/agents/scaff"
# → /Users/alice/tools/specaffold/.claude/agents/scaff
```

If the repo later moves to `/Users/alice/work/specaffold/`, the link becomes broken. Running `bin/claude-symlink install` again rebuilds it with the new absolute path — the correct recovery documented in symlink-operation PRD §6 ("Repo moved after install").
