# Tech — scaff-init-preflight

- **Slug**: 20260426-scaff-init-preflight
- **Authored**: 2026-04-26 by Architect
- **Reads**: 00-request.md, 03-prd.md
- **Tier**: standard
- **Mechanism chosen**: **Option A (convention + lint)** — see D1.

## 1. Context & Constraints

### 1.1 Existing stack (committed; reuse, do not extend)

- Slash-command surface: 18 markdown files under `.claude/commands/scaff/*.md`. Each file is a self-contained directive set that the assistant interprets at invocation time. The first non-frontmatter content of each file is the operative instruction.
- `.claude/commands/scaff/` is **harvested recursively** by the Claude Code session-start scan; every `*.md` under it becomes a `/scaff:<name>` slash command. There is no opt-out marker, no underscore-prefix exemption, no nested-subdirectory exemption (architect memory `commands-harvest-scope-forbids-non-command-md`). Any shared snippet for the gate **must live outside this directory**, or it would itself become a spurious `/scaff:<snippet-name>` command.
- `bin/scaff-lint` is the existing lint binary. Today it implements one subcommand (`scan-staged` / `scan-paths`) for CJK guardrail scanning. It is bash 3.2 / BSD-userland portable, dispatches via a `case` block on the first argument, and exits 0/1/2 in a documented contract. It is invoked from a pre-commit hook.
- `bin/claude-symlink install` exposes `.claude/commands/scaff/`, `.claude/agents/scaff/`, `.claude/skills/scaff-init/` user-globally via symlinks. `scaff-init` is a **skill** (`.claude/skills/scaff-init/SKILL.md` + `init.sh`), not a slash command — it is **not** present under `.claude/commands/scaff/`. PRD AC3 (`scaff-init.md` must not reference the shared mechanism) is satisfied vacuously: the file does not exist in the gated directory at all.
- Off-by-one in PRD §5.3 R3: the enumerated list contains 18 names (archive, bug, chore, design, implement, next, plan, prd, promote, remember, request, review, tech, update-{plan,req,task,tech}, validate) while the prose says "exactly 17 commands". The directory contains 18 files. Treat the enumerated list as authoritative (R3's prose miscount is a typo); gate all 18.
- `.specaffold/config.yml` exists in this repo (`lang: chat: zh-TW`). The presence-only check needed by R1/R2 is: `[ -f "$cwd/.specaffold/config.yml" ]`.
- `.specaffold/` is the established home for non-command repo metadata: `.specaffold/features/`, `.specaffold/archive/`, `.specaffold/prd-templates/` (architect memory: shared markdown owned by command files belongs under `.specaffold/<purpose>-templates/`, not under `.claude/commands/scaff/`).

### 1.2 Hard constraints

- **Bash 3.2 / BSD userland portability** — any shell logic the gate adds (reference snippet, lint script extension) must conform to `.claude/rules/bash/bash-32-portability.md`. No `[[ =~ ]]`, no `realpath`, no `mapfile`, no `jq`. POSIX `case` and `expr` only.
- **No force, no silent clobber** — gate's purpose IS the policy (`.claude/rules/common/no-force-on-user-paths.md`). No bypass flag in v1 (PRD D3 / NG7).
- **Classify before mutate** — the gate is the canonical "classify project as init'd vs not-init'd, then dispatch (run or refuse)" application of `.claude/rules/common/classify-before-mutate.md`. The pure classifier is "does `.specaffold/config.yml` exist as a regular file under CWD?".
- **Sandbox `HOME` in tests** — runtime ACs (AC7–AC11, AC13) must run inside a `mktemp -d` sandbox per `.claude/rules/bash/sandbox-home-in-tests.md`. The harness must NOT invoke the assistant; it must exercise the gate's deterministic shell text directly.
- **English-only file content / CLI stdout** — refusal message text is English regardless of `LANG_CHAT` (PRD §10; `.claude/rules/common/language-preferences.md` carve-outs (b)(d)).

### 1.3 Soft preferences

- Minimise diff blast radius: PRD AC12 binds that each of the 18 files diff from baseline contains **only** the wiring addition. Mechanism choices that mutate file structure (move directives, replace bodies) are disfavoured.
- Auditability from a single grep: PRD G5 requires "the operator can read exactly one location to know what the gate does". Single source of truth.
- Reversibility: the dogfood paradox (PRD §9) says this feature modifies the surface that scaff itself runs through. If a wave breaks a command file, recovery must be a hand-edit (no `/scaff:next` round-trip required).

### 1.4 Forward constraints

- A future "logging marker every command emits at start" feature would want the same by-construction inheritance shape. The mechanism chosen here should be reusable as a template for that class of feature, not a one-off.
- A future config-validation feature (PRD NG5) will sit alongside this presence-check, not replace it. The gate body must be a self-contained presence check that a future validator can be layered above (e.g. "presence + parses + has key X").

## 2. System Architecture

### 2.1 Components

```
                         User invokes /scaff:<name>
                                   │
                                   ▼
        ┌──────────────────────────────────────────────┐
        │  .claude/commands/scaff/<name>.md            │
        │  ┌────────────────────────────────────────┐  │
        │  │ <!-- preflight: required -->           │  │ ← wiring (1 line / file)
        │  │ Run preflight from                     │  │
        │  │ `.specaffold/preflight.md` first;      │  │
        │  │ abort with refusal if it fails.        │  │
        │  └────────────────────────────────────────┘  │
        │  <existing command body — UNCHANGED>         │
        └──────────────────────────────────────────────┘
                                   │
                                   ▼
        ┌──────────────────────────────────────────────┐
        │  .specaffold/preflight.md (single source)    │ ← gate body (1 file)
        │  - presence check on .specaffold/config.yml  │
        │  - refusal text + recovery pointer           │
        │  - mechanical refusal marker (REFUSED:PREFLIGHT)
        └──────────────────────────────────────────────┘
                                   │
                                   ▼
              ┌─────────────────────────────────┐
              │ bin/scaff-lint preflight-coverage│ ← lint subcommand (R4)
              │ enforces every command.md under │
              │ .claude/commands/scaff/ carries │
              │ the wiring marker line          │
              └─────────────────────────────────┘
```

### 2.2 Sequence — gated path (Scenario 4.2)

1. User runs `/scaff:next` in a project where `.specaffold/config.yml` does not exist.
2. Assistant loads `.claude/commands/scaff/next.md`. The first instruction line is the preflight directive (the wiring).
3. Assistant follows the wiring directive: reads `.specaffold/preflight.md`. The preflight body specifies a single `[ -f .specaffold/config.yml ]` check.
4. The check fails. Preflight emits the refusal one-liner (containing the literal tokens `.specaffold/config.yml`, the CWD, and `/scaff-init`) plus the mechanical marker `REFUSED:PREFLIGHT`, and instructs the assistant to terminate.
5. Assistant halts. Zero side effects: no template copy, no STATUS edits, no agent dispatch.

### 2.3 Sequence — passthrough (Scenario 4.1)

1. User runs `/scaff:next` in a project where `.specaffold/config.yml` exists.
2. Assistant follows the wiring directive, reads `.specaffold/preflight.md`, runs the presence check.
3. Check passes. Preflight emits **no user-visible output** (the silent passthrough required by R7) and instructs the assistant to continue with the command's normal body.
4. The command runs byte-identically to its pre-change behaviour.

### 2.4 Sequence — exempt path (Scenario 4.3)

1. User invokes `scaff-init`. `scaff-init` is a **skill** at `.claude/skills/scaff-init/`, NOT a slash command under `.claude/commands/scaff/`.
2. Skills are not in the gated directory; the wiring is not added there. The gate cannot fire.
3. AC3 (no preflight reference in `scaff-init.md`) is structurally satisfied: the file does not exist in the directory the gate operates on.

## 3. Technology Decisions

### D1. Gate mechanism — convention + lint (Option A)

- **Options considered**:
  - **A** — Each command file carries a one-line wiring directive at the top that points at a shared snippet. A new lint subcommand asserts every command file under `.claude/commands/scaff/` carries the wiring (so a new author cannot forget to add it).
  - **B** — A SessionStart hook ships a session-global rule under `.claude/rules/common/scaff-preflight.md` saying "before executing any `/scaff:*` command except via the scaff-init skill, check `.specaffold/config.yml`; refuse if missing". Inheritance is automatic; no per-file wiring.
  - **C** — Replace each command file's body with a one-line dispatch to a wrapper bash script that runs the preflight then sources/inlines the original instructions.

- **Chosen**: **A**.

- **Why**:
  1. **Concreteness wins for slash-commands.** Claude Code commands are *interpreted markdown directives*, not executed scripts. Option B's "session-global rule" is also an interpreted directive — its enforcement is exactly as strong as today's status quo (assistant compliance with a rule it has loaded). The gate the user wants is a per-command anchor that lives **inside** the command body, so a reviewer can see it inline and the assistant cannot "forget" because the directive is already in front of it. Option A puts the gate at the top of every file the assistant loads when invoking the command. Option B puts the gate in a separate rules digest the assistant must remember to consult — not stronger, just more diffuse.
  2. **By-construction inheritance via lint is deterministic.** R4 / AC4 require new commands to inherit the gate without author-discipline. Option A's mechanism is: `bin/scaff-lint preflight-coverage` runs in the pre-commit hook and fails the commit if any `.claude/commands/scaff/*.md` file (other than non-existent allow-listed paths) lacks the wiring marker. The lint is the by-construction enforcement (architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task` — the wiring is a deliverable, not implicit; here, it's *enforced* as a deliverable rather than just promised). Option B's "automatic inheritance" is inheritance only if the assistant honours the rule; this is the same compliance model the status quo already has and PRD §1 says is too weak.
  3. **Reversibility under dogfood paradox.** If a wave merges a broken wiring line, recovery is a hand-edit of plain markdown — no `/scaff:next` round-trip needed (because that's exactly what the gate would block). Option C (wrapper script) has the highest blast radius: a syntax error in the wrapper breaks all 18 commands at once. Option B's failure mode is subtler — if the SessionStart hook itself errors, the rule isn't loaded and the gate silently disappears (`hook-fail-safe-pattern` memory: hooks must be fail-safe for session boot, which can mean fail-open for the gate they ship).
  4. **Single source of truth for the gate body.** Option A's wiring is one line per file; the gate logic itself lives in `.specaffold/preflight.md` (one location). G5 satisfied: a reviewer reads one file to know what the gate does.
  5. **Lint binary already exists.** `bin/scaff-lint` is bash 3.2 portable, has a documented exit-code contract, and already runs from the pre-commit hook. Adding a subcommand `preflight-coverage` is a minimal extension (architect memory `scope-extension-minimal-diff`: extend, don't re-taxonomy).

- **Tradeoffs accepted**:
  - 18 wiring lines must be authored once. Acceptable: this is a one-time edit per command file, the wiring **is the whole content of each diff** (PRD AC12 requires it), and the lint guarantees no backsliding.
  - The assistant's compliance with the wiring directive is still load-bearing for runtime correctness — i.e. the gate is *enforced* by the assistant reading the directive at the top of the file it just loaded. This is strictly stronger than Option B (where compliance depends on a session-global rule digest the assistant may de-emphasise). It is strictly weaker than Option C (where compliance is enforced by a wrapper script the assistant cannot bypass even by misreading). The lint catches the *authoring* failure mode (a missing wiring line) deterministically; the *interpretation* failure mode (assistant reads the wiring but ignores it) is the residual risk shared with every Claude-Code-interpreted directive in the repo.

- **Reversibility**: high. Wiring is plain markdown; either drop the marker line or remove the lint check.

- **Requirement link**: R4, R7, R8, R9, G5.

### D2. Shared snippet location and name — `.specaffold/preflight.md`

- **Options considered**:
  - **A** — `.claude/commands/scaff/_preflight.md` (colocated with consumers).
  - **B** — `.claude/commands/scaff-includes/preflight.md` (sibling subdir).
  - **C** — `.specaffold/preflight.md` (under repo metadata root).
  - **D** — Inline the gate body 18 times (rejected: violates R9, AC1).

- **Chosen**: **C**, exactly `.specaffold/preflight.md`.

- **Why**:
  - Architect memory `commands-harvest-scope-forbids-non-command-md`: any `.md` under `.claude/commands/scaff/` is harvested into a slash command. `_preflight.md` would auto-register as `/scaff:_preflight`, exactly the spurious-command class that surfaced as a remediation cost in feature `20260424-entry-type-split`. Underscore prefix is **not** an opt-out. This eliminates A immediately.
  - For B, the harvest scope walks `.claude/commands/scaff/` recursively but I have **not** verified at this layer that `.claude/commands/scaff-includes/` is excluded; the harvest is rooted at `.claude/commands/scaff/`, so a sibling directory `.claude/commands/scaff-includes/` would be outside the harvest tree. However this still places the snippet inside the slash-command surface space, where future tidying could mistakenly fold it back in. Memory `commands-harvest-scope-forbids-non-command-md` recommends `.specaffold/<purpose>-templates/` as the durable location for non-command markdown, which is the exact precedent set by `.specaffold/prd-templates/` from the same memory.
  - C aligns with the established pattern: `.specaffold/` is where shared, non-command markdown that command files reference belongs. The name `preflight.md` (no `<purpose>-templates/` directory wrapper) is acceptable because there is exactly one preflight body for v1; if a second preflight kind ever ships, promote to `.specaffold/preflight/<kind>.md`. Single-file simplicity wins now.

- **Tradeoffs accepted**: the file is one directory removed from the consumers; reviewers must follow one path-link to read the gate body. Acceptable: G5 says "one location", which `.specaffold/preflight.md` is.

- **Reversibility**: high (rename / move requires updating 18 wiring directives + 1 lint allow-list).

- **Requirement link**: R8, AC1, NG6.

### D3. Wiring directive shape — visible markdown comment + imperative directive

- **Options considered**:
  - **A** — HTML comment marker only: `<!-- preflight: required -->` (machine-greppable; not surfaced to the assistant as instruction text).
  - **B** — Imperative directive line: a literal sentence at the top of the body that says to run the preflight first.
  - **C** — Frontmatter key: `preflight: required` inside the existing `---`-fenced YAML block.
  - **D** — Both A and B (marker + directive).

- **Chosen**: **D** (marker + directive). Concretely, the wiring block is:

  ```markdown
  <!-- preflight: required -->
  Run the preflight from `.specaffold/preflight.md` first.
  If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
  this command immediately with no side effects (no agent dispatch,
  no file writes, no git ops); print the refusal line verbatim.
  ```

- **Why**:
  - The HTML-comment marker is the **lint anchor** — `bin/scaff-lint preflight-coverage` greps for the literal string `<!-- preflight: required -->`, an unambiguous needle that won't accidentally match prose elsewhere.
  - The imperative directive is the **runtime anchor** — the assistant reads it as part of the command body and executes the preflight. Without it, the comment is invisible to the assistant.
  - Frontmatter (Option C) was rejected: not all 18 files have identical frontmatter shape today, and adding a new key would push some files into multi-key frontmatter that they don't currently use. Higher diff churn for no readability gain.
  - Putting the directive inline (above the existing first step) is the minimal-diff shape: the existing first-step content is unchanged, the new content is purely additive (PRD AC12).

- **Tradeoffs accepted**: 18 file diffs each adding 5 lines (1 comment + 4 directive lines). Acceptable: this is exactly the wiring-only diff PRD AC12 expects.

- **Reversibility**: high (per-file edit if shape needs to change).

- **Requirement link**: R8, R9, AC2, AC12.

### D4. Refusal message format and mechanical marker

- **Options considered**:
  - **A** — Single-line refusal containing all three required tokens (R5: `.specaffold/config.yml`, CWD, `/scaff-init`).
  - **B** — Single-line refusal **plus** a separate machine marker line (e.g. `REFUSED:PREFLIGHT`) that downstream tooling can grep for.

- **Chosen**: **B**. The preflight body emits exactly two lines on the refusal path:

  ```
  REFUSED:PREFLIGHT — .specaffold/config.yml not found in <CWD>; run /scaff-init first
  ```

  Wait — that is **one** line. The single line carries both the mechanical marker prefix and the human-readable body. PRD R5 binds "exactly one line of user-visible output"; combining the marker with the human text in one line satisfies R5 and R10 simultaneously.

  Concrete refusal one-liner template, in the preflight body:

  ```
  REFUSED:PREFLIGHT — .specaffold/config.yml not found in $(pwd); run /scaff-init first
  ```

  When emitted, `$(pwd)` is substituted at gate time to the current working directory, satisfying AC5 and AC7.3 (refusal contains the runtime CWD).

- **Why**:
  - PRD R10 / D4 require "mechanically distinguishable from a runtime error". A literal prefix `REFUSED:PREFLIGHT` is a deterministic grep target for tests (`grep -q '^REFUSED:PREFLIGHT'`); arbitrary error messages from broken commands won't accidentally match.
  - Single-line constraint (R5.4) is preserved: prefix + em-dash + body is one line.
  - All three required substrings present: `.specaffold/config.yml` (literal), `$(pwd)` (substituted), `/scaff-init` (literal). AC5 and AC7.1–4 satisfied by inspection.

- **Tradeoffs accepted**: marker is bash-shaped (uppercase, colon-separated). A user reading the refusal sees the marker prefix; that is the intended UX for "loud refusal" (G2).

- **Reversibility**: medium (changing the marker means updating both the preflight body and any downstream tooling that greps for it; acceptable because no such downstream tooling exists yet).

- **Requirement link**: R5, R10, D4, AC5, AC7, AC8.

### D5. Preflight body — pure presence check, no parsing

The body of `.specaffold/preflight.md` is itself a markdown directive set, since the assistant interprets it. It must:

1. Resolve the working directory (the assistant's invocation CWD).
2. Test `[ -f "$CWD/.specaffold/config.yml" ]`. **Presence-only** (R2 / D2 / NG5). Zero-byte and malformed contents both pass.
3. On absent: emit the single-line refusal per D4 and instruct the assistant to abort with no side effects (R6 enumeration: no directories, no files, no git ops, no sub-agent invocations).
4. On present: emit nothing user-visible (R7 byte-identical passthrough) and instruct the assistant to continue.

The presence check is intentionally trivial. Future config-schema validation (NG5) ships as a separate feature on top of this gate, not as a modification to it.

- **Reversibility**: high.
- **Requirement link**: R1, R2, R5, R6, R7, NG5.

### D6. Lint subcommand — `bin/scaff-lint preflight-coverage`

- **Options considered**:
  - **A** — New top-level binary `bin/scaff-preflight-lint`.
  - **B** — New subcommand on existing `bin/scaff-lint`: `bin/scaff-lint preflight-coverage`.

- **Chosen**: **B**.

- **Why**:
  - Architect memory `scope-extension-minimal-diff`: existing `bin/scaff-lint` already has a documented subcommand dispatch (`scan-staged`, `scan-paths`); adding `preflight-coverage` is a one-row extension to the dispatch `case` block. No new binary, no new pre-commit hook entry needed if the existing hook already invokes `bin/scaff-lint`.
  - Reviewer-style memory: bash 3.2 portable, follows existing exit-code contract (0 = clean, 1 = findings, 2 = usage error).

- **Behaviour**:
  - **Input**: zero arguments (the subcommand operates on a fixed scope).
  - **Scope**: all `*.md` files directly under `.claude/commands/scaff/` (non-recursive — there are no subdirs there today, and nesting is forbidden by the harvest-scope memory anyway).
  - **Allow-list**: empty in v1. (`scaff-init.md` is **not** in the directory; no allow-list entry needed for it. If a future non-command markdown file legitimately lives here — which the harvest-scope memory says it should not — it would be added explicitly.)
  - **Check**: each file must contain the literal anchor line `<!-- preflight: required -->`. Match via `grep -F` (fixed-string, no regex). Missing match for any file = finding.
  - **Output**: stdout one line per file; `ok:<path>` or `missing-marker:<path>`. Matches the existing `scan-staged` / `scan-paths` output shape.
  - **Exit**: 0 if every file has the marker; 1 if any file lacks it; 2 on usage error.
  - **Self-allow-list**: not applicable. The lint searches `.claude/commands/scaff/`, not `bin/`. The lint script's own source contains the marker literal as a search pattern, but that source lives at `bin/scaff-lint`, outside the scan scope. Architect memory `self-referencing-assertion-script-allow-list` does not apply (the search corpus and the search source are in different trees). Leaving this note here so a future maintainer doesn't add a needless allow-list entry.
  - **Pre-commit hook wiring**: existing pre-commit hook already invokes `bin/scaff-lint scan-staged`. **Wiring task** for TPM: add a second invocation `bin/scaff-lint preflight-coverage` to the same hook (this satisfies architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task` — wiring is an explicit task, not implicit).

- **Reversibility**: high (single subcommand `case` arm; remove arm to retract).

- **Requirement link**: R4, R8, AC2, AC4.

### D7. Test harness — exercise preflight body directly, NOT via the assistant

- **Options considered**:
  - **A** — Test harness invokes a slash-command end-to-end (assistant in the loop) and asserts the refusal is printed. Rejected: assistant invocation isn't reproducible from a shell test, and circularity (test-the-gate-by-asking-the-assistant-to-run-the-gated-command) collapses confidence.
  - **B** — Test harness extracts the deterministic shell snippet from `.specaffold/preflight.md` (the presence check + refusal one-liner) and runs **that** against a sandboxed CWD. The assistant is not in the loop; the test asserts the output of running the preflight body's shell.

- **Chosen**: **B**. The preflight body must contain a deterministic shell snippet (a small bash block) that performs the presence check and emits the refusal/passthrough output. The harness extracts and runs that snippet.

- **Why**:
  - PRD §6.2 ("runtime ACs") says "executed inside a `mktemp -d` sandbox that exports `HOME`". The harness must be a shell test (`.claude/rules/bash/sandbox-home-in-tests.md`). A shell test cannot invoke the assistant.
  - The deliverable is a property of the preflight body's *output* (refusal one-liner / silent passthrough), not of the assistant's behaviour. Asserting the property by directly running the shell snippet is the correct test boundary.
  - The structural ACs (§6.1) cover the wiring layer: AC2 asserts each command file references the shared snippet; AC1 asserts the shared snippet exists; the lint (D6) automates AC4. Together with D7's runtime sandbox tests, the gate is fully tested without the assistant in the loop.

- **Concrete shape of the snippet inside `.specaffold/preflight.md`** (the assistant is instructed to execute this block; tests extract and run it directly):

  ```bash
  # === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===
  # This block is the single source of truth for the gate.
  # Tests may extract and execute this block directly.
  if [ ! -f ".specaffold/config.yml" ]; then
    printf 'REFUSED:PREFLIGHT — .specaffold/config.yml not found in %s; run /scaff-init first\n' "$(pwd)" >&2
    exit 70
  fi
  # === END SCAFF PREFLIGHT ===
  ```

  The fenced markers (`# === SCAFF PREFLIGHT ===` / `# === END SCAFF PREFLIGHT ===`) let the test harness `awk` the exact block out of `.specaffold/preflight.md`, write it to a temp file, and `bash` it. Bash 3.2 / BSD portable: only `[ -f ]`, `printf`, `pwd`, `exit` — no GNU-only flags.

  The exit code `70` is arbitrary but documented (treat as `EX_PROTOCOL` from `<sysexits.h>`); any non-zero would do. Test harnesses can assert both the `REFUSED:PREFLIGHT` stdout marker AND a non-zero exit. The assistant's own dispatch on this block: when running the snippet, a non-zero exit signals "abort the command" (assistant interprets it per the wiring directive in the command file).

- **Tradeoffs accepted**:
  - The preflight body has dual purpose: assistant-readable directive (markdown prose) + shell-executable block (fenced code). Both must agree. Lint check `preflight-coverage` does NOT validate this agreement (it only checks command-file wiring); a single qa-tester runtime AC asserting "the extracted shell block, when run in a sandbox without `.specaffold/config.yml`, emits `REFUSED:PREFLIGHT` and exits non-zero" is the contract test. This is one of the runtime ACs.
  - The assistant must understand that "execute the fenced bash block" is the operative directive. The wiring text in each command file (D3) names this explicitly.

- **Reversibility**: high.

- **Requirement link**: R6, R10, AC7, AC8, AC10, AC11, AC13.

### D8. `scaff-init` skill — no change

- `scaff-init` is a **skill** (`.claude/skills/scaff-init/{SKILL.md,init.sh}`), not a slash command under `.claude/commands/scaff/`. The wiring directive (D3) is added only to slash-command files in the harvested directory; the skill is outside that scope. AC3 ("`scaff-init.md` does not reference the shared mechanism") is satisfied vacuously.
- The lint (D6) operates on `.claude/commands/scaff/*.md`; it does not scan `.claude/skills/`. No lint exclusion needed for scaff-init.
- **No changes to the scaff-init skill files in this feature.** PRD NG1 holds: scaff-init is the init entry point and stays exempt.

- **Reversibility**: trivial (no change made).

- **Requirement link**: NG1, AC3.

### D9. README mention — one sentence in repo `README.md`

- **Chosen**: add one sentence to the repo `README.md` near the existing scaff-command introduction (whichever section enumerates the scaff commands today; if absent, add to the "Usage" or "Quickstart" section). Wording is the Developer's call (PRD R13), but the sentence must contain both `config.yml` and `scaff-init` co-occurring on one line so `grep -E '(config\.yml.*scaff-init|scaff-init.*config\.yml)' README.md` matches AC6.
- Single sentence; no new section header. Architect memory `scope-extension-minimal-diff` applies.

- **Reversibility**: high.

- **Requirement link**: R13, AC6.

## 4. Cross-cutting Concerns

### 4.1 Error handling

- **Refusal path** — preflight emits the marker line on stderr (per D7 snippet), exits non-zero. The assistant aborts the command per the wiring directive.
- **Passthrough path** — preflight emits nothing, exits zero. Assistant continues with the command body.
- **Malformed wiring** — caught by `bin/scaff-lint preflight-coverage` at pre-commit, before the bad file is ever invoked. Failure is loud (exit 1, the missing-marker classifier line in stdout).
- **Preflight body itself broken** — caught by the runtime AC that extracts the fenced snippet and runs it against a sandbox CWD. If the snippet has a syntax error or wrong logic, the runtime AC fails at validate.

### 4.2 Logging / tracing

- No new logging infrastructure. The refusal line itself IS the trace; if the user sees `REFUSED:PREFLIGHT — ...` they have the full diagnostic.
- No bypass flag (D3 / NG7), so `architect/opt-out-bypass-trace-required.md` does not apply in v1. If a future bypass is added (separate feature), that feature must implement the STATUS-Notes-trace pattern from that memory.

### 4.3 Security

- **Path traversal** — the preflight check uses a relative path `.specaffold/config.yml` resolved against `$(pwd)`. The assistant's CWD is by construction the project root; the check is a regular-file existence test, not a path join with user input. No traversal surface.
- **No secrets handled** — the gate is presence-only and emits a path string (`$(pwd)`) into stdout. The CWD is not a secret in this CLI's context.
- **No injection surface** — the refusal `printf` uses a format string with `%s`; the substituted argument is `$(pwd)`, which is not user input.

### 4.4 Testing strategy (feeds Developer's TDD)

- **Structural tests** (executed by qa-tester, no sandbox needed):
  - AC1: assert `.specaffold/preflight.md` exists and contains the SCAFF PREFLIGHT fenced block.
  - AC2: for each of 18 files in `.claude/commands/scaff/`, assert `grep -F '<!-- preflight: required -->'` matches.
  - AC3: assert no file under `.claude/skills/scaff-init/` contains `<!-- preflight: required -->` (vacuous; skill files aren't markdown commands, but cheap to check).
  - AC4: assert `bin/scaff-lint preflight-coverage` exits 0 today (after wiring is in) and exits 1 when the marker is removed from any file (mutation test).
  - AC5: extract the refusal one-liner template from `.specaffold/preflight.md`; assert it contains `.specaffold/config.yml`, `$(pwd)` (literal `$(pwd)` token), and `/scaff-init`.
  - AC6: `grep -E '(config\.yml.*scaff-init|scaff-init.*config\.yml)' README.md`.
  - AC12: pre-change baseline (golden snapshot) of each of 18 files vs post-change content; diff is restricted to the wiring lines added per D3.

- **Runtime tests** (executed by qa-tester via sandboxed shell harness, NOT via the assistant; see D7):
  - AC7: extract the fenced block, run it in a `mktemp -d` sandbox CWD lacking `.specaffold/config.yml`; assert stdout/stderr contains the three required tokens, single line, marker prefix, non-zero exit.
  - AC8: hash-verify the sandbox CWD before and after extraction-snippet run; assert byte-identical (no mutations from the gate itself).
  - AC9: in same sandbox, simulate the scaff-init exempt path by NOT invoking the snippet (since scaff-init is outside the gated directory); the test is structural — assert the scaff-init skill is not in `.claude/commands/scaff/`.
  - AC10: extract the fenced block, run it in a sandbox CWD where `touch .specaffold/config.yml` was first run; assert empty stdout/stderr (silent passthrough), exit 0.
  - AC11: same as AC10 but with `printf 'not yaml at all\n' > .specaffold/config.yml` and a zero-byte variant; assert both pass the gate.
  - AC13: structural — assert no command body lines other than the wiring block were modified vs baseline (extension of AC12 to cover passthrough byte-identity).

### 4.5 Performance / scale

- Gate cost: one `[ -f ]` test per command invocation. Sub-millisecond on any local filesystem. Latency budget is irrelevant for this feature.
- Lint cost: 18 `grep -F` invocations at pre-commit. Reviewer-performance memory (`shell-out in tight loops`): the lint should batch the grep — `grep -L -F '<!-- preflight: required -->' .claude/commands/scaff/*.md` (single fork, lists files MISSING the marker) instead of looping. This is a TPM-plan-time refinement — flagging here so the developer doesn't spawn 18 forks.

## 5. Open Questions

None blocker. Two minor notes for TPM:

- **Note A — PRD off-by-one**: PRD §5.3 R3 says "exactly 17 commands" but enumerates 18. Tech treats the enumerated list as authoritative (gate all 18 files in `.claude/commands/scaff/`). TPM should not treat this as a blocker; mention it in the plan retrospective so PM updates R3 prose if desired.
- **Note B — `scaff-init` is a skill, not a slash command**: AC3 is therefore satisfied vacuously. PRD wording references `.claude/commands/scaff/scaff-init.md` which does not exist; the file system reality is `.claude/skills/scaff-init/SKILL.md`. TPM should reflect this in the plan's structural-AC restatement so the developer doesn't go looking for a non-existent file.

## 6. Non-decisions (deferred)

- **Config schema validation** (NG5) — deferred. Presence-only check today; a separate feature can layer schema validation on top by adding a second fenced block to `.specaffold/preflight.md` or a separate preflight stage.
- **Bypass flag** (NG7 / D3) — deferred. If a future use case needs to bypass the gate (e.g. a meta-tool inspecting another project), it ships as its own feature with the STATUS-Notes-trace pattern from `architect/opt-out-bypass-trace-required.md`.
- **Help-exempt path** (R11 / D6) — deferred. No help convention exists today; if one is added, that feature decides whether the gate applies.
- **Gating CLI scripts in `bin/scaff-*`** (NG6) — deferred. Scripts inherit the gate transitively from their command-file callers; gating at the script layer would double-fire.

## Team memory

Applied entries:
- `architect/script-location-convention` (local) — bin/ scripts only; the lint subcommand goes into the existing `bin/scaff-lint`, not a new top-level script. Drove D6.
- `architect/no-force-by-default` (local) — paired with `.claude/rules/common/no-force-on-user-paths.md`. Drove D3 (no bypass flag) and the gate's stance: refusal IS the policy.
- `architect/classification-before-mutation` (local) — paired with `.claude/rules/common/classify-before-mutate.md`. The gate is the canonical operationalisation of this rule for the scaff command surface.
- `architect/shell-portability-readlink` (local) — kept the shell snippet in D7 to bash 3.2 / BSD portable primitives only (`[ -f ]`, `printf`, `pwd`, `exit`).
- `architect/commands-harvest-scope-forbids-non-command-md` — drove D2 (snippet location is `.specaffold/preflight.md`, NOT under `.claude/commands/scaff/`).
- `architect/scope-extension-minimal-diff` — drove D6 (extend `bin/scaff-lint` with one subcommand) and D9 (one sentence to README).
- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task` — drove D6's "Wiring task for TPM" note: pre-commit hook invocation of the new subcommand is a plan-time deliverable, not implicit.
- `architect/self-referencing-assertion-script-allow-list` — checked, does not apply: lint scope and lint source live in different trees.
- `shared/dogfood-paradox-third-occurrence` — drove the structural-vs-runtime AC split (already in PRD §6) and D1's "reversibility under dogfood paradox" justification.
- `shared/auto-classify-argv-by-pattern-cascade` — does not apply: the gate has no polymorphic argv classification; it has a single binary check.
- `shared/status-notes-rule-requires-enforcement-not-just-documentation` — drove D6's lint discipline: the gate is enforced by tooling (lint + pre-commit hook), not by per-author memory.

Proposed new memory (post-validate, only if pattern recurs): `architect/by-construction-coverage-via-lint-anchor` — when a new convention must apply to N files in a closed directory and a future author must inherit it without discipline, the pattern is (1) one-line markdown anchor in each file, (2) gate body in a single shared file outside the harvest scope, (3) lint subcommand asserting marker presence as the by-construction enforcement, (4) pre-commit hook wires the lint. Wait until validate to confirm this generalises.
