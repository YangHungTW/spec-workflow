# Request

**Raw ask**:

> bin/scaff-seed init/migrate should copy `.claude/settings.json` (the project-level SessionStart hook registration) into the consumer repo, so the LANG_CHAT marker and rule banner injection from `.claude/hooks/session-start.sh` actually fire. Right now consumer repos that scaff-seed sets up will have the hook script but no settings.json registering it, exactly the silent dogfood failure that 20260426-fix-commands-source-from-scaff-src archive retrospective surfaced. If the consumer already has .claude/settings.json, merge the SessionStart hook entry rather than clobber. plan_copy is the natural surface; the file should be copied alongside hooks/.

**Source**: dogfood retrospective from parent feature `20260426-fix-commands-source-from-scaff-src` (just archived).

**Context**:

The just-archived parent feature `20260426-fix-commands-source-from-scaff-src` (see `.specaffold/archive/20260426-fix-commands-source-from-scaff-src/`) surfaced a silent dogfood failure: the project's own `.claude/settings.json` was missing, so the SessionStart hook never fired, so the `LANG_CHAT=zh-TW` marker and the rule-banner injection produced by `.claude/hooks/session-start.sh` were never injected into the Claude Code session prompt. The fix in commit `0443f98` added project-level `.claude/settings.json` to specaffold itself, but did NOT propagate the same pattern to consumer repos seeded via `bin/scaff-seed`.

This chore is the propagation step: every new consumer that `scaff-seed init`/`migrate` sets up must ship with `.claude/settings.json` registering the SessionStart hook, otherwise consumers inherit the same silent failure mode the source repo just escaped.

The natural surface is `bin/scaff-seed`'s `plan_copy` enumerator (around lines 463-502 in current HEAD). For consumers that already have `.claude/settings.json` (e.g. they hand-added permissions or other hooks), the merge must be read-merge-write, not clobber, per the precedent in `bin/scaff-install-hook` (referenced from `.claude/rules/common/no-force-on-user-paths.md`).

**Success looks like**:

- `bin/scaff-seed init` on a fresh consumer repo produces a `.claude/settings.json` with the SessionStart hook entry pointing at `bash .claude/hooks/session-start.sh`.
- `bin/scaff-seed init` on a consumer with a pre-existing `.claude/settings.json` (containing unrelated keys, e.g. permissions) merges the SessionStart hook in without clobbering pre-existing content; a `.bak` is left behind per the no-force discipline.
- A regression test `test/t114_*.sh` exercises both fresh-install and merge paths and exits 0.

**Out of scope**:

- Changes to `.claude/hooks/session-start.sh` itself (already correct in source repo).
- Changes to the source repo's own `.claude/settings.json` (already in place from parent feature).
- Any new hook event beyond SessionStart.
- Changes to `update` mode (per existing `plan_copy` convention, `update` does not touch team-memory; settings.json is similarly user-mutable, so update should not refresh it).

**UI involved?**: no (chore, work-type=chore by construction).
