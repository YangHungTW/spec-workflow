# PRD — fix init missing preflight files

## Problem

`bin/scaff-seed init` (dispatched by the `/scaff-init` skill) leaves the
consumer repo without `.specaffold/config.yml` or `.specaffold/preflight.md`.
Because the preflight gate shipped today (feature
`20260426-scaff-init-preflight`) asserts `.specaffold/config.yml` as its
passthrough sentinel and instructs the assistant to "Run preflight from
.specaffold/preflight.md", every `/scaff:*` command in a freshly-init'd repo
fails closed with `REFUSED:PREFLIGHT` and the gate body itself cannot be
read because the file is absent. The init manifest only copies
`.specaffold/features/_template/`; the gate's two required files were never
added to the manifest.

## Source

- type: description
- value: |
  scaff-seed init does not create .specaffold/config.yml or copy .specaffold/preflight.md, so the preflight gate (feature 20260426-scaff-init-preflight) fires REFUSED:PREFLIGHT on freshly-init'd consumer repos — gate sentinel assumes init produces these files but scaff-seed's manifest only ships .specaffold/features/_template/

## Repro

1. In an empty directory, run `git init`.
2. Run `bin/scaff-seed init --from <scaff-source-repo> --ref HEAD`.
3. Observe: `.specaffold/features/_template/` is present, the pre-commit
   hook is installed, 61 `.claude/` files are symlinked, but
   `.specaffold/config.yml` and `.specaffold/preflight.md` are absent.
4. Invoke any `/scaff:*` slash command (e.g. `/scaff:request "demo"`).
5. Observe: assistant returns `REFUSED:PREFLIGHT` because the gate sentinel
   `.specaffold/config.yml` is missing; furthermore the directive to run
   `.specaffold/preflight.md` cannot be followed because that file is
   absent too.

## Expected

After `bin/scaff-seed init` (or `bin/scaff-seed migrate`) succeeds in a
clean repo, the consumer is immediately usable: `.specaffold/config.yml`
and `.specaffold/preflight.md` both exist with sensible defaults, and a
`/scaff:*` invocation runs cleanly through the preflight gate.

## Actual

Both files are absent. The gate body cannot be read; even if it could, the
sentinel check `[ ! -f .specaffold/config.yml ]` would still trigger
`REFUSED:PREFLIGHT`. The user must hand-create the two files to use scaff
in their repo.

## Environment

- macOS (bash 3.2 / BSD userland).
- specaffold source repo at HEAD (post `20260426-scaff-init-preflight`
  archive — commit 11df1f8 or later).
- Consumer repo: any freshly `git init`'d directory.
- Originally observed in `/Users/yanghungtw/Tools/llm-wiki/`.

## Root cause

Two layers contribute:

1. **Init manifest is incomplete.** `bin/scaff-seed init` (and `migrate`)
   copies only `.specaffold/features/_template/` from the source repo; the
   manifest never enumerated `.specaffold/config.yml` or
   `.specaffold/preflight.md` because both files post-date earlier
   manifest design.
2. **Gate body assumes the wiring is done.** The W3 marker block in every
   `/scaff:<cmd>.md` references `.specaffold/preflight.md` by relative
   path, expecting it in the consumer's working tree. Without the manifest
   update, the directive is dangling.

The validate stage of the preflight gate feature did not catch this:
`t108` and `t110` mocked the gate's two passthrough/refuse states by
toggling `config.yml` presence in `mktemp -d` sandboxes, but did not
exercise the integration path `bin/scaff-seed init → resulting .specaffold/
state`. This is the same wiring-vs-entrypoint gap captured in the
qa-analyst memory `partial-wiring-trace-every-entry-point`.

## Fix requirements

- **R1**: `bin/scaff-seed init` and `bin/scaff-seed migrate` MUST create
  `.specaffold/config.yml` if absent, with a default content of at minimum
  `lang:\n  chat: en\n` (matching the `language-preferences` rule).
  MUST NOT overwrite an existing `config.yml` (no-force-on-user-paths
  discipline).
- **R2**: `bin/scaff-seed init` and `bin/scaff-seed migrate` MUST copy
  `.specaffold/preflight.md` from the source repo verbatim to the
  consumer's `.specaffold/preflight.md` if absent. MUST NOT overwrite an
  existing `preflight.md` (no-force-on-user-paths discipline).
- **R3**: The init/migrate manifest MUST be discoverable and explicit:
  adding new top-level `.specaffold/*` template files in future should
  fit the same pattern, not require ad-hoc edits to two functions.
- **R4**: After running `bin/scaff-seed init` in a clean repo,
  (a) `bin/scaff-lint preflight-coverage` MUST still exit 0, and
  (b) any `/scaff:<cmd>` invocation MUST NOT return `REFUSED:PREFLIGHT`
  due to a missing sentinel.
- **R5**: A regression integration test MUST cover the full path
  `mktemp -d → git init → scaff-seed init → /scaff:* preflight passthrough`
  so this regression cannot recur. Today's `t108` / `t110` do not cover
  this path; the new test (e.g. `t112` or an extension of `t108`) must.

## Regression test requirements

Per R5, a new integration test under `test/` (named to fit the existing
sandbox-home test convention, e.g. `test/scaff-seed-init-preflight.sh`)
MUST:

1. Build a `mktemp -d` sandbox; set `HOME` inside it; preflight-assert
   per `.claude/rules/bash/sandbox-home-in-tests.md`.
2. Run `bin/scaff-seed init --from <SCAFF_SRC> --ref HEAD` against the
   sandbox.
3. Assert both `.specaffold/config.yml` and `.specaffold/preflight.md`
   exist.
4. Assert `cmp` of `preflight.md` against the source's
   `.specaffold/preflight.md` (byte-identical).
5. Extract the gate body from the consumer's `preflight.md` and run it
   from the consumer's CWD; assert exit 0 and empty output (passthrough).
6. Run `bin/scaff-seed init` again; assert idempotent (`already:` for
   both files; shasum unchanged).

## Acceptance criteria

- **AC1**: Running `bin/scaff-seed init --from <src> --ref HEAD` in a
  fresh `mktemp -d` + `git init` repo creates BOTH
  `.specaffold/config.yml` AND `.specaffold/preflight.md`. Verify:
  `[ -f $CONSUMER/.specaffold/config.yml ]` AND
  `[ -f $CONSUMER/.specaffold/preflight.md ]`.
- **AC2**: The created `.specaffold/preflight.md` is byte-identical to
  the source's. Verify:
  `cmp $SRC/.specaffold/preflight.md $CONSUMER/.specaffold/preflight.md`
  exits 0.
- **AC3**: The created `.specaffold/config.yml` contains a recognisable
  default — at minimum a top-level `lang:` key with a `chat:` sub-key.
  Verify: `grep -E '^lang:' $CONSUMER/.specaffold/config.yml` matches
  AND `grep -E '^[[:space:]]+chat:' $CONSUMER/.specaffold/config.yml`
  matches.
- **AC4**: A second `bin/scaff-seed init` on the same consumer is
  idempotent: reports `already:` (or equivalent skip marker) for
  `config.yml` and `preflight.md`, with byte-identical content.
  Verify: shasum-before == shasum-after for both files.
- **AC5**: A pre-existing user-edited `config.yml` is NOT clobbered.
  Fixture: consumer has a `.specaffold/config.yml` with custom content
  before init runs; assert content unchanged after init
  (no-force-on-user-paths discipline).
- **AC6**: After scaff-seed init in a clean repo, simulating an
  assistant running the gate body (extract from
  `.specaffold/preflight.md`, run from the consumer's CWD) exits 0 with
  no output (passthrough). Verify: extract+run as in `t110`'s harness
  pattern.
- **AC7**: An integration test under `test/` exercises the full path
  `mktemp -d → git init → scaff-seed init → assert config.yml +
  preflight.md present → extract+run preflight returns exit 0`. The
  test is added to whatever test runner currently invokes `t108` /
  `t110` siblings.

## Decisions

- **D1** — `config.yml` default content shape: minimal viable is
  `lang:\n  chat: en\n` (matches existing
  `.claude/rules/common/language-preferences.md`). Architect to confirm
  whether more fields ship in v1; default lean is "no — fewer surfaces
  reduce migration headaches".
- **D2** — `preflight.md` distribution: copy verbatim from source into
  the consumer (consumer is self-contained; can run preflight without
  resolving any source path). Rejected alternative: reference source
  via `$SCAFF_SRC` indirection — adds a runtime dependency on source
  resolution and breaks if source moves.
- **D3** — Idempotency markers: depends on whether scaff-seed already
  tracks installed files via a manifest sentinel. If yes, add
  `config.yml` + `preflight.md` to the manifest. If no, the simplest
  pattern is "skip if exists". Architect to confirm by reading
  `bin/scaff-seed`.
- **D4** — `bin/scaff-seed migrate` MUST backfill these files for repos
  that were init'd before this fix landed (otherwise existing consumer
  repos remain broken). Migrate's classification logic adds these as
  `missing → install` candidates.

## Open questions

None at PRD close. D1–D4 are flagged for Architect refinement during
the tech stage; none block PRD acceptance.

## Team memory

Applied entries:

- `pm/ac-must-verify-existing-baseline` — AC2 / AC6 anchor on a single
  canonical reference (the source's `.specaffold/preflight.md` and
  `t110`'s extract-and-run harness pattern) rather than vague "match
  existing" language.
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap` —
  reframed as a wiring-vs-entrypoint gap: the preflight feature shipped
  the gate but not its install path; this PRD closes that half.
- `shared/dogfood-paradox-third-occurrence` — informs R5 / AC7: the
  preflight feature could only be structurally verified during its own
  bootstrap; live integration with `bin/scaff-seed` is the next-feature
  exercise — i.e. this bug.
- `shared/auto-classify-argv-by-pattern-cascade` — referenced for the
  `/scaff:bug` argv classification (the input was correctly classified
  as `description` per the cascade).

Proposed new memory: `pm/preflight-gates-need-init-wiring-paired` —
when shipping a fail-closed gate that asserts a sentinel file, the
same feature MUST also ship the install path that creates the sentinel
in fresh consumer repos; otherwise validate-time mocks pass while
real consumer init breaks. Will draft after archive if reviewer agrees.
