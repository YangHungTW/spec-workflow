# Tech — shareable-hooks (B2.a)

_2026-04-17 · Architect_

## Team memory consulted

- `architect/hook-fail-safe-pattern.md` — **load-bearing**: the new `.claude/hooks/stop.sh` is the second instance of a lifecycle hook in this repo and must carry the exact discipline B1 established (`set +e`, `trap 'exit 0' ERR INT TERM`, stderr-only diagnostics, unconditional final `exit 0`, `HOOK_TEST=1` test-mode gate). D1 / D6 below are direct applications.
- `architect/settings-json-safe-mutation.md` — applies transitively: this feature does not itself touch `settings.json`, but the per-project opt-in flow documented here (R6) relies on `bin/specflow-install-hook`'s D12-shape read-merge-write. No change to that helper; just documenting the hand-off.
- `architect/no-force-by-default.md` — applies to the new dir-level symlink pair (`~/.claude/hooks/`): pre-existing real dir / foreign symlink at `~/.claude/hooks/` must report-and-skip, never clobber (AC-uninstall-leaves-foreign). The existing `classify_target` → `apply_plan` dispatch already enforces this; the new pair participates without special-casing.
- `architect/classification-before-mutation.md` — applies twice:
  1. `bin/claude-symlink`'s existing 8-state classifier (the new pair slots in).
  2. The Stop hook's "should I append?" decision is itself a classify-before-mutate: classify the current environment into a closed enum (`not-git | no-specflow | no-match | ambiguous | ok-<slug>`) **before** opening `STATUS.md` for write.
- `architect/shell-portability-readlink.md` — both `stop.sh` and the `claude-symlink` edit stay on the macOS bash 3.2 / BSD floor. No `readlink -f`, no `jq`, no `mapfile`, no `[[ =~ ]]` where portability matters. `python3` is allowed only on the install path (never on the hook runtime path), matching D1/D12 precedent.
- `architect/script-location-convention.md` — `bin/` is for user-facing CLIs; Claude Code infrastructure scripts live in `.claude/hooks/`. D1 places `stop.sh` under `.claude/hooks/` alongside `session-start.sh` — no new `bin/` entry. The third managed dir-level pair in `bin/claude-symlink` is the user-facing surface that globalizes this hook dir.
- `shared/` (both tiers) — empty; nothing to pull.

---

## 1. Context & Constraints

### Existing stack (what's already in the repo)
- **Pure bash tooling** — `bin/claude-symlink` (dir+file managed-set installer, 8-state classifier, macOS 3.2 floor), `bin/specflow-install-hook` (D12 read-merge-write helper for `settings.json`).
- **One live hook** — `.claude/hooks/session-start.sh` (B1 D1/D7): SessionStart event, reads `<cwd>/.claude/rules/`, emits JSON digest, fail-safe `exit 0`. Exactly the template the Stop hook must mirror.
- **Repo-root `settings.json`** — B1 D2/D12 created it. This feature does not touch it.
- **Test harness** `test/smoke.sh` — 28 tests post-B1 (from STATUS: t1–t28). R17 adds 5 more (t29–t33).

### Hard constraints
- **macOS bash 3.2 + BSD userland floor** (memory `shell-portability-readlink`; project rule `bash/bash-32-portability`). No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `flock`. BSD `date -j -f …` on mac, GNU `date -d …` on Linux — dispatch by `uname -s`.
- **Hook fail-safe** (memory `hook-fail-safe-pattern`, B1 D1, PRD R9). `set +e`, `trap 'exit 0' ERR INT TERM`, stderr-only diagnostics, unconditional final `exit 0`. No exit-non-zero path anywhere in `stop.sh`.
- **No `--force` on user-owned paths** (memory `no-force-by-default`; project rule `common/no-force-on-user-paths`). New `hooks/` symlink pair inherits the existing dispatch: `skipped:real-dir`, `skipped:foreign-symlink`, `skipped:not-ours` are the terminal verbs for any non-owned target. No new flag.
- **Zero install footprint** — no Node, no Python in the hook's runtime path. `python3` permitted only on the `specflow-install-hook` install path (B1 D12, unchanged). `stop.sh` itself is pure bash + POSIX `awk`/`sed`/`grep`/`date`.
- **Backward compatibility** — `bash test/smoke.sh` (28 existing tests) stays green. No behavior change for the existing two dir-level pairs (`agents/specflow`, `commands/specflow`) or the `team-memory/**` file walk.

### Soft preferences
- **Minimize diff to `bin/claude-symlink`** — the 8-state classifier is well-tested; the new pair slots in with zero classifier changes, two lines in `plan_links()`, and a usage-string update. Anything more is scope creep.
- **Mirror B1 hook conventions** — `stop.sh` uses the same log prefix (`stop.sh: WARN:` / `stop.sh: INFO:`) and the same `HOOK_TEST=1` env var gate as `session-start.sh`. Contributor muscle memory > cleverness.
- **Cwd-aware hooks** — both hooks read `<cwd>/.claude/rules/` and `<cwd>/.spec-workflow/features/*/STATUS.md`, never paths derived from their own (possibly-symlinked) install location. This is what makes globalization shallow (PRD R8) and must not regress.

### Forward constraints (must not make B2.b harder)
- **Stop-hook payload enrichment** — PRD §8 explicitly defers orchestrator-supplied rich context (role name, task id, PRD req id). v1 payload is fixed generic text (D5 below). The parser in `stop.sh` reads minimal fields from stdin and logs the raw payload on stderr in `HOOK_TEST=1` mode; B2.b can grow the payload without touching the stdin parser if it stays JSON.
- **Per-project reviewer rubric (B2.b item 4)** — will consume `<cwd>/.claude/rules/` just as `session-start.sh` does. The cwd-aware contract (R8) is the reason that will work transparently.

---

## 2. System Architecture

### Components

```
+----------------------------+          +----------------------------+
| Claude Code session start  | <------- | <consumer>/settings.json   |
|   (any project)            |          |   hooks.SessionStart[]     |
+-------------+--------------+          |   hooks.Stop[]             |
              |                         +-------------+--------------+
              |                                       |
              v                                       v
   +---------------------+               +------------------------+
   | ~/.claude/hooks/    |  (symlink)    |  <consumer>/settings   |
   |   session-start.sh  +---> /Tools/spec-workflow/.claude/hooks/
   |   stop.sh           |               |   session-start.sh     |
   +---------------------+               |   stop.sh              |
              |                          +-----------+------------+
              |                                      |
              |                                      |  reads
              v                                      v
   +------------------------+     +-----------------------------+
   | cwd = <consumer repo>  |<----| <consumer>/.claude/rules/   |
   |                        |     | <consumer>/.spec-workflow/  |
   |                        |     |   features/<slug>/STATUS.md |
   +------------------------+     +-----------------------------+


Globalization pipeline (one-time per machine):

   bin/claude-symlink install
      │
      ├─ plan_links() emits 3 dir-level pairs (was 2)
      │    (1) agents/specflow
      │    (2) commands/specflow
      │    (3) hooks            ← NEW (this feature)
      ├─ + file-level team-memory/** walk (unchanged)
      │
      └─ apply_plan() — existing classify → dispatch table,
                       no new arms, no special-casing
```

### Data flow — key PRD scenarios

**Scenario A — Globalize hooks (PRD §4 / R1–R5, AC-symlink-hooks-installed).**
1. User runs `bin/claude-symlink install` from this repo (first time, any machine).
2. `plan_links()` populates `PLAN_SRC` / `PLAN_TGT` with three dir-level pairs (new: `hooks`) then walks `team-memory/**`.
3. `apply_plan()` classifies `$HOME/.claude/hooks` via the existing 8-state classifier: `missing` → create symlink with absolute target `$REPO/.claude/hooks`.
4. `readlink "$HOME/.claude/hooks"` now resolves to `$REPO/.claude/hooks`. Both `session-start.sh` and `stop.sh` are reachable via `~/.claude/hooks/<name>`.

**Scenario B — Consumer project opts into Stop hook (PRD R6, R14).**
1. Consumer `cd`s into their own repo root.
2. Runs `bin/specflow-install-hook add Stop ~/.claude/hooks/stop.sh` (absolute path: the helper lives in this repo; consumer invokes it by absolute path if not checked out locally — see PRD §6 edge case).
3. Helper (unchanged, B1 D12) read-merge-writes `<consumer>/settings.json` with an idempotent Stop entry.
4. Next Claude Code session in the consumer sees Stop events routed through `~/.claude/hooks/stop.sh` (symlink) → `<this-repo>/.claude/hooks/stop.sh` (real file), but **cwd is the consumer repo**, so the hook reads the consumer's `.spec-workflow/features/` — not this repo's.

**Scenario C — Stop hook fires at end of an agent turn (PRD R9–R16, AC-stop-hook-appends).**
1. Claude Code sends Stop event JSON on stdin.
2. `stop.sh` classifies the environment into a closed enum (D3 below):
   - `not-git` / `no-specflow` / `no-notes-heading` / `no-status` / `no-match` / `ambiguous` → stderr diagnostic, exit 0 (no mutation).
   - `ok-<slug>` → proceed.
3. Dedup check (D4): read tail of `## Notes`, compare timestamp to current wall clock. If within 60s of a prior stop-hook note → skip (stderr INFO), exit 0.
4. Append (D3 discipline): read `STATUS.md`, splice new line, write `STATUS.md.tmp`, `mv` atomically, exit 0.

### Module boundaries

- **`.claude/hooks/stop.sh`** — new, pure bash. Reads stdin + `<cwd>/.git/HEAD` + `<cwd>/.spec-workflow/features/*/STATUS.md`. Writes exactly one file (one `STATUS.md`) via `.tmp`+`mv`. Writes stderr diagnostics. **Never** writes anything else. **Never** calls network, **never** reads anything outside `<cwd>` (except stdin).
- **`bin/claude-symlink`** — edited to add one dir-pair in `plan_links()` and update `usage()` text. `classify_target`, `owned_by_us`, `apply_plan`, `cmd_install`, `cmd_uninstall`, `cmd_update`, the probe harness — **all unchanged**. The new pair goes through the same code paths as the existing two dir-pairs.
- **`bin/specflow-install-hook`** — unchanged. Per-project opt-in wiring uses the existing `add Stop <cmd>` flow (B1 D12).
- **`.claude/hooks/session-start.sh`** — unchanged. Mentioned here because the new `stop.sh` reuses its log-prefix and test-mode conventions; neither script calls the other.

---

## 3. Technology Decisions

### D1. Stop hook script location & language — `.claude/hooks/stop.sh`, pure bash
- **Options considered**: (A) `.claude/hooks/stop.sh` (sibling of `session-start.sh`), (B) new `bin/specflow-stop-hook`, (C) single dispatcher script at `.claude/hooks/dispatch.sh` keyed by event name.
- **Chosen**: **A. `.claude/hooks/stop.sh`**, pure bash, bash 3.2 compatible, BSD userland only.
- **Why**: Memory `script-location-convention` — `bin/` is for user-facing CLIs; Claude Code lifecycle hooks are infrastructure and live under `.claude/hooks/`. B1 D2 committed to "one script per event" precisely so B2 adds siblings without editing the SessionStart dispatcher. PRD R9 mandates bash + bash-32 floor. Memory `hook-fail-safe-pattern` applies verbatim.
- **Tradeoffs accepted**: slight duplication of the fail-safe header across `session-start.sh` and `stop.sh` (~5 lines). Acceptable — each script is <150 lines and has its own fail-safe boundary. Extracting a shared helper is a B2+ refactor if a third event ever lands.
- **Reversibility**: **high** — collapse to a dispatcher later is a localized refactor; no caller knows the script path except `settings.json` entries.
- **Requirement link**: R9, and B1 D2 forward-compat.

**Script skeleton (exact header):**

```bash
#!/usr/bin/env bash
# .claude/hooks/stop.sh
# Stop hook: detect active feature (branch-name match) → append note to STATUS.md
# Fail-safe: any error → WARN to stderr + exit 0. Never blocks session Stop.

set +e
trap 'exit 0' ERR INT TERM

log_warn() { printf 'stop.sh: WARN: %s\n' "$1" >&2; }
log_info() { printf 'stop.sh: INFO: %s\n' "$1" >&2; }
```

### D2. Stop event stdin parsing — awk/sed key sniff, no `jq`, no `python3`
- **Options considered**: (A) `jq` (rejected — not in floor per `shell-portability-readlink`), (B) `python3 -c "import json, sys; ..."` one-shot, (C) `awk`/`grep` single-key sniff, (D) ignore stdin entirely and treat every invocation as generic.
- **Chosen**: **C. awk/grep sniff**, with D as the fallback if stdin is empty/malformed.
- **Why**: The Stop hook's v1 behavior (PRD R12) appends a **fixed generic note** — the payload's concrete fields are not used to synthesize the note text. We need to detect "stdin is a plausible JSON object" and log the raw payload under `HOOK_TEST=1` for forward-compat debugging. That's two cheap `awk` operations. Adding `python3` to the hook's runtime path would be a regression vs B1 D1's "pure bash hook" constraint; the install path already has `python3` (D12), but the hook must not.
- **Tradeoffs accepted**: we parse nothing structural from the payload today. Fine — PRD §8 defers rich payload consumption to a later revision. When that lands, the parse step can grow (still bash + awk) without changing the script's fail-safe boundary.
- **Reversibility**: **high** — the parse is one function; swap its guts later.
- **Requirement link**: R10.

**Parse discipline:**

```bash
# Read stdin defensively (empty stdin is valid — classify as no-payload).
raw_payload=$(cat 2>/dev/null)

if [ "${HOOK_TEST:-0}" = "1" ]; then
  # Test mode: dump raw payload for inspection, don't mutate.
  log_info "test-mode raw payload: $(printf '%s' "$raw_payload" | head -c 200)"
fi

# Minimal shape sniff: a JSON object starts with '{'. Anything else is no-payload.
# (We don't require any specific key — PRD R12 is fixed generic.)
case "$raw_payload" in
  '{'*) ;; # plausible JSON object; proceed
  *) log_info "stdin not a valid Stop payload"; exit 0 ;;
esac
```

### D3. Active-feature detection — branch-name substring match, closed enum
- **Options considered**: (A) most-recently-modified feature dir, (B) branch-name substring match, (C) env var opt-in (`SPECFLOW_ACTIVE_FEATURE=<slug>`), (D) hybrid (env var wins, fall back to branch).
- **Chosen**: **B. branch-name substring match**, resolved in PRD R11. No env var dependency in v1.
- **Why**: `/specflow:implement` creates feature branches today; branch name is the most reliable signal without an orchestrator-owned hand-off protocol. Recency heuristic is sloppy across waves; env var requires orchestrator changes that PRD §8 defers. Memory `classification-before-mutation` applies: we classify the environment into a closed enum **before** any write.
- **Tradeoffs accepted**: a dev pairing on a feature branch in an unrelated Claude Code session will get spurious stop-hook notes (PRD §6 accepts). Multiple-substring-match case is silently skipped with a WARN — ambiguity is never resolved by guessing.
- **Reversibility**: **high** — the detector is one function returning a state string; swap later.
- **Requirement link**: R11, R16.

**Classifier (pure function, no side effects):**

```bash
# classify_env — pure classifier; stdout emits exactly one of:
#   not-git | no-specflow | no-match | ambiguous | ok:<slug>
# No mutations. No stderr. Caller logs the diagnostic based on returned state.
classify_env() {
  # Git-worktree check (portable — no readlink -f, no git rev-parse --is-inside-work-tree assumption)
  if [ ! -r ".git/HEAD" ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'not-git'
    return
  fi

  # specflow features dir check
  if [ ! -d ".spec-workflow/features" ]; then
    printf 'no-specflow'
    return
  fi

  # Current branch — prefer git symbolic-ref (bash 3.2 safe, no --show-current floor)
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    # Detached HEAD or other edge case — treat as no-match
    printf 'no-match'
    return
  fi

  # Walk features/, collect slugs whose name is a substring of the branch.
  # Avoid `[[ =~ ]]` for portability; use case-glob.
  local matches=""
  local match_count=0
  local f
  for f in .spec-workflow/features/*/; do
    [ -d "$f" ] || continue
    local slug
    slug=$(basename "$f")
    case "$branch" in
      *"$slug"*)
        matches="$matches $slug"
        match_count=$((match_count + 1))
        ;;
    esac
  done

  if [ "$match_count" -eq 0 ]; then
    printf 'no-match'
  elif [ "$match_count" -eq 1 ]; then
    printf 'ok:%s' "${matches# }"
  else
    printf 'ambiguous:%s' "${matches# }"
  fi
}
```

**Dispatch (mutation happens here, nowhere else):**

```bash
state=$(classify_env)
case "$state" in
  not-git)           log_info "not a git worktree"; exit 0 ;;
  no-specflow)       log_info "no specflow features in cwd"; exit 0 ;;
  no-match)          log_info "branch does not match any feature"; exit 0 ;;
  ambiguous:*)       log_warn "ambiguous: ${state#ambiguous:}"; exit 0 ;;
  ok:*)              slug="${state#ok:}" ;;  # fall through to D4 dedup + D3 append
  *)                 log_warn "unknown classify_env state: $state"; exit 0 ;;
esac
```

### D4. Dedup window — 60s, BSD/GNU date split
- **Options considered**: (A) no dedup (let duplicates accumulate), (B) hash-based dedup over the message tail, (C) time-window dedup with last-note timestamp parse, (D) fcntl/mkdir lockfile for cross-process serialization.
- **Chosen**: **C. 60-second time-window** per PRD R13. BSD/GNU `date` dispatch by `uname -s`.
- **Why**: PRD R13 fixes the semantics (60s, last-note tail, stop-hook-prefixed). Lockfiles (D) add bash 3.2 portability complexity (`flock` not available; `mkdir` works but has cleanup concerns); tmp-write + atomic `mv` (D3's append discipline) already guarantees no partial writes — last-writer-wins is acceptable per PRD §6. Hash-based dedup (B) is scope creep for a fixed generic payload.
- **Tradeoffs accepted**: two `date` dialects means a 4-line dispatch. BSD/GNU detection via `uname -s` is already idiomatic in the repo; the cost is trivial. Clock skew between parallel agents on the same machine is negligible.
- **Reversibility**: **high** — dedup is one function; swap to lockfile-based later if contention bites.
- **Requirement link**: R13.

**Date dispatch (bash 3.2 safe):**

```bash
# to_epoch "YYYY-MM-DD HH:MM:SS" → integer seconds on stdout
# Cross-platform: BSD date on macOS (-j -f), GNU date on Linux (-d).
to_epoch() {
  local ts="$1"
  case "$(uname -s)" in
    Darwin|*BSD)  date -j -f "%Y-%m-%d %H:%M:%S" "$ts" +%s 2>/dev/null ;;
    Linux|*)      date -d "$ts" +%s 2>/dev/null ;;
  esac
}
```

**Dedup check (reads last 5 notes to cap work; matches last stop-hook line):**

```bash
# within_60s "<STATUS.md path>" → returns 0 if a stop-hook note within 60s exists
within_60s() {
  local status="$1"
  local now_epoch
  now_epoch=$(date +%s)

  # Tail the last non-blank stop-hook line under ## Notes (scan last 20 lines is enough)
  local last_line
  last_line=$(awk '
    /^## Notes/ { in_notes=1; next }
    in_notes && /^## / { in_notes=0 }
    in_notes && /- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].*stop-hook/ { last=$0 }
    END { print last }
  ' "$status" 2>/dev/null)

  [ -z "$last_line" ] && return 1

  # Extract the YYYY-MM-DD from the line; treat day-only timestamps as midnight.
  # (PRD R12 payload is date-only; the 60s window is meaningful only when two Stop
  # events fall in the same day — the tail comparison degenerates correctly.)
  local ts_date
  ts_date=$(printf '%s' "$last_line" | awk '{print $2}')
  local last_epoch
  last_epoch=$(to_epoch "$ts_date 00:00:00")

  [ -z "$last_epoch" ] && return 1

  # Same-day check: if the last stop-hook note is from today and written in the
  # last 60s window, skip. Because PRD R12 is date-only, we use a sentinel file
  # `.spec-workflow/features/<slug>/.stop-hook-last-epoch` to record the precise
  # wall-clock of the last append and gate off that. The sentinel is written
  # atomically (echo → tmp → mv) in the same append step.
  local sentinel="$(dirname "$status")/.stop-hook-last-epoch"
  if [ -r "$sentinel" ]; then
    local prior
    prior=$(cat "$sentinel" 2>/dev/null)
    if [ -n "$prior" ] && [ $((now_epoch - prior)) -lt 60 ]; then
      return 0
    fi
  fi
  return 1
}
```

**Why the sentinel**: PRD R12 mandates a date-only payload (`- YYYY-MM-DD stop-hook — stop event observed`), so the STATUS.md note text does not carry HH:MM:SS. The 60s dedup window (R13) needs sub-minute precision. A per-feature sentinel file (`<feature>/.stop-hook-last-epoch` — hidden, never committed intentionally; listed in `.gitignore` if needed) records the last epoch atomically alongside the append, and the sentinel is read by the dedup check before the next append. This keeps the STATUS.md format clean (the user-visible contract) while giving dedup the precision it needs. Single-slot file, overwritten per append, never versioned.

### D5. Stop hook payload — fixed generic date-stamped note
- **Options considered**: (A) date + time + role + task id + PRD req id (rich), (B) fixed generic date-stamped string per PRD R12, (C) blank timestamp (count-only).
- **Chosen**: **B. fixed generic per PRD R12**: `- YYYY-MM-DD stop-hook — stop event observed`.
- **Why**: PRD R12 binds the format exactly. Richer orchestrator-supplied context is explicitly deferred to §8 (post-v1 revision). Generic text is auditable (`grep stop-hook`) and keeps the hook decoupled from any agent-side protocol that doesn't exist yet.
- **Tradeoffs accepted**: two Stop events on the same day (>60s apart) produce two identical lines. Acceptable — visual duplication is a mild cost; changing the format mid-v1 is worse.
- **Reversibility**: **high** — the printf template is one line.
- **Requirement link**: R12.

**Append discipline (memory `settings-json-safe-mutation` pattern, STATUS.md variant):**

```bash
# append_note "<status-path>" "<slug>"
append_note() {
  local status="$1" slug="$2"
  local today
  today=$(date +%Y-%m-%d)

  # Read current file; refuse to write if no ## Notes heading (R16 edge case).
  if ! grep -q '^## Notes' "$status" 2>/dev/null; then
    log_warn "no ## Notes heading in $status"
    return
  fi

  local tmp="${status}.tmp"
  # Use awk to insert the new line at end-of-file (after the last ## Notes line block)
  # Simpler: just `printf` append via read-whole + write-whole (atomic via mv)
  {
    cat "$status"
    printf -- '- %s stop-hook — stop event observed\n' "$today"
  } > "$tmp" 2>/dev/null || { log_warn "tmp write failed"; rm -f "$tmp"; return; }

  mv "$tmp" "$status" 2>/dev/null || { log_warn "atomic swap failed"; rm -f "$tmp"; return; }

  # Record sentinel for D4 dedup
  local sentinel="$(dirname "$status")/.stop-hook-last-epoch"
  local sentinel_tmp="${sentinel}.tmp"
  date +%s > "$sentinel_tmp" 2>/dev/null && mv "$sentinel_tmp" "$sentinel" 2>/dev/null
}
```

### D6. Test mode — `HOOK_TEST=1` env gate
- **Options considered**: (A) `--dry-run` flag (rejected — the hook has no arg parser; env is simpler), (B) `HOOK_TEST=1` env, (C) sniff `TERM` or `CI` (rejected — too indirect).
- **Chosen**: **B. `HOOK_TEST=1`**, matching B1's `session-start.sh` precedent exactly.
- **Why**: Contributor muscle memory. One env var gates both hooks' test mode identically. Under test mode, the hook dumps what it **would** append to stderr (as INFO) and does not mutate `STATUS.md`. The mutation path is still exercised structurally (classify, dedup lookup, compute the line) but `append_note` early-returns.
- **Tradeoffs accepted**: nothing meaningful; env-var test modes are idiomatic.
- **Reversibility**: **high** — gate is one `if` in `append_note`.
- **Requirement link**: R9 (fail-safe discipline); test harness convenience.

**Gate shape:**

```bash
if [ "${HOOK_TEST:-0}" = "1" ]; then
  log_info "test-mode would append: - $today stop-hook — stop event observed to $status"
  return   # from append_note; no mutation
fi
```

### D7. `bin/claude-symlink` extension — two-line addition in `plan_links()`
- **Options considered**: (A) add the pair as a third fixed entry before the team-memory walk, (B) parameterize `plan_links()` to accept a list of dir-pairs, (C) add a new `plan_hooks_pair()` helper.
- **Chosen**: **A. add the pair as a third fixed entry**, mirroring the existing two-entry shape.
- **Why**: Memory `classification-before-mutation` is already honored by the existing 8-state classifier; the new pair participates without special-casing. Memory `no-force-by-default` is already honored by the existing skip-table. There is no justification for parameterizing (B) when v2 has not yet revealed a second new pair; YAGNI. Helper (C) adds a function for two lines — worse than inlining.
- **Tradeoffs accepted**: `plan_links()` grows from ~20 lines to ~22. Trivial. The alternative (a helper) would grow the file more and split related logic across two spots.
- **Reversibility**: **high** — remove two lines to uninstall.
- **Requirement link**: R1, R2, R3.

**Concrete diff in `plan_links()`** (insert between existing "Fixed pair 2" block and the `team-memory` walk):

```bash
  # Fixed pair 2: commands/specflow
  PLAN_SRC+=("$REPO/.claude/commands/specflow")
  PLAN_TGT+=("$HOME/.claude/commands/specflow")

+ # Fixed pair 3: hooks (NEW, feature 20260417-shareable-hooks)
+ PLAN_SRC+=("$REPO/.claude/hooks")
+ PLAN_TGT+=("$HOME/.claude/hooks")
+
  # File-level pairs: walk team-memory with -print0 for filename safety
```

Nothing else in `bin/claude-symlink` requires edits for planning. **However**, two existing hard-coded spots enumerate the dir-pairs for uninstall / usage:
1. `cmd_uninstall`'s `dir_links=(...)` array (currently two entries — lines ~656–658). Add `"$HOME/.claude/hooks"` as a third entry so uninstall's Step 1 covers it.
2. `usage()`'s `Managed set:` block (lines ~427–429). Add a `hooks` row with the same shape.

These are not refactors — they are the symmetric edits that match the `plan_links()` addition. D7 is the complete list of edit sites. No other function changes.

### D8. README / `--help` text — enumerate 3 dir-level pairs
- **Options considered**: (A) update `usage()` only, (B) update `usage()` + top-of-file header comment + top-level `README.md` (if present) or equivalent docs, (C) leave undocumented and let users discover.
- **Chosen**: **B. update all three locations** where the managed set is enumerated today.
- **Why**: PRD R5 requires a documented flow (`AC-usage-mentions-hooks` greps `--help` output). PRD R6 requires the three-command per-project opt-in flow be grep-findable. The script header comment enumerates the set authoritatively; `usage()` echoes it; a top-level doc (README.md if present, else the in-repo docs file that already lists the managed set — see the script header block itself at lines 23–28) must stay in sync. Out-of-sync docs are worse than no docs.
- **Tradeoffs accepted**: three edit sites to keep synced. Mitigated by `t29`'s grep check and a future `tests/doc-sync.sh` (B2.b scope, not mandated here).
- **Reversibility**: **high** — doc-only edits.
- **Requirement link**: R5, R6, and AC-usage-mentions-hooks, AC-per-project-wiring-docs.

### D9. Backward compatibility — existing installs self-heal via `update`
- **Options considered**: (A) ship a `migrate` subcommand, (B) rely on the existing `update` self-healing contract, (C) prompt the user to uninstall + reinstall.
- **Chosen**: **B. rely on `update`**.
- **Why**: `claude-symlink update` already classifies every planned pair and converges `missing → created`. An existing install (before this feature) has two live symlinks under `~/.claude/` and no hooks pair; running `update` on the new binary sees `hooks` as `missing` and creates it. No migration code needed. PRD §6 lists this as the self-healing contract for the existing two pairs — the new pair inherits it.
- **Tradeoffs accepted**: users who never run `update` will never get the hooks symlink until they do. Acceptable — they explicitly opted out of the sync. Documentation (D8) mentions this in the `update` line.
- **Reversibility**: **n/a** (no code to revert).
- **Requirement link**: R1, R3, PRD §6 self-healing.

---

## 4. Cross-cutting Concerns

### Error handling strategy
- **`stop.sh`**: `set +e` at the top, `trap 'exit 0' ERR INT TERM`, every external command call followed by a `|| { log_warn …; return; }` or `|| exit 0` pattern. No `set -e` / `set -u` anywhere. Final line of the script is a literal `exit 0` (belt + suspenders with the trap). Every path that might fail to write (`>`, `mv`, `cat`) is guarded and degrades to a stderr WARN.
- **`classify_env`**: pure function, returns a state string via stdout. No early exits. No logging. Dispatch table at the call site is the sole place that emits stderr based on state.
- **`bin/claude-symlink` edit**: inherits the existing error model. No new error paths introduced. The new pair flows through the same `MAX_CODE` accumulator and `emit_summary` as the existing pairs.

### Logging / tracing / metrics
- **stop.sh stderr**: one line per decision, format `stop.sh: <LEVEL>: <message>`. Levels: `WARN` (ambiguous branch, failed tmp write, missing `## Notes` heading) and `INFO` (not-git / no-specflow / no-match / dedup-skip / test-mode).
- **stop.sh stdout**: nothing in normal operation. Stop hook does not emit `hookSpecificOutput` JSON — Stop events don't inject context. (Contrast with SessionStart which does.)
- **claude-symlink output**: unchanged — same `report "<verb>" "<tgt>" "<src>"` discipline, same `emit_summary` line. Users see one new row per invocation (`created  $HOME/.claude/hooks  ←  $REPO/.claude/hooks`).
- **No metrics pipeline** — 100ms SLA (R15) is a soft target, measured by `/usr/bin/time` in `t30` for spot-check only.

### Security / authn / authz posture
- **No secrets** — stop.sh reads stdin + git metadata + feature dirs + STATUS.md; writes one `STATUS.md` and one sentinel file under `<cwd>/.spec-workflow/features/<slug>/`. Never networks, never shells out to anything that does.
- **Path confinement** — stop.sh writes only under `<cwd>/.spec-workflow/features/<slug>/`. If `<slug>` came from user-controlled branch-name content, the `case "$branch" in *"$slug"*)` check is evaluated against **existing** feature dirs — a malicious branch name can at most cause a stop-hook note to be written to a feature dir that already exists. It cannot cause file creation outside `<cwd>/.spec-workflow/features/`.
- **STATUS.md injection** — the appended line contains only a wall-clock date and fixed literal text (PRD R12). No user-controlled content is interpolated into the note. Safe.
- **Symlink extension** — new `hooks` dir-pair is created with an **absolute** target via `ln -s "$REPO/.claude/hooks" "$HOME/.claude/hooks"` (project rule `common/absolute-symlink-targets`). Repo relocation = broken link = re-run `install` / `update` (same self-heal as existing two pairs).

### Testing strategy (feeds Developer's TDD)

| Test | Level | What it asserts | Maps to AC |
|---|---|---|---|
| `t29_claude_symlink_hooks_pair.sh` | integration | In sandbox `$HOME`, `install` creates `~/.claude/hooks` as symlink → `$REPO/.claude/hooks`; `install` again reports `already`; `uninstall` removes it; `update` reconciles; `--dry-run` reports `would-create`. | AC-symlink-hooks-installed, AC-symlink-hooks-idempotent, AC-symlink-hooks-update, AC-uninstall-removes-hooks-link |
| `t30_stop_hook_happy_path.sh` | integration | Sandbox git worktree on branch `<date>-<slug>`, seeded `STATUS.md` with `## Notes`, synthetic JSON Stop payload on stdin → exactly one new line matching `- <date> stop-hook — stop event observed` under `## Notes`. Also asserts `/usr/bin/time` wall-clock <100ms (soft target, logged not gated). | AC-stop-hook-appends, AC-stop-hook-performance |
| `t31_stop_hook_failsafe.sh` | integration | Six variants (empty stdin; malformed JSON; non-git cwd; branch matches no feature; missing `STATUS.md`; missing `## Notes` heading). Each exits 0; no `STATUS.md` mutation; exactly one stderr diagnostic. | AC-stop-hook-failsafe, AC-stop-hook-exists |
| `t32_stop_hook_idempotent.sh` | integration | Two invocations within 60s (via monkey-patched sentinel) → one new line. Third invocation with sentinel aged 61s → second line. Verified by line count under `## Notes`. | AC-stop-hook-idempotent |
| `t33_claude_symlink_hooks_foreign.sh` | integration | Pre-create `~/.claude/hooks/` as a real dir (foreign). `install` reports `skipped:real-dir`; dir untouched. `uninstall` reports `skipped:not-ours`; dir still untouched. | AC-uninstall-leaves-foreign |

Every test starts with the `mktemp -d` sandbox pattern (project rule `bash/sandbox-home-in-tests`), exports `HOME="$SANDBOX/home"`, preflights `case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac`, and traps cleanup on EXIT. The harness `test/smoke.sh` registers the five new tests; R18 / AC-no-regression require all 33 tests green (28 existing + 5 new).

**Developer TDD per task**: each test above maps to a task's Acceptance command. Red-first is natural — neither `stop.sh` nor the hooks pair exists at task start.

### Performance / scale targets
- **Stop hook <100ms warm (PRD R15)** — realistic on macOS: `git symbolic-ref` ~5ms, feature dir walk O(N) typically N≤3 (~5ms), awk tail scan of STATUS.md ~5ms, atomic append ~5ms. Total budget well under 100ms. Performance is a soft target, not gated by AC.
- **claude-symlink install** — grows by one classify+create. No scaling concern.

---

## 5. Open Questions

**None blocking.** All candidates resolved inline:

- **BSD vs GNU `date` parsing for the 60s dedup window** — resolved D4 with `uname -s` dispatch. Both forms are tested in sandboxes via `t32`.
- **Stop event JSON shape forward compat** — resolved D2: minimal shape sniff (`{`-prefix check), no required keys. `HOOK_TEST=1` dumps the raw payload on stderr for forward-compat debugging. If Claude Code evolves the payload, the hook degrades to "generic note" (its v1 behavior anyway).
- **Dedup precision vs PRD date-only payload** — resolved D4 with a per-feature `.stop-hook-last-epoch` sentinel file. Keeps STATUS.md format clean (PRD R12 literal); gives dedup sub-minute precision (PRD R13). Sentinel is local, single-slot, overwritten per append.
- **`bin/claude-symlink` edit sites** — resolved D7 to the complete enumeration: `plan_links()` (2 lines added), `cmd_uninstall`'s `dir_links` array (1 line added), `usage()` managed-set block (1 line added), top-of-file header comment (1 line added). Four edit sites, all mechanical, no behavior change anywhere else.
- **Backward compat for existing installs** — resolved D9 via the existing `update` self-healing contract.

---

## 6. Non-decisions (deferred)

- **Orchestrator-supplied rich Stop payload** — explicitly deferred by PRD §8. Trigger: B2.b or later adopts a hand-off protocol; the D2 minimal parser can grow without touching the fail-safe boundary.
- **Distributed lock for concurrent Stop events** — explicitly deferred (PRD §6 accepts last-writer-wins). Trigger: telemetry shows >5% loss of notes under heavy parallel waves. Atomic `mv` already guarantees no partial writes; the worst case is one of N near-simultaneous identical notes being dropped (which dedup would have dropped anyway).
- **`.claude/hooks/README.md`** — not written. B1 D6 deferred this; B2.a also defers. Trigger: a third hook script lands and the naming convention needs to be documented in one place. The two-script precedent (session-start + stop) is self-explanatory.
- **`--force` on the hooks pair** — explicitly forbidden by project rule `common/no-force-on-user-paths`. Trigger: never in v1 (PRD §8 restates this).
- **Sentinel file in `.gitignore`** — the per-feature `.stop-hook-last-epoch` sentinel should not be committed. If a feature happens to commit feature-dir state elsewhere, the sentinel would ride along. Trigger: gap-check or QA notices the sentinel appearing in a commit; add a `.gitignore` entry then. For v1, the hook writes the file and nobody stages it; there is no `git add -A` path in the specflow flow that would sweep it up.
- **Rich stop-hook note format** (role, task id, PRD req id) — deferred with the orchestrator-supplied payload.
- **Stop hook for consumer projects that don't have specflow** — gracefully no-ops via the `no-specflow` state. No migration path needed; it's already correct.
- **Path-based filter instead of branch-name match** — deferred to a later revision if branch-name match proves insufficient. The classifier's closed-enum shape makes it a single-function swap.

---

## 7. Risks + concrete tech mitigations

| Risk (from PRD / brainstorm §4) | Mitigation in this tech plan |
|---|---|
| **Stop hook breaks → every Stop event fails** | D1 fail-safe discipline: `set +e`, trap, stderr-only, unconditional `exit 0`. `t31_stop_hook_failsafe.sh` exercises 6 fail paths. |
| **Stop hook mis-fires on every agent stop → STATUS spam** | D3 branch-name classifier is the de-facto filter: any Stop on a non-feature branch silently skips. Accepted noise: a dev pairing on a feature branch in an unrelated session. v1 accepts (PRD §6); B2.b revisits if a path-based filter is needed. |
| **Concurrent Stop events from wave agents → STATUS race or duplicate notes** | D4 60s dedup via per-feature sentinel file. D3 append via `.tmp`+`mv` — no partial-write window. Last-writer-wins on near-simultaneous appends is acceptable per PRD §6. |
| **Branch name matches multiple features** | D3 `ambiguous:<list>` state → stderr WARN + skip. Never guesses. Test: `t31` branch `feature-hooks` with two slugs seeded. |
| **New hooks dir-pair clobbers user's existing `~/.claude/hooks/`** | Existing `classify_target` returns `real-dir` or `real-file` → `apply_plan` emits `skipped:real-dir` and sets `MAX_CODE=1`. No mutation. Memory `no-force-by-default` + project rule `common/no-force-on-user-paths` hold. Test: `t33_claude_symlink_hooks_foreign.sh`. |
| **Existing installs miss the hooks pair until `update`** | D9 self-heal contract: `claude-symlink update` classifies the hooks target as `missing` and creates it. No migration code. Documented in D8 `--help` text. |
| **`date` dialect break between BSD and GNU** | D4 dispatch by `uname -s`. Both branches tested in `t32`. Memory `shell-portability-readlink` holds. |
| **Sentinel file accidentally committed** | Listed in §6 non-decisions as a deferred concern. Gap-check / QA catches. Minimal blast radius (per-feature file, ignored by specflow code). |
| **BSD vs GNU `awk` behavior differences** | Scripts use only POSIX `awk` idioms (`/regex/{action}`, `sub(…)`, `split(…)`). No GNU extensions (`gensub`, arrays-of-arrays). Matches B1 `session-start.sh` precedent. |
| **Claude Code Stop payload shape changes** | D2 minimal-sniff parse (`{`-prefix check) tolerates arbitrary JSON. `HOOK_TEST=1` dumps raw payload for forward-compat debugging. No field dependency means no breakage path. |
| **Repo moves → hooks symlink breaks** | Same as existing pairs: classified `broken-ours` → `created:replaced-broken` on next `install`/`update`. Absolute targets (project rule `common/absolute-symlink-targets`). Self-heal on re-run. |
| **`stop.sh` exits non-zero and blocks future Stop events** | Impossible by construction: `set +e`, trap to exit 0, final `exit 0`. Every write guarded with `||` degrade path. `t31_stop_hook_failsafe.sh` asserts exit 0 on 6 variants. |

---

## 8. Acceptance checks the Architect stands behind

Developer must demonstrate, in order:

1. **Hooks symlink installs idempotently** — `t29_claude_symlink_hooks_pair.sh` passes: `install` creates `~/.claude/hooks` as symlink → `$REPO/.claude/hooks`; second `install` reports `already`; `uninstall` removes; `update` reconciles.
2. **Hooks symlink respects foreign content** — `t33_claude_symlink_hooks_foreign.sh` passes: pre-existing real dir at `~/.claude/hooks/` is `skipped:real-dir` on install and `skipped:not-ours` on uninstall; never mutated.
3. **Stop hook exists and is executable** — `.claude/hooks/stop.sh` file present, exec bit set, `bash -n` clean.
4. **Stop hook happy path** — `t30_stop_hook_happy_path.sh` passes: appends exactly one PRD-R12-shaped line under `## Notes` in the matched feature's `STATUS.md`.
5. **Stop hook fail-safe on 6 error variants** — `t31_stop_hook_failsafe.sh` passes: each variant exits 0 with no `STATUS.md` mutation.
6. **Stop hook 60s dedup** — `t32_stop_hook_idempotent.sh` passes: two calls within 60s produce one line; third >60s produces a second line.
7. **`--help` mentions hooks pair** — `bin/claude-symlink --help | grep -q hooks` passes.
8. **Per-project wiring docs searchable** — `grep -r 'specflow-install-hook add SessionStart' README.md` and `grep -r 'specflow-install-hook add Stop' README.md` (or equivalent documented file per R5) both find matches.
9. **No regression** — `bash test/smoke.sh` exits 0; all 33 tests green (28 existing + 5 new).

---

## 9. Memory candidates flagged for archive retro

To be proposed at `/specflow:archive` retro (not written now, per `.claude/team-memory/README.md` scope discipline):

- **`architect/hook-event-payload-stability.md`** — pattern: "Depend on minimal-stable JSON shape (`{`-prefix), never on transient fields. Log raw payload under `HOOK_TEST=1` for forward-compat debugging. When the payload evolves, the hook degrades to its v1 behavior automatically." Extends `hook-fail-safe-pattern`; local scope; promote candidate if B2.b adds a second event consumer.
- **`architect/symlink-tool-extension-pattern.md`** — pattern: "To add a managed target to a symlink-management tool with a classify-then-dispatch contract, edit only `plan_links()` (or the equivalent plan-population function) plus the symmetric enumerations in `cmd_uninstall` and `usage()`. The dispatch table absorbs the new target without any new arm. Proven here by adding one dir-pair in 4 mechanical edits (~5 lines total) with zero new error paths." Local scope; strong promote candidate — this is the architectural value of B1's D5 + D6 classify-before-mutate contract playing out in practice.
- **`architect/date-dispatch-bsd-gnu.md`** — pattern: "For any bash script that needs `date` arithmetic across macOS (BSD) and Linux (GNU), dispatch at call time via `uname -s`. Never rely on GNU-only `-d` or BSD-only `-j -f` alone. A 4-line wrapper function (`to_epoch`) isolates the dialect choice." Local scope initially; promote candidate — this is a repo-agnostic pattern that every bash tool touching time will eventually need.

---

## Summary

- **D-count**: 9 decisions (D1–D9).
- **§5 blockers**: **none**. Safe to proceed to `/specflow:plan`.
- **Memory candidates proposed**: 3 (hook-event-payload-stability, symlink-tool-extension-pattern, date-dispatch-bsd-gnu) — flagged for archive retro, not written now.
- **Applied architect memory entries (6)**: `hook-fail-safe-pattern`, `settings-json-safe-mutation`, `no-force-by-default`, `classification-before-mutation`, `shell-portability-readlink`, `script-location-convention`.
