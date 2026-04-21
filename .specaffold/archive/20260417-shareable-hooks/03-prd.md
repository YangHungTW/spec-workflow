# PRD — shareable-hooks (B2.a)

_2026-04-17 · PM_

## 1. Overview

B1 landed a rules-injection SessionStart hook **inside this repo only**. B2.a makes the hook scripts *shareable* across projects: `bin/claude-symlink` grows a third managed directory-level pair (`.claude/hooks/`) so a single `install` globalizes the hook scripts to `~/.claude/hooks/`, and `bin/specflow-install-hook` (unchanged) lets each consumer project opt into wiring that global script into its own `settings.json`. Alongside the infra change, B2.a ships a new `.claude/hooks/stop.sh` — a Stop-event hook that auto-appends a STATUS note when an agent finishes, eliminating the "File has been modified since read" race we hit during B1's implement waves. Rules stay per-project (Q1=b, shallow globalize); only hook scripts become shared.

## 2. Goals / Non-goals

### Goals
- **(7) Shallow globalize hook scripts** — `bin/claude-symlink install` places `~/.claude/hooks/` as a symlink to this repo's `.claude/hooks/`, without any change to the existing managed set's behavior. A consumer project opts into the SessionStart hook (or the new Stop hook) with a single `bin/specflow-install-hook add …` call against its own `settings.json`. The hook scripts remain cwd-aware: they read `<cwd>/.claude/rules/` and `<cwd>/.spec-workflow/…` rather than the repo that hosts the scripts.
- **(5) Stop hook for STATUS sync** — `.claude/hooks/stop.sh` fires on Claude Code's Stop event, detects the active feature (when unambiguous), and appends a timestamped note to that feature's `STATUS.md`. Fail-safe: any error path exits 0 with a stderr diagnostic and no mutation. Idempotent within a 60-second window.
- **Meta outcome** — after B2.a archives, any other project on this machine can pick up the rules-injection hook with two commands, and implement-wave runs in this repo no longer race the linter on STATUS append.

### Non-goals
- Items (4) inline per-task review and (6) `/specflow:review` parallel reviewers — **deferred to feature B2.b** (opens after B2.a archives). Not designed for here.
- **Deep globalization of `.claude/rules/`** — explicitly rejected during brainstorm (Q1=b). Rules stay per-project; each project's own `.claude/rules/` is the source of truth for its own sessions.
- TDD enforcement, strategic compaction hooks, `/specflow:extract` knowledge extraction, dashboard GUI, cross-harness adapters (Cursor / Codex / OpenCode), Claude plugin-marketplace migration.
- Rewriting `bin/claude-symlink`'s existing managed set (`agents/specflow`, `commands/specflow`, `team-memory/**` stay as-is).
- Agent-side structured Stop-event contract (the Stop hook v1 logs a generic timestamped note; richer orchestrator-supplied context is deferred).
- Automated concurrency linter or stricter race detection — v1 uses the 60-second idempotence window and best-effort append.

## 3. User stories

1. **Developer running B2.b's implement stage in this repo.** I want the Stop hook to auto-append a STATUS note when each parallel developer agent finishes, so the orchestrator's subsequent STATUS write doesn't hit "File has been modified since read" from my hand-editing in a stale buffer. Today that race bit every wave in B1; I want it gone for B2.b.
2. **User installing specflow's agents into another project.** I want one command (`bin/claude-symlink install` from this repo) to also make the rules-injection SessionStart hook script available at `~/.claude/hooks/session-start.sh`, then one more command (`bin/specflow-install-hook add SessionStart ~/.claude/hooks/session-start.sh`) inside the consumer project to wire it into that project's `settings.json`. I do **not** want the consumer project to suddenly pick up this repo's rules — the consumer keeps its own `.claude/rules/`.
3. **Contributor updating the Stop hook.** I want to edit `<this-repo>/.claude/hooks/stop.sh`, and every project that symlinked `~/.claude/hooks/` sees the change on the next Stop event — no per-project re-install.
4. **User who never touched specflow.** I want `claude-symlink install` in my own scratch project to leave my existing `~/.claude/hooks/` alone if it isn't a symlink we own (no silent clobber of personal hooks).

## 4. Functional requirements

### Shallow globalize via `bin/claude-symlink` extension (item 7)

**R1 — Third dir-level managed pair.** `bin/claude-symlink`'s `plan_links()` grows a third fixed directory-level pair, appended alongside the existing two:

| index | source | target |
|-------|--------|--------|
| 1 (existing) | `$REPO/.claude/agents/specflow` | `$HOME/.claude/agents/specflow` |
| 2 (existing) | `$REPO/.claude/commands/specflow` | `$HOME/.claude/commands/specflow` |
| 3 (**new**) | `$REPO/.claude/hooks` | `$HOME/.claude/hooks` |

After the three dir-level pairs, the existing `team-memory/**` file-level walk continues unchanged. The managed set documented in the script header comment and `usage()` output must be updated to list the new pair.

**R2 — Post-install state.** After `bin/claude-symlink install`, `~/.claude/hooks/` resolves to `<this-repo>/.claude/hooks/`, and both `~/.claude/hooks/session-start.sh` and `~/.claude/hooks/stop.sh` resolve (via the dir-symlink) to this repo's scripts. Verified by `readlink "$HOME/.claude/hooks"` returning an absolute path under `$REPO/.claude/`.

**R3 — All install / uninstall / update semantics preserved.** The new pair participates in the existing `classify_target` → `apply_plan` dispatch without special-casing. Every state (`missing`, `ok`, `wrong-link-ours`, `broken-ours`, `real-file`, `real-dir`, `wrong-link-foreign`, `broken-foreign`) handles the hooks pair exactly as it handles the two existing dir-level pairs. Idempotent: re-running `install` after success reports `already` for the hooks pair.

**R4 — Uninstall ownership gate.** `claude-symlink uninstall` removes `~/.claude/hooks/` **only** when `owned_by_us` returns true for it (i.e. it is a symlink whose resolved target is under `$REPO/.claude/`). A pre-existing real dir at `~/.claude/hooks/`, or a symlink pointing somewhere else, is reported `skipped:not-ours` and left untouched. This pattern is already enforced by the classify-before-mutate dispatch; R4 just makes the expectation explicit for the new pair.

**R5 — Top-level README updated.** The repo root `README.md` (if present; if not, update the relevant in-repo documentation file that already lists the managed set, e.g. the script header or a dedicated doc) names the third managed dir, explains that hook scripts are globalized but rules remain per-project, and shows the one-command per-project opt-in flow for each event.

**R6 — Per-project opt-in flow (documented).** The documented flow for a consumer project to enable rules-injection is:
```
# one-time per machine, run from this repo:
bin/claude-symlink install

# one-time per consumer project, run from the consumer's repo root:
bin/specflow-install-hook add SessionStart ~/.claude/hooks/session-start.sh

# (optional) enable STATUS auto-sync in the consumer project:
bin/specflow-install-hook add Stop ~/.claude/hooks/stop.sh
```
The consumer project's rules still come from **its own** `.claude/rules/` — the SessionStart hook script walks `<cwd>/.claude/rules/`, not the hook script's own source repo.

**R7 — `bin/specflow-install-hook` operates on `<cwd>/settings.json`.** No code change required; existing behavior already mutates `settings.json` in the working directory. This PRD only requires that the behavior is **documented** (not assumed) in the per-project opt-in instructions, so users understand they must `cd` into the consumer project before running the helper.

**R8 — Hook scripts remain cwd-aware.** Both `session-start.sh` (existing) and `stop.sh` (new per R9) read paths relative to the session's working directory — `<cwd>/.claude/rules/` for the SessionStart hook, `<cwd>/.spec-workflow/features/*/STATUS.md` for the Stop hook. The hook script's own location (which may be a symlink to this repo) is **not** used to locate the rules or feature directories. This is what makes globalization shallow: the script is shared; the content it reads is per-project.

### Stop hook for STATUS sync (item 5)

**R9 — New script `.claude/hooks/stop.sh`.** Pure bash, bash-3.2 portable (no `readlink -f`, `realpath`, `jq`, `mapfile`; see `bash/bash-32-portability` rule). Opens with:
```bash
#!/usr/bin/env bash
set +e
trap 'exit 0' ERR INT TERM
```
Every diagnostic goes to stderr with a prefixed tag (`stop.sh: WARN:` or `stop.sh: INFO:`). The script's final line is an unconditional `exit 0`. No path in the script may call `exit` with a non-zero code.

**R10 — Stop event input contract.** Claude Code passes the Stop event payload on stdin as JSON (same shape convention as SessionStart). The hook parses it defensively: malformed JSON, missing keys, or empty stdin all route to the "no-op, exit 0" path with a stderr diagnostic. Parsing uses Python 3 (per `bash/bash-32-portability` — no `jq`) or simple `awk`/`grep` key sniffs; the PRD does not mandate which (architect's call in 04-tech).

**R11 — Active-feature detection (branch-name match).** The hook determines which feature (if any) is active by reading the current git branch and matching it against feature slugs under `.spec-workflow/features/`. A match exists when the branch name contains any existing feature-slug as a substring, case-sensitive. Resolution rules:
- **Zero matches** → silent skip; exit 0. No STATUS mutation.
- **Exactly one match** → that feature is active; proceed to R12.
- **Multiple matches** → stderr WARN listing the candidates, then silent skip; exit 0. Ambiguity is never resolved by guessing.

Rationale: `/specflow:implement` creates feature branches today, so the branch-name heuristic is the most reliable signal available without an orchestrator-owned hand-off protocol. The alternatives considered (most-recently-modified feature dir; env-var opt-in) were weaker (heuristic sloppy across waves; env-var requires orchestrator changes out of scope). If branch-name match proves insufficient in practice, a richer contract is a B2.b-or-later revisit, not a v1 blocker.

**R12 — STATUS note format and append.** When exactly one feature is active, the hook appends a single line under the feature's `## Notes` heading in `.spec-workflow/features/<slug>/STATUS.md`:
```
- YYYY-MM-DD stop-hook — stop event observed
```
Date is the hook's own wall-clock date (UTC or local; architect's call). The role tag is the literal string `stop-hook` (not an agent role name — keeps the source auditable). The action summary is fixed and generic in v1; richer orchestrator-supplied text is explicitly deferred (see §8).

Append discipline: read the current file content, append the new line after the last existing note, write to `.tmp`, `mv` atomically. Never open-for-append on the live file directly. This is the same pattern `bin/specflow-install-hook` uses for `settings.json` (per `architect/settings-json-safe-mutation`, which governs the settings.json helper — the Stop hook's STATUS.md append follows the same read-write-replace discipline).

**R13 — Idempotence (60-second window).** Before appending, the hook reads the last non-empty line under `## Notes`. If that line starts with `- YYYY-MM-DD stop-hook — stop event observed` **and** the timestamp is within 60 seconds of the hook's current wall-clock time, the hook skips the append (stderr INFO: `dedup: recent stop-hook note within 60s`). This absorbs the most common duplication case (two parallel agents Stop in the same second; Claude Code fires the event twice for framing reasons) without a distributed lock. Two stop-hook notes separated by more than 60 seconds are both kept — the hook intentionally does not compress history.

**R14 — Per-project opt-in wiring.** The consumer project enables the Stop hook via the existing helper:
```
bin/specflow-install-hook add Stop ~/.claude/hooks/stop.sh
```
This is identical in shape to the SessionStart opt-in (R6). No new flag, no new subcommand.

**R15 — Performance budget.** The hook completes within **100 ms** of wall-clock time on a warm cache in the happy path (branch resolves, one feature matches, append succeeds). The budget is a soft target — exceeding it is not a failed AC — but the hook must not perform an unbounded walk (e.g., a `find` across the whole worktree with no prune). Any I/O is confined to reading `HEAD`, listing `.spec-workflow/features/`, and read-modify-write on one `STATUS.md`.

**R16 — Edge cases (silent-skip catalogue).** Each of the following routes to "no mutation, stderr INFO or WARN as noted, exit 0":
- `.git/HEAD` unreadable or not in a git worktree → INFO: `not a git worktree`, skip.
- `.spec-workflow/features/` does not exist → INFO: `no specflow features in cwd`, skip.
- Branch name matches no feature slug → INFO: `branch does not match any feature`, skip.
- Branch matches multiple feature slugs → WARN: `ambiguous: <list>`, skip.
- Matched feature's `STATUS.md` missing → INFO: `STATUS.md not present`, skip.
- Matched feature's `STATUS.md` has no `## Notes` heading → WARN: `no ## Notes heading`, skip.
- Stdin is empty or malformed JSON → INFO: `stdin not a valid Stop payload`, skip.
- Append (tmp-write + rename) fails at the filesystem level → WARN: `append failed: <errno>`, still exit 0.

### Cross-cutting

**R17 — New tests under `test/`.** At minimum:
- `t29_claude_symlink_hooks_pair.sh` — `claude-symlink install` in a sandboxed `$HOME` creates `~/.claude/hooks/` as a symlink to `$REPO/.claude/hooks/`; `uninstall` removes it; `update` reconciles it; all idempotent.
- `t30_stop_hook_happy_path.sh` — in a sandboxed git worktree with one matching feature dir, a synthetic Stop payload on stdin causes exactly one new line to appear under `## Notes` in that feature's `STATUS.md`.
- `t31_stop_hook_failsafe.sh` — malformed JSON on stdin, missing `STATUS.md`, missing `## Notes` heading, non-git cwd — each variant exits 0 with no `STATUS.md` mutation.
- `t32_stop_hook_idempotent.sh` — two Stop invocations within 60 seconds produce exactly one note; a third invocation >60 seconds later produces a second note.
- `t33_claude_symlink_hooks_foreign.sh` — a pre-existing real dir at `~/.claude/hooks/` is reported `skipped:real-dir` by `install` and `skipped:not-ours` by `uninstall`; never mutated.

Every test script begins with the `mktemp -d` sandbox pattern (per `bash/sandbox-home-in-tests` rule), exports `HOME="$SANDBOX/home"`, and preflights `case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac` before any CLI invocation.

**R18 — `bash test/smoke.sh` green.** The existing smoke harness (28 tests from B1) continues to pass, plus the new tests from R17 (29+ total). No regression in existing `claude-symlink` or SessionStart-hook behavior.

## 5. Acceptance criteria

- **AC-symlink-hooks-installed.** After `bin/claude-symlink install` in a sandboxed `$HOME`, `~/.claude/hooks/` is a symlink and `readlink "$HOME/.claude/hooks"` returns an absolute path equal to `<sandbox repo>/.claude/hooks`. Maps to R1, R2.
- **AC-symlink-hooks-idempotent.** Running `install` a second time reports `already` for the hooks pair; no mutation occurs. Maps to R3.
- **AC-symlink-hooks-update.** Running `update` after a clean `install` reports `already` for the hooks pair. Maps to R3.
- **AC-uninstall-removes-hooks-link.** After `install` then `uninstall`, `~/.claude/hooks` does not exist (and the intermediate `~/.claude/` parent was not itself removed if it held other managed links). Maps to R3, R4.
- **AC-uninstall-leaves-foreign.** A pre-existing real dir at `~/.claude/hooks/` survives `claude-symlink install` (reported `skipped:real-dir`) and is not touched by `uninstall` (reported `skipped:not-ours` or silently left — ownership gate). Maps to R4.
- **AC-usage-mentions-hooks.** `bin/claude-symlink --help` output lists `hooks` as a managed directory-level pair. Maps to R1, R5.
- **AC-stop-hook-exists.** `.claude/hooks/stop.sh` exists, has the executable bit set, and `bash -n .claude/hooks/stop.sh` reports clean syntax. Maps to R9.
- **AC-stop-hook-failsafe.** Invoking `.claude/hooks/stop.sh` with each of (empty stdin; malformed JSON; cwd outside a git worktree; branch matches no feature; missing `STATUS.md`; missing `## Notes`) exits 0 and produces no change to any `STATUS.md` under the cwd. Maps to R9, R10, R16.
- **AC-stop-hook-appends.** In a sandboxed git worktree on branch `<date>-<slug>` where `.spec-workflow/features/<slug>/STATUS.md` exists with a `## Notes` section, invoking the hook with a valid Stop payload appends exactly one line matching `- <date> stop-hook — stop event observed` under `## Notes`. Maps to R11, R12.
- **AC-stop-hook-skip-ambiguous.** Branch matches two feature slugs → hook emits a stderr WARN listing both candidates and makes no STATUS mutation. Maps to R11.
- **AC-stop-hook-idempotent.** Two invocations within 60 seconds of each other on the same branch produce exactly one new line under `## Notes`. A third invocation at least 61 seconds later produces a second line. Maps to R13.
- **AC-per-project-wiring-docs.** Project README (or equivalent documented file) contains the three-command flow from R6 verbatim enough that a grep for `specflow-install-hook add SessionStart` and `specflow-install-hook add Stop` both find the documented flow. Maps to R5, R6, R14.
- **AC-stop-hook-performance.** A single happy-path invocation of `.claude/hooks/stop.sh` completes in under 100 ms wall-clock on the test harness (measured by `/usr/bin/time` or equivalent; not strict under heavy system load — target, not gate). Maps to R15.
- **AC-tests-added.** `test/` contains the five new scripts listed in R17, each executable, each beginning with the sandbox + preflight pattern. Maps to R17.
- **AC-no-regression.** `bash test/smoke.sh` passes green after the feature lands, including both existing tests and the new ones from R17. Maps to R18.

## 6. Edge cases

- **Third dir-level pair changes plan count.** Existing tests that assert a specific number of planned links (if any) must be updated to account for the third pair. `apply_plan` iterates PLAN_SRC/PLAN_TGT without hardcoded counts, so behavior is correct; only test expectations may need adjusting.
- **Stop hook misfires on non-implement Stop events.** Every Stop event — not just implement-wave completions — invokes the hook. R11's branch-name match acts as the de-facto filter: any Stop event on a non-feature branch silently skips. Accepted: a dev pairing on a feature branch in an unrelated Claude Code session will get spurious stop-hook notes. v1 accepts this noise; post-ship measurement decides whether to tighten.
- **Concurrent Stop events from parallel wave agents.** N developer agents in a wave Stop near-simultaneously; each fires its own Stop hook invocation. R13's 60-second dedup absorbs the common case. The rename-based atomic write (R12) ensures no partially-written `STATUS.md`; worst case, last-writer-wins on near-simultaneous appends (losing one of N nearly identical notes — acceptable, because they would have been deduped anyway).
- **Branch name is a substring of multiple slugs.** e.g. branch `feature-hooks` when features `20260417-shareable-hooks` and `20260420-hooks-v2` both exist. R11's "multiple matches → skip" handles this. The user sees a stderr WARN and can disambiguate by picking a more specific branch name.
- **Consumer project doesn't have `bin/specflow-install-hook` locally.** The helper lives in *this* repo; consumer projects that don't check it out must call it by absolute path, e.g. `~/tools/spec-workflow/bin/specflow-install-hook add SessionStart …`. The per-project docs (R5, R6) must spell this out.
- **Repo root `settings.json` in this repo vs. consumer project's `settings.json`.** `bin/specflow-install-hook` always mutates `<cwd>/settings.json`. Running it from *this* repo wires *this* repo's settings; running it from a consumer's repo root wires theirs. The helper does not care which — R7 just requires the docs make this clear.
- **Git worktrees / submodules under `.spec-workflow/features/`.** If a feature dir is actually a submodule or worktree pointing elsewhere, the hook's append still targets the local `STATUS.md`. Not a special case; standard filesystem behavior.
- **`.claude/hooks/` already symlinked by us, and the repo moves.** An existing `~/.claude/hooks` symlink whose resolved target no longer exists (because the user moved or renamed this repo) classifies as `broken-ours`; `install` or `update` replaces it with a fresh absolute-target link to the new location. This is the same self-healing contract as the existing two dir pairs (see `common/absolute-symlink-targets`).

## 7. Open questions / blockers

**None — all candidates resolved inline:**

- _Which feature is active? (branch-name vs. recency vs. env-var)_ — resolved R11 to **branch-name match**; single match → append, multiple → skip, zero → skip. Rationale documented in R11.
- _STATUS-write atomicity under concurrent waves_ — resolved R12 / R13 to **tmp-write + atomic rename + 60-second dedup window**. No distributed lock needed for v1; acceptable-loss semantics.
- _Stop hook payload richness_ — resolved R12 to **fixed generic note**; richer orchestrator-supplied text deferred to §8.
- _JSON parsing in `stop.sh`_ — resolved R10 to **python3 or awk/grep; architect's call in 04-tech**. Both are bash-3.2-portable and already sanctioned elsewhere in the harness.

## 8. Out of scope

(Restated from `00-request.md` plus items resolved during PRD that are now explicitly deferred.)

- Items (4) inline per-task reviewer and (6) `/specflow:review` parallel reviewer team — **B2.b** (opens after B2.a archives).
- **Deep globalization of `.claude/rules/`** — rejected Q1=b; rules stay per-project.
- Porting Superpowers skills, wshobson plugin-marketplace format, everything-claude-code MCP configs.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- TDD enforcement, strategic compaction hooks, `/specflow:extract`, dashboard GUI — tier 3 backlog.
- Rewriting `bin/claude-symlink`'s existing managed set (`agents/specflow`, `commands/specflow`, `team-memory/**` stay as-is).
- Versioning `.claude/rules/` or `.claude/hooks/` — hook edits apply on next Stop/SessionStart event; no re-run mechanism.
- Orchestrator-supplied rich STATUS context in Stop hook — v1 logs a generic note; richer integration (role name, task id, PRD requirement id) is a future revision once the v1 plumbing proves out.
- Automated linter for "performative `stop-hook` note" (notes that fire but contribute no signal) — deferred to telemetry-maturity phase.
- `--force` on any path — continues to be explicitly forbidden by `common/no-force-on-user-paths`; the hooks pair inherits the same skip-and-report discipline via the existing classify-before-mutate dispatch.
- Any new slash command. `/specflow:review` naming is reserved for B2.b; this feature must not preempt it.
