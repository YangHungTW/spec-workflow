# Tech — fix commands source from $SCAFF_SRC

## 1. Context & Constraints

### Existing stack (already committed)

- Bash 3.2 / BSD userland (macOS default) — see `.claude/rules/bash/bash-32-portability.md`. No `readlink -f`, no `realpath`, no `mapfile`, no `jq`.
- Python 3 available for atomic-write helpers in `bin/scaff-seed`; not required at command-preamble runtime.
- `.claude/skills/scaff-init/SKILL.md` already documents the canonical `$SCAFF_SRC` resolution order: (a) env-var override, (b) `readlink ~/.claude/agents/scaff` from the user-global symlink installed by `bin/claude-symlink install`. This feature lifts that pattern out of skill-prose and into actual shell code at the three runtime surfaces.
- `bin/scaff-seed` already emits a pre-commit shim via two byte-identical heredocs (lines 797 in `cmd_init`, 1384 in `cmd_migrate`); both must update together per the by-construction-coverage memory entry.
- Eighteen W3 marker blocks in `.claude/commands/scaff/*.md` already reference `.specaffold/preflight.md` by relative path — this feature rewrites that reference as part of the marker block.
- Source for the resolver pattern: `~/.claude/agents/scaff` is a symlink whose target ends in `/.claude/agents/scaff`; stripping that 21-character suffix yields the source-repo root.

### Hard constraints (cannot bend)

- **Bash 3.2 portability** (`.claude/rules/bash/bash-32-portability.md`) — the resolver runs at every `/scaff:*` invocation and at every commit; cannot use GNU-only flags or builtins.
- **Hook latency budget < 200ms** (`.claude/rules/reviewer/performance.md` rule 7) — the pre-commit shim now does `$SCAFF_SRC` resolution before each `scan-staged` / `preflight-coverage` call. The resolver must complete in single-digit milliseconds (`readlink` + parameter-expansion strip; one `[ -d ]` test).
- **No new file in consumer** — the architectural goal is the thin-consumer model from PRD R5. We cannot ship a sourced helper file into the consumer because that re-creates the chicken-and-egg this feature exists to remove. The resolver must be inline in every surface that needs it.
- **No `--force` on user paths** (`.claude/rules/common/no-force-on-user-paths.md`) — shim install in `bin/scaff-seed` already classifies before mutating; this feature changes the heredoc body but not the surrounding classify-then-write pattern.
- **18-file uniformity** — all 18 `.claude/commands/scaff/*.md` files have a byte-identical W3 marker block today; the post-fix block must remain byte-identical across all 18. Lint subcommand asserts this.
- **Source-tree dogfood must not regress** — in the source repo (`SCAFF_SRC == REPO_ROOT`), every command and the pre-commit shim continue to work because the resolver returns the same absolute path the source already uses (PRD R7 / AC6).

### Soft preferences

- Prefer extending the existing `bin/scaff-lint preflight-coverage` subcommand to also assert the resolver lines are present, rather than adding a new `bin/scaff-lint resolver-coverage` subcommand. Justification: the marker block and the resolver are two parts of one preamble convention; one lint subcommand asserting one byte-identical block (longer than today, but still single-block) is simpler than two coverage scans. Cross-references the by-construction-coverage memory: "shared body + per-file marker + lint subcommand" — the lint enforces the *whole* canonical preamble.
- Prefer reusing the existing `<!-- preflight: required -->` marker comment line as the lint anchor. The block grows from 5 lines of prose to 5 lines of bash + 4 lines of prose; the anchor comment stays unchanged.

### Forward constraints

- Future commands that need to source other tooling (e.g. a hypothetical `bin/scaff-lock`) must follow the same resolver convention. The resolver is reusable for any source-repo path; the marker-block and lint coverage scope grows along.
- The resolver itself should not gain features (e.g. version-pinning, multi-source dispatch) without a follow-up tech doc. Today's contract: resolve one absolute path or fail; no fallbacks beyond env-var and user-global symlink.

## 2. System Architecture

### Components

```
                       ┌──────────────────────────────────────────┐
                       │ ~/.claude/agents/scaff   (user-global)   │
                       │   symlink -> <SCAFF_SRC>/.claude/agents/ │
                       │              scaff                       │
                       └─────────────────┬────────────────────────┘
                                         │ readlink + suffix strip
                                         ▼
              ┌──────────────────────────────────────────────┐
              │  $SCAFF_SRC resolver — inline bash snippet   │
              │  (a) env-var override                        │
              │  (b) readlink user-global symlink            │
              │  (c) loud failure: exit 65 EX_DATAERR        │
              └────────┬──────────────────┬──────────────────┘
                       │                  │
              ┌────────▼─────────┐ ┌──────▼──────────────────┐
              │  Command         │ │ Pre-commit shim         │
              │  preambles       │ │ (emitted by scaff-seed) │
              │  (18 files)      │ │                         │
              │                  │ │  $SCAFF_SRC/bin/        │
              │  source          │ │   scaff-lint            │
              │  $SCAFF_SRC/bin/ │ │     scan-staged         │
              │   scaff-tier     │ │     preflight-coverage  │
              │   scaff-stage-   │ │                         │
              │     matrix       │ │                         │
              │                  │ │                         │
              │  preflight body  │ │                         │
              │  $SCAFF_SRC/     │ │                         │
              │   .specaffold/   │ │                         │
              │     preflight.md │ │                         │
              └──────────────────┘ └─────────────────────────┘
                       ▲                  ▲
                       │                  │
              ┌────────┴──────────────────┴──────────────────┐
              │  bin/scaff-lint preflight-coverage           │
              │   asserts every command file carries the     │
              │   byte-identical marker + resolver block     │
              └──────────────────────────────────────────────┘
```

### Data flow — `/scaff:next` invocation in a consumer repo

1. Claude Code session loads `.claude/commands/scaff/next.md` (which is symlinked from source via `bin/claude-symlink install` or copied via `scaff-seed init`'s plan_copy).
2. The preamble's W3 marker block runs: it inlines the `$SCAFF_SRC` resolver, then sources `$SCAFF_SRC/.specaffold/preflight.md`.
3. The preflight gate body executes — checks for `.specaffold/config.yml` in the consumer's CWD. If absent, exits 70 with `REFUSED:PREFLIGHT`.
4. After the preflight returns, the command body runs: `source "$SCAFF_SRC/bin/scaff-tier"` and `source "$SCAFF_SRC/bin/scaff-stage-matrix"`. Both files exist because `$SCAFF_SRC` is the source repo's absolute path.
5. `tier=$(get_tier "$feature_dir")` runs against `$REPO_ROOT/.specaffold/features/<slug>` — the consumer's local feature dir; `$REPO_ROOT` is still the consumer's git root (the legitimate use of `$REPO_ROOT` is preserved).

### Data flow — pre-commit shim invocation in a consumer repo

1. User runs `git commit` in the consumer.
2. `.git/hooks/pre-commit` (installed by `scaff-seed init`) runs.
3. The shim resolves `$SCAFF_SRC` inline (same 7-line bash snippet as the command preambles).
4. The shim execs `"$SCAFF_SRC/bin/scaff-lint" scan-staged "$@"`.
5. After scan-staged returns 0, the shim runs `"$SCAFF_SRC/bin/scaff-lint" preflight-coverage` — both invocations now use absolute paths.

### Module boundaries

- `bin/scaff-lint preflight-coverage` (existing subcommand) — extended to assert each `.claude/commands/scaff/*.md` carries the new combined marker+resolver block, byte-identically. Single fork via `grep -L -F` per the performance rule. Detail in §3 D5.
- `bin/scaff-seed cmd_init` and `cmd_migrate` shim heredocs — both lines updated; both must remain byte-identical (cross-reference: `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md`, `architect/by-construction-coverage-via-lint-anchor.md` lesson-set "mirror-emit sites").
- `bin/scaff-seed plan_copy` — drop the `if [ -f "${src_root}/.specaffold/preflight.md" ]; then printf …` branch (per PRD R5 / AC7).

## 3. Technology Decisions

### D1. Resolver placement — inline in every surface; no shared helper file

- **Options considered**:
  - **D1a. Inline 7-line bash snippet in every surface** (each command preamble, the pre-commit shim heredoc) — three call sites for the three command files that source `bin/`, plus the heredoc, plus the W3 marker prose pointing to `$SCAFF_SRC/.specaffold/preflight.md`.
  - D1b. Sourced helper file at `bin/_scaff-src-resolve` — recreates the chicken-and-egg: the consumer has no `bin/`, so to source the resolver they need to know where the source is, which the resolver tells them.
  - D1c. Sourced helper at `.specaffold/scaff-src-resolver.md` shipped via `scaff-seed`'s plan_copy — resurrects the same architectural defect this feature is fixing (a file that must live in the consumer).
- **Chosen**: **D1a** — inline 7-line bash snippet at every surface, with byte-identical text enforced by lint.
- **Why**: D1b and D1c both require a file in the consumer that the resolver itself bootstraps; only D1a breaks the cycle. The resolver is small (7 lines) so the duplication cost is low; the lint enforces uniformity. PRD R2 + the chicken-and-egg analysis in the request context lead unambiguously to D1a.
- **Tradeoffs accepted**: the resolver text is duplicated across the 3 command files that source `bin/scaff-*` (next, implement, archive), the pre-commit shim heredoc, and the W3 marker block in all 18 command files. Future edits to the resolver require updating every surface; lint catches divergence.
- **Reversibility**: medium. Could collapse to a sourced helper later if/when the consumer ever ships a `bin/` (would be a re-architecture of this whole feature, not a tweak).
- **Requirement link**: R1, R2.

### D2. Shim resolution time — hook-run-time, not install-time

- **Options considered**:
  - D2a. Install-time path resolution — `scaff-seed` resolves `$SCAFF_SRC` at install and bakes the absolute path into the emitted shim text.
  - **D2b. Hook-run-time path resolution** — the emitted shim contains the same inline resolver as the command preambles; resolves at every commit.
- **Chosen**: **D2b** — hook-run-time.
- **Why**: D2a is brittle: if the user moves the source clone (legit operation per `.claude/rules/common/absolute-symlink-targets.md` recovery prose: "running `bin/claude-symlink install` again rebuilds it with the new absolute path"), every consumer's pre-commit hook silently breaks. D2b survives source-clone moves because it re-resolves through the symlink each commit. The resolver overhead is `readlink` + parameter expansion + one `[ -d ]` test — well under 5 ms, comfortably inside the 200 ms hook budget.
- **Tradeoffs accepted**: shim file grows by ~7 lines.
- **Reversibility**: medium-high — could switch to D2a in a future feature with no impact on already-installed hooks (they would just keep working until a re-install rewrites them).
- **Requirement link**: R3.

### D3. W3 marker block strategy — sweep-substitute the marker body, keep the anchor comment

- **Options considered**:
  - **D3a. Sweep-substitute** — keep the `<!-- preflight: required -->` HTML-comment anchor; rewrite the prose body to "First resolve `$SCAFF_SRC` per the resolver block, then source `$SCAFF_SRC/.specaffold/preflight.md`". Block grows from 5 lines to ~9 lines (resolver inline + preflight directive). Byte-identical across all 18 files.
  - D3b. Inline the gate body directly in the marker — eliminate the `.specaffold/preflight.md` indirection; the entire gate logic lives in each command file.
  - D3c. Split into two markers — separate resolver-bootstrap marker and preflight marker, two separate lint coverage checks.
- **Chosen**: **D3a** — sweep-substitute.
- **Why**: D3b duplicates the gate body across 18 files (current model has it in one file); makes future gate edits an 18-file sweep rather than a 1-file edit. D3c doubles the lint surface area without functional benefit. D3a preserves the existing one-file-source-of-truth (`.specaffold/preflight.md` in the source repo) while fixing the path-resolution defect.
- **Tradeoffs accepted**: marker block grows from 5 lines to ~9 lines (prose 4 → 4 + 5 lines of bash for the resolver). Still well under the "5-line directive" rule-of-thumb for marker blocks because the bash is mechanical, not prose.
- **Reversibility**: high — sweeping back to D3b would be a one-time reflow per command file.
- **Requirement link**: R1, R4.

### D4. Resolver failure UX — exit 65 (EX_DATAERR), explicit remediation pointer

- **Options considered**:
  - D4a. Silent fallback to `$REPO_ROOT/bin/scaff-*` — re-introduces the bug we are fixing.
  - D4b. Exit 1 with generic error — does not distinguish from gate refusal (exit 70) or scan-staged failure (exit 1).
  - **D4c. Exit 65 (EX_DATAERR) with remediation pointer to `bin/claude-symlink install`** — distinct exit code; clear guidance.
- **Chosen**: **D4c**.
- **Why**: 65 is `EX_DATAERR` in BSD `sysexits.h` ("input data was incorrect in some way"); using a stable, distinct code lets test harnesses and downstream automation detect this failure mode without grepping stderr. Exit 70 is reserved for `REFUSED:PREFLIGHT`; exit 1 is what `scan-staged` returns on findings; exit 2 is what `scaff-lint` and other helpers use for "usage error or internal error". Choosing 65 keeps the codes disjoint.
- **Stderr message text** (byte-identical across every surface, asserted by lint via D5):
  ```
  ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo
  ```
- **Tradeoffs accepted**: callers must know that 65 means "resolver failed". Documented in PRD AC1 and in the resolver block's leading comment.
- **Reversibility**: high — exit code is parameterised in one place (the inline snippet); changes are byte-identical sweeps.
- **Requirement link**: R2.

### D5. Lint coverage — extend `preflight-coverage`; do not add a new subcommand

- **Options considered**:
  - **D5a. Extend `bin/scaff-lint preflight-coverage`** to assert the new combined marker+resolver block (byte-identical) is present in every `.claude/commands/scaff/*.md`.
  - D5b. Add a new sibling subcommand `bin/scaff-lint resolver-coverage` and run both subcommands in the pre-commit shim.
- **Chosen**: **D5a**.
- **Why**: the marker block and the resolver are two parts of *one* preamble convention; splitting them into two coverage subcommands doubles the lint surface, doubles the pre-commit shim length, and obscures the conceptual unity. The existing `preflight-coverage` already does a single `grep -L -F` fork against a fixed canonical block — extending the canonical block (longer multi-line `grep -F` match) preserves the shape and the perf budget.
- **Tradeoffs accepted**: the canonical block stored inside `bin/scaff-lint preflight-coverage` grows from ~5 lines to ~9 lines. The implementation may need to switch from a single `grep -L -F` fork to a single `awk`/`grep` pipeline that asserts the exact 9-line sequence; perf budget still single-digit-ms because the file count is fixed at 18 and each file is small.
- **Implementation hint for TPM/Developer**: the canonical block string lives in one variable inside the `run_preflight_coverage` function; tests for byte-identity diff against that variable. No file path tied to "the canonical block" — it lives in the lint script.
- **Reversibility**: high — split into two subcommands later if a third convention lands and needs its own coverage.
- **Requirement link**: R6, AC2, AC3.

### D6. plan_copy cleanup — remove the `.specaffold/preflight.md` branch in source's `bin/scaff-seed`; do NOT remove the file from source

- **Options considered**:
  - **D6a. Remove only the `plan_copy` branch that ships `.specaffold/preflight.md` to consumers** — keep the file in source's `.specaffold/preflight.md` because the source-repo dogfood path resolves it via `$SCAFF_SRC == $REPO_ROOT`.
  - D6b. Remove the file from source as well — breaks dogfood; the source repo's commands would resolve `$SCAFF_SRC/.specaffold/preflight.md` to a missing file.
  - D6c. Keep the `plan_copy` branch as a redundancy — wastes consumer disk; if a user edits the consumer-local copy, they create a divergence with the source-of-truth in source.
- **Chosen**: **D6a**.
- **Why**: PRD R5 / AC7 are explicit about removing the `plan_copy` branch (the file becomes redundant in the consumer once the W3 marker resolves via `$SCAFF_SRC`). The source file stays because the source repo also runs the W3 marker block; for source-repo runs the resolver returns `$REPO_ROOT`, and `$REPO_ROOT/.specaffold/preflight.md` is exactly the same file that was always read. No regression.
- **Tradeoffs accepted**: a consumer that has been previously init'd with the old `plan_copy` branch has a stale `.specaffold/preflight.md` in their tree. This stale file is no longer read (the W3 marker now points at `$SCAFF_SRC/.specaffold/preflight.md`); it is leftover but harmless. Cleanup is out of scope for this feature (a future migrate could prune it).
- **Reversibility**: high — a future change could re-introduce the `plan_copy` entry without breakage.
- **Requirement link**: R5, AC7.

### D7. Regression test — assistant-not-in-loop sandbox; counter t113

- **Options considered**:
  - **D7a. New `test/t113_scaff_src_resolver.sh`** — sandboxes per `.claude/rules/bash/sandbox-home-in-tests.md`, fakes `~/.claude/agents/scaff` symlink inside the sandbox, runs `scaff-seed init` against an empty consumer dir, asserts no `bin/` in consumer, sources the W3 marker block from `next.md` in a subshell, asserts it loads `bin/scaff-tier` from the source path. Single test file, one counter.
  - D7b. Distribute the assertions across multiple new test files (one per AC) — overkill for a single architectural fix; reviewer-friendliness suffers.
- **Chosen**: **D7a** — single new test file, counter `t113`.
- **Why**: PRD R6 / AC8 explicitly call for one assistant-not-in-loop integration test that exercises the end-to-end flow. The sandbox-HOME rule requires `mktemp -d` + trap + preflight assertion. One file, one counter, easy to review.
- **Tradeoffs accepted**: the test is large (~80–120 lines) because it covers six steps from R6's regression-test list. Acceptable; the alternative is a fan-out across files that obscures the trace.
- **Implementation hint for TPM/Developer**: the test fakes the user-global symlink in the sandbox by `ln -s "$REPO_ROOT" "$SANDBOX/home/.claude/agents/scaff"` (trailing path missing — the resolver strips `/agents/scaff` from the readlink output to get the source root, so the symlink target should end in `/agents/scaff`; in the sandbox, it points at the source's `/.claude/agents/scaff`). Source: `bin/claude-symlink install` is the real-world creator; the test simulates one of its post-conditions.
- **Reversibility**: high — counter is monotonic; renaming/removing later is cosmetic.
- **Requirement link**: R6, AC1, AC4, AC5, AC8.

## 4. Cross-cutting Concerns

### Error handling

- Resolver failure (D4) is the only new error class. Exit 65, byte-identical stderr message, no retry. Surfaces: command preambles → command aborts before sourcing `bin/scaff-*` → user sees the message in their terminal. Pre-commit shim → commit is rejected with exit 65 → user sees the message in `git commit` output. Both paths land the user at the same remediation: `bin/claude-symlink install` from the source clone.
- Pre-existing exit codes preserved: 70 = REFUSED:PREFLIGHT (gate body); 1 = scan-staged finding; 2 = usage / internal error. Exit codes are now disjoint across the four meaningful failure modes.

### Logging / tracing

- No new logging. The resolver is silent on success (just sets `SCAFF_SRC` in the running shell or echoes nothing) and emits one stderr line on failure. Hook latency is below any threshold worth measuring.

### Security

- No new security surface. The resolver reads `$SCAFF_SRC` (env var) — input validation: must be a real directory, asserted via `[ -d "$SCAFF_SRC" ]` after resolution. The `readlink ~/.claude/agents/scaff` path is bounded by the user's own `~/.claude/agents/scaff` symlink — not an untrusted input. No shell concatenation of any user-provided string into a command.
- Cross-references `.claude/rules/reviewer/security.md` checks 2 (path traversal — N/A: resolver does not join user-supplied path components) and 4 (injection — N/A: resolver does not build shell commands from variables; all subprocess calls are argv-form).

### Testing strategy

- **Unit-ish**: `test/t107_preflight_lint_and_body.sh` (existing) extended OR new assertions in `t113` cover D5's lint coverage of the new combined marker block.
- **Integration**: `test/t113_scaff_src_resolver.sh` (new) covers AC1, AC4, AC5, AC8 end-to-end in a `mktemp -d` sandbox.
- **Regression / dogfood**: source-repo `bin/scaff-lint preflight-coverage` continues to pass after the marker block grows (AC6).
- **Performance**: implicit — t113 runs end-to-end in the sandbox; if it completes in under a couple of seconds the resolver overhead is well within budget. No explicit latency assertion needed.

### Performance / scale

- Resolver runs at most once per command invocation and once per `git commit`. Single-digit milliseconds per run; well inside the 200 ms hook budget. No iteration, no shell-out in a loop, no re-reading of files.
- Lint subcommand `preflight-coverage` continues to use a single `grep -L -F` fork per the performance rule. The canonical block growing from 5 to 9 lines does not change the fork count.

## 5. Open Questions

None — the four PM-deferred D-placeholders are resolved (D1–D4), three additional decisions are made (D5–D7), and no decision depends on information not yet available.

## 6. Non-decisions (deferred)

- **N1. Stale `.specaffold/preflight.md` cleanup in already-init'd consumers.** The file becomes orphaned (no longer read) but not harmful. Triggering decision: a future feature that adds `cmd_migrate --prune-stale-files` or similar consumer-cleanup logic. Until then, the file sits as dead state in older consumers.
- **N2. Versioning the resolver.** If a future change to the resolver text needs to coexist with older consumer command-file copies, we will need a version marker. Triggering decision: any non-byte-identical resolver edit. Until then, the lint-enforced byte-identity makes versioning unnecessary.
- **N3. Multi-source dispatch.** A user with multiple specaffold clones might want different consumers to point at different source clones. Today's `~/.claude/agents/scaff` is a single user-global symlink; `$SCAFF_SRC` env var is the per-shell escape hatch. Triggering decision: explicit user request for per-consumer source pinning. Until then, the env-var override is the documented workaround.

---

## Team memory

Applied entries:
- `architect/by-construction-coverage-via-lint-anchor.md` — drives D3+D5: combined marker block, single lint subcommand asserting byte-identical block across all 18 command files; mirror-emit sites in `bin/scaff-seed` (`cmd_init` line 797 + `cmd_migrate` line 1384) named explicitly per the lesson set.
- `architect/commands-harvest-scope-forbids-non-command-md.md` — informs D1: confirms we cannot place a non-command markdown helper inside `.claude/commands/scaff/`; the inline-snippet choice respects the harvest constraint.
- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` — informs D2: the hook-run-time resolver in the pre-commit shim is a wired commitment that must be an explicit task in the plan, not an implicit follow-up.
- `shared/orchestrator-rider-commit-recovery.md` — applicable if validate-stage commits drift across parallel branches; flagged for TPM in plan stage as the W2/W3 wiring may need rider commits if `--no-verify` is required during the W3 marker sweep.
- `.claude/rules/bash/bash-32-portability.md` (rule, not memory) — drives the resolver shape: bare `readlink` (BSD-safe), parameter-expansion suffix strip (`${tgt%/.claude/agents/scaff}` not GNU `sed -i`), `[ -d ]` over `[[ -d ]]`.
- `.claude/rules/common/no-force-on-user-paths.md` (rule, not memory) — preserved by D6: source's `.specaffold/preflight.md` stays; only the `plan_copy` ship-to-consumer branch is removed; no destructive action on user state.

Proposed new memory: defer to validate retrospective. Candidate lesson if the implementation lands cleanly: **"Inline-snippet conventions are the only way to ship a runtime-resolver into a thin-consumer model"** — applicable to any future feature that wants to add a new dependency surface to the consumer without expanding the consumer manifest. Confirm this is not already covered by the by-construction-coverage entry (which captures the *enforcement* shape but not the *placement* tradeoff between inline-snippet and sourced helper) post-archive.
