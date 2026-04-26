# Plan — fix commands source from $SCAFF_SRC

- **Feature**: `20260426-fix-commands-source-from-scaff-src`
- **Stage**: plan
- **Author**: TPM
- **Date**: 2026-04-26
- **Tier**: standard (every wave merge runs reviewer-style + reviewer-security per `.claude/rules/reviewer/*.md`; reviewer-performance opt-in here for the lint extension that scans 18 files and for the resolver block that fires on every commit / `/scaff:*` invocation — both have explicit perf budgets per tech §4)

PRD: `03-prd.md` (R1–R7, AC1–AC8, D1–D4 placeholders).
Tech: `04-tech.md` (D1–D7 resolved; mechanism: D1 inline 7-line bash resolver in every surface; D5 single-lint extension; D6 `plan_copy` cleanup; D7 t113 sandbox harness).

---

## 1. Approach

This feature ships the **architectural other-half** of the just-archived parent bug `20260426-fix-init-missing-preflight-files`. The parent fixed `config.yml` seeding (one symptom of the broken consumer-bootstrap path); this feature fixes the broader path-resolution architecture so that **all** tool dependencies (`bin/scaff-*`, `.specaffold/preflight.md`) resolve from `$SCAFF_SRC` (the source-repo path established by the user-global symlink at `~/.claude/agents/scaff`) rather than from `$REPO_ROOT` (the consumer). The mechanism per tech-D1 is:

- **One inline 7-line bash resolver** embedded in every surface that needs it (no shared helper file in the consumer per the chicken-and-egg analysis: the consumer has no `bin/`, so a sourced helper would itself need `$SCAFF_SRC` to locate). Three surfaces:
  1. **Slash-command preambles** — 18 files in `.claude/commands/scaff/*.md`. The combined W3 marker block grows from 5 lines (HTML comment + 4-line preflight directive) to ~12 lines (HTML comment + 7-line resolver bash + preflight directive that now references `$SCAFF_SRC/.specaffold/preflight.md`). Byte-identical across all 18 files. Surfaces that source `bin/*` (next, archive, implement) additionally rewrite their `$REPO_ROOT/bin/scaff-*` calls to `$SCAFF_SRC/bin/scaff-*` per AC2.
  2. **Pre-commit shim** emitted by `bin/scaff-seed` at TWO heredoc sites (`cmd_init` line 797 and `cmd_migrate` line 1384, byte-identical per parent feature's wiring-trace lesson). Both heredocs grow by ~7 lines (resolver) + the existing `bin/scaff-lint` calls become `"$SCAFF_SRC/bin/scaff-lint"` per AC4 / D2.
  3. **Lint extension** — `bin/scaff-lint preflight-coverage` (existing subcommand from the parent feature) is extended to assert BOTH the marker presence (existing) AND the byte-identical resolver+marker block across all 18 files (new) per D5. Single subcommand, not a sibling.

Cleanup per D6: `bin/scaff-seed`'s `plan_copy` branch that ships `.specaffold/preflight.md` to consumers (added in just-archived parent feature `20260426-fix-init-missing-preflight-files` T1) is REMOVED — consumer no longer needs preflight.md (commands resolve via `$SCAFF_SRC`). Source's own `.specaffold/preflight.md` STAYS (source-repo dogfood: `$SCAFF_SRC == $REPO_ROOT` for source). The `emit_default_config_yml` helper from the parent feature also STAYS (config.yml IS in consumer state, not tool surface).

### 1.1 Authoritative count: 18 command files

Verbatim verification per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`:

```
ls .claude/commands/scaff/ | wc -l
# expected: 18

ls .claude/commands/scaff/
# expected: archive.md bug.md chore.md design.md implement.md next.md
#           plan.md prd.md promote.md remember.md request.md review.md
#           tech.md update-plan.md update-req.md update-task.md update-tech.md validate.md
```

Every task references this exact set. The lint scans the directory at runtime (no hard-coded count); structural tests assert 18 explicitly.

### 1.2 Surfaces that source `bin/*` — exact set

Verbatim verification (run at dispatch, not just at plan time):

```
grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md
# Expected (from grep at plan time, 2026-04-26):
#   .claude/commands/scaff/archive.md
#   .claude/commands/scaff/implement.md
#   .claude/commands/scaff/next.md
#   .claude/commands/scaff/review.md
#   .claude/commands/scaff/validate.md
```

Five command files actively `source "$REPO_ROOT/bin/scaff-*"`. AC2 binds: after the fix, `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` returns empty. The remaining 13 of 18 only carry the W3 marker block (no `bin/*` source line), so for them the resolver block alone (no `$SCAFF_SRC/bin/scaff-*` rewrite) is sufficient. **Important**: T4's developer MUST re-run the `grep` above at dispatch time — if intervening work changes the set, the developer flags it via `/scaff:update-plan` rather than guessing.

### 1.3 Wave sequencing — strict serial (W1 → W2)

Per `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` and the dogfood-paradox guard: enforcement layer (the extended lint) ships in W1; satisfier (the marker sweep with the new combined block) ships in W2. Two waves.

- **W1 — foundations (parallel within wave)** — Three file-disjoint tasks land together:
  - T1 extends `bin/scaff-lint preflight-coverage` to assert byte-identical resolver+marker block across all 18 files (the "new" canonical block, ~12 lines, embedded in the lint script as the expected literal).
  - T2 authors `test/t113_scaff_src_resolver.sh` — the assistant-not-in-loop sandbox harness covering AC1, AC4, AC5, AC8 per D7.
  - T3 edits `bin/scaff-seed` at two sites: (a) the pre-commit shim heredocs at lines 797 and 1384 (byte-identical mirror per parent-feature wiring-trace lesson), and (b) the `plan_copy` branch at lines 440–442 (drop the `.specaffold/preflight.md` ship-to-consumer entry).
  - At W1 close, **the lint exits 1 against the on-disk tree** (markers still in old shape; new lint requires new shape). **t113 also fails** because the marker sweep hasn't happened. Both are **expected** at W1 close. T4 in W2 satisfies both.
- **W2 — marker sweep (the dogfood wave)** — One bulk task lands the new combined block in all 18 files atomically.
  - T4 sweeps the W3 marker block across all 18 files: replaces the existing 5-line block with the new ~12-line combined resolver+marker block (byte-identical across all 18). Additionally, in the 5 files identified in §1.2 that source `bin/*`, rewrites `$REPO_ROOT/bin/scaff-*` → `$SCAFF_SRC/bin/scaff-*`.
  - At W2 close, lint exits 0 (all 18 files match the new canonical block); t113 passes; source-repo `bin/scaff-lint preflight-coverage` regression passes (AC6).

### 1.4 Dogfood-paradox sequencing — twelfth occurrence

Per `shared/dogfood-paradox-third-occurrence.md` (eleven prior occurrences, including the parent feature `20260426-scaff-init-preflight` which is itself the eleventh). This is the twelfth. The umbrella pattern holds: structural verification at validate, runtime exercise on the next feature.

The specific paradox here: **the lint extension in W1 will fail against the on-disk tree until W2's marker sweep lands**. Local pre-commit hook is already enforcing `preflight-coverage` (installed by parent feature W2). Per `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md`, every commit between W1 close and W2 satisfaction MUST use `git commit --no-verify` AND log to STATUS Notes. Enumeration of every bypass site:

> The local `.git/hooks/pre-commit` already calls `bin/scaff-lint preflight-coverage` (installed by parent feature). After T1's lint extension lands on main, the lint expects the **new** ~12-line canonical block but the working tree still has the **old** 5-line shape — lint exits 1 on every commit until W2's T4 lands.
>
> Bypass sites (`--no-verify` MANDATORY, plus STATUS Notes log per the eleventh-occurrence discipline):
>
> 1. **T1 developer commit** — the T1 worktree has NEW lint + OLD markers. The hook runs T1's new lint binary against the worktree's old markers → fails. The T1 developer MUST `git commit --no-verify` and log it in their reply.
> 2. **W1 inter-merge commits** — the orchestrator merges T1 first (or after T2/T3); whichever merge lands the new lint on main, every subsequent merge in W1 hits new-lint-vs-old-markers. To avoid order-sensitive bookkeeping, the orchestrator uses `--no-verify` on EVERY W1 merge commit and the W1 bookkeeping commit. (Conservative: covers all merge orders.)
> 3. **W1 bookkeeping commit** — orchestrator commit on main after all W1 merges; main has new lint + old markers → fails. `--no-verify` MANDATORY.
> 4. **T2 developer commit** — T2 worktree has OLD lint (branched off old main before T1 landed) + OLD markers. The hook runs OLD lint against OLD markers → passes. **No `--no-verify` needed** at T2 dev commit time. *Caveat*: if the orchestrator dispatches T2's worktree AFTER T1 has already merged to main and T2 rebases or merges from main, T2 inherits the new lint and the same hazard applies. To be safe, T2 developer MAY use `--no-verify` if the lint fails locally; log either way.
> 5. **T3 developer commit** — same shape as T2: old-lint-on-worktree + old markers → passes the hook. **No `--no-verify` needed at dev-commit time** under default dispatch (T3 worktree branched off old main). Same caveat as T2 if rebased post-T1-merge.
> 6. **T4 developer commit (W2)** — T4 worktree branches off post-W1 main (NEW lint already merged). T4 sweeps the markers in its worktree. At T4's commit, working tree has NEW lint + NEW markers → lint exits 0 → hook passes. **No `--no-verify` needed**. T4 IS the producer; its commit is the one site in W2 that should pass cleanly.
> 7. **W2 bookkeeping commit** — orchestrator commit on main after T4 merge; main has NEW lint + NEW markers → passes. **No `--no-verify` needed**.

Summary: `--no-verify` MANDATORY at sites 1, 2, 3 (T1 dev + every W1 merge + W1 bookkeeping); CONDITIONAL (only if the worktree was rebased post-T1-merge) at sites 4, 5; UNNEEDED at sites 6, 7.

STATUS Notes line format per the discipline:

```
YYYY-MM-DD implement — --no-verify USED for <site> (reason: enforcement layer ships before satisfier; expected per plan §1.4)
```

One line per actual bypass.

### 1.5 Out-of-scope / deferred

- **Stale `.specaffold/preflight.md` cleanup in already-init'd consumers** (tech §6 N1) — file becomes orphaned but harmless; future `cmd_migrate --prune-stale-files` covers it.
- **Resolver versioning** (tech §6 N2) — lint enforces byte-identity today; versioning is unneeded until a non-byte-identical resolver edit is required.
- **Multi-source dispatch** (tech §6 N3) — `~/.claude/agents/scaff` is single-source; `$SCAFF_SRC` env var is the per-shell escape hatch.
- **Updating the source-repo's `.git/hooks/pre-commit`** — the local hook is already wired by parent feature; no re-install task needed in this feature. If T3's `bin/scaff-seed` heredoc edit changes the shim shape, the local hook continues to work because it was installed pointing at `bin/scaff-lint` directly (not via the heredoc — the heredoc is for consumer installs, not for source-repo dogfood). Confirm via `grep -F 'preflight-coverage' .git/hooks/pre-commit` at T3 dispatch.

---

## 2. Wave schedule

| Wave | Purpose                                                        | Task IDs        | Parallelisation notes                                                                                                                                                                                |
|------|----------------------------------------------------------------|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| W1   | Lint extension + sandbox test author + scaff-seed edits        | T1, T2, T3      | T1 edits `bin/scaff-lint`; T2 writes `test/t113_scaff_src_resolver.sh` (new); T3 edits `bin/scaff-seed`. Three disjoint files. Fully parallel-safe by file disjointness.                              |
| W2   | Marker sweep across all 18 command files                       | T4              | T4 edits all 18 files in `.claude/commands/scaff/` in one atomic bulk task (per parent-feature §4 atomicity argument: lint exits 0 only when ALL files carry the new block; subset = lint red).      |

**Wave count**: 2. **Task count**: 4. **Per-wave**: W1 = 3 · W2 = 1.

### Parallel-safety analysis per wave

**W1 — Three tasks across three disjoint file namespaces.**
- T1: edits `bin/scaff-lint` (one new canonical-block string + extension to `run_preflight_coverage` to assert byte-identical block, single `grep -L -F` fork or single multi-line awk pass per the performance rule).
- T2: writes `test/t113_scaff_src_resolver.sh` (new test file; no overlap).
- T3: edits `bin/scaff-seed` at three line ranges: 440–442 (drop plan_copy entry), 797 (cmd_init shim heredoc), 1384 (cmd_migrate shim heredoc). All three edits are in one file; T3 owns that file solo within W1.

No file overlap; no shared fixture or DB state; tests run via on-disk artefacts with sandbox-HOME isolation per `.claude/rules/bash/sandbox-home-in-tests.md` (T2 uses `mktemp -d`).

**Same-wave hazard check** — `grep -hE '^- \*\*Deliverables\*\*' 05-plan.md | grep -oE '(\.claude|bin|test)/[A-Za-z0-9_./-]+' | sort | uniq -d` returns empty across W1's three tasks (verified at plan write time).

**W2 — Single task** (size 1 by atomicity: marker sweep across 18 files must be one commit per parent-feature §4 atomicity argument and `tpm/parallel-safe-requires-different-files.md` — splitting into 18 parallel tasks gains nothing because each file edit is < 30 seconds, and any subset = lint red until all 18 land).

### Test filename pre-declaration (per `tpm/pre-declare-test-filenames-in-06-tasks.md`)

Last used counter: `t112` (in just-archived parent bug `20260426-fix-init-missing-preflight-files`). Next counter: **`t113`**.

- T2 → `test/t113_scaff_src_resolver.sh` (W1)

One new test file; no collisions. Verification: `ls test/t113_*.sh` returns "No such file or directory" at plan time (confirmed: `t112` is the latest).

---

## 3. Risks

1. **Dogfood paradox (twelfth occurrence)** — see §1.4 above. Local pre-commit hook starts firing the new lint as soon as T1 lands on main; until T4 lands, every commit on main hits new-lint-vs-old-markers. Mitigation: §1.4 enumerates every `--no-verify` site; STATUS Notes must log every bypass. Recovery if T4 lands a broken canonical block: `git revert` on T4's bulk commit (single commit per §4 atomicity rationale, ported from parent feature).

2. **18-file uniformity drift** — the new combined block must be byte-identical across all 18 files. If the developer accidentally introduces a per-file variation (e.g. file-specific line wrapping or trailing whitespace), the lint will catch it post-W2 but at additional review cost. Mitigation: T4 scope explicitly says "paste the canonical block verbatim 18 times; do not edit between paste sites"; the lint's byte-identity check (T1) IS the enforcement layer.

3. **Mirror-emit site coverage in `bin/scaff-seed`** — per parent-feature wiring-trace lesson (`qa-analyst/partial-wiring-trace-every-entry-point.md` referenced in shared dogfood-paradox 11th-occurrence appendix), the shim heredoc has TWO mirror sites (line 797 + line 1384). T3 scope explicitly names BOTH lines; T2's t113 sandbox test asserts the consumer-installed hook (which is emitted from `cmd_init`, line 797). **Gap**: t113 does NOT exercise `cmd_migrate` (line 1384). This mirrors the parent-feature gap exactly. Mitigation: T1's lint canonical-block check guards the SHIM TEMPLATE against drift indirectly via `bin/scaff-lint`'s own self-check on changed lines (NOT applicable here — the shim heredoc is in `bin/scaff-seed`, not in `.claude/commands/scaff/`). Direct mitigation: T3's developer MUST verify byte-identity post-edit with `diff <(sed -n '797p' bin/scaff-seed) <(sed -n '1384p' bin/scaff-seed)` (after the edit, both lines should be byte-identical). T3 Verify includes this exact command. If a follow-up feature wants to add a per-emit-site test, file as a separate chore.

4. **Resolver byte-identity across surfaces** — the 7-line resolver appears in (a) bin/scaff-seed shim heredocs (TWO sites; sub-string of the larger heredoc), and (b) the 18 command files' marker blocks (ONE per file). The lint's byte-identity check covers (b) but not (a). **Mitigation**: T3's Verify command includes a diff between the heredoc resolver text in bin/scaff-seed (lines 797, 1384) and the canonical resolver text the lint expects in command files (extracted from bin/scaff-lint). Specifically: extract the resolver substring from each of the three sites and assert all three hashes match. Concrete commands listed in T3 Verify field. Cross-reference: `qa-analyst/partial-wiring-trace-every-entry-point.md`.

5. **Lint performance** — the new canonical block is ~12 lines (up from ~1 line of marker check). Per tech §4.5 / D5: the existing `grep -L -F` single-fork pattern survives if the lint extracts a single-line anchor (`<!-- preflight: required -->`) for presence-check, then for byte-identity uses one `awk` per file (or one grep with `-F` and the multi-line block as the pattern). The original parent-feature lint used `grep -L -F` with a single-line marker; with a 12-line block as the pattern, `grep -L -F` against a multi-line literal needs a different approach. Tech §4.5 says "single fork via `grep -L -F` per the performance rule" but extending to byte-identity may need a single `awk` invocation that processes all 18 files in one fork (`awk '...' .claude/commands/scaff/*.md`). T1's Scope embeds the constraint: single fork, < 100ms warm-cache wall time. Reviewer-performance axis at W1 merge enforces. If a developer drifts to per-file-fork loop, reviewer flags it as `must`.

6. **Pre-checked checkboxes anti-pattern** — per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`, every `- [ ]` below stays unchecked. TPM never writes `- [x]` at plan time; orchestrator's per-wave bookkeeping commit is the sole `[x]` writer. Per `tpm/checkbox-lost-in-parallel-merge.md`, post-wave audit flips any `[ ]` → `[x]` for tasks the wave actually merged.

7. **Placeholder-token hazard** — per `tpm/task-scope-fence-literal-placeholder-hazard.md`, no `tN_` / `<fill>` / `<new file>` placeholders appear anywhere; every test filename, command-file path, and line number is verbatim.

8. **Wave-merge reviewer axis budget (tier=standard + opt-in performance)** — every wave runs reviewer-style + reviewer-security. reviewer-performance opt-in at W1 (lint extension on tight 18-file loop + resolver runs at every commit and every `/scaff:*`) and at W2 (no code, but the marker block is plain markdown — quick).
   - **security** — resolver reads `$SCAFF_SRC` env var and `readlink ~/.claude/agents/scaff`; both validated via `[ -d ]` post-resolve. No string-built shell command. No untrusted YAML/JSON parsing. No path traversal (no user-supplied path joining). The `printf '%s\n'` form for the failure message is argv-form, not shell-built. Pre-commit shim heredoc embeds the same resolver and same argv-form invocations.
   - **performance** — resolver overhead (single `[ -d ]` test + parameter expansion + at most one `readlink` fork) under 5ms; well inside hook budget. Lint canonical-block byte-identity check single fork (single `awk` over all 18 files) under 100ms.
   - **style** — bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md`: no `[[ =~ ]]`, no `readlink -f`, no `realpath`. Use `${var%/.claude/agents/scaff}` parameter expansion for the symlink-target suffix strip. No commented-out code; no commented-WHAT comments; no dead imports.

---

## 4. Open questions

None. Every PRD requirement (R1–R7) maps to a task; every AC (AC1–AC8) has a structural or runtime verifier; every architect D-id (D1–D7) has a task or an explicit no-op carve-out (D6 cleanup is in T3; D7 sandbox test is T2; D5 lint extension is T1).

PRD D1–D4 (architect placeholders) are resolved in tech-D1–D4. D2 (hook-run-time resolution) is satisfied by T3's heredoc edit. D3 (sweep-substitute combined marker block) is T4. D4 (failure UX exit 65 + remediation) is hard-coded into the resolver text in T1's canonical block + T3's heredoc + T4's marker sweep — byte-identical across all surfaces.

---

## 5. Task checklist

Each task below uses the merged-form task block shape per `tpm.appendix.md` §"Task format and wave schedule rules".

---

### W1 — Lint extension + sandbox test author + scaff-seed edits

## T1 — Extend `bin/scaff-lint preflight-coverage` to assert byte-identical resolver+marker block across all 18 files

- **Milestone**: M1
- **Requirements**: R6, R7
- **Decisions**: D5 (extend, not split), tech-D5
- **Scope**: Modify `bin/scaff-lint` to extend the existing `run_preflight_coverage` function (around line 425 — verify with `grep -n 'run_preflight_coverage()' bin/scaff-lint` at dispatch, expected single match) so it asserts the NEW canonical block (HTML-comment marker `<!-- preflight: required -->` + 7-line bash resolver + 4-line preflight directive that references `$SCAFF_SRC/.specaffold/preflight.md`) is present byte-identically in all 18 files under `.claude/commands/scaff/`. Embed the canonical block as a single `read -r -d '' CANONICAL_BLOCK <<'EOF' ... EOF` (or equivalent bash 3.2 / BSD portable single-quote-fenced heredoc) at the top of `run_preflight_coverage`.
  - **Canonical block** (verbatim, byte-identical across all surfaces: lint, scaff-seed shim, 18 command files):
    ```
    <!-- preflight: required -->
    # Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
    if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
      _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
      SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
      unset _scaff_src_link
    fi
    [ -d "${SCAFF_SRC:-}" ] || { printf '%s\n' 'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo' >&2; exit 65; }
    Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.
    If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
    this command immediately with no side effects (no agent dispatch,
    no file writes, no git ops); print the refusal line verbatim.
    ```
    (12 lines: 1 marker + 7 resolver + 4 directive. Exact line count to assert: 12. The resolver lines 2–8 are byte-identical to the heredoc resolver in T3's scaff-seed shim emitter; T3's Verify includes a cross-surface diff to confirm.)
  - **Lint algorithm** (single fork, performance budget < 100ms warm cache):
    1. Use one `awk` invocation across all 18 files: `awk -v block="$CANONICAL_BLOCK" '...' .claude/commands/scaff/*.md` — for each file, the awk program scans for the canonical block as a contiguous run of lines and reports `ok:<file>` on match, `missing-marker:<file>` on miss. Single fork; no per-file shell-out (per `.claude/rules/reviewer/performance.md` rule 1).
    2. Alternative: keep the existing `grep -L -F '<!-- preflight: required -->'` for the marker-presence check (single fork), then a single `awk` pass for byte-identity on those that pass marker-presence. Two forks total; still inside budget. **Choose whichever the developer finds clearer; both are perf-compliant**.
  - **Backwards compatibility**: the function's exit-code contract is preserved (0 = all 18 OK; 1 = any missing/divergent; 2 = usage error i.e. positional args supplied). Verbatim verification at dispatch: `grep -c 'run_preflight_coverage' bin/scaff-lint` returns ≥ 2 (function definition + case-arm dispatch).
  - **Bash 3.2 portability** per `.claude/rules/bash/bash-32-portability.md` — no `[[ =~ ]]`, no `mapfile`, no GNU-only flags. Use `read -r -d ''` heredoc form for the canonical block; `awk` is BSD-safe.
  - **Byte-identity guarantee for the canonical block string**: the lint script IS the canonical source. T3 (scaff-seed) and T4 (18 command files) MUST paste a substring of this canonical block; if they drift, the lint catches it. The lint's own canonical block is reviewed by reviewer-style/security at W1 merge.
- **Deliverables**: `bin/scaff-lint` (edit; one extension to `run_preflight_coverage` adding the byte-identity check; add the `CANONICAL_BLOCK` constant near the top of the function or at script-header scope). No new function; no new case-arm; one subcommand.
- **Verify**: `bash -n bin/scaff-lint` (syntax). After T4 lands (W2), `bin/scaff-lint preflight-coverage; echo "exit=$?"` from repo root should print 18 `ok:<file>` lines and `exit=0`. **At W1 close (before T4 lands), the same command should print 18 `missing-marker:<file>` lines and `exit=1`** — this is the expected negative-path behaviour and is asserted by T2's t113. Also `time bin/scaff-lint preflight-coverage` should run in under 100ms warm cache (reviewer-performance budget at W1 merge).
- **Depends on**: —
- **Parallel-safe-with**: T2, T3
- [ ]

## T2 — Author `test/t113_scaff_src_resolver.sh` covering AC1, AC4, AC5, AC8 (assistant-not-in-loop sandbox)

- **Milestone**: M1
- **Requirements**: R2, R3, R6, R7
- **Decisions**: D7
- **Scope**: Author `test/t113_scaff_src_resolver.sh` per tech-D7. Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (mandatory): top-of-script `SANDBOX="$(mktemp -d)"`, `trap 'rm -rf "$SANDBOX"' EXIT`, `export HOME="$SANDBOX/home"`, `mkdir -p "$HOME/.claude/agents"`, preflight `case "$HOME"` assertion. Resolve `REPO_ROOT="$(git rev-parse --show-toplevel)"` to point at the source repo (the test runs from the source). Fake the user-global symlink inside the sandbox: `ln -s "$REPO_ROOT/.claude/agents/scaff" "$HOME/.claude/agents/scaff"` — this gives the resolver path-(b) a real target whose readlink output ends in `/.claude/agents/scaff` and whose suffix strip yields `$REPO_ROOT`.

  **Assertions** (one per AC plus negative-path coverage):

  - **A1 (AC1 — resolver resolves correctly from env-var override)**: Set `SCAFF_SRC="$REPO_ROOT"` explicitly, then source the resolver block (extracted from `next.md`'s W3 marker block via awk between the `<!-- preflight: required -->` line and the next blank line; or run the W3 marker block from a representative command file in a subshell). Assert: `[ "$SCAFF_SRC" = "$REPO_ROOT" ]` after resolution; resolver did not fall back to readlink.
  - **A2 (AC1 — resolver resolves correctly from readlink fallback)**: Unset `SCAFF_SRC`, run the resolver. Assert: post-resolve, `SCAFF_SRC` is byte-identical to `$REPO_ROOT` (because the sandbox symlink points at `$REPO_ROOT/.claude/agents/scaff` and the suffix strip produces `$REPO_ROOT`).
  - **A3 (AC1 — resolver fails loudly when neither resolves)**: Unset `SCAFF_SRC`; remove the sandbox symlink (`rm "$HOME/.claude/agents/scaff"`); run the resolver. Assert: exit code 65 (EX_DATAERR per tech-D4); stderr contains literal `ERROR: cannot resolve SCAFF_SRC`; stderr contains literal `bin/claude-symlink install`; no stdout output.
  - **A4 (AC4 — pre-commit shim resolves at hook-run time, not install time)**: in the sandbox, build a minimal consumer-repo recipe (modelled on existing `test/t108_precommit_preflight_wiring.sh`'s `make_consumer` helper — see lines 60–80 of that file as the template), then run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref HEAD)`. Verify the installed hook contains the resolver bash (`grep -F 'readlink "$HOME/.claude/agents/scaff"' "$CONSUMER/.git/hooks/pre-commit"` matches) AND the absolute-path `bin/scaff-lint` invocation (`grep -F '"$SCAFF_SRC/bin/scaff-lint"' "$CONSUMER/.git/hooks/pre-commit"` matches). Then stage a benign change in the consumer (`echo x > "$CONSUMER/x"; (cd "$CONSUMER" && git add x)`) and run the hook directly: `(cd "$CONSUMER" && SCAFF_SRC="$REPO_ROOT" .git/hooks/pre-commit)`. Assert exit 0 (passthrough — no findings).
  - **A5 (AC5 — sandboxed consumer with NO `bin/` can extract and run the gate body via `$SCAFF_SRC`)**: confirm `[ ! -d "$CONSUMER/bin" ]` (thin-consumer invariant per AC5). Then source one representative command's W3 marker block from `$CONSUMER/.claude/commands/scaff/next.md` in a subshell with the sandbox `$HOME` set; the resolver should pick up `$REPO_ROOT` via the sandbox symlink; the gate body at `$SCAFF_SRC/.specaffold/preflight.md` (which IS in the source) executes. With `.specaffold/config.yml` present in the consumer (via `emit_default_config_yml`), the gate exits 0 (passthrough). Without it (delete the file), the gate exits 70 with `REFUSED:PREFLIGHT`. Assert both branches.
  - **A6 (AC8 — assistant-not-in-loop)**: every step above is a literal subprocess invocation; no agent-mediated step. The test is purely shell. Header comment: `# AC8: assistant-not-in-loop — every assertion is a subprocess invocation; no LLM-mediated description.`
  - **A7 (AC7 cross-check — `plan_copy` removed `.specaffold/preflight.md` entry)**: `grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty. (After T3 lands. At W1 close pre-T3-merge this would still match line 440–442; once T3 merges, empty.)

  **Notes for the test**:
  - The test imports the canonical resolver text from `bin/scaff-lint`'s `CANONICAL_BLOCK` constant (avoids drift). At dispatch, the test reads the constant via `awk` extraction from `bin/scaff-lint` if simpler, else hard-codes a check that the constant in `bin/scaff-lint` matches the marker blocks in 18 files (a stronger structural assertion).
  - Bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md`. No `[[ =~ ]]`; use `case` glob.
  - The test MUST exercise the resolver against the SOURCE repo (not against a fake sandbox-internal source) so AC6 dogfood-regression is implicit (if the resolver works against `$REPO_ROOT` in the test, then `bin/scaff-lint preflight-coverage` will continue to work in source-repo dogfood).
- **Deliverables**: `test/t113_scaff_src_resolver.sh` (new file, executable: `chmod +x`).
- **Verify**: `bash test/t113_scaff_src_resolver.sh` exits 0 (after T3 and T4 land — T2 itself only authors the test; the test passing requires W1+W2 to be merged). At W1 close (T3 merged but T4 not yet): A1–A3 should pass (resolver behaviour is independent of marker shape); A4 requires T3's shim heredoc edit; A5 requires T4's marker sweep, so A5 fails at W1 close. Note in test header: `# At W1 close: A1–A4 pass; A5 fails (markers not yet swept). At W2 close: all pass.`
- **Depends on**: —
- **Parallel-safe-with**: T1, T3
- [ ]

## T3 — Edit `bin/scaff-seed` — update shim heredocs at lines 797 + 1384 (byte-identical mirror) + drop `plan_copy` `.specaffold/preflight.md` entry at lines 440–442

- **Milestone**: M1
- **Requirements**: R3, R5
- **Decisions**: tech-D2 (hook-run-time resolution), tech-D6 (plan_copy cleanup)
- **Scope**: Two edits in `bin/scaff-seed`:

  **Edit 1 — Drop `plan_copy` `.specaffold/preflight.md` branch**. Verbatim verification at dispatch: `grep -n 'preflight.md' bin/scaff-seed` should match lines 440 and 441 (and possibly 641 / 1217 as comments — confirm). The block to delete is lines 440–442:
  ```
  if [ -f "${src_root}/.specaffold/preflight.md" ]; then
    printf '.specaffold/preflight.md\n'
  fi
  ```
  Delete the entire 3-line `if`-block. The surrounding comment block (lines 437–439) explains the original D6 sibling-block reasoning; either delete the comment too (cleanest) or leave it with an addendum noting it was removed in this feature. **Decision: delete both the comment block (lines 437–439) and the `if` block (lines 440–442) — single contiguous deletion, no orphan prose.** Post-edit verification: `grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty (per AC7).

  **Edit 2 — Update both shim heredocs (lines 797 + 1384) to embed the resolver and use absolute-path `bin/scaff-lint`**. Verbatim verification at dispatch: `grep -n "scaff-lint scan-staged" bin/scaff-seed` should match exactly two lines (797 and 1384). The current heredoc is:
  ```
  printf '#!/usr/bin/env bash\n# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate\nset -euo pipefail\nbin/scaff-lint scan-staged "$@"\nbin/scaff-lint preflight-coverage\n' \
  ```
  Replace BOTH heredocs (must remain byte-identical between the two lines per `qa-analyst/partial-wiring-trace-every-entry-point.md`) with:
  ```
  printf '#!/usr/bin/env bash\n# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate\nset -euo pipefail\n# Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.\nif [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then\n  _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)\n  SCAFF_SRC="${_scaff_src_link%%/.claude/agents/scaff}"\n  unset _scaff_src_link\nfi\n[ -d "${SCAFF_SRC:-}" ] || { printf %s\\\\n "ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run \\`bin/claude-symlink install\\` from the scaff source repo" >&2; exit 65; }\n"$SCAFF_SRC/bin/scaff-lint" scan-staged "$@"\n"$SCAFF_SRC/bin/scaff-lint" preflight-coverage\n' \
  ```
  Notes on heredoc encoding:
  - The outer `printf '...'` is single-quoted so `$SCAFF_SRC`, `$HOME`, `$@`, `$?` etc. are NOT expanded by the OUTER printf — they are written into the emitted hook file verbatim and expanded at hook-RUN time.
  - Backticks around `bin/claude-symlink install` are escaped as `\\\`...\\\`` so they survive the outer printf single-quote escape and the heredoc-internal printf.
  - The `%s\\n` is literal `%s\n` in the emitted hook.
  - The two heredocs (lines 797 and 1384) MUST be byte-identical. Use the same source string for both; do not reformat one differently.

  **Cross-surface byte-identity check** for the resolver substring: the resolver lines (4 conditional lines + closing `[ -d ]` line) must match the resolver section in T1's `CANONICAL_BLOCK`. Specifically: extract the resolver substring from each surface and assert byte-identity. The simplest assertion lives in T2's t113 (A4 / A7 — shim hook contents check); T3's developer Verify command additionally diffs the two heredocs against each other and against the resolver substring of T1's canonical block.

  **Bash 3.2 portability**: `${var%%/.claude/agents/scaff}` is POSIX; no `[[ =~ ]]`; no GNU-only flags.
- **Deliverables**: `bin/scaff-seed` (edit; ~10 line change at lines 437–442 deletion, ~+15 line replacement at lines 797 and 1384 — net effect: file shrinks by 6 and grows by ~20 in two heredocs).
- **Verify**: `bash -n bin/scaff-seed` (syntax). After edit: `grep -n "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty (AC7); `grep -nF 'readlink "$HOME/.claude/agents/scaff"' bin/scaff-seed | wc -l` returns exactly 2 (AC4 — both heredocs); `diff <(awk 'NR==797' bin/scaff-seed) <(awk 'NR==1384' bin/scaff-seed)` returns empty (byte-identity between the two emit sites — verbatim per `qa-analyst/partial-wiring-trace-every-entry-point.md`). Also `bash test/t113_scaff_src_resolver.sh` (T2 authors) — A4 and A7 should pass after T3 lands (A5 still requires T4).
  Note: line numbers (797, 1384) shift after Edit 1 (delete 6 lines around line 440) by -6, so post-Edit-1 the heredocs are at 791 and 1378. Update the awk line numbers accordingly OR use grep to find them: `grep -n "scaff-lint: pre-commit shim" bin/scaff-seed` returns two lines (the post-edit positions). The Verify command should use grep-then-awk, not hard-coded line numbers, to remain stable across edits.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2

  **Pre-commit hook caveat (per §1.4)**: T3's worktree branched off old main has OLD lint + UNCHANGED markers. The hook runs OLD lint against OLD markers → passes. **No `--no-verify` needed** at T3 dev commit time *unless* the worktree was rebased post-T1-merge. If the developer rebases or the orchestrator merges T1 first, T3's worktree inherits new lint + old markers → hook fails. Conservative discipline: T3 developer MAY use `--no-verify` if the local hook fails; log the bypass in the dev reply per `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md` step 4.
- [ ]

---

### W2 — Marker sweep across all 18 command files

## T4 — Sweep the W3 marker block in all 18 `.claude/commands/scaff/*.md` files to the new combined resolver+marker shape; rewrite `$REPO_ROOT/bin/scaff-*` → `$SCAFF_SRC/bin/scaff-*` in the 5 files that source bin/

- **Milestone**: M2
- **Requirements**: R1, R4
- **Decisions**: tech-D1 (inline 7-line resolver), tech-D3 (sweep-substitute combined block), D5 (lint anchor)
- **Scope**: Two coupled edits across 18 files:

  **Edit A — W3 marker block sweep (all 18 files)**. For each of the 18 files in `.claude/commands/scaff/` (verbatim list — verify with `ls .claude/commands/scaff/` at dispatch; expected count: 18; expected names: `archive.md, bug.md, chore.md, design.md, implement.md, next.md, plan.md, prd.md, promote.md, remember.md, request.md, review.md, tech.md, update-plan.md, update-req.md, update-task.md, update-tech.md, validate.md`), replace the existing 5-line marker block:
  ```
  <!-- preflight: required -->
  Run the preflight from `.specaffold/preflight.md` first.
  If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
  this command immediately with no side effects (no agent dispatch,
  no file writes, no git ops); print the refusal line verbatim.
  ```
  with the new 12-line combined resolver+marker block (verbatim, byte-identical across all 18 files; matches T1's `CANONICAL_BLOCK` constant in `bin/scaff-lint`):
  ```
  <!-- preflight: required -->
  # Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
  if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
    _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
    SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
    unset _scaff_src_link
  fi
  [ -d "${SCAFF_SRC:-}" ] || { printf '%s\n' 'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo' >&2; exit 65; }
  Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.
  If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
  this command immediately with no side effects (no agent dispatch,
  no file writes, no git ops); print the refusal line verbatim.
  ```
  No other content is modified by Edit A — every edit is a 5-line → 12-line replacement at the SAME insertion point per file (immediately after the file's frontmatter, replacing the existing marker block in place).

  **Edit B — `bin/*` source-line rewrite (5 files only)**. In the 5 files identified by `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` (per §1.2; expected: `archive.md`, `implement.md`, `next.md`, `review.md`, `validate.md` — but **the developer MUST re-run this grep at dispatch time** per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`; if the result drifts from the §1.2 list, STOP and `/scaff:update-plan`), replace every occurrence of `$REPO_ROOT/bin/scaff-` with `$SCAFF_SRC/bin/scaff-`. Use a single `sed` invocation per file with a non-GNU-only flag form: `sed -i '' 's|\\$REPO_ROOT/bin/scaff-|\\$SCAFF_SRC/bin/scaff-|g' <file>` on macOS / BSD. The `-i ''` two-arg form is mandatory per `.claude/rules/bash/bash-32-portability.md`. Verify with: `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` returns empty post-edit (AC2); `grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns the 5 names (subset of 18, NOT all 18 — only files that source bin/ get the rewrite).

  **NOTE** — the AC3 grep target (`SCAFF_SRC` in the marker block reference) is satisfied by Edit A directly: the new combined block contains `$SCAFF_SRC/.specaffold/preflight.md` in line 9 (the preflight directive). All 18 files match `grep -l '\\$SCAFF_SRC/.specaffold/preflight.md' .claude/commands/scaff/*.md` post-edit.

  **Atomicity discipline** (per §1.3 / §1.4 / parent-feature §4 atomicity argument): Edits A and B are landed in ONE commit (one task, one bulk edit). Lint exits 0 only when ALL 18 files carry the new canonical block; any subset = lint red. `git revert` is one-step recovery if T4 lands a syntactically-broken block.

  **Verbatim file-existence guard before starting** (per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`):
  ```
  ls .claude/commands/scaff/ | wc -l    # expected: 18
  ls .claude/commands/scaff/scaff-init.md   # expected: No such file or directory
  grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md   # expected: 5 files (archive, implement, next, review, validate)
  ```
  If any expected count drifts, STOP and `/scaff:update-plan`.
- **Deliverables**: 18 file edits — `.claude/commands/scaff/{archive,bug,chore,design,implement,next,plan,prd,promote,remember,request,review,tech,update-plan,update-req,update-task,update-tech,validate}.md`. Each gains 7 lines (5 → 12) in the marker block; 5 of them additionally have `$REPO_ROOT/bin/scaff-` replaced by `$SCAFF_SRC/bin/scaff-` (no line count change for those rewrites — same number of lines, different text).
- **Verify**: `bash test/t113_scaff_src_resolver.sh` (T2 authors); `bin/scaff-lint preflight-coverage; echo "exit=$?"` returns `exit=0` with 18 `ok:<file>` lines. Also AC2: `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` returns empty; `grep -l '\\$SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns 5 files. Also AC3: `grep -l '\\$SCAFF_SRC/.specaffold/preflight.md' .claude/commands/scaff/*.md` returns 18 files. Also AC6 dogfood-regression: `bin/scaff-lint preflight-coverage` returns 0 (i.e. `$SCAFF_SRC` resolves to `$REPO_ROOT` in source-repo, so all paths still work). `git diff --stat HEAD~1 -- .claude/commands/scaff/` shows roughly `+126 -90` (5-line block × 18 files removed, 12-line block × 18 added, plus a few `s/REPO_ROOT/SCAFF_SRC/g` changes in 5 files).
- **Depends on**: T1 (lint canonical block must be authored before T4 edits the 18 files; the 18 files MUST byte-match T1's `CANONICAL_BLOCK`), T3 (T3 ships the matching shim heredoc; cross-surface byte-identity is asserted by t113)
- **Parallel-safe-with**: — (single task in W2; no peer)

  **Pre-commit hook clean path** (per §1.4): T4's worktree branches off post-W1 main (NEW lint + UNCHANGED markers in main; T4 sweeps markers in worktree before commit). At T4 dev commit time, working tree has NEW lint + NEW markers → hook passes. **No `--no-verify` needed** for T4's dev commit. T4 IS the satisfier; this is the one commit between W1 close and W2 close that should pass cleanly.
- [ ]

---

## Team memory

Applied entries:

- `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md` — DRIVES §1.4 enumeration of every `--no-verify` site (T1 dev commit, every W1 merge, W1 bookkeeping; T2/T3 conditional; T4 + W2 bookkeeping clean). Eleventh-occurrence discipline ported verbatim: STATUS Notes log every bypass per the dogfood-paradox / opt-out-bypass-trace contract.
- `shared/dogfood-paradox-third-occurrence.md` — TWELFTH occurrence; the structural-only-at-validate / runtime-on-next-feature split holds. Confirms the umbrella pattern at scale (12 occurrences); no new failure mode beyond the umbrella.
- `tpm/parallel-safe-requires-different-files.md` — DRIVES W1 parallel-safety (T1 = `bin/scaff-lint`, T2 = `test/t113_*.sh`, T3 = `bin/scaff-seed`; three disjoint files, no overlap). DRIVES W2 single-task design (T4 owns 18 files atomically; splitting into 18 parallel tasks gains nothing per parent-feature §4).
- `tpm/pre-declare-test-filenames-in-06-tasks.md` — DRIVES test counter assignment: t113 (next after t112 from parent feature). Single new test file; no collisions verified at plan-write time via `ls test/t113_*.sh`.
- `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md` — DRIVES verbatim verification commands embedded in §1.1, §1.2, T1 Scope, T3 Scope, T4 Scope (every file-count claim and every grep claim has the exact `ls`/`grep` command for the developer to paste-and-run at dispatch).
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` — every `- [ ]` below stays unchecked at plan-write time (Risk #6).
- `tpm/task-scope-fence-literal-placeholder-hazard.md` — every test filename, command-file path, and line number is verbatim; no `tN_` / `<fill>` / `<new file>` placeholders (Risk #7).
- `qa-analyst/partial-wiring-trace-every-entry-point.md` (referenced via parent-feature 11th-occurrence dogfood-paradox appendix) — DRIVES Risk #3 mitigation (T3 edits BOTH shim heredocs at lines 797 + 1384; T3 Verify diffs the two emit sites for byte-identity) and Risk #4 (cross-surface resolver byte-identity check across lint canonical block, two scaff-seed heredocs, and 18 marker blocks).
- `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` — DRIVES W1 → W2 strict serial: enforcement layer (lint extension) ships in W1; satisfier (marker sweep) ships in W2. Wave boundary carries the ordering constraint without per-task `Depends on:` chains across the wave boundary (T4 declares `Depends on: T1, T3` for clarity; the wave boundary is the canonical enforcement).

Proposed new memory: defer to validate retrospective. Candidate lessons that may surface:
- **"Cross-surface byte-identity invariants need a single source of truth + cross-checks at every emit site"** — generalises the lint canonical block + 18 marker blocks + 2 scaff-seed heredocs + 1 sandbox-resolver pattern. May already be covered by `qa-analyst/partial-wiring-trace-every-entry-point.md` and `architect/by-construction-coverage-via-lint-anchor.md` together; confirm post-archive.
- **"Resolver byte-identity across N surfaces — pick a canonical surface, lint the rest against it"** — names the "lint owns the canonical block" choice in this feature. Differs subtly from "by-construction-coverage" because here the canonical block is enforced ACROSS surface types (lint script + bin script + markdown), not just within one surface type. Confirm post-archive.
