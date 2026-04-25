# Specaffold

Role-based spec-driven development workflow for Claude Code. A small virtual team (PM, Designer, Architect, TPM, Developer, QA-analyst, QA-tester) drives every feature through numbered markdown artifacts.

繁體中文版:[README.zh-TW.md](README.zh-TW.md)

See also: [README.zh-TW.md](README.zh-TW.md)

## Install

### 1. One-time global bootstrap

From this repo, create the managed symlinks under `~/.claude/`:

```sh
bin/claude-symlink install
```

This installs directory symlinks at `~/.claude/agents/scaff`, `~/.claude/commands/scaff`, `~/.claude/hooks`, and `~/.claude/skills/scaff-init` — making Specaffold's agents, commands, hooks, and the `/scaff-init` bootstrap skill available in every Claude Code session on this machine. Repo-local team-memory stays repo-scoped (not symlinked as user-global); see [Team memory](#team-memory) below. See [`bin/claude-symlink`](#binclaude-symlink--global-symlink-manager) for `install` / `uninstall` / `update` / `--dry-run` details.

### 2. Per-consumer initialisation

From inside the **target consumer repo**, run the init skill:

```
/scaff-init
```

Every `/scaff:*` command (except `/scaff-init`) refuses to run when `.specaffold/config.yml` is missing — run `/scaff-init` first.

For headless or scripted use, invoke the seed binary directly:

```sh
<src>/bin/scaff-seed init --from <src> --ref HEAD
```

Replace `<src>` with the absolute path to this repo and `<ref>` with the pinned commit or tag you want to track.

**What `init` does:**

- Seeds `.claude/agents/scaff`, `.claude/commands/scaff`, `.claude/hooks`, `.claude/rules`, and `.claude/team-memory` skeleton into the consumer repo.
- Seeds `.specaffold/features/_template/` as the feature scaffold.
- Records `specaffold.manifest` at the repo root with the pinned source ref and a per-file baseline hash for future `update` comparisons.
- Wires consumer-local hook paths into `settings.json` (SessionStart + Stop) using an atomic read-merge-write with `.bak` backup on any pre-existing file.

### 3. Updating to a newer ref

Re-run `update` whenever you want to adopt a newer Specaffold version:

```sh
bin/scaff-seed update --to <new-ref>
```

Behaviour per file:

- Files byte-identical to the source at the new ref: reported `already`, untouched.
- Files that match the **previous-ref baseline** stored in the manifest (i.e., not locally modified): replaced with new content and reported `replaced:drifted`; pre-replace bytes saved as `<path>.bak`.
- Files that differ from **both** the source and the baseline (user-modified): skipped and reported `skipped:user-modified`; your edits are preserved.
- The manifest ref only advances when the run completes with no `skipped:user-modified` outcomes. If any files are skipped, resolve conflicts first (see [Verb vocabulary](#verb-vocabulary) and [Recovery](#recovery)) then re-run.

### Per-project isolation guarantee

Each consumer repo is pinned to its own ref in its own `specaffold.manifest`. Team-memory files are local to the consumer and never travel back to the source repo. Two consumers on the same machine can run different Specaffold versions concurrently without interference.

### Recovery

If a run of `update` leaves `skipped:user-modified` files, the manifest ref is **not** advanced. To resolve:

1. Inspect the diff between your file and the new source content.
2. Either preserve your edit (copy the file to `<path>.bak` manually, then re-run `update` — the tool will treat it as baseline-matched and replace it) or discard it (restore from the manifest baseline, then re-run).
3. After a conflict-free run the manifest advances to the new ref.

If you need to roll back, restore from the `.bak` files the tool produced.

---

## Language preferences

Specaffold supports an opt-in language preference for chat replies. The setting lives in `.specaffold/config.yml` and is user-authored; the file is local-only by default. Users who want the preference shared across contributors can deliberately commit it to the repo.

Absence of the file — or of the `lang.chat` key — means default-off: English-only behaviour. The setting is strictly opt-in; no config file required.

### Config key: `lang.chat`

Set `lang.chat` to `zh-TW` (or any BCP-47 tag) to enable chat-reply localisation. Any unrecognised value produces a warning and falls back to the default-off behaviour.

```yaml
# .specaffold/config.yml
lang:
  chat: zh-TW    # or "en" (explicit default) — any other value → warning + default-off
```

The SessionStart hook reads this file and, when `lang.chat: zh-TW` is set, injects a `LANG_CHAT=zh-TW` marker into the session context so every Specaffold subagent role honours the preference without per-agent duplication. The full conditional and carve-out rules (file content, CLI stdout, commit messages, and team-memory files always stay English regardless of config value) are documented in `.claude/rules/common/language-preferences.md`.

### Precedence

The hook walks these candidates in order and stops at the first file whose `lang.chat` key is present (even if the value is invalid):

1. `.specaffold/config.yml` — project-level (repo-local).
2. `$XDG_CONFIG_HOME/specaffold/config.yml` — only when `$XDG_CONFIG_HOME` is set and non-empty.
3. `~/.config/specaffold/config.yml` — user-home fallback.

Invalid values (outside `{zh-TW, en}`) in an earlier candidate produce a single stderr warning naming the path, and the hook falls back to English default for the session. Iteration does **not** cascade past an invalid early candidate to a later one — the invalid file is treated as a deliberate "this is the setting, please fix the typo" signal, not an oversight to route around.

For most users, `~/.config/specaffold/config.yml` is the right file to set once and forget; project-level is for team-shared overrides.

### Bypass discipline

Two escape hatches are available when the language preference must be suppressed on a specific commit or file:

- **Emergency (commit-level):** `git commit --no-verify` skips all pre-commit hooks, including the Specaffold linter that enforces the preference. Use sparingly; the bypass is not audited automatically.
- **Surgical (per-file):** Add an HTML comment to the file before linting runs:
  ```
  <!-- scaff-lint: allow-cjk reason="..." -->
  ```
  The linter treats this marker as an exemption for that file only, leaving all other files under normal enforcement.

---

## Flow

```
/scaff:request      → PM intake (proposes tier if --tier not given)
/scaff:design       → Designer mockup — only if has-ui: true
/scaff:prd          → PM writes requirements
/scaff:tech         → Architect selects tech + system architecture
/scaff:plan         → TPM writes merged plan (narrative + task checklist)
/scaff:implement    → Developer runs waves in parallel via worktrees + inline review
/scaff:validate     → QA-tester + QA-analyst in parallel; verdict PASS / NITS / BLOCK
/scaff:archive      → TPM retrospective + archive move
```

**Work-type entry commands** (alternatives to `/scaff:request` for non-feature work):

```
/scaff:bug   <input>   → PM intake for fix-type work
/scaff:chore <input>   → PM intake for maintenance/cleanup work
```

**`/scaff:bug`** — for fix-type intake. The `<input>` argument is auto-classified:
- URL (e.g. `https://github.com/user/repo/issues/123`) → `type: url`
- Ticket ID (e.g. `PROJ-456`) → `type: ticket-id`
- Free-form description → `type: description`

Slug convention: `YYYYMMDD-fix-<body>`. PM probe elicits: repro steps, expected vs actual behaviour, environment. PRD template is bug-shaped (Repro / Expected / Actual / Environment / Root cause / Fix requirements / Regression test requirements). At archive time, the retrospective prompt focuses on **guardrail gaps** — what checks or tests could have caught this earlier.

**`/scaff:chore`** — for maintenance/cleanup intake. Slug convention: `YYYYMMDD-chore-<body>`. PM probe elicits: scope, reason, verify-assertion. PRD template is checklist-shaped (items to do + verify assertions). At archive time, the retrospective prompt focuses on **automation potential** — what recurring manual work could be automated.

For feature work, `/scaff:request` remains the entry point. Its retrospective prompt focuses on **tech decisions** — rationale for architecture and library choices made during the feature.

Shortcut — advance one stage at a time based on STATUS:

```
/scaff:next <slug>
```

Revisions:

```
/scaff:update-req    /scaff:update-tech    /scaff:update-plan    /scaff:update-task
```

Multi-axis review (one-shot, never advances STATUS; safe to run at any stage):

```
/scaff:review <slug>                      # all 3 axes: security, performance, style
/scaff:review <slug> --axis security      # single-axis targeted re-review
```

Team memory:

```
/scaff:remember <role> "<lesson>"          # manual save
/scaff:promote <role>/<file>               # local → global
```

Two-tier memory: `~/.claude/team-memory/<role>/` (global) + `<repo>/.claude/team-memory/<role>/` (local). Agents read both on every invocation. `/scaff:archive` runs a retrospective that polls each role for lessons. See `.claude/team-memory/README.md` for the full protocol.

## Layout

```
.claude/
  agents/scaff/        pm.md designer.md architect.md tpm.md developer.md
                       qa-analyst.md qa-tester.md
                       reviewer-security.md reviewer-performance.md reviewer-style.md
  commands/scaff/      request.md design.md prd.md tech.md plan.md
                       implement.md validate.md review.md archive.md
                       next.md remember.md promote.md
                       update-req.md update-tech.md update-plan.md update-task.md
  hooks/               session-start.sh stop.sh
  rules/               common/ bash/ markdown/ git/ reviewer/
                       README.md index.md
  team-memory/         pm/ designer/ architect/ tpm/ developer/
                       qa-analyst/ qa-tester/ shared/
                       README.md
  skills/scaff-init/   (per-project bootstrap skill)

.specaffold/
  config.yml           (optional — language preferences)
  features/
    _template/         (feature scaffold, copied by /scaff:request)
    <slug>/
      00-request.md
      02-design/       (only if has-ui: true)
      03-prd.md
      04-tech.md
      05-plan.md       (merged: narrative + task checklist)
      08-validate.md
      STATUS.md
  archive/<slug>/

bin/
  scaff-seed           (per-project init / update / migrate)
  scaff-tier           (single tier-reading helper)
  scaff-aggregate-verdicts
  scaff-install-hook
  scaff-lint

settings.json          (Claude Code settings; SessionStart + Stop hook wiring)
```

## Tier model

Every feature carries a **tier** that controls which stages are required, which are optional, and which are skipped entirely. The tier is declared at `/scaff:request` time and is monotonic — it can only increase, never decrease.

### Three tiers

| Tier | Intent | Typical size |
|---|---|---|
| `tiny` | Typo, one-function tweak, copy fix | < 1 day |
| `standard` | Normal feature or bugfix | 1–5 days |
| `audited` | Auth, secrets, breaking API, high-risk change | Any size |

### Stage matrix

The tier → stage dispatch table (✅ required, 🔵 optional, ⚫ conditional on `has-ui: true`, — skipped):

| Stage | tiny | standard | audited |
|---|:---:|:---:|:---:|
| request | ✅ | ✅ | ✅ |
| prd | ✅ (1-liner allowed) | ✅ | ✅ (with `## Exploration` mandatory) |
| tech | — | ✅ | ✅ |
| plan | 🔵 | ✅ | ✅ (fine-grained wave split) |
| design | — | ⚫ | ⚫ |
| implement | ✅ | ✅ | ✅ |
| validate | ✅ (tester-only default) | ✅ (both axes) | ✅ (both axes) |
| review | 🔵 | 🔵 | ✅ (all 3 axes mandatory) |
| archive | ✅ | ✅ (merge-check) | ✅ (merge-check strict) |

`/scaff:next` reads the `tier:` field from `STATUS.md` and skips stages that are not required for the feature's tier, writing a STATUS Note for each skipped stage.

The skip logic is extended by a **3×3 work-type × tier matrix** implemented in `bin/scaff-stage-matrix`. Work-type (`feature` / `bug` / `chore`) and tier (`tiny` / `standard` / `audited`) together determine which stages are required, optional, or skipped. Notable rules: `chore` work-type always skips the design stage regardless of tier; `bug-tiny` still runs validate (regression test required even for the smallest fix).

### Declaring a tier at request time

Pass `--tier` to set the tier explicitly:

```sh
/scaff:request --tier tiny "fix typo in README"
/scaff:request --tier audited "rotate OAuth secrets"
```

When `--tier` is omitted, the PM proposes a tier based on the raw ask and presents a **propose-and-confirm** prompt. Silent acceptance (Enter) adopts the proposal; type a different tier to override. The PM never defaults silently without proposing first.

### Monotonic upgrade rule

Tier upgrades are **one-way**: `tiny → standard → audited`. Downgrades are refused by every command that writes the `tier:` field. Attempts to downgrade exit non-zero with no STATUS mutation.

**Auto-upgrade triggers**:

- `/scaff:implement` detects diff > 200 lines OR > 3 files → suggests `tiny → standard` (TPM decides whether to accept).
- Any reviewer returns a `must`-severity **security** finding → auto-upgrades to `audited` immediately; no confirmation needed.
- PRD touches security-sensitive paths (auth, secrets, `settings.json`) → PM suggests `audited` at PRD time.

### Audit trail

Every tier change appends a STATUS Notes line in this format:

```
YYYY-MM-DD <role> — tier upgrade <old>→<new>: <trigger-reason>
```

No tier change is valid without this note. Common trigger-reason values: `TPM veto at plan`, `security BLOCK auto-upgrade`, `diff exceeded threshold`.

### Archive merge-check

`/scaff:archive` refuses to archive a `standard` or `audited` feature whose current branch is not merged to `main`. The refusal prints the branch and main ref, exits non-zero, and leaves the feature unmodified.

`tiny` tier does not trigger the merge-check.

**Escape hatch**: pass `--allow-unmerged REASON` to bypass the check. A `REASON` argument is required — omitting it exits non-zero with a usage error. The reason is appended to STATUS Notes with date and role.

```sh
/scaff:archive --allow-unmerged "multi-PR split — PR #42 covers auth changes"
```

---

## Review capability

`/scaff:implement` includes **inline multi-axis review** between wave collection and per-task merge. For every completed task in a wave, three reviewer subagents run in parallel (security / performance / style). Each loads its own rubric from `.claude/rules/reviewer/<axis>.md`, stays in lane, and emits a severity-tagged verdict. Any `must` finding blocks the wave merge; `should` / `advisory` findings are logged to STATUS.

```sh
# one-shot multi-axis review of a feature branch, writes a timestamped report
/scaff:review <slug>                  # all three axes in parallel
/scaff:review <slug> --axis security  # single-axis targeted re-review
```

Reports land at `<feature-dir>/review-YYYYMMDD-HHMM.md`. The one-shot command never advances STATUS and is safe to run at any stage (implement, validate, archive, post-archive).

Rubrics under `.claude/rules/reviewer/` are **agent-triggered**, not session-loaded — the SessionStart hook deliberately skips this subdir so rubric content only reaches the reviewer agents that invoke them.

**Escape hatch**: `/scaff:implement --skip-inline-review` bypasses the inline reviewer dispatch entirely. Uses are logged to STATUS Notes for audit. Intended for emergencies and for features that deliver the reviewer capability during their own implement waves.

## `/scaff:validate` — consolidated validation

`/scaff:validate <slug>` runs `qa-tester` (dynamic axis — walks each PRD acceptance criterion) and `qa-analyst` (static axis — PRD-vs-diff gap analysis) **in parallel**, collects their verdict footers, and aggregates to a single stage verdict using the same aggregator contract as `/scaff:review`. Output artefact: `08-validate.md`.

Verdict values: `PASS` / `NITS` / `BLOCK`. Malformed footers parse as BLOCK.

---

## `.claude/rules/` — session-wide guardrails

This repo ships a SessionStart hook that injects a digest of `.claude/rules/` into every Claude Code session opened here. Rules are **hard** cross-role guardrails (bash 3.2 portability, sandbox-HOME in tests, no `--force` on user paths, classify-before-mutate, etc.) — distinct from per-role `.claude/team-memory/` which is soft craft advisory.

The hook is wired in `settings.json`:

```json
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":".claude/hooks/session-start.sh"}]}]}}
```

Details (schema, severity vocabulary, authoring checklist): see [.claude/rules/README.md](.claude/rules/README.md).

---

## `bin/scaff-*` helpers

Single-purpose scripts under `bin/` that back the workflow. All are bash 3.2 / BSD userland portable.

```sh
bin/scaff-seed <init|update|migrate>       # per-project seed + version sync
bin/scaff-tier <slug>                      # read tier: field from a feature's STATUS.md
bin/scaff-aggregate-verdicts <axes...>     # aggregate per-axis verdicts → PASS|NITS|BLOCK
bin/scaff-install-hook <event> <path>      # idempotent settings.json hook wiring
bin/scaff-lint                             # pre-commit language-preference linter
```

`bin/scaff-tier` is the **only** code path that reads the `tier:` field from a feature's `STATUS.md`. All scripts, agents, and commands route through this helper — there is no second parse site. This is enforced by code-review discipline.

`bin/scaff-aggregate-verdicts` is the **only** classifier that aggregates per-axis reviewer or validator verdicts. It reads per-axis outputs from a scratch dir and emits `PASS` / `NITS` / `BLOCK` on stdout line 1; a must-severity security finding adds `suggest-audited-upgrade: <task-id>` on line 2.

---

## `bin/claude-symlink` — global symlink manager

`bin/claude-symlink` manages the symlinks under `~/.claude/` that make this repo's Specaffold content available to Claude Code sessions across every project on this machine. The `install` / `uninstall` / `update` subcommands are safe to re-run; conflicts are reported and skipped (no `--force` flag).

### Managed set

- `~/.claude/agents/scaff` → `<repo>/.claude/agents/scaff`
- `~/.claude/commands/scaff` → `<repo>/.claude/commands/scaff`
- `~/.claude/hooks` → `<repo>/.claude/hooks`
- `~/.claude/skills/scaff-init` → `<repo>/.claude/skills/scaff-init`

`team-memory/**` is intentionally **not** managed. Repo-local memory (`<repo>/.claude/team-memory/`) stays repo-scoped; global memory (`~/.claude/team-memory/`) is per-user real files, promoted explicitly via `/scaff:promote` — never auto-symlinked from a repo. `update` still walks `~/.claude/team-memory/` to prune any owned symlinks left by earlier releases.

All symlinks point at **absolute paths** inside the repo, so `ls -l` is always diagnosable. Moving the repo breaks the links — re-run `install` (or `update`) from the new location to refresh them.

### Subcommands

```sh
bin/claude-symlink install            # first-time setup; idempotent
bin/claude-symlink uninstall          # remove only tool-owned symlinks
bin/claude-symlink update             # add missing, replace broken-ours, prune owned orphans
bin/claude-symlink install --dry-run  # preview without mutating (works with any subcommand)
```

Supported platforms: macOS and Linux (bash 3.2 / BSD userland portable). Windows shells exit 2 with a clear message.

### Conflict handling

When a managed path can't be safely touched, the tool skips it and reports a verb. Exit code is 1 when any skip occurs; resolve conflicts manually and re-run.

| Verb | Meaning | Remediation |
|---|---|---|
| `skipped:real-file` | A regular file occupies the target path. | Inspect, back up, `rm`, re-run. |
| `skipped:real-dir` | A regular directory occupies the target path. | Inspect, back up, `rm -rf` if safe, re-run. |
| `skipped:foreign-symlink` | A live symlink points outside this repo (another tool's install). | Manually `rm` it, re-run. |
| `skipped:foreign-broken-symlink` | A broken symlink points outside this repo. | Manually `rm` it, re-run. |
| `skipped:not-ours` (`uninstall` only) | Managed path holds a symlink not owned by this tool. | Manual cleanup if desired. |

### Caveat: orphan-walk under `team-memory/`

`update` walks `~/.claude/team-memory/` for owned orphan links to prune. Ownership is determined by a single rule: the resolved link target begins with `<repo>/.claude/` (with trailing slash). A user-created symlink under `~/.claude/team-memory/` that **happens to point into this repo** is indistinguishable from one the tool created — `update` will treat it as an orphan and remove it. Avoid placing hand-crafted symlinks pointing into this repo under `~/.claude/team-memory/`.

---

## Team memory

Specaffold keeps two tiers of team memory, read by every agent at invocation:

| Tier | Location | Scope |
|---|---|---|
| Global | `~/.claude/team-memory/<role>/` | Lessons that apply across every project on this machine. Real files, one per lesson. |
| Local | `<repo>/.claude/team-memory/<role>/` | Repo-scoped lessons. Version-controlled with the repo and shared via git. |

Read order at agent start: **global first, local second**. Local overrides same-topic global silently.

`/scaff:archive`'s retrospective pass asks each role for lessons worth saving; approved entries land as files in the relevant tier. To move a local entry to global: `/scaff:promote <role>/<file>`. The two tiers are kept **independent** — `bin/claude-symlink install` never auto-syncs repo-local memory into the user-global directory.

Full authoring protocol: [.claude/team-memory/README.md](.claude/team-memory/README.md).

---

## Verb vocabulary

The `scaff-seed` commands (`init`, `update`, `migrate`) emit exactly the following verbs on stdout, one per managed file. No flow emits a verb outside this set; if a future verb is introduced, the table must be updated first.

| Verb | Meaning | Remediation |
|---|---|---|
| `created` | New file written at a previously-missing path. | None — expected on first init. |
| `already` | Destination is byte-identical to source at the chosen ref. | None. |
| `replaced:drifted` | Destination differed from source but matched the previous-ref baseline in the manifest — replaced with new content; `<path>.bak` holds the pre-replace bytes. | Inspect `.bak`; delete once satisfied. |
| `skipped:user-modified` | Destination differs from source AND differs from the baseline — user edit preserved. | Decide whether to keep the edit (copy to `.bak`, then re-run `update`) or discard it (restore from baseline, then re-run). |
| `skipped:real-file-conflict` | Destination is a directory, symlink, or non-regular file where a regular file is expected. | Remove the offending path manually, then re-run. |
| `skipped:foreign` | Destination is outside the managed subtree. | Should not occur; file a bug if observed. |
| `skipped:unknown-state` | Classifier returned an unrecognised state (defensive wildcard arm). | Should not occur; file a bug if observed — indicates a classifier/dispatcher mismatch. |
| `would-create` / `would-replace:drifted` / `would-skip:already` / `would-skip:user-modified` / `would-skip:real-file-conflict` / `would-skip:foreign` / `would-skip:unknown` | `--dry-run` preview of the above; no mutation. | None. |
