# Tasks — symlink-operation

_2026-04-16 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R16), `04-tech.md` (D1–D6 active),
`05-plan.md` (M1–M10). Every task names the milestone, requirements, and
decisions it lands. `Verify` is a concrete command or filesystem check the
Developer runs at the end of the task; if it passes, the task is done.

All paths below are absolute under
`/Users/yanghungtw/Tools/spec-workflow/`. When this plan says "the script",
it means `bin/claude-symlink` per D3.

---

## T1 — Script skeleton, shebang, OS guard, stub subcommand dispatch
- **Milestone**: M1
- **Requirements**: R14, R16
- **Decisions**: D1, D3, D4
- **Scope**: Create `bin/claude-symlink` as a new executable file. Shebang
  `#!/usr/bin/env bash`. Top matter: `set -u -o pipefail` (do NOT `set -e` per
  plan §3). Print usage + exit 2 on unknown subcommand or no args. OS guard:
  if `uname -s` matches `MINGW*|MSYS*|CYGWIN*`, print a one-line unsupported
  message to stderr and exit 2. Three stub functions `cmd_install`,
  `cmd_uninstall`, `cmd_update` that each just `echo "stub: <name>"` — real
  logic arrives in T7/T8/T9. `main` dispatches to them by positional arg 1.
- **Deliverables**: new file `bin/claude-symlink`; executable bit set
  (`chmod +x`). No other files touched.
- **Verify**:
  - `bash -n bin/claude-symlink` exits 0 (syntax clean).
  - `bin/claude-symlink` (no args) exits 2 and prints usage to stderr.
  - `bin/claude-symlink bogus` exits 2.
  - `bin/claude-symlink install` exits 0 and prints `stub: install`.
  - `test -x bin/claude-symlink` succeeds.
- **Depends on**: —
- [x]

## T2 — Flag parsing: `--dry-run`, `--help`, `-h`
- **Milestone**: M1
- **Requirements**: R12, R14, R15
- **Decisions**: D1, D4
- **Scope**: Single pass over `"$@"` that pulls `--dry-run` (sets
  `DRY_RUN=1`, default 0), `--help` / `-h` (prints usage, exits 0), and
  accepts these flags **anywhere** in argv (before or after the
  subcommand). Everything else collects into a positional array; first
  positional must be `install` / `uninstall` / `update` else exit 2 with
  usage. No `--force`, no `--quiet`, no `--verbose` — reject unknown flags
  with exit 2. Update stub handlers to echo `dry-run=$DRY_RUN` so T-level
  smoke can observe the value.
- **Deliverables**: modifications to `bin/claude-symlink` (parse_flags
  function; dispatch wiring).
- **Verify**:
  - `bin/claude-symlink --help` exits 0 and prints usage including the
    three subcommands and the `--dry-run` flag.
  - `bin/claude-symlink install --dry-run` exits 0 and echoes `dry-run=1`.
  - `bin/claude-symlink --dry-run install` exits 0 and echoes `dry-run=1`
    (flag accepted before subcommand).
  - `bin/claude-symlink install --force` exits 2 with a "unknown flag"
    message on stderr.
- **Depends on**: T1
- [x]

## T3 — `resolve_path` + `resolve_repo_root` (D2, R1)
- **Milestone**: M2
- **Requirements**: R1, R3, R16
- **Decisions**: D1, D2
- **Scope**: Implement pure-bash `resolve_path <p>`: iterative loop,
  `cd "$(dirname "$p")" && p="$(pwd -P)/$(basename "$p")"` style; if the
  basename is itself a symlink, read it with bare `readlink` (no `-f`, no
  `-m`) and continue; cycle cap at 40 iterations — on exceed, `die 2
  "symlink cycle at ..."`. Handles both files and directories.
  `resolve_repo_root` calls `resolve_path "$0"` (or `${BASH_SOURCE[0]}`),
  takes `dirname` twice (strip `/bin/<script>`), caches the result in
  global `REPO`. Add a central `die <code> <msg>` helper (stderr + exit).
  Add a hidden `__probe` subcommand that prints `REPO=$REPO` so T3 and T4
  can be smoke-verified before the full plumbing exists; remove `__probe`
  at T10 or leave it gated behind an env var — TPM leaves that choice to
  the Developer.
- **Deliverables**: helper functions in `bin/claude-symlink`;
  `__probe` subcommand (temporary).
- **Verify**:
  - `bin/claude-symlink __probe` prints
    `REPO=/Users/yanghungtw/Tools/spec-workflow`.
  - From a different cwd: `(cd /tmp && /Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink __probe)`
    prints the same `REPO`.
  - Via a symlink to the script:
    `ln -sfn /Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink /tmp/cs-link && /tmp/cs-link __probe`
    still prints the repo root (not `/tmp`).
  - Cycle test: create `A -> B`, `B -> A` in `/tmp`, assert
    `resolve_path` exits non-zero within 40 iterations, not a hang.
- **Depends on**: T2
- [ ]

## T4 — `owned_by_us` (D6)
- **Milestone**: M2
- **Requirements**: R8
- **Decisions**: D6
- **Scope**: Implement `owned_by_us <path>` → return 0 iff `-L "$path"`
  AND `resolve_path` of the link's target begins with `"$REPO/.claude/"`
  **including the trailing slash**. The trailing slash is mandatory per
  plan §5 (sibling-repo prefix collision watch-item). Callers must have
  `REPO` populated (T3). This function is the sole ownership gate; nothing
  else may decide "ours vs theirs".
- **Deliverables**: `owned_by_us` function in `bin/claude-symlink`; a
  short inline comment spelling out why the trailing slash matters.
- **Verify** (via manual bash-sourced probe or a throwaway temp script):
  - Symlink whose target is inside `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/YHTW`
    → `owned_by_us` returns 0.
  - Symlink whose target is `/tmp/fake/.claude/agents/YHTW` → returns 1
    (foreign).
  - Sibling-repo path `/Users/yanghungtw/Tools/spec-workflow-fork/.claude/…`
    → returns 1 (NOT a prefix match because of trailing slash).
  - Real file (not a symlink) → returns 1.
- **Depends on**: T3
- [ ]

## T5 — `plan_links` (R4, R5)
- **Milestone**: M3
- **Requirements**: R4, R5
- **Decisions**: D1, D4
- **Scope**: Implement `plan_links` that populates global indexed arrays
  `PLAN_SRC` and `PLAN_TGT` (D1: no associative arrays). Two fixed
  directory-level pairs for `agents/YHTW` and `commands/YHTW`. For
  `team-memory`, walk via `find "$REPO/.claude/team-memory" -type f
  -print0` piped through `while IFS= read -r -d '' src; do ...`. Target
  path is `$HOME/.claude/team-memory/<rel>` where `<rel>` is the `src`
  with the `$REPO/.claude/team-memory/` prefix stripped. Emit pairs into
  the arrays; do not print during plan (a debug dump helper may print them
  on demand behind `__probe`). `HOME` must come from env, never hardcoded
  (R2).
- **Deliverables**: `plan_links` function + `__probe plan` variant that
  dumps pairs one-per-line as `<src>\t<tgt>`.
- **Verify**:
  - `HOME=/tmp/fakehome bin/claude-symlink __probe plan | wc -l` equals
    `2 + $(find /Users/yanghungtw/Tools/spec-workflow/.claude/team-memory -type f | wc -l)`.
  - First two lines end with `/tmp/fakehome/.claude/agents/YHTW` and
    `/tmp/fakehome/.claude/commands/YHTW` targets respectively.
  - Every subsequent target starts with `/tmp/fakehome/.claude/team-memory/`.
  - Sources are absolute and all begin with the repo root.
- **Depends on**: T3
- [ ]

## T6 — `classify_target` (R10, D5)
- **Milestone**: M4
- **Requirements**: R9, R10
- **Decisions**: D5, D6
- **Scope**: Implement `classify_target <tgt> <expected_src>` as a pure
  function that echoes exactly one of: `missing`, `ok`, `wrong-link-ours`,
  `wrong-link-foreign`, `broken-ours`, `broken-foreign`, `real-file`,
  `real-dir`. No side effects, no stderr on expected states. Uses `-L`,
  `-e`, `-f`, `-d` tests plus `owned_by_us` and `resolve_path` on the
  current link target compared to `$expected_src`. Follows the case
  ladder in `04-tech.md` §3 verbatim.
- **Deliverables**: `classify_target` function. Developer should add a
  hand-rolled bash test at `test/unit/classify_target.sh` that sets up
  each of the 8 states in a `mktemp -d` sandbox and asserts the echoed
  string matches expectation (per plan M4 verification signal). This is
  the first real test; subsequent tasks lean on the same test harness
  style.
- **Verify**:
  - `bash test/unit/classify_target.sh` exits 0 with 8 green assertions.
  - The test sandbox uses `HOME=$(mktemp -d)/home`; it refuses to run
    against the real `$HOME` (preflight guard; same shape we'll reuse in
    T11).
- **Depends on**: T4, T5
- [ ]

## T7 — `cmd_install` (R6, R7, R10, R12, R13)
- **Milestone**: M5, M8
- **Requirements**: R6, R7, R10, R11, R12, R13
- **Decisions**: D3, D4, D5
- **Scope**: Flesh out `cmd_install`: call `plan_links`; for each pair,
  call `ensure_parent` (mkdir -p, record in `CREATED_DIRS` for later
  uninstall cleanup), then `classify_target`, then dispatch per the R10
  action table. Missing → `create_link` (absolute source per R3, `ln -s
  "$src" "$tgt"`), report `created`. `ok` → report `already`. `broken-ours`
  / `wrong-link-ours` → `rm "$tgt" && ln -s "$src" "$tgt"`, report
  `created:replaced-broken`. All foreign / real states → skip with
  `skipped:<reason>`. Under `DRY_RUN=1`, `create_link` and
  `ensure_parent` become no-ops and verbs become `would-*`. Use a
  `report <verb> <tgt> [<src>]` helper that buffers lines and bumps a
  per-verb counter (sets stage for T10's final summary). Wrap every
  mutation with `if ! cmd; then report_failure; MAX_CODE=1; continue; fi`
  per plan §3.
- **Deliverables**: `cmd_install`, `ensure_parent`, `create_link`,
  `report` helpers in `bin/claude-symlink`.
- **Verify**: `test/unit/cmd_install.sh` (new, hand-rolled) exercises:
  - Clean `HOME=$(mktemp -d)/home` → `install` exits 0; every managed
    target is a symlink; `readlink` of each returns an absolute path
    starting with the repo root (AC10).
  - Second `install` → all verbs are `already`; exit 0; filesystem
    byte-identical (tar or `find ... -exec ls -lnd` diff).
  - Pre-placed real file at `$HOME/.claude/agents/YHTW` →
    `skipped:real-file` for that path, other links still created, exit 1
    (AC3).
  - `install --dry-run` on clean sandbox → every verb is `would-create`,
    zero symlinks on disk afterward (AC9 subset).
- **Depends on**: T6
- [ ]

## T8 — `cmd_uninstall` (R8)
- **Milestone**: M6, M8
- **Requirements**: R8, R13, R14
- **Decisions**: D4, D6
- **Scope**: Flesh out `cmd_uninstall`. Step 1: for each of the two
  dir-level managed paths (`agents/YHTW`, `commands/YHTW`), if
  `owned_by_us` → `rm` the symlink, report `removed`; else report
  `skipped:not-ours` iff the path exists (don't report on truly absent
  paths). Step 2: `find "$HOME/.claude/team-memory" -type l -print0`;
  for each link, if `owned_by_us` → remove, report `removed`; else leave
  silent (per tech §3 subtlety: unrelated foreign links don't warrant
  noise). Step 3: `try_remove_empty_parents` — `rmdir` each known
  managed parent deepest-first, stopping at `$HOME/.claude/` exclusive.
  `rmdir` failures on non-empty dirs are swallowed. NEVER `rm -r`, NEVER
  touch `$HOME/.claude/` itself. Honor `DRY_RUN=1` with `would-remove`.
- **Deliverables**: `cmd_uninstall`, `remove_link`,
  `try_remove_empty_parents` helpers.
- **Verify**: `test/unit/cmd_uninstall.sh` exercises:
  - After `install`, `uninstall` → no tool-owned symlinks remain under
    any managed root; exit 0 (AC4).
  - A hand-placed real file under
    `$HOME/.claude/team-memory/shared/notes.md` is untouched after
    `uninstall` (AC4).
  - A hand-placed symlink at a managed path pointing to `/tmp/decoy` is
    reported `skipped:not-ours` and left untouched.
  - `$HOME/.claude/` directory still exists post-uninstall.
  - If `$HOME/.claude/team-memory/shared/` is empty after removals, it
    is `rmdir`ed (AC5); if it contains an unrelated file, it is left.
- **Depends on**: T4, T5, T7 (for `remove_link` primitive & `report` helper reuse)
- [ ]

## T9 — `cmd_update` (R9)
- **Milestone**: M7, M8
- **Requirements**: R9, R10, R13, R14
- **Decisions**: D5, D6
- **Scope**: Flesh out `cmd_update`. Pass 1: identical to `cmd_install`
  (adds + fixes, including `broken-ours` replace per R9). Pass 2: build a
  `DESIRED_TARGETS` set (indexed array + linear `case` match since D1
  forbids associative arrays — OK at this size), walk
  `find "$HOME/.claude/team-memory" -type l -print0`, for each link that
  is `owned_by_us` AND whose path is not in `DESIRED_TARGETS`, remove and
  report `removed:orphan`. Foreign / unrelated links: left alone, not
  reported. Pass 3: `try_remove_empty_parents` same as uninstall. Honor
  `DRY_RUN=1` with `would-remove` for orphans.
- **Deliverables**: `cmd_update` wiring in `bin/claude-symlink`;
  reuse existing helpers from T7/T8. Refactor T7's install loop into a
  shared `apply_plan` helper if the duplication is ugly — keep the
  refactor scoped.
- **Verify**: `test/unit/cmd_update.sh` exercises:
  - After `install`, create
    `.claude/team-memory/shared/glossary.md` in the repo → `update`
    reports `created` only for that path, `already` for everything else,
    exit 0 (AC6). **Important**: test must work on a repo copy or clean
    up the new file in a `trap EXIT`; do not leave drift in the real
    repo.
  - After `install`, delete a file that was linked → `update` reports
    `removed:orphan` for the stranded link, exits 0 (AC7).
  - A foreign broken symlink under a managed team-memory path is left
    alone and not reported as ours (AC7).
  - Real-file conflict at a managed path → `update` skips that path,
    still reconciles others, exit 1 (AC8).
- **Depends on**: T7, T8
- [ ]

## T10 — `emit_summary` + final exit code wiring (R13, R14, R15)
- **Milestone**: M8
- **Requirements**: R13, R14, R15
- **Decisions**: D1, D4
- **Scope**: Finalize `report` / `emit_summary`. Every subcommand ends
  with one call to `emit_summary` which flushes the buffered per-path
  lines in the order they were reported, then prints
  `summary: created=N already=N removed=N skipped=N  (exit CODE)` on the
  last stdout line. `MAX_CODE` starts at 0; bumps to 1 on any
  `skipped:conflict:*` / mutation failure / orphan-prune failure; 2 only
  via `die` at precondition stage. Final line of the program is
  `exit "$MAX_CODE"`. Remove (or env-gate) the `__probe` subcommand from
  T3/T5 before shipping. Confirm every verb emitted is in the R13 closed
  set; grep-audit: `report ` calls should use only the closed verb tags.
- **Deliverables**: finalized `report` / `emit_summary`; removed
  `__probe` (or gated behind `YHTW_PROBE=1`).
- **Verify**:
  - `test/unit/summary.sh` — for each of install/uninstall/update, at
    least one clean run and one conflict run, assert:
    - Last stdout line starts with `summary:`.
    - Clean run exit 0 and summary ends `(exit 0)`.
    - Conflict run exit 1 and summary ends `(exit 1)`.
  - `bin/claude-symlink` source grep — every verb argument to `report`
    matches the closed set: `created|created:replaced-broken|already|removed|removed:orphan|skipped:[^ ]+|would-[a-z:-]+`.
  - `bin/claude-symlink __probe` (if not env-gated) exits 2 as an
    unknown subcommand.
- **Depends on**: T7, T8, T9
- [ ]

## T11 — Smoke harness `test/smoke.sh` covering AC1–AC12
- **Milestone**: M9
- **Requirements**: R12, R13, R14, R16; covers AC1–AC12
- **Decisions**: D1, D4
- **Scope**: Write `test/smoke.sh` as a single bash driver. Hard
  preflight: refuse to run unless `$HOME` is already redirected to a
  `mktemp -d` path — specifically, the script sets
  `SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink')`
  (D1 + plan §5 portability note), then `export HOME="$SANDBOX/home"`,
  then `mkdir -p "$HOME"`, then verifies `$HOME` starts with the sandbox
  path before running any scenario. If the check fails, `exit 2` with a
  loud message — DO NOT run against real `$HOME` (plan §5 watch-item).
  Scenarios (one function per AC):
  - `ac1_clean_install`, `ac2_idempotent_install`,
    `ac3_real_file_conflict`, `ac4_uninstall_scope`,
    `ac5_empty_dir_cleanup`, `ac6_update_adds_missing`,
    `ac7_update_prunes_orphans`, `ac8_update_conflict`,
    `ac9_dry_run_no_mutation` (uses `find ... -exec stat ... | sort`
    hash before/after), `ac10_absolute_link_targets`,
    `ac11_report_exit_consistency`, `ac12_cross_platform` (noop marker:
    prints uname; real check is running the script on both OSes).
  For AC6/AC7 which mutate the repo, use a per-scenario `trap EXIT`
  cleanup so the real repo is never left dirty; alternatively rsync the
  repo's `.claude/` tree into the sandbox and run the script from that
  copy via a symlink — Developer's call.
- **Deliverables**: new file `test/smoke.sh`; `test/fixtures/` if the
  scenarios need canned files.
- **Verify**:
  - `bash test/smoke.sh` exits 0 on a clean repo checkout on macOS.
  - Running with `HOME=/Users/yanghungtw` (real $HOME) aborts with
    exit 2 and a preflight message before any mutation.
  - Every scenario prints `AC<n>: PASS` or `AC<n>: FAIL`; non-zero exit
    iff any FAIL.
- **Depends on**: T10
- [ ]

## T12 — Docs: script header + README section
- **Milestone**: M10
- **Requirements**: R3, R11, R15
- **Decisions**: D3
- **Scope**: Two touches.
  1. Top-of-script comment block in `bin/claude-symlink`: usage, the
     three subcommands, `--dry-run`, exit-code semantics (0/1/2), the
     managed set (agents/YHTW dir, commands/YHTW dir, team-memory/**
     files), and a one-liner that content conflicts resolve manually
     (R11 — no `--force`).
  2. README section (append to `README.md` at repo root, or create a
     fresh README if none exists — TPM prefers appending to the existing
     one if present). Sections to include: What it does · Install /
     uninstall / update invocation · `--dry-run` preview · Supported
     platforms (macOS + Linux, bash 3.2+) · Recovery from a moved repo
     (re-run `install`, which will replace broken-ours links — R3) ·
     Conflict reference: for each `skipped:<reason>`, the manual
     remediation (inspect, back up, `rm`, re-run). Also note the
     orphan-walk sharp edge flagged in plan §5: a user-created symlink
     under `team-memory/` that happens to point into this repo IS
     indistinguishable from one we made and will be pruned by `update`
     if it's not in the current plan — documented, not a bug.
  No other docs changes.
- **Deliverables**: header comment in `bin/claude-symlink`; appended /
  new section in `/Users/yanghungtw/Tools/spec-workflow/README.md`.
- **Verify**:
  - `bin/claude-symlink --help` output contains the same usage lines
    that appear in the header comment (parity).
  - README section covers every item in the scope list above; can be
    skimmed by QA-analyst in T-next gap-check.
  - No content changes to `.claude/` source trees.
- **Depends on**: T11
- [ ]

---

## Sequencing notes

- Strict spine: **T1 → T2 → T3 → T4, T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12**.
- T4 and T5 can be built in either order once T3 lands (both depend on
  `REPO`).
- T7 / T8 / T9 are sequential as written because T8 reuses T7's
  `report` helper and T9 reuses both. If the Developer wants parallelism,
  land the shared `report` / `emit_summary` skeleton (subset of T10)
  earlier; otherwise keep it linear for a simpler diff.
- T10 is listed after T7–T9 because the closed verb-set audit is best
  done once every call site exists. Partial summary wiring can land
  inside T7 as a rough draft.

## Task sizing

Target: each task ≤ 60 min of focused Developer work. The largest are
T7 and T11; both have natural split points (T7: install happy path vs.
conflict branches; T11: AC1–AC4 batch vs. AC5–AC12 batch) if the
Developer finds them slipping. Split and renumber only via
`/YHTW:update-task` — don't fork ad hoc.

---

## STATUS Notes

- 2026-04-16 Developer — T1 done (script skeleton, OS guard, dispatch stubs)
- 2026-04-16 Developer — T2 done (flag parsing: --dry-run, --help/-h, unknown-flag rejection)
