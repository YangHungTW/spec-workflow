# PRD — scaff-init-preflight

- **Slug**: 20260426-scaff-init-preflight
- **Tier**: standard
- **Has-ui**: false
- **Work-type**: feature
- **Authored**: 2026-04-26 by PM
- **Related**: 00-request.md (intake), STATUS.md

## 1. Problem / background

The `.claude/commands/scaff/*.md` surface (18 commands: archive, bug, chore, design, implement, next, plan, prd, promote, remember, request, review, tech, update-{plan,req,task,tech}, validate, plus `scaff-init` itself) is exposed user-globally on this machine via the symlinks created by `bin/claude-symlink install`. As a consequence, every project on the machine — including projects that have never been `/scaff-init`'d — sees the full `/scaff:*` slash-command palette.

A grep across all 18 files for `scaff-init`, `config.yml`, or `specaffold/config` returns zero matches. None of the gateable 17 commands carry a deterministic preflight that refuses to run when `.specaffold/config.yml` is absent. The closest accidental gate is in `request.md` (`cp .specaffold/features/_template/ ...`), which would fail with a cryptic `cp: cannot stat` only after the dispatcher has already begun work; commands that do not touch the template (`next`, `validate`, `implement`, `archive`, …) have no such accidental brake at all.

Today the missing-init case is caught only when the assistant happens to notice — i.e. by judgment, not by mechanism. A less careful assistant could partially mutate the project (creating `.specaffold/`, leaving STATUS notes, even committing) before failing. This contradicts the project's own `no-force-on-user-paths` and `classify-before-mutate` rules: scripts must classify before mutating, but the scaff command surface itself does not classify "is this a scaff project?" before mutating.

## 2. Goals

- **G1** — Every `/scaff:<name>` command except `scaff-init` deterministically refuses to run when `.specaffold/config.yml` is absent in the current working directory.
- **G2** — Refusal is loud, single-line, names the recovery command (`/scaff-init`), and produces zero side effects (no directories, no files, no STATUS edits, no commits, no agent invocations).
- **G3** — Behaviour is unchanged when `.specaffold/config.yml` is present — no new prompts, no new latency surface visible to the user, no false positives.
- **G4** — The gate is applied to the 17 commands by construction, not by hand-copying a check into each file. A future `/scaff:foo` command authored after this feature ships inherits the gate without the author having to remember to add it.
- **G5** — The gate is greppable from a single source of truth so the operator (or a reviewer) can audit "what is the gate?" by reading exactly one location.

## 3. Non-goals

- **NG1** — **Not modifying `scaff-init` itself.** `scaff-init` is the init entry point; it must work pre-init by definition. The gate excludes it explicitly.
- **NG2** — **Not changing the symlink mechanism in `bin/claude-symlink`.** Global exposure of the command palette is correct; the gate goes inside each command, not at the symlink layer.
- **NG3** — **Not auto-running `scaff-init`.** Gating means "stop and instruct the user", not "fix it for the user". An accidental auto-init would silently create `.specaffold/` in unrelated projects.
- **NG4** — **Not changing post-init behaviour.** Once `.specaffold/config.yml` exists, every command behaves byte-identically to today.
- **NG5** — **Not validating the contents of `config.yml`.** Presence-only check. A malformed or schema-invalid `config.yml` is out of scope for this feature; that is a separate "config validation" concern with its own UX (likely a reviewer rule or a startup hook). The gate here is binary: file exists or it does not.
- **NG6** — **Not gating CLI scripts under `bin/scaff-*`.** The gate is for slash-commands invoked by the user via Claude Code; the helper scripts in `bin/` are invoked by command files and inherit the gate transitively from their callers. Gating them at the script layer too would double-fire and is not required by the success criteria.
- **NG7** — **Not adding a `--force` or bypass flag.** v1 is unconditional. If a future use case needs to bypass the gate (e.g. a meta-tool inspecting another project), it will be added as a separate feature.

## 4. Users / scenarios

One user: the primary operator, in two distinct project shapes.

- **Scenario 4.1 (init'd project — happy path)** — Operator is in a project where `.specaffold/config.yml` exists. They invoke any `/scaff:<name>` command. Behaviour is identical to today: PM probes, TPM dispatches, files get written, STATUS gets updated. No new prompts, no new errors, no perceptible delay.
- **Scenario 4.2 (non-init'd project — gated)** — Operator is in a project where `.specaffold/config.yml` does not exist (a brand-new repo, a non-scaff project on the same machine, or a half-init'd directory). They invoke any `/scaff:<name>` command except `/scaff-init`. The command emits a single-line refusal naming the missing file and pointing to `/scaff-init`, then exits without touching the working directory. Re-running `/scaff-init` (which is exempt from the gate) lets them recover.
- **Scenario 4.3 (init entry point — exempt)** — Operator runs `/scaff-init` in either an init'd or non-init'd project. The gate does not fire; `scaff-init` runs normally.

## 5. Requirements

Each R maps to at least one AC in §6.

### 5.1 Trigger condition

- **R1** — The gate fires when, at the moment a `/scaff:<name>` command is invoked, the path `.specaffold/config.yml` does not exist as a regular file under the current working directory. The check anchors on the file `config.yml` (not the directory `.specaffold/`) because a half-init'd state may leave the directory present without a valid config; presence of `config.yml` is the authoritative init marker.
- **R2** — The check is presence-only. File contents are not parsed and not validated by this gate (see NG5). A zero-byte or syntactically-invalid `config.yml` causes the gate to pass; any further validation is a separate concern.

### 5.2 Scope of gating

- **R3** — The gate applies to exactly the following 17 commands: `archive`, `bug`, `chore`, `design`, `implement`, `next`, `plan`, `prd`, `promote`, `remember`, `request`, `review`, `tech`, `update-plan`, `update-req`, `update-task`, `update-tech`, `validate`. The command `scaff-init` is exempt by construction (NG1).
- **R4** — Any new `/scaff:<name>` command file added to `.claude/commands/scaff/` after this feature ships inherits the gate without the author having to wire it in by hand. The shared mechanism (per R7) must make this true by construction, not by a documented convention the author can forget.

### 5.3 Refusal behaviour

- **R5** — When the gate fires, the command emits a single-line refusal to the user that:
  1. Names the missing file (`.specaffold/config.yml`).
  2. Names the current working directory (so the user can confirm they are in the project they think they are in).
  3. Names `/scaff-init` as the recovery command.
  4. Is exactly one line of user-visible output (no banners, no multi-paragraph explanation).
- **R6** — When the gate fires, the command produces zero side effects in the working directory:
  1. No directories are created (in particular, `.specaffold/` is not created).
  2. No files are created or modified (in particular, no `STATUS.md` edit if one happens to exist for an unrelated reason).
  3. No git operations are performed (no `git add`, `git commit`, no branch creation).
  4. No specaffold sub-agent is invoked (no PM probe, no TPM dispatch, no Architect, no Developer, no Designer, no QA-tester, no QA-analyst).

### 5.4 Passthrough behaviour

- **R7** — When `.specaffold/config.yml` is present, the gate is a no-op and every gated command behaves byte-identically to its pre-change state. "Byte-identical" applies to: prompts emitted, files created, STATUS lines added, agent invocations made, git operations performed, exit code, and stdout/stderr beyond the gate's silent passthrough.

### 5.5 Shared mechanism

- **R8** — The gate logic lives in exactly one source of truth that is referenced from each of the 17 command files. The exact mechanism (Architect's call) may be one of:
  - A shared markdown include (e.g. `.claude/commands/scaff/_preflight.md`) referenced from each command.
  - A one-liner directive at the top of each command file that delegates to a shared helper (script under `bin/`, sentinel file, or front-matter convention).
  - A wrapper script that all command files dispatch through.
  Whichever the Architect picks, the resulting gate must satisfy R4 (new commands inherit by construction) and G5 (auditable from one location).
- **R9** — Wiring 17 command files to the shared mechanism is acceptable as a one-time edit, but the *gate logic itself* must not be hand-copied 17 times. If the wiring is a one-line directive per file (e.g. `<!-- preflight: required -->` or an `include` line), the gate body lives in the included file, not in each command.

### 5.6 Exit semantics

- **R10** — When the gate fires, the command terminates with a non-zero exit posture so any wrapping automation (e.g. a test harness, a CI invocation, a future scripted invocation of slash-commands) can detect the refusal mechanically. Exact mechanism for slash-command "exit code" is Architect's call (slash-commands are markdown; "exit" here means "the command's terminal output ends in an unambiguous failure marker that downstream tooling can pattern-match"). PRD binds: refusal must be mechanically distinguishable from success and from an unrelated runtime error.

### 5.7 Edge cases

- **R11** — `--help` / introspection (if any command surface supports it) is **not** exempt: a user asking for help inside a non-init'd project still gets the same refusal. Rationale: the slash-command palette has no `--help` convention today; adding a help-bypass would expand the gate's surface area without justification. If a future feature adds command help, it can revisit this.
- **R12** — The gate fires regardless of which command tier (tiny / standard / audited) or work-type (feature / bug / chore) the invoked command corresponds to. Tier and work-type are read from `STATUS.md` of an in-progress feature directory, which by definition cannot exist when the gate fires (no `config.yml` ⇒ no `.specaffold/` features tree).

### 5.8 Documentation surface

- **R13** — The repo `README.md` (or the equivalent contributor doc that enumerates scaff commands) must mention the gate's existence in one sentence — enough that an operator who hits the refusal in a non-init'd project knows it is intended behaviour. The exact wording is the Developer's call; PRD binds the presence.

## 6. Acceptance criteria

Per `shared/dogfood-paradox-third-occurrence.md`, this feature ships a gate that lives inside the very command files used by every other scaff workflow. The gate cannot be runtime-exercised against itself in a normal scaff loop without first sandboxing `HOME` and the working directory. ACs distinguish **structural** (verifiable by static inspection / file content checks) from **runtime** (verifiable by sandboxed invocation per `.claude/rules/bash/sandbox-home-in-tests.md`).

### 6.1 Structural ACs

- **AC1** (structural) — The shared gate mechanism (R8) exists in exactly one canonical location. Verify: a reviewer can find one file (or one helper) that contains the entire gate body; grep across `.claude/commands/scaff/*.md` for the gate's logic body matches in zero places except via the shared reference.
- **AC2** (structural — coverage) — All 17 gated commands listed in R3 reference the shared mechanism. Verify: for each filename in {archive, bug, chore, design, implement, next, plan, prd, promote, remember, request, review, tech, update-plan, update-req, update-task, update-tech, validate}.md under `.claude/commands/scaff/`, a grep for the shared-mechanism reference matches.
- **AC3** (structural — exemption) — `.claude/commands/scaff/scaff-init.md` does **not** reference the shared mechanism (NG1). Verify: grep for the shared-mechanism reference in `scaff-init.md` returns zero matches.
- **AC4** (structural — by-construction inheritance) — Adding a new command file under `.claude/commands/scaff/` either (a) inherits the gate via the shared mechanism without any per-file wiring (preferred), or (b) requires a single, minimal one-line wiring step that is documented in `.claude/commands/scaff/README.md` (or equivalent author-facing doc). Verify: the author-facing doc names the wiring step explicitly OR the mechanism's design auto-applies (e.g. orchestrator scans the directory at session start and fails the build if a command file lacks the gate marker).
- **AC5** (structural — refusal message format) — The refusal message body in the shared gate file (R5) is a single user-visible line that contains the literal strings `.specaffold/config.yml`, the runtime CWD (substituted at gate time), and `/scaff-init`. Verify: static inspection of the shared file shows all three tokens; no multi-paragraph banner.
- **AC6** (structural — README mention) — The repo `README.md` (or named contributor doc) contains one sentence describing the gate behaviour (R13). Verify: grep `config.yml` and `scaff-init` co-occurring in the named doc matches.

### 6.2 Runtime ACs (sandboxed)

Each runtime AC is executed inside a `mktemp -d` sandbox that exports `HOME` to a subdirectory of the sandbox per `.claude/rules/bash/sandbox-home-in-tests.md`. The sandbox CWD is set to a fresh directory under `$SANDBOX/proj/` that does **not** contain `.specaffold/config.yml`. Each AC asserts (a) refusal message content, (b) zero filesystem mutation under `$SANDBOX/proj/`, (c) mechanical refusal posture per R10.

- **AC7** (runtime — refusal happy path) — In a sandbox CWD without `.specaffold/config.yml`, invoking each of the 17 gated commands (in turn or by representative sample if the harness chooses; harness must justify in 06-tasks if sampling) produces a refusal whose user-visible output:
  1. Contains the literal substring `.specaffold/config.yml`.
  2. Contains the literal substring `/scaff-init`.
  3. Contains the sandbox CWD path.
  4. Is exactly one line (no extra paragraph, no banner).
  Verify: capture stdout+stderr; assert all four conditions.
- **AC8** (runtime — zero side effects) — In the same sandbox, after each gated command's refusal, the sandbox CWD has the **same** file tree it had immediately before invocation. Verify: `find "$SANDBOX/proj" -ls | sort | shasum` taken before and after the invocation match exactly. In particular: no `.specaffold/` directory exists, no `STATUS.md` exists, no `00-request.md` exists, no git operations occurred (assert by `git status` baseline equality).
- **AC9** (runtime — exempt path) — In the same sandbox CWD without `.specaffold/config.yml`, invoking `/scaff-init` does **not** trigger the refusal; `scaff-init`'s normal init flow runs. Verify: stdout does not contain the refusal substring `/scaff-init` *as a recovery instruction* (i.e. scaff-init's own output is allowed to mention itself; the marker is the absence of the gate's specific refusal phrase).
- **AC10** (runtime — passthrough) — In a sandbox CWD where `.specaffold/config.yml` is present (created by an explicit `touch` in the test harness; contents irrelevant per R2), invoking a representative gated command (e.g. `/scaff:next`, which is read-only relative to the feature tree) proceeds without firing the gate. Verify: stdout does **not** contain the refusal substring; the command's own happy-path output is observed.
- **AC11** (runtime — malformed-config passthrough) — In a sandbox CWD where `.specaffold/config.yml` exists but is empty (zero bytes) or contains arbitrary non-YAML text, the gate still passes (R2). Verify: same as AC10 with a deliberately malformed config file. (This AC exists to lock in NG5 — content validation is out of scope; presence is the only signal.)

### 6.3 Regression ACs

- **AC12** (structural — baseline) — Pre-change file content of each of the 17 command files is captured as a golden snapshot at PRD-lock time (per `pm/ac-must-verify-existing-baseline.md`). After the feature ships, the diff between the pre-change snapshot and the post-change file content is exactly the wiring addition required by R8/R9 (one line, or one front-matter key, or one include statement — whichever the Architect chooses). No other content changes are introduced into the 17 files. Verify: diff each file; assert the diff is restricted to the wiring addition.
- **AC13** (runtime — passthrough byte-identical) — In the init'd-project sandbox of AC10, the side-effect output of a representative gated command (files created, STATUS lines appended, agent invocations logged) is byte-identical to the pre-change behaviour for the same input. Verify: capture the sandbox file tree and stdout before and after this feature's implementation; diff them.

## 7. Open questions

None. The mechanism choice (markdown include vs front-matter directive vs wrapper script) is delegated to the Architect per R8; the PRD does not need that decision to be testable. Edge-case stances (NG5 malformed config, NG6 bin-script gating, NG7 no bypass flag, R11 no help-exempt) are explicitly closed.

## 8. Decisions

- **D1** — **Trigger condition anchors on `config.yml`, not on `.specaffold/` directory existence.** A half-init'd state (directory exists but config missing) should still fire the refusal so the user is pointed back to `/scaff-init`. `config.yml` is the authoritative init marker.
- **D2** — **Presence-only check, no content validation.** Schema validation is a separate concern (NG5). The gate is binary and cheap, so it adds zero latency on the happy path.
- **D3** — **No bypass flag in v1.** A `--force` or `--no-preflight` would re-introduce the same silent-clobber risk this feature exists to eliminate. If a real bypass need surfaces later, it ships as its own feature with its own UX justification.
- **D4** — **Refusal must be mechanically distinguishable from runtime error.** Per R10. Slash-commands are markdown so "exit code" is informal; the binding is on user-visible refusal phrasing being unambiguous and pattern-matchable, not on a POSIX exit code. Architect picks the exact marker.
- **D5** — **Gate the 17 commands by referencing a shared body, not by 17 hand-copied checks.** Per R8/R9. The mechanism is the Architect's call; the PRD binds the property (single source of truth, by-construction inheritance for new commands).
- **D6** — **Help / introspection is not exempt.** Per R11. Zero help convention exists today; adding a help bypass expands surface area without justification.

## 9. Dogfood paradox

The gate this feature ships lives inside the 17 command files that any subsequent scaff invocation depends on. The feature itself, however, is being authored *inside* this scaffold project (where `.specaffold/config.yml` already exists), so the implement and validate stages will not invoke the gate's refusal path against themselves. The runtime ACs in §6.2 sandbox `HOME` and CWD per `.claude/rules/bash/sandbox-home-in-tests.md` to exercise the refusal path; the passthrough ACs in §6.3 lock in that the happy path remains byte-identical for the very project we are working in. Per `shared/dogfood-paradox-third-occurrence.md`, structural ACs (§6.1) are the primary verification surface; runtime ACs (§6.2) are exercised in a sandboxed harness rather than by re-running the scaff loop on this feature itself.

## 10. Constraints

- **Bash 3.2 / BSD userland portability** for any helper script the Architect introduces (`.claude/rules/bash/bash-32-portability.md`).
- **Sandbox HOME in tests** for AC7–AC11, AC13 (`.claude/rules/bash/sandbox-home-in-tests.md`). The test harness must `mktemp -d`, export `HOME` into it, register a cleanup `trap`, and assert `HOME` is inside the sandbox before any command invocation.
- **No force on user paths** (`.claude/rules/common/no-force-on-user-paths.md`) — the refusal IS the policy; do not introduce a force-bypass flag (D3).
- **Classify before mutate** (`.claude/rules/common/classify-before-mutate.md`) — the gate is the canonical "classify before mutate" application: classify the project as init'd vs not-init'd, then dispatch (run or refuse). This feature operationalises that rule for the scaff command surface itself.
- **Language preferences** (`.claude/rules/common/language-preferences.md`) — refusal-message text is English regardless of `LANG_CHAT`. Chat replies during PM/Architect/Developer probes are zh-TW when `LANG_CHAT=zh-TW`.

## Team memory

Applied entries:
- `pm/ac-must-verify-existing-baseline.md` — applied to AC12: pre-change golden snapshot of the 17 command files captured at PRD-lock so the wiring diff can be asserted as the only change.
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md` — does not apply (no B1/B2 split here; this is a single-feature gate).
- `shared/dogfood-paradox-third-occurrence.md` — applied to §9 and the structural-vs-runtime AC split: the gate ships in command files that any in-repo invocation depends on; runtime exercise lives in a sandbox harness, not in the dogfooded scaff loop.
- `shared/status-notes-rule-requires-enforcement-not-just-documentation.md` — informs the disposition that the gate must be enforced by mechanism, not by a "remember to check first" prompt reminder; that conviction is reflected in R4 (by-construction inheritance) and G5 (auditable from one location).

Proposed new memory: none yet — wait until validate to see whether the by-construction-inheritance pattern (R4 + AC4) generalises to other "every command must X" features (e.g. a future logging-marker, a future telemetry hook). If it does, a `pm/by-construction-coverage-over-author-discipline.md` memory entry is the candidate.
