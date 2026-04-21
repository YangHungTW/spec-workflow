# Slug boundary check — path traversal prevention pattern

When a command or script builds a filesystem path from a user-supplied slug
(e.g. `feature_dir="$REPO_ROOT/.specaffold/features/$slug"`), apply the
two-layer boundary check or reviewers will block it as a path traversal finding:

**Layer 1 — character deny-list (fast fail before any filesystem access):**
```bash
case "$slug" in
  *..* | */* ) printf 'ERROR: invalid slug — contains .. or /\n' >&2; exit 2 ;;
  -*)          printf 'ERROR: invalid slug — starts with -\n' >&2; exit 2 ;;
esac
```

**Layer 2 — canonical resolve + prefix assert (catches symlink escapes):**
```bash
feature_dir="$REPO_ROOT/.specaffold/features/$slug"
canonical_dir="$(cd "$feature_dir" 2>/dev/null && pwd -P)" || {
  printf 'ERROR: feature dir not found: %s\n' "$feature_dir" >&2; exit 2
}
features_root="$REPO_ROOT/.specaffold/features"
case "$canonical_dir" in
  "$features_root"/*) ;;
  *) printf 'ERROR: feature_dir escapes features root\n' >&2; exit 2 ;;
esac
```

This uses `cd ... && pwd -P` (bash 3.2 / BSD portable) rather than `readlink -f`
or `realpath`. The `case` pattern in the canonical-resolve block is safe because
it runs in the outer shell, not inside a subshell (no bash32 case-in-subshell issue).

Source: T23 security BLOCK fix in feature `20260420-tier-model` (archive.md).
