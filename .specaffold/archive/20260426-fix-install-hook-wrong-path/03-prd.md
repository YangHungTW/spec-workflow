## Problem

`scaff-seed init` Step 10 invokes `bin/scaff-install-hook add SessionStart …` and `add Stop …` from the consumer project root to wire Claude Code session/stop hooks. The helper hardcodes its target as the bare filename `settings.json` (see `bin/scaff-install-hook` lines 66 and 109), so it reads/writes `<consumer>/settings.json` at the project root rather than `<consumer>/.claude/settings.json` — the only settings file Claude Code actually loads. Step 7's earlier Python merge already wrote `<consumer>/.claude/settings.json` correctly for `SessionStart`, so post-init the consumer ends up with two divergent settings files: the real one (SessionStart only) and a stray root-level one (SessionStart + Stop) plus a `settings.json.bak` snapshot. The Stop hook is therefore never delivered to Claude Code, and the consumer root is polluted with two orphan files.

## Source

**Source**:
- type: description
- value: scaff-seed init wires Stop hook to wrong settings.json. Step 10 cd's to consumer_root then invokes bin/scaff-install-hook, which writes to cwd-relative 'settings.json' (a hardcoded bare filename in scaff-install-hook lines 66 and 109) — so Step 10 ends up creating /<consumer>/settings.json and /<consumer>/settings.json.bak at the project root, while Step 7's Python merge correctly writes /<consumer>/.claude/settings.json. Net effect: two divergent settings files; the Stop hook never lands in .claude/settings.json (the only one Claude Code actually reads), and a stray settings.json + settings.json.bak get left at the consumer root.

## Repro

1. Start with a fresh empty consumer directory (e.g. `/Users/yanghungtw/Projects/meridian` with no `.claude/` and no `settings.json`).
2. From that directory, run `scaff-seed init`.
3. After init completes, list the consumer root and the `.claude/` directory.
4. Open both `<consumer>/settings.json` and `<consumer>/.claude/settings.json` and compare their `hooks` sections.

## Expected

- After init, no `settings.json` and no `settings.json.bak` exist at the consumer project root.
- `<consumer>/.claude/settings.json` exists and contains both a `SessionStart` hook (command: `bash .claude/hooks/session-start.sh`) and a `Stop` hook (command: `bash .claude/hooks/stop.sh`).
- Claude Code, on next launch in that consumer, fires both hooks.

## Actual

- `<consumer>/settings.json` exists at the project root containing both `SessionStart` and `Stop` entries (commands without the `bash ` prefix: `.claude/hooks/session-start.sh`, `.claude/hooks/stop.sh`).
- `<consumer>/settings.json.bak` exists at the project root — the snapshot `scaff-install-hook` took before merging in `Stop` on its second invocation.
- `<consumer>/.claude/settings.json` exists and contains only the `SessionStart` entry (command `bash .claude/hooks/session-start.sh`) — the output of Step 7's Python merge, untouched by Step 10.
- Claude Code reads only `<consumer>/.claude/settings.json`, so the `Stop` hook never fires.

## Environment

- Repo: specaffold source repo at `/Users/yanghungtw/Tools/specaffold` (self-hosting; `.specaffold/` lives there).
- Reproduced on consumer: `/Users/yanghungtw/Projects/meridian`, fresh empty directory.
- Date reproduced: 2026-04-26.
- Host OS: macOS (Darwin 25.3.0).
- Relevant code: `bin/scaff-install-hook` (lines 66, 109 — hardcoded `p = "settings.json"`); `scaff-seed` Step 10 init invocation; `scaff-seed` migrate counterpart around lines 1620–1623.

## Root cause

`bin/scaff-install-hook` hardcodes its settings-file target as the bare relative path `settings.json` (`p = "settings.json"` at lines 66 and 109), with no `.claude/` prefix and no override surface. When `scaff-seed init` Step 10 calls the helper from inside the consumer root (the natural cwd for the rest of the init flow), the helper resolves that bare filename against the consumer root and silently creates/edits the wrong file. The helper has no awareness of the `.claude/` convention even though Claude Code only reads `<consumer>/.claude/settings.json`.

## Fix requirements

- **R1**: `bin/scaff-install-hook` MUST default its settings-file target to `.claude/settings.json` (resolved relative to the helper's invocation cwd), replacing the bare `settings.json` literal at both line 66 and line 109. The helper MUST create the `.claude/` directory if it does not yet exist.
- **R2**: The helper's `.bak` snapshot behaviour MUST follow the new default — i.e. any backup file is written next to the new target (`.claude/settings.json.bak`), never at the consumer root.
- **R3**: `scaff-seed` Step 10 (init flow) and the migrate counterpart around lines 1620–1623 MUST continue to work without modification under the new default; if the existing call sites pass cwd-relative hook paths or a settings-path argument that would now point to the wrong place, those call sites MUST be updated in the same change so init and migrate both land hook entries in `<consumer>/.claude/settings.json`.
- **R4**: The helper MUST be idempotent: invoking `add SessionStart` (or `add Stop`) when an equivalent entry already exists in `.claude/settings.json` MUST be a no-op (no duplicate entry, no `.bak` written).
- **R5**: After the fix, `scaff-seed init` on a fresh empty consumer MUST NOT create any file at the consumer project root other than what was already created pre-bug — specifically, no `settings.json` and no `settings.json.bak` at the root.
- **R6**: Hook command strings written by the helper MUST match the form already produced by Step 7's Python merge (i.e. `bash .claude/hooks/session-start.sh` / `bash .claude/hooks/stop.sh`) so the two write paths converge on a single canonical entry shape.

## Regression test requirements

- **T1**: Automated or scripted check that runs `scaff-seed init` against a fresh empty consumer fixture and asserts:
  - `<consumer>/settings.json` does not exist.
  - `<consumer>/settings.json.bak` does not exist.
  - `<consumer>/.claude/settings.json` exists and contains both `SessionStart` and `Stop` hook entries with the canonical `bash .claude/hooks/...` command form.
- **T2**: Idempotency check — re-running `scaff-seed init` on the same consumer (post-T1) does not produce a `.bak` and leaves `<consumer>/.claude/settings.json` unchanged (or changed only in whitespace/key-order ways that are semantically identical).
- **T3**: Direct unit-style check of `bin/scaff-install-hook add Stop …` invoked from a temp directory: confirm it targets `.claude/settings.json` (creates `.claude/` if missing) and never writes `settings.json` at the cwd root.

## Acceptance criteria

- **AC1**: After `scaff-seed init` on a fresh empty consumer, neither `<consumer>/settings.json` nor `<consumer>/settings.json.bak` exists.
- **AC2**: After `scaff-seed init` on a fresh empty consumer, `<consumer>/.claude/settings.json` contains both a `SessionStart` and a `Stop` hook entry, each with command `bash .claude/hooks/session-start.sh` and `bash .claude/hooks/stop.sh` respectively.
- **AC3**: Re-running `scaff-seed init` against the same consumer is idempotent: it does not create a `settings.json.bak` (anywhere), and `<consumer>/.claude/settings.json` remains semantically unchanged. (This holds because no prior `.claude/settings.json` existed before the first run, and on the second run the helper sees the entries it would add are already present and no-ops.)
- **AC4**: The migrate flow (`scaff-seed` lines ~1620–1623 counterpart) lands hook entries in `<consumer>/.claude/settings.json` and never at the consumer root.

## Decisions

- **D1**: Adopt fix Option B — change `bin/scaff-install-hook` to default its target to `.claude/settings.json` — over Option A (cd into `consumer_root/.claude` from Step 10). Rationale: the helper is the long-lived contract; aligning it with the file Claude Code actually reads removes a footgun for any future caller and eliminates the bare-filename literal at the source.
- **D2**: Do not introduce a `--settings-path` CLI flag in this change unless the existing call sites in `scaff-seed` Step 10 / migrate require it to keep working. Rationale: keep the diff minimal; the default change is sufficient for the documented call sites. (If a flag is needed for the migrate counterpart, that's a same-PR scope creep, not a follow-up.)
- **D3**: Do not retro-clean orphaned `settings.json` / `.bak` files on existing consumer checkouts as part of this fix. Rationale: out of scope; one-time manual `rm` is acceptable, and an automatic cleanup risks deleting user data on consumers that legitimately have a root-level `settings.json` for unrelated reasons.

## Open questions

- **OQ1**: Does the migrate counterpart around `scaff-seed` lines 1620–1623 invoke `scaff-install-hook` with the same bare-filename assumption, and does the Option B default fully cover it, or does migrate pass an explicit path that would still be wrong? (Architect to confirm during tech stage; if the latter, R3 implies updating the migrate call site too.)
