# Tech — language-preferences

_2026-04-19 · Architect_

## Team memory consulted

- `architect/hook-fail-safe-pattern.md` — **load-bearing**: the SessionStart
  hook's new config read (D1, D5, D7) must stay `set +e` + `trap 'exit 0'`;
  a broken config-read must degrade to "feature off" silently, never block
  session start. Warning path is stderr only per R7.
- `architect/settings-json-safe-mutation.md` — cross-referenced for D1: the
  config file is user-owned and the installer must NOT touch it if present
  (feature is opt-in; users author the file by hand). If install ever needs
  to write it later, the read-merge-write + `.bak` + atomic-swap discipline
  applies.
- `architect/script-location-convention.md` — applies to D2: the guardrail
  CLI is user-facing, so `bin/specflow-lint` (no extension, exec bit);
  `scripts/` remains reserved for dev-time helpers.
- `architect/shell-portability-readlink.md` — applies to every bash and
  hook decision below. No `readlink -f`, no `realpath`, no `jq`, no
  `mapfile`, no `[[ =~ ]]` for portability-critical logic. YAML read is
  a single-line `awk` sniff (bash 3.2 + BSD userland).
- `architect/classification-before-mutation.md` — applies to D2/D6: the
  guardrail scans files into a closed result enum (`ok` / `cjk-hit` /
  `allowlisted` / `binary-skip`) before reporting; no mutation in the
  classifier.
- `shared/dogfood-paradox-third-occurrence.md` — **7th occurrence**. R9
  binds this directly. All runtime-observable ACs (AC1.b, AC5.a, AC7.\*)
  are structural-only during this feature's own verify; runtime PASS is
  the next-feature handoff. Design intentionally keeps the install
  surface as small as possible (one new file + one small hook edit + one
  new bin script) to minimise what the post-archive smoke test must
  cover manually.
- `shared/opt-out-bypass-trace-required.md` — applies to D8: the
  guardrail bypass flag (`git commit --no-verify`, or the
  `SPECFLOW_LINT_ALLOW` env escape) must write a STATUS Notes trace when
  used on a feature in progress; the guardrail itself emits the line
  that a human or orchestrator appends.
- `shared/scope-extension-minimal-diff.md` — applies to D4: the rule
  adds one file under `.claude/rules/common/` and one row to
  `index.md`; it does **not** introduce a new `scope:` value or a new
  subdir. Flat-enum extension via append, not re-taxonomy.

---

## 1. Context & Constraints

### Existing stack (what's already committed)

- **`.claude/rules/` tree** — eight rules today, indexed by
  `.claude/rules/index.md`. Frontmatter schema (five keys) documented in
  `.claude/rules/README.md`. Scope enum: `common | bash | markdown | git
  | reviewer | <lang>`. Every rule body today is **unconditional** (its
  text always applies in session).
- **`.claude/hooks/session-start.sh`** — pure bash 3.2, fail-safe
  (`set +e`, `trap 'exit 0' ERR INT TERM`). Walks `.claude/rules/common/`
  unconditionally plus lang-heuristic subdirs, classifies each `.md`
  frontmatter, and emits a digest line per valid rule in JSON
  `hookSpecificOutput.additionalContext`. The hook does **not** currently
  read any config; its only input is `.claude/rules/**` file content.
- **`.claude/hooks/stop.sh`** — fail-safe bash, appends a STATUS.md line
  when the current branch names an active feature. Does not read config.
- **`bin/specflow-install-hook`** — Python 3 read-merge-write helper for
  `settings.json`; only touched at install time (`init` / `migrate`).
  Pattern is load-bearing for any future config-write flow.
- **`bin/specflow-seed`** (init/update/migrate, feature
  `20260418-per-project-install`) — the copy engine. Its managed subtree
  list is **explicitly enumerated** (`.claude/agents/specflow/`,
  `.claude/commands/specflow/`, `.claude/hooks/`, `.claude/rules/`,
  `.claude/team-memory/` skeleton, `.spec-workflow/features/_template/`).
  Per-project config lives **outside** the managed subtree by
  construction; `update` will never overwrite it.
- **No `.spec-workflow/config.yml` today** — greenfield. No precedent
  for a `.spec-workflow/` top-level file other than
  `.spec-workflow/features/` and `.spec-workflow/archive/`.
- **No `.claude/settings.json` committed in the source repo today** —
  `.claude/settings.local.json` exists locally but is per-user not
  per-repo; consumers that have run `init` get their own
  `settings.json` authored by `bin/specflow-install-hook` (contains
  only `hooks`, nothing else).
- **No git pre-commit hook** under `.git/hooks/` (only `.sample`s);
  repo has never used one.
- **Only three files in the repo carry CJK today**: the three
  `00-request.md` files that quote the user's original ask verbatim
  (one in this feature's tree, two in `.spec-workflow/archive/`).
  Every other file is pure ASCII + Latin-1 punctuation.

### Hard constraints (from PRD + rules)

- **macOS bash 3.2 + BSD userland floor** (project rule
  `bash/bash-32-portability`; memory `shell-portability-readlink`). The
  new hook-side config read and the guardrail script must both honour
  this. No `jq`, no GNU-only `sed -i`, no `[[ =~ ]]` in portability-
  critical code.
- **Opt-in, default-off is structural** (PRD R1 AC1.a, AC1.c). Must be
  a true no-op — no directive injected, no warning, no observable
  change — when the config key is absent.
- **Artifact English is an invariant** regardless of config (PRD R3).
  The rule body itself is English-only (AC2.a) and the guardrail
  enforces this mechanically (R5).
- **Zero edits under `.claude/agents/specflow/`** (PRD R4 AC4.a).
  Agents inherit the directive via session-wide context, not via
  per-agent prompt edits.
- **Hook must never block session start** (memory
  `hook-fail-safe-pattern.md`). Config-read errors degrade to
  default-off with a stderr warning and exit 0.
- **Rule file itself is English-only** (R2 AC2.a). The *directive* is
  in English, even though it *instructs* the agent to reply in zh-TW.
  This is the crux of the bilingual design: the rule is metadata, not
  content.
- **Dogfood paradox** (shared memory; PRD R9). No AC in this feature
  can be exercised live during its own implement/verify. Runtime
  verification is deferred to the first session after archive +
  session restart.

### Soft preferences

- **Reuse the existing SessionStart hook**. Adding a new hook surface
  for one 2-line config read is a waste of a hook slot and adds
  session-start latency. One `awk` line in the existing hook is
  cheaper.
- **Single source of truth for the directive**. The rule file itself
  carries the directive prose. The hook only emits a small config
  *marker* (`LANG_CHAT=zh-TW`) so the rule body can refer to it; the
  prose lives in one place.
- **Per-project, not per-user**. The knob travels with the consumer
  repo (or is local-only, see D1). A global `~/.claude/settings.json`
  key would cross-contaminate every project on the machine; explicitly
  rejected.
- **Guardrail is cheap to run and cheap to understand**. One script,
  one regex (actually one Python `str.encode` range-test for CJK), one
  allowlist mechanism. No dependency on `jq`, no dependency on `git`
  porcelain beyond `git diff --cached --name-only` and `git
  show :FILE`.

### Forward constraints (must not make later backlog harder)

- **Second language later** (out of scope in v1, but likely). The
  schema should allow `lang.chat: <value>` where v1 recognises
  `zh-TW` and future values can be added without a schema change.
  Config-read code must treat unknown values as default-off with a
  warning (R7) — that naturally accommodates future tokens.
- **Artifact-language non-invariant**. PRD R3 + Non-goals fix
  artefact language at `en`. The schema must NOT include an
  `artifacts` key (would imply configurability that does not exist).
- **Per-project `.spec-workflow/config.yml` might grow other keys
  later** (not specflow-managed; user-authored). The file itself is
  local-only by default. If it later needs to be committed and
  templated, the per-project-install flow would add it to the managed
  subtree list — a one-line diff (scope-extension pattern).

---

## 2. System Architecture

### Components

```
  ┌─────────────────────────────────────────┐
  │ <consumer>/.spec-workflow/config.yml    │  D1: user-authored,
  │   lang:                                  │      local-only,
  │     chat: zh-TW                          │      optional
  └─────────────────┬───────────────────────┘
                    │
                    │ read once at session start
                    v
  ┌─────────────────────────────────────────┐
  │ .claude/hooks/session-start.sh          │  D5: awk one-liner
  │   walks .claude/rules/**                 │      appends marker to
  │   reads lang.chat if config present      │      digest when set
  │   appends "LANG_CHAT=zh-TW" to digest     │
  └─────────────────┬───────────────────────┘
                    │ JSON hookSpecificOutput.additionalContext
                    v
  ┌─────────────────────────────────────────┐
  │ Claude Code session                     │  D4/D7: rule loaded
  │   • rules digest (always includes        │  unconditionally;
  │     language-preferences rule body)      │  body checks marker
  │   • LANG_CHAT marker (only when set)     │  and activates itself
  │   ⇓ inherited by every subagent          │
  │   PM / Architect / TPM / Developer /     │
  │   QA-analyst / QA-tester / Designer      │
  └─────────────────────────────────────────┘

  ┌─────────────────────────────────────────┐
  │ git commit (any surface)                │  D2: pre-commit hook
  │   .git/hooks/pre-commit  ──►  bin/       │      wired by
  │   specflow-lint scan-staged              │      install step
  └─────────────────┬───────────────────────┘
                    │ staged file set
                    v
  ┌─────────────────────────────────────────┐
  │ bin/specflow-lint                       │  D2/D6: closed enum
  │   classify each staged path:             │      classifier
  │     ok / cjk-hit / allowlisted /         │
  │     binary-skip                          │
  │   exit 0 if every path ok/allowlisted    │
  │   exit 1 with human report on cjk-hit    │
  └─────────────────────────────────────────┘
```

### Data flow — Scenario A (opt-in, fresh session)

1. Alice edits `<consumer>/.spec-workflow/config.yml` and adds
   `lang:\n  chat: zh-TW`.
2. She opens a new Claude Code session. Claude Code invokes
   `.claude/hooks/session-start.sh`.
3. The hook walks `.claude/rules/` as today, building the digest.
4. **New step** (D5): after building the digest, the hook reads
   `.spec-workflow/config.yml` via a single `awk` sniff:
   ```bash
   cfg_chat=$(awk '
     /^lang:/        {in_lang=1; next}
     in_lang && /^  chat:/ { sub(/^  chat:[[:space:]]*/, ""); gsub(/"/, ""); print; exit }
     /^[^ ]/         {in_lang=0}
   ' .spec-workflow/config.yml 2>/dev/null)
   ```
   If the file is missing, `cfg_chat` is empty and nothing changes
   (AC7.c: no warning, absence is ordinary).
5. If `cfg_chat` has a recognised value (`zh-TW` or `en`), the hook
   appends `LANG_CHAT=<value>` as a separate line to the digest payload.
   Unknown values → empty `cfg_chat` + one warning line to stderr (R7
   AC7.a). Parse errors → same (AC7.b).
6. The hook emits the combined digest as
   `hookSpecificOutput.additionalContext` and exits 0.
7. Claude Code's session has the digest in-context. The
   `language-preferences` rule body is present (it's a rule like any
   other); its `## Rule` and `## How to apply` sections explicitly say
   *"If `LANG_CHAT=zh-TW` appears in the additional-context payload,
   reply to the user in zh-TW; always write file content, tool
   arguments, and commit messages in English."*
8. When Alice invokes `/specflow:brainstorm`, the PM subagent inherits
   this session context, sees the marker, and replies in zh-TW. The
   `01-brainstorm.md` file it writes is in English (the rule body's
   carve-outs bind it). Every other subagent inherits the same context.

### Data flow — Scenario C (leak caught at commit)

1. Carol's PM drifted under long context and wrote a zh-TW sentence
   into `01-brainstorm.md`. She stages and runs `git commit`.
2. Git invokes `.git/hooks/pre-commit` (installed by D2's wiring step).
3. The hook runs `bin/specflow-lint scan-staged`.
4. The lint script lists staged files via `git diff --cached
   --name-only`. For each staged path, it classifies:
   - Path outside the in-scope set (e.g., anything under
     `.spec-workflow/archive/**`, `test/fixtures/**`, binary files) →
     `binary-skip` or `allowlisted` (D6).
   - Path inside the in-scope set → read the staged content via
     `git show :FILE` and scan for codepoints in the CJK range
     (U+3400–U+9FFF; see D6 for exact ranges). Hit → `cjk-hit`. Clean
     → `ok`.
   - Path matches an explicit allowlist rule (D6, e.g.
     `.spec-workflow/features/**/00-request.md` request-quote lines) →
     `allowlisted`.
5. Classification emits one line per path; after the loop, the lint
   script reports any `cjk-hit` findings (file, line, codepoint) to
   stderr and exits 1. No mutation. Carol's commit is rejected.
6. Carol opens `01-brainstorm.md`, rewrites the sentence in English,
   re-stages, and commits cleanly (every path now `ok` or
   `allowlisted`, exit 0, commit proceeds).

### Module boundaries

- **`.spec-workflow/config.yml`** (user-authored) — one file, one
  key in v1. Local-only by default (not committed; see D1
  Tradeoffs). Specflow never writes it; the user edits it by hand
  (or via a future `specflow config set` verb — out of scope).
- **`.claude/rules/common/language-preferences.md`** (new) — the
  directive prose. English-only. Frontmatter matches the existing
  schema. Body is **conditional** on a marker in the session's
  additional-context payload; this is a new pattern that the rule
  documents in its own `## How to apply`.
- **`.claude/hooks/session-start.sh`** (minor edit) — add ~10 lines
  between the digest-build and the JSON-emit steps: read
  `.spec-workflow/config.yml` via `awk`, validate value, append
  `LANG_CHAT=<value>` line to the digest when recognised. Error
  paths degrade to default-off + stderr warning.
- **`bin/specflow-lint`** (new) — single-subcommand CLI:
  `scan-staged` (default when invoked by pre-commit) and
  `scan-paths <path>...` (invokable ad-hoc). Bash 3.2 + Python 3
  for the codepoint scan (Python 3 is an install-path dependency
  already per `bin/specflow-install-hook`; reusing is free).
- **`.git/hooks/pre-commit`** (installed per-consumer) — 2-line
  shim that execs `bin/specflow-lint scan-staged`. Installed by
  a new wire-up step in `specflow-seed init` and `specflow-seed
  migrate`, using the same "classify target state before mutation"
  discipline as existing hook wiring.
- **`.claude/rules/index.md`** (one-row addition) — per the
  scope-extension memory; no scope taxonomy change.

---

## 3. Technology Decisions

### D1. Config file location — `.spec-workflow/config.yml` (specflow-native, local-only by default)

- **Options considered**:
  - A. `.spec-workflow/config.yml` (new file, specflow-native, YAML).
  - B. `.claude/settings.json` (existing file, Claude-harness-native, JSON).
  - C. Environment variable (`SPECFLOW_LANG_CHAT=zh-TW`).
- **Chosen**: **A — `.spec-workflow/config.yml`**, local-only by default
  (documented in README but not added to `.gitignore` by the installer;
  users who wish to share the setting across contributors can commit it
  deliberately).
- **Why**:
  - **Specflow owns the key.** The schema is specflow's, the read path
    is specflow's, the directive is specflow's. Putting it in
    `.claude/settings.json` (option B) mixes specflow concerns into the
    Claude Code harness's own config file, which Anthropic owns and may
    change schema on. A future harness schema change could collide with
    our `lang.chat` key silently.
  - **Per-project isolation** (PRD default-off for multi-contributor
    repos, Scenario B + Scenario D). Option C (env var) is rejected by
    the brainstorm: env vars don't travel with the repo and break the
    per-project isolation model the per-project-install feature
    established.
  - **YAML read is trivial under bash 3.2.** A single `awk` one-liner
    handles `lang:` block → `  chat:` field extraction without `jq`,
    without Python at hook-runtime, without any multi-line parser. See
    Data flow Scenario A step 4.
  - **Forward-compat for future keys.** A top-level `.spec-workflow/
    config.yml` is a natural home for any future user-owned specflow
    knob (e.g., `verbose:`, `default-branch:`). Starting it here avoids
    a later rename.
  - **Matches the `20260418-per-project-install` precedent.** That
    feature deliberately keeps specflow concerns inside `.spec-workflow/`
    and `.claude/rules/`, `.claude/agents/specflow/`, etc. — never
    mixed into the harness's own `settings.json` body. This decision
    carries the same bias forward.
- **Tradeoffs accepted**:
  - A **new file** at a new top-level path in `.spec-workflow/`.
    Mitigation: it's optional (absent = default-off), so existing
    consumers see no diff.
  - **Local-only by default** means the setting doesn't automatically
    replicate when the user clones the repo to a second machine. The
    user re-authors the two-line YAML on the new machine. Acceptable;
    a personal language preference is naturally per-machine, and the
    PRD's Scenario D explicitly wants default-off for contributors who
    haven't opted in.
  - YAML parsing without `jq`/Python at hook-runtime is less robust
    than a full parser. Mitigation: accept only `lang:` block +
    `  chat: <token>` as the v1 schema (documented in R7 AC7.a/b);
    any other shape classifies unknown and falls back to default-off
    with a warning.
- **Reversibility**: medium — switching to `.claude/settings.json`
  later is a localized hook edit + README nudge; users re-author two
  lines in the new location.
- **Requirement link**: PRD §6 open-decision #1; R1 (single config
  key); R7 (graceful degradation); R8 (discoverability — one
  canonical doc location).

### D2. Guardrail surface — git pre-commit hook invoking `bin/specflow-lint`

- **Options considered**:
  - A. Git pre-commit hook (repo-local, bypassable via `--no-verify`,
    fires on every `git commit` regardless of origin).
  - B. Claude Code Stop hook lint step (specflow-owned, only fires
    inside Claude Code sessions, misses commits from outside Claude
    Code).
  - C. `specflow lint` CLI invoked by CI only (server-side, highest
    latency, unbypassable at push time).
  - D. Hybrid A + C (pre-commit local, same script as CI net).
- **Chosen**: **A — git pre-commit hook**, with the same
  `bin/specflow-lint` script invokable manually for ad-hoc scans (and
  by CI in a future extension — D20 trigger).
- **Why**:
  - **Fires on every commit path**, including commits Carol makes from
    a plain shell outside Claude Code. Option B (Stop hook) misses
    those entirely — a zh-TW leak that lands via `git commit` in a
    terminal would never trigger a Stop hook check.
  - **Leak latency is the single commit boundary**, not the push
    boundary. Option C alone waits until the user pushes, which can
    be days after the leak; by then, the user may have reshaped the
    branch and won't remember which file drifted.
  - **Bypass is explicit and conventional**: `git commit --no-verify`
    is a well-known git escape hatch. The bypass is trace-required
    (D8 below) so audit remains clean.
  - **Dogfood paradox coverage**: pre-commit hooks are installed by a
    step in `specflow-seed init` / `migrate` and persist through the
    session lifecycle — they don't depend on a newly-shipped hook
    mechanism activating mid-session. This improves structural
    verification (the hook can be invoked directly via a synthetic
    `git commit` in the smoke harness) and reduces what the manual
    post-archive smoke must cover.
  - **Hybrid (D)** is the right shape for the future; but CI is not
    in scope for v1 (no CI config in this repo today). Starting with
    just the pre-commit hook is the minimal shape; CI can reuse the
    same `bin/specflow-lint scan-staged` script later without code
    change.
- **Tradeoffs accepted**:
  - **`git commit --no-verify` is a globally-disabling bypass**, not
    surgical. Mitigation: the lint script itself is re-invokable ad
    hoc; a contributor who needs to commit a legitimate CJK fragment
    can use the more surgical allowlist (D6) rather than
    `--no-verify`. And D8 below makes bypass invocations
    trace-required.
  - **The hook must be installed on every consumer**. Mitigation:
    `specflow-seed init` / `migrate` install it idempotently (D3 below);
    existing consumers pick it up on their next `update` if we extend
    the managed subtree list (out of scope for this feature — see
    "Non-decisions D15").
  - **Commits made via GitHub PR merge UI** bypass pre-commit hooks
    entirely. Acceptable for v1; a CI lint would be the backstop for
    that path (Non-decisions D16).
- **Reversibility**: high — swap to or add the Stop-hook / CI variant
  later; the `bin/specflow-lint` script is the single source of truth
  for the scan logic regardless of invocation surface.
- **Requirement link**: PRD §6 open-decision #2; R5 (all ACs).

### D3. Guardrail install — one-line pre-commit shim wired by `specflow-seed init/migrate`

- **Options considered**:
  - A. `specflow-seed init` / `migrate` write a literal
    `.git/hooks/pre-commit` shim (two lines: `#!/usr/bin/env bash` +
    `exec bin/specflow-lint scan-staged "$@"`) at install time.
  - B. Instruct users to set `core.hooksPath` to a
    specflow-controlled directory and copy a versioned shim there.
  - C. Use `husky` or `lefthook` or similar Node-based hook manager.
- **Chosen**: **A — one-liner pre-commit shim written by
  `specflow-seed`** during `init` / `migrate`. Classify-before-mutate
  discipline applies: if `.git/hooks/pre-commit` already exists and
  does NOT contain the specflow-lint sentinel (a specific comment
  string), the installer **skips and reports** rather than clobbering
  — matches the existing `common/no-force-on-user-paths.md` rule.
- **Why**:
  - **No new dependency**. Bash, Python 3 (already required), and
    git are the floor.
  - **Idempotent**: on re-install, the installer detects the
    specflow-lint sentinel and reports `already`. On `migrate` into a
    consumer with an existing unrelated pre-commit, the installer
    reports `skipped:foreign-pre-commit` and exit non-zero (same
    report pattern as other `skipped:*` outcomes in
    `bin/specflow-seed`), guiding the user to either rename or
    include the specflow shim manually.
  - **Option B (`core.hooksPath`)** is cleaner conceptually but
    hijacks a global git config surface that many projects already
    use for their own purposes. Higher blast radius.
  - **Option C (husky/lefthook)** adds a Node or Go dependency
    entirely out of scope for this repo (pure bash + Python 3
    floor).
- **Tradeoffs accepted**:
  - **`.git/hooks/pre-commit` is not normally tracked in git**, so
    the shim must be reinstalled on every fresh clone. Mitigation:
    `specflow-seed init` and `migrate` both install it; fresh clones
    in an already-initialised consumer will need a new
    `specflow-seed init-hooks` subcommand (out of scope here, flagged
    in Non-decisions D14 below) or a one-line command in the README.
    For this feature's scope, the primary install path is `init` /
    `migrate`, which matches the PRD's "opt-in, default-off" posture
    on the rule side.
  - **Classify-before-mutate state list** for the pre-commit hook
    adds one new state to the installer: `foreign-pre-commit` (file
    exists but lacks our sentinel). That's a scope extension on
    `specflow-seed`'s classifier — one-line diff per the
    scope-extension-minimal-diff memory, no re-taxonomy.
- **Reversibility**: high — the sentinel comment makes uninstall
  trivial.
- **Requirement link**: R5 AC5.d (bypass is explicit, not
  accidental); memory `no-force-by-default.md` +
  `classification-before-mutation.md`.

### D4. Rule file — `.claude/rules/common/language-preferences.md`, severity `should`

- **Options considered**:
  - A. Place under `common/`, severity `must`.
  - B. Place under `common/`, severity `should`.
  - C. Create a new `language/` scope subdir.
  - D. Inline in the SessionStart hook's additional-context payload
    (no rule file).
- **Chosen**: **B — `.claude/rules/common/language-preferences.md`
  with `severity: should`**. Filename stem matches frontmatter
  `name: language-preferences`. Scope `common` (session-wide, loaded
  unconditionally per D7). Conditional body activates only when
  `LANG_CHAT=zh-TW` appears in the additional-context payload
  (per D5 + D7).
- **Why**:
  - **`common` is the correct scope**: the rule must fire in every
    session regardless of which filetype the user is editing (the
    language preference applies to PRD authoring, code reviews,
    brainstorms — everything). The lang-heuristic subdirs (`bash`,
    `markdown`, `git`) would scope the rule to only specific file
    contexts; wrong axis.
  - **No new scope subdir** (rejects option C). Per the
    scope-extension-minimal-diff memory: adding a new enum value for
    one new rule is over-engineering; `common` + name-based
    discoverability is sufficient.
  - **`severity: should`** (not `must`) matches the actual semantic:
    the rule deviates from today's English-everywhere default only
    when the user explicitly opts in. A `must` severity would imply
    the rule is unconditionally binding, which is wrong — it is
    conditional by design. `should` also signals to agents that
    deviation is tolerable (e.g., a subagent that doesn't know zh-TW
    can still proceed in English without a blocker).
  - **Inline in hook output (option D)** loses the rules-tree
    discoverability surface; violates the "rule files are the source
    of truth" invariant the prompt-rules-surgery feature
    established.
- **Tradeoffs accepted**:
  - **New conditional-body pattern** in a tree of unconditional
    rules. The brainstorm and PRD (AC2.b) both call this out; the
    rule's own `## How to apply` body documents the pattern in prose
    so future rule authors don't mistake it for a template.
  - The `session-start.sh` classifier treats this rule as valid
    frontmatter (five keys present, well-formed); no classifier
    change needed.
- **Reversibility**: high — severity or scope can be changed later
  with a one-line frontmatter edit.
- **Requirement link**: R2 (all ACs), R4 (session-wide inheritance
  via digest), AC2.b (conditional pattern documented).

### D5. How the rule reads config — hook-injected marker, rule body consults it by name

- **Options considered**:
  - A. Rule file statically contains the directive prose; the hook
    appends a separate `LANG_CHAT=<value>` marker line to the digest
    when config is set. Rule body says "if `LANG_CHAT=zh-TW` appears
    in the additional-context payload, …"
  - B. Rule file contains a placeholder token (e.g. `{{LANG_CHAT}}`);
    hook preprocesses the rule body and substitutes the value before
    emitting.
  - C. Rule body unconditionally instructs the agent to check
    `.spec-workflow/config.yml` at every reply (agent reads the file
    at runtime).
  - D. Hook decides whether to *include* the rule file in the digest
    at all (conditional load-time filter).
- **Chosen**: **A — hook appends a `LANG_CHAT=<value>` marker line
  when config is set; rule body unconditionally says "when
  `LANG_CHAT=zh-TW` is present in the additional-context payload,
  reply in zh-TW; otherwise, English."** The rule file is the single
  source of truth for the prose. The hook's only language-specific
  responsibility is appending the marker line.
- **Why**:
  - **Separation of concerns**. The rule file is plain English prose;
    the hook does a minimal YAML sniff and emits a flat marker. No
    templating engine, no substitution logic, no test surface for
    interpolation bugs.
  - **PRD AC2.d**: "the existing SessionStart rules digest emits the
    rule's body in every session regardless of config state; the
    conditional activation is entirely inside the rule body, not at
    the hook's load-time filter." Option D violates this directly.
  - **Option B (templating)** introduces a new preprocessing step in
    the hook that would need its own test matrix (empty template,
    unknown token, nested tokens). Marker-plus-conditional-prose
    avoids that surface entirely.
  - **Option C (agent reads the file at runtime)** is non-deterministic
    (relies on agents remembering to read) and defeats the
    SessionStart-hook design the rest of the system follows. Also
    slower: every reply would trigger a file read.
  - **Hook fail-safe discipline preserved**: if config-read fails
    (missing file, bad YAML, unknown value), the hook just doesn't
    append the marker line. Rule body's conditional then collapses
    to "otherwise, English" — default-off (R7 AC7.c).
- **Tradeoffs accepted**:
  - **The marker line and the rule body are loosely coupled** — the
    rule body must reference the exact marker string
    (`LANG_CHAT=zh-TW`) the hook emits. A drift between the two
    would silently break the feature. Mitigation: a smoke test
    (t52+) grep-verifies the exact string in both files.
  - **The marker occupies a line of the digest payload**. Adds one
    line to the additional-context, ~20 bytes. Negligible.
- **Reversibility**: medium — moving to a templating model later is
  possible but not trivial; stay with marker-plus-conditional unless
  a second conditional rule emerges.
- **Requirement link**: R1 AC1.b (marker emitted when set), R2
  AC2.d (rule loaded unconditionally), R7 AC7.\* (graceful
  degradation).

### D6. CJK-detection pattern — Unicode block scan via Python 3, closed classifier enum

- **Options considered**:
  - A. Grep with a Unicode range regex at the bash layer.
  - B. Python 3 one-shot script that reads each staged path's content
    and tests each code point for membership in a small set of
    CJK-related Unicode blocks.
  - C. `iconv` or `file` heuristics.
- **Chosen**: **B — Python 3 scanner**. One invocation per
  `scan-staged` run (not per file) — read the full path list from
  stdin, emit one line per finding. Classifier emits one of `ok` /
  `cjk-hit:<file>:<line>:<codepoint>` / `allowlisted:<file>:<reason>`
  / `binary-skip:<file>` per input path.
- **Why**:
  - **Deterministic range test**. Python's string is code-point
    iterable; testing `if 0x3400 <= ord(c) <= 0x9FFF` is exact and
    fast.
  - **Bash grep with Unicode ranges is fragile**: BSD grep
    (`/usr/bin/grep` on macOS) lacks `-P`, GNU-only; `pcregrep` is
    not installed by default. A Python one-shot is more portable than
    shell regex acrobatics.
  - **Python 3 is already a floor dependency** (`bin/specflow-install-hook`).
    No new install surface.
  - **Single-invocation efficiency**: the scanner is invoked once per
    `git commit`, reads all staged paths into one Python process,
    and exits with aggregate status. Matches the reviewer/performance
    rule's "no shell-out in tight loops" guidance.
- **Scanned Unicode ranges (v1)**:
  - **U+3400–U+4DBF** CJK Unified Ideographs Extension A
  - **U+4E00–U+9FFF** CJK Unified Ideographs (the main block)
  - **U+3000–U+303F** CJK Symbols and Punctuation (punctuation-only;
    see allowlist below)
  - **U+3040–U+309F** Hiragana (forward-compat, catches ja leaks)
  - **U+30A0–U+30FF** Katakana (forward-compat)
  - **U+AC00–U+D7AF** Hangul Syllables (forward-compat)
  - **U+F900–U+FAFF** CJK Compatibility Ideographs
  - **U+FF00–U+FFEF** Halfwidth and Fullwidth Forms
- **In-scope paths**:
  - `.spec-workflow/features/**` (all, **except** the
    `00-request.md` files' bounded request-quote pattern — see
    allowlist).
  - `.claude/**` (agents, rules, commands, hooks, team-memory,
    skills).
  - `bin/**`
  - `test/**` (except explicitly-marked CJK fixtures — see
    allowlist).
  - `*.md` at the repo root.
  - `COMMIT_EDITMSG` body (if the hook is ever extended to
    `commit-msg`; v1 scans staged files only, commit message
    scanning is a Non-decision — see D12).
- **Out-of-scope paths** (not scanned at all):
  - `.spec-workflow/archive/**` — PRD Non-goals explicitly excludes
    archive.
  - `.git/**`
  - `node_modules/**`, any binary file (`file` or extension-based
    probe) — `binary-skip` classification.
- **Allowlist mechanism** (two surfaces, both greppable):
  - **Path pattern allowlist** at the top of
    `bin/specflow-lint` (Python dict):
    `.spec-workflow/features/**/00-request.md` — but only within a
    block bounded by the markers the request-quote convention uses
    (a literal `**Raw ask**:` prefix line). Lines between the first
    `**Raw ask**:` line and the following blank line are permitted
    CJK. Every other line in that file is scanned.
  - **Inline marker allowlist**: any file containing a
    `<!-- specflow-lint: allow-cjk reason="..." -->` HTML comment
    (on its own line) suppresses CJK scanning for that file entirely.
    Used for test fixtures (e.g., `test/fixtures/*.md` that carry
    deliberate CJK for the guardrail's own smoke test). The reason
    is mandatory and grep-verifiable; accidental use is
    distinguishable from intentional.
- **Classifier output contract**:
  ```
  ok:<path>
  cjk-hit:<path>:<line>:<col>:U+<hex>
  allowlisted:<path>:<reason>
  binary-skip:<path>
  ```
  Final exit code: 0 if every path is `ok`, `allowlisted`, or
  `binary-skip`; 1 if any `cjk-hit`. No mutation anywhere in the
  script; the classifier is pure.
- **Tradeoffs accepted**:
  - **Halfwidth and Fullwidth Forms (U+FF00–U+FFEF)** include
    fullwidth ASCII variants that are legitimate in mathematical or
    typographic contexts. Mitigation: they're rare enough in this
    repo (zero hits today) to treat as suspicious-by-default; a
    legitimate case uses the inline marker.
  - **False positive on curly quotes (U+2018, U+2019, U+201C,
    U+201D)** — deliberately NOT scanned (they're in
    General Punctuation, not CJK). Em-dash U+2014 also out of
    scope. Keeps the classifier's "CJK-only" contract honest.
  - **Hiragana/Katakana/Hangul scanning** is forward-compat for ja,
    ko leaks; v1 only documents zh-TW as the supported language, but
    the scanner treats any CJK-family block as a finding. If a user
    adds ja support later (explicit Non-goal today), the scanner
    already catches ja leaks.
- **Reversibility**: high — ranges and allowlists are all
  declarative at the top of the script.
- **Requirement link**: R5 (all ACs), R6 AC6.b (carve-outs
  enumerated).

### D7. SessionStart hook changes — single `awk` sniff, marker-emit, fail-safe preserved

- **Options considered**:
  - A. Add a new hook surface (e.g., a separate
    `.claude/hooks/read-config.sh` that emits only the marker).
  - B. Extend `.claude/hooks/session-start.sh` with ~10 lines of
    config-read + marker-append.
  - C. Don't edit the hook at all; put the conditional read entirely
    in the rule body (agent reads file at session start).
- **Chosen**: **B — minimal edit to
  `.claude/hooks/session-start.sh`**. Diff shape (not the actual
  diff):
  1. After the `digest` variable is built but before JSON-escape,
     add a block that runs an `awk` sniff on
     `.spec-workflow/config.yml`.
  2. If the sniff produces a recognised value, append a newline +
     `LANG_CHAT=<value>` to `digest`.
  3. If the sniff produces an unrecognised value OR the file is
     malformed, emit one warning to stderr and skip the append.
  4. Missing file → silent skip (R7 AC7.c).
- **Why**:
  - **Reuses the existing hook's JSON-emit path**. No new hook file,
    no new Claude Code settings.json entry, no new test for
    second-hook-interaction.
  - **Fail-safe discipline is already in place** (`set +e`,
    `trap 'exit 0' ERR INT TERM`). The new config-read lines
    inherit this.
  - **Option A (separate hook)** doubles the hook install surface
    and gives Claude Code two payloads to reconcile on session
    start — more complexity for zero benefit.
  - **Option C (in-rule runtime read)** was rejected in D5.
- **Minimal diff sketch** (not the actual implementation; informs
  TPM):
  ```
  # ... existing digest assembly ...

  # New: read lang.chat from config, append marker line if set
  cfg_file=".spec-workflow/config.yml"
  if [ -r "$cfg_file" ]; then
    cfg_chat=$(awk '
      /^lang:/        {in_lang=1; next}
      in_lang && /^  chat:/ {
        sub(/^  chat:[[:space:]]*/, "")
        gsub(/"/, ""); gsub(/#.*$/, "")
        gsub(/[[:space:]]+$/, "")
        print; exit
      }
      /^[^ ]/         {in_lang=0}
    ' "$cfg_file" 2>/dev/null)

    case "$cfg_chat" in
      zh-TW|en)
        if [ -n "$digest" ]; then
          digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
        else
          digest="LANG_CHAT=$cfg_chat"
        fi
        ;;
      "")
        # Empty / absent key — default-off, no warning
        :
        ;;
      *)
        log_warn "config.yml: lang.chat has unknown value '$cfg_chat' — ignored"
        ;;
    esac
  fi

  # ... existing JSON-emit ...
  ```
  The block is ~20 lines, bash 3.2 safe (no `[[ =~ ]]`, no
  `readlink -f`, no `jq`, `case`-based state machine).
- **Tradeoffs accepted**:
  - **`awk` YAML sniff is narrow**: it matches only the exact
    shape `lang:\n  chat: <value>`. Anything else (different
    indentation, `lang.chat: <value>` flat-scalar form, comments on
    the same line as the key) is classified as unknown and
    default-off. Documented in the README's language-preferences
    section.
  - **One `awk` invocation per session start** (< 5 ms on a warm
    cache). Well under the reviewer/performance 200 ms hook budget.
- **Reversibility**: high — the block is localized; reverting is a
  git revert of one commit.
- **Requirement link**: R1 AC1.a, AC1.b; R7 AC7.a, AC7.b, AC7.c.

### D8. Bypass and opt-out semantics — `git commit --no-verify` + inline allowlist marker; STATUS trace on use

- **Options considered**:
  - A. Rely solely on `git commit --no-verify` (git's native escape
    hatch, globally-disabling).
  - B. Add a `SPECFLOW_LINT_ALLOW=1` env var that the pre-commit
    shim checks before running `bin/specflow-lint`.
  - C. Add a per-path inline marker that allowlists one file
    (D6 mechanism).
  - D. Combine all three.
- **Chosen**: **A + C — `--no-verify` for emergency (globally
  disables all pre-commit hooks) AND the inline allowlist marker
  from D6 for surgical per-file exemption**. No env var bypass
  (rejects B).
- **Why**:
  - **Surgical is better than global**. When a contributor
    legitimately needs a zh-TW fragment in a single file (test
    fixture, archived quote), the inline marker (D6) is the
    right tool — it documents the exception in-line, grep-findable,
    reason-required.
  - **`--no-verify`** remains as git's native emergency escape, for
    cases where the entire lint surface is broken (the script is
    crashing) and the user needs to commit-first-debug-later.
  - **Env var (option B)** is the worst bypass because it silently
    affects every future invocation until unset — the accidental
    persistence pattern the opt-out-bypass-trace memory warns
    against.
- **STATUS trace requirement**: per the
  `shared/opt-out-bypass-trace-required.md` memory, a contributor
  using `--no-verify` during feature work should append a STATUS
  Notes line:
  `- YYYY-MM-DD <contributor> — --no-verify USED on commit <sha>
  (reason: <text>)`.
  The orchestrator or user is responsible for the trace; the lint
  script cannot enforce this because `--no-verify` skips the hook
  entirely. README documents this convention.
- **The inline allowlist marker** (D6) also leaves a trail
  automatically: the `<!-- specflow-lint: allow-cjk reason="..." -->`
  comment is grep-findable in the file itself. A later audit can
  scan for every allowlist marker and cross-reference the claimed
  reason against the file's content.
- **Tradeoffs accepted**:
  - **`--no-verify` trace is human-discipline**, not
    machine-enforced. Consistent with the memory's "STATUS entry is
    the audit trail" pattern; same posture as the
    `--skip-inline-review` flag.
  - **Inline allowlist marker relies on the contributor not
    abusing it**. Mitigation: periodic audits (`grep -rn
    "specflow-lint: allow-cjk"` across repo) and the required
    `reason=` field surface abuse quickly.
- **Reversibility**: high — the allowlist marker's form can change
  without breaking the scanner (scanner reads whatever shape is
  declared at its top).
- **Requirement link**: R5 AC5.c (allowlist scope), AC5.d (bypass
  explicit), memory `opt-out-bypass-trace-required.md`.

### D9. Config schema shape — minimal nested YAML (`lang.chat: zh-TW`), no `artifacts` key

- **Options considered**:
  - A. Flat scalar: `lang-chat: zh-TW` at top level.
  - B. One-level nested: `lang:\n  chat: zh-TW`.
  - C. Two-axis nested: `lang:\n  chat: zh-TW\n  artifacts: en`.
  - D. Dotted flat key: `lang.chat: zh-TW` (YAML-legal but reads as
    a single key string).
- **Chosen**: **B — one-level nested, `lang:` block with `chat:`
  field**. The `artifacts` key is explicitly NOT added; artifact
  language is fixed at `en` as an invariant and documented as such
  in the rule file's prose.
- **Why**:
  - **Matches PM's lean and brainstorm recommendation**: minimal
    nested for future extensibility (a future `lang.default:` or
    second key falls under the same parent) without leaking
    aspirational structure (no unused sibling keys).
  - **Respects the PRD's "no general i18n framework" non-goal**:
    `artifacts:` is not configurable, so it's not in the schema.
    If v2 ever opens artifact localisation (a huge scope expansion
    per the Non-goals), the schema extends by appending one key —
    scope-extension-minimal-diff pattern.
  - **Flat scalar (A) or dotted key (D)** read as ad-hoc when a
    second related key lands later. Nested is the idiomatic YAML
    shape for a namespaced group.
  - **Two-axis (C)** overspecifies: the `artifacts: en` value would
    mislead users into thinking they can change it. Non-goal says
    they can't.
- **Exact v1 schema**:
  ```yaml
  # .spec-workflow/config.yml
  lang:
    chat: zh-TW    # or "en" (explicit default) — any other value → warning + default-off
  ```
- **Tradeoffs accepted**:
  - **`awk` YAML parser is narrower than a general YAML library**
    (see D7 tradeoffs). The documented v1 schema shape is all the
    parser supports.
  - **A future `lang.default` key** (e.g., for fallback language
    when a subagent lacks context in the primary language) would
    require a second `awk` rule in the hook — one-line addition,
    not a schema rewrite.
- **Reversibility**: high — any schema change is accompanied by a
  `session-start.sh` parser extension. Malformed configs fall back
  to default-off per R7.
- **Requirement link**: PRD §6 open-decision #3; R1 (single config
  key); Non-goals (no general i18n framework).

---

## 4. Cross-cutting Concerns

### Error handling strategy

- **Hook side (SessionStart)**: strict fail-safe per
  `hook-fail-safe-pattern.md`. All config-read paths degrade to
  default-off on any failure; warnings go to stderr; exit is always
  0. The hook never blocks session start regardless of config
  state.
- **Lint side (`bin/specflow-lint`)**: `set -u -o pipefail`, no
  `-e` (accumulate findings across files). Exit codes:
  - `0` — every scanned path classified `ok`, `allowlisted`, or
    `binary-skip`.
  - `1` — one or more `cjk-hit` findings; report printed to stderr.
  - `2` — usage error, Python 3 missing, or internal error (e.g.,
    the script itself was tampered with and self-check fails).
- **Pre-commit shim**: two-line bash, execs `bin/specflow-lint
  scan-staged`; propagates exit code. If `bin/specflow-lint` is
  missing (user moved/renamed it without updating the shim), the
  shim exits 2 with a pointer to the `specflow-seed init` command.

### Logging / tracing / metrics

- **Hook stdout**: JSON payload only (as today); marker line
  appears inside the `additionalContext` string when config is set.
- **Hook stderr**: one warning line per config-read issue (unknown
  value, malformed YAML). Matches the existing stop/start hooks'
  `log_warn` convention.
- **Lint stdout**: one line per scanned path (`ok:<path>`,
  `cjk-hit:<path>:<line>:<col>:U+<hex>`, `allowlisted:<path>:…`,
  `binary-skip:<path>`). Parseable by CI or audit scripts.
- **Lint stderr**: only the summary / error messages (e.g., "2
  cjk-hit findings", "Python 3 required").
- **No metrics, no log file**. Matches repo precedent.

### Security / authn / authz posture

- **No secrets involved.** Config file has one string value; no
  auth token, no credential.
- **Path confinement**:
  - SessionStart hook reads only `.spec-workflow/config.yml` from
    its own cwd; never writes anywhere.
  - `bin/specflow-lint` reads staged content via `git show :FILE`
    (git-internal, respects git's path resolution) and writes
    nothing; pure classifier + report.
  - Pre-commit shim execs `bin/specflow-lint` only; no network, no
    file writes.
- **No `rm -rf`**, no `--force`, no mutation on user-owned paths
  beyond the one-time pre-commit shim install (D3, classify-
  before-mutate disciplined).
- **Injection surface**: zero — the only external-input handling is
  reading YAML (constrained-shape `awk` parse) and staged file
  content (treated as opaque bytes for codepoint scan).
- **Path traversal**: `bin/specflow-lint` receives paths from
  `git diff --cached --name-only`, which are always inside the
  repo root by construction. No user-supplied path joining.

### Testing strategy (feeds Developer's TDD)

| Test | Level | What it asserts | Maps to AC |
|---|---|---|---|
| `t51_rule_file_shape.sh` | static | `.claude/rules/common/language-preferences.md` exists, frontmatter has all five keys, body is English-only (lint-verified), `## How to apply` documents the conditional pattern. | AC2.a, AC2.b |
| `t52_rule_index_row.sh` | static | `.claude/rules/index.md` contains a row for `language-preferences` with scope `common` and severity `should`, sorted alphabetically. | AC2.c |
| `t53_marker_rule_coupling.sh` | static | `grep -F 'LANG_CHAT=zh-TW'` finds exactly (a) the hook script, (b) the rule body. No drift. | D5 tradeoff |
| `t54_hook_config_absent.sh` | integration | Sandbox consumer with no `.spec-workflow/config.yml`; run `.claude/hooks/session-start.sh` under `HOOK_TEST=1`; assert digest contains NO `LANG_CHAT=` line, stderr is clean. | AC1.a, AC7.c |
| `t55_hook_config_zh_tw.sh` | integration | Sandbox with `lang.chat: zh-TW`; hook emits `LANG_CHAT=zh-TW` marker; stderr clean. | AC1.b |
| `t56_hook_config_unknown.sh` | integration | Sandbox with `lang.chat: fr`; hook emits NO marker + exactly one warning line on stderr; exit 0. | AC7.a |
| `t57_hook_config_malformed.sh` | integration | Sandbox with syntactically broken config; hook emits no marker + one warning; exit 0. Hook fail-safe discipline held. | AC7.b |
| `t58_lint_clean_diff.sh` | integration | Sandbox git repo; stage a set of ASCII-only files across `.claude/**`, `.spec-workflow/features/**`, `bin/**`; run `bin/specflow-lint scan-staged`; exit 0, no findings. | AC5.b |
| `t59_lint_cjk_hit.sh` | integration | Sandbox with one staged `.md` file containing a zh-TW sentence; lint exits 1 with `cjk-hit:<file>:<line>:<col>:U+<hex>` on stdout and a human-readable summary on stderr. | AC5.a |
| `t60_lint_request_quote_allowlist.sh` | integration | Stage a `00-request.md` containing zh-TW only inside the `**Raw ask**:` block; lint exits 0, emits `allowlisted:…:request-quote`. Move the zh-TW outside the block → exit 1. | AC5.c |
| `t61_lint_inline_marker_allowlist.sh` | integration | Stage a test fixture carrying `<!-- specflow-lint: allow-cjk reason="fixture" -->`; lint exits 0, emits `allowlisted:…:inline-marker`. Remove the marker → exit 1. | AC5.c |
| `t62_lint_archive_ignored.sh` | integration | Stage a file with zh-TW at `.spec-workflow/archive/.../foo.md`; lint ignores (not in scope); exit 0 with `binary-skip:` or omits the path entirely. | R5 Non-goals, AC5.c |
| `t63_lint_no_jq_no_readlink_f.sh` | static | `grep -Fn 'jq\|readlink -f\|realpath\|mapfile'` over `bin/specflow-lint` and the hook edit returns empty. | bash-32-portability rule |
| `t64_precommit_shim_wiring.sh` | integration | Sandbox consumer; run `specflow-seed init` (extended per D3); `.git/hooks/pre-commit` exists, contains the specflow-lint sentinel, is executable; staging a CJK file and committing gets rejected. | R5 AC5.d, D3 |
| `t65_subagent_diff_empty.sh` | static | `git diff --stat` at the feature's final commit shows zero lines changed under `.claude/agents/specflow/`. | AC4.a |
| `t66_readme_doc_section.sh` | static | `README.md` contains a "Language preferences" section with the key name and the example value `zh-TW`. `grep -l 'lang.chat\|lang:\n  chat'` finds exactly README.md and the rule file. | AC8.a, AC8.b |

Every integration test uses the `mktemp -d` sandbox + `$HOME`
preflight per `bash/sandbox-home-in-tests.md`.

### Performance / scale targets

- **SessionStart hook** with the new config read: soft target <150
  ms total (budget 200 ms per
  `.claude/rules/reviewer/performance.md`). The `awk` sniff is
  single-file, single-pass; negligible.
- **`bin/specflow-lint scan-staged`** on a typical commit (10–30
  staged files): <300 ms. Python 3 start-up is the dominant cost
  (~50 ms); per-file codepoint scan is negligible. No AC specifies
  a budget; this is a soft target.
- **No runtime perf impact on Claude Code sessions** — the rule
  itself is already part of the digest payload whether or not the
  feature is activated; the marker line adds ~20 bytes.

---

## 5. Open Questions

**None blocking — proceed to `/specflow:plan`.**

No notes or downstream flags to PM either. PRD §6 open decisions are
all resolved (D1 = `.spec-workflow/config.yml`; D2 = git pre-commit
hook; D9 = minimal nested). PRD R5 AC5.d's "accidental bypass not
possible on the chosen surface" is satisfied by D2 + D3 + D8: the
pre-commit hook fires on every `git commit` by default; bypass
requires the explicit `--no-verify` flag or an inline allowlist
marker with a reason.

---

## 6. Non-decisions (deferred)

- **D10. CI-side lint** — a future GitHub Actions / CI job that
  runs `bin/specflow-lint` on the pushed tree as a backstop for
  PR-merge-UI commits that bypass local pre-commit hooks.
  **Trigger**: first observed CJK leak via a GitHub "merge commit"
  path.
- **D11. `specflow-seed init-hooks` subcommand** — a standalone
  entry point to re-install `.git/hooks/pre-commit` without running
  the full copy plan. Useful for fresh clones where `.git/hooks/`
  is empty but the rest of the managed tree is already in place.
  **Trigger**: user reports that fresh clones miss the guardrail.
- **D12. Commit-message scanning** (`commit-msg` hook) — scan
  `COMMIT_EDITMSG` for CJK before the commit is recorded. Today
  only staged content is scanned; a user could still type a zh-TW
  commit message. **Trigger**: first observed zh-TW in a commit
  message on this repo.
- **D13. `specflow config set / get`** — a CLI surface for authoring
  `.spec-workflow/config.yml` instead of requiring hand-edit.
  **Trigger**: user friction with YAML syntax; or a second config
  key lands and the hand-edit surface grows.
- **D14. Committing `.spec-workflow/config.yml` by default** —
  today's local-only model (D1) serves the multi-contributor
  default-off requirement. If teams later want a shared opted-in
  repo (the entire team works in zh-TW), they commit the config
  manually — same mechanism, different social convention. A
  later feature could add a `--share` flag that also writes a
  `.gitignore` rule-removal line. **Trigger**: team-level
  zh-TW adoption in a specific consumer.
- **D15. Extending the managed subtree list to include
  `.spec-workflow/config.yml`** — if a future version decides the
  config file should be a specflow-managed per-file (not
  user-authored), adding it to `bin/specflow-seed`'s plan is a
  one-line diff. **Trigger**: user feedback that the bootstrap
  user-experience is too manual.
- **D16. Forward-compat `lang.default` / `lang.fallback` keys** —
  see D9 tradeoffs. **Trigger**: request for per-reply-kind language
  (e.g., "reply in zh-TW but fall back to English when the subagent
  is uncertain").
- **D17. Second language support** (ja, ko, etc.) — PRD Non-goals
  forbids this in v1. Scanner already handles the Unicode blocks
  (D6 forward-compat). **Trigger**: explicit second-language
  request from user.

---

## 7. File-level impact map (feeds TPM's plan stage)

| File | Action | Purpose |
|---|---|---|
| `.claude/rules/common/language-preferences.md` | **CREATE** | The directive rule, English-only body, severity `should`, conditional on `LANG_CHAT=zh-TW` marker in additional-context. |
| `.claude/rules/index.md` | **EXTEND** | One new row for `language-preferences` in the `common` section, sorted alphabetically. |
| `.claude/hooks/session-start.sh` | **EXTEND** | ~20-line block: `awk` sniff `.spec-workflow/config.yml` for `lang.chat`; append `LANG_CHAT=<value>` marker to digest when recognised; warning-to-stderr on unknown values; silent on missing file. Fail-safe discipline preserved. |
| `bin/specflow-lint` | **CREATE** | Bash shim + Python 3 scanner. `scan-staged` (default) and `scan-paths <path>...` subcommands. Closed classifier enum (`ok` / `cjk-hit` / `allowlisted` / `binary-skip`); exit 0/1/2 per §4. |
| `.git/hooks/pre-commit` | **CREATE per consumer** | Two-line shim that execs `bin/specflow-lint scan-staged "$@"`. Installed by `specflow-seed init` and `specflow-seed migrate` (see next row). |
| `bin/specflow-seed` | **EXTEND** | (a) Add `foreign-pre-commit` state to pre-commit classifier (classify-before-mutate scope extension). (b) Add pre-commit shim install step to the dispatcher for `init` and `migrate`. (c) Update the summary line to reflect hook wiring. No change to the copy plan, manifest, or managed subtree list. |
| `test/smoke.sh` | **EXTEND** | Add tests `t51`–`t66` per §4. Existing `t1`–`t50` stay green. |
| `README.md` | **UPDATE** | New section "Language preferences" (post-Install, before "Recovery"): names the config file, the key, example values, example snippet, and pointer to the rule file. R8 AC8.a. |
| `.spec-workflow/config.yml` | **NOT SHIPPED** | User-authored, local-only. README instructs creation. Not in the managed subtree; `specflow-seed update` never touches it. |
| `.claude/agents/specflow/**` | **UNCHANGED** | Per R4 AC4.a; verified by t65. |

---

## 8. Acceptance checks the Architect stands behind

Developer must demonstrate:

1. **Rule file exists, English-only, conditional pattern documented**
   — `t51`, `t52`, `t53` green. Reviewer can grep the rule body for
   each of the six carve-outs (R3 AC3.a).
2. **SessionStart hook config-read is fail-safe** — `t54`–`t57`
   green. Missing file silent (AC7.c); unknown value +
   malformed config one-warning each (AC7.a, AC7.b); hook exits 0
   in every case.
3. **Marker emission is conditional and coupled to the rule** —
   `t55` + `t53` together prove the marker appears in the digest
   when and only when the config is recognised, and that the rule
   body references the exact same marker string.
4. **`bin/specflow-lint` classifies correctly** — `t58`–`t62`
   green. Clean diff passes silently; CJK hit rejects with
   file/line/codepoint; request-quote block and inline marker
   allowlists work; archive/ is out of scope.
5. **Pre-commit shim is installed and fires** — `t64` green.
   Re-running `init` is idempotent (shim already in place with
   specflow sentinel → `already`); a foreign pre-commit is
   `skipped:foreign-pre-commit` with exit non-zero.
6. **Zero agent diff** — `t65` green; also by inspection at final
   commit.
7. **README has exactly one canonical doc section** — `t66` green.
8. **All bash scripts and Python helpers pass `bash -n` / `python3
   -m py_compile`** and grep-clean against `readlink -f |
   realpath | jq | mapfile | \[\[ .*=~ | rm -rf | --force` in the
   new code.
9. **Dogfood paradox**: `08-verify.md` MUST annotate AC1.b, AC5.a,
   AC7.\* as "structural PASS; runtime verification deferred to
   next feature after session restart" per the shared memory. The
   user will perform a manual post-archive smoke by opening a
   fresh session in a consumer repo with `lang.chat: zh-TW` set
   and confirming at least one subagent reply is in zh-TW while a
   file-write (e.g., the brainstorm scratch file) remains English.

---

## Summary

- **D-count**: 9 primary decisions (D1–D9), 8 deferred (D10–D17).
- **§5 blockers**: **none** — all three PRD §6 open decisions (config
  location, guardrail surface, schema shape) resolved here; no
  PM-level questions outstanding.
- **§5 notes**: none.
- **Applied memory entries**: `hook-fail-safe-pattern`,
  `settings-json-safe-mutation`, `script-location-convention`,
  `shell-portability-readlink`, `classification-before-mutation`,
  `dogfood-paradox-third-occurrence`,
  `opt-out-bypass-trace-required`, `scope-extension-minimal-diff`.
- **One-phrase summaries**: **D1** config at
  `.spec-workflow/config.yml`, local-only by default.
  **D2** guardrail is a `bin/specflow-lint`-backed git pre-commit
  hook. **D9** schema is one-level nested `lang.chat` with no
  `artifacts` key.
