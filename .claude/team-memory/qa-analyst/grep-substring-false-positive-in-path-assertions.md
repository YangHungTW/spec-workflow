---
name: grep substring false-positive in path assertions
description: When a path assertion uses bare `grep '\.claude/...'` against text that may contain either bare or `~/`-prefixed forms, the bare grep matches the `~/`-prefixed form because `.claude/` is a substring of `~/.claude/`; the test passes for the wrong reason. Anchor with `-E '(^|[^~])\.claude/'` or assert full-string equality.
type: pattern
created: 2026-04-27
updated: 2026-04-27
---

## Context

Tests that assert "the post-migration command string contains `.claude/hooks/<file>`" are vulnerable to a substring-coincidence false-positive when the same file historically also wrote `~/.claude/hooks/<file>`. The bare-form pattern `\.claude/hooks/<file>` matches inside the `~/`-prefixed string at offset 1, so a test that READ the OLD pre-migration file (instead of the new post-migration file) still passes the grep — the assertion is structurally correct but semantically tautological.

This pattern bit `test/t45_migrate_from_global.sh` line 213 during `20260426-fix-install-hook-wrong-path` validate. The test's post-migrate assertion read `CONSUMER/settings.json` (the old root-level file, untouched per D3 because the bug fix changed the helper's default to `.claude/settings.json`) and grepped for `\.claude/hooks/session-start\.sh`. The OLD file's content was `~/.claude/hooks/session-start.sh` — the grep matched, the test passed, but the test never verified what AC4 actually requires (that hooks land in the NEW `.claude/settings.json`, not at the old root).

## Template

```bash
# Bad — ~/.claude/foo also matches:
grep -F '.claude/hooks/session-start.sh' "$file"

# Bad — same; -F is fixed-string but still substring:
grep -E '\.claude/hooks/session-start\.sh' "$file"

# Good — anchored with negative lookbehind via "not preceded by ~":
grep -E '(^|[^~])\.claude/hooks/session-start\.sh' "$file"

# Better — assert the WHOLE string the JSON should contain:
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
cmd = d["hooks"]["SessionStart"][0]["hooks"][0]["command"]
sys.exit(0 if cmd == "bash .claude/hooks/session-start.sh" else 1)
' "$file"
```

The Python form is the gold standard when the file is JSON: it extracts the exact field and compares the whole string, eliminating both the substring class of bug AND any future ambiguity about prefix variants.

## When to use

- Any path assertion in a test that may run against history with both bare and `~/`-prefixed forms (Claude Code config evolution is a recurring example).
- Migration tests that compare pre-migration content to post-migration content, where the migration adds or removes a leading prefix.
- JSON command-string assertions where the field is a known shape and the test can extract-and-compare exactly.

## When NOT to use

If the field genuinely is free-text and substring-matching is the actual intent (e.g. log line scanning), the bare grep is fine. The rule applies specifically to *path assertions* where the prefix carries semantic meaning.

## Cross-reference

`qa-analyst/partial-wiring-trace-every-entry-point.md` — adjacent: this memory is about HOW to assert at each entry point; that one is about WHICH entry points to cover. Together they catch the failure mode "every entry point has an assertion, but the assertion is tautological".

## Source

`20260426-fix-install-hook-wrong-path` validate (qa-analyst Finding F3): `test/t45_migrate_from_global.sh:212-215` reads the wrong file post-migrate and the grep passes only because of the substring coincidence. Recommended follow-up chore in `08-validate.md` of that feature.
