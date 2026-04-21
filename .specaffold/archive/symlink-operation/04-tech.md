# Tech — symlink-operation

_2026-04-16 · Architect_

The PRD (`03-prd.md`) has already settled the product shape: a single POSIX bash
script with `install` / `uninstall` / `update` subcommands, hybrid granularity,
absolute symlink targets, no `--force`, `update`-as-reconciler. This document
covers *how* to build it, not *what* to build. Every decision here is anchored
to a PRD requirement (`R<n>`) or to the only soft constraint the PRD punted to
Architect (script path and readlink portability).

## 1. Technology selection

The repo today contains no executable code — only markdown under `.claude/` and
the `.spec-workflow/` metadata tree. There is no package manifest, no CI
config, no lockfile. There is nothing to "match" in the existing stack; this
feature introduces the first executable the repo ships.

### D1. Shell + minimum version

- **Options considered**: `/usr/bin/env bash` targeting bash 3.2, targeting bash
  4+, or pure POSIX `sh`.
- **Chosen**: `/usr/bin/env bash`, minimum **bash 3.2**.
- **Why**: R16 names bash and requires macOS + Linux out of the box. macOS
  ships `/bin/bash` 3.2.57 by default (confirmed on this machine) and will
  until Apple ships a newer GPL-compatible bash, which is not happening.
  Requiring bash 4+ would force the user to `brew install bash` on every Mac
  and re-shebang. Pure POSIX `sh` would cost us arrays, `[[ ]]`, and local
  variables for no gain — R16 already permits bash. 3.2 is the floor.
- **Tradeoffs accepted**: no associative arrays (need flat indexed arrays +
  prefix-encoded keys instead), no `mapfile`/`readarray` (use `while IFS= read
  -r -d '' … done < <(find … -print0)`), no `${var,,}` lowercasing. None of
  these are needed by the algorithms in §3.
- **Reversibility**: high — bumping the minimum later is a single shebang /
  preflight check change.
- **Requirement link**: R16.

### D2. `readlink` portability strategy

- **Options considered**: (a) require `coreutils` via Homebrew on macOS and use
  `greadlink -f`; (b) write a portable `resolve_path` shell helper that loops
  over `readlink` one segment at a time; (c) use Perl / Python as a fallback.
- **Chosen**: **(b) portable `resolve_path` helper**, pure bash 3.2 +
  `readlink` (no `-f`).
- **Why**: R16 explicitly calls out tolerating BSD vs GNU `readlink`
  differences and demands zero install-time deps. Forcing `coreutils` violates
  "stock macOS". Perl/Python is a heavier dep than the shell script itself.
  A ~20-line loop that `cd`s into the dirname and re-reads the basename until
  a non-symlink is hit resolves any path on both platforms.
- **Tradeoffs accepted**: a few extra lines of shell; very slightly slower per
  path (negligible for tens-to-hundreds of files). Must handle cycles (bounded
  iteration cap, e.g. 40).
- **Reversibility**: high — isolated helper.
- **Requirement link**: R16.

### D3. Script location and name in the repo

- **Options considered**: `bin/yhtw-claude-link`, `scripts/claude-links.sh`,
  `bin/claude-symlink`, top-level `./symlink-operation`.
- **Chosen**: **`bin/claude-symlink`** (no extension, executable bit set).
- **Why**: `bin/` is the conventional home for repo-shipped executables and
  reads as "this is meant to be run". Omitting the `.sh` extension matches
  the convention that a tool's implementation language is an implementation
  detail, and leaves room to reimplement later without a breaking rename.
  `claude-symlink` says exactly what it does; the `yhtw-` prefix is redundant
  inside a repo that is itself the YHTW tooling.
- **Tradeoffs accepted**: users who grep for `.sh` scripts won't find it.
  Acceptable — discovery is via README and `make` wrapper (D8), not filesystem
  grep.
- **Reversibility**: medium — renaming later breaks any muscle-memory and any
  external docs, but there are none yet.
- **Requirement link**: PRD §7 nice-to-clarify #1 (Architect's call).

### D4. No external binaries beyond the R16 allow-list

- **Options considered**: pull in `jq` / `yq` / `tree` etc. for nicer output.
- **Chosen**: stick strictly to `ln`, `readlink`, `rm`, `mkdir`, `find`,
  `test`, plus bash builtins.
- **Why**: R16 names exactly this toolset. Anything else is another install
  burden on a fresh macOS.
- **Tradeoffs accepted**: output formatting is done by hand.
- **Reversibility**: high.
- **Requirement link**: R16.

## 2. Script architecture

### File layout

```
<repo>/
├── bin/
│   └── claude-symlink         # the script (this feature)
└── .claude/                   # source tree the script manages (already exists)
    ├── agents/YHTW/
    ├── commands/YHTW/
    └── team-memory/**
```

Rationale: one file, one place. The script resolves its own repo root as
`dirname(dirname(resolve_path($0)))` — i.e. the parent of `bin/`. This matches
R1 (repo root is the parent of the dir containing the script).

### Entry point

`main` parses flags, validates subcommand, dispatches:

```
main "$@"
  → parse_flags (strips --dry-run / --help anywhere in argv, sets globals)
  → validate positional → subcommand name
  → dispatch: cmd_install | cmd_uninstall | cmd_update
  → emit summary
  → exit with computed code
```

### Subcommand functions

- `cmd_install` — R6 / R7. Uses `plan_links` + `apply_plan install`.
- `cmd_uninstall` — R8. Uses `plan_links` (for the managed-set shape) + a walk
  of the managed roots to catch orphans the plan no longer lists, then
  `remove_link` on anything `owned_by_us`, then best-effort empty-parent prune.
- `cmd_update` — R9. Reconciler: plan-then-walk, diff, apply adds + prunes.

### Shared helpers

| Helper | Responsibility |
|--------|----------------|
| `resolve_path <p>` | D2: portable absolute-path resolution with cycle cap. |
| `resolve_repo_root` | Resolves `$0`, returns `<repo>`; cached in a global. |
| `plan_links` | R4: emits the desired (source, target) pair set. |
| `classify_target <target>` | Returns one of `missing`, `ok`, `wrong-link-ours`, `wrong-link-foreign`, `broken-ours`, `broken-foreign`, `real-file`, `real-dir`. See R10. |
| `owned_by_us <symlink>` | True iff target is a symlink AND `resolve_path(link-target)` has the repo root as a prefix (R8). |
| `create_link <src> <tgt>` | `mkdir -p` the parent (recording created dirs), then `ln -s` with the **absolute** source (R3). Under `--dry-run`, just record the would-be action. |
| `remove_link <tgt>` | `rm` the symlink (never a real file; caller must have classified first). |
| `ensure_parent <dir>` | `mkdir -p`, recording each newly created dir into a global `CREATED_DIRS` array for uninstall cleanup (R7). |
| `try_remove_empty_parents <dir>` | Best-effort `rmdir` upward, stopping at `~/.claude/`, and only for dirs in `CREATED_DIRS` (R8). |
| `report <verb> <target> <source?>` | Appends to the per-path report buffer and bumps the category counter (R13). |
| `emit_summary` | Prints the full report + summary counts at end (R13, R15). |

### Flag parsing

- Single pass over `"$@"`; recognized: `--dry-run`, `--help`, `-h`.
- Flags accepted **anywhere** in argv (before or after the subcommand).
- Everything else goes into a positional array. The first positional must be
  exactly one of `install` / `uninstall` / `update`; else exit 2 with usage.
- No support for `--force`, `--verbose`, `--quiet` (R11, R15).

### Exit codes (R14)

- `0` — fully converged (or dry-run plan produced without error).
- `1` — one or more `skipped (conflict:*)`, or any mutation failed, or any
  orphan prune failed.
- `2` — usage error or internal precondition failure (unresolvable repo root,
  missing `.claude/` source subtree, Windows detected, etc.).

Internal policy: never abort on first conflict. Accumulate, report, then exit
with the max code seen. Trap `ERR` only around mutations; classification and
planning must not trip `set -e`.

### Output format (R13, R15)

Fixed column, one line per path:

```
[created]               /Users/me/.claude/agents/YHTW  ←  /repo/.claude/agents/YHTW
[already]               /Users/me/.claude/commands/YHTW  ←  /repo/.claude/commands/YHTW
[skipped:real-file]     /Users/me/.claude/team-memory/shared/index.md
[removed:orphan]        /Users/me/.claude/team-memory/shared/stale.md
[would-create]          /Users/me/.claude/team-memory/pm/intake.md  ←  /repo/.claude/team-memory/pm/intake.md
```

Closed verb set per R13: `created`, `created:replaced-broken`, `already`,
`removed`, `removed:orphan`, `skipped:<reason>`, `skipped:not-ours`, plus
`would-*` under `--dry-run`. Final line:

```
summary: created=12 already=3 removed=0 skipped=1  (exit 1)
```

The source-path column is omitted on `removed*` and `skipped*` lines where it
is irrelevant.

### Diagram

```
            ┌────────────────────────────────────────┐
  argv ───▶ │  main / parse_flags                    │
            │    │                                   │
            │    ▼                                   │
            │  resolve_repo_root ─▶ REPO             │
            │    │                                   │
            │    ▼                                   │
            │  plan_links(REPO) ─▶ DESIRED[] pairs   │
            │    │                                   │
            │    ▼                                   │
            │  dispatch                              │
            │    ├── cmd_install  ──▶ apply(DESIRED) │
            │    ├── cmd_update   ──▶ apply(DESIRED) │
            │    │                     + prune walk  │
            │    └── cmd_uninstall ──▶ plan shape    │
            │                          + orphan walk │
            │                          + remove_link │
            │    │                                   │
            │    ▼                                   │
            │  emit_summary ─▶ stdout                │
            │    │                                   │
            │    ▼                                   │
            │  exit(max_code)                        │
            └────────────────────────────────────────┘
```

## 3. Key algorithms (pseudocode-level)

### `plan_links` (R4)

```
REPO := resolve_repo_root
HOME_CLAUDE := "$HOME/.claude"
emit_pair "$REPO/.claude/agents/YHTW"   "$HOME_CLAUDE/agents/YHTW"
emit_pair "$REPO/.claude/commands/YHTW" "$HOME_CLAUDE/commands/YHTW"
find "$REPO/.claude/team-memory" -type f -print0
  | while read -r -d '' src; do
      rel := src - "$REPO/.claude/team-memory/"
      emit_pair "$src" "$HOME_CLAUDE/team-memory/$rel"
    done
```

Note on symlinks inside `team-memory/`: `find -type f` follows symlinks to
files, which means a symlink source in the repo gets linked as if it were the
resolved file. This is fine — the canonical case is that there are none (the
repo today has zero symlinks under `.claude/team-memory/`). **Decision: treat
symlinks in source exactly like regular files** (`-type f` without `-P` /
with default symlink-following). Rationale: the repo is the source of truth;
whatever shape the repo exposes is what gets mirrored. Revisit only if we
start committing intra-repo symlinks, which we don't.

### `classify_target` (R10)

```
case on target:
  ! exists              → missing
  -L && not -e          → broken
                          if owned_by_us → broken-ours
                          else           → broken-foreign
  -L && -e              → symlink
                          if owned_by_us:
                            if link-target == expected source → ok
                            else                               → wrong-link-ours
                          else → wrong-link-foreign
  -f && ! -L            → real-file
  -d && ! -L            → real-dir
```

Mapping to R10's action table happens in `apply_plan`:

| class | install/update action |
|-------|------------------------|
| `missing` | `create_link` → `created` |
| `ok` | no-op → `already` |
| `wrong-link-ours` | atomic relink (`ln -sfn` on a temp name then `mv -fn`; or `rm` + `ln -s` if `mv -fn` unsupported) → `created:replaced-broken` semantics; reported as `created` |
| `wrong-link-foreign` | skip → `skipped:foreign-symlink` |
| `broken-ours` | replace → `created:replaced-broken` |
| `broken-foreign` | skip → `skipped:foreign-broken-symlink` |
| `real-file` | skip → `skipped:real-file` |
| `real-dir` | skip → `skipped:real-dir` |

### `install` (R6, R7)

```
DESIRED := plan_links
for each (src, tgt) in DESIRED:
  ensure_parent(dirname(tgt))
  class := classify_target(tgt, src)
  act per table above
emit_summary
exit(max_code)
```

### `uninstall` (R8)

```
DESIRED := plan_links          # for its target-path shape only
MANAGED_ROOTS := [
  "$HOME/.claude/agents/YHTW",           # dir-level link, if it's a link
  "$HOME/.claude/commands/YHTW",
  "$HOME/.claude/team-memory",           # walk for file-level links
]

# 1. Remove managed dir-level links first (if owned_by_us)
for dir_link in (agents/YHTW, commands/YHTW):
  if classify_target(dir_link) is ours → remove_link, report [removed]
  else → report [skipped:not-ours]

# 2. Walk team-memory, pruning every symlink that resolves into this repo,
#    whether or not it's still in the current plan. This catches orphans
#    from prior runs (file renamed / deleted).
find "$HOME/.claude/team-memory" -type l -print0
  | while read -r -d '' link; do
      if owned_by_us(link) → remove_link, report [removed]
      else                 → report [skipped:not-ours]     (actually: only
                                                            report if at a
                                                            planned path; an
                                                            unrelated foreign
                                                            symlink isn't our
                                                            problem)
    done

# 3. Best-effort empty-parent cleanup (R8)
for d in CREATED_DIRS reverse-sorted by depth:
  if d is empty AND d != "$HOME/.claude"  → rmdir d
# NB: CREATED_DIRS is only populated if we ran install/update in the same
# invocation. For a fresh uninstall process, we infer "created by us" by:
# "dir is empty after removal AND is one of the known managed parents".
```

**Subtlety**: uninstall in a fresh process has no memory of which parents it
created. Per R8 ("dirs it would have created"), the fresh-process rule is:
*after* removing links, attempt `rmdir` on each managed parent path
(`~/.claude/team-memory/<role>/`, then `~/.claude/team-memory/`, then
`~/.claude/agents/`, `~/.claude/commands/`) from deepest to shallowest. `rmdir`
on a non-empty dir fails harmlessly; we swallow that and move on. Never try
`~/.claude` itself.

### `update` (R9) — reconciler

```
DESIRED := plan_links
DESIRED_TARGETS := set of target paths in DESIRED

# Pass 1: add/fix
for (src, tgt) in DESIRED:
  apply per R10 table (same as install)

# Pass 2: prune orphans under managed roots
find "$HOME/.claude/team-memory" -type l -print0
  | while read -r -d '' link; do
      if not owned_by_us(link) → continue         # never ours, leave alone
      if link not in DESIRED_TARGETS → remove, report [removed:orphan]
      # else: already handled in pass 1 (was reported as `already` or updated)
    done

# For agents/YHTW and commands/YHTW (dir-level), there are no orphans to
# enumerate beyond the two planned paths themselves — they are either still
# in DESIRED (always are, hardcoded) or not. Nothing to prune.

# Pass 3: empty-parent cleanup as in uninstall
```

`owned_by_us` is the only thing standing between this tool and clobbering user
data. Its definition: `-L $link` AND `resolve_path $(readlink $link)` starts
with `$REPO/.claude/` (trailing slash required to avoid the
`/repo-sibling-foo/.claude` false-positive). Test this function hard.

## 4. Cross-cutting concerns

### Error handling

- `set -u` (unset variables are bugs) and `set -o pipefail`. **Not** `set -e`:
  the whole point is to accumulate conflicts and continue, which `set -e`
  fights. Mutating operations (`ln`, `rm`, `mkdir`) get their own `if !
  <cmd>; then report failure; max_code=1; continue; fi` wrapping.
- `trap 'echo "internal error at line $LINENO" >&2; exit 2' ERR` — optional;
  if used, it must be disabled around classification and mutation loops.
- OS check at start: if `uname` is `MINGW*`, `MSYS*`, or `CYGWIN*`, print a
  message and exit 2 (R16).

### Logging / tracing / metrics

Out of scope. Stdout is the log (R15, R13). No file logging, no metrics.
A future `--verbose` could add per-step `set -x`-style traces; not v1.

### Security / authn / authz posture

- Script runs as the invoking user; never `sudo`. Fails cleanly if `$HOME` is
  unwritable.
- Never follows a symlink to decide ownership — always compares the
  *resolved* link-target path against the *resolved* repo root. Prevents a
  malicious symlink at a managed path from tricking us into
  `rm`-ing something outside the repo.
- `rm` is only ever called on a path we have just classified as a symlink
  (`-L`). Never `rm -r`. Never `rm` a path `classify_target` labeled
  `real-file` or `real-dir`.
- Absolute source paths in link targets (R3): prevents a later `cd` inside the
  script from shifting what the link means.

### Testing strategy (for Developer's TDD)

The script is small and the ROI of a real test harness is high because every
algorithm is on the filesystem.

- **Unit**: `resolve_path`, `owned_by_us`, `classify_target`, and `plan_links`
  are pure-ish. Test via [Bats](https://github.com/bats-core/bats-core) or a
  hand-rolled bash test runner. Given the "no external deps" stance for the
  shipped script, keep test deps out of the runtime path; allow `bats` as a
  dev-only requirement.
- **Integration**: one test per AC1–AC12 in the PRD. Each test spins up a
  throwaway `$HOME` via `mktemp -d`, `export HOME=…`, runs the subcommand, and
  asserts filesystem state + stdout + exit code. These are the primary
  regression harness.
- **Cross-platform**: run the same integration suite on macOS (CI: GitHub
  Actions `macos-latest`) and Linux (`ubuntu-latest`) for AC12.
- **No E2E** beyond that: this tool has no network, no services, no UI.

### Performance / scale targets

Not a concern. Worst case a few hundred files in `team-memory/` and a dozen
commands; single-digit-second runtime is plenty. No optimization needed.

## 5. Open questions / blockers

None.

## 6. Non-decisions (deferred)

- **D7. Makefile / shell-completion / Homebrew formula**: not part of this
  feature. Trigger to revisit: when a non-repo-owner user is expected to run
  the tool.
- **D8. `--force-symlinks`**: PRD R11 defers it. Trigger: user reports
  repeated wrong-symlink conflicts from routine workflows.
- **D9. JSON / machine-readable output**: deferred. Trigger: someone wants to
  script on top of the tool's output.
- **D10. Structured logging / log file**: deferred. Trigger: debugging an
  intermittent cross-machine issue where stdout is insufficient.
- **D11. Link mode for intra-repo source symlinks under `team-memory/`**:
  deferred; today the answer is "follow them as files". Trigger: the repo
  starts committing symlinks inside `team-memory/` intentionally.

## 7. Acceptance checks the Architect stands behind

The Developer must be able to demonstrate, beyond PRD AC1–AC12:

1. **Dry-run parity**. `install --dry-run` followed by `install` produces
   exactly the `would-*` → `*` mapping, line-for-line, on the same host.
2. **Idempotence of `install`**. `install` then `install` again: second run
   reports `already` on every path, exit 0, filesystem byte-identical.
3. **Uninstall cleanliness**. After `install` then `uninstall` on a host
   where `~/.claude/` was absent to start with, `~/.claude/` is either gone
   (if nothing else lives there and the tool created it — note R8 says
   `~/.claude/` itself is never removed, so expect it to remain as an empty
   dir) or contains only content the tool did not create. No leftover
   symlinks under managed roots.
4. **Update adds missing**. Create a new file under
   `.claude/team-memory/<role>/`; `update` links it and reports `created` for
   just that path and `already` for everything else.
5. **Update prunes orphans**. Delete a file under `.claude/team-memory/<role>/`
   after it was linked; `update` removes the now-broken link, reports
   `removed:orphan`, exits 0.
6. **Conflicts exit non-zero**. With a real file at any managed target path,
   `install` and `update` both exit 1 and report `skipped:real-file` for that
   path without touching it.
7. **`owned_by_us` is strict**. A symlink at a managed path whose resolved
   target is `/tmp/fake/.claude/agents/YHTW` (i.e. contains `/.claude/`
   substring but is not inside the real repo) is classified
   `wrong-link-foreign` / `skipped:foreign-symlink`, not touched.
8. **`readlink` portability**. The script passes the full integration suite
   on macOS (bash 3.2, BSD `readlink`) and on Linux (bash 4+, GNU `readlink`)
   with no conditional code paths other than the one inside `resolve_path`.

---

_Decisions count: D1–D6 active (D1 shell, D2 readlink, D3 script path, D4
deps allow-list; plus §2/§3 architecture decisions implicit in the helper
table and `apply_plan` action mapping — counted as D5 classification taxonomy,
D6 uninstall fresh-process cleanup rule). Deferred: D7–D11. No blockers._
