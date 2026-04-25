---
name: By-construction coverage via lint-anchor — four-layer enforcement loop
description: When a new convention must apply uniformly across N files in a closed directory and future authors must inherit it without discipline, decompose the enforcement into four layers — shared body outside the harvest scope, per-file marker wiring, lint subcommand asserting marker presence, pre-commit hook wired via scaff-seed.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a new convention must apply uniformly across N files in a closed directory and future authors must inherit it without discipline, decompose the enforcement into four layers:

1. **Shared body** lives outside the auto-harvest scope (e.g. for `.claude/commands/scaff/`, the body goes under `.specaffold/<purpose>.md`, not in the commands dir — see `commands-harvest-scope-forbids-non-command-md.md`).
2. **Per-file marker wiring** — each file in the gated directory carries a short, byte-identical marker block (HTML comment + a 4–5 line imperative directive) that points to the shared body.
3. **Lint subcommand** — extend the existing project lint binary (`bin/scaff-lint <subcommand>`) with a coverage check that asserts every file in the directory carries the marker. Use a single `grep -L -F` fork (not a per-file loop) per the performance rule.
4. **Pre-commit hook** — wire the lint into the project's pre-commit shim emitter in `bin/scaff-seed` so that consumer repos inherit the enforcement on every `scaff-seed init/migrate`. Local repo's own `.git/hooks/pre-commit` must also be refreshed for dogfood enforcement.

## Why

The pattern is general beyond preflight gates — it applies to any future "every X must do Y" requirement: every reviewer must emit a verdict footer; every command must declare its work-type filter; every agent prompt must declare a team-memory protocol. Without enforcement, the convention rots silently as new files land without the marker; reviewers may catch it once but not consistently. The four-layer shape moves the discipline from author memory to mechanism: the lint asserts coverage, the pre-commit hook asserts the lint runs, and the marker text is what the assistant actually obeys at runtime.

The architect on `20260426-scaff-init-preflight` reasoned through the four-layer shape from first principles in a single session; capturing it saves that derivation cost on the next occurrence. Cross-references existing `architect/commands-harvest-scope-forbids-non-command-md.md` (which is *why* the body lives outside the harvest scope) and `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md` (which captures the bookkeeping consequence).

## How to apply

1. **At tech time**, when a new convention must apply across all files in a directory, name the four layers explicitly in the D-decisions:
   - D-N: shared body location (outside any auto-harvest scope).
   - D-N+1: marker-block shape (byte-identical 5-line block; HTML comment + directive prose).
   - D-N+2: lint subcommand name and scope (`bin/scaff-lint <name>`; non-recursive directory scan; single `grep -L -F` fork).
   - D-N+3: pre-commit hook wiring point (`bin/scaff-seed cmd_init` shim heredoc + `cmd_migrate` mirror — both heredocs MUST stay byte-identical, see lessons below).
2. **At plan time**, sequence the four layers as separate waves:
   - W1: shared body + lint (producers).
   - W2: pre-commit hook wiring.
   - W3: marker propagation (consumer of W1+W2 — the dogfood wave).
   - W4: docs + runtime AC harness.
   The strict ordering makes recovery hand-edit-tractable: if W3 lands a bad marker, `git revert` the bulk commit; the lint and hook still work.
3. **Marker insertion point** — for files with frontmatter, insert the marker block **between** the closing `---` of the frontmatter and the first body line, with one blank line on each side. Bulk-apply via a single `awk` script over a verbatim filename array (do NOT glob — a stray non-command file in the directory becomes silent coverage drift).
4. **Mirror-emit sites** — if the shim emitter exists at multiple call sites (e.g. `cmd_init` AND `cmd_migrate`), ALL sites must update together. Plan time must enumerate every emit site by `grep -n` line number; missing one breaks by-construction inheritance on that command path. Cross-reference: `qa-analyst/partial-wiring-trace-every-entry-point.md`.
5. **At validate time**, qa-tester runs the runtime sandbox harness (extract the SCAFF block, run in `mktemp -d`); qa-analyst checks marker coverage (lint exit 0 + 18 ok lines) AND every emit site has a corresponding test path.

## Example

The four-layer enforcement loop for the preflight gate (`20260426-scaff-init-preflight`):

| Layer | File | Lines added | Reviewable in isolation? |
|------|------|------|---|
| Shared body | `.specaffold/preflight.md` | +14 | yes (W1 review) |
| Lint subcommand | `bin/scaff-lint preflight-coverage` | +39 | yes (W1 review; single `grep -L -F` fork) |
| Pre-commit hook | `bin/scaff-seed` shim heredoc | +2 (one line × 2 emit sites) | yes (W2 review + W2 fixup for cmd_migrate site) |
| Markers | 18 × `.claude/commands/scaff/*.md` | +6/file × 18 = +108 | yes (W3 bulk diff is byte-identical 6-line addition × 18) |

The dogfood-paradox bit at three sites: orchestrator W2 bookkeeping commit needed `--no-verify` (lint can't pass before W3); developer T7 commit (W3, parallel branch) also needed `--no-verify` (markers not on T7's branch); both `--no-verify` sites must be enumerated in the plan section before W2 starts. Cross-reference: `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md`.

The pattern is not specific to preflight gates. The next time a convention like "every reviewer agent emits the verdict footer" or "every command file declares its work-type filter" needs to apply across N files, the same four layers (shared body + marker + lint + pre-commit) port directly. Naming convention: lint subcommand is `<convention>-coverage`, marker is `<!-- <convention>: required -->`.
