---
description: TPM archives a completed feature. Usage: /scaff:archive <slug> [--allow-unmerged REASON]
---

1. Require `08-validate.md` exists and its aggregate verdict is `PASS` or `NITS`. If the file is absent or its verdict is `BLOCK`, refuse and exit non-zero.
2. **Resolve tier and run merge-check** (skip to step 3 if `--allow-unmerged REASON` was supplied and REASON is non-empty):

   **Validate the slug and resolve `feature_dir`** (security: path traversal prevention):
   - Extract `<slug>` from `$ARGUMENTS` (the first non-flag word).
   - Reject invalid slugs immediately — print usage error to stderr and exit non-zero if the slug:
     - contains `..` (directory traversal),
     - contains `/` (path separator),
     - starts with `-` (leading dash, misinterpreted as flag).
   - Resolve `feature_dir` via `cd ... && pwd -P` and assert the resolved path begins with `$REPO_ROOT/.specaffold/features/`. If the boundary check fails, print an error and exit non-zero. Never pass an unvalidated slug to filesystem operations.
   ```bash
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   slug="$1"
   case "$slug" in
     *..* | */* ) printf 'ERROR: invalid slug — contains .. or /\n' >&2; exit 2 ;;
     -*)          printf 'ERROR: invalid slug — starts with -\n' >&2; exit 2 ;;
   esac
   feature_dir="$REPO_ROOT/.specaffold/features/$slug"
   canonical_dir="$(cd "$feature_dir" 2>/dev/null && pwd -P)" || {
     printf 'ERROR: feature dir not found: %s\n' "$feature_dir" >&2; exit 2
   }
   features_root="$REPO_ROOT/.specaffold/features"
   case "$canonical_dir" in
     "$features_root"/*) ;;
     *) printf 'ERROR: feature_dir escapes features root (boundary check failed)\n' >&2; exit 2 ;;
   esac
   ```

   Parse `$ARGUMENTS` for `--allow-unmerged`:
   - `--allow-unmerged` present but REASON (the word immediately after the flag) is absent or empty → print usage error to stderr and exit non-zero. Do NOT proceed.
   - `--allow-unmerged REASON` present with a non-empty REASON → validate REASON; record it; skip the merge-check gate below; append STATUS Notes line at end of step 2 and continue.

   **Validate REASON before appending** (security: single-line printable-ASCII only):
   - REASON must be a single line (no embedded newlines). Reject with a usage error if it contains `\n` or `\r`.
   - Pattern (bash):
     ```bash
     case "$reason" in
       *$'\n'* | *$'\r'*) printf 'ERROR: REASON must be single line\n' >&2; exit 2 ;;
     esac
     ```

   Resolve the feature's tier by sourcing `bin/scaff-tier` and calling `get_tier`:
   ```bash
   . "$REPO_ROOT/bin/scaff-tier"
   tier=$(get_tier "$feature_dir")
   ```

   Dispatch on tier:
   - `tier = malformed` → fail loud: print `"ERROR: tier field in STATUS.md is malformed — fix before archiving"` to stderr and exit non-zero. Leave feature unmodified.
   - `tier = tiny` → skip merge-check entirely; continue to step 3.
   - `tier = missing` → treat as tiny-equivalent (legacy feature pre-rollout per tech §1.4 forward constraint); skip merge-check; continue to step 3.
   - `tier ∈ {standard, audited}` → run the merge-check:
     ```bash
     branch=$(git rev-parse --abbrev-ref HEAD)
     if ! git merge-base --is-ancestor "$branch" main; then
       printf 'ERROR: branch %s has not been merged into main.\n' "$branch" >&2
       printf 'Merge or rebase onto main before archiving, or pass --allow-unmerged REASON.\n' >&2
       exit 1
     fi
     ```
     If `git merge-base --is-ancestor` returns non-zero → print the branch name, the `main` ref, and the diagnostic above; exit non-zero; leave feature unmodified.

   On `--allow-unmerged REASON` use: append the following STATUS Notes line using a **backup-then-temp-then-mv** atomic write pattern (security: no partial-write window, no data loss on interruption):
   ```bash
   status_md="$feature_dir/STATUS.md"
   status_bak="$feature_dir/STATUS.md.bak"
   status_tmp="$feature_dir/STATUS.md.tmp"
   cp "$status_md" "$status_bak"
   cp "$status_md" "$status_tmp"
   printf '%s archive — --allow-unmerged USED: %s\n' "$(date +%Y-%m-%d)" "$reason" >> "$status_tmp"
   mv "$status_tmp" "$status_md"
   ```
   The appended line format is:
   ```
   <date> archive — --allow-unmerged USED: <REASON>
   ```
   where `<date>` is today in `YYYY-MM-DD` format.

3. Invoke **scaff-tpm** subagent for archive mode.
4. **Retrospective** — TPM polls each role that participated (check STATUS for who ran which stage):
   - Ask each: "Anything from this feature worth saving to team memory?"
   - For each proposed lesson: user approves, picks scope (local/global) and type.
   - Write approved entries via the same protocol as `/scaff:remember`.
   - Skip roles that say "nothing new".
5. Check `[x] archive`, then `git mv .specaffold/features/<slug> .specaffold/archive/<slug>` (fall back to `mv` if not a git repo).
6. Report final archive path and any memory entries added.
