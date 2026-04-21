## Rule

Any assertion script that searches for forbidden literals (a grep-negative guard) must add *itself* to its allow-list, and the self-entry must be documented in the script's header comment so a future maintainer doesn't "clean up" the entry.

## Why

`test/t_grep_allowlist.sh` in the rename-to-specaffold feature (2026-04-21) greps the tree for `specflow|spec-workflow` and fails if any file hits that pattern outside the allow-list. Its own source is the single richest concentration of those literals in the repo (the search pattern is literally `"specflow|spec-workflow"` in the code). Without self-allow-listing, the script always fails on its own body — a permanent false BLOCK that defeats the assertion's purpose.

## How to apply

1. When authoring a forbidden-string scanner, list the scanner's own path in its allow-list (or equivalent exemption file) from the outset — not as a later patch.
2. Document in the scanner's header comment *why* it self-references, e.g.:
   ```sh
   # SELF-ALLOW-LIST NOTE: this script's own source contains the forbidden
   # literals "specflow" / "spec-workflow" as grep search patterns; the
   # allow-list entry for `test/t_grep_allowlist.sh` is load-bearing and
   # must not be removed.
   ```
3. Prefer a non-literal representation (hex concat, base64, split-join) of search patterns when self-reference is avoidable, e.g. `needle="spec"; needle="$needle""flow"; grep "$needle"` — but be honest about the readability cost before doing this.
4. In the review step, treat a missing self-allow-list entry as a `must`-severity finding (the script cannot function without it).

## Cross-reference

Pair with the allow-list integrity discipline: the pattern of allow-listing a file *as a forward-promise before the file exists* is a separate hazard (see `qa-analyst/pre-allow-before-file-exists-is-a-silent-over-exemption.md`).
