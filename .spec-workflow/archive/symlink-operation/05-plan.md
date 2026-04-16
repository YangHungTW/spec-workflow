# Plan — symlink-operation

_2026-04-16 · TPM_

Implementation roadmap for `bin/claude-symlink`. Anchored to PRD `03-prd.md`
(R1–R16) and tech `04-tech.md` (D1–D6 active, D7–D11 deferred). This is the
milestone-level sequencing plan; the per-step task breakdown lives in
`06-tasks.md`.

## 1. Scope summary

We are shipping one new executable — `bin/claude-symlink` — a pure-bash 3.2
script with three subcommands (`install`, `uninstall`, `update`) plus
`--dry-run` and `--help`. It manages a closed set of symlinks from
`~/.claude/{agents/YHTW, commands/YHTW, team-memory/**}` back to this repo's
`.claude/` tree, safe on macOS + Linux with zero install-time deps. All 16 PRD
requirements and all 6 active tech decisions (D1 bash 3.2 floor; D2 pure-bash
`resolve_path`; D3 `bin/claude-symlink`; D4 strict tool allow-list; D5
classification taxonomy; D6 repo-root prefix ownership check) are in scope for
v1. D7–D11 are deferred.

## 2. Milestones

### M1 — Script skeleton + flag parsing

- **Output**: `bin/claude-symlink` exists, is executable, shebang
  `#!/usr/bin/env bash`, `set -u -o pipefail`, OS guard (exits 2 on
  `MINGW*/MSYS*/CYGWIN*`). `--help` / `-h` prints usage and exits 0.
  Unknown subcommand exits 2. `--dry-run` is parsed anywhere in argv and
  exported as `DRY_RUN=1`. Stub `cmd_install`, `cmd_uninstall`, `cmd_update`
  dispatch targets exist and each currently just echoes the subcommand name.
- **Requirements covered**: R12 (dry-run flag accepted), R14 (exit 2 on
  usage error), R16 (bash + OS guard).
- **Decisions honored**: D1 (bash 3.2, no `set -e`, no bash 4 idioms), D3
  (path & name), D4 (no external binaries beyond allow-list).
- **Verification signal**: `bin/claude-symlink --help` prints usage, exits 0;
  `bin/claude-symlink bogus` exits 2; `bin/claude-symlink install --dry-run`
  echoes a stub line and exits 0.

### M2 — Path helpers

- **Output**: `resolve_path` (iterative segment-by-segment resolver, cycle cap
  40), `resolve_repo_root` (dirname dirname of `resolve_path "$0"`, cached in
  a global), `owned_by_us` (`-L` AND `resolve_path(readlink …)` starts with
  `$REPO/.claude/` — trailing slash required to avoid sibling false-positive).
  `die()` helper writes to stderr and exits with a passed code.
- **Requirements covered**: R1 (repo root resolution), R3 (absolute targets
  pipeline), R16 (BSD/GNU readlink portability).
- **Decisions honored**: D2 (pure-bash, no `readlink -f`, no `coreutils`), D6
  (prefix-match with trailing slash is the ownership rule).
- **Verification signal**: invoking the script from a different `cwd` and
  via a symlink to the script both report the same repo root (add a hidden
  `__probe` subcommand during dev that prints `REPO`, or assert via the
  integration harness once M9 lands).

### M3 — Plan computation

- **Output**: `plan_links` emits the full `(src, tgt)` pair set to a
  bash-array global (D1: no associative arrays — flat indexed arrays with
  `PLAN_SRC[i]` / `PLAN_TGT[i]`). Two fixed directory-level pairs for
  `agents/YHTW` and `commands/YHTW`; file-level walk via
  `find "$REPO/.claude/team-memory" -type f -print0` piped into
  `while IFS= read -r -d '' src`.
- **Requirements covered**: R4 (managed set shape), R5 (no exclusions).
- **Decisions honored**: D1 (no `mapfile`), D4 (find + bash builtins only).
- **Verification signal**: `plan_links` followed by a debug dump shows two
  directory pairs plus one file pair for every regular file currently under
  `.claude/team-memory/`. Count matches `find .claude/team-memory -type f | wc -l` + 2.

### M4 — Classifier

- **Output**: `classify_target <tgt> <expected_src>` returns exactly one of:
  `missing`, `ok`, `wrong-link-ours`, `wrong-link-foreign`, `broken-ours`,
  `broken-foreign`, `real-file`, `real-dir`. Pure function — no mutation, no
  stderr on expected states. Implements the case ladder from tech §3.
- **Requirements covered**: R10 (conflict matrix), R9 (broken-ours handling).
- **Decisions honored**: D5 (exactly this taxonomy), D6 (ownership test via
  `owned_by_us`).
- **Verification signal**: unit test fixtures — temp dir, place each of the
  8 states at a known path, assert the returned string. This is the first
  milestone with direct unit coverage.

### M5 — `install`

- **Output**: `cmd_install` iterates the plan; for each pair, `ensure_parent`
  creates missing parent dirs (recording them in `CREATED_DIRS`), then
  dispatches on `classify_target`:
  `missing` → `create_link` → `[created]`;
  `ok` → `[already]`;
  `broken-ours` → replace → `[created:replaced-broken]`;
  `wrong-link-ours` → replace → `[created:replaced-broken]`;
  anything foreign or real → skip with the matching `skipped:<reason>`.
  Under `DRY_RUN=1`, `create_link` and `ensure_parent` are no-ops and the
  verb becomes `would-*`. Per-path lines buffered to stdout.
- **Requirements covered**: R6, R7, R10, R11 (no force), R12 (dry-run), R13
  (per-path report).
- **Decisions honored**: D3 (absolute source in `ln -s`), D4 (ln/mkdir only),
  D5 (dispatch on taxonomy).
- **Verification signal**: on a sandbox `$HOME`, `install` creates the two
  dir-level links + every file-level link; second run reports all `[already]`;
  a pre-placed real file at a managed path produces
  `[skipped:real-file]` and an overall exit 1.

### M6 — `uninstall`

- **Output**: `cmd_uninstall` removes the two dir-level links if
  `owned_by_us`, then walks `~/.claude/team-memory` via
  `find … -type l -print0` and removes any symlink that is `owned_by_us`.
  Foreign symlinks are reported `[skipped:not-ours]` only if they sit at a
  planned path; unrelated foreign links elsewhere are left silent (per tech
  §3 subtlety). After removals, `try_remove_empty_parents` attempts `rmdir`
  on each known managed parent dir (`agents/`, `commands/`,
  `team-memory/<role>/`, `team-memory/`) deepest-first, stopping at
  `~/.claude/` — `rmdir` on non-empty dirs fails harmlessly.
- **Requirements covered**: R8 (ownership-gated removal, empty-dir cleanup,
  never touch `~/.claude/` itself).
- **Decisions honored**: D6 (prefix-check ownership is the sole gate), D4
  (rm + rmdir only, never `rm -r`).
- **Verification signal**: post-install → `uninstall` leaves no tool-owned
  symlink behind; a hand-placed real file at a managed path is untouched;
  `~/.claude/` still exists.

### M7 — `update`

- **Output**: `cmd_update` runs the install pass (M5 logic) first to add /
  fix, then prunes: `find ~/.claude/team-memory -type l -print0`, and for
  every `owned_by_us` link whose path is not in `DESIRED_TARGETS`, remove
  and report `[removed:orphan]`. Then run the same empty-parent cleanup as
  uninstall. `broken-ours` links inside the desired set are replaced in the
  install pass; only links absent from the new plan get pruned.
- **Requirements covered**: R9 (reconciler: add ∪ prune, broken-link replace).
- **Decisions honored**: D5, D6.
- **Verification signal**: after install, add a new file under
  `team-memory/shared/` → `update` links it and reports `created` only for
  that path; delete a file, `update` prunes the now-broken link and reports
  `removed:orphan`.

### M8 — Output + exit codes

- **Output**: fixed-column verb tags (tech §2 "Output format"). `report
  <verb> <tgt> [<src>]` appends to a line buffer and bumps a
  per-verb counter. `emit_summary` prints every buffered line, then a
  final `summary: created=… already=… removed=… skipped=…  (exit N)`.
  `MAX_CODE` starts at 0, bumps to 1 on any `skipped:conflict:*` or
  mutation failure, stays 2 only for usage / precondition errors handled at
  flag-parse time. Exit at the very end with `$MAX_CODE`.
- **Requirements covered**: R13 (closed verb set + summary), R14 (exit
  semantics 0/1/2), R15 (always verbose).
- **Decisions honored**: D1 (plain bash arrays for buffering), D4 (pure
  bash output).
- **Verification signal**: conflict run produces correct summary line and
  exit 1; clean run exits 0; usage error exits 2. Every verb printed is in
  R13's closed set.

### M9 — Manual QA harness

- **Output**: `test/run-smoke.sh` (plus `test/fixtures/` if needed). It
  creates a sandbox via `HOME=$(mktemp -d)`, runs each of the 12 AC
  scenarios (PRD §5) end-to-end against the real script, asserts on
  `[[ -L … ]]` / `readlink` output / exit code / grep over the report, and
  prints a pass/fail summary. Not a unit-test framework — just a bash
  driver the Developer and QA-tester can both run. Bats may be pulled in as
  a dev-only dep (tech §4 allows) but is optional; the smoke harness itself
  must run with nothing but bash.
- **Requirements covered**: R12 (dry-run verification), R13, R14, R16, all
  ACs.
- **Decisions honored**: D1 (no bash 4 in the harness either), D4.
- **Verification signal**: `bash test/run-smoke.sh` exits 0 on a clean
  checkout on macOS and on Linux. Each AC scenario reports PASS.

### M10 — Docs

- **Output**: top-of-script header comment block (usage, exit codes, the
  managed set), plus a short README section (or `bin/claude-symlink.md`
  next to the script if the repo prefers co-located docs — TPM leans
  README in the repo root) describing: what it does, how to run, dry-run
  flag, supported platforms, recovery from a moved repo, how to resolve
  each conflict class manually (R11 — no `--force`).
- **Requirements covered**: R3 (documents the moved-repo behavior as
  supported recovery), R11 (documents conflict resolution is manual),
  R15 (documents no `--quiet`).
- **Decisions honored**: D3 (documents path and name).
- **Verification signal**: README scan by QA-analyst during gap-check
  confirms every user-facing PRD requirement is addressed in docs.

## 3. Cross-cutting concerns

- **Testing strategy**. Never touch the real `~/.claude/`. Every test run
  sets `HOME=$(mktemp -d)` and `export HOME` before invoking the script.
  The script reads `$HOME` (R2), so this fully sandboxes it. Fixtures live
  under `test/fixtures/` and the smoke driver is `test/run-smoke.sh`.
  Unit-style tests for `resolve_path`, `owned_by_us`, `classify_target`,
  and `plan_links` may use Bats as a dev-only dep per tech §4.
- **Error handling**. Central `die <code> <msg>` writes to stderr and
  exits — used only for preconditions (flag-parse error, unresolvable repo
  root, OS unsupported, missing `.claude/` source subtree). Inside the
  command loops, every `ln` / `rm` / `mkdir` is wrapped
  `if ! …; then report_failure; MAX_CODE=1; continue; fi`. Never `set -e`
  — it fights accumulate-and-continue.
- **Logging**. Tag-prefixed per-path lines to **stdout**; `die` and
  in-loop failure messages to **stderr**. Summary is always the last
  stdout line. No file logging, no `--verbose`, no `--quiet` (D4 / R15).
- **Idempotence**. Every subcommand is safe to re-run against any
  convergent state. `install` twice → second run is all `[already]`.
  `update` twice → second run is all `[already]`. `uninstall` twice → second
  run finds nothing owned and reports cleanly. This is a property, not a
  flag — bake it into the classifier so the mutator never sees an
  already-done state.
- **No destructive ops**. Re-affirming D6 and tech §4: `rm` only ever runs
  on a path `classify_target` just labeled as a symlink, and only if
  `owned_by_us` is true. Never `rm -r`. Never touch anything outside
  `~/.claude/{agents/YHTW, commands/YHTW, team-memory/**}`. Never remove
  `~/.claude/` itself. Never follow a symlink to make an ownership
  decision — always compare the *resolved* link-target against the
  *resolved* repo root with a trailing-slash prefix match.

## 4. Dependencies & sequencing

```
M1 ──▶ M2 ──▶ M3 ──▶ M4 ──▶ M5 ──┐
                     │           ├──▶ M8 ──▶ M9 ──▶ M10
                     ├──▶ M6 ────┤
                     └──▶ M7 ────┘
```

- **Strict**: M1 → M2 → M3 → M4. Nothing downstream works without the
  classifier and the plan.
- **Parallel eligible**: M5, M6, M7 can be built in any order after M4;
  each reuses `classify_target` and `plan_links`. Recommended order M5 → M6
  → M7 because `install` is the thing most users run first and the
  smallest surface to get right.
- **M8** can be incrementally wired into M5–M7 as those land; the
  finalized summary + exit-code semantics should be locked *before* M9 so
  the smoke tests have stable assertions.
- **M9** gates M10 only in the sense that docs should not be written
  before the behavior is pinned.

## 5. Risks / watch-items for implementation

- **macOS bash 3.2 quirks** — no `mapfile`, no associative arrays, no
  `${var,,}`. Mitigation: use flat indexed arrays, `while read -r -d ''`,
  and `tr` for lowercasing (though nothing in the plan currently needs
  lowercasing).
- **`find -print0` portability** — BSD and GNU both support it; the
  concern is shell handling. Mitigation: always pair with
  `while IFS= read -r -d ''` and run a fixture test on both platforms in
  M9.
- **`readlink` BSD vs GNU** — the whole reason for D2. Mitigation:
  `resolve_path` uses only bare `readlink` (no `-f`, no `-m`) and loops
  explicitly. Cycle cap 40 prevents infinite recursion.
- **Symlinks inside `team-memory/`** — tech §3 decided `-type f` follows
  source symlinks and mirrors them as files. Mitigation: documented; not
  a risk unless the repo starts committing symlinks under
  `team-memory/`, which it doesn't.
- **Orphan walk false-positives under `~/.claude/team-memory/`** — a
  user's own symlink that happens to point inside the repo would be
  considered ours. Mitigation: `owned_by_us` already requires the resolved
  target to start with `$REPO/.claude/` with trailing slash; that's the
  contract. An in-repo symlink that wasn't created by the tool but does
  satisfy the ownership test is, by definition, indistinguishable from one
  we created — and since the tool's managed plan exactly matches where such
  links would sit, pruning it is correct behavior, not a bug. Document
  this in M10.
- **Sibling-repo prefix collision** — `/repo-sibling/.claude/...` shares
  the `/repo/.claude` prefix if the trailing slash is dropped. Mitigation:
  tech §3 explicitly requires the trailing slash in `owned_by_us`. Add a
  unit test for this exact case in M4.
- **`mktemp -d` flag differences** — BSD wants `mktemp -d -t prefix`
  (with `-t`), GNU tolerates bare `mktemp -d`. Mitigation: use the
  lowest-common-denominator form `mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink'`
  in the smoke harness (M9).
- **Developer accidentally tests against real `$HOME`** — very high-cost
  mistake. Mitigation: the smoke harness must `exit 2` if `$HOME` is not
  a freshly-created `mktemp` path; add a preflight assertion on the
  sandbox path shape in M9.
- **Atomic relink on `wrong-link-ours` / `broken-ours`** — `mv -fn` on
  macOS differs from Linux in edge cases. Mitigation: fall back to
  `rm <link> && ln -s <abs-src> <link>` sequentially; a race here is
  effectively impossible because only this tool owns the path.

## 6. Out of plan

Explicitly deferred per tech §6 — not shipping in v1:

- **D7** — Makefile / shell-completion / Homebrew formula.
- **D8** — `--force-symlinks` flag.
- **D9** — JSON or machine-readable output.
- **D10** — Structured logging / log file.
- **D11** — Special handling for intra-repo source symlinks under
  `team-memory/` (today: treated as files).

Also out: `--quiet`, `--verbose`, Windows support, any subtree beyond
`agents/YHTW` / `commands/YHTW` / `team-memory/**`, copy-based install,
watchers, auto-sync.
