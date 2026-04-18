# Tasks — per-project-install

_2026-04-18 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R13), `04-tech.md` (D1–D12 primary; D13–D20
deferred), `05-plan.md` (W0–W6). Every task names the wave, requirements, and
decisions it lands. `Verify` is a concrete runnable command (or filesystem
check) the Developer runs at the end of the task; if it passes, the task is
done.

All paths below are absolute under `/Users/yanghungtw/Tools/spec-workflow/`.
"The seed tool" means `bin/specflow-seed` per D2. "The source repo" means
this repo (the clone `bin/specflow-seed` runs from).

Wave schedule lives at the bottom; R↔T trace table immediately below it.

---

## T1 — `bin/specflow-seed` skeleton + subcommand dispatcher
- **Wave**: W0
- **Requirements**: R2 (scaffold only; no mutation yet), R13 (portability + no-force posture from day one)
- **Decisions**: D2 (one multi-subcommand bash script), D12 (smoke harness reuse)
- **Scope**: Create the new file `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` (exec bit set) per D2. Pure bash 3.2, BSD userland only; no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic, no `rm -rf`, no `--force` (cross-ref `.claude/rules/bash/bash-32-portability.md`, `.claude/rules/common/no-force-on-user-paths.md`). Structure:
  1. **Header** — shebang `#!/usr/bin/env bash`; `set -u -o pipefail` (NOT `-e` — accumulate-and-continue error model per 04-tech.md §4; mirrors `bin/claude-symlink`).
  2. **Helpers ported from `bin/claude-symlink`** — `die <msg>` (log to stderr, `exit 2`); `resolve_path` (the BSD-safe 40-hop loop from `.claude/rules/bash/bash-32-portability.md` Example); `repo_root` resolver (prefers `git rev-parse --show-toplevel` at cwd, falls back to `pwd -P`).
  3. **Preflight** — refuse to run if `python3` is missing (`command -v python3 >/dev/null || die "python3 required"`). D4 tradeoff: manifest write requires Python 3 at install-time; fail-fast loud.
  4. **Flag parser** — recognise `--dry-run`, `--from <path>`, `--to <ref>`, `--ref <ref>`, `--help`. Stored in plain shell vars (`DRY_RUN=0`, `SRC=""`, `TO_REF=""`, `AT_REF=""`). No GNU `getopt` (portability).
  5. **Subcommand dispatcher** — `case "$1" in init|update|migrate|__probe) ... ;; -h|--help|"") usage ;; *) die "unknown subcommand: $1" ;; esac`. The `__probe` arm is the hidden classifier harness slot reserved for Wave 1.
  6. **Stub bodies** — `cmd_init() { echo "init: not-yet-implemented"; exit 0; }`; same for `cmd_update` / `cmd_migrate`. No filesystem mutation on any invocation in W0.
  7. **Exit-code contract scaffolded** — `MAX_CODE=0` global; `emit_summary` stub that prints `summary: created=0 already=0 replaced=0 skipped=0 (exit 0)` (populated in W2–W4). Exit semantics per R7/AC7.c: 0 = all converged; 1 = any skip or mutation failure; 2 = usage / unresolvable source / python3 missing / corrupt manifest.
  8. **`chmod +x`** the new file.
- **Deliverables**: one new file `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` (exec bit set). No other files touched.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` succeeds.
  - `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed --help` exits 0.
  - `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed init 2>&1 | grep -q 'not-yet-implemented'` AND exit code 0.
  - Same for `update` and `migrate` stubs.
  - `grep -En 'readlink -f|realpath|jq|mapfile|rm -rf| --force| -f "--force"' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns empty (no prohibited tokens even at scaffold stage).
  - Sandbox invariant: invoke any stub under `HOME=$(mktemp -d)`; `find "$HOME" -mindepth 1` returns empty (stubs do not mutate).
- **Depends on**: —
- **Parallel-safe-with**: — (sole task in W0)
- [x]

---

## T2 — Classifier + manifest IO + plan_copy library (bundled)
- **Wave**: W1
- **Requirements**: R1 (machine-readable ref), R4 (team-memory skeleton generation), R5 (rules copy), R6 (closed-enum classifier, pure function, dispatcher table — the crux rule), R13 (portability, no-force)
- **Decisions**: D3 (manifest JSON schema — quoted verbatim below), D4 (tri-hash baseline — pseudocode quoted verbatim below), D5 (port `classify_copy_target` from `classify_target`), D11 (write-temp + `os.replace` per-file — no `cp -R`)
- **Scope**: Extend `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` in place with the shared library code consumed identically by `cmd_init` / `cmd_update` / `cmd_migrate`. Per `05-plan.md` §7 recommendation (a), bundle the three placeholder tasks (classifier, manifest IO, plan_copy) into ONE task — small blast radius (~150 lines of bash + Python 3 heredocs), shared TDD anchor (hidden `__probe`), no external contract.

  **Per `tpm/briefing-contradicts-schema.md`**: the D3 manifest schema and D4 classifier pseudocode below are quoted VERBATIM from `04-tech.md` §3. Do not paraphrase. Do not rewrite. Paste as-is; let the schema shape the code, not vice versa.

  **D3 manifest JSON schema (verbatim from 04-tech.md §3):**

  ```json
  {
    "schema_version": 1,
    "specflow_ref": "<sha>",
    "source_remote": "<url>",
    "applied_at": "<iso8601>",
    "files": { "<relpath>": "<sha256>", ... }
  }
  ```

  **D4 classifier pseudocode (verbatim from 04-tech.md §3):**

  ```
  classify_copy_target(consumer_root, relpath, expected_sha_at_new_ref, manifest) →
    dst = consumer_root + "/" + relpath
    if ! -e dst && ! -L dst:
        return "missing"
    if -L dst:
        return "real-file-conflict"    # we never create symlinks here (R1)
    if -d dst:
        return "real-file-conflict"    # dir where a file is expected
    if ! -f dst:
        return "real-file-conflict"    # other non-regular files (fifo, device)
    actual_sha = sha256(dst)
    if actual_sha == expected_sha_at_new_ref:
        return "ok"
    baseline_sha = manifest.files[relpath]    # may be absent (first-appeared-in-new-ref)
    if baseline_sha is None:
        # File is new in the new ref, but the destination already has content at
        # that path. The user must have created it manually — cannot be ours.
        return "user-modified"
    if actual_sha == baseline_sha:
        return "drifted-ours"
    return "user-modified"
  ```

  **D4 dispatcher table (verbatim from 04-tech.md §3):**

  ```
  case state in
    missing)             write_with_atomic_swap(dst, content);  report "created" ;;
    ok)                  report "already" ;;
    drifted-ours)        cp "$dst" "$dst.bak"; write_with_atomic_swap(dst, content); report "replaced:drifted"; ;;
    user-modified)       report "skipped:user-modified"; MAX_CODE=1 ;;
    real-file-conflict)  report "skipped:real-file-conflict"; MAX_CODE=1 ;;
    foreign)             report "skipped:foreign"; MAX_CODE=1 ;;
  esac
  ```

  Concrete deliverables inside `bin/specflow-seed`:

  1. **`sha256_of <path>`** — dispatches by `uname -s`. Darwin/*BSD → `shasum -a 256 "$1" | awk '{print $1}'`. Linux/* → `sha256sum "$1" | awk '{print $1}'`. Python 3 fallback if neither binary present. Matches the `to_epoch` dispatch-wrapper shape from `.claude/rules/bash/bash-32-portability.md`.
  2. **`manifest_read <path>`** — Python 3 heredoc reads the file; asserts `schema_version == 1`, `specflow_ref` non-empty, `files` is a dict. On any schema mismatch or JSON parse error, print `manifest: corrupt` to stderr and exit 2 (fail-loud per D4 tradeoff). Emits a two-column `relpath<TAB>sha256` stream on stdout for bash consumption.
  3. **Bash-only ref sniff** — `awk -F'"' '/"specflow_ref"/ { print $4; exit }' "$manifest"` — exactly the form from 04-tech.md §3 D3 "Tradeoffs". Used by callers that only need the ref (not the full file map) and as a defensive fallback.
  4. **`manifest_write <path> <ref> <source_remote> <files-tsv>`** — Python 3 heredoc. Reads the TSV of `relpath<TAB>sha256` rows from stdin; builds the dict; assembles the full v1 object per D3 schema verbatim above; writes to `<path>.tmp`; `os.replace(tmp, path)`. Atomic swap per D11, `.bak` by caller (here we produce a fresh manifest; backup discipline applies at `cmd_update` / `cmd_migrate` call-sites when overwriting an existing manifest).
  5. **`classify_copy_target <consumer_root> <relpath> <expected_sha> <baseline_sha>`** — pure function implementing the D4 pseudocode above. Stdout emits exactly one of the six enum strings. No mutation. Baseline `""` (empty string) represents "absent from manifest" per the pseudocode's `None` branch. A pre-commit mental check: diff this function line-by-line against the pseudocode block; they must match branch-for-branch.
  6. **`plan_copy <src_root> <mode>`** — enumerates the managed relpath set. `mode=init|migrate` includes the team-memory skeleton (one synthesized `index.md` per role dir listed in `.claude/team-memory/` of the source repo, plus `shared/README.md` and `shared/index.md` — empty-but-present per R4 "no inherited lesson content"). `mode=update` OMITS the team-memory skeleton entirely (R4/R8 — `update` never touches team-memory). Also includes every file under `.claude/agents/specflow/`, `.claude/commands/specflow/`, `.claude/hooks/`, `.claude/rules/`, `.spec-workflow/features/_template/`. Emits a flat bash-array-friendly newline-separated relpath list on stdout.
  7. **Atomic-write Python 3 helper** — `write_atomic <dst> <content-on-stdin>`: Python 3 heredoc reads bytes from stdin, writes to `<dst>.tmp`, calls `os.replace(tmp, dst)`. No partial-write window. Used by every D4 dispatcher "write" arm.
  8. **Hidden `__probe` subcommand** — Wave 1's TDD harness. Accepts `__probe classify <consumer_root> <relpath> <expected_sha> <baseline_sha>` and prints the classifier verdict; `__probe manifest-roundtrip <path>` reads then re-writes a manifest to a sibling temp and asserts byte-identity; `__probe plan <src_root> <mode>` prints the planned relpath list. Hidden (not documented in `--help`); sole purpose is to let Wave 1 and beyond fuzz the library in isolation.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed`. No other files touched.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` exits 0.
  - `bin/specflow-seed __probe classify "$(mktemp -d)" ".claude/agents/specflow/architect.md" "abc" ""` prints `missing` on a fresh temp root.
  - Classifier branch-table coverage: a shell fixture script (inline in this verify, not a separate test file) creates one file per enum state under a mktemp `$CR` root, invokes `__probe classify` with the corresponding `expected_sha` / `baseline_sha` tuples, and greps each of the six enum strings (`missing`, `ok`, `drifted-ours`, `user-modified`, `real-file-conflict`, `foreign`) at least once in the combined output. Closed-enum coverage per R6.
  - Manifest round-trip byte-identity: write a fixture manifest via `manifest_write`, run `__probe manifest-roundtrip` on it; second write byte-matches the first (`cmp` returns 0).
  - Corrupt-manifest fail-loud: create a manifest with `schema_version: 99` and run `manifest_read`; exit code 2, stderr contains `manifest: corrupt`, no filesystem mutation.
  - `plan_copy` relpath count matches `find .claude/agents/specflow .claude/commands/specflow .claude/hooks .claude/rules .spec-workflow/features/_template -type f | wc -l` plus `( 7 role dirs + 1 shared dir ) * 2 - 1 = 15` synthesized team-memory skeleton paths (or the exact count derived from the source tree — assert equality, don't hardcode).
  - `grep -En 'readlink -f|realpath|jq|mapfile|rm -rf| --force' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns empty.
- **Depends on**: T1
- **Parallel-safe-with**: — (sole task in W1; all code lives in `bin/specflow-seed` which collides with itself)
- [x]
- 2026-04-18 Developer — implement: classifier + manifest IO + plan_copy library bundled into bin/specflow-seed; all 7 verify assertions pass; 581 lines

---

## T3 — `cmd_init` dispatcher + hook wiring
- **Wave**: W2
- **Requirements**: R1 (ref recorded), R2 (init seeds fresh consumer), R3 (single global artefact — init references the skill path, not the other way around), R4 (team-memory skeleton), R5 (rules copy), R6 (classifier dispatch), R7 (per-state action table), R13 (no-force, classify-before-mutate)
- **Decisions**: D2, D4 (dispatcher), D5, D7 (source discovery: `--from` > `$SPECFLOW_SRC` > auto-discover — same fallback reused by init), D8 (hook wiring via `<src>/bin/specflow-install-hook`), D11 (per-file atomic write)
- **Scope**: Implement `cmd_init` inside `bin/specflow-seed`. Consumes the Wave 1 library verbatim.
  1. **Arg parsing** — accept `--from <path>` (source repo), `--ref <ref>` (pin), `--dry-run`. Resolve source per D7 layered fallback (arg → env → `readlink ~/.claude/agents/specflow` with `bin/specflow-seed` + `.claude/agents/specflow/` structural markers → exit 2 with clear error). Resolve consumer via `repo_root` helper.
  2. **Preflight** — assert `<src>/bin/specflow-install-hook` is present (D8 tradeoff: init refuses to proceed if the helper isn't reachable). Assert `<src>/.claude/agents/specflow/`, `<src>/.claude/commands/specflow/`, `<src>/.claude/hooks/`, `<src>/.claude/rules/`, `<src>/.spec-workflow/features/_template/` all exist. No filesystem mutation before preflight passes.
  3. **Plan** — invoke `plan_copy <src> init`. For each relpath, compute `expected_sha = sha256_of <src>/<relpath>` (team-memory skeleton paths use the synthesized empty-ish content's SHA).
  4. **Classify + dispatch** — for each planned relpath: on a fresh consumer every path classifies `missing`; dispatcher writes via `write_atomic` and appends `<relpath>\t<expected_sha>` to the manifest-files-tsv accumulator. Dispatcher table verbatim per T2 / D4.
  5. **`--dry-run` early-return** — after the plan is built and classified, if `$DRY_RUN=1`, print `would-<verb>` lines for each dispatched state (`would-create`, `would-replace:drifted`, `would-skip:user-modified`, etc.) and return WITHOUT any write. Filesystem state must be byte-identical before/after a dry-run (hash-verify in T4).
  6. **Manifest authoring** — on non-dry-run success (including if `MAX_CODE=0`), invoke `manifest_write <consumer>/.claude/specflow.manifest <ref> <source_remote> <stdin-tsv>`. `source_remote` resolved via `git -C <src> config --get remote.origin.url` (best-effort; empty string if unset). `applied_at` = `date -u +%FT%TZ`.
  7. **Hook wiring per D8** — after manifest is authored, invoke `<src>/bin/specflow-install-hook add SessionStart .claude/hooks/session-start.sh` then `add Stop .claude/hooks/stop.sh`, both referencing CONSUMER-LOCAL paths (never `~/.claude/hooks/…`). The helper is idempotent and applies its own `.bak` + atomic swap on `<consumer>/settings.json`.
  8. **Summary** — emit the standard `created=N already=N replaced=N skipped=N (exit K)` line per R7/AC7.c. Exit `$MAX_CODE`.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed`. No other files.
- **Verify**:
  - `bash -n bin/specflow-seed` exits 0; `bash test/t39_init_fresh_sandbox.sh` exits 0; `bash test/t40_init_idempotent.sh` exits 0; `bash test/t41_init_preserves_foreign.sh` exits 0 (requires T4/T5/T6 landed — cross-task smoke coverage).
  - `bin/specflow-seed init --dry-run --from $(pwd) --ref HEAD` inside a fresh-consumer mktemp produces per-path `would-*` lines AND a byte-identical filesystem (`find "$CR" -type f | xargs shasum | sort | shasum` identical before/after).
- **Depends on**: T2
- **Parallel-safe-with**: T4, T5, T6 (tests are different new files)
- [x]
- 2026-04-18 Developer — implement: cmd_init dispatcher + hook wiring; all verify assertions pass; 864 lines (+243 vs W1 close)

---

## T4 — `test/t39_init_fresh_sandbox.sh`
- **Wave**: W2
- **Requirements**: R1 AC1.a + AC1.c (no symlinks, bytes match), R2 AC2.a (self-contained install, settings.json wired), R4 AC4.a (skeleton dirs only), R5 AC5.a (rules copied)
- **Decisions**: D3 (manifest present + ref correct), D8 (hook paths are consumer-local), D12 (sandbox-HOME discipline)
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t39_init_fresh_sandbox.sh` (exec bit set). Pure bash 3.2 per `.claude/rules/bash/bash-32-portability.md`. Sandbox-HOME per `.claude/rules/bash/sandbox-home-in-tests.md` — NON-NEGOTIABLE.
  1. `SANDBOX=$(mktemp -d)`; `trap 'rm -rf "$SANDBOX"' EXIT`; `export HOME="$SANDBOX/home"`; `mkdir -p "$HOME"`; case-pattern preflight `case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac`.
  2. Create fresh consumer repo at `$SANDBOX/consumer` — `git init -q`, `git config user.email t@example.com`, `git config user.name t`, write a `.gitignore` + one commit so `repo_root` resolves.
  3. From inside `$SANDBOX/consumer`, run `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed init --from /Users/yanghungtw/Tools/spec-workflow --ref "$(git -C /Users/yanghungtw/Tools/spec-workflow rev-parse HEAD)"`.
  4. **Assert AC1.a** — every file under `$SANDBOX/consumer/.claude/agents/specflow/`, `…/commands/specflow/`, `…/hooks/` is a regular file (`test -f ... && test ! -L ...`) AND `shasum` matches the corresponding source file at the captured ref.
  5. **Assert AC1.c** — `find $SANDBOX/consumer/.claude -type l` returns empty.
  6. **Assert AC2.a** — `.claude/agents/specflow/`, `…/commands/specflow/`, `…/hooks/`, `…/rules/`, `.spec-workflow/features/_template/` all populated; `$SANDBOX/consumer/.claude/specflow.manifest` exists; `$SANDBOX/consumer/settings.json` contains exactly one SessionStart and one Stop `"command"` entry, and both `command` strings reference `.claude/hooks/` (consumer-local), not `~/.claude/hooks/`.
  7. **Assert AC4.a** — list `.claude/team-memory/*/`; the set equals `{pm, designer, architect, tpm, developer, qa-analyst, qa-tester, shared}` (or whatever the source repo ships — derive from `ls /Users/yanghungtw/Tools/spec-workflow/.claude/team-memory/`); each role dir contains ONLY its `index.md` (and optional README); `find $SANDBOX/consumer/.claude/team-memory -name '*.md' -not -name 'index.md' -not -name 'README.md'` is empty.
  8. **Assert AC5.a** — every file under `$SANDBOX/consumer/.claude/rules/` has a byte-matching source counterpart.
  9. **Assert** — manifest's `specflow_ref` equals the captured git SHA (grep-sniff via the D3 `awk -F'"' '/"specflow_ref"/'` pattern).
  10. `echo PASS` / exit 0 on all passes; `FAIL: <label>: <reason>` / exit 1 on any miss.
  11. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t39_init_fresh_sandbox.sh` (exec bit set). Test does NOT self-register in `test/smoke.sh` (T19 is single-editor).
- **Verify**:
  - `bash -n test/t39_init_fresh_sandbox.sh` exits 0; `test -x test/t39_init_fresh_sandbox.sh` succeeds.
  - `bash test/t39_init_fresh_sandbox.sh` exits 0 (requires T3 merged; RED pre-T3 for the right reason: init stub echoes "not-yet-implemented").
- **Depends on**: T2 (classifier + manifest library exists)
- **Parallel-safe-with**: T3, T5, T6
- [x]
- 2026-04-18 Developer — implement: test/t39_init_fresh_sandbox.sh created; syntax OK, exec bit set, sandbox-HOME preflight present; RED on current HEAD (init stub not-yet-implemented)

---

## T5 — `test/t40_init_idempotent.sh`
- **Wave**: W2
- **Requirements**: R2 AC2.b (second init at same ref → byte-identical state, every path `already`)
- **Decisions**: D3, D12; `architect/byte-identical-refactor-gate.md` discipline
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t40_init_idempotent.sh` (exec bit set). Sandbox-HOME per template.
  1. Sandbox + preflight (same boilerplate as t39).
  2. Create fresh consumer + initial `init --from <this-repo> --ref <sha>` (first run).
  3. Capture a hash tree of `$SANDBOX/consumer` — `FIND_HASH_1=$(find "$SANDBOX/consumer" -type f -not -path '*/\.git/*' -exec shasum {} \; | sort | shasum | awk '{print $1}')`.
  4. Run `init` a SECOND time at the same ref.
  5. Assert output contains `already` for multiple paths AND does NOT contain `created` (every path already converged).
  6. Assert exit code 0 AND `MAX_CODE` summary line shows `skipped=0`.
  7. Capture `FIND_HASH_2` identically; assert `[ "$FIND_HASH_1" = "$FIND_HASH_2" ]` — byte-identical before/after second run.
  8. `echo PASS` / exit 0; `FAIL` / exit 1.
  9. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t40_init_idempotent.sh` (exec bit set). No smoke.sh registration (T19).
- **Verify**:
  - `bash -n test/t40_init_idempotent.sh` exits 0; `test -x` succeeds.
  - `bash test/t40_init_idempotent.sh` exits 0 (requires T3 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T3, T4, T6
- [x] 2026-04-18 Developer — implement: test/t40_init_idempotent.sh created (exec bit set); RED pre-T3 (init stub)

---

## T6 — `test/t41_init_preserves_foreign.sh`
- **Wave**: W2
- **Requirements**: R2 AC2.c (pre-existing non-byte-identical destination → classifier + R7 conflict policy, no silent overwrite), R7 AC7.c (exit-code contract on skip), R7 AC7.d (no force)
- **Decisions**: D4 (classifier `real-file-conflict` + `user-modified` states), D11 (no `cp -R`); sandbox-HOME template
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t41_init_preserves_foreign.sh` (exec bit set). Plan §4 §7 explicitly reserved this slot for AC2.c and deferred split-decision to tasks stage — splitting is correct: AC2.c is a distinct behavioral assertion (destination exists as non-byte-identical real file OR as a directory where a file is expected) and deserves its own focused fixture.
  1. Sandbox + preflight.
  2. Create fresh consumer at `$SANDBOX/consumer` (same boilerplate).
  3. **Variant A — real file at a managed path** (user-modified-before-init). Pre-create `$SANDBOX/consumer/.claude/agents/specflow/architect.md` with content `not the real architect.md`. Run `init`; assert output contains `skipped:user-modified` for that path; assert the file content is STILL `not the real architect.md` (untouched); assert exit code is non-zero (per AC7.c).
  4. **Variant B — directory at a file path**. Fresh sandbox; pre-create `$SANDBOX/consumer/.claude/hooks/session-start.sh/` as a directory. Run `init`; assert `skipped:real-file-conflict` reported for that path; directory still present and empty; exit code non-zero.
  5. **Variant C — symlink at a managed path**. Fresh sandbox; `ln -s /tmp/nowhere $SANDBOX/consumer/.claude/agents/specflow/architect.md`. Run `init`; assert `skipped:real-file-conflict` reported (R1 forbids symlinks in the consumer tree; the classifier treats a pre-existing symlink as a conflict); symlink still present. Exit code non-zero.
  6. For all three variants: assert `grep -rn ' --force\| -f \|rm -rf' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` returns empty (AC7.d structural check).
  7. `echo PASS` / exit 0; `FAIL: variant <X>: <reason>` / exit 1.
  8. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t41_init_preserves_foreign.sh` (exec bit set). No smoke.sh registration (T19).
- **Verify**:
  - `bash -n test/t41_init_preserves_foreign.sh` exits 0; `test -x` succeeds.
  - `bash test/t41_init_preserves_foreign.sh` exits 0 (requires T3 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T3, T4, T5
- [x] 2026-04-18 Developer — implement

---

## T7 — `cmd_update` dispatcher with tri-hash baseline + ref-advance gate
- **Wave**: W3
- **Requirements**: R1 (ref recorded → read), R4 AC4.b (update never touches team-memory), R6, R7, R8 AC8.a (advance on clean), R8 AC8.b (no-advance on conflict), R8 AC8.c (team-memory untouched), R13
- **Decisions**: D3 (manifest read), D4 (tri-hash — the crux), D6 (`--to <ref>` required, no default-HEAD), D11
- **Scope**: Implement `cmd_update` inside `bin/specflow-seed`.
  1. **Arg parsing** — require `--to <ref>`. If omitted, `die "--to <ref> required"` (exit 2 per D6).
  2. **Manifest read** — resolve consumer via `repo_root`; require `<consumer>/.claude/specflow.manifest` present else `die "no manifest; run init or migrate first"` (exit 2 — D13 opt-out-bypass trace per `shared/opt-out-bypass-trace-required.md`). Invoke `manifest_read` to get `previous_ref` + `files_map`. Log `update: previous-ref <prev>; target-ref <to>` to stdout (AC1.b).
  3. **Plan** — `plan_copy <src> update` (team-memory skeleton OMITTED per R4/R8).
  4. **Classify + dispatch** (tri-hash per D4) — for each relpath: `expected_sha = sha256_of <src at to-ref>/<relpath>`; `baseline_sha = files_map[relpath]` (empty if absent); `actual_sha` computed on consumer's current on-disk file. Invoke `classify_copy_target`; dispatch per R7 table.
  5. **`--dry-run`** — same pattern as T3: emit `would-*` lines, early-return, no writes.
  6. **Ref-advance gate** — if `MAX_CODE != 0` (any `skipped:*`), do NOT rewrite the manifest; emit summary; exit `$MAX_CODE`. Per AC8.b: manifest ref stays at the pre-update value so a subsequent `update --to <to-ref>` re-attempts after the user resolves the conflict.
  7. **Clean-run manifest rewrite** — if `MAX_CODE == 0`, rebuild the full `files-tsv` (every planned relpath's new-ref SHA) and invoke `manifest_write` with the new ref. Backup-before-replace: before the `os.replace`, copy the existing manifest to `<manifest>.bak` (matches R7 AC7.b discipline applied to the manifest file itself).
  8. **Team-memory walk prohibition** — the implementation MUST NOT issue any read/write call whose path includes `.claude/team-memory/` during `cmd_update`. T10 is the machine-checkable guard; the code review should confirm no such path appears in any dispatch arm of `cmd_update`.
  9. Emit summary; exit `$MAX_CODE`.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed`. No other files.
- **Verify**:
  - `bash -n bin/specflow-seed` exits 0.
  - `bash test/t42_update_no_conflict.sh` exits 0; `bash test/t43_update_user_modified.sh` exits 0; `bash test/t44_update_never_touches_team_memory.sh` exits 0 (requires T8–T10 landed).
  - `bin/specflow-seed update` (no `--to`) exits 2 with `--to <ref> required` on stderr.
  - `bin/specflow-seed update --to HEAD` in a consumer missing the manifest exits 2 with `no manifest; run init or migrate first` on stderr.
- **Depends on**: T2, T3 (init must land first so update has a consumer to operate against in tests)
- **Parallel-safe-with**: T8, T9, T10
- [x]

---

## T8 — `test/t42_update_no_conflict.sh`
- **Wave**: W3
- **Requirements**: R7 AC7.b (replaced:drifted + `.bak` discipline), R8 AC8.a (advance on clean)
- **Decisions**: D3, D4, D11, D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t42_update_no_conflict.sh` (exec bit set). Sandbox + preflight.
  1. Build a fixture "source at ref-B" tree — `cp -R /Users/yanghungtw/Tools/spec-workflow/.claude $SANDBOX/src-at-ref-b/.claude`; edit ONE file under `$SANDBOX/src-at-ref-b/.claude/agents/specflow/` with a one-line change to synthesize ref-B. Build matching `bin/`, `.spec-workflow/features/_template/` structural markers.
  2. `init` the consumer from THIS repo at HEAD (ref-A).
  3. Capture consumer's pre-update state of the soon-to-change file.
  4. Run `specflow-seed update --to fake-ref-b --from $SANDBOX/src-at-ref-b` (see note below on `--from` — update may need this to be implementation-discovered; if update uses the manifest's pinned source path rather than `--from`, adapt the fixture to point at the fixture src — document whichever the T7 implementation chose).
  5. Assert the edited file reports `replaced:drifted`; assert `<consumer>/<relpath>.bak` exists and byte-matches the pre-update content; assert current `<consumer>/<relpath>` byte-matches the ref-B source content.
  6. Assert every other managed file reports `already`.
  7. Assert `specflow-seed`'s manifest ref advanced: `awk -F'"' '/"specflow_ref"/ {print $4; exit}' <consumer>/.claude/specflow.manifest` equals `fake-ref-b`.
  8. Assert exit code 0.
  9. `echo PASS` / exit 0; `FAIL` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t42_update_no_conflict.sh` (exec bit set). No smoke.sh edit (T19).
- **Verify**:
  - `bash -n test/t42_update_no_conflict.sh` exits 0; `test -x` succeeds.
  - `bash test/t42_update_no_conflict.sh` exits 0 (requires T7 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T7, T9, T10
- [x] 2026-04-18 Developer — implement: test/t42_update_no_conflict.sh created; RED (stub exits 0, no replaced:drifted); GREEN requires T7

---

## T9 — `test/t43_update_user_modified.sh`
- **Wave**: W3
- **Requirements**: R7 AC7.a (skipped:user-modified leaves file untouched, exit non-zero), R8 AC8.b (ref NOT advanced on conflict; revert-then-re-run advances)
- **Decisions**: D3, D4, D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t43_update_user_modified.sh` (exec bit set). Sandbox + preflight.
  1. Build ref-B fixture (same shape as T8) — one source file changed.
  2. `init` consumer at ref-A.
  3. Hand-edit a DIFFERENT consumer file (one that also changed in ref-B, so the classifier sees `actual != expected` and `actual != baseline` → `user-modified`). Save pre-edit and post-edit contents.
  4. Run `update --to fake-ref-b …`.
  5. Assert the hand-edited file reports `skipped:user-modified` AND its content is BYTE-IDENTICAL to the user's post-edit value (untouched by update).
  6. Assert every OTHER changed file still reports `replaced:drifted` (conflict on one path does not halt the run).
  7. Assert manifest ref UNCHANGED — still the pre-update ref. Grep-sniff the manifest.
  8. Assert exit code non-zero.
  9. **Revert-then-re-run** — revert the hand-edit by writing the ref-A baseline content back to the file (so classifier sees `actual == baseline` → `drifted-ours`). Re-run `update --to fake-ref-b`. Assert the file now reports `replaced:drifted`, manifest ref advances to `fake-ref-b`, exit 0.
  10. `echo PASS` / exit 0; `FAIL: <step>: <reason>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t43_update_user_modified.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t43_update_user_modified.sh` exits 0; `test -x` succeeds.
  - `bash test/t43_update_user_modified.sh` exits 0 (requires T7 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T7, T8, T10
- [x] 2026-04-18 Developer — implement test/t43_update_user_modified.sh (R7 AC7.a + R8 AC8.b; two-file fixture, user-modified skip + revert-then-re-run)

---

## T10 — `test/t44_update_never_touches_team_memory.sh`
- **Wave**: W3
- **Requirements**: R4 AC4.b (no flow writes to consumer's team-memory during update), R8 AC8.c (team-memory files unread/unwritten/undeleted)
- **Decisions**: D3 (team-memory omitted from plan_copy `update` mode); D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t44_update_never_touches_team_memory.sh` (exec bit set). Sandbox + preflight.
  1. `init` a fresh consumer at ref-A.
  2. Seed a "local lesson" in the consumer's team-memory: `echo 'local lesson' > $SANDBOX/consumer/.claude/team-memory/developer/my-lesson.md`. Capture its mtime + content.
  3. Build the usual ref-B source fixture.
  4. Capture an mtime+hash tree of `$SANDBOX/consumer/.claude/team-memory/` — `TM_HASH_1=$(find "$SANDBOX/consumer/.claude/team-memory" -type f -exec shasum {} \; -exec stat -f '%m' {} \; | sort | shasum)` (BSD `stat` — Linux fallback: `stat -c '%Y' {}`; dispatch by `uname -s`).
  5. Run `update --to fake-ref-b`. Confirm exit 0.
  6. Recompute `TM_HASH_2`; assert `[ "$TM_HASH_1" = "$TM_HASH_2" ]` — mtime tree unchanged (nothing read, nothing written).
  7. Assert `$SANDBOX/consumer/.claude/team-memory/developer/my-lesson.md` still has the `local lesson` content byte-identically.
  8. `echo PASS` / exit 0; `FAIL: <reason>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t44_update_never_touches_team_memory.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t44_update_never_touches_team_memory.sh` exits 0; `test -x` succeeds.
  - `bash test/t44_update_never_touches_team_memory.sh` exits 0 (requires T7 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T7, T8, T9
- [x] 2026-04-18 Developer — implement

---

## T11 — `cmd_migrate` dispatcher with D10 shared-symlink abstention
- **Wave**: W4
- **Requirements**: R9 (migrate semantics), R9 AC9.a (other projects' `~/.claude/` data unaffected — D10 load-bearing), R9 AC9.b (idempotent re-run), R9 AC9.c (--dry-run byte-identical three roots), R9 AC9.d (user-modified skip + symlinks stay), R10 AC10.a (claude-symlink external contract preserved), R13
- **Decisions**: D4, D7 (source discovery layered fallback), D8 (hook wiring), D10 (symlink-teardown abstention — the PRD R9 body-text contradiction; implementation follows D10 + AC9.a per 05-plan.md §3 R2 risk mitigation), D11
- **Scope**: Implement `cmd_migrate` inside `bin/specflow-seed`. 05-plan.md §3 R2 flags the PRD R9 body-text mismatch — the implementation MUST follow D10 and AC9.a, NOT R9's body text. Quoted D10 guidance verbatim from 04-tech.md §3:

  > **B — leave all global symlinks in place; document that `bin/claude-symlink uninstall` is the manual teardown step once every consumer on the machine has migrated.** `migrate` only rewires `<consumer>/settings.json` to point at local hooks.

  1. **Arg parsing** — `--from <path>`, `--ref <ref>` (optional; default to source-clone HEAD per D6 divergence for migrate), `--dry-run`.
  2. **Source discovery per D7 layered fallback** — (1) `--from`; (2) `$SPECFLOW_SRC`; (3) auto-discover via `readlink ~/.claude/agents/specflow` (portable `readlink`, no `-f`); (4) `die "no source repo; pass --from or set SPECFLOW_SRC or ensure ~/.claude/agents/specflow resolves"` exit 2.
  3. **Source-assertion (security, §4)** — resolved `<src>` MUST contain both `bin/specflow-seed` and `.claude/agents/specflow/`. Refuse to proceed otherwise (`die` exit 2).
  4. **Ref resolution** — `<ref>` = arg or `git -C <src> rev-parse HEAD`.
  5. **Plan + classify + dispatch** — reuse the `plan_copy <src> migrate` + classifier + dispatcher from T2/T3. Same R7 action table. `--dry-run` early-return same as T3.
  6. **Manifest authoring** — on clean run, same shape as `cmd_init`: `manifest_write <consumer>/.claude/specflow.manifest …`.
  7. **`settings.json` rewiring (D8)** — ON CLEAN RUN ONLY (`MAX_CODE == 0`): invoke `<src>/bin/specflow-install-hook remove SessionStart ~/.claude/hooks/session-start.sh` (if present in settings.json — the helper is idempotent), then `remove Stop ~/.claude/hooks/stop.sh`, then `add SessionStart .claude/hooks/session-start.sh`, then `add Stop .claude/hooks/stop.sh`. Each call applies its own `.bak` + atomic swap. On conflict run (any `skipped:user-modified`), DO NOT rewrite `settings.json` (per AC9.d).
  8. **D10 abstention — NO symlink teardown**. `cmd_migrate` MUST NOT remove, modify, or `readlink -f` any path under `~/.claude/`. Code review check: `grep -En 'HOME/\.claude|\$HOME/\.claude|~/.claude' bin/specflow-seed` should show only the D7 discovery `readlink` call and NO `rm`/`mv`/`ln`/write operation against `$HOME/.claude/*`.
  9. **Idempotence** — re-running `migrate` on an already-migrated consumer: every path classifies `ok` (manifest matches current), manifest is not rewritten (no-op atomic), settings.json helper is idempotent (no-op if already correct). Every path reports `already`; exit 0 per AC9.b.
  10. Emit summary; exit `$MAX_CODE`.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed`. No other files.
- **Verify**:
  - `bash -n bin/specflow-seed` exits 0.
  - `bash test/t45_migrate_from_global.sh` exits 0; `bash test/t46_migrate_dry_run.sh` exits 0; `bash test/t47_migrate_user_modified.sh` exits 0 (requires T12–T14).
  - `grep -En 'HOME/\.claude|\$HOME/\.claude|~/.claude' bin/specflow-seed` shows only source-discovery read, no write.
- **Depends on**: T2, T3 (init flow exists; migrate structurally mirrors init's copy path)
- **Parallel-safe-with**: T12, T13, T14
- [x] 2026-04-18 Developer — implement

---

## T12 — `test/t45_migrate_from_global.sh`
- **Wave**: W4
- **Requirements**: R9 AC9.a (other projects' `~/.claude/` data unaffected), R9 AC9.b (idempotent re-run), R10 AC10.a (global symlinks still resolve to `<src>` after migrate)
- **Decisions**: D8 (settings.json rewired consumer-local), D10 (shared-symlink abstention load-bearing), D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t45_migrate_from_global.sh` (exec bit set). Sandbox + preflight. This is the D10 behavioral guard — a regression here would be catastrophic per 05-plan.md §3 R2.
  1. Sandbox `$HOME="$SANDBOX/home"` + case-pattern preflight. **Doubly load-bearing**: this test mutates `$HOME/.claude/` subtree structure.
  2. **Pre-stage a global install** — `mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/hooks-parent" "$HOME/.claude/team-memory-parent"`; `ln -s /Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow "$HOME/.claude/agents/specflow"`; same for `commands/specflow`, `hooks`, and per-role `team-memory/*` (match whatever `bin/claude-symlink install` produces on a real machine — verify structural parity by running `bin/claude-symlink install` against the sandbox first and asserting its output). All symlink targets ABSOLUTE per `.claude/rules/common/absolute-symlink-targets.md`.
  3. **Pre-stage a consumer** — `$SANDBOX/consumer`; `git init -q`; write a `settings.json` with SessionStart + Stop entries pointing at `$HOME/.claude/hooks/session-start.sh` and `$HOME/.claude/hooks/stop.sh` (the pre-migration wiring shape).
  4. **Add a "foreign" file under `~/.claude/`** — `echo 'unrelated' > $HOME/.claude/other-project-marker`. This is the AC9.a "unrelated content" anchor.
  5. Capture the hash of `$HOME/.claude/` EXCLUDING the agents/commands/hooks symlinks (since those resolve outside the sandbox) — hash the symlink-target strings themselves via `ls -l` output instead of `shasum`, to prove the links are preserved byte-identically. Also capture hash of `$HOME/.claude/other-project-marker`.
  6. Run `/Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed migrate --from /Users/yanghungtw/Tools/spec-workflow` from inside `$SANDBOX/consumer`.
  7. **Assert AC9.a** — `$HOME/.claude/other-project-marker` byte-identical before/after; `ls -l $HOME/.claude/agents/specflow` shows the same target string (symlink UNTOUCHED); same for commands/specflow, hooks, team-memory.
  8. **Assert AC10.a shape** — `readlink $HOME/.claude/agents/specflow` resolves to `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow` (unchanged).
  9. **Assert AC9.b** — `$SANDBOX/consumer/.claude/specflow.manifest` exists; `settings.json` now has `command` strings referencing `.claude/hooks/session-start.sh` (consumer-local). Re-run `migrate`; every path reports `already`; exit 0; consumer state byte-identical.
  10. Exit code 0 on first run AND re-run.
  11. `echo PASS` / exit 0; `FAIL: <label>: <reason>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t45_migrate_from_global.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t45_migrate_from_global.sh` exits 0; `test -x` succeeds.
  - `bash test/t45_migrate_from_global.sh` exits 0 (requires T11 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T11, T13, T14
- [ ] 2026-04-18 Developer — implement: created test/t45_migrate_from_global.sh (D10 shared-symlink abstention guard; RED until T11 merged)

---

## T13 — `test/t46_migrate_dry_run.sh`
- **Wave**: W4
- **Requirements**: R6 AC6.a (dry-run byte-identical), R9 AC9.c (migrate --dry-run byte-identical on consumer, source, ~/.claude/)
- **Decisions**: D10 (no mutation anywhere on dry-run), D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t46_migrate_dry_run.sh` (exec bit set). Sandbox + preflight.
  1. Pre-stage global install + consumer + settings.json exactly as t45 step 2–3.
  2. Capture hash trees of all three roots: `CONS_H1=$(find $SANDBOX/consumer -type f -not -path '*/\.git/*' | sort | xargs shasum | shasum)`; `HOME_H1=$(ls -lR $HOME/.claude | shasum)` (captures symlink target strings too); `SRC_H1=$(find /Users/yanghungtw/Tools/spec-workflow/.claude -type f | sort | xargs shasum | shasum)`.
  3. Run `specflow-seed migrate --dry-run --from /Users/yanghungtw/Tools/spec-workflow`.
  4. Assert output contains `would-create` lines for the expected relpath set (non-empty).
  5. Recompute `CONS_H2`, `HOME_H2`, `SRC_H2`; assert all three pairs equal (AC9.c).
  6. Exit code 0 on dry-run.
  7. `echo PASS` / exit 0; `FAIL: <root>: <before>!=<after>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t46_migrate_dry_run.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t46_migrate_dry_run.sh` exits 0; `test -x` succeeds.
  - `bash test/t46_migrate_dry_run.sh` exits 0 (requires T11 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T11, T12, T14
- [x] 2026-04-18 Developer — implement: created test/t46_migrate_dry_run.sh (200 lines); three-root hash capture present; bash -n + exec-bit verified; RED on stub (plan-empty)

---

## T14 — `test/t47_migrate_user_modified.sh`
- **Wave**: W4
- **Requirements**: R9 AC9.d (user-modified → skip; global symlinks in place; settings.json NOT rewired; exit non-zero)
- **Decisions**: D4, D10, D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t47_migrate_user_modified.sh` (exec bit set). Sandbox + preflight.
  1. Pre-stage global install + consumer + settings.json (shape from t45).
  2. Pre-create a `user-modified` file in the consumer — e.g. `mkdir -p $SANDBOX/consumer/.claude/agents/specflow; echo 'user edit' > $SANDBOX/consumer/.claude/agents/specflow/architect.md`.
  3. Capture pre-migration settings.json hash AND `$HOME/.claude/agents/specflow` symlink target string.
  4. Run `specflow-seed migrate --from /Users/yanghungtw/Tools/spec-workflow`.
  5. Assert the user-modified file reports `skipped:user-modified`.
  6. Assert exit code non-zero.
  7. Assert the user-modified file content is STILL `user edit` (untouched).
  8. Assert `settings.json` hash UNCHANGED (migrate did not rewire; still points at `~/.claude/hooks/*`).
  9. Assert `$HOME/.claude/agents/specflow` symlink target UNCHANGED (D10 abstention holds even on failure path).
  10. `echo PASS` / exit 0; `FAIL: <step>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t47_migrate_user_modified.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t47_migrate_user_modified.sh` exits 0; `test -x` succeeds.
  - `bash test/t47_migrate_user_modified.sh` exits 0 (requires T11 merged).
- **Depends on**: T2
- **Parallel-safe-with**: T11, T12, T13
- [ ]

---

## T15 — `.claude/skills/specflow-init/` — SKILL.md + init.sh
- **Wave**: W5
- **Requirements**: R3 (single global artefact — this is the one), R3 AC3.b (footprint bounded and enumerable)
- **Decisions**: D1 (skill distribution via `cp -R`)
- **Scope**: Create the NEW directory `/Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/` (the `.claude/skills/` tree does not yet exist per 04-tech.md §1). Two files:
  1. **`SKILL.md`** — per D1 sketch, verbatim frontmatter + body from 04-tech.md §3 D1:

     ```markdown
     ---
     name: specflow-init
     description: Seed a target repo with a per-project specflow install (init/update/migrate).
     ---

     # /specflow-init

     Locate the user's source-repo clone (env `SPECFLOW_SRC` or prompt),
     invoke `<src>/bin/specflow-seed <subcmd>` with args inferred from the
     user's task description. Subcommands: init / update / migrate.
     ```

     The two frontmatter keys (`name`, `description`) are the Claude Code global-skill convention. Do not add extra keys without checking the convention documented in the tech doc.
  2. **`init.sh`** — tiny bootstrap helper invoked by the skill body. Pure bash 3.2. Structure:
     - `#!/usr/bin/env bash`; `set -u -o pipefail`.
     - Resolve source: `SRC="${SPECFLOW_SRC:-}"`. If empty, print a user-facing prompt to stderr and `exit 2` (non-interactive fail-fast — the skill's agent body handles the prompt interactively).
     - Validate: assert `$SRC/bin/specflow-seed` exists and is executable; else `die` with remediation.
     - `exec "$SRC/bin/specflow-seed" "$@"` — pass-through, no business logic.
     - `chmod +x init.sh`.
  3. `chmod +x` on `init.sh` (SKILL.md is not executable).
- **Deliverables**: two new files under a new directory. No other files touched.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/init.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/init.sh` succeeds.
  - `grep -q '^name: specflow-init$' /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/SKILL.md` AND `grep -q '^description:' …/SKILL.md`.
  - `bash test/t49_init_skill_bootstrap.sh` exits 0 (requires T17 merged — but T17 is authored in this same wave; TDD shape: red-first OK).
- **Depends on**: — (new directory, no code dependency on T1–T14)
- **Parallel-safe-with**: T16, T17, T18, T19, T20 (all different files / different editor)
- [ ]

---

## T16 — `test/t48_seed_rule_compliance.sh`
- **Wave**: W5
- **Requirements**: R13 AC13.a (bash portability rule compliance), R13 AC13.c (no `rm -rf` / `--force` / unconditional overwrite)
- **Decisions**: D12; cross-ref `.claude/rules/bash/bash-32-portability.md`, `.claude/rules/common/no-force-on-user-paths.md`
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t48_seed_rule_compliance.sh` (exec bit set). STATIC test — does not sandbox `$HOME` (no CLI invocation; pure grep + `bash -n`).
  1. Assert `grep -rEn 'readlink -f|realpath|jq[^\.]|mapfile|readarray|rm -rf| --force' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/` returns empty. (The `jq[^\.]` pattern tolerates `jq.` references in doc comments but catches binary invocations.)
  2. Assert `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` exits 0.
  3. Assert `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/init.sh` exits 0.
  4. Assert `grep -c 'set -u' /Users/yanghungtw/Tools/spec-workflow/bin/specflow-seed` ≥ 1 (strict-mode convention).
  5. `echo PASS` / exit 0; `FAIL: <prohibited-token>: <hit-line>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t48_seed_rule_compliance.sh` (exec bit set). No smoke.sh edit (T19).
- **Verify**:
  - `bash -n test/t48_seed_rule_compliance.sh` exits 0; `test -x` succeeds.
  - `bash test/t48_seed_rule_compliance.sh` exits 0 (requires T1, T2, T15 merged — but T15 may land in same wave; red-first OK).
- **Depends on**: —
- **Parallel-safe-with**: T15, T17, T18, T19, T20
- [ ]

---

## T17 — `test/t49_init_skill_bootstrap.sh`
- **Wave**: W5
- **Requirements**: R3 AC3.b (init skill footprint is enumerable + bounded)
- **Decisions**: D1
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t49_init_skill_bootstrap.sh` (exec bit set). STATIC test.
  1. Assert `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/SKILL.md`.
  2. Assert `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/skills/specflow-init/init.sh` AND `test -x …/init.sh`.
  3. Assert SKILL.md frontmatter shape — the first line is `---`; a subsequent `name: specflow-init` line appears; a `description:` line appears; the block is closed by a second `---` line before the body.
  4. Assert `bash -n …/init.sh` exits 0.
  5. Assert the directory tree under `.claude/skills/specflow-init/` contains EXACTLY those two files (no stray fixtures): `find .claude/skills/specflow-init -type f | wc -l` equals 2.
  6. Assert the `cp -R` bootstrap is documented in `README.md` — `grep -q 'cp -R.*\.claude/skills/specflow-init.*~/.claude/skills/' /Users/yanghungtw/Tools/spec-workflow/README.md` (requires T20 merged; TDD shape acceptable).
  7. `echo PASS` / exit 0; `FAIL: <assertion>` / exit 1; `chmod +x`.
- **Deliverables**: new file `test/t49_init_skill_bootstrap.sh` (exec bit set). No smoke.sh edit.
- **Verify**:
  - `bash -n test/t49_init_skill_bootstrap.sh` exits 0; `test -x` succeeds.
  - `bash test/t49_init_skill_bootstrap.sh` exits 0 (requires T15 + T20 merged).
- **Depends on**: —
- **Parallel-safe-with**: T15, T16, T18, T19, T20
- [ ]

---

## T18 — `test/t50_dogfood_staging_sentinel.sh`
- **Wave**: W5
- **Requirements**: R10 AC10.a (pre-W6 staging: `bin/claude-symlink` external contract preserved; `~/.claude/agents/specflow` still resolves to `<src>`)
- **Decisions**: `shared/dogfood-paradox-third-occurrence.md` (this sentinel gates W6); D12
- **Scope**: Create `/Users/yanghungtw/Tools/spec-workflow/test/t50_dogfood_staging_sentinel.sh` (exec bit set). THIS TEST IS A PRE-CONDITION SENTINEL FOR WAVE 6 — the orchestrator MUST check this is green before running T21.

  **Unusual sandbox shape**: this test exercises the REAL `~/.claude/` state of the developer's machine (because AC10.a asserts the live global install still works). BUT it does so strictly read-only (dry-runs, `readlink`, `test` — no `ln`/`rm`/`mv`/`install` that mutates). The test is allowed to skip the sandbox-HOME preflight discipline ONLY because every invocation is provably read-only; verify this claim with a post-test check that the machine's `~/.claude/` hash is byte-identical before and after the test runs.
  1. Capture `HOME_HASH_1=$(ls -lR "$HOME/.claude" 2>/dev/null | shasum)`.
  2. Assert `bin/claude-symlink install --dry-run` exits 0 (R10 AC10.a; the `install` subcommand supports `--dry-run` per `bin/claude-symlink`'s existing external contract).
  3. Assert `bin/claude-symlink uninstall --dry-run` exits 0.
  4. Assert `bin/claude-symlink update --dry-run` exits 0.
  5. Assert `readlink "$HOME/.claude/agents/specflow"` returns the absolute path `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow`.
  6. Capture `HOME_HASH_2`; assert `[ "$HOME_HASH_1" = "$HOME_HASH_2" ]` — sentinel itself is provably read-only.
  7. `echo PASS` / exit 0; `FAIL: <assertion>` / exit 1; `chmod +x`.

  **Runtime coupling note** — this test becomes RED after T21 runs (by design; T21 tears the pointer). T21's developer notes explicitly document that after T21 lands, t50 is expected to be red on this repo and is removed from the smoke.sh registration in the same commit as T21. Mention this in T21's scope.
- **Deliverables**: new file `test/t50_dogfood_staging_sentinel.sh` (exec bit set). No smoke.sh edit in this task (T19 registers).
- **Verify**:
  - `bash -n test/t50_dogfood_staging_sentinel.sh` exits 0; `test -x` succeeds.
  - `bash test/t50_dogfood_staging_sentinel.sh` exits 0 PRIOR TO T21 running on this repo.
- **Depends on**: —
- **Parallel-safe-with**: T15, T16, T17, T19, T20
- [ ]

---

## T19 — `test/smoke.sh` single-editor registration bundle
- **Wave**: W5
- **Requirements**: R13 AC13.a / AC13.b flow-level coverage (all new smoke tests registered); harness completeness
- **Decisions**: D12; `tpm/parallel-safe-append-sections.md` (single editor for smoke.sh)
- **Scope**: Edit `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` — add registrations for exactly these 11 new tests: `t39`, `t40`, `t41`, `t42`, `t43`, `t44`, `t45`, `t46`, `t47`, `t48`, `t49`, `t50` → **12 tests** (T6 split added t41, making the total 12 not 11). Final tally: existing 38 + 12 = 50 tests. Follow the existing registration pattern (append after t38 — do not renumber existing rows). Tests DO NOT self-register (per `.spec-workflow/archive/20260417-shareable-hooks/06-tasks.md` T8 / B2.b precedent). This task is the SINGLE editor of `smoke.sh` for this feature; zero append collisions by design.

  **Note on t50**: register t50 (dogfood sentinel). After T21 lands (W6), t50 is expected to flip RED on this repo (by design) — T21's commit note documents the removal-or-archival of t50 registration in smoke.sh at that point. T19 leaves t50 registered; T21 deregisters.
- **Deliverables**: edit to `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh`. No new files.
- **Verify**:
  - `bash -n test/smoke.sh` exits 0.
  - `bash test/smoke.sh` exits 0 when run AFTER T3, T7, T11, T15 have all landed — output shows PASS for t39–t50; final tally ≥ 50/50.
  - `grep -c '^t39_\|^t40_\|^t41_\|^t42_\|^t43_\|^t44_\|^t45_\|^t46_\|^t47_\|^t48_\|^t49_\|^t50_' test/smoke.sh` ≥ 12 (all new tests registered — pattern depends on existing registration shape; adjust the grep to match).
- **Depends on**: T4, T5, T6, T8, T9, T10, T12, T13, T14, T16, T17, T18 (every test file must exist before registration; otherwise `bash test/smoke.sh` exits non-zero)
- **Parallel-safe-with**: T15, T20 (different file; different editor)
- [x] implement
- 2026-04-18 Developer — registered t39-t50 in test/smoke.sh for-loop; bash -n passes; grep count 12

---

## T20 — `README.md` — install flow + deprecation + verb vocabulary
- **Wave**: W5
- **Requirements**: R11 AC11.a (top-level Install section describes `init` first), R11 AC11.b (deprecation notice on `bin/claude-symlink` + `bin/specflow-install-hook` sections with link to `migrate`), R11 AC11.c (grep-verifiable: `grep -l "migrate"` and `grep -l "deprecated"` both find README.md), R12 AC12.a (verb vocabulary table enumerates every emitted verb with remediation pointer), R12 AC12.b (no flow emits a verb outside the documented closed set)
- **Decisions**: D9 (committed `.claude/` + manifest — documentation consequence); D10 (migrate abstention — "run `bin/claude-symlink uninstall` manually once every consumer migrated" is the user-facing story)
- **Scope**: Edit `/Users/yanghungtw/Tools/spec-workflow/README.md`. Single editor for README in this feature; all R11 + R12 content bundled into one pass per 05-plan.md §7 guidance.
  1. **Add top-level "Install" or "Getting started" section at the top of the README** — present `init` as the first command a new consumer runs. Describe the global skill bootstrap (`cp -R <src>/.claude/skills/specflow-init ~/.claude/skills/`), then the skill invocation (`/specflow-init` from inside a target consumer repo), then what it does (seeds agents/commands/hooks/team-memory/rules; records the ref in `specflow.manifest`). Do NOT describe the legacy `~/.claude/` symlink model as current.
  2. **Describe `update` and `migrate`** — `update` re-copies at a newly-chosen ref with skip-and-report on user-modified files (backup on drifted). `migrate` converts an existing global-symlink consumer to per-project without touching the shared `~/.claude/` symlinks (the user runs `bin/claude-symlink uninstall` manually once every consumer on the machine has migrated — per D10).
  3. **Explain the per-project isolation guarantee** — each consumer is pinned to its own ref; team-memory is local and never travels back; two consumers on the same machine can run different specflow versions concurrently (PRD goal 1).
  4. **Deprecation notice on existing sections** — the existing "bin/claude-symlink" section and any "Per-project opt-in" section that references `bin/specflow-install-hook add SessionStart ~/.claude/hooks/…` get a **deprecation banner** at the top: `> **Deprecated** — superseded by the per-project `migrate` flow (see §Install). `bin/claude-symlink` is retained only to maintain existing installs until every consumer on the machine has migrated.` Include an explicit link/anchor to the Install / `migrate` section.
  5. **Recovery path** — a one-paragraph "if your consumer's ref needs to change" subsection pointing at `update --to <new-ref>` and, if the update fails, at the `.bak` files the flow produces.
  6. **Verb vocabulary table (R12)** — one table with one row per verb. Closed set derived from D4 dispatcher + R12 PRD body:

     | Verb | Meaning | Remediation |
     |---|---|---|
     | `created` | New file written at a previously-missing path. | None — expected on first init. |
     | `already` | Destination is byte-identical to source at the chosen ref. | None. |
     | `replaced:drifted` | Destination differed from source but matched the previous-ref baseline in the manifest — replaced with new content; `<path>.bak` holds the pre-replace bytes. | Inspect `.bak`; delete once satisfied. |
     | `skipped:user-modified` | Destination differs from source AND differs from the baseline — user edit preserved. | Decide whether to keep the edit (copy to `.bak`, then re-run `update`) or discard it (restore from baseline, then re-run). |
     | `skipped:real-file-conflict` | Destination is a directory, symlink, or non-regular file where a regular file is expected. | Remove the offending path manually, then re-run. |
     | `skipped:foreign` | Destination is outside the managed subtree. | Should not occur; file a bug if observed. |
     | `would-created` / `would-replaced:drifted` / `would-skipped:*` | `--dry-run` preview of the above; no mutation. | None. |

     Note at the bottom of the table: "No flow emits a verb outside this set; if a future verb is introduced, the table must be updated first (AC12.b)."
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/README.md`. No other files.
- **Verify**:
  - `grep -l 'migrate' /Users/yanghungtw/Tools/spec-workflow/README.md` returns the path (AC11.c).
  - `grep -l -i 'deprecated' /Users/yanghungtw/Tools/spec-workflow/README.md` returns the path (AC11.c).
  - `grep -q 'cp -R.*\.claude/skills/specflow-init.*~/.claude/skills/' README.md` (bootstrap documented per D1).
  - `grep -q 'replaced:drifted' README.md` AND `grep -q 'skipped:user-modified' README.md` AND `grep -q 'skipped:real-file-conflict' README.md` AND `grep -q 'would-' README.md` (every verb in the vocabulary table — AC12.a).
  - `grep -q 'specflow-seed init' README.md` AND `grep -q 'specflow-seed update' README.md` AND `grep -q 'specflow-seed migrate' README.md` (AC11.a — installed command surface appears verbatim).
  - Spot-check sibling test `bash test/t49_init_skill_bootstrap.sh` passes (step 6 of that test greps the bootstrap line).
- **Depends on**: —
- **Parallel-safe-with**: T15, T16, T17, T18, T19 (all different files / different editors)
- [ ]

---

## T21 — Dogfood migration of this repo (final act)
- **Wave**: W6
- **Requirements**: R10 AC10.b (this repo migrated to per-project as final feature task), R10 AC10.c (structural-only verify is the archive gate; runtime confirmation on next feature after session restart per `shared/dogfood-paradox-third-occurrence.md`)
- **Decisions**: D10 (leave global `~/.claude/*` symlinks in place — they may still serve un-migrated consumers); `architect/byte-identical-refactor-gate.md` applied to the consumer-vs-source subtree comparison
- **Scope**: Run the live migration of THIS repo from the global-symlink model to per-project install. Absolutely the LAST task of this feature — nothing follows.

  **Pre-conditions (the orchestrator MUST verify before letting this task mutate)**:
  - `bash test/t50_dogfood_staging_sentinel.sh` exits 0 (AC10.a holds).
  - T15 (skill) + T20 (README) are landed (otherwise a freshly-cloned developer can't reproduce the migration).
  - `git status` is clean on this branch — a failed dogfood leaves `.bak` artefacts that must be inspectable.

  **Mutation sequence** (matches `bin/specflow-seed migrate` against this repo):
  1. From `/Users/yanghungtw/Tools/spec-workflow/`, run `bin/specflow-seed migrate --from .`.
  2. **Byte-identity assertion (architect/byte-identical-refactor-gate.md)** — the copy from `<src>` to `<src>` is a no-op for every managed file (source and consumer are the same tree). The flow's per-file classifier emits `already` for EVERY managed path. Assert: output contains no `created`, no `replaced:*`; only `already` lines AND the manifest-write step. Hash-verify: `find .claude -type f -not -path '*/\.git/*' | sort | xargs shasum | shasum` is IDENTICAL before and after the migrate invocation.
  3. **Manifest created** — `.claude/specflow.manifest` now exists with `specflow_ref` = `git rev-parse HEAD`, `source_remote` = this repo's remote URL, `files` map populated per D3.
  4. **settings.json rewired** — `bin/specflow-install-hook` (invoked by migrate) swaps `~/.claude/hooks/session-start.sh` → `.claude/hooks/session-start.sh` and the Stop pair. A `settings.json.bak` is produced by the helper.
  5. **Global symlinks UNTOUCHED per D10** — `readlink ~/.claude/agents/specflow` still resolves to this repo's `.claude/agents/specflow`. Same for commands/specflow, hooks, team-memory. Un-migrated consumers on the machine continue to resolve via these symlinks (the whole reason for D10).
  6. **Test deregistration** — `test/t50_dogfood_staging_sentinel.sh` is by design now RED (AC10.a asserted *pre-migration* state; post-migration, `~/.claude/agents/specflow` still resolves but the point of t50 has passed). In this SAME commit: remove t50's registration line from `test/smoke.sh` (single append collision with T19's addition — T21 is post-T19 so no parallel conflict). Keep the test file itself on disk as a historical artifact.
  7. **STATUS Notes** — append to `/Users/yanghungtw/Tools/spec-workflow/.spec-workflow/features/20260418-per-project-install/STATUS.md`: `- 2026-04-18 | tpm | T21 dogfood migration complete — this repo is now its own per-project consumer; .claude/specflow.manifest created at ref <sha>; settings.json rewired to local hooks (.bak available); global ~/.claude/* symlinks left in place per D10 for any un-migrated consumer on this machine.`
  8. **Commit note** — the git commit message for this task must include: "This is the dogfood-final task per PRD R10. Runtime confirmation of `init` / `update` / `migrate` against a fresh external consumer is deferred to the next feature after session restart, per `shared/dogfood-paradox-third-occurrence.md`."
- **Deliverables**:
  - NEW `/Users/yanghungtw/Tools/spec-workflow/.claude/specflow.manifest` (created by the migrate flow).
  - REWIRED `/Users/yanghungtw/Tools/spec-workflow/settings.json` hook paths (local instead of `~/.claude/hooks/*`); produces `settings.json.bak`.
  - EDIT `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` — remove t50 registration line.
  - APPEND STATUS.md Notes line.
  - No other filesystem changes.
- **Verify**:
  - `test -f /Users/yanghungtw/Tools/spec-workflow/.claude/specflow.manifest` succeeds; `awk -F'"' '/"specflow_ref"/ {print $4; exit}' .claude/specflow.manifest` equals `git rev-parse HEAD`.
  - `grep -q '"command": ".claude/hooks/session-start.sh"' /Users/yanghungtw/Tools/spec-workflow/settings.json` (or equivalent path-relative reference — actual format depends on `specflow-install-hook`'s output).
  - `grep -v 'command.*~/.claude/hooks' /Users/yanghungtw/Tools/spec-workflow/settings.json` — hooks no longer reference global paths.
  - `readlink "$HOME/.claude/agents/specflow"` STILL returns `/Users/yanghungtw/Tools/spec-workflow/.claude/agents/specflow` (D10 — symlinks untouched).
  - `bash test/smoke.sh` exits 0 — the remaining registered tests still pass (t50 deregistered).
  - Byte-identity: `find /Users/yanghungtw/Tools/spec-workflow/.claude -type f -not -path '*/\.git/*' | sort | xargs shasum` snapshot before T21 matches the snapshot after (no content change — only manifest + settings.json mutations).
  - STATUS.md Notes contains the T21 completion line.
- **Depends on**: T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20 — every preceding task must have landed. **T18 (t50 sentinel) must pass green immediately before T21 starts.**
- **Parallel-safe-with**: — (sole task in W6; absolutely last)
- [ ]

---

## R ↔ T trace (bidirectional)

Every PRD requirement maps to at least one task; every task maps to at least one requirement. Checkmark per cell = "task covers this R / AC".

| R / AC | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 | T12 | T13 | T14 | T15 | T16 | T17 | T18 | T19 | T20 | T21 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| R1 — copy at pinned ref | | X | X | | | | X | | | | X | | | | | | | | | | X |
| R1 AC1.a (bytes match) | | | X | X | | | | | | | | | | | | | | | | | |
| R1 AC1.b (ref readable) | | X | X | | | | X | | | | X | | | | | | | | | | X |
| R1 AC1.c (no symlinks) | | | X | X | | | | | | | | | | | | | | | | | |
| R2 — init seeds fresh | X | | X | X | | | | | | | | | | | | | | | | | |
| R2 AC2.a (self-contained) | | | X | X | | | | | | | | | | | | | | | | | |
| R2 AC2.b (idempotent) | | | | | X | | | | | | | | | | | | | | | | |
| R2 AC2.c (classify on conflict) | | | | | | X | | | | | | | | | | | | | | | |
| R3 — single global artefact | | | X | | | | | | | | | | | | X | | X | | | | |
| R3 AC3.a (source-clone deletable) | | X | | | | | | | | | | | | | | | | | | | |
| R3 AC3.b (footprint bounded) | | | | | | | | | | | | | | | X | | X | | | | |
| R4 — team-memory skeleton | | X | X | X | | | X | | | X | | | | | | | | | | | |
| R4 AC4.a (skeleton only) | | | | X | | | | | | | | | | | | | | | | | |
| R4 AC4.b (flows don't write TM) | | | | | | | X | | | X | | | | | | | | | | | |
| R5 — rules copied | | X | X | X | | | | | | | | | | | | | | | | | |
| R5 AC5.a (byte-match) | | | | X | | | | | | | | | | | | | | | | | |
| R5 AC5.b (preserved across update) | | | | | | | X | | X | | | | | | | | | | | | |
| R6 — classifier + dispatcher | | X | X | | | X | X | | | | X | | | | | | | | | | |
| R6 AC6.a (--dry-run no-op) | | | X | | | | X | | | | X | | X | | | | | | | | |
| R6 AC6.b (one-branch dispatch) | | X | X | | | X | X | | | | X | | | | | | | | | | |
| R7 — skip-and-report + backup | | X | X | | | X | X | X | X | | X | | | X | | | | | | | |
| R7 AC7.a (user-modified skip) | | | | | | X | | | X | | | | | X | | | | | | | |
| R7 AC7.b (replaced:drifted + .bak) | | | | | | | X | X | | | | | | | | | | | | | |
| R7 AC7.c (exit-code contract) | X | | X | | | X | X | | | | X | | | | | | | | | | |
| R7 AC7.d (no force, atomic) | X | X | | | | X | | | | | | | | | | X | | | | | |
| R8 — update re-copy | | | | | | | X | X | X | X | | | | | | | | | | | |
| R8 AC8.a (advance clean) | | | | | | | X | X | | | | | | | | | | | | | |
| R8 AC8.b (no advance on conflict) | | | | | | | X | | X | | | | | | | | | | | | |
| R8 AC8.c (team-memory untouched) | | | | | | | X | | | X | | | | | | | | | | | |
| R9 — migrate single consumer | | | | | | | | | | | X | X | X | X | | | | | | | |
| R9 AC9.a (other ~/.claude/ data unaffected) | | | | | | | | | | | X | X | | | | | | | | | |
| R9 AC9.b (idempotent) | | | | | | | | | | | X | X | | | | | | | | | |
| R9 AC9.c (--dry-run byte-identical 3 roots) | | | | | | | | | | | X | | X | | | | | | | | |
| R9 AC9.d (user-modified → skip, no rewire) | | | | | | | | | | | X | | | X | | | | | | | |
| R10 — this repo migrated last | | | | | | | | | | | | | | | | | | X | | | X |
| R10 AC10.a (external contract preserved pre-W6) | | | | | | | | | | | | X | | | | | | X | | | |
| R10 AC10.b (final task migrates this repo) | | | | | | | | | | | | | | | | | | | | | X |
| R10 AC10.c (structural PASS for archive) | | | | | | | | | | | | | | | | | | X | | | X |
| R11 — README install + deprecation | | | | | | | | | | | | | | | | | | | | X | |
| R11 AC11.a (Install section describes init) | | | | | | | | | | | | | | | | | | | | X | |
| R11 AC11.b (deprecation notice) | | | | | | | | | | | | | | | | | | | | X | |
| R11 AC11.c (grep-verifiable) | | | | | | | | | | | | | | | | | | | | X | |
| R12 — verb vocabulary documented | | | | | | | | | | | | | | | | | | | | X | |
| R12 AC12.a (every verb in table) | | | | | | | | | | | | | | | | | | | | X | |
| R12 AC12.b (closed set) | | | | | | | | | | | | | | | | | | | | X | |
| R13 — rule compliance | X | X | X | | | X | X | | | | X | | | | X | X | | | | | |
| R13 AC13.a (bash portability) | X | X | | | | | | | | | | | | | | X | | | | | |
| R13 AC13.b (sandbox-HOME in tests) | | | | X | X | X | | X | X | X | | X | X | X | | | | | | | |
| R13 AC13.c (no rm -rf / --force) | X | X | | | | X | | | | | | | | | | X | | | | | |

**Bi-directional coverage check**: every column T1–T21 has at least one row with X; every row R1–R13 (and all scoped ACs) has at least one X. Fully populated.

---

## STATUS Notes

_(populated by Developer as tasks complete; expected mechanical append-collisions on this section are resolved keep-both per `tpm/parallel-safe-append-sections.md`)_

---

## Wave schedule

- **Wave 0** (size 1, serial): T1
- **Wave 1** (size 1, serial): T2
- **Wave 2** (4 parallel): T3, T4, T5, T6
- **Wave 3** (4 parallel): T7, T8, T9, T10
- **Wave 4** (4 parallel): T11, T12, T13, T14
- **Wave 5** (6 parallel): T15, T16, T17, T18, T19, T20
- **Wave 6** (size 1, serial): T21

**Total**: 21 tasks across 7 wave slots. Widest wave: W5 (6-way). Critical path length: 7 wave gates (W0 → W1 → W2 → W3 → W4 → W5 → W6).

### Parallel-safety analysis per wave

**Wave 0 (size 1)** — T1 creates `bin/specflow-seed`. Sole task; no collision possible. Size-1 because the skeleton is a hard prerequisite for every downstream task — all of W1–W4 edit this file.

**Wave 1 (size 1)** — T2 extends `bin/specflow-seed`. Sole task by design per 05-plan.md §7 recommendation (a): bundle classifier + manifest IO + plan_copy into ONE task; these three originally-separate placeholders all edit the same file (`bin/specflow-seed`) and cannot run parallel per `tpm/parallel-safe-requires-different-files.md`. Bundling saves two wave gates with no parallelism loss.

**Wave 2 (4 parallel)** — Files:
  - T3: `bin/specflow-seed` (edits).
  - T4: `test/t39_init_fresh_sandbox.sh` (new).
  - T5: `test/t40_init_idempotent.sh` (new).
  - T6: `test/t41_init_preserves_foreign.sh` (new).

  All four tasks write to DISJOINT files. T3 edits `bin/specflow-seed`; T4/T5/T6 each create a brand-new test file. No task in this wave edits `test/smoke.sh` (deferred to T19). TDD shape: tests can land red-first alongside T3's green; all pass after T3 merges.

  Test isolation: each t39/t40/t41 uses its own `mktemp -d` sandbox with `HOME` override. No `/tmp` collision, no shared port, no shared fixture.

  No same-file tasks. No dispatcher-arm edits shared between tasks.

**Wave 3 (4 parallel)** — Files:
  - T7: `bin/specflow-seed` (edits).
  - T8: `test/t42_update_no_conflict.sh` (new).
  - T9: `test/t43_update_user_modified.sh` (new).
  - T10: `test/t44_update_never_touches_team_memory.sh` (new).

  Same shape as W2 — T7 is the sole `bin/specflow-seed` editor in the wave; three test tasks are different new files. No smoke.sh edit.

**Wave 4 (4 parallel)** — Files:
  - T11: `bin/specflow-seed` (edits).
  - T12: `test/t45_migrate_from_global.sh` (new).
  - T13: `test/t46_migrate_dry_run.sh` (new).
  - T14: `test/t47_migrate_user_modified.sh` (new).

  Same shape. No smoke.sh edit. Sandbox-HOME is LOAD-BEARING for t45/t46/t47 — they mutate `$HOME/.claude/*` structure, which is the exact class of test that the sandbox-HOME rule was authored to protect against. Preflight + trap cleanup in each test is non-negotiable.

**Wave 5 (6 parallel)** — Files:
  - T15: NEW directory `.claude/skills/specflow-init/` (two new files: `SKILL.md` + `init.sh`).
  - T16: `test/t48_seed_rule_compliance.sh` (new).
  - T17: `test/t49_init_skill_bootstrap.sh` (new).
  - T18: `test/t50_dogfood_staging_sentinel.sh` (new).
  - T19: `test/smoke.sh` (edit — single editor; registers all twelve new tests).
  - T20: `README.md` (edit — single editor; install + deprecation + verb table).

  All six tasks write to DISJOINT files (T15 creates a new directory not previously present in the repo — zero collision with any existing file). T19 and T20 are each the sole editor of their respective files in this wave. No dispatcher-arm edits; no shared registrations between T19 and any other task (all other tasks in W5 either create files or edit a different file).

  **Expected append-only collisions** (per `tpm/parallel-safe-append-sections.md`): tasks write their own STATUS Notes lines in `06-tasks.md` — adjacent appends; resolve keep-both mechanically. **Expected checkbox flips**: 6 checkboxes flipped `[ ]` → `[x]` in `06-tasks.md`. Per `tpm/checkbox-lost-in-parallel-merge.md`, at 6-way wave width the precedent loss rate is ~1–2 checkboxes per wave merge. Orchestrator runs `grep -c '^- \[x\]' 06-tasks.md` after the wave merges and flips any silently-dropped boxes in a post-merge fix-up commit. No surprise — this is the standard hygiene for wide waves in this repo.

  Test isolation: t48, t49, t50 are static (grep / file-presence) tests; no sandbox needed. t48 + t49 are pure filesystem asserts. t50 runs READ-ONLY dry-runs against the real `~/.claude/` — the only wide-wave test with any coupling to machine state, and the pre-migration sentinel for W6.

**Wave 6 (size 1)** — T21 is the dogfood migration; absolutely last. Edits `bin/specflow-seed`-none (reads via invocation), creates `.claude/specflow.manifest`, rewires `settings.json`, deregisters t50 from `smoke.sh`, appends a STATUS.md Notes line. Single task by design per PRD R10 AC10.b. No wave follows. If T21 fails, recovery: restore `settings.json.bak`, delete `.claude/specflow.manifest`, revert the smoke.sh edit; no mutations under `~/.claude/` to reverse (D10).

### Wave-level collision risks (summary)

| Wave | Widest collision risk | Mitigation |
|---|---|---|
| W0 | none | size 1 |
| W1 | none | size 1 (bundled by design) |
| W2 | T3 edits `bin/specflow-seed`; tests don't | disjoint file sets |
| W3 | same as W2 | disjoint |
| W4 | same as W2 | disjoint + sandbox-HOME load-bearing |
| W5 | STATUS.md notes + `06-tasks.md` checkbox flips (6-way) | append-only keep-both; post-merge checkbox audit |
| W6 | none | size 1 |

### Expected append-only conflicts

- `STATUS.md` Notes lines appended per task across every wave — mechanical keep-both per `tpm/parallel-safe-append-sections.md`.
- `06-tasks.md` checkbox flips — predictable loss rate 1–2 boxes per 6-way W5 merge; post-merge `grep -c '^- \[x\]'` audit per `tpm/checkbox-lost-in-parallel-merge.md`.
- `test/smoke.sh` — single-editor task (T19); zero collision. W6's T21 also edits `smoke.sh`, but serially (W6 runs after W5).
- `README.md` — single-editor task (T20); zero collision.
- `bin/specflow-seed` — serialized across five waves (W0 → W1 → W2 → W3 → W4) per `tpm/parallel-safe-requires-different-files.md`; same-file dispatcher-arm edits cannot be parallelized.

### Wave 1 bundling rationale (explicit)

Per 05-plan.md §7 recommendation (a) and `tpm/parallel-safe-requires-different-files.md`: three logically independent helpers (classifier, manifest IO, plan_copy) all edit `bin/specflow-seed`. Splitting into three tasks within W1 would force same-file serialization at the task level (zero parallelism). Splitting across three waves would over-serialize the critical path (three extra wave gates for no gain — all three are hard prerequisites for every flow). Bundling into one task (T2) is the correct shape: one commit, one TDD gate (hidden `__probe` harness), one reviewer pass. Blast radius small (~150 lines of bash + Python 3 heredocs).

### Dogfood staging (recap)

- W0–W5 run entirely against sandboxed `$HOME` fixtures. This repo stays on the global-symlink model throughout (AC10.a).
- W5's T18 (t50 sentinel) is the pre-condition gate for W6.
- W6's T21 is the sole live migration of this repo, gated on t50 green.
- Post-archive: runtime PASS on `init` / `update` / `migrate` against a fresh external consumer is deferred to the next feature after session restart per `shared/dogfood-paradox-third-occurrence.md` 6th occurrence (with the 4th-occurrence "next feature after session restart" clause, not merely after archive).

## Team memory

- `tpm/parallel-safe-requires-different-files.md` — load-bearing for W0–W4 serialization on `bin/specflow-seed`; every wave gate in the critical path is justified by this rule.
- `tpm/parallel-safe-append-sections.md` — applied to W5 STATUS.md / 06-tasks.md checkbox-flip collisions; accept mechanical keep-both without over-serializing the 6-way wave.
- `tpm/checkbox-lost-in-parallel-merge.md` — flagged for W5 post-merge audit at 6-way width; precedent loss rate 1–2 boxes.
- `tpm/briefing-contradicts-schema.md` — applied to T2: D3 manifest schema and D4 classifier pseudocode + dispatcher table pasted VERBATIM from `04-tech.md` §3 into T2's scope. No paraphrase.
- `shared/dogfood-paradox-third-occurrence.md` — 6th occurrence. T18 (t50 sentinel) gates T21 (W6 dogfood); structural-only verify is the archive gate; runtime confirmation deferred to next feature after session restart.
