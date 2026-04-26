## Summary

Teach `bin/scaff-seed` (init and migrate modes) to land `.claude/settings.json` in the consumer repo so the SessionStart hook actually registers, merging into any pre-existing settings.json rather than clobbering it.

## Scope

- **File-copy surface**: `bin/scaff-seed`'s `plan_copy` enumerator (around lines 463-502 in current HEAD; verify at draft time with `grep -n 'plan_copy' bin/scaff-seed`).
- **Source path** (in source repo): `.claude/settings.json`.
- **Destination path** (in consumer repo): `.claude/settings.json` (same relative path).
- **Modes affected**: `init` and `migrate` (consumer-onboarding paths). `update` mode does not touch settings.json — consistent with the existing rule that `update` skips team-memory and other user-mutable files.
- **Merge behaviour**: if consumer's `.claude/settings.json` already exists, read → merge the SessionStart hook entry into the existing JSON → write atomically (`.tmp` + `os.replace`) with a prior `.bak` of the original. New seed (no existing file): write fresh. The read-merge-write pattern in `bin/scaff-install-hook` (referenced by `.claude/rules/common/no-force-on-user-paths.md`) is the precedent.

## Reason

Tooling breakage / dogfood-failure propagation. Without this chore, every new consumer seeded by `scaff-seed` inherits the same silent SessionStart-hook-not-firing bug that `20260426-fix-commands-source-from-scaff-src` surfaced in the source repo itself: the hook script lands but is never registered with Claude Code, so `LANG_CHAT=zh-TW` and the rule-banner injection produced by `.claude/hooks/session-start.sh` are never seen by the session — silent, not loud.

## Checklist

- [ ] `bin/scaff-seed` `plan_copy` enumerates `.claude/settings.json` for `init` and `migrate` modes — verify: `grep -F '.claude/settings.json' bin/scaff-seed` returns the plan_copy entry (or the equivalent dispatcher line that emits the relpath for the two modes).
- [ ] `scaff-seed init` on a fresh consumer creates `.claude/settings.json` with the SessionStart hook entry — verify: a sandbox test (sandboxed `$HOME` and a `mktemp -d` consumer root) asserts the file exists post-init and contains a `hooks.SessionStart[*].hooks[*].command` value referencing `.claude/hooks/session-start.sh`.
- [ ] `scaff-seed init` merges the SessionStart hook into a consumer's pre-existing `.claude/settings.json` without clobbering unrelated keys — verify: a sandbox test pre-creates `$CONSUMER/.claude/settings.json` containing an unrelated permission rule (no hooks block), runs init, asserts both the pre-existing permission rule AND the SessionStart hook command are present in the post-init file, and asserts a `.claude/settings.json.bak` exists with the original content.
- [ ] regression test `t114_*.sh` (next free t-counter; verify by `ls test/t1*.sh | sort | tail -5` showing t113 as the highest existing) covers both fresh-install and merge paths — verify: `bash test/t114_*.sh` exits 0.

## Verify assertions

Rolled-up commands a reviewer can run against a green build:

```
grep -F '.claude/settings.json' bin/scaff-seed
ls test/t1*.sh | sort | tail -5      # t114_*.sh present, t113 was previous max
bash test/t114_*.sh                    # exits 0
```

The t114 test itself owns the deeper assertions (fresh-install file shape; merge preserves pre-existing keys; `.bak` written on merge path).

## Out-of-scope

- Source-repo `.claude/settings.json` content (already correct from parent feature `20260426-fix-commands-source-from-scaff-src`).
- The `.claude/hooks/session-start.sh` script itself.
- Adding any new hook event beyond SessionStart.
- `update` mode behaviour for settings.json (out-of-scope by parity with team-memory: user-mutable file, `update` does not refresh it).
- A general-purpose JSON-merge utility extracted as a helper — only the SessionStart-hook-entry merge is required; defer abstraction until a fourth occurrence per `.claude/rules/common/minimal-diff.md` entry 2.
