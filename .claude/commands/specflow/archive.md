---
description: TPM archives a completed feature. Usage: /specflow:archive <slug> [--allow-unmerged REASON]
---

1. Require `08-verify.md` verdict = PASS.
2. **Resolve tier and run merge-check** (skip to step 3 if `--allow-unmerged REASON` was supplied and REASON is non-empty):

   Parse `$ARGUMENTS` for `--allow-unmerged`:
   - `--allow-unmerged` present but REASON (the word immediately after the flag) is absent or empty → print usage error to stderr and exit non-zero. Do NOT proceed.
   - `--allow-unmerged REASON` present with a non-empty REASON → record the reason; skip the merge-check gate below; append STATUS Notes line at end of step 2 and continue.

   Resolve the feature's tier by sourcing `bin/specflow-tier` and calling `get_tier`:
   ```bash
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   . "$REPO_ROOT/bin/specflow-tier"
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

   On `--allow-unmerged REASON` use: append the following STATUS Notes line (after the existing notes):
   ```
   <date> archive — --allow-unmerged USED: <REASON>
   ```
   where `<date>` is today in `YYYY-MM-DD` format.

3. Invoke **specflow-tpm** subagent for archive mode.
4. **Retrospective** — TPM polls each role that participated (check STATUS for who ran which stage):
   - Ask each: "Anything from this feature worth saving to team memory?"
   - For each proposed lesson: user approves, picks scope (local/global) and type.
   - Write approved entries via the same protocol as `/specflow:remember`.
   - Skip roles that say "nothing new".
5. Check `[x] archive`, then `git mv .spec-workflow/features/<slug> .spec-workflow/archive/<slug>` (fall back to `mv` if not a git repo).
6. Report final archive path and any memory entries added.
