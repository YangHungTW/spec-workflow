# PRD — language-preferences

_2026-04-19 · PM_

## 1. Summary

A zh-TW native user drives the specflow pipeline every day and wants to
collaborate with the subagents in Chinese while keeping every committed
artefact — PRDs, plans, tasks, code, commit messages, `.claude/**`,
`.spec-workflow/features/**` — in English for PR-reviewability and
grep-ability. Today both halves are English-only; there is no knob. This
feature adds **one opt-in config key** that, when set, flips every specflow
subagent reply (and the top-level Claude Code session's final message) to
zh-TW while leaving file writes, CLI stdout, tool arguments, and commit
messages English. Default-off — a repo whose contributors have not opted in
sees today's behaviour exactly. A commit-time guardrail catches accidental
CJK leaks into committed content before they reach review.

## 2. Goals

- **One knob, seven agents.** A single config key controls chat language
  for all specflow subagents (PM, Architect, TPM, Developer, QA-analyst,
  QA-tester, Designer) and the top-level session; no per-agent edits
  required.
- **Opt-in, default-off.** Absent or unset config preserves today's
  English-only behaviour for every existing repo and every contributor who
  has not opted in.
- **Artifact English is an invariant.** Regardless of chat-language
  setting, every file written under `.spec-workflow/features/**`,
  `.claude/**`, source code, tests, tool arguments, and commit messages
  stays English.
- **Mechanical leak detection.** A commit-time guardrail rejects CJK
  content in committed artefacts so a prompt-level drift failure surfaces
  loudly at commit, not silently at review.
- **Reuse, not expansion.** Built on the existing SessionStart hook and
  `.claude/rules/` tree; no net-new session surface.

## 3. Non-goals

Pulled from `00-request.md` §Out of scope plus brainstorm resolutions:

- Translating or back-filling any existing artefact (PRDs, rules, memory,
  archive) into zh-TW.
- Localising specflow CLI stdout (`bin/specflow-*`), hook log lines, tool
  names (`Read`/`Write`/`Bash`/etc.), STATUS Notes entries, commit
  messages, error text, or any machine-parsed output — these stay English.
- A general i18n/locale framework. Two values only in v1: `zh-TW` for
  chat, `en` fixed for artefacts. Additional languages (ja, ko, etc.) are
  explicit future work with no forward-compat scaffolding.
- A per-agent toggle. The single knob is the product; seven toggles would
  be a regression.
- Env-var configuration. Rejected in brainstorm — env vars do not travel
  with the repo and break per-project isolation.
- Changing anything about how `.claude/rules/` loads. The SessionStart
  hook's rules-digest path is untouched except for reading one new config
  key.
- Changing what `.spec-workflow/archive/**` contains. The archive is
  out-of-scope for the guardrail; historical files with incidental
  non-ASCII stay as they are.

## 4. Requirements

Each R has one-line statement + 1–4 acceptance criteria. R-numbers are
stable; AC IDs scoped per R.

### Configuration

**R1 — A single opt-in config key controls chat language.** The feature
introduces exactly one user-visible configuration key whose value selects
the chat language. Default behaviour (key absent, file absent, or value
unset) is identical to today's English-only behaviour — no session-context
injection, no directive, no observable change. Setting the key to `zh-TW`
turns the feature on for that repo only. Config file location and exact
schema are deferred to tech (§6).

- **AC1.a (baseline).** With the config key absent (or the config file
  itself absent), a fresh session opened in the consumer repo produces
  subagent replies in English — identical to today's behaviour. Verify by
  comparing a synthetic session's first reply shape to the pre-feature
  baseline; no "reply in zh-TW" directive appears in the SessionStart
  additional-context payload.
- **AC1.b (opt-in).** With the config key set to `zh-TW`, a fresh session
  produces the SessionStart additional-context payload containing a
  `LANG_CHAT=zh-TW` line (or tech's chosen equivalent) and the rule from
  R2 becomes active. Structural verification only — runtime subagent
  behaviour is covered by R9's dogfood note.
- **AC1.c (opt-out is removal, not a flag).** Removing the config key or
  deleting the config file restores AC1.a's behaviour on the next session
  start; no residual state persists between sessions.

### Rule file

**R2 — A conditional rule file in `.claude/rules/common/` declares the
language split.** A new file `.claude/rules/common/language-preferences.md`
ships in the source repo and is seeded into every consumer at `init`
(per feature `20260418-per-project-install`). The rule file itself is
English-only. Its body is conditional: it instructs the agent that **if**
`LANG_CHAT` is set to `zh-TW` (via the SessionStart additional-context
payload or tech's chosen surface), replies to the user are in zh-TW; file
writes, tool arguments, commit messages, and CLI stdout are English. If
`LANG_CHAT` is absent, the rule is a no-op. The rule is loaded
unconditionally by the existing SessionStart digest; the conditional
activation happens inside the rule body, not at load time.

- **AC2.a (rule exists, English-only).** `.claude/rules/common/language-preferences.md`
  exists in the source repo with the frontmatter schema from
  `.claude/rules/README.md` (name, scope=common, severity, created,
  updated) and a body that contains only ASCII + standard Latin-1
  punctuation — no CJK codepoints — verifiable by the same guardrail R5
  ships.
- **AC2.b (conditional pattern documented).** The rule's `## How to apply`
  body explicitly documents the conditional shape — "when `LANG_CHAT` is
  set to `zh-TW`, …; otherwise this rule is a no-op" — so a future rule
  author does not mistake the conditional body for an unconditional
  template. This AC exists because the conditional shape is a new pattern
  in a tree of otherwise-unconditional rules.
- **AC2.c (index row).** `.claude/rules/index.md` contains a row for
  `language-preferences` in the `common` scope section, sorted
  alphabetically per the README's "sorted by scope then name" convention.
- **AC2.d (loads unconditionally).** The existing SessionStart rules
  digest emits the rule's body in every session regardless of config
  state; the conditional activation is entirely inside the rule body,
  not at the hook's load-time filter.

### Directive semantics

**R3 — The directive explicitly carves out file writes, tool arguments,
and commit messages.** The rule body states, in plain English, that when
activated: (a) replies to the user are in zh-TW; (b) every file written
via any tool (`Write`, `Edit`, `NotebookEdit`, etc.) has English content;
(c) every tool-call argument (paths, patterns, flags, commit messages,
branch names) is English; (d) CLI stdout emitted by any `bin/specflow-*`
script or hook script is English; (e) commit messages are English; (f)
STATUS Notes entries and any file under `.claude/team-memory/**` are
English. The directive is wording only — tech picks no structure for it
other than "English rule-body prose."

- **AC3.a (carve-outs enumerated).** The rule body enumerates the six
  carve-outs (a)–(f) above; a reviewer can point to each one verbatim in
  the file.
- **AC3.b (no reverse).** The rule body does not state the inverse
  ("write file content in zh-TW when …") under any condition. There is
  no language other than zh-TW for chat and no language other than
  English for artefacts in v1.

### Subagent coverage

**R4 — All seven specflow subagents honour the directive without
per-agent edits.** Because the rule loads via the session-wide
SessionStart digest, every subagent (PM, Architect, TPM, Developer,
QA-analyst, QA-tester, Designer) inherits the directive from the same
session context. The feature ships zero edits to any file under
`.claude/agents/specflow/`. A future eighth subagent would inherit the
directive for free.

- **AC4.a (no agent diff).** `git diff` on the feature's final commit
  shows zero modifications under `.claude/agents/specflow/`. The rule
  reaches the agents via session-context inheritance, not via
  per-agent prompt edits.
- **AC4.b (coverage enumerated).** The rule body or its `## How to
  apply` section names each of the seven subagent roles explicitly so a
  reader can verify by grep that every role is in scope.

### Commit-time guardrail

**R5 — A commit-time guardrail rejects CJK content in committed
artefacts.** The feature ships a mechanical check that scans committed
content for CJK codepoints and fails loudly when one is found outside a
bounded allowlist. The surface — git pre-commit hook, Stop hook lint
step, or a `specflow lint` command invoked by CI — is deferred to tech
(§6). On hit, the guardrail prints the offending file, line, and
codepoint range, and exits non-zero so the commit is rejected. Bypass is
explicit (the user's escape hatch, not a silent toggle).

- **AC5.a (rejection path).** A synthetic commit that introduces a CJK
  character into a path under `.spec-workflow/features/**`,
  `.claude/**`, or `bin/**`, or into the commit message body, is
  rejected by the guardrail with a non-zero exit and a human-readable
  report naming the file, line, and character. The offending commit
  does not land.
- **AC5.b (clean-diff passes).** A commit that touches only ASCII +
  standard Latin-1 punctuation files passes the guardrail with exit 0
  and no noise on stdout/stderr beyond a single-line "ok" or silent
  success. Verify on the feature's own commits.
- **AC5.c (allowlist scope).** The guardrail's allowlist covers at
  least: the raw zh-TW quote in `.spec-workflow/features/**/00-request.md`
  (the request-quote pattern), the existing `.spec-workflow/archive/**`
  tree (historical artefacts are out of scope — see Non-goals), and any
  path the tech stage identifies as legitimately non-ASCII. The
  allowlist mechanism (header marker, path allowlist, or both) is tech's
  call; PRD requires only that it exists and is greppable.
- **AC5.d (bypass is explicit).** A bypass mechanism exists and is
  documented (e.g., `--no-verify`, an env var, or a path allowlist
  entry). An accidental bypass — a contributor forgetting to run the
  guardrail — is not possible on the chosen surface; tech picks the
  surface to satisfy this.

### Scope of "chat"

**R6 — Chat is subagent conversational prose and top-level session final
messages; everything else is English.** The positive scope is: text that
the model emits to the user as a conversational reply inside Claude
Code, from any specflow subagent or from the top-level session. The
negative scope (stays English) is exhaustively: CLI stdout from any
`bin/specflow-*` script, hook log lines, tool names (`Read`, `Write`,
`Bash`, `Grep`, etc.), status telemetry, STATUS Notes entries, commit
messages, error messages from scripts, anything that machine tooling
greps, and every file-write content.

- **AC6.a (positive scope example).** The rule body gives at least one
  concrete example of what is in-scope: e.g. "PM's brainstorm summary
  shown to the user in chat" (zh-TW when opted in).
- **AC6.b (negative scope example).** The rule body gives at least
  three concrete negative examples covering (a) CLI stdout from a
  `bin/specflow-*` script, (b) a STATUS Notes line, and (c) a commit
  message — all of which stay English regardless of config.

### Graceful degradation

**R7 — Invalid or unknown config values fall back to default-off with a
single-line warning.** If the config file exists but the key's value is
not a recognised language token (`zh-TW` or explicit `en`), the feature
behaves as if the key were absent (default-off) and emits a single-line
warning to the SessionStart hook's stderr identifying the file, key, and
invalid value. Malformed config (unparseable YAML or JSON, tech's call)
also falls back to default-off with a warning. The session is never
blocked by a config-read failure.

- **AC7.a (unknown value).** Setting the key to a value other than
  `zh-TW` or `en` (e.g. `jp`, `true`, empty string) produces default-off
  behaviour identical to AC1.a, plus exactly one warning line on the
  hook's stderr. Session start completes successfully.
- **AC7.b (malformed config).** A syntactically broken config file
  produces default-off behaviour plus one warning line; session start
  completes successfully. The session does not fail to initialise
  because of a config parse error.
- **AC7.c (missing file).** A missing config file produces default-off
  behaviour with **no** warning — absence is the ordinary case, not an
  error.

### Discoverability

**R8 — The feature is discoverable from one place.** A user new to the
repo can find the opt-in instructions in exactly one canonical location
(the repo `README.md`'s install or usage section, whichever tech
selects) and the instructions point at the config file, the config key
name, and an example value. No duplicate documentation lives in
multiple places; the rule file itself is a reference, not an
entry-point.

- **AC8.a (single canonical doc).** `README.md` contains a short
  section — heading "Language preferences" or equivalent — that names
  the config key, shows the example value `zh-TW`, and links to the
  rule file for the directive's full text.
- **AC8.b (grep-verifiable).** `grep -l "lang.chat"` (or the key name
  tech picks) finds exactly `README.md` and the rule file in the
  repo-root documentation surface — no other file duplicates the
  opt-in instructions.

### Dogfood paradox

**R9 — Structural verification only during this feature's own verify
stage; runtime verification on the next feature after session restart.**
Per `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`
(now seventh occurrence in this repo), this feature ships a mechanism
it would itself invoke: the SessionStart hook reads the new config key;
the rule directive is loaded via the same hook that this feature
modifies. Neither is live during this feature's own development
session. Every AC that depends on runtime subagent language behaviour
(AC1.b's "rule becomes active," AC5's guardrail firing on a real
commit, AC7's warning appearing on real hook start) is a **structural
PASS only** during this feature's `verify` stage; runtime PASS is
observed on the first session the user opens after archive + session
restart. The `08-verify.md` MUST mark each such AC explicitly.

- **AC9.a (structural markers).** The `08-verify.md` for this feature
  distinguishes structural PASS (file exists, hook reads config, rule
  injected when tested synthetically, guardrail script rejects a
  synthetic CJK fixture on a sandbox commit) from runtime PASS (a real
  session exhibits zh-TW chat when the config is set). At least AC1.b,
  AC5.a, AC5.b, and AC7 carry an explicit "structural PASS; runtime
  deferred to next feature after session restart" annotation.
- **AC9.b (next-feature confirmation).** The next feature after this
  one archives MUST include an early STATUS Notes line confirming
  first-session runtime behaviour of language-preferences (either "ran
  with knob unset, chat English as expected" or "ran with knob set to
  zh-TW, chat observed in zh-TW as expected"). This is a handoff AC,
  not a same-feature AC.

## 5. User scenarios

### Scenario A — Opt-in on a fresh repo

Alice works in her own consumer repo. She edits
`.spec-workflow/config.yml` (or whatever tech picks) to add
`lang.chat: zh-TW`. She opens a new Claude Code session. The
SessionStart hook reads the config, adds a `LANG_CHAT=zh-TW` marker to
its additional-context payload, and the session-wide rule from R2
becomes active. When she invokes `/specflow:brainstorm`, the PM
subagent replies to her in zh-TW; when it writes `01-brainstorm.md`,
the file is English. CLI output from any `bin/specflow-*` she invokes
is English. Git diffs show English content.

### Scenario B — Default-off for a multi-contributor repo

Bob shares a consumer repo with three teammates. None of them has
touched the config file. Sessions in the repo behave exactly as they
did before this feature landed — PM, Architect, TPM, Developer,
QA-analyst, QA-tester, Designer all reply in English. The rule file
exists in `.claude/rules/common/language-preferences.md`, but its body
is a no-op with no config key set. No warning appears; absence is
ordinary (AC7.c).

### Scenario C — Accidental leak caught by the guardrail

Carol has opted in and is driving a PM brainstorm in zh-TW. The PM
subagent drifts under long context and writes one zh-TW sentence into
`01-brainstorm.md`. Carol stages the file and tries to commit. The
guardrail (per R5) scans the staged content, finds a CJK codepoint in
`.spec-workflow/features/**/01-brainstorm.md`, rejects the commit with
a non-zero exit, prints the file path, line number, and codepoint
range. Carol opens the file, translates the sentence to English,
re-stages, and commits cleanly. The leak never reaches the remote.

### Scenario D — Repo moved to a new contributor who hasn't opted in

Dan clones the consumer repo Alice has been working in. The repo's
`.claude/rules/common/language-preferences.md` travels with the clone
(seeded by `init` per the per-project-install feature). Alice's local
config file is ignored or absent on Dan's machine (tech picks whether
the config is committed or local-only; recommended local-only for
default-off preservation). Dan opens a session. No config → default-off
→ English chat, identical to today's behaviour. The rule file's
presence does not affect him until he opts in himself.

## 6. Open decisions for architect

These are the two items the brainstorm deferred and a third that
emerged during PRD drafting; `/specflow:tech` must resolve all three.

1. **Config file location.** Should the knob live in
   `.spec-workflow/config.yml` (specflow-native, bash-32-portable YAML
   read, aligns with per-project-install) or `.claude/settings.json`
   (Claude-harness-native, JSON parse already used by
   `bin/specflow-install-hook`, risks colliding with a future Claude
   Code schema change)? PM leans specflow-native
   (`.spec-workflow/config.yml`). Whichever is chosen, the read must be
   bash-32-portable (no `jq`) and must fail gracefully per R7.
2. **Guardrail surface.** Should the commit-time guardrail run as (a) a
   git pre-commit hook (repo-local, bypassable via `--no-verify`, fires
   on every `git commit` regardless of origin), (b) a Stop hook lint
   step (specflow-owned, only fires inside Claude Code sessions, misses
   commits made outside Claude Code), or (c) a `specflow lint` command
   invoked by CI (catches leaks only at push time, highest latency but
   unbypassable on the server)? Trade-offs: leak latency vs. developer
   friction vs. bypassability. PM has no strong lean — tech weighs the
   dogfood-paradox coverage (Stop hook may fire during the feature's
   own work; pre-commit does not) against leak-latency.
3. **Config schema shape.** Flat scalar (`lang.chat: zh-TW`) or nested
   (`lang: { chat: zh-TW, artifacts: en }`)? PM leans **minimal
   nested** (`lang.chat` as a dotted key or a one-level-nested object)
   for forward-extensibility, but the "no general i18n framework"
   non-goal means nested should be structural-only, not aspirational —
   no unused sibling keys, no `artifacts` key (artefact language is
   fixed at `en` as an invariant and not user-configurable). Tech picks
   the exact shape and documents it in the rule file and the README.

## 7. Blocker questions

None — proceed to `/specflow:tech`.

## Team memory

- `pm/ac-must-verify-existing-baseline.md` — applied. R1's AC1.a
  explicitly asserts the English-baseline behaviour before R1's AC1.b
  asserts the opt-in change. R2 anchors the rule-file shape to one
  specific reference (`.claude/rules/README.md`'s frontmatter schema)
  rather than saying "match existing rules"; the conditional-body
  pattern is called out as **new** (AC2.b) so no silent parity trap
  against siblings.
- `pm/split-by-blast-radius-not-item-count.md` (global) — considered,
  does not split. R2 (session-wide rule injection) and R5 (commit-time
  guardrail) have different blast radii — a session-wide drift vs. a
  single rejected commit — but the request bundles them as a single
  opt-in UX and they only function together (R2 without R5 has no
  mechanical backstop; R5 without R2 forces manual translation every
  turn). Brainstorm flagged revisiting if implementation sequencing
  forces different waves; PRD carries the same caveat forward.
- `pm/housekeeping-sweep-threshold.md` — does not apply. Functional
  feature, not a review-nits sweep.
- `shared/dogfood-paradox-third-occurrence.md` — applied, seventh
  occurrence. R9 carries the structural-vs-runtime split; AC9.a
  annotates which ACs are structural-only; AC9.b is the next-feature
  handoff. Propose: on next update to that memory, bump the occurrence
  count and add this feature to the examples list under "Fifth and
  sixth occurrences" with a new "Seventh occurrence" subsection noting
  that the feature under dogfood-paradox review was itself a language
  directive (i.e., the mechanism cannot be exercised by its own
  development session because every PM/Architect/TPM reply written
  during development of language-preferences is in English regardless
  of any knob value).

Memory proposal (not yet filed): `pm/conditional-rule-shape-is-novel.md`
— when a new rule in an otherwise-unconditional tree adds a
conditional body, the PRD should carry an AC that the rule's `## How
to apply` body documents the conditional pattern explicitly, so
future rule authors do not mistake the conditional shape for a
template. Filed-candidate only; wait for a second occurrence before
promoting.
