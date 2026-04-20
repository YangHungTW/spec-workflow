# Retrospective — 20260419-language-preferences

_2026-04-19 · TPM · archive retrospective_

## 1. Summary

Parent feature of the `zh-TW chat / English artefacts` language-preference work.
Shipped one opt-in config key (`lang.chat` in `.spec-workflow/config.yml`) that
flips specflow subagent chat prose to Traditional Chinese while keeping every
committed artefact in English. The child feature
`20260419-user-lang-config-fallback` (already archived) extended the same
SessionStart hook with an ordered candidate list (project -> XDG ->
`~/.config`) so the opt-in could also live in the user's home. This archive is
the parent's overdue housekeeping — the code was merged to main days ago via
its own feature branch and is now in daily runtime use in this repo's
development sessions; only the feature dir was lingering under
`.spec-workflow/features/` when it should have been under
`.spec-workflow/archive/`.

## 2. Scope delta — asked vs shipped

**Original ask** (from `00-request.md`):
- Single opt-in config knob that flips all specflow subagent conversational
  replies to zh-TW.
- No Chinese in any committed artefact (`.spec-workflow/features/**`,
  `.claude/**`, source, tests, commit messages).
- Default-off so multi-contributor repos are unchanged for users who have not
  opted in.
- A sanity check (grep or hook) to detect accidental Chinese in committed
  artefacts and fail loudly before merge.

**Shipped by this parent feature (B1-B5 across W1-W3, T1-T22)**:
- `.claude/rules/common/language-preferences.md` — the English-only rule body
  that declares the conditional `LANG_CHAT=zh-TW` -> zh-TW chat directive and
  enumerates the six English-only carve-outs (file content, tool-call
  arguments, CLI stdout, commit messages, STATUS Notes, team-memory files).
- `.claude/rules/index.md` — one row appended, sorted between
  `classify-before-mutate` and `no-force-on-user-paths`.
- `.claude/hooks/session-start.sh` — `awk` sniff block (D7) reads
  `.spec-workflow/config.yml`, validates against the closed enum
  (`zh-TW` | `en`), appends `LANG_CHAT=<value>` to the SessionStart digest on
  recognition. Fail-safe: unknown value -> one stderr warning + default-off;
  malformed YAML -> silent default-off (D7 tradeoff, confirmed in G2); missing
  file -> silent + default-off.
- `bin/specflow-lint` (D2/D6) — new guardrail CLI with `scan-staged` and
  `scan-paths` subcommands; rejects CJK codepoints in committed artefacts
  outside a bounded allowlist (D8: `00-request.md` user-ask quotes, inline
  `LANG_CHAT=zh-TW` markers, `.spec-workflow/archive/` prefix skip).
- `bin/specflow-seed` (D3) — pre-commit shim installer wiring the lint CLI
  into consumer repos.
- `README.md` — new "Language preferences" section naming the config key,
  example value `zh-TW`, and linking to the rule file.
- `test/` — 16 new tests t51-t66 (rule shape, index row, marker-rule coupling,
  hook absent / zh-TW / unknown / malformed, lint clean / CJK / allowlists,
  precommit shim wiring, subagent diff empty, README doc section).

**Shipped by the child feature (already archived, for reference)**:
- Same hook extended with ordered candidate list: `.spec-workflow/config.yml`
  in the consumer repo -> `~/.config/specflow/config.yml` -> `$XDG_CONFIG_HOME/specflow/config.yml`.
- Enables global opt-in so a zh-TW user doesn't need a per-repo config file.

**Delta**: the ask was satisfied by this parent feature. The child feature
extended it from project-scoped to user-scoped with no change to semantics.
No scope slipped, no scope was dropped. The only documented `should` findings
at gap-check (G1: README "any BCP-47 tag" forward-lean; G2: malformed-YAML
silent-default-off vs. PRD's "one warning line") are documented architectural
tradeoffs (D7) and not regressions.

## 3. Dogfood fact — clean runtime confirmation

This RETROSPECTIVE.md itself is being authored inside a development session
running with `LANG_CHAT=zh-TW` active. The SessionStart additional-context
payload in this very session carries the marker emitted by the hook block
shipped in T2 of this feature; the chat reply that the user will read when
this archive completes is written in zh-TW per the rule shipped in T1. No
synthetic sandbox, no deferred exercise — the parent feature is in real
production use throughout the `20260419-flow-monitor` development
conversation that just archived and continues to drive this session's chat
behaviour.

This is the clean runtime handoff that the dogfood-paradox pattern
(`shared/dogfood-paradox-third-occurrence.md`, 7th occurrence) reserved for
"the next feature after archive". Because the child feature
`20260419-user-lang-config-fallback` archived first (within the same day),
its own T1 hook edit also ran live and confirmed the candidate-list read
path. Both structural-verify features have now passed real-world runtime
exercise without surfacing a new dogfood-exposed bug — a first for this
repo's dogfood series (prior occurrences always revealed at least one
sandbox-invisible fix).

The "runtime PASS" half of R9 AC9.b is therefore satisfied by this session's
existence: the preceding `20260419-flow-monitor` archive session was held in
zh-TW, and this session continues to behave per the language-preferences
rule. No additional runtime verification is required before archive.

## 4. Counts

- **Tasks**: 22 (T1-T22 across 3 waves).
  - W1: T1, T2, T3 (rule file + hook edit + lint CLI skeleton).
  - W2: T4 (seed installer extension).
  - W3: T5-T22 (docs, tests, README, smoke registration, subagent-diff
    gate).
- **Tests added**: 16 (t51-t66).
- **Smoke state at archive**: 65/65 in isolation; 64/65 in the verify-stage
  working tree due to a test-isolation artefact (t53 scanned an untracked
  next-feature brainstorm file). Not a code regression — documented in
  `08-verify.md` §5.
- **Waves with retries**: W1 (T3 retry 1 for path-traversal security
  must-fix; T3 retry 2 for `git show` shell-out-in-loop `must` perf finding
  resolved by switching to `git cat-file --batch` for O(1) forks). W3 (T7
  GNU-only `grep --exclude-dir` rewritten as `grep -v` chain; T19 missing
  sandbox preflight added). No wave required manual escalation; all retries
  landed within the 2-retry budget.
- **Gap-check verdict**: NITS (2 `should` findings G1 / G2, both documented
  D7 tradeoffs; 0 `must`).
- **Verify verdict**: PASS (22 PASS / 7 structural-PASS / 0 FAIL / 1 N/A).
- **Architect decisions**: D1-D9 primary (D10-D17 deferred to future
  extension work on extra languages, artefact localisation, and lint-scope
  widening).

## 5. Memory proposals

Polling the roles that participated in this feature (STATUS checklist shows
PM, Architect, TPM, Developer, QA-analyst, QA-tester):

- **PM** — the `01-brainstorm.md` open-question split (config location +
  guardrail surface) deferred cleanly to architect. The only PM-side pattern
  worth noting is "two-value opt-in knob with explicit `en` default keeps
  forward-compat honest", but this is adequately captured in the D9 schema
  comment and README wording guidance. The G1 finding about "any BCP-47 tag"
  overstatement in README is a one-off review-time catch, not a PM recurring
  pattern. **No new proposal.**

- **Architect** — D7 (malformed YAML silent vs. warning) is an interesting
  tradeoff: narrow-awk parsing cannot distinguish "empty value from present
  key" from "key not parseable at all", so the silent branch was accepted.
  This pattern ("narrow stream parsers cannot distinguish absence from
  unrecognised-shape; document silent defaults as explicit D-decision") may
  be a reusable lesson, but the existing memory
  `architect/opt-out-bypass-trace-required.md` already covers the broader
  "document silent degradation paths" theme. **No new proposal.**

- **TPM** — the tasks-doc discipline here was textbook: briefings pasted
  verbatim frontmatter schema, D9 YAML snippet, awk sniff block, classifier
  enum, allowlist pattern. This is already captured by
  `tpm/briefing-contradicts-schema.md` ("quote, don't paraphrase"). The W3
  18-way parallel wave (T5-T22) completed cleanly with only 2 retries — a
  data point consistent with `tpm/checkbox-lost-in-parallel-merge.md` (4th
  occurrence noted there already mentions widths scale). **No new proposal.**

- **Developer** — T3 retry 2 surfaced a reusable bash pattern: `git cat-file
  --batch` with a single persistent process is the correct replacement for
  per-file `git show :FILE` shell-out-in-loop under the 200ms hook latency
  budget (cross-reference `reviewer/performance.md` entries 1 and 7). This
  is a **new developer-local memory candidate** — not currently in
  `.claude/team-memory/developer/`. Proposed:
  `developer/git-cat-file-batch-for-staged-file-scan.md`.
  - *Rationale*: the retry 1 perf BLOCK cost one full review cycle; a
    captured pattern would short-circuit the next similar implementation.
  - *Scope*: local (specflow-specific — lint CLI pattern).

- **QA-analyst** — G1 (README forward-lean) and G2 (malformed-YAML silent)
  are both documented D7 tradeoffs caught at gap-check. The existing memory
  `qa-analyst/dry-run-double-report-pattern.md` covers the general "line-
  shape assertions catch output-shape drift" theme and applies to the
  malformed-config test t57's "at most one line" assertion. **Already
  captured.**

- **QA-tester** — the qa-tester index is currently empty (`_No memories yet._`).
  This feature's verify produced a clean 4-step structural/runtime split
  applied consistently across AC1.b / AC5.a / AC5.b / AC7.a / AC7.b /
  AC7.c, each with explicit "runtime deferred to next feature after session
  restart" annotations. This is **already captured** by the shared memory
  `shared/dogfood-paradox-third-occurrence.md` under the QA-tester section
  ("Distinguish structural PASS vs runtime PASS per AC"); the qa-tester-
  local index just hasn't pulled in a role-specific pointer yet, but that is
  a housekeeping nit rather than a new lesson. **No new proposal.**

**Net**: 1 new proposal (developer/git-cat-file-batch-for-staged-file-scan.md),
awaiting user approval.
