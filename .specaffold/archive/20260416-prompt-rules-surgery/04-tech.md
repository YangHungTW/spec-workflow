# Tech — prompt-rules-surgery (B1)

_2026-04-16 · Architect_

## Team memory consulted

- `architect/shell-portability-readlink.md` — applies: hook must run on macOS bash 3.2, no `readlink -f`, no GNU coreutils, no `jq`. Pure-POSIX text tools only.
- `architect/classification-before-mutation.md` — applies as analogy: rule-file parsing must **classify first** (`valid | missing-frontmatter | missing-required-field | parse-error`) before emitting any digest line. Classifier is a pure function; emission is a separate pass.
- `architect/no-force-by-default.md` — applies in spirit to hook fail-safe: the hook never overrides, never blocks, never mutates. On any ambiguity → stderr diagnostic + `exit 0`.
- `architect/script-location-convention.md` — applies with exception: `bin/` is for user-facing CLIs. The SessionStart hook is Claude Code infrastructure (not user-invoked) so `.claude/hooks/session-start.sh` is the correct home per R4. The convention still wins for the hook **self-test helper** (see D6).
- `shared/` (both tiers) and global `architect/` — empty; nothing to pull.

---

## 1. Context & Constraints

### Existing stack (what's already in the repo)
- **Shell tooling only.** Repo ships `bin/claude-symlink` (pure bash, macOS 3.2 floor). No package manifest, no CI config, no language runtime beyond system bash + BSD userland.
- **No `settings.json` at repo root today** — this feature creates it (R4). User-level `~/.claude/settings.json` exists with no hooks block, so no collision at the user tier either. **Important (see D12 [ADDED 2026-04-16]):** even though this feature is the first to write `settings.json`, the install step must still use the read-merge-write pattern — any future feature, or a user who hand-adds `permissions` / env vars before re-running install, relies on that discipline. Do NOT overwrite `settings.json`.
- **Seven agent files** at `.claude/agents/specflow/*.md`, current line counts (non-empty, `grep -cv '^$'`-equivalent): pm 32, designer 32, developer 35, qa-analyst 30, qa-tester 33, architect 54, tpm 64. These match the PRD R9b baseline.
- **Team-memory layout** at `.claude/team-memory/<role>/` and `shared/` with `index.md` + per-topic `.md` files, YAML frontmatter (`name`, `description`, `type`, `created`, `updated`). Protocol documented in `.claude/team-memory/README.md`.
- **Test harness** at `test/smoke.sh` (12 tests currently, PRD R16 + AC-no-regression require this stays green).

### Hard constraints
- **macOS bash 3.2 + BSD userland floor** (architect memory `shell-portability-readlink`). Corollaries: no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` relied on for portability-critical logic, no `flock`. Linux CI is a *subset* target; portability lives at the macOS floor.
- **Zero install footprint** — no Node.js, Python, or Homebrew dependency introduced by this feature (PRD R4: pure bash).
- **Fail-safe hook** — under any fault, hook logs one stderr line and `exit 0`. Never blocks session startup (R5-item-4).
- **Backward compat** — `test/smoke.sh` stays green (R16); `.claude/commands/specflow/` file list unchanged (R15); agent frontmatter shape preserved so Claude Code still discovers agents (R7).

### Soft preferences
- **Single bash script** for the hook; no helper-script-calls-helper-script tree in v1.
- **Shell-only test fixtures** — stick with the `test/t*_*.sh` + `smoke.sh` pattern already established.
- **Dogfood the feature's own item (3)** — this tech doc opens with a "Team memory consulted" block per R10/R11 even though enforcement isn't wired yet.

### Forward constraints from B2 (must not make B2 harder)
- **Stop hook** (B2 item 5) and **PostToolUse** hooks must plug into the same `settings.json` → `.claude/hooks/*.sh` pattern without rework. Each event gets its **own** script file (no single dispatcher), so B2 just adds siblings. See D2 and §7.
- **Inline per-task reviewer** (B2 item 4) will want to consult `.claude/rules/` as its rubric source. v1 format (D3) must be stable enough that B2 rubrics can reuse it.

---

## 2. System Architecture

### Components

```
+---------------------------+     +---------------------------+
| Claude Code session start |<----| settings.json (repo root) |
+-------------+-------------+     | hooks.SessionStart[]      |
              |                   +---------------------------+
              v
   +----------------------------+        +----------------------+
   | .claude/hooks/             |------->| stderr (diagnostics) |
   |   session-start.sh         |        +----------------------+
   |   (pure bash, exit 0 safe) |
   +-------+--------------------+
           |
           | reads (filesystem only)
           v
   +---------------------+   +---------------------+
   | .claude/rules/      |   | git diff / ls       |
   |   common/*.md       |   | (lang heuristic:    |
   |   bash/*.md         |<--+  file extensions in |
   |   markdown/*.md     |   |  recent worktree)   |
   |   git/*.md          |   +---------------------+
   +---------------------+
           |
           | emits JSON on stdout
           v
   +-------------------------------+
   | { "hookSpecificOutput": {     |
   |     "hookEventName":          |
   |       "SessionStart",         |
   |     "additionalContext":      |
   |       "<digest text>" }       |
   | }                             |
   +-------------------------------+
                ||
                v
   Claude Code session context (visible to every agent this session)


Separately (no hook involvement):

  /specflow:<cmd>  --->  agent invocation  --->  agent reads
                                                  .claude/team-memory/<role>/index.md
                                                  (global tier + local tier)
                                                 and emits "## Team memory" block
                                                 in its return to orchestrator
```

### Data flow — key PRD scenarios

**Scenario A: fresh Claude Code session opens in this repo (PRD R4, R5, AC-rules-visible).**
1. Claude Code reads repo-root `settings.json`, sees `hooks.SessionStart[].hooks[].command = ".claude/hooks/session-start.sh"`.
2. Shells out to that script with hook JSON on stdin (may be empty for SessionStart — parse defensively).
3. Script walks `.claude/rules/common/*.md`; for each: classifies (valid / bad-frontmatter / missing-field), extracts `name`, `severity`, and the `Rule:` body line; accumulates digest lines.
4. Script sniffs recent edits (`git diff --name-only HEAD~5..HEAD 2>/dev/null` + `ls -t` fallback) for file extensions; for each matched language subdir that exists and has `.md` rules, walks it the same way.
5. Script emits one JSON object on stdout: `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<digest>"}}` and `exit 0`.
6. Claude Code merges `additionalContext` into session context. Every agent spawned this session sees the rules digest.

**Scenario B: agent invoked by `/specflow:next` (PRD R10, R11, AC-memory-section-visible).**
1. Orchestrator runs the agent (say, developer) via the Task tool.
2. Agent's core prompt (post-refactor) opens with the mandatory "Before acting" block (R10): list `~/.claude/team-memory/developer/` + `.claude/team-memory/developer/`, ditto `shared/` in both tiers.
3. Agent reads the relevant index files and pulls in applicable entries.
4. Agent does its work (TDD loop, etc.).
5. Agent's return to orchestrator **must** include a `## Team memory` section (R11): either a 3–5 line "applied:" list or a single `none apply because <reason>` line. Missing-dir case uses `dir not present: <path>` per R12.

**Scenario C: hook fault — rules dir missing, bad frontmatter, etc. (PRD R5-item-4, AC-hook-failsafe, AC-hook-bad-frontmatter).**
1. Script runs, classifier rejects the problem file(s), logs one stderr diagnostic line per problem.
2. Script still emits a (possibly empty) digest JSON on stdout.
3. `exit 0` — session starts normally. Agents see whatever valid rules did load.

### Module boundaries

- **Hook script** `.claude/hooks/session-start.sh` — **only** writes to stdout/stderr. No filesystem mutation anywhere. Read-only relative to the repo worktree.
- **Rule files** `.claude/rules/**/*.md` — data; consumed by the hook and (via injected context) by every agent. Not imported by code.
- **Agent core files** `.claude/agents/specflow/<role>.md` — prompts; Claude Code reads them when the agent is invoked. The hook does **not** read or modify them.
- **Agent appendix files** `.claude/agents/specflow/<role>.appendix.md` — reference material; only read when the core file's pointer triggers the agent to open it (agent tool-call, not a hook).
- **Team-memory** `.claude/team-memory/**` — separate data layer; consumed only by agents, never by the hook. Clear contrast from rules (see D4).

---

## 3. Technology Decisions

### D1. Hook script language — pure bash
- **Options considered**: (A) pure bash, (B) Python, (C) Node.js, (D) Deno/JS one-liner.
- **Chosen**: **A. pure bash**, bash 3.2 compatible, BSD userland only (POSIX `sed`/`awk`/`find`/`head`/`grep`).
- **Why**: PRD R4 mandates bash; `shell-portability-readlink` memory documents the zero-dependency requirement; this is the same constraint `bin/claude-symlink` already honors. No new runtime introduced.
- **Tradeoffs accepted**: verbose frontmatter parsing (no YAML library). Mitigated by D5's line-range `awk` approach — we only need five fields, not general YAML.
- **Reversibility**: **high** — if a future rule corpus outgrows bash parsing, the hook script can be rewritten in any language behind the same `settings.json` entry with zero call-site change.
- **Requirement link**: R4, R5.

### D2. `settings.json` hook wiring — concrete JSON shape
- **Options considered**: (A) single dispatcher script keyed by event name, (B) one script per event in `.claude/hooks/<event>.sh`.
- **Chosen**: **B. one script per event**, starting with only `session-start.sh` for B1.
- **Why**: B2 will add Stop + possibly PostToolUse hooks; separate scripts avoid a fragile `case "$1" in …` dispatcher that every B2 task has to edit. Each script has its own fail-safe boundary. Simpler tests (one script, one test).
- **Tradeoffs accepted**: slight duplication of fail-safe header across scripts when B2 arrives. Acceptable — each script is <100 lines.
- **Reversibility**: **high** — collapsing to a dispatcher later is a localized refactor.
- **Requirement link**: R4; B2-forward compat.

**Concrete `settings.json` (repo root, created by this feature):**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

**How this file gets created/modified — see D12 [ADDED 2026-04-16].** The snippet above is the *shape* the SessionStart entry must take; it is NOT how to write the file. The install step MUST read-merge-write (no overwrite, no heredoc-clobber), back up to `settings.json.bak`, swap atomically via `settings.json.tmp → settings.json`, and be idempotent. Future features (B2 Stop hook, PostToolUse, etc.) will call the same `add_hook(event, command)` shape against the existing file.

**Uncertainty note (addressed, not blocking):** Claude Code's SessionStart hook configuration uses the nested `hooks.<Event>[].hooks[].command` shape with `type: "command"` (matching the documented hook config format). The script emits JSON on stdout; Claude Code reads the `hookSpecificOutput.additionalContext` field (or the older top-level `context` field as a fallback) and injects it into session context. If Developer's first integration test shows Claude Code expects a different key name, the fix is a one-line change in the hook script (D7) — no architectural impact. The `type: "command"` wrapper is required; omitting it is the most common config bug.

### D3. Rule file format — YAML-frontmatter markdown, five required keys
- **Options considered**: (A) pure markdown with H2-keyed metadata, (B) TOML frontmatter, (C) YAML frontmatter.
- **Chosen**: **C. YAML frontmatter**, aligned with team-memory convention but with a deliberately different key set so the two layers can't be confused.
- **Why**: PRD R2 specifies the schema. YAML matches team-memory (contributor muscle memory). Distinct keys (`scope`, `severity` vs team-memory's `type`, `description`) prevent accidental rule/memory conflation.
- **Tradeoffs accepted**: YAML parsing in bash is fragile; mitigated by restricting to a fixed 5-key shape and parsing each key with its own `awk` one-liner (see D5).
- **Reversibility**: **medium** — changing the schema means migrating every rule file + updating the hook parser.
- **Requirement link**: R2.

**Frontmatter (exact schema, enforced by the hook's classifier):**
```yaml
---
name: <kebab-case slug, matches filename stem>
scope: common | bash | markdown | git | <lang>
severity: must | should | avoid
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

**Body (required sections, in this order, per R2):**
- `## Rule` — one-sentence imperative.
- `## Why` — 1–3 sentences.
- `## How to apply` — checklist or template.
- `## Example` — optional but strongly preferred.

**Severity semantics:**
- `must` — blocker if violated; agent must refuse or escalate.
- `should` — strong default; deviation requires explicit justification.
- `avoid` — known anti-pattern; agent must not produce this unless user overrides.

### D4. Rules vs team-memory — single source of truth delineation
- **Options considered**: (A) merge rules into team-memory with a `severity: must` field, (B) keep them separate layers.
- **Chosen**: **B. separate layers**, each with its own load mechanism and its own README.
- **Why**: Rules are **hard**, session-global, enforced on every matching session. Memory is **soft**, role-specific, consulted per task. Conflating them would mean either (a) every memory entry loads at session start (token blowout) or (b) every role reads every rule file (misses the point of the hook). Also: team-memory frontmatter is already in the wild; changing its schema is gratuitous churn.
- **Tradeoffs accepted**: two READMEs to maintain. Acceptable — they read as a pair and the contrast is pedagogically useful.
- **Reversibility**: **medium** — re-merging later is a schema migration.
- **Requirement link**: R1, R14.

**Authoritative contrast (goes into `.claude/rules/README.md`):**

| Dimension | `.claude/rules/` | `.claude/team-memory/` |
|---|---|---|
| Enforcement | **hard** (must / should / avoid) | **soft** (craft advisory) |
| Load time | session start (via hook) | task start (agent reads index) |
| Scope | all sessions matching scope (`common` or `<lang>`) | one role (or `shared/`) |
| Source of truth | yes — rule file is authoritative | yes — memory file is authoritative |
| Duplication with prompts | forbidden after this feature lands (R14) | tolerated where context demands |
| Versioning | not versioned; edits apply per-session | not versioned; edits apply per-read |

### D5. Rule parsing — `awk` range extraction + per-field sniff
- **Options considered**: (A) invoke `yq`/`python -c "yaml.safe_load"` (rejected — dependency), (B) one big `awk` frontmatter parser, (C) per-field `awk` one-liners.
- **Chosen**: **C. per-field sniffs** inside a pure classifier function, with `awk '/^---$/{c++; next} c==1{print}'` isolating the frontmatter block once per file.
- **Why**: bash 3.2 compat; tiny surface; reusable between SessionStart and future hooks. Matches `classify_target` / `owned_by_us` pattern from `bin/claude-symlink` (two-phase: isolate the block, then sniff each required key). Classifier is a pure function in line with `classification-before-mutation`.
- **Tradeoffs accepted**: won't handle multi-line YAML values, quoted colons, or nested keys. We don't need any of those — the schema is five flat keys.
- **Reversibility**: **high** — swap the classifier body, keep its signature.
- **Requirement link**: R2, R5-item-4.

### D6. Hook self-test location — `test/t*_*.sh`
- **Options considered**: (A) `bin/specflow-hook-check` (user-invokable), (B) `test/t_hook_session_start.sh` (plugs into `test/smoke.sh`), (C) split: a `test/` harness and a separate `bin/` user-facing self-check.
- **Chosen**: **B. `test/t_hook_session_start.sh`**, wired into `test/smoke.sh` so AC-no-regression (12/12 → 13/13 or more) covers it automatically.
- **Why**: `script-location-convention` says `bin/` is user-facing; the hook self-test is developer-facing (CI gate). `test/` is where `t2…t12` already live. A dedicated hook test appends to the suite naturally.
- **Tradeoffs accepted**: no standalone user CLI to "run the hook and show me what it outputs". Users can invoke the hook directly (`bash .claude/hooks/session-start.sh < /dev/null`) — no wrapper needed.
- **Reversibility**: **high** — adding a `bin/` wrapper later is trivial.
- **Requirement link**: R5, R16, AC-hook-failsafe, AC-hook-bad-frontmatter, AC-hook-lang-lazy.

### D7. Hook output format — `hookSpecificOutput.additionalContext`
- **Options considered**: (A) plain text to stdout (older hook conventions), (B) JSON with `context` key, (C) JSON with `hookSpecificOutput.additionalContext`.
- **Chosen**: **C**, with a one-line conditional fallback to **B** if needed.
- **Why**: This is the documented Claude Code SessionStart shape for injecting context. The fallback is cheap — emit both keys in the same object, and Claude Code reads whichever it recognizes.
- **Tradeoffs accepted**: slight JSON duplication if both keys present. Acceptable; parser picks one.
- **Reversibility**: **high** — one-line change.
- **Requirement link**: R5.

**Emitted JSON (exact shape):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "rules loaded (common): • [must] bash-32-portability — Write pure bash, no readlink -f / realpath.\n• [must] classify-before-mutate — Classify targets into a closed enum before any mutation.\n…"
  }
}
```

### D8. Language heuristic — `git diff` + file-ext sniff, v1
- **Options considered**: (A) parse recent worktree edits via `git log --name-only`, (B) `find` + sort by mtime, (C) environment variable opt-in, (D) always-load all languages.
- **Chosen**: **A primary + B fallback**. Collect file paths from `git diff --name-only HEAD~10..HEAD 2>/dev/null` plus `git status --short 2>/dev/null`; if both empty (not a git repo, or fresh repo), fall back to `find . -type f -mtime -1 -maxdepth 3 2>/dev/null`. Map extensions:

| ext | loads dir |
|---|---|
| `.sh` / `.bash` | `bash/` |
| `.md` | `markdown/` |
| any file under `.git/` OR ext `.gitignore`/`.gitattributes` OR recent `git` operation signal | `git/` |

- **Why**: PRD R5-item-2 requires a "simple heuristic". `git`-based signals are cheap, bounded, and don't depend on Claude Code hook payload structure (which may vary between hook versions). If git isn't available, the mtime fallback still catches the common case.
- **Tradeoffs accepted**: false positives (e.g. a `.md` commit loads markdown rules even if the task is non-markdown); PRD §6 explicitly accepts these. False negatives possible on totally fresh repos — okay, common rules still load.
- **Reversibility**: **high** — the heuristic is one function; swap out or tighten later.
- **Requirement link**: R5-item-2, R6.

### D9. Appendix reference mechanism — literal pointer phrase
- **Options considered**: (A) free-form prose pointers, (B) strict `When you need X, consult <role>.appendix.md section "Y".` phrase, (C) YAML manifest mapping core sections to appendix anchors.
- **Chosen**: **B. literal phrase**, grep-verifiable.
- **Why**: PRD R9 calls for grep-verifiable pointers. Phrase B is exactly what AC-appendix-pointers-resolve needs (`grep -o 'section "[^"]*"' | …`). Option C adds a file; option A fails acceptance.
- **Tradeoffs accepted**: authors must remember the phrase; the gap-check can catch drift. Add the phrase to `.claude/rules/markdown/appendix-reference-phrase.md` (optional additional rule) to enforce via session context.
- **Reversibility**: **high** — phrase is a convention, not a code contract.
- **Requirement link**: R9, AC-appendix-pointers-resolve.

### D10. Agent core header shape — fixed six-block ordering
- **Options considered**: (A) free-form re-authoring per role, (B) a shared fixed template every role fills in.
- **Chosen**: **B. fixed template**, exactly the order PRD R8 prescribes.
- **Why**: AC-core-header-grep (frontmatter → identity → Team memory → When invoked → Output contract → Rules) must grep-verify across all 7 roles. Consistent order makes that one grep, not seven. Also compresses the slimming task — TPM can template-fill instead of re-writing each agent.
- **Tradeoffs accepted**: slight rigidity; some agents (architect, tpm) have more than one "When invoked" — the template must allow multiple. That's fine — the ordering is enforced, not cardinality.
- **Reversibility**: **medium** — re-ordering later requires edits to all seven files.
- **Requirement link**: R7, R8, R9b, AC-core-header-grep, AC-slim-line-count.

**Template (per-role):**
```markdown
---
name: specflow-<role>
model: opus|sonnet
description: <existing one-liner>
tools: <existing tool list>
---

You are the <Role>. <one-sentence role identity>.

## Team memory

Before acting (this is R10 — mandatory, machine-visible):
1. `ls ~/.claude/team-memory/<role>/` and `ls .claude/team-memory/<role>/` (global then local).
2. `ls ~/.claude/team-memory/shared/` and `ls .claude/team-memory/shared/`.
3. Pull in any entry whose description is relevant to the current task.

Your return to the orchestrator MUST include a `## Team memory` section containing either:
- 3–5 lines, one per applied entry with a one-phrase relevance note, OR
- the exact phrase `none apply because <reason>`, OR
- `dir not present: <path>` when a tier dir is missing (R12).

After finishing, propose a memory file if you discovered a reusable lesson (per `.claude/team-memory/README.md`).

## When invoked for /specflow:<cmd>
<behavior — only what's load-bearing for the core loop>

## Output contract
- Files written: <exact paths>
- STATUS note format: `- YYYY-MM-DD <role> — <action>`
- Team memory block: required (per R11)

## Rules
<short, role-specific; cross-role rules live in .claude/rules/ now>

<!-- Optional appendix pointer, R9 literal phrase: -->
<!-- When you need X, consult <role>.appendix.md section "Y". -->
```

### D11. Migration policy — refactor-not-rewrite, deduped
- **Options considered**: (A) delete-and-rewrite each agent, (B) surgical extract: move content to rules/appendix, delete duplicates, keep semantics.
- **Chosen**: **B. surgical extract**, with a mandatory diff check at gap-check stage: every non-empty line removed from a core file must be traceable to either (i) a rule file under `.claude/rules/`, (ii) a section in `<role>.appendix.md`, or (iii) an explicit "already covered by memory entry X" justification.
- **Why**: PRD §4 says "refactor, not rewrite" (R9b). `01-brainstorm.md` §4 flags "slim prompts drop a load-bearing directive" as the top risk — the diff-traceability rule is the mitigation.
- **Tradeoffs accepted**: slower than a rewrite. Worth it; these prompts are load-bearing.
- **Reversibility**: **high** — git history preserves every removed line.
- **Requirement link**: R7, R9b, R14, AC-no-duplication.

### D12. Safe `settings.json` mutation — read-merge-write, never overwrite [ADDED 2026-04-16]

- **Options considered**: (A) truncate + rewrite whole file from a heredoc, (B) Python 3 one-liner (`python3 -c "import json,sys; …"`) that read-modify-writes, (C) `jq --argjson` pipeline, (D) Node.js one-liner, (E) pure-bash manual splice.
- **Chosen**: **B. Python 3 one-liner**, with atomic swap + single-slot backup. `jq` is opt-in only (per `architect/shell-portability-readlink.md` — `jq` is not in our floor); `node` is not assumed; pure-bash splice is last-resort.
- **Why**: User flagged late constraint — `settings.json` at repo root is user-owned. It may already contain (or will contain, via other features / B2 / per-user tweaks) `permissions`, env vars, other `hooks.*` events, unrelated tool configs. Overwriting wholesale would silently destroy all of that. Python 3.6+ is effectively guaranteed on macOS 12+ and every Linux dev env we care about — the install step is one-shot (not a hot path), so assuming `python3` is cheap. `jq` is cleaner syntactically but adds a runtime dep the repo floor doesn't otherwise require. This decision also honors `architect/no-force-by-default.md` in spirit: don't clobber user state; and `architect/classification-before-mutation.md`: classify existing JSON (does the event array exist? does our entry already exist?) before mutating.
- **Tradeoffs accepted**: Python 3.6+ assumed on install path (not on hook runtime path — the hook itself stays pure bash per D1). If a user lacks `python3`, the install step fails loudly with a clear stderr message telling them to install it or hand-edit `settings.json` using the documented snippet from D2. No fallback to clobber — better to refuse than to destroy.
- **Reversibility**: **high** — the installer's `add_hook` / `remove_hook` are pure functions over parsed JSON; swapping the engine (Python → jq → node) later is localized.
- **Requirement link**: R4 (hook wiring), and new user-flagged invariant: preserve existing `settings.json` content.

**Rule (normative, applies to B1, B2, and every future feature):**

> Any operation that modifies `settings.json` — whether adding or removing a hook entry, a permissions rule, an env var, anything — **must** read the existing file, mutate the parsed structure in memory, and write the result back. **Never** truncate + rewrite. **Never** `cat > settings.json`. **Never** emit a heredoc that discards prior content. This rule is non-negotiable even when "only one key" is owned by the feature.

**Preferred implementation order:**

1. **Python 3 one-liner** (default for this feature): zero install, proper JSON handling, preserves unrelated keys by construction.
   ```bash
   python3 - <<'PY'
   import json, os, shutil
   p = "settings.json"
   try:
       with open(p) as f: data = json.load(f)
   except FileNotFoundError:
       data = {}
   if os.path.exists(p):
       shutil.copyfile(p, p + ".bak")
   # add_hook logic: idempotent append
   hooks = data.setdefault("hooks", {})
   event = hooks.setdefault("SessionStart", [])
   cmd = ".claude/hooks/session-start.sh"
   already = any(
       any(h.get("command") == cmd for h in grp.get("hooks", []))
       for grp in event
   )
   if not already:
       event.append({"hooks": [{"type": "command", "command": cmd}]})
   tmp = p + ".tmp"
   with open(tmp, "w") as f:
       json.dump(data, f, indent=2)
       f.write("\n")
   os.replace(tmp, p)
   PY
   ```
2. **`jq` pipeline** — opt-in if user has `jq` and prefers it. Not the default; don't add `jq` to the dependency floor.
3. **Node.js one-liner** — if Python is unavailable; not assumed.
4. **Pure-bash manual splice** — last resort; fragile; write sandbox fixtures + test before shipping.

**Required invariants of any implementation:**

- **Idempotent**: running the install step twice leaves exactly one matching entry. Check via `command` string equality before appending.
- **Pure add_hook / remove_hook shape**: structure the installer so a sibling `remove_hook(event, command)` is a trivial inversion — both operate on the parsed dict. Even though B1 has no uninstall flow, future features (and user recovery) need this to be ~5 lines.
- **Atomic write**: write `settings.json.tmp`, then `os.replace` (POSIX atomic) to `settings.json`. Never truncate-then-write in place.
- **Single-slot backup**: `cp settings.json settings.json.bak` before mutating (overwritten each run — this is a safety net, not version history; git is version history).
- **Preserves unrelated keys**: an existing `permissions`, env vars, other `hooks.<Event>` arrays, and any future top-level key must survive untouched. This is the acceptance test.
- **Clear failure**: if `python3` is missing, fail non-zero with a stderr line naming the required snippet (from D2) so the user can hand-edit. Never downgrade to clobbering.

**Install-time usage in this feature:** the task that installs the SessionStart hook (wiring per D2) MUST use the D12 shape. Bare `cat > settings.json` or unconditional heredoc is forbidden and will be caught by `t27_settings_json_preserves_keys.sh` (see §4 testing table additions below).

---

## 4. Cross-cutting Concerns

### Error handling strategy
- **Hook script**: `set +e` at the top (never `set -e`), explicit `trap 'exit 0' ERR INT TERM` so any unhandled error still exits zero. Every external command call checked; on failure, emit stderr line prefixed `session-start.sh: WARN: ` and continue. Final `exit 0` unconditional. (Echoes PRD R5-item-4 + `no-force-by-default` spirit — never make session startup worse.)
- **Classifier**: pure function, returns enum string (`valid | no-frontmatter | missing-name | missing-scope | missing-severity | missing-created | missing-updated | empty`) — no early exits, no side effects beyond stderr logging on the caller side.
- **Agent core files**: prompt-level only. No runtime exceptions. If an agent fails to produce the Team memory section, that's a review-time catch (PRD R13 — no auto-linter in v1).

### Logging / tracing / metrics
- **Hook stderr**: one line per warning, format `session-start.sh: <level>: <message>`. Levels: `WARN` (bad frontmatter, missing field) and `INFO` (empty common/, no language signal).
- **Rules digest on stdout**: goes into session context; functions as the "hook ran" visible evidence (AC-rules-visible).
- **No metrics pipeline** — out of scope. 200ms SLA (R5-item-3) is a manual target, not an asserted test.

### Security / authn / authz posture
- **No secrets**. Hook reads only files under `.claude/rules/` and git metadata. Never writes. Never shells out to network.
- **Injection risk**: rule bodies are concatenated into `additionalContext` JSON string. The hook must **JSON-escape** the digest content (backslash-escape `"`, `\`, newlines via `\n`). Mitigation lives inside the hook's `emit_json` helper.
- **Untrusted rule files**: rules are repo-committed; any adversarial content is a git-review problem, not a runtime problem.

### Testing strategy (feeds Developer's TDD)
Test boundaries, each a concrete `test/t*_*.sh` in the existing pattern:

| Test | Level | What it asserts | Maps to AC |
|---|---|---|---|
| `t13_settings_json.sh` | unit | `settings.json` exists, parses (`sed`/`awk` smoke), references `.claude/hooks/session-start.sh` | AC-hook-wired |
| `t14_rules_dir_structure.sh` | unit | `.claude/rules/{common,bash,markdown,git}/` all exist; R3 slug files present | AC-rules-dir, AC-rules-count |
| `t15_rules_schema.sh` | unit | Every `.md` under `.claude/rules/` has 5 required frontmatter keys + 3 required body sections | AC-rules-schema |
| `t16_hook_exec_bit.sh` | unit | `.claude/hooks/session-start.sh` exists + `test -x` | AC-hook-exists |
| `t17_hook_happy_path.sh` | integration | Run hook with stocked rules dir; stdout is valid JSON with non-empty `additionalContext`; exit 0 | AC-rules-visible |
| `t18_hook_failsafe.sh` | integration | Rename `.claude/rules/` temp; run hook; assert exit 0 + stderr warning; restore | AC-hook-failsafe |
| `t19_hook_bad_frontmatter.sh` | integration | Stock a broken file; run hook; assert valid files still digested, broken file skipped with stderr line, exit 0 | AC-hook-bad-frontmatter |
| `t20_hook_lang_lazy.sh` | integration | Run hook with a dummy `.sh` touched in worktree → assert bash digest present; without → absent | AC-hook-lang-lazy |
| `t21_agent_line_count.sh` | unit | `grep -cv '^$' <role>.md` ≤ R9b ceiling for every role | AC-slim-line-count |
| `t22_agent_header_grep.sh` | unit | Every `<role>.md` has frontmatter → identity → `## Team memory` → `## When invoked` in that order | AC-core-header-grep |
| `t23_memory_required.sh` | unit | Every `<role>.md` contains `ls ~/.claude/team-memory/<role>/` and the `none apply because` phrase | AC-memory-required |
| `t24_appendix_pointers.sh` | unit | Every `section "X"` reference in a core file has a matching `## X` / `### X` in that role's appendix | AC-appendix-pointers-resolve |
| `t25_no_duplication.sh` | unit | `grep -l 'readlink -f\|--force\|sandbox-HOME' .claude/agents/specflow/*.md` → zero hits | AC-no-duplication |
| `t26_no_new_command.sh` | unit | `ls .claude/commands/specflow/ \| wc -l` equals the git-baseline count | AC-no-new-command |
| `t27_settings_json_preserves_keys.sh` [ADDED 2026-04-16] | integration | Seed `settings.json` with dummy `{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}`; run install step; assert dummy `permissions` + `env` keys still present **and** SessionStart entry added | AC-settings-json-preserves (D12) |
| `t28_settings_json_idempotent.sh` [ADDED 2026-04-16] | integration | Run install step twice against a clean sandbox; assert `settings.json` has exactly one `SessionStart[].hooks[]` entry pointing at `.claude/hooks/session-start.sh` (no duplicate) | AC-settings-json-idempotent (D12) |

All registered in `test/smoke.sh` — `smoke.sh` stays green **and** grows (AC-no-regression: old tests still pass; new tests are additive).

**Developer TDD per task**: each test above is a task's Acceptance command. Red-first is natural here — none of these files exist at task start.

### Performance / scale targets
- Hook <200ms warm (R5-item-3). With <50 rule files (v1 realistic ceiling), this is trivial on macOS (bash + `awk` startup dominates at ~20ms/file).
- Digest size: cap implicit via rule count. If the common set ever exceeds ~20 rules, revisit truncation. Not v1.

---

## 5. Open Questions

**None blocking.** All candidate questions resolved:

- **`settings.json` shape for SessionStart** — resolved in D2/D7 with the nested `hooks.SessionStart[].hooks[]` shape and `hookSpecificOutput.additionalContext` output. Uncertainty called out; fix is one-line if Developer's integration test reveals a newer convention.
- **Hook script location** — resolved as `.claude/hooks/session-start.sh` (D2, per R4).
- **Hook self-test location** — resolved as `test/t_hook_*.sh` (D6).
- **Frontmatter YAML vs TOML** — resolved as YAML (D3, matches team-memory).
- **Appendix file optional** — yes, optional per role (D11; PRD R7 "role may have no appendix").
- **Language heuristic** — resolved in D8; simple git-diff + ext-sniff.

---

## 6. Non-decisions (deferred)

- **B2 hook wiring** (Stop, PostToolUse) — **not decided here**. D2 guarantees the one-script-per-event pattern so B2 adds siblings without editing `session-start.sh`. Trigger: B2's own `04-tech.md`.
- **Rule-digest truncation** — **not decided**. v1 trusts authors to keep common rules short. Trigger: digest exceeds ~4 KB in practice, or a rule author complains.
- **Rule priority / ordering** — **not decided** (PRD non-goal). Trigger: two rules in the digest contradict and we need a tiebreaker.
- **Memory-invocation linter** (performative `none apply`) — **not decided** (PRD R13 defers). Trigger: gap-check finds a pattern of hollow "none apply" lines across ≥3 features.
- **Reviewer rubric format** — **not decided** (B2 scope). Trigger: B2 item (4) opens. D3 format is stable enough to reuse, no preemption needed.
- **Rule versioning / re-run-on-edit** — **not decided** (PRD non-goal). Trigger: a rule edit mid-feature causes a verified regression and we need selective re-run.
- **`.claude/hooks/` contents beyond `session-start.sh`** — **not decided**. B2 owns. No README in `.claude/hooks/` for v1; the README goes in alongside Stop hook.

---

## 7. Risks + concrete tech mitigations

| Risk (from PRD / brainstorm §4) | Mitigation in this tech plan |
|---|---|
| **Lost load-bearing directive during slimming (R1b)** | D11 diff-traceability rule: every removed non-empty line traces to rule, appendix, or justified memory entry. AC-no-duplication + AC-core-header-grep are the enforced grep checks. Gap-check stage diffs `agents/specflow/*.md` against `HEAD~<feature-start>` and asserts traceability. |
| **SessionStart hook breaks → every session degraded** | D1 + cross-cutting: `set +e`, `trap … ERR INT TERM`, unconditional `exit 0`, every external call checked. `test/t18_hook_failsafe.sh` + `t19_hook_bad_frontmatter.sh` exercise the fail paths as part of `smoke.sh`. |
| **Hook output too large for context budget** | v1: soft cap via author discipline. Cross-cutting: note the risk; revisit if digest exceeds ~4 KB. No automatic truncation (keeps parser simple). |
| **Rules vs memory confusion** | D4 table goes verbatim into `.claude/rules/README.md`. Different frontmatter keys (D3) make accidental cross-pollination visually obvious. |
| **Missing team-memory dir silently swallowed** | R12 enforced by `AC-missing-memory-dir` + `t23_memory_required.sh` greps for the exact phrase `dir not present:`. |
| **Language heuristic misfires on `.md` repos** | Accepted false positive per PRD §6. Cost = ~20–50 extra tokens per session. No mitigation needed. |
| **Hook JSON output key changes across Claude Code versions** | D7 fallback: emit both `hookSpecificOutput.additionalContext` **and** top-level `context` in the same JSON object. Parser picks what it recognizes. One-line change to drop the unused key once we know which is current. |
| **`settings.json` collides with user-level hooks** | PRD §6 accepts as known limitation. Our `settings.json` only **adds** a SessionStart entry; Claude Code documented precedence merges per-event arrays rather than overwriting. If collision bites a user, they see their own hook output too — additive, not destructive. |
| **Install step clobbers unrelated `settings.json` keys** [ADDED 2026-04-16] | D12 mandates read-merge-write: Python 3 load → in-memory mutate → atomic `os.replace`. Single-slot backup at `settings.json.bak`. Acceptance test `t27_settings_json_preserves_keys.sh` seeds dummy `permissions` + `env` keys and asserts they survive. |
| **Corrupt JSON from interrupted write** [ADDED 2026-04-16] | D12 atomic write: `settings.json.tmp` + `os.replace` (POSIX rename is atomic on same filesystem). Plus `settings.json.bak` single-slot backup — user can always recover the prior state even after a crash during write. |
| **Duplicate hook entries from re-running install** [ADDED 2026-04-16] | D12 idempotence: existence check (`any(... command == cmd ...)`) before append. Acceptance test `t28_settings_json_idempotent.sh` runs install twice and asserts exactly one entry. |
| **`python3` not installed on target machine** [ADDED 2026-04-16] | D12 fails loud (non-zero exit, stderr line referencing the D2 snippet) rather than falling back to clobber. Acceptable because (a) Python 3 ships by default on macOS 12+ and all mainstream Linux distros, (b) install is one-shot and can be re-run after installing Python, (c) silent clobber is strictly worse than a clear error. |

---

## 8. Open questions / blockers

**No blockers.** All candidates resolved inline (§5). The `settings.json` uncertainty in D2/D7 is called out but not blocking: Developer's first integration test (`t17_hook_happy_path.sh`) will reveal the correct shape definitively; the fallback in D7 makes the fix one line if needed.

---

## 9. Acceptance checks the Architect stands behind

Developer must demonstrate, in order:

1. **Hook produces non-empty digest** — `t17_hook_happy_path.sh` passes: stdout is valid JSON, `additionalContext` is non-empty when `common/` has ≥1 rule.
2. **Hook exit 0 on missing rules dir** — `t18_hook_failsafe.sh` passes.
3. **Hook skips bad frontmatter, exit 0** — `t19_hook_bad_frontmatter.sh` passes.
4. **Language lazy-load works** — `t20_hook_lang_lazy.sh` passes both branches (with and without `.sh` in worktree).
5. **Agent line counts meet R9b ceilings** — `t21_agent_line_count.sh` passes for all 7 roles (≥30% drop each).
6. **Every agent has the mandatory `## Team memory` block** — `grep -l '^## Team memory' .claude/agents/specflow/*.md | wc -l` equals 7.
7. **No cross-role rule duplicated in agent prompts** — `t25_no_duplication.sh` passes.
8. **`settings.json` mutation preserves existing keys** [ADDED 2026-04-16, D12] — `t27_settings_json_preserves_keys.sh` passes: sandbox seeded with `{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}` → install step run → final file contains the seeded `permissions` + `env` keys **and** the SessionStart hook entry.
9. **`settings.json` mutation is idempotent** [ADDED 2026-04-16, D12] — `t28_settings_json_idempotent.sh` passes: install step run twice against a clean sandbox → exactly one `SessionStart[]` group, exactly one `command: ".claude/hooks/session-start.sh"` entry.
10. **No regression** — `bash test/smoke.sh` exits 0 (all tests, old + new).

---

## Summary

- **D-count**: 12 decisions (D1–D12). D12 added 2026-04-16 — safe `settings.json` read-merge-write.
- **§8 blockers**: none. Safe to proceed to `/specflow:plan`.
- **Amendments since initial tech**:
  - 2026-04-16 — D12 added (read-merge-write `settings.json`); §1, D2, §4 testing table, §7 risks, §9 acceptance checks all updated to reference it.
- **Memory candidates proposed** (to log at archive retro, not now):
  - `architect/hook-fail-safe-pattern.md` — "SessionStart hooks: `set +e` + `trap ERR → exit 0` + stderr-only diagnostics; never block session startup." (local default; could promote if B2 hooks repeat the pattern.)
  - `architect/rules-vs-memory-layer-contract.md` — "Hard guardrails (session-start injected) vs soft craft (role-read at task start): different frontmatter, different load path, no cross-pollination." (local.)
  - `shared/rules-severity-vocabulary.md` — "must / should / avoid: closed set; everything else is prose." (shared, because every role consumes this.)
  - `architect/settings-json-safe-mutation.md` [ADDED 2026-04-16] — "Any tool that modifies user-owned config files (`settings.json`, `.gitconfig`, `.npmrc`, etc.) must read-merge-write with atomic swap + single-slot backup. Never overwrite wholesale, even if 'only one key' is owned by the feature. Python 3 is the default engine when a JSON parser is needed; `jq` is opt-in; pure-bash splice is last resort." (local; strong candidate for eventual promotion — the lesson is repo-agnostic and extends the `no-force-by-default` + `classification-before-mutation` pair.)
