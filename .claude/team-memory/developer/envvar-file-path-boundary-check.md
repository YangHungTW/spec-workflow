# Env-var file path boundary check — security input-validation pattern

When a test or script accepts env-var overrides for file paths
(e.g. `IMPL="${IMPL:-$REPO_ROOT/...}"`), reviewers will block missing boundary
checks as a security `must` finding (input-validation-at-boundaries).

Apply this pattern after default assignment for each such env var:

```bash
# Helper: canonicalise a file path via cd+dirname+pwd-P (BSD-safe, no readlink -f).
# Falls back to raw value if parent directory does not yet exist (pre-wave artefact).
_resolve_file_path() {
  local p="$1" dir base resolved_dir
  dir="$(dirname "$p")"
  base="$(basename "$p")"
  if resolved_dir="$(cd "$dir" 2>/dev/null && pwd -P)"; then
    printf '%s/%s\n' "$resolved_dir" "$base"
  else
    printf '%s\n' "$p"   # parent absent — sub-test will SKIP on [ ! -f ]
  fi
}

IMPL="$(_resolve_file_path "$IMPL")"
if [ "${IMPL#$REPO_ROOT/}" = "$IMPL" ]; then
  printf 'ERROR: IMPL must be under %s (got: %s)\n' "$REPO_ROOT" "$IMPL" >&2
  exit 2
fi
```

For executable paths (scripts that will be invoked), additionally assert:
```bash
if [ -e "$AGG" ] && [ ! -x "$AGG" ]; then
  printf 'ERROR: AGG is not executable: %s\n' "$AGG" >&2; exit 2
fi
```

Key points:
- Use `${var#$REPO_ROOT/}` prefix-strip test (not `case "$var" in "$REPO_ROOT"/*`) —
  the `case` form inside a subshell can parse-error on bash 3.2.
- Fall back to raw value (not exit 2) when parent dir is absent; the sub-test itself
  will SKIP on `[ ! -f "$path" ]` — the boundary check still fires on whatever
  value is presented.
- Applies to test scripts that accept env-var overrides to point at pre-merge artefacts.

Source: T29 security BLOCK retry in feature `20260420-tier-model`.
