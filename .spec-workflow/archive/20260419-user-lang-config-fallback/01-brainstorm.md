# Brainstorm — user-lang-config-fallback

## 1. Problem recap

Parent feature `20260419-language-preferences` shipped `lang.chat` as a per-repo
knob at `.spec-workflow/config.yml`. That models team-level opt-in correctly
but forces an N-repos-N-identical-files papercut on single users whose language
preference is personal. We need the SessionStart hook to also consult a
user-home config when the project-level file is absent (or silent on the key),
without adding a fork, without changing the default-off baseline, and without
breaking parent R1's team-override contract.

## 2. Approaches

### A. Two-path try-in-order
Hook reads `.spec-workflow/config.yml` first via the existing `awk` sniff; if
the file is absent or the key empty, re-run the sniff on
`~/.config/specflow/config.yml`. First non-empty match wins. Precedence is
hard-coded (project → user). Minimum diff against the parent hook.

- Pros: smallest change; parser is the parent's sniff lifted into a tiny loop
  of two paths; zero new dependencies; easy to reason about.
- Cons: hard-coded two paths — adding a third candidate later (XDG, env-var
  escape hatch) means reshaping the control flow.
- Effort: XS (~10 lines).
- Risks: low.

### B. Candidate list with stop-at-first-hit
Same shape as (A) but the paths live in an ordered bash array (or newline list,
since bash 3.2 has no proper arrays in all contexts). The hook iterates, runs
the sniff on the first readable file, stops at the first non-empty value.
Adding a future fallback means appending one line to the list; the loop body
is dialect-free.

- Pros: extensible without reshaping; matches `classify-before-mutate` reads-
  first discipline (build candidates, walk once, stop at first hit); keeps the
  parent's sniff exactly as-is (single awk program, just called per candidate).
- Cons: one extra indirection vs (A); candidate construction needs a tiny
  helper to compose the XDG-or-tilde choice once.
- Effort: S (~15–20 lines).
- Risks: low — loop is bounded at 2 or 3 iterations, so no perf concern.

### C. Explicit env-var override (`SPECFLOW_CONFIG`)
Same as (A)/(B) but prepended by a `SPECFLOW_CONFIG` env-var path that, when
set, takes absolute precedence over both project and user files. Useful for CI
and testing.

- Pros: escape hatch for non-standard layouts and for writing deterministic
  smoke tests; matches the `shared/local-only-env-var-boundary-carveout.md`
  threat model (operator-controlled config, local-only tool).
- Cons: adds surface area before it's demonstrably needed; escape hatches
  accumulate — each one becomes a `v2` burden to document, test, and deprecate;
  smoke tests can set paths without an env-var knob by sandboxing `$HOME`.
- Effort: S (~5 lines on top of B).
- Risks: scope creep — v1 doesn't need it; deferring costs nothing because
  adding later is non-breaking.

### D. XDG-aware user path
Honour `$XDG_CONFIG_HOME/specflow/config.yml` when `$XDG_CONFIG_HOME` is set
and non-empty; otherwise fall back to `~/.config/specflow/config.yml`. macOS
doesn't set XDG by default but users who do set it (dotfile managers,
freedesktop-aligned setups) get the respected path. Composes with (A), (B),
or (C).

- Pros: respects a documented cross-platform convention with zero new fork
  (one env-var check via `${XDG_CONFIG_HOME:-}`); preserves the simple
  `~/.config/specflow/` path as the default so the README example stays
  one line.
- Cons: one extra env check in the hook (no fork, still under the 200ms
  budget); slightly more surface in docs ("here's where we look, and the
  XDG override").
- Effort: XS on its own (~3 lines) — composes into B's candidate list.
- Risks: none — the env check is a string test, not a subprocess.

## 3. Evaluation axes

- **Precedence clarity** — can a user predict which file wins without reading
  source?
- **Reuses parent machinery** — is the awk sniff unchanged, only the candidate
  list expanded?
- **Default-off preservation** — both files absent → identical to today.
- **Hook latency** — extra forks added (goal: zero).
- **Discoverability** — README / `/help` surfaces all candidate paths.
- **Test surface** — new test scripts or matrix cells needed (goal: ≤ 3).
- **Dogfood paradox** — can the feature be exercised during its own session?

## 4. Comparison matrix

| Axis                       | A (two-path)  | B (candidate list) | C (env-var)   | D (XDG-aware)     |
|----------------------------|---------------|--------------------|---------------|-------------------|
| Precedence clarity         | high          | high               | medium        | high (w/ doc)     |
| Reuses parent machinery    | yes           | yes                | yes           | yes               |
| Default-off preservation   | yes           | yes                | yes           | yes               |
| Hook latency (forks added) | 0             | 0                  | 0             | 0                 |
| Discoverability            | 2 paths       | 2–3 paths          | 3 paths + env | 2 paths + env     |
| Test surface               | 4-cell matrix | 4-cell matrix      | 8-cell matrix | 4-cell + XDG case |
| Dogfood paradox            | structural    | structural         | structural    | structural        |

All approaches pass the `must`-severity reviewer-performance R7 (hook latency
< 200ms) because none add a fork; the awk invocation count stays at "one per
readable candidate file", bounded at 2.

## 5. Open-question resolutions

1. **Exact user-home path** — recommend `~/.config/specflow/config.yml` as the
   default, with an XDG-aware variant `$XDG_CONFIG_HOME/specflow/config.yml`
   when `$XDG_CONFIG_HOME` is set and non-empty. Reject `~/.claude/*` (that's
   Claude-harness territory — wrong tool, wrong ownership) and `~/.specflow/*`
   (non-dotfile-dir convention; XDG-incompatible). PM lean is XDG-aware; final
   XDG-vs-simple-tilde call deferred to architect at `/specflow:tech` (this is
   the one architect-owned decision carrying forward).

2. **Override vs merge semantics** — recommend **file-level override**. When
   the project-level file exists and sets the key, it wins wholesale; the user
   file is ignored for that key. v1 schema has exactly one key (`lang.chat`),
   so per-key merge complexity is unwarranted. Key-level merge becomes a real
   design question only when the schema grows a second key; it can ship as a
   separate feature then without breaking v1 semantics.

3. **README discoverability timing** — update the repo `README.md`
   "Language preferences" section in **this** feature (dedicated task at
   implement stage), not as a post-archive amendment to the parent. The parent
   is already merged; piggybacking its README edit onto this follow-up keeps
   the docs landed with the feature that makes them true.

## 6. Recommendation

**Combine B (candidate list) + D (XDG-aware user path).** The hook builds an
ordered list of ≤ 3 candidate paths — project `.spec-workflow/config.yml`,
then `$XDG_CONFIG_HOME/specflow/config.yml` if that env var is set and
non-empty, else `~/.config/specflow/config.yml` — and runs the parent's
existing awk sniff on the first readable file. First non-empty value wins.

Rationale (5 lines):
- Preserves parent R1's team-override contract: project-level still wins
  when present.
- Zero new fork/exec in the hook path; reuses the parent's awk sniff verbatim.
- Default-off invariant (parent R1 AC1.a, R7 AC7.c) holds because the loop
  emits no marker when every candidate is absent or silent.
- XDG-awareness costs one shell-variable expansion (no subprocess) and
  respects a documented cross-platform convention.
- Candidate-list shape leaves room for a future env-var escape hatch without
  reshaping the control flow, if operators ever demonstrate a need.

Accepted tradeoffs:
- **No env-var escape hatch in v1** — smoke tests sandbox `$HOME` per
  `.claude/rules/bash/sandbox-home-in-tests.md`, which is sufficient for
  testing without exposing a new CLI knob. `SPECFLOW_CONFIG` stays a future
  feature.
- **File-level override (not per-key merge)** — correct for a one-key schema;
  revisit when the schema grows.
- **One extra env-var read for XDG** — no fork, well under the 200ms budget.

## 7. Risks / carry-forward for PRD

- **Dogfood paradox — 7th occurrence.** This feature ships SessionStart hook
  logic that cannot be exercised during its own development session (the
  session was started before the hook change merged). Structural verification
  is all the feature's own verify stage can offer; runtime confirmation
  deferred to the first session started after archive. Cross-reference
  `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md` (pattern
  doc; filename is stable despite count drift). Flag to QA-tester at verify.
- **Architect-owned decision carried forward.** XDG-vs-simple-tilde final call
  lives at `/specflow:tech`. PRD should state the PM-recommended shape
  (XDG-aware + simple-tilde fallback) and defer the atomic path string to
  04-tech.md.
- **Test matrix must cover 4 cells** — {project-present, project-absent} ×
  {user-home-present, user-home-absent}, each asserting the expected
  precedence outcome. A 5th cell (XDG-aware pathing) can be a targeted
  single-path assertion rather than a full matrix axis.
- **README edit is part of this feature.** The "Language preferences" section
  needs a paragraph naming both candidate paths and the precedence order.
  PM will carry this as a documented R in the PRD.
- **Bash 3.2 portability risk on the candidate loop.** `case` inside a
  `while IFS= read` subshell can parse-error on bash 3.2 (see
  `.claude/rules/bash/bash-32-portability.md`); architect should use
  `if/elif` inside the iteration, not `case`. Flagged so tech doesn't
  rediscover this the hard way.
- **Default-off preservation is a verify-stage must-hold invariant.** Any
  test cell where both project and user configs are absent MUST produce zero
  `LANG_CHAT=` marker output; regression on this bleeds into every user who
  never opted in. Structural + smoke assertion required.

## Team memory

Applied entries:
- `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md` — 7th
  occurrence; structural-only verify, runtime on next session after archive.
- `.claude/team-memory/pm/ac-must-verify-existing-baseline.md` — PRD ACs will
  cite the parent's AC1.a English-baseline shape explicitly rather than
  vaguely saying "match parent behaviour".
- `~/.claude/team-memory/pm/split-by-blast-radius-not-item-count.md` — this
  feature is already correctly scoped as a follow-up to the parent rather
  than bundled into a bigger rework; blast radius (SessionStart hook path)
  is shared with the parent but the surface change is local to the hook's
  config-read block.
- `~/.claude/team-memory/shared/local-only-env-var-boundary-carveout.md` —
  informs the env-var escape hatch defer: operator-set env vars (like a
  hypothetical `SPECFLOW_CONFIG`) are inside the trust boundary, so a future
  feature adding one is not blocked by reviewer-security rule #3.

Proposed new memory: none — existing entries cover the reasoning. Will
revisit at PRD if a novel pattern emerges.
