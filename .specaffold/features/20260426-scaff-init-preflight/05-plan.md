# Plan — scaff-init-preflight

- **Feature**: `20260426-scaff-init-preflight`
- **Stage**: plan
- **Author**: TPM
- **Date**: 2026-04-26
- **Tier**: standard (every wave merge runs reviewer-style + reviewer-security per `.claude/rules/reviewer/*.md`; reviewer-performance optional but invoked here because the new lint runs on a tight loop of 18 files — see Risk #4)

PRD: `03-prd.md` (R1–R13, AC1–AC13, D1–D6).
Tech: `04-tech.md` (D1–D9, mechanism: Option A — convention + lint).

---

## 1. Approach

This feature ships a **preflight gate** that sits at the top of every `/scaff:<name>` slash command and refuses to run when the current working directory has no `.specaffold/config.yml`. The mechanism per tech-D1 is:

- **One shared body** at `.specaffold/preflight.md` (NOT under `.claude/commands/scaff/` — that directory is harvested into slash commands, so any `*.md` there auto-registers as a spurious `/scaff:<name>` command per architect memory `commands-harvest-scope-forbids-non-command-md`).
- **One wiring block per command file** (5 lines: HTML-comment marker `<!-- preflight: required -->` + 4-line imperative directive that points at `.specaffold/preflight.md`).
- **One lint subcommand** `bin/scaff-lint preflight-coverage` that asserts every `*.md` under `.claude/commands/scaff/` carries the marker; failure is a finding (exit 1).
- **Pre-commit shim wiring** so the lint runs on every commit. The shim template lives in `bin/scaff-seed` (line 733) and is the single source of truth for what consumer repos install; this repo's own `.git/hooks/pre-commit` is also installed for dogfooding.

### 1.1 Authoritative count: **18**, not 17

Architect Note A (tech §5): PRD §5.3 R3 prose says "exactly 17 commands" but the enumerated list contains 18 names (the commands are: `archive`, `bug`, `chore`, `design`, `implement`, `next`, `plan`, `prd`, `promote`, `remember`, `request`, `review`, `tech`, `update-plan`, `update-req`, `update-task`, `update-tech`, `validate`). The directory contains 18 files. **Treat 18 as authoritative.** Every task below references 18; the lint targets 18; structural tests assert 18. PM may opt to fix the R3 prose at archive-retro time via `/scaff:update-req`; the plan does not block on it (architect's "minor note, not blocker" classification holds).

### 1.2 `scaff-init` exclusion is vacuous; no special-case logic

Architect Note B (tech §5, D8): `scaff-init` is a **skill** at `.claude/skills/scaff-init/{SKILL.md,init.sh}`, NOT a slash command. There is **no** `.claude/commands/scaff/scaff-init.md` file. PRD AC3 ("`scaff-init.md` does not reference the shared mechanism") is satisfied vacuously by file-system reality. **The lint must NOT add a `scaff-init` allow-list entry, exclusion regex, or any filtering** — adding such filtering would be dead code that future maintainers would have to reason about. Verbatim verification: `ls .claude/commands/scaff/scaff-init.md` returns "No such file or directory". This claim is embedded into T2's task scope per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`.

### 1.3 Wave sequencing — strict serial (W1 → W2 → W3 → W4)

Per `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` widened to four waves: producer-consumer chain has four layers here.

- **W1 — gate body + lint subcommand (producers)** — Author `.specaffold/preflight.md` (the gate body) and extend `bin/scaff-lint` with the new `preflight-coverage` subcommand. Author the structural test for the gate body (extracts the SCAFF PREFLIGHT fenced bash block, sandboxes HOME, asserts refusal output). At W1 close, `.specaffold/preflight.md` exists and `bin/scaff-lint preflight-coverage` runs cleanly against the **current** state of `.claude/commands/scaff/` — which has zero markers — and therefore reports 18 findings and exits 1. That "negative" exit is **expected at W1 close**; it's the lint's correct behaviour against a not-yet-wired tree, and is asserted by W1's test (mutation test in reverse: the lint MUST exit 1 when no marker is present).
- **W2 — pre-commit hook wiring (consumer of W1's lint)** — Update the `bin/scaff-seed` shim template (line 733) so newly-init'd consumer repos call BOTH `scaff-lint scan-staged` AND `scaff-lint preflight-coverage`. Install/refresh this repo's own `.git/hooks/pre-commit` to match. Author the structural test for the shim template. **W2 close still has the lint exiting 1 against the un-wired tree** (markers haven't been added yet). That's by design — see dogfood-paradox sequencing below.
- **W3 — marker propagation across all 18 command files (the dogfood wave)** — Add the 5-line wiring block (HTML comment + 4-line imperative directive) to all 18 files in `.claude/commands/scaff/` in **one bulk task**. Rationale for one task vs 18 (decision below in §3 risk #1 / §4): the 18 edits are byte-identical, must land atomically (any subset = lint still red), and one merge diff is reviewable as a single shape. Author the structural coverage test. At W3 close, `bin/scaff-lint preflight-coverage` exits 0 across all 18 files — and the pre-commit hook installed in W2 begins to enforce going forward.
- **W4 — README mention + runtime sandbox verification + final gate-state cleanup** — One sentence to `README.md` per tech-D9 / R13 / AC6. The runtime AC sandbox test is authored as one new file under `test/` and asserts: refusal one-liner content (AC7), zero side effects (AC8), passthrough silence (AC10), malformed-config passthrough (AC11). Plus the structural test that all 18 baseline diffs are restricted to the wiring block (AC12 / AC13).

### 1.4 Dogfood paradox sequencing (eleventh occurrence)

Per `shared/dogfood-paradox-third-occurrence.md` (10 prior occurrences), this feature ships a gate that lives inside the 18 command files that any subsequent scaff invocation depends on. Hand-edit recoverability is the dominant constraint:

> **Sequencing rule applied**: land the gate body and the lint **first** (W1), then the pre-commit hook (W2), then the markers (W3) **last**.

Why: hand-editing 18 files to **add** a missing marker line is mechanical (same 5-line block in each); hand-editing 18 files to **remove** a bad marker line is mechanical too — but if W3 lands a syntactically-broken wiring directive (e.g. a typo'd path to `.specaffold/preflight.md`), every subsequent `/scaff:*` invocation in this repo loads the bad directive at the top of the file. The user could not run `/scaff:update-plan` to fix it (gate would refuse — wait, actually `.specaffold/config.yml` exists in this repo so the gate passes; but the assistant would still execute the bad directive and look for a non-existent file). Recovery is plain `Edit`-tool surgery on 18 files. By landing the gate body first, the shape of the directive is reviewable in isolation (W1 ships the canonical text); W3 then bulk-applies that exact text. This **minimises blast radius** at the marker-propagation step because the directive's text is already known-good when W3 starts.

If W3 breaks something despite the sequencing, recovery is `git revert` on the bulk-add commit — single-task design makes this surgical.

### 1.5 Out-of-scope / deferred (per PRD §3, tech §6)

- Config schema validation (NG5) — deferred; presence-only check per R2 / D2.
- Bypass flag (NG7 / D3) — deferred; refusal IS the policy.
- Help-exempt path (R11 / D6) — deferred; no help convention exists.
- Gating `bin/scaff-*` scripts (NG6) — deferred; scripts inherit the gate transitively via their command-file callers.
- Updating PRD R3 prose ("17" → "18") — deferred to archive retrospective. PM's call.

---

## 2. Wave schedule

| Wave | Purpose                                                                                | Task IDs       | Parallelisation notes                                                                                  |
|------|----------------------------------------------------------------------------------------|----------------|--------------------------------------------------------------------------------------------------------|
| W1   | Gate body + lint subcommand + structural test for the gate's fenced shell block        | T1, T2, T3     | T1 writes `.specaffold/preflight.md` (new); T2 edits `bin/scaff-lint`; T3 writes `test/t107_preflight_lint_and_body.sh` (new). Three disjoint files. Fully parallel-safe. |
| W2   | Pre-commit shim wiring (template in scaff-seed + this repo's own hook) + shim test     | T4, T5         | T4 edits `bin/scaff-seed` (line ~733 shim template); T5 writes `test/t108_precommit_preflight_wiring.sh` (new). Disjoint files. Parallel-safe. The local `.git/hooks/pre-commit` install is folded into T4's verify step (it's a side effect of running scaff-seed's update path; no separate task). |
| W3   | Marker propagation to all 18 command files + structural coverage test                  | T6, T7         | T6 edits all 18 files in `.claude/commands/scaff/` in one atomic commit; T7 writes `test/t109_marker_coverage.sh` (new). T6 owns the bulk file edit; T7 only reads the result. Parallel-safe (T7 runs against the post-T6 tree, but T7's test author can write the test logic against the eventual shape — `Verify:` will fail until T6 merges, which is fine for parallel-within-wave authoring). |
| W4   | README sentence + runtime sandbox AC harness + AC12/AC13 baseline-diff structural test | T8, T9, T10    | T8 edits `README.md`; T9 writes `test/t110_runtime_sandbox_acs.sh` (new); T10 writes `test/t111_baseline_diff_shape.sh` (new). Three disjoint files. Fully parallel-safe. |

**Wave count**: 4. **Task count**: 10. **Per-wave counts**: W1 = 3 · W2 = 2 · W3 = 2 · W4 = 3.

### Parallel-safety analysis per wave

**W1** — Three tasks across three disjoint file namespaces.
- T1: writes `.specaffold/preflight.md` (new file; directory `.specaffold/` already exists).
- T2: edits `bin/scaff-lint` — adds one `case` arm and one new function.
- T3: writes `test/t107_preflight_lint_and_body.sh` (new test file).
No file overlap; no shared fixture or DB state; tests run against on-disk artefacts so isolation is per-test-script via sandbox-HOME (T3 uses `mktemp -d`).

**W2** — Two tasks across two disjoint file namespaces.
- T4: edits `bin/scaff-seed` (one-line change at the shim heredoc, line ~733; the template gets a second `&&`-chained invocation of `bin/scaff-lint preflight-coverage`). Also installs/refreshes this repo's own `.git/hooks/pre-commit` as part of `Verify:` (running `bin/scaff-seed init --from . --ref HEAD` from a sandboxed consumer asserts the template change; running it against this repo via `cmd_update` refreshes the shim — but `cmd_update` does NOT install hooks per existing tech-§6 D11, so the local hook refresh is a one-time manual `cp` step in `Verify:`).
- T5: writes `test/t108_precommit_preflight_wiring.sh` (new test file). The test asserts both that the shim template in `bin/scaff-seed` contains `preflight-coverage` AND that a sandboxed init produces a hook file containing both invocations.
No file overlap.

**W3** — Two tasks.
- T6: edits all 18 files in `.claude/commands/scaff/`. This is the **only** task in the project that touches those files in this feature. No same-wave hazard; sequenced after W2 so the pre-commit hook is already wired (i.e. the bulk commit will pass its own pre-commit check). T6 is one bulk task per §4 below.
- T7: writes `test/t109_marker_coverage.sh` (new test file). Independent of T6 at authoring time; its `Verify` runs against the post-T6 tree.
No file overlap. T7 is parallel-safe-with T6.

**W4** — Three tasks.
- T8: edits `README.md` — adds one sentence near the existing scaff-command introduction; co-occurrence of `config.yml` and `scaff-init` on one line per AC6 grep target.
- T9: writes `test/t110_runtime_sandbox_acs.sh` (new test file). Runs the AC7/AC8/AC10/AC11 sandbox harness.
- T10: writes `test/t111_baseline_diff_shape.sh` (new test file). Asserts AC12 (each of 18 files diffs only by the wiring block) and AC13 (passthrough byte-identity) — a structural diff against the W3-pre baseline captured in T6's commit message or via a small fixture.
No file overlap.

### Test filename pre-declaration (per `tpm/pre-declare-test-filenames-in-06-tasks.md`)

Next available counter as of 2026-04-26: `t107` (last used `t106` in `20260424-entry-type-split`). Wave assignments:

- T3 → `test/t107_preflight_lint_and_body.sh` (W1)
- T5 → `test/t108_precommit_preflight_wiring.sh` (W2)
- T7 → `test/t109_marker_coverage.sh` (W3)
- T9 → `test/t110_runtime_sandbox_acs.sh` (W4)
- T10 → `test/t111_baseline_diff_shape.sh` (W4)

Five new test files; none collide. `grep -hE '^- \*\*Deliverables\*\*' 05-plan.md | grep test/ | sort | uniq -d` returns empty.

---

## 3. Risks

1. **Dogfood paradox (eleventh occurrence)** — This feature ships the gate that every subsequent scaff invocation hits. Recovery from a broken wiring directive is hand-edit only (a refused gate cannot run `/scaff:update-plan`). Wait — `.specaffold/config.yml` exists in this repo, so the gate passes; the actual hazard is the assistant *reading* a malformed wiring directive at the top of the command file and following bad instructions (e.g. a typo'd path to `.specaffold/preflight.md` would lead to a "file not found" error mid-command). **Mitigation**: W1 lands the canonical wiring text first; W3's bulk edit pastes that exact text. The wiring block is reviewed once at W1 close (in T1's deliverable shape), then the lint enforces it once propagated. If W3 lands broken markers, `git revert` the W3 bulk commit is one-step recovery.

2. **18 vs 17 count drift** — PRD §5.3 R3 says "17"; tech §5 reconciles to 18. Tasks below all reference **18**. If a developer reads only the PRD (not the plan or tech), they may try to gate 17 files. **Mitigation**: every task's Scope explicitly says "all 18 files" with the verbatim `ls .claude/commands/scaff/` command embedded per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`. The lint (T2) does not hard-code a count — it scans the directory at runtime — so future additions auto-inherit.

3. **`scaff-init` non-existence at the gated directory** — Some readers may search for `.claude/commands/scaff/scaff-init.md` and not find it; if they then add an exclusion rule to the lint "to be safe", that's dead code per §1.2. **Mitigation**: T2's Scope explicitly forbids exclusion logic and embeds the verbatim `ls .claude/commands/scaff/scaff-init.md` command (expected: "No such file or directory"). T7's coverage test does NOT special-case scaff-init.

4. **Lint performance on a tight loop of 18 files** — Reviewer-performance memory (`shell-out-in-loop`) and architect tech §4.5 both flag this: a naïve implementation with `for f in *.md; do grep -F MARKER "$f"; done` spawns 18 forks. **Mitigation**: tech §4.5 prescribes `grep -L -F '<!-- preflight: required -->' .claude/commands/scaff/*.md` (single fork; lists files MISSING the marker). T2's Scope makes this explicit and `Verify:` runs `time bin/scaff-lint preflight-coverage` to confirm sub-100ms wall time on warm cache.

5. **Pre-checked checkboxes anti-pattern** — Per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`, every `- [ ]` below stays unchecked. TPM never writes `- [x]` at plan time; the orchestrator's per-wave bookkeeping commit is the sole `[x]` writer. Also per `tpm/checkbox-lost-in-parallel-merge.md`, post-wave audit flips any `[ ]` → `[x]` for tasks the wave actually merged.

6. **Placeholder-token hazard** — Per `tpm/task-scope-fence-literal-placeholder-hazard.md`, no `tN_` / `<fill>` / `<new file>` placeholders appear in any task's `Deliverables:` or `Verify:` field. All test filenames are pre-filled (§2 above). All command-file paths are listed verbatim.

7. **Wave-merge reviewer axis budget (tier=standard + opt-in performance)** — Every wave merge runs reviewer-style + reviewer-security; reviewer-performance is invoked at W1 (lint code path) and at W3 (no code, but the marker block is plain markdown — should be quick). Anticipated axis hits:
   - **security** — the gate body's refusal `printf` uses `%s` format with `$(pwd)` argv; no string-built shell command. The lint's grep targets `.claude/commands/scaff/*.md` — fixed scope, no user-supplied path. No injection surface.
   - **performance** — see Risk #4. Lint must use `grep -L -F` batch invocation, not a per-file fork loop.
   - **style** — bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md`. The fenced bash block in `.specaffold/preflight.md` uses only `[ -f ]`, `printf`, `pwd`, `exit`. The lint subcommand fits the existing `case` dispatch in `bin/scaff-lint` (line 413) and follows the existing exit-code contract (0/1/2).

8. **Pre-commit hook re-installation in this repo** — `bin/scaff-seed cmd_update` does NOT install hooks (existing tech §6 D11). For this repo to enforce the new lint, the hook needs a one-time manual refresh. **Mitigation**: T4's `Verify:` includes the exact `cp` / `printf` command to author `.git/hooks/pre-commit` locally with both lint subcommands. This is a one-time bootstrap, not a recurring deliverable.

---

## 4. Bulk vs per-file decision for W3 marker propagation

The TPM brief asked: should W3 add the marker as one bulk task or 18 per-file tasks?

**Decision: one bulk task (T6).** Justification:

1. **Atomicity is the contract.** Lint exits 0 only when ALL 18 files carry the marker. Any subset = lint red. A 18-task split would push 17 unrelated tasks into a "almost-passing" intermediate state at every partial wave-merge point; the orchestrator's per-task review would have to assert "lint is allowed to fail here, just not at end-of-wave" — confusing.
2. **Diff homogeneity.** The 5-line block is byte-identical across all 18 files. A reviewer reading 18 small diffs sees the same 5 lines 18 times — high noise-to-signal. A reviewer reading one bulk diff sees: "5 new lines, repeated 18 times, no other content changes" and can verify with one `git diff --stat` / `git show` invocation. AC12 ("each diff restricted to the wiring addition") is asserted by T10's structural test which reads from the W3 commit.
3. **Reversibility.** `git revert` on a single bulk commit unwinds the change atomically. If W3 lands broken wiring, recovery is one revert + redo, not 18 reverts.
4. **No parallelism gain.** Per `tpm/parallel-safe-requires-different-files.md`, parallelism requires different files. 18 tasks editing 18 distinct files would be parallel-safe in principle, but each task is < 1 minute of work (paste 5 lines at a known location) — splitting wastes orchestration overhead.

If W3 were to be split per-file in some future analogous feature (say, 50+ files where the per-file edit is non-trivial), the bulk-vs-split call would flip. For 18 byte-identical 5-line additions, bulk wins.

---

## 5. Open questions

None. Every PRD requirement has an AC; every AC has a structural or runtime task; every tech-D has a task or an explicit no-op carve-out (D8 = scaff-init no-change is structurally satisfied by T2's `ls` verification + T7's coverage test which scans the gated directory only).

---

## 6. Task checklist

Each task below uses the merged-form task block shape per `tpm.appendix.md` §"Task format and wave schedule rules".

---

### W1 — Gate body + lint subcommand + structural test

## T1 — Author `.specaffold/preflight.md` with the SCAFF PREFLIGHT fenced bash block and the imperative directive prose

- **Milestone**: M1
- **Requirements**: R1, R2, R5, R6, R7, R8, R9, R10
- **Decisions**: D1, D4, D5, tech-D2, tech-D4, tech-D5, tech-D7
- **Scope**: Create new file `.specaffold/preflight.md` containing two operative parts. **Part 1 (assistant-readable directive prose)**: a brief opening section (3–6 sentences) that names the gate's purpose ("preflight gate fires when `.specaffold/config.yml` is missing"), names the runtime CWD as the resolution anchor (R1), names the recovery command (`/scaff-init`), and instructs the assistant to execute the fenced bash block below this prose section. **Part 2 (deterministic shell snippet)**: a fenced bash block bracketed by exact sentinel comments `# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===` and `# === END SCAFF PREFLIGHT ===` (so test harness `awk` extracts cleanly per tech-D7), containing exactly the body shown in tech §3 D7:
  ```
  if [ ! -f ".specaffold/config.yml" ]; then
    printf 'REFUSED:PREFLIGHT — .specaffold/config.yml not found in %s; run /scaff-init first\n' "$(pwd)" >&2
    exit 70
  fi
  ```
  Verbatim. Bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md` — no `[[ =~ ]]`, no GNU-only flags. The refusal one-liner contains all three required tokens (`.specaffold/config.yml`, `$(pwd)` substituted, `/scaff-init`) on one line, satisfying R5 and AC5/AC7. Exit code 70 is documented in tech §3 D7 as `EX_PROTOCOL`. After the fenced block, add a short tail section (1–2 sentences) instructing the assistant: "If the block exits non-zero, abort the command immediately with no side effects; print the refusal line verbatim; do not invoke any sub-agent." The whole file is plain markdown; English only per `.claude/rules/common/language-preferences.md` carve-out (b).
- **Deliverables**: `.specaffold/preflight.md` (new file).
- **Verify**: `bash test/t107_preflight_lint_and_body.sh` (T3 authors this test; T1 delivers the body). Also `[ -f .specaffold/preflight.md ]` and `grep -F '# === SCAFF PREFLIGHT' .specaffold/preflight.md` and `grep -F 'REFUSED:PREFLIGHT' .specaffold/preflight.md`.
- **Depends on**: —
- **Parallel-safe-with**: T2, T3
- [ ]

## T2 — Extend `bin/scaff-lint` with the `preflight-coverage` subcommand

- **Milestone**: M1
- **Requirements**: R4, R8
- **Decisions**: D5, tech-D6
- **Scope**: Add a new subcommand `preflight-coverage` to `bin/scaff-lint` per tech-D6. Modify `bin/scaff-lint` in two places:
  1. Add a new bash function `run_preflight_coverage()` (above the existing `case` dispatch at line 413) that invokes `grep -L -F '<!-- preflight: required -->' .claude/commands/scaff/*.md` (per tech §4.5: single fork via `grep -L`, NOT a per-file shell-out loop — reviewer-performance memory `shell-out-in-loop`). Files listed by `grep -L` are MISSING the marker. For each such file, emit `missing-marker:<path>` to stdout. For each file that matched (i.e. carries the marker), emit `ok:<path>`. To get both classifications cheaply, capture the missing-list in a variable (single fork) then iterate the directory listing with bash word-splitting (no further forks per file). Exit 0 if every file has the marker; exit 1 if any file is missing the marker; exit 2 on usage error (any positional argument supplied). **Do NOT add any allow-list or exclusion logic for `scaff-init`** — that file does not exist in `.claude/commands/scaff/` (verify with `ls .claude/commands/scaff/scaff-init.md` → expected "No such file or directory"). Adding exclusion logic would be dead code; per architect tech §3 D6 self-allow-list note. The lint's scope is the literal directory `.claude/commands/scaff/*.md` — non-recursive, no filtering.
  2. Add a new `case` arm to the existing dispatch (around line 413) for `preflight-coverage`. Pattern: `preflight-coverage)` arm with no positional args (reject if any). The arm calls `run_preflight_coverage; exit $?`.
  Bash 3.2 / BSD portable. `set -u -o pipefail` already in place (line 44). Existing exit-code contract (0/1/2) preserved.
- **Deliverables**: `bin/scaff-lint` (edit; one new function + one new `case` arm).
- **Verify**: `bash test/t107_preflight_lint_and_body.sh` (T3 authors). Also `bash -n bin/scaff-lint` for syntax check. Also a manual smoke step: `bin/scaff-lint preflight-coverage; echo "exit=$?"` from repo root — at W1 close, this should print 18 `missing-marker:` lines and `exit=1` (none of the command files carry the marker yet; this confirms the lint's negative path works). Also `time bin/scaff-lint preflight-coverage` should run in under 100ms warm cache (reviewer-performance budget).
- **Depends on**: —
- **Parallel-safe-with**: T1, T3
- [ ]

## T3 — Author structural test for the gate body and the lint subcommand

- **Milestone**: M1
- **Requirements**: R1, R2, R5, R6, R7, R10
- **Decisions**: D4, D5, tech-D6, tech-D7
- **Scope**: Author `test/t107_preflight_lint_and_body.sh` covering AC1, AC5, plus the negative-path lint behaviour. Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md`: top-of-script `SANDBOX="$(mktemp -d)"`, `trap 'rm -rf "$SANDBOX"' EXIT`, `export HOME="$SANDBOX/home"`, preflight `case "$HOME"` assertion. Assertions:
  - **A1 (AC1)**: `[ -f .specaffold/preflight.md ]`.
  - **A2 (AC1, AC5)**: `grep -F '# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===' .specaffold/preflight.md` matches AND `grep -F '# === END SCAFF PREFLIGHT ===' .specaffold/preflight.md` matches AND the block between them contains the literal token `REFUSED:PREFLIGHT`, the literal `/scaff-init`, and the literal `.specaffold/config.yml`.
  - **A3 (negative-path lint)**: From repo root (no sandboxing — this asserts the lint binary works against the actual tree as-is at W1 close, when no markers are present), run `bin/scaff-lint preflight-coverage` and assert exit code 1 AND assert stdout contains 18 lines starting with `missing-marker:` (one per command file). After W3 lands, T7 will assert the inverse (exit 0 + 18 `ok:` lines); at W1 close T3 asserts the lint's negative path. **Important**: this assertion's expectations flip after W3 merges. Document inside the test with a comment block: `# At W1 close: 18 missing-marker lines, exit 1. After W3 merges: 18 ok lines, exit 0. T7 asserts the post-W3 state; this test asserts the W1-close state and is RE-RUN after each wave to confirm the flip happens cleanly.` — alternatively gate the expectation on whether ANY command file carries the marker (count `grep -lF '<!-- preflight: required -->' .claude/commands/scaff/*.md | wc -l`) and assert ternary: 0 markers → exit 1 + 18 missing-marker lines; 18 markers → exit 0 + 18 ok lines; intermediate → fail (lint mid-state is a planning bug per §4 atomicity argument). Choose ternary.
  - **A4 (AC4 by-construction)**: mutation test — copy `.claude/commands/scaff/archive.md` to a temp copy under `$SANDBOX`, simulate "marker removed" by writing a no-marker variant, run the lint against a fixture directory `$SANDBOX/cmd-fixture/` containing one no-marker file, assert exit 1 and `missing-marker:` for that file. (This requires the lint to accept a path argument OR to test against a temporary `.claude/commands/scaff/` overlay; tech-D6 says the subcommand operates on a fixed scope, so use a `mktemp -d` sandbox and `cd` into it, mocking the directory shape.) Easier alternative: skip the mutation overlay test in T3 and rely on T7's post-W3 assertion + T9's runtime AC harness; T3 covers AC1/AC5/lint-negative only. **Choose the easier alternative**: T3 covers A1/A2/A3 only; mutation testing is implicit in T7's post-W3 expected-state assertion.
  - The test must also `bash -n .specaffold/preflight.md`'s extracted shell block — extract via `awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' .specaffold/preflight.md > "$SANDBOX/extracted.sh"` then `bash -n "$SANDBOX/extracted.sh"` (syntax check). Then run it once in a sandbox CWD without `.specaffold/config.yml` and assert exit 70 + stdout/stderr contains `REFUSED:PREFLIGHT` (this is a lightweight precursor to T9's full runtime AC harness; smoke-only here).
- **Deliverables**: `test/t107_preflight_lint_and_body.sh` (new, executable).
- **Verify**: `bash test/t107_preflight_lint_and_body.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2
- [ ]

---

### W2 — Pre-commit shim wiring (consumer of W1's lint)

## T4 — Update the `bin/scaff-seed` shim template to invoke both `scan-staged` and `preflight-coverage`; refresh this repo's local pre-commit hook

- **Milestone**: M2
- **Requirements**: R4, R8
- **Decisions**: D5, tech-D6
- **Scope**: Edit `bin/scaff-seed` at the shim heredoc (currently line 733):
  ```
  printf '#!/usr/bin/env bash\n# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate\nexec bin/scaff-lint scan-staged "$@"\n' \
  ```
  Replace with a two-invocation shim:
  ```
  printf '#!/usr/bin/env bash\n# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate\nset -e\nbin/scaff-lint scan-staged "$@"\nbin/scaff-lint preflight-coverage\n' \
  ```
  Note: `set -e` ensures the second invocation only runs on the first's success; either subcommand failing aborts the commit. The order is `scan-staged` first (existing behaviour preserved) then `preflight-coverage` (new). Verbatim verification: `grep -n 'preflight-coverage' bin/scaff-seed` should match exactly one line in the shim template. The shim_state classifier at line 339 checks for the literal `'scaff-lint'` string; the new shim still contains it, so existing init/idempotency behaviour is unchanged.
  Also refresh this repo's own `.git/hooks/pre-commit` so dogfood enforcement is live: run the **exact** following commands from repo root once at the end of T4 (these are listed verbatim per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md` so the developer pastes-and-runs):
  1. `[ -f .git/hooks/pre-commit ] && cp .git/hooks/pre-commit .git/hooks/pre-commit.bak.$(date +%s)` (no-force backup per `.claude/rules/common/no-force-on-user-paths.md`).
  2. `printf '#!/usr/bin/env bash\n# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate\nset -e\nbin/scaff-lint scan-staged "$@"\nbin/scaff-lint preflight-coverage\n' > .git/hooks/pre-commit`
  3. `chmod +x .git/hooks/pre-commit`
  At T4 close, the local hook runs both subcommands. Note that running `git commit` at this point will FAIL because no markers are present yet (T6 fixes that in W3). The orchestrator's W2 bookkeeping commit will need to bypass the local hook (`git commit --no-verify` is acceptable in the bookkeeping path per shared/dogfood-paradox-third-occurrence.md "self-shipping mechanism not yet live for this commit"). **The orchestrator's W2 bookkeeping commit MUST use `--no-verify` and STATUS Notes MUST log this**; T4's verify command does NOT itself attempt a commit.
- **Deliverables**: `bin/scaff-seed` (edit, one heredoc replacement at line ~733); `.git/hooks/pre-commit` (created or replaced; not a tracked file but its presence is a runtime deliverable).
- **Verify**: `bash test/t108_precommit_preflight_wiring.sh` (T5 authors). Also: `grep -F 'preflight-coverage' bin/scaff-seed | wc -l` returns 1; `[ -x .git/hooks/pre-commit ]` AND `grep -F 'preflight-coverage' .git/hooks/pre-commit` matches.
- **Depends on**: T2 (lint subcommand must exist before the shim references it; W1 → W2 strict serial guarantees this)
- **Parallel-safe-with**: T5
- [ ]

## T5 — Author structural test for the pre-commit shim wiring

- **Milestone**: M2
- **Requirements**: R4
- **Decisions**: D5, tech-D6
- **Scope**: Author `test/t108_precommit_preflight_wiring.sh` covering AC4 (by-construction inheritance via lint + pre-commit). Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md`. Assertions:
  - **A1 (template)**: `grep -F 'preflight-coverage' bin/scaff-seed` matches at least once and `grep -nF 'scan-staged' bin/scaff-seed` AND `grep -nF 'preflight-coverage' bin/scaff-seed` both appear in the shim heredoc context (within ~5 lines of the `pre-commit shim — installed by bin/scaff-seed` comment).
  - **A2 (sandboxed init produces a hook with both invocations)**: in a `mktemp -d` sandbox, run a minimal consumer-repo recipe modelled on `test/t64_precommit_shim_wiring.sh`'s `make_consumer` helper (see lines 64–79 of that file for the verbatim template), then run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref HEAD)`. Assert: `[ -x "$CONSUMER/.git/hooks/pre-commit" ]`, `grep -F 'scaff-lint scan-staged' "$CONSUMER/.git/hooks/pre-commit"` matches, AND `grep -F 'scaff-lint preflight-coverage' "$CONSUMER/.git/hooks/pre-commit"` matches.
  - **A3 (idempotency)**: run `scaff-seed init` twice; assert second run reports `already:.git/hooks/pre-commit` and the hook contents are byte-identical.
  - **A4 (foreign hook untouched)**: per existing `t64`'s A5 pattern, pre-create a foreign hook (no `scaff-lint` sentinel), run init, assert `skipped:foreign-pre-commit:` appears and the foreign content is byte-identical to before.
- **Deliverables**: `test/t108_precommit_preflight_wiring.sh` (new, executable).
- **Verify**: `bash test/t108_precommit_preflight_wiring.sh` exits 0.
- **Depends on**: T4 (the test's A1/A2/A3 assertions require T4's edit to be in place; W2-internal dependency)
- **Parallel-safe-with**: T4 — the test author can write the test scaffolding (sandbox setup, helper functions) in parallel with T4's edit; the test only needs to be run/passing after T4 lands. Both edit different files (T4: `bin/scaff-seed`; T5: `test/t108_*.sh`). Parallel-safe by file-disjointness.
- [ ]

---

### W3 — Marker propagation to all 18 command files (the dogfood wave)

## T6 — Add the 5-line wiring block (HTML comment + 4-line imperative directive) to all 18 files in `.claude/commands/scaff/` in one bulk commit

- **Milestone**: M3
- **Requirements**: R3, R4, R8, R9
- **Decisions**: D5, tech-D1, tech-D3, tech-D8
- **Scope**: Edit each of the 18 files listed in §1.1 (verbatim list verifiable by `ls .claude/commands/scaff/`; expected count: 18; exact filenames: `archive.md`, `bug.md`, `chore.md`, `design.md`, `implement.md`, `next.md`, `plan.md`, `prd.md`, `promote.md`, `remember.md`, `request.md`, `review.md`, `tech.md`, `update-plan.md`, `update-req.md`, `update-task.md`, `update-tech.md`, `validate.md`). For **each** file, insert the following 5-line wiring block at a single, deterministic insertion point. **Insertion point**: per tech-D3 ("inline above the existing first step"), the block goes **immediately after the file's frontmatter (if present) or at the very top of the body content if no frontmatter exists**, and **before** the first command-body instruction. The exact block to insert (paste verbatim, no edits per file — content is identical across all 18):
  ```
  <!-- preflight: required -->
  Run the preflight from `.specaffold/preflight.md` first.
  If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
  this command immediately with no side effects (no agent dispatch,
  no file writes, no git ops); print the refusal line verbatim.
  ```
  No other content in any of the 18 files is modified — AC12 binds the diff to be the wiring addition only. The 5-line block is byte-identical across all files; this is verifiable post-edit by `git diff --stat HEAD~1 -- .claude/commands/scaff/` showing exactly `+5` per file × 18 files = `+90 -0`. Decision rationale for one bulk task vs 18 split tasks documented in §4 of this plan. **Do NOT edit `.claude/skills/scaff-init/SKILL.md`** (that's the exempt entry point per AC3 / D8). Verbatim file-existence guard before starting: `ls .claude/commands/scaff/scaff-init.md` should return "No such file or directory" — if it returns a real file, STOP and `/scaff:update-plan` (the directory shape has drifted since plan time; per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`).
- **Deliverables**: 18 file edits — `.claude/commands/scaff/{archive,bug,chore,design,implement,next,plan,prd,promote,remember,request,review,tech,update-plan,update-req,update-task,update-tech,validate}.md`. Each file gains exactly 5 added lines and zero removed lines.
- **Verify**: `bash test/t109_marker_coverage.sh` (T7 authors). Also: `bin/scaff-lint preflight-coverage; echo "exit=$?"` should now print 18 `ok:<path>` lines and `exit=0` (the post-W3 expected state). Also: `git diff --stat HEAD~1 -- .claude/commands/scaff/` should show exactly `90 insertions(+), 0 deletions(-)` across 18 files (5 lines × 18 files).
- **Depends on**: T1 (the wiring directive references `.specaffold/preflight.md` which T1 creates), T2 (the lint must exist before W3 commits — pre-commit hook needs the subcommand resolvable), T4 (the local pre-commit hook is wired in W2; T6's commit will pass that hook because the markers being added are exactly what the lint requires)
- **Parallel-safe-with**: T7
- [ ]

## T7 — Author structural test for marker coverage (the post-W3 expected state)

- **Milestone**: M3
- **Requirements**: R3, R4, R8
- **Decisions**: D5, tech-D6
- **Scope**: Author `test/t109_marker_coverage.sh` covering AC2 (every gated command references the shared mechanism) and AC3 (vacuous — scaff-init not in scope). Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (template uniformity even though the test is read-only against the on-disk tree). Assertions:
  - **A1 (AC2 coverage)**: for each of the 18 filenames in `.claude/commands/scaff/`, assert `grep -F '<!-- preflight: required -->' "$f"` matches at least once. List the 18 filenames as a verbatim bash array at the top of the test (do NOT use a glob expansion that could silently skip files; the array is the contract). If any file is missing the marker, fail with `missing-marker: <file>`.
  - **A2 (AC2 count)**: `ls .claude/commands/scaff/*.md | wc -l` returns 18. If a 19th file appears, the test fails with a clear "directory shape has drifted" message instructing the reader to update this test's hard-coded array. (This is a deliberate brittleness — see `tpm/briefing-contradicts-schema.md`: encode the schema explicitly so drift surfaces loudly.)
  - **A3 (lint exit-zero)**: `bin/scaff-lint preflight-coverage` exits 0 and stdout has 18 lines all starting with `ok:`.
  - **A4 (AC3 vacuous)**: `[ ! -e .claude/commands/scaff/scaff-init.md ]`. The file does NOT exist in the gated directory; AC3 is satisfied by file-system absence.
  - **A5 (AC3 sanity — skill files don't carry the marker, but that's also vacuous since they're not in the scan scope)**: `grep -rF '<!-- preflight: required -->' .claude/skills/` returns no matches (skills don't carry the marker; they're outside the scan scope per tech-D8). This guards against a future maintainer pasting the marker into the skill "to be safe", which would be dead code.
  - **A6 (mutation test)**: in a `mktemp -d` sandbox, copy `.claude/commands/scaff/archive.md` to `$SANDBOX/cmd-fixture/archive.md`, then `sed`-delete the marker line, then run a lint-equivalent grep (`grep -lF '<!-- preflight: required -->' "$SANDBOX/cmd-fixture/archive.md"` returns empty). This validates the lint's negative-path detection at fixture level without requiring the lint to accept a path argument.
- **Deliverables**: `test/t109_marker_coverage.sh` (new, executable).
- **Verify**: `bash test/t109_marker_coverage.sh` exits 0 (after T6 lands).
- **Depends on**: T6 (A1/A3 require markers to be in place; W3-internal dependency)
- **Parallel-safe-with**: T6 — T7 author writes the test logic in parallel with T6's bulk edit; T7's `Verify:` only passes after T6 merges. Different files (T6: 18 command files; T7: 1 new test file). Parallel-safe by file-disjointness.
- [ ]

---

### W4 — README sentence + runtime sandbox AC harness + baseline-diff structural test

## T8 — Add one sentence to `README.md` per tech-D9 / R13 / AC6

- **Milestone**: M4
- **Requirements**: R13
- **Decisions**: D5, tech-D9
- **Scope**: Add one sentence to `README.md` near the existing scaff-command introduction (likely the "Install" section after the `/scaff-init` command introduction; see lines 11–25 of current README for the scaff-init context). The sentence's content is the Developer's call (PRD R13 binds presence, not wording); two constraints bind:
  1. The sentence must contain both literal strings `config.yml` and `scaff-init` co-occurring on one line (so `grep -E '(config\.yml.*scaff-init|scaff-init.*config\.yml)' README.md` matches per AC6).
  2. The sentence must convey the gate's purpose: that `/scaff:*` commands refuse to run when `.specaffold/config.yml` is absent and that `/scaff-init` is the recovery command.
  Suggested wording (Developer free to refine): "Every `/scaff:*` command (except `/scaff-init`) refuses to run when `.specaffold/config.yml` is missing — run `/scaff-init` first." Single sentence; no new section header per architect memory `scope-extension-minimal-diff`. English only per `.claude/rules/common/language-preferences.md` carve-out (b).
  **Note**: The repo also has `README.zh-TW.md`. PRD R13 does NOT bind localisation; tech-D9 does NOT mention it. Per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md` verbatim verification: `ls README.zh-TW.md` should return the file. **Plan decision**: T8 edits `README.md` only. Localising to `README.zh-TW.md` is out of scope; if a future feature ships full README localisation parity, that feature can sweep this sentence in. Document this in STATUS Notes at T8 close.
- **Deliverables**: `README.md` (edit; +1 line, possibly minor reflow).
- **Verify**: `grep -E '(config\.yml.*scaff-init|scaff-init.*config\.yml)' README.md` matches at least one line. Also `git diff --stat HEAD~1 -- README.md` shows a small additive diff (≤ ~3 lines for the sentence + any whitespace).
- **Depends on**: —
- **Parallel-safe-with**: T9, T10
- [ ]

## T9 — Author runtime sandbox AC harness for AC7, AC8, AC10, AC11

- **Milestone**: M4
- **Requirements**: R1, R2, R5, R6, R7, R10
- **Decisions**: D4, D5, tech-D5, tech-D7
- **Scope**: Author `test/t110_runtime_sandbox_acs.sh` exercising the §6.2 runtime ACs by extracting the fenced bash block from `.specaffold/preflight.md` and running it directly inside a sandbox (assistant NOT in the loop per tech-D7). Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md`: top-of-script `SANDBOX="$(mktemp -d)"`, `trap 'rm -rf "$SANDBOX"' EXIT`, `export HOME="$SANDBOX/home"`, `mkdir -p "$HOME"`, preflight `case "$HOME"` assertion. Extract the SCAFF PREFLIGHT block once at top of the test:
  ```
  awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' .specaffold/preflight.md > "$SANDBOX/preflight.sh"
  ```
  Then create three sandbox CWDs as fixtures and run the extracted block in each. Assertions:
  - **A1 (AC7 — refusal happy path)**: `mkdir -p "$SANDBOX/proj-noinit" && cd "$SANDBOX/proj-noinit"`, run `bash "$SANDBOX/preflight.sh" 2>&1`, capture stdout+stderr+exit. Assert: exit code is 70; output contains literal `REFUSED:PREFLIGHT`; output contains literal `.specaffold/config.yml`; output contains literal `/scaff-init`; output contains the path `$SANDBOX/proj-noinit` (the runtime CWD); output is exactly one line (count newlines).
  - **A2 (AC8 — zero side effects)**: in `$SANDBOX/proj-noinit`, capture `find . -ls | sort | shasum | awk '{print $1}'` BEFORE running the snippet, run the snippet, capture the same hash AFTER. Assert: hashes are byte-identical. Also assert: `[ ! -d .specaffold ]` AND `[ ! -f STATUS.md ]` AND `[ ! -d .git ]` (no git ops occurred — the fixture has no git repo to begin with).
  - **A3 (AC10 — passthrough on present config)**: `mkdir -p "$SANDBOX/proj-init/.specaffold" && touch "$SANDBOX/proj-init/.specaffold/config.yml" && cd "$SANDBOX/proj-init"`, run the snippet. Assert: exit code 0; stdout AND stderr are both empty (silent passthrough per R7).
  - **A4 (AC11 — malformed config still passes)**: two sub-fixtures — one with `printf '' > .specaffold/config.yml` (zero-byte) and one with `printf 'not yaml at all\n@@@\n' > .specaffold/config.yml` (arbitrary non-YAML). Both invocations: exit 0, empty stdout+stderr.
  - **A5 (AC9 — exempt path is structurally satisfied)**: assert `[ ! -e .claude/commands/scaff/scaff-init.md ]` (file does not exist; no slash command for scaff-init; the gate cannot fire on the exempt path because there's nothing in the gated directory to fire from). This is a structural cross-check of D8.
  Each sandbox CWD is fresh (separate `mktemp -d` subdir); cleanup via the top-level trap.
- **Deliverables**: `test/t110_runtime_sandbox_acs.sh` (new, executable).
- **Verify**: `bash test/t110_runtime_sandbox_acs.sh` exits 0.
- **Depends on**: T1 (the test extracts from `.specaffold/preflight.md`; W1 → W4 strict serial guarantees this)
- **Parallel-safe-with**: T8, T10
- [ ]

## T10 — Author baseline-diff structural test for AC12 and AC13

- **Milestone**: M4
- **Requirements**: R3, R7
- **Decisions**: D5, tech-D3
- **Scope**: Author `test/t111_baseline_diff_shape.sh` asserting AC12 (each of 18 command files diffs from baseline by exactly the wiring addition) and AC13 (passthrough byte-identity preserved by structural assertion that no body content other than the wiring lines was added, removed, or modified). Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md`. Assertions:
  - **A1 (AC12 per-file diff shape)**: for each of the 18 files in `.claude/commands/scaff/`, run `git log --diff-filter=M --pretty=format:%H -- <file>` to find the most recent modifying commit, then `git show <commit>:<file>` to get the pre-change content, then `diff` against the current content. Assert: the diff is a pure addition (no deletions); the added lines are exactly the 5-line wiring block (HTML comment + 4 directive lines, byte-identical across all 18 files). For each file, the diff `+` lines must contain `<!-- preflight: required -->` AND the four directive lines and nothing else additive. Done by extracting the `+` lines from `git diff <commit-before-T6>..HEAD -- <file>` and asserting the multi-line content matches a fixed expected string.
  - **A2 (AC12 bulk diff stat)**: `git diff --stat <commit-before-T6>..HEAD -- .claude/commands/scaff/` reports exactly `+90 -0` (5 lines × 18 files, no deletions).
  - **A3 (AC13 byte-identical bodies modulo the wiring)**: for each of the 18 files, after stripping the 5-line wiring block (via `awk '!/^<!-- preflight: required -->/ && !/^Run the preflight from/ && !/^If preflight refuses/ && !/^this command immediately/ && !/^no file writes/'`), the remainder must be byte-identical to the pre-change content (`git show <commit-before-T6>:<file>`). This is a stronger form of A1 — A1 asserts the diff IS the wiring; A3 asserts the rest is unchanged.
  - The `<commit-before-T6>` reference must be resolvable at test-run time; T10's Scope embeds the lookup pattern: `git log --pretty=format:%H -- .claude/commands/scaff/archive.md | head -2 | tail -1` returns the commit immediately preceding T6's bulk-edit commit. (Brittle if the same file is touched again later by an unrelated feature — flag this in test header comment with `# WARNING: this test asserts the W3 baseline diff shape; if a future feature edits any command file, this test must be updated to track the new baseline. See plan §4 for the bulk-vs-split rationale.`)
- **Deliverables**: `test/t111_baseline_diff_shape.sh` (new, executable).
- **Verify**: `bash test/t111_baseline_diff_shape.sh` exits 0 (after T6 merges).
- **Depends on**: T6 (the baseline-diff is computed against the pre-T6 commit; W3 → W4 strict serial guarantees the commit exists)
- **Parallel-safe-with**: T8, T9
- [ ]

---

## Team memory

Applied entries:
- `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` — applied to the strict serial W1→W2→W3→W4 sequencing. Producer-consumer chain is four layers: gate body & lint (W1) → pre-commit shim wiring (W2) → marker propagation (W3) → docs & runtime AC harness (W4). Wave boundaries carry the ordering constraint; no per-task `Depends on:` chain is needed across waves (intra-wave deps still declared).
- `tpm/parallel-safe-requires-different-files.md` — applied to per-wave parallelism analysis. W1 has 3 disjoint files (preflight body, lint binary, test); W2 has 2 (scaff-seed binary, test); W3 is a single bulk edit + test (different files but T6 owns 18 files atomically); W4 has 3 disjoint files (README, two new tests). T6's bulk-edit-of-18-files is one task (not 18) per the §4 atomicity argument, so no intra-T6 collision.
- `tpm/pre-declare-test-filenames-in-06-tasks.md` — applied to test filename pre-declaration in §2 (t107..t111 across 5 test files; no same-wave or cross-wave collisions). Counter advanced from t106 (last used in `20260424-entry-type-split`).
- `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md` — applied to T2 (`ls .claude/commands/scaff/scaff-init.md` verbatim verification embedded in scope), T6 (verbatim verification of the 18 filenames embedded in scope), and T8 (`ls README.zh-TW.md` verbatim check before deciding scope of localisation work). Each task's Scope contains the exact `ls` / `grep` command, not just the claim.
- `tpm/task-scope-fence-literal-placeholder-hazard.md` — applied throughout: no `tN_` / `<fill>` / `<new file>` placeholders anywhere; every test filename and command-file path is verbatim.
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` — applied: every `- [ ]` below stays unchecked at plan-write time. Orchestrator owns `[x]` flips in post-wave bookkeeping commits.
- `tpm/checkbox-lost-in-parallel-merge.md` — applied as Risk #5 reminder: post-wave audit flips any `[ ]` → `[x]` for tasks the wave actually merged.
- `shared/dogfood-paradox-third-occurrence.md` — applied to §1.4 dogfood-paradox sequencing rationale (eleventh occurrence; gate body and lint land first, marker propagation last; recovery is hand-edit on plain markdown if W3 breaks; W2 bookkeeping commit must use `--no-verify` because the lint won't pass until W3 lands; this is logged in STATUS Notes per the discipline).
- `shared/status-notes-rule-requires-enforcement-not-just-documentation.md` — applied as the meta-rationale for the whole feature: the gate is enforced by mechanism (lint + pre-commit hook), not by per-author memory. T2/T4 deliver the enforcement; T7 asserts the enforcement holds at W3 close.

Proposed new memory (post-validate, only if pattern recurs): `tpm/by-construction-coverage-via-lint-anchor.md` (proposed by Architect in tech §Team memory) — when a new convention must apply to N files in a closed directory and a future author must inherit it without discipline, the four-layer wave shape (gate body → lint → pre-commit → markers) generalises. Wait until validate to see whether the structure recurs in a future feature.
