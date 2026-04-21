## Rule

When a feature introduces two parallel renames that share a substring (e.g. brand `specflow → specaffold` AND binary prefix `specflow → scaff`), enumerate which substring rewrites to which target *per file class* before any sed runs, and review diffs specifically for the wrong-target typo class.

## Why

In the rename-to-specaffold feature (2026-04-21), two developer agents produced the same bug independently: T19 rewrote `bin/specflow-install-hook` → `bin/specaffold-install-hook` in rule files; T20 rewrote `bin/specflow-run` → `bin/specaffold-run` in `reviewer/security.md`. The canonical form per tech §D3 was `bin/scaff-*` (short binary prefix) — the brand rename was for product-name prose only. The typo survived acceptance checks because the grep AC (`specflow|spec-workflow` returns 0) was satisfied either way; the rewrites were internally consistent, just wrong-targeted.

## How to apply

1. Before editing, write down the substitution table explicitly as an ordered chain, longest-first:
   ```
   .claude/agents/specflow/      → .claude/agents/scaff/
   .claude/commands/specflow/    → .claude/commands/scaff/
   bin/specflow-                 → bin/scaff-
   /specflow:                    → /scaff:
   /specflow-                    → /scaff-
   .spec-workflow/               → .specaffold/
   spec-workflow                 → specaffold
   specflow                      → scaff
   ```
   The longer, more-specific patterns rewrite first; the bare `specflow → scaff` is a catch-all applied last.
2. Apply sed with the chain in this exact order so a shorter pattern doesn't clobber a longer one mid-rewrite.
3. After each file edit, run `grep -nE '<wrong-target-pattern>' <file>` — e.g. `grep -nE 'bin/specaffold-|/specaffold:|specaffold-<role>'` — to catch the wrong-target typo directly.
4. In the code-review step, explicitly eyeball any line that contains the longer-rename substring next to the short-rename prefix; that's the class the naive `s/brand/BRAND/g` mis-applies.

## Example

Corrective sed chain (BSD two-arg form per `.claude/rules/bash/bash-32-portability.md`):
```bash
sed -i '' \
  -e 's|\.claude/agents/specflow/|.claude/agents/scaff/|g' \
  -e 's|\.claude/commands/specflow/|.claude/commands/scaff/|g' \
  -e 's|bin/specflow-|bin/scaff-|g' \
  -e 's|/specflow:|/scaff:|g' \
  -e 's|/specflow-|/scaff-|g' \
  -e 's|\.spec-workflow/|.specaffold/|g' \
  -e 's|spec-workflow|specaffold|g' \
  -e 's|specflow|scaff|g' \
  "$file"
```
The order matters: if `s|specflow|scaff|g` ran first, `specflow-` contexts would become `scaff-` correctly, but `.claude/agents/specflow/` would become `.claude/agents/scaff/` before the more-specific directory rename could match — not wrong per se, but harder to reason about when a pattern-overlap bug appears.
