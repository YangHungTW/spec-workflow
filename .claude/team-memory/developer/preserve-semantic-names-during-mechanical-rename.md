## Rule

A mechanical rename (sed / find-replace) must distinguish semantic references (the old name is the *subject* being described) from incidental references (the old name is a variable, path, or binary reference). Semantic references are preserved verbatim and added to the assertion allow-list; only incidental references are rewritten.

## Why

A mechanical sed pass is textual; it cannot tell whether `foo` inside a file means "this file contains the string foo in prose" versus "this file IS the compat shim named foo and renaming it breaks the contract". T21d in the rename-to-specaffold feature (2026-04-21) caught this class of bug just in time: an aggressive `s/.spec-workflow/.specaffold/g` would have rewritten the literal string `.spec-workflow` inside `bin/scaff-seed`'s `ensure_compat_symlink` function — but `.spec-workflow` IS the compat-symlink name the function creates. The rewrite would have silently broken the R17/AC15 backwards-compat contract while the grep assertion reported zero violations.

## How to apply

1. Before running the sed pass, enumerate every file you will edit and mark each occurrence as `semantic` (subject) or `incidental` (variable/path/binary ref).
2. Rewrite only incidental occurrences. Keep semantic verbatim.
3. Add semantic-reference files to the grep-allow-list (`.claude/carryover-allowlist.txt` or equivalent) with a one-line comment citing *why* the legacy string must remain.
4. Where possible, structure the code so the legacy name is a single constant with a named origin (e.g. `LEGACY_COMPAT_LINK=".spec-workflow"`), so a future maintainer reading the allow-list entry can find the defining occurrence quickly.

## Example

T21d preserved `.spec-workflow` literals in:
- `bin/scaff-seed` (compat-symlink name, referenced in `classify_compat_symlink` + `ensure_compat_symlink`)
- `test/t_T25_ensure_compat_symlink.sh` (the test's subject is the compat symlink)

Both were added to `.claude/carryover-allowlist.txt` with `# file references .spec-workflow as compat-link name, not as legacy product ref` comments. A naive full-sweep rewrite would have passed the grep assertion by removing the literal strings while silently breaking the function.
