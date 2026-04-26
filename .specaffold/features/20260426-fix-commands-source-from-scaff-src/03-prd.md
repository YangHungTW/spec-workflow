# PRD — fix commands source from $SCAFF_SRC

## Problem

In a consumer repo (any project that is not the specaffold source itself) that has been `/scaff-init`'d, every slash-command, every pre-commit hook, and every W3-marker preflight directive dies on the first relative-path read because `bin/*` and `.specaffold/preflight.md` only exist in the source repo. The just-archived parent bug `20260426-fix-init-missing-preflight-files` fixed `config.yml` (one symptom); the architectural fix (option B = thin consumer) is to resolve tool dependencies from `$SCAFF_SRC` — the source-repo path already established by the user-global symlink at `~/.claude/agents/scaff` — rather than from `$REPO_ROOT` (the consumer).

This PRD ships the second half of a two-part fix; B1 was the parent (config.yml seeding), B2 is this feature (path-resolution architecture). Both lines are necessary for `/scaff:*` to work end-to-end in a consumer.

## Source

**Source**:
- type: description
- value: slash-command preambles source bin/* libraries from $REPO_ROOT (consumer), but bin/* only lives in the source repo — consumers init'd via scaff-seed have no bin/ so /scaff:next fails with 'No such file or directory: bin/scaff-tier'; pre-commit shim and W3 marker block (preflight.md reference) have the same flaw. Fix: command preambles resolve from $SCAFF_SRC (via the existing readlink ~/.claude/agents/scaff pattern), not $REPO_ROOT — thin-consumer architecture decision (option B from 20260426-fix-init-missing-preflight-files post-validate)

## Repro

1. Start in any consumer repo (a project clone that is not the specaffold source).
2. Run `scaff-seed init` from the source's `bin/scaff-seed` to bootstrap the consumer.
3. In Claude Code, invoke `/scaff:next`.
4. The command markdown loads and executes its preamble: `source "$REPO_ROOT/bin/scaff-tier"`.
5. Observed failure: `bash: $REPO_ROOT/bin/scaff-tier: No such file or directory`. The same failure mode applies to all 18 commands in `.claude/commands/scaff/*.md`, the W3 preflight reference (`.specaffold/preflight.md`), and the pre-commit shim emitted by `bin/scaff-seed` (which references `bin/scaff-lint`).

## Expected

1. A consumer repo that has been `/scaff-init`'d (no `bin/`, no `preflight.md`, only `config.yml` + `.specaffold/features/_template/`) can run any `/scaff:<cmd>` end-to-end without `No such file or directory` errors.
2. The pre-commit hook installed by `scaff-seed` runs successfully in consumer repos because it resolves `bin/scaff-lint` via `$SCAFF_SRC` at hook-run time.
3. The W3 marker block's preflight directive resolves the gate body via `$SCAFF_SRC`, not consumer-local relative path.
4. Source repo (specaffold itself) still works because `$SCAFF_SRC` resolves to `$REPO_ROOT` for the source.

## Actual

Every command, every pre-commit hook, every preflight directive in a consumer repo dies on the first relative-path read. The user has zero usable scaff workflow in a consumer until they manually symlink `bin/` and `.specaffold/preflight.md` from source.

## Environment

- macOS Darwin 25.3.0; bash 3.2 / BSD userland (per `.claude/rules/bash/bash-32-portability.md`).
- Consumer repo has been bootstrapped via `bin/scaff-seed init` (post the just-archived parent bug, so `config.yml` is present and `preflight.md` may also be present as a stale copy).
- User-global symlink in place: `~/.claude/agents/scaff` -> `<source-repo>/.claude/agents/scaff`. This is the existing pattern the resolver reuses.

## Root cause

Three coupled defects, all rooted in the same assumption that `$REPO_ROOT` (the consumer) hosts the tool surface:

1. **Command preambles** — 18 files in `.claude/commands/scaff/*.md` source `$REPO_ROOT/bin/scaff-*`. They should source from the source-repo path, not the consumer.
2. **Pre-commit shim emitter** (`bin/scaff-seed`) — heredoc emits `bin/scaff-lint scan-staged "$@"` as a relative path. Should emit a hook that resolves the source-repo path at run time.
3. **W3 marker block** — 18 files have a 5-line block referencing ``.specaffold/preflight.md`` by relative path. Should resolve the source-repo path.

The fix is one new `$SCAFF_SRC` resolver helper plus a sweep across the three surfaces.

## Fix requirements

- **R1** — All 18 `.claude/commands/scaff/*.md` files have their preamble source statements changed from `$REPO_ROOT/bin/scaff-*` to `$SCAFF_SRC/bin/scaff-*`. The preamble must include the `$SCAFF_SRC` resolver (or source it from a helper that is user-global resolvable).
- **R2** — A new `$SCAFF_SRC` resolver helper exists, idempotent and bash 3.2 portable. Resolution order: (a) `$SCAFF_SRC` env var if set and points to a real directory; (b) `readlink ~/.claude/agents/scaff` -> strip `/agents/scaff` (or `/.claude/agents/scaff`) suffix to get source root; (c) fail loudly if neither resolves.
- **R3** — `bin/scaff-seed`'s pre-commit shim heredoc emits a hook that resolves `bin/scaff-lint` via `$SCAFF_SRC` at hook-run time, so the hook works in any consumer regardless of whether `bin/` is shipped locally.
- **R4** — The W3 marker block in all 18 command files updates the preflight reference from a relative ``.specaffold/preflight.md`` to a `$SCAFF_SRC`-resolved path (or equivalent that resolves via the resolver helper).
- **R5** — After this fix, the just-archived parent bug's `plan_copy` entry for `.specaffold/preflight.md` becomes redundant. Cleanup is **in scope**: remove that `plan_copy` entry from `bin/scaff-seed`. The `emit_default_config_yml` helper from the parent bug **stays** (config.yml lives in the consumer; the gate sentinel is correct).
- **R6** — Regression test exercises the full flow in a consumer-shaped sandbox where `bin/` is **not** present. The harness must run assistant-not-in-loop per `qa-analyst/wiring-trace-ends-at-user-goal.md` — a literal subprocess invocation of the preamble flow, not an LLM-mediated description. The test must NOT pass while still relying on consumer-local `bin/`.
- **R7** — Source repo (specaffold itself) continues to work: `$SCAFF_SRC` resolves to `$REPO_ROOT` for the source, so all commands work as before. No regression on dogfood (e.g. `bin/scaff-lint preflight-coverage` still passes against the source tree).

## Regression test requirements

A new test under `test/` (counter assigned by TPM) that:

1. Builds an `mktemp -d` sandbox per `.claude/rules/bash/sandbox-home-in-tests.md` (sandboxed `$HOME`, preflight assertion, `trap` cleanup).
2. Symlinks a fake `~/.claude/agents/scaff` inside the sandbox to the source-repo path so the resolver's path-(b) branch is exercised end-to-end.
3. Runs `bin/scaff-seed init` against an empty consumer dir inside the sandbox.
4. Asserts `bin/` is NOT present in the consumer dir (thin-consumer invariant).
5. Sources one representative command's preamble (e.g. `next.md`) in a subshell and verifies it loads `bin/scaff-tier` successfully — i.e. the resolver picked up the source path.
6. Installs the pre-commit hook into the consumer; stages a benign change; runs the hook; asserts exit 0 (or the appropriate gated exit) and that `bin/scaff-lint` was invoked from the source path.
7. Reads the W3 marker block's preflight reference and confirms it resolves via the resolver to a real file under the source repo.

The harness must work without an assistant in the loop — every step is a subprocess.

## Acceptance criteria

- **AC1** — Resolver helper resolves `$SCAFF_SRC` correctly from (a) env-var override, (b) `readlink` of the user-global symlink, and (c) errors loudly when neither resolves. Verifiable via unit test on the resolver alone.
- **AC2** — All 18 command files' preambles source from `$SCAFF_SRC/bin/scaff-*`, not `$REPO_ROOT/bin/scaff-*`. Verifiable: `grep -l 'REPO_ROOT/bin/scaff-' .claude/commands/scaff/*.md` returns empty after the fix; `grep -l 'SCAFF_SRC/bin/scaff-' .claude/commands/scaff/*.md` returns 18 paths.
- **AC3** — All 18 command files' W3 marker blocks reference the preflight body via `$SCAFF_SRC` (not a bare relative path). Verifiable similarly via `grep`.
- **AC4** — `bin/scaff-seed`'s pre-commit shim heredoc emits a hook that resolves `$SCAFF_SRC` at run time. Verifiable: a sandboxed consumer repo with no `bin/` can still run the installed pre-commit hook successfully.
- **AC5** — A sandboxed consumer repo with NO `bin/` directory at all, freshly init'd via `scaff-seed init`, can extract and run the gate body referenced by the W3 marker block (which now resolves via `$SCAFF_SRC`) — exit 0 (passthrough) or exit 70 (REFUSED), depending on whether `config.yml` is present.
- **AC6** — Source repo `bin/scaff-lint preflight-coverage` still passes (regression: dogfood path still works since `$SCAFF_SRC` == `$REPO_ROOT` in the source).
- **AC7** — `bin/scaff-seed`'s `plan_copy` entry for `.specaffold/preflight.md` is removed (now redundant per R5). Verifiable: `grep "preflight.md" bin/scaff-seed | grep -v "preflight-coverage"` returns empty.
- **AC8** — Integration test (assistant-not-in-loop) covers the end-to-end "fresh sandbox -> scaff-seed init -> simulate `/scaff:next` preamble execution -> no errors". This is the runtime test that catches the trace-terminus failure mode that the parent bug's verify missed.

## Decisions

- **D1** — Resolver shape and location. The helper is bash 3.2 portable and lives at a single source-of-truth path that all 18 command preambles can reach without bin-shipping. Resolution order is fixed at (a) env-var override, (b) `readlink ~/.claude/agents/scaff`, (c) loud failure. *Architect to refine: exact filename, where the helper lives in the source tree (e.g. `bin/_scaff-src-resolve` vs an inline preamble snippet vs a `.claude/skills/_resolver` shim), and whether each command preamble inlines the resolver or sources it.*
- **D2** — Shim resolution time: hook-run time vs install time. R3 calls for hook-run resolution (option b in the request context) so that moving the source clone does not break installed hooks. *Architect to confirm: pin to hook-run-time resolution, with the install-time absolute-path option only as fallback if there is a portability blocker.*
- **D3** — W3 marker block change strategy: textual `$SCAFF_SRC/.specaffold/preflight.md` substitution in all 18 files vs a directive that the assistant interprets and the resolver dereferences vs a single sourced fragment. *Architect to decide between (a) sweep-and-substitute, (b) directive-rewrite, (c) extracted fragment.*
- **D4** — Resolver failure UX. When neither (a) nor (b) resolves, exit code, stderr message, and remediation hint shape. *Architect to specify: exact message text and exit code; user remediation should point to `bin/claude-symlink install` or equivalent.*

## Open questions

None — all probes folded into R1–R7 and AC1–AC8 from the orchestrator's bug-intake context.

---

## Team memory

Applied entries:
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md` — Problem section names this as the second half of a two-part fix (parent: 20260426-fix-init-missing-preflight-files); pre-commits the pairing in PRD prose.
- `pm/ac-must-verify-existing-baseline.md` — AC2/AC3 anchor on grep-verifiable post-conditions over all 18 files rather than vague "match siblings".
- `shared/auto-classify-argv-by-pattern-cascade.md` — informed Source classification (description) per /scaff:bug step 6.
- `qa-analyst/wiring-trace-ends-at-user-goal.md` — informs R6/AC8 (assistant-not-in-loop sandbox is the regression test shape).

Proposed new memory: defer until validate retrospective; the lesson from this feature (architectural pivots discovered post-validate of a sibling bug should pre-commit a follow-up slug in the parent's archive notes) may already be covered by the b1-b2 split entry — confirm post-archive.
