# PRD — user-lang-config-fallback

_2026-04-19 · PM_

## 1. Summary

Chat language is a personal preference that follows the user across every
repo they drive specflow in; it should not require committing an identical
two-line YAML file into each consumer tree. Today (parent
`20260419-language-preferences`) the only knob lives at
`.spec-workflow/config.yml` (project-level), which models team-level
opt-in correctly but forces an N-repos-N-identical-files papercut on a
single user whose preference is global. This feature extends the parent's
SessionStart hook read path to fall back to a user-home config when the
project-level file is absent, preserving every parent invariant
(default-off, artefact-English, bash 3.2 portability, no per-agent toggle,
team override when both files exist). Config **location** only; directive
semantics are unchanged.

## 2. Goals

- **Personal preferences are set once per machine.** A single user-home
  config file provides a default `lang.chat` across every specflow
  consumer repo on that machine — no per-repo opt-in required.
- **Team override preserved.** A committed project-level
  `.spec-workflow/config.yml` still wins wholesale when present, so teams
  that have standardised on one chat language for their shared repo keep
  today's behaviour exactly.
- **Default-off invariant preserved.** All candidate files absent =
  English baseline, identical to today's behaviour for any user who has
  not opted in at either level.
- **Zero new fork/exec in the hook path.** The parent's `awk` YAML sniff
  is reused as-is; only the candidate path list grows.
- **Discoverable precedence.** The README documents the lookup order
  unambiguously in plain words so a user with both files knows which one
  is live.

## 3. Non-goals

Pulled from `00-request.md` §Out of scope and brainstorm §5 resolutions:

- **No env-var escape hatch in v1** (e.g. `SPECFLOW_CONFIG=…`). Rejected
  in brainstorm §2 C — escape hatches accumulate into deprecation debt
  and smoke tests can sandbox `$HOME` per
  `.claude/rules/bash/sandbox-home-in-tests.md` without a new CLI knob.
- **No per-key merge semantics.** When both files exist, the
  project-level file wins **wholesale**; the user-home file is ignored
  for that session. Key-level merge becomes a real design question only
  when the schema grows beyond `lang.chat` and can ship as its own
  feature then.
- **No migration tooling.** The hook learns to read a second file; no
  script ships that moves or symlinks existing project-level contents
  into the user-home location.
- **No new config keys.** Schema is exactly the parent's v1 (`lang:`
  block → `  chat: <zh-TW|en>`) per
  `.spec-workflow/features/20260419-language-preferences/04-tech.md` §D9.
  No `lang.default`, no `artifacts`, no new axes.
- **No changes to parent directive semantics.** Parent R3 (carve-outs),
  R4 (subagent coverage), R5 (commit-time guardrail), R6 (scope of
  chat) are frozen; this feature touches only the candidate-path list
  inside the hook's config-read block.
- **No user-home config management UX.** No `specflow config set`, no
  template installer, no validation CLI — users author the YAML by hand,
  same as the parent's model for `.spec-workflow/config.yml`.
- **No cross-machine sync.** The user-home file is local to the machine,
  same as any other dotfile.

## 4. Requirements

Each R has a one-line statement + 1–4 acceptance criteria. R-numbers are
stable; AC IDs scoped per R.

### Candidate list & precedence

**R1 — The hook walks an ordered candidate list and the first file whose
`lang.chat` sniff yields a valid value wins (file-level override).** The
ordered list is:

  1. `.spec-workflow/config.yml` (project — wins when present)
  2. `$XDG_CONFIG_HOME/specflow/config.yml` (user-home XDG; evaluated
     only when `$XDG_CONFIG_HOME` is set **and non-empty**)
  3. `~/.config/specflow/config.yml` (user-home final fallback)

Iteration stops at the first readable file whose `lang.chat` value is a
recognised token (`zh-TW` or `en`); that value becomes the emitted
marker. All three absent = no marker emitted (default-off preserved).

- **AC1.a (baseline — all absent).** With all three candidate files
  absent, a fresh session produces no `LANG_CHAT=` line in the hook's
  additional-context payload — identical to parent
  `03-prd.md` R1 AC1.a (English baseline). Structural verify only per
  R7.
- **AC1.b (user-home-only opt-in).** With `.spec-workflow/config.yml`
  absent and `~/.config/specflow/config.yml` present containing `lang:`
  → `  chat: zh-TW`, the hook emits `LANG_CHAT=zh-TW`. Runtime PASS is
  deferred per R7; structural verify asserts the marker appears in the
  hook's JSON output under a sandboxed `$HOME`.
- **AC1.c (project wins over user-home).** With `.spec-workflow/config.yml`
  containing `chat: zh-TW` AND `~/.config/specflow/config.yml`
  containing `chat: en`, the emitted marker is `LANG_CHAT=zh-TW`
  (project wins wholesale — file-level override, not per-key merge).
  Cross-ref: parent R1 (team-override contract, `03-prd.md` R1 body).
- **AC1.d (XDG wins over simple-tilde when both user-home files
  present).** With `$XDG_CONFIG_HOME` set to a non-empty value,
  `$XDG_CONFIG_HOME/specflow/config.yml` present with `chat: zh-TW`,
  and `~/.config/specflow/config.yml` present with `chat: en` (and no
  project-level file), the emitted marker is `LANG_CHAT=zh-TW`. With
  `$XDG_CONFIG_HOME` unset or empty, the simple-tilde path is consulted
  directly.

### Reuse parent's awk sniff — no duplication

**R2 — The YAML parsing code is unchanged; only the candidate path list
is extended around it.** The parent's single `awk` program from
`.claude/hooks/session-start.sh` (lines 261–269) is called once per
readable candidate, wrapped in a small iteration. No second parser is
introduced; no copy-paste of the awk block per candidate.

- **AC2.a (single awk definition).** `grep -c 'in_lang=1' .claude/hooks/session-start.sh`
  returns exactly `1` after this feature lands — the awk program is
  defined once, invoked inside a loop. Counting `in_lang=1` (the awk
  program's distinctive state-machine token) pins the parser's
  identity rather than a flimsy grep on the token `awk`.
- **AC2.b (awk body byte-identical to parent D7).** A structural diff
  of the awk program body (the multi-line string between `awk '` and
  the closing `'`) shows zero character changes vs the parent's current
  block at `.claude/hooks/session-start.sh` lines 261–269. The diff at
  commit time shows added loop/iteration structure **around** the awk
  call, not a rewrite of it. Cross-ref:
  `.spec-workflow/features/20260419-language-preferences/04-tech.md`
  §D7.

### Invariants preserved from parent

**R3 — Parent invariants are preserved wholesale; no directive or
guardrail semantics change.** The following parent requirements remain
in force exactly as specified — this feature adds no new contract, only
extends the config read path:

- Parent R3 (directive carve-outs: file writes, tool args, commit
  messages, CLI stdout, STATUS Notes, team-memory all stay English) —
  unchanged; source at
  `.spec-workflow/features/20260419-language-preferences/03-prd.md` R3,
  AC3.a–AC3.b.
- Parent R4 (subagent coverage — all seven specflow subagents inherit
  from session context; zero agent diffs) — unchanged; source at
  parent `03-prd.md` R4, AC4.a–AC4.b.
- Parent R5 (commit-time guardrail rejects CJK leaks in committed
  artefacts) — unchanged; source at parent `03-prd.md` R5,
  AC5.a–AC5.d.
- Parent R6 (scope of "chat" = conversational prose only; everything
  else English) — unchanged; source at parent `03-prd.md` R6,
  AC6.a–AC6.b.
- Parent R1 AC1.a (English baseline when config absent) — preserved and
  extended: AC1.a above asserts the same baseline across all three
  candidate paths absent, not just the project-level one. Source at
  parent `03-prd.md` R1 AC1.a.

This R exists to make the invariant set explicit and greppable; no
additional tests are owed beyond what the parent already ships. If any
of these invariants would be affected by the candidate-list extension,
tech/TPM must stop and escalate rather than ship a silent regression.

### Graceful degradation extended per candidate

**R4 — Each candidate file, when read, degrades gracefully on its own
content (malformed YAML → silent; unknown value → one stderr warning
naming the path); but across the candidate list, the first file whose
`lang.chat` key is present wins the decision, per tech D6.
[CHANGED 2026-04-19]** Default-off obtains when all candidates are
absent or have no `lang.chat` key. Mirrors parent R7 (source: parent
`03-prd.md` R7, AC7.a–AC7.c), extended so the warning identifies
**which** candidate file held the invalid value — important because a
user with both a project-level and a user-home file may not immediately
know which one triggered the warning.

- **AC4.a (unknown value per candidate).** For each candidate path
  (project, XDG, simple-tilde), when that file is present with
  `chat: fr` (or any value outside `{zh-TW, en}`), the hook emits
  exactly one stderr warning line that names the candidate file path
  and the invalid value, and default-off behaviour obtains for the
  session (no `LANG_CHAT=` marker emitted). **Iteration stops at the
  first candidate whose `lang.chat` key is present — regardless of
  whether the value is valid — per tech D6 file-level-override
  semantics; an invalid early candidate is NOT cascaded past to a later
  one. [CHANGED 2026-04-19]** A user with a project-level typo
  (`chat: fr`) is expected to fix it rather than rely on a global
  fallback taking over silently.
- **AC4.b (session never blocked).** Exit code is `0` regardless of
  config state (all absent, all malformed, mix). Cross-ref: parent
  R7's "session is never blocked by a config-read failure" contract
  (parent `03-prd.md` R7 body).
- **AC4.c (missing file silent).** A missing candidate produces no
  warning — absence is the ordinary case for user-home configs
  (identical to parent AC7.c, parent `03-prd.md` R7 AC7.c). A missing
  file does not stop the iteration; only a file whose `lang.chat` key
  is present stops it (per AC4.a and tech D6). [CHANGED 2026-04-19]

### Hook latency preserved

**R5 — The added iteration does not breach parent R5's 200ms hook
budget.** The loop body is bounded at ≤ 3 iterations, each doing an
`[ -r "$path" ]` existence check and — only on present files — invoking
the existing awk program. No new subprocess is introduced; no network
I/O; no `readlink -f`/`realpath` calls.

- **AC5.a (structural — no new fork per iteration).** A static read of
  the modified hook script shows the loop body contains at most: one
  `[ -r … ]` test, one shell-variable expansion for the XDG path
  construction, and (on present files only) one invocation of the
  existing awk program. Cross-ref:
  `.claude/rules/reviewer/performance.md` rule 1 (no shell-out in
  loops) and rule 6 (minimise fork/exec in hot paths).
- **AC5.b (all-absent wall-clock unchanged within noise).** With all
  three candidate files absent, hook wall-clock is unchanged within
  measurement noise (±10ms) vs the parent's single-path baseline.
  Cross-ref: parent
  `.spec-workflow/features/prompt-rules-surgery/03-prd.md` R5 SLA
  (200ms budget, inherited via parent R5).

### Discoverability updated

**R6 — The repo `README.md` "Language preferences" section documents
the full candidate-list precedence in plain words.** The parent
shipped a single-path description (parent R8, parent `03-prd.md` R8,
AC8.a–AC8.b); this feature extends that section so a user who sees
both a project-level and a user-home file knows which one is live. The
rule file (`.claude/rules/common/language-preferences.md`) is
**unchanged** — it speaks only about the `LANG_CHAT` marker and its
directive, not about how the marker is sourced.

- **AC6.a (simple-tilde path documented).** `grep -F '~/.config/specflow/config.yml' README.md`
  returns at least one line.
- **AC6.b (XDG path documented).** `grep -F 'XDG_CONFIG_HOME' README.md`
  returns at least one line, and the surrounding prose states that the
  XDG path is consulted only when the env var is set and non-empty.
- **AC6.c (precedence stated in plain words).** The README section
  contains a sentence of the form "project > XDG > tilde" (or
  equivalent plain-English ordering — e.g. "the project file wins when
  present; otherwise the XDG path is consulted when
  `$XDG_CONFIG_HOME` is set; otherwise the simple `~/.config/specflow/`
  path").
- **AC6.d (rule file unchanged).** `git diff` on the feature's final
  commit shows zero modifications to
  `.claude/rules/common/language-preferences.md` — the rule body is
  location-agnostic and stays that way.

### Dogfood paradox

**R7 — Structural verification only during this feature's own verify
stage; runtime verification on the next feature after session restart.**
Per `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`
(8th occurrence in this repo — 7th was the parent
`20260419-language-preferences`), this feature ships SessionStart hook
logic that cannot fire during its own development session (the session
was started before the hook change merged). Every AC that depends on
the hook actually re-reading config at session start is a **structural
PASS only** during this feature's `verify` stage; runtime PASS is
observed on the first session opened after archive + session restart.

- **AC7.a (structural markers in verify).** `08-verify.md` explicitly
  annotates AC1.b, AC1.c, AC1.d, and AC4.a with "structural PASS;
  runtime deferred to next feature after session restart".
- **AC7.b (next-feature handoff).** The first feature archived after
  this one includes an early STATUS Notes line confirming first-session
  runtime behaviour — e.g., "new session read
  `~/.config/specflow/config.yml`, `LANG_CHAT=zh-TW` marker observed"
  or "user-home config absent, no marker, English baseline as
  expected". Cross-ref: parent R9 AC9.b (same handoff shape; parent
  `03-prd.md` R9).

## 5. User scenarios

### Scenario A — Global personal preference, no per-repo setup

Alice is a zh-TW native who maintains several personal repos plus
contributes to one team repo. She runs once, on her machine:

```sh
mkdir -p ~/.config/specflow
printf 'lang:\n  chat: zh-TW\n' > ~/.config/specflow/config.yml
```

She opens a fresh Claude Code session in any of her personal repos (no
`.spec-workflow/config.yml` present). The SessionStart hook walks the
candidate list: project-level absent → `$XDG_CONFIG_HOME` unset →
simple-tilde path present → emits `LANG_CHAT=zh-TW`. When she invokes
`/specflow:brainstorm`, the PM replies in zh-TW; `01-brainstorm.md`
contents and all CLI output remain English. No per-repo edit required.

### Scenario B — Team repo overrides personal preference

The same Alice now switches to the team repo, which ships a committed
`.spec-workflow/config.yml` containing `chat: en` (the team has
standardised on English chat for the shared session). Her user-home
file still says `zh-TW`. The hook walks the list: project-level present
and valid → emits `LANG_CHAT=en` → iteration stops. Her chat session in
this repo is English (team override wins wholesale). When she returns
to her personal repo, the project-level file is absent again, the
user-home value is picked up, and chat is back to zh-TW.

### Scenario C — Linux user with an XDG-aware dotfile manager

Dave uses a Linux box with `$XDG_CONFIG_HOME=/home/dave/.custom-config`
(set by his dotfile manager). He has two files on disk:
`/home/dave/.custom-config/specflow/config.yml` with `chat: zh-TW` and
`/home/dave/.config/specflow/config.yml` with `chat: en` (stale, from a
previous setup). The hook sees `$XDG_CONFIG_HOME` non-empty, reads the
XDG path first, finds `zh-TW`, stops. The stale simple-tilde file is
never consulted. Chat is zh-TW.

### Scenario D — Fresh clone with no configs anywhere

Erin clones a repo for the first time on a machine where she has never
set up a user-home specflow config. No project-level file, no
`$XDG_CONFIG_HOME` specflow config, no `~/.config/specflow/`. The hook
walks the list, finds nothing readable, emits no `LANG_CHAT=` marker.
Chat is English (baseline). No stderr warnings fire (missing files are
silent per AC4.c). No surprises.

## 6. Open decisions for architect

One decision carries forward from brainstorm §5 #1:

1. **XDG-aware vs simple-tilde-only for the user-home path.** PM's lean
   (per brainstorm §6 recommendation B+D) is **XDG-aware with tilde
   fallback** — the candidate list includes
   `$XDG_CONFIG_HOME/specflow/config.yml` when the env var is set and
   non-empty, then `~/.config/specflow/config.yml` as the final
   fallback. Rationale: XDG-awareness respects a documented
   cross-platform convention (Linux dotfile managers, freedesktop-aligned
   setups) at the cost of one shell-variable expansion — no subprocess,
   no fork, well under the 200ms budget (R5). The alternative is
   simple-tilde-only: drop the XDG candidate, always read
   `~/.config/specflow/config.yml`. Simpler to document (one path
   instead of two), but users with XDG set will find their preferred
   location silently ignored. Architect picks at `/specflow:tech`; PRD's
   R1 candidate list and R6's README text are written assuming the
   XDG-aware shape. If architect picks simple-tilde-only, AC1.d and
   AC6.b drop out and R1's candidate list shrinks to two entries (trim
   at tech stage, not now).

   Cross-ref constraints that make this architect-owned, not PM-owned:
   bash 3.2 portability (`${XDG_CONFIG_HOME:-}` expansion is safe on
   3.2 but the surrounding loop must avoid `case` inside a subshell —
   see brainstorm §7 bash-32 note and
   `.claude/rules/bash/bash-32-portability.md`); hook latency budget (no
   new fork permitted); no `readlink -f` / `realpath` on any candidate
   path construction.

## 7. Blocker questions

None — proceed to `/specflow:tech`.

## Team memory

Applied entries:

- `pm/ac-must-verify-existing-baseline.md` — applied. R3 explicitly
  names each preserved parent R with its file+AC-id anchor
  (`03-prd.md` R3/R4/R5/R6/R1 AC1.a) rather than saying "match parent
  behaviour". AC1.c, AC2.b, AC5.b, AC7.b each cite the specific parent
  AC they extend or inherit.
- `pm/housekeeping-sweep-threshold.md` — does not apply. Functional
  feature, not a review-nits sweep.
- `shared/dogfood-paradox-third-occurrence.md` — applied, 8th
  occurrence. R7 carries the structural-vs-runtime split; AC7.a
  annotates which ACs are structural-only; AC7.b is the next-feature
  handoff.
- `~/.claude/team-memory/pm/split-by-blast-radius-not-item-count.md`
  (global) — considered; does not split. The blast radius is identical
  to the parent's (SessionStart hook read path) and the change is
  narrowly scoped to the candidate-list block inside the same hook.
  Splitting further would create a one-R feature.
- `~/.claude/team-memory/shared/local-only-env-var-boundary-carveout.md`
  (global) — informs non-goal #1 (no `SPECFLOW_CONFIG` env var escape
  hatch in v1). Operator-set env vars are inside the trust boundary,
  so a future feature adding one would not be blocked by
  reviewer-security rule #3; the reason to defer is scope, not safety.
- `~/.claude/team-memory/shared/skip-inline-review-scope-confirmation.md`
  (global) — not applicable at PRD stage; carries forward as a TPM/dev
  guardrail if `--skip-inline-review` is needed during implement.

Proposed new memory: none. Existing entries cover the reasoning; will
revisit at verify if a novel pattern emerges (e.g. if architect picks
simple-tilde-only and AC trimming surfaces a pattern worth capturing).
