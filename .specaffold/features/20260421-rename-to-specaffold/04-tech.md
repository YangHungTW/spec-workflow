# Tech — rename-to-specaffold

**Feature**: `20260421-rename-to-specaffold`
**Stage**: tech
**Author**: Architect
**Date**: 2026-04-21
**Tier**: standard

PRD: `03-prd.md` (R1–R17, AC1–AC15; D1–D6 pre-resolved in §8).

This feature ships **no new language, framework, runtime, or external dependency**. It is a pure rename pass on files, paths, and prose already in the repo. The architecture work here is narrow: sequence the self-renaming dogfood safely, enumerate rename surfaces into parallel-safe classes, commit the compat-symlink and allow-list mechanics, and hand TPM a wave structure. The technology-decision section (§3) is therefore mostly migration-mechanic decisions rather than stack choices; the cross-cutting concerns section (§4) carries most of the weight (grep-allow-list assertion, hook-latency preservation, archive byte-identity).

---

## 1. Context & Constraints

### 1.1 Existing stack — what is already committed

- **Bash 3.2 / BSD userland** (`.claude/rules/bash/bash-32-portability.md`). Every shipped script runs on macOS default shell. No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic.
- **`bin/` for user-facing CLIs**, no extension, exec bit (per `architect/script-location-convention.md`). Today's surface: `claude-symlink`, `specflow-seed`, `specflow-lint`, `specflow-tier`, `specflow-install-hook`, `specflow-aggregate-verdicts` — five of six filenames carry the old prefix.
- **`.claude/commands/specflow/*.md`** — 20 orchestrator slash-command files, YAML-frontmatter `description:` plus prose+code steps.
- **`.claude/agents/specflow/*.md`** — 7 agent roles (pm, architect, tpm, designer, developer, qa-analyst, qa-tester) + 3 reviewer agents + 4 `.appendix.md` tails; each agent's YAML frontmatter carries `name: specflow-<role>` (AC10 anchors one of these).
- **`.claude/hooks/session-start.sh` + `.claude/hooks/stop.sh`** — two hooks, together 13 `specflow|spec-workflow` hits; the stop hook carries the language-config-candidate list (`$XDG_CONFIG_HOME/specflow/`, `$HOME/.config/specflow/`). Hook wall-clock budget < 200 ms per `reviewer/performance.md` entry 7.
- **`.claude/rules/`** — 8 rule files; 5 of them reference the old names (13 hits, mostly cross-references in example prose).
- **`.claude/team-memory/`** — 83 `specflow|spec-workflow` hits across 31 memory files. R10 freezes filename slugs; only body prose is rewritten.
- **`.claude/skills/specflow-init/`** — single skill dir with `SKILL.md` + `init.sh` (7 hits total). Directory name itself is in scope.
- **`.claude/settings.local.json`** — two keys reference `.claude/specflow.manifest` (permission entries).
- **`.claude/specflow.manifest`** — per-project install manifest authored by `bin/claude-symlink` / `bin/specflow-seed`.
- **`.spec-workflow/archive/**`** — 11 archived feature slugs, byte-identically frozen by R11.
- **`test/smoke.sh` + 100+ `test/t*.sh`** — smoke harness and per-task verify scripts; many reference `specflow-*` binaries and `.spec-workflow/` paths.

### 1.2 Hard constraints

- **Archive byte-identity (R11 / AC8)** — no byte-level edits under `.specaffold/archive/**` except the rename-commit path-move itself. The rename commit's `git diff --stat` scoped to the archive subtree must show only renames, no body deltas.
- **Grep zero-hits outside allow-list (R6 / AC1)** — after the rename, `grep -rE "spec-workflow|specflow" .` must return zero hits except those listed in `.claude/carryover-allowlist.txt`. The allow-list itself lives in version control; any future addition is a reviewable diff.
- **Dogfood paradox (ninth+ occurrence, `shared/dogfood-paradox-third-occurrence.md`)** — the renaming mechanism is the harness being renamed. The `/specflow:validate` invocation that gates this feature's archive must run under the **old** command name (the command file is itself being renamed). Structural-only verification is the archive gate; runtime re-exercise lands on the next feature (R14 / AC11 deferred).
- **Bash 3.2 portability** for every shell decision introduced by this feature (assertion script, allow-list parser).
- **No `--force` defaults on user-owned paths** (`common/no-force-on-user-paths.md`) — the compat-symlink authoring in `bin/scaff-seed` (R17) classifies-before-mutate: create only if target absent or already a symlink pointing at `.specaffold`; never silent-clobber.
- **Absolute-symlink targets** (`common/absolute-symlink-targets.md`) — the `.spec-workflow → .specaffold` compat symlink uses an absolute target per R17.
- **Hook latency budget < 200 ms** (`reviewer/performance.md` entry 7, R8 / AC7) — the rename must not introduce new fork/exec paths in either hook.

### 1.3 Soft preferences

- **Prefer `git mv` over author-new + delete-old.** Every renamed path should appear as a rename entry in the commit (not as add+delete pair) so `git log --follow` stays clean and AC8 byte-identity is trivially checkable by `git diff --stat -M`.
- **Prefer `sed -i ''` with BSD-compatible two-arg form** over `awk | mv` when an in-place string substitution is sufficient; the two-arg form (`sed -i '' -e 's/old/new/g' file`) is portable on macOS bash 3.2 (per `.claude/rules/bash/bash-32-portability.md`).
- **Prefer batch-invocation assertion over per-file loops** (`reviewer/performance.md` entry 1) — the grep-allow-list assertion reads the full repo with one `grep -rE` call, not one call per file.

### 1.4 Forward constraints (what must not be made harder)

- **Future rename passes** (none planned) — the allow-list file and assertion script set the pattern: any future mass rewrite has a ready template.
- **Global install paths** (`~/.claude/agents/specflow/`, `~/.claude/commands/specflow/`) — D3 defers these to organic migration on the user's next `bin/claude-symlink install` or `bin/scaff-seed install`. The next feature after this one must not assume global paths are pre-migrated.
- **Runtime dogfood handoff to successor feature** — per the ninth-occurrence discipline, the RUNTIME HANDOFF STATUS line must be pre-committed as a **final-wave TPM task**, not an archive-time afterthought (cross-reference `shared/dogfood-paradox-third-occurrence.md` ninth-occurrence paragraph).

---

## 2. System Architecture

### 2.1 Rename surface taxonomy

The rename surface decomposes into seven independent **classes** (each wave-schedulable in parallel; inter-class dependencies explicit at §5 wave hint):

```
                         Rename surface (seven classes)

  C1  Slash-command files      .claude/commands/specflow/*.md
                                  → .claude/commands/scaff/*.md            (dir-rename + body rewrite)

  C2  Agent files              .claude/agents/specflow/*.md
                                  → .claude/agents/scaff/*.md              (dir-rename + frontmatter
                                                                             name:/description: rewrite
                                                                             + body rewrite)

  C3  bin/ scripts             bin/specflow-*        → bin/scaff-*         (file-rename + internal ref
                                                                             rewrite; path-authoring
                                                                             logic rewrite)

  C4  Hooks                    .claude/hooks/*.sh                          (body rewrite only —
                                                                             filenames do not change;
                                                                             latency budget enforced)

  C5  Rules + memory prose     .claude/rules/**, .claude/team-memory/**    (body rewrite only —
                                                                             filenames frozen per R10)

  C6  Skills dir               .claude/skills/specflow-init/
                                  → .claude/skills/scaff-init/             (dir-rename + body rewrite)

  C7  Root docs + config       README.md, settings.json, .claude/          (body rewrite +
                                settings.local.json, .claude/*.manifest     manifest-filename
                                                                             rename)

  D   .spec-workflow/ root     .spec-workflow/  → .specaffold/             (dir-rename)
  S   Compat symlink           .spec-workflow → .specaffold (absolute)     (author post-D; symlink
                                                                             is in R6 allow-list)
```

Classes C1–C7 are independent of each other at the filename-rename layer: a `git mv` on C1 has no bearing on C3's `git mv`. Cross-class references (C1's command bodies reference C2's agent names, C3's binary paths, and D's `.specaffold/` paths) are resolved in a second body-rewrite pass. See §5 wave hint.

### 2.2 Key data flow: the compat symlink

```
  repo-root/
  ├── .specaffold/              (renamed from .spec-workflow/, canonical)
  │   ├── archive/               (R11: byte-identical; internal paths say
  │   │   └── 20260419-.../     .spec-workflow/… — resolve via symlink)
  │   ├── features/
  │   ├── drafts/
  │   └── config.yml
  │
  └── .spec-workflow    ───────→ /abs/path/to/repo/.specaffold
                         (absolute-target symlink authored by bin/scaff-seed
                          on install/update; R17; in R6 allow-list)
```

Archived artefact `.specaffold/archive/20260419-flow-monitor/03-prd.md` contains the literal string `.spec-workflow/archive/20260419-flow-monitor/…` inside its prose. Any consumer that reads that string as a filesystem path (tests, tools, greps that resolve paths) follows the symlink and lands on the canonical file. The PRD text itself is unmodified per R11.

### 2.3 CLI alias mechanics

`scaff` is the **canonical user-facing CLI**, not a wrapper. Reasoning:

- The binaries being renamed are already six one-shot shell scripts, each invoked by name from slash-commands, hooks, and the user's shell. There is no "one entry point with subcommands" today; `specflow-seed`, `specflow-lint`, `specflow-tier` are sibling top-level commands, not subcommands of a parent.
- Introducing a `specaffold` canonical binary with `scaff` as a shell-alias wrapper would triple the install surface (two binary names + one alias) and invert the ergonomic choice users already made (they want to type `scaff`, not `specaffold`).
- Therefore: no `specaffold` binary exists. Users type `scaff-seed`, `scaff-lint`, `scaff-tier` etc. directly. The prose name "Specaffold" appears in README and docs as the product name; the shell surface uses the short form exclusively.

This is captured as D3 below. (The naming collision with `scaffold(1)` from Ruby-on-Rails era is a non-issue — `scaff` is six characters and distinct.)

---

## 3. Migration-mechanic decisions

### D1. Sequencing strategy — git-mv-first single-commit (option-a variant)

- **Options considered**:
  - (a) **All renames in one commit** — one huge `git mv` + body-rewrite commit; atomic cutover at merge; biggest blast radius for review.
  - (b) **Staged: file renames first, leave old-name symlinks as aliases, then remove symlinks in a follow-up** — violates D1 of the PRD (no deprecation alias window; hard cutover). Rejected.
  - (c) **Staged inverted: add new names as parallel copies, switch all callers, remove old names** — three-phase; doubles the command/agent surface mid-feature, violates PRD D1 (the allow-list would have to include the temporary parallel copies, defeating R6's purpose). Rejected.
  - (d) **Worktree-based** — do the whole rename in a separate worktree, verify self-dogfood works there, then fast-forward merge to main. Keeps main runnable through the entire rename. Reviewable as a single merge commit on main.

- **Chosen**: (a) **one-commit-per-wave with `git mv` preserved**, decomposed into four waves (§5 hint) — so the **final** merged topology looks like "one big rename" from a `main` perspective, but the wave-level commits keep review tractable. Each wave is a `git mv` + body-rewrite unit that the reviewer can inspect independently.

- **Why**: option (a) in its pure single-commit form is unreviewable (hundreds of file changes); option (d) adds worktree overhead with no safety benefit because the harness runs fine under the old names right up to the merge — the dogfood paradox is solved by the **command-file rename being the LAST wave**, not by an isolated worktree. The orchestrator invoking `/specflow:validate <slug>` during this feature's validate stage uses the **old** command file (still at `.claude/commands/specflow/validate.md`) because validate runs before the rename merges to the session that invokes it. A worktree adds complexity without changing that invariant.

- **Why not (b) or (c)**: both violate PRD D1 (no alias window, hard cutover). The PM pinned this intentionally so the grep allow-list (R6) stays minimal.

- **Tradeoffs accepted**: four commits to review instead of one; slight risk that a wave-N commit leaves the tree temporarily inconsistent between waves (e.g., C3 binaries renamed but C4 hooks still invoke old paths). Mitigation: wave ordering (§5) puts body-rewrite passes AFTER file-renames, so any intra-wave inconsistency is bounded to at most one wave-merge window, during which the feature's own dev session is the only consumer (no other feature is being archived in parallel).

- **Reversibility**: medium. A full revert is one `git revert` per wave commit (or a single compound revert of the merge commit), but revert after merge requires every downstream consumer to re-pull.

- **Requirement link**: PRD D1 (hard cutover), R6 (grep zero-hits), R11 (archive byte-identity).

### D2. Grep allow-list file format and location

- **Options considered**:
  - (i) Inline allow-list embedded in the assertion shell script (`test/t_grep_allowlist.sh`).
  - (ii) **Newline-delimited glob-pattern file at `.claude/carryover-allowlist.txt`** (path pre-confirmed in PRD R6).
  - (iii) YAML/JSON structured file with a reason field per entry.

- **Chosen**: (ii) — the plain-text file at the PRD-confirmed path `.claude/carryover-allowlist.txt`, one glob pattern per line, `#`-prefixed comment lines permitted. The assertion script (authored by QA-analyst per R6 ownership) reads the file with `while IFS= read -r line; do …` (bash 3.2 portable, no `mapfile`).

- **Why**: PRD R6 pins the path. Plain text is diffable, greppable, and sortable. JSON/YAML would require a parser in the assertion script (no `jq` per bash-32 portability rule). Inline embedding (option i) mixes data-that-changes-often with code-that-doesn't and defeats the "reviewable diff" property called out in PRD §6 (carryover allow-list drift).

- **Tradeoffs accepted**: no structured reason field per entry; reasons live in a leading comment block at the top of the file. Acceptable because the list is short (≈6–10 patterns) and the patterns themselves are self-documenting.

- **Reversibility**: high. File format can evolve; the only external contract is the assertion script's reader.

- **Requirement link**: R6, AC1.

- **Allow-list contents (initial)**:

  ```
  # .claude/carryover-allowlist.txt
  # Patterns (one per line, glob-matched against grep-hit filenames) that are
  # permitted to retain the old "spec-workflow" / "specflow" strings after the
  # rename. See 03-prd.md R6 and .specaffold/features/20260421-rename-to-specaffold/04-tech.md D2.

  .git/**
  .specaffold/archive/**
  .spec-workflow                          # the compat symlink itself (R17)
  .claude/carryover-allowlist.txt         # this file (reason comments reference old names)
  docs/rename-migration.md                # migration notes (R15); path confirmed at plan time
  .specaffold/features/20260421-rename-to-specaffold/RETROSPECTIVE.md
  ```

### D3. CLI alias authoring — `scaff-*` binaries are canonical, no `specaffold` wrapper

- **Options considered**:
  - (i) Single `specaffold` canonical binary with subcommand dispatch (`specaffold seed`, `specaffold lint`) + `scaff` wrapper script that execs it.
  - (ii) **Sibling `scaff-*` binaries (no parent), matching today's `specflow-*` sibling topology.**
  - (iii) Dual install: both `specaffold-*` and `scaff-*` exist as aliases via symlink pairs.

- **Chosen**: (ii). `bin/` contains `scaff-seed`, `scaff-lint`, `scaff-tier`, `scaff-install-hook`, `scaff-aggregate-verdicts` (+ `claude-symlink` which is **not** renamed — it was never prefixed). No `specaffold` binary exists.

- **Why**: preserves today's topology (R7 is a 1:1 rename, not a restructure); zero new entry-point code; matches user ergonomic preference (type `scaff`, not `specaffold`); keeps global install paths identical in shape (`~/.claude/bin/scaff-seed` replaces `~/.claude/bin/specflow-seed` directly).

- **Tradeoffs accepted**: the product-name "Specaffold" never appears as a bare binary; this is a prose/CLI split. Users read "Specaffold" in README, type `scaff-*` at the shell. Mitigation: README install section calls this out explicitly (R1 + R15 migration notes).

- **Reversibility**: high. A future feature could add a `specaffold` front-binary without touching the sibling `scaff-*` binaries.

- **Requirement link**: R5, R7, AC13.

### D4. Hook body rewrite — sed -i '' in place, no latency regression

- **Options considered**:
  - (i) Rewrite hooks by hand, preserving logic.
  - (ii) **`sed -i ''` two-arg form for string substitution** (BSD-compatible per bash-32-portability rule).
  - (iii) `awk` + `mv` (slightly more portable but more verbose for this case).

- **Chosen**: (ii) for the string-substitution portion of each hook; (i) review-pass over the result to verify logic is unchanged.

- **Why**: the hook rewrite is purely mechanical (s/specflow/scaff/g for binary names, s/\.spec-workflow/\.specaffold/g for dir paths); no new fork/exec is introduced in the hot path. `sed -i ''` is the idiomatic one-liner on macOS bash 3.2. The review-pass is belt-and-braces to confirm no logic drift.

- **Tradeoffs accepted**: none significant. The 200 ms hook latency budget (R8 / AC7) is measured after rewrite; any regression is a wave-merge BLOCK per the reviewer-performance axis.

- **Reversibility**: high; hooks are small (< 400 lines total).

- **Requirement link**: R8, AC7.

- **Wiring task**: QA-analyst's grep-allow-list assertion script (authored per R6 / AC1) must be invoked from the validate stage — not implicit. TPM must scope an explicit task that (a) authors `test/t_grep_allowlist.sh`, (b) wires it into `test/smoke.sh` or the validate command's dispatch, and (c) verifies exit-non-zero on unlisted hits. (Cross-reference `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md`.)

### D5. Compat-symlink authoring — owned by bin/scaff-seed, classify-before-mutate

- **Options considered**:
  - (i) Author the symlink once as a one-shot script in this feature's implement wave.
  - (ii) **Move authoring ownership into `bin/scaff-seed` (the renamed `bin/specflow-seed`)** — run on every `install` / `update`; R17 pre-resolves this.
  - (iii) Leave the symlink to be created manually by users who need it.

- **Chosen**: (ii) — PRD R17 pins this. `bin/scaff-seed` on `install` or `update` runs the classify-before-mutate pattern against the target path:

  - Classifier input: `<repo_root>/.spec-workflow`
  - Enum output: `missing | ok-ours | foreign-symlink | real-dir | real-file | broken-symlink`
  - Dispatch:
    - `missing` → `ln -s "<abs_repo_root>/.specaffold" "<repo_root>/.spec-workflow"` (absolute target per `common/absolute-symlink-targets.md`)
    - `ok-ours` → no-op (symlink already points at `.specaffold`)
    - `foreign-symlink` / `real-dir` / `real-file` → warn, skip (no `--force`, per `common/no-force-on-user-paths.md`)
    - `broken-symlink` → warn, skip (user must manually reconcile)

- **Why**: authoring from `scaff-seed` is idempotent across fresh and re-runs, survives repo-moves (absolute target per `common/absolute-symlink-targets.md`), and uses the established classify-before-mutate pattern (`common/classify-before-mutate.md`, `architect/classification-before-mutation.md`). Option (i) would leave new-install environments without the symlink.

- **Tradeoffs accepted**: first-time users who clone the repo but never run `bin/scaff-seed install` will not have the compat symlink and may see broken internal paths inside archived artefacts when resolving them as filesystem paths. Mitigated by README install section instructing `bin/scaff-seed install` as step 1.

- **Reversibility**: medium. Removing the symlink is a one-line `rm .spec-workflow`; the classifier's `missing` arm then recreates it on next install.

- **Requirement link**: R17, AC15.

- **Wiring task**: `bin/scaff-seed`'s install/update subcommands must call the new `ensure_compat_symlink` function; the function-authoring task and the call-site wiring are **distinct** — TPM must not leave wiring implicit (cross-reference `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md`).

### D6. Orphan cleanup command for global install paths

- **Options considered**:
  - (i) No cleanup; users' `~/.claude/agents/specflow/` dirs persist silently as orphans.
  - (ii) **Document a one-line cleanup command in migration notes** (`rm -rf ~/.claude/agents/specflow ~/.claude/commands/specflow`).
  - (iii) Add an `--orphan-cleanup` flag to `bin/claude-symlink` / `bin/scaff-seed`.

- **Chosen**: (ii). Migration notes (R15) document the one-line cleanup; users who care run it once. No CLI code changes.

- **Why**: PRD D3 pins the "organic migration" posture — the next `claude-symlink install` / `scaff-seed install` writes the new paths; old dirs become orphans only in the user's global `~/.claude/` space, which is never read by the repo. Adding a CLI flag for this couples feature scope to user-owned state we deliberately do not touch.

- **Tradeoffs accepted**: users who never read migration notes will leave orphan dirs under `~/.claude/` indefinitely. Low-severity — the orphans are dormant and consume negligible space.

- **Reversibility**: high. A follow-up feature can add a `--orphan-cleanup` flag if the orphan count becomes a support issue.

- **Requirement link**: R16, D3, R15.

---

## 4. Cross-cutting Concerns

### 4.1 Grep-allow-list assertion (QA-analyst-owned)

The single structural AC gating archive (AC1) is a shell-executed `grep -rE "spec-workflow|specflow" .` against the repo root, post-filtered by the allow-list file (D2). The assertion script:

```bash
#!/usr/bin/env bash
# test/t_grep_allowlist.sh
set -euo pipefail

ALLOWLIST=".claude/carryover-allowlist.txt"
[ -f "$ALLOWLIST" ] || { echo "FAIL: $ALLOWLIST missing" >&2; exit 2; }

# Read allow-list patterns (bash 3.2: no mapfile; while-read loop)
patterns=""
while IFS= read -r line; do
  case "$line" in
    ""|\#*) continue ;;  # skip blank and comment lines
    *) patterns="$patterns $line" ;;
  esac
done < "$ALLOWLIST"

# Run grep once (not per-file — reviewer/performance.md entry 1)
hits="$(grep -rEn "spec-workflow|specflow" . 2>/dev/null || true)"

# Filter hits: each hit line shape is "path:line:match"; strip to "path" and
# test against each allow-list pattern via `case` glob (bash 3.2: no [[ =~ ]]).
fail_count=0
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  path="${hit%%:*}"
  allowed=0
  for pat in $patterns; do
    case "$path" in
      $pat) allowed=1; break ;;
    esac
  done
  if [ $allowed -eq 0 ]; then
    printf 'UNLISTED: %s\n' "$hit" >&2
    fail_count=$((fail_count + 1))
  fi
done <<EOF
$hits
EOF

if [ $fail_count -gt 0 ]; then
  printf 'FAIL: %d unlisted carryover hit(s)\n' "$fail_count" >&2
  exit 1
fi
printf 'PASS: all carryover hits allow-listed\n'
```

QA-analyst owns the script (per PRD §6 "carryover allow-list drift"). It is invoked from the validate-stage workflow; TPM must scope an explicit task for both authorship and wiring (D4 wiring-task note).

### 4.2 Archive byte-identity preservation (AC8)

The `.spec-workflow/` → `.specaffold/` rename is a directory move. To preserve `git log --follow` ancestry and satisfy AC8, the rename commit:

1. Uses `git mv .spec-workflow .specaffold` (git records as rename, not delete+add).
2. Makes **zero body edits** under `.specaffold/archive/**` in that same commit.
3. Verification post-commit: `git diff --stat -M HEAD~1 -- .specaffold/archive/` must list only `{old} => {new}` rename entries with `(100%)` similarity; any non-100% entry is a BLOCK.

The archived artefacts internally reference `.spec-workflow/…` paths. Those references resolve via the compat symlink (D5) authored by `bin/scaff-seed` in a **later** wave than the dir-rename itself. Between the dir-rename wave merging and the compat-symlink authoring task running on the developer's machine, archived paths resolved as filesystem paths will transiently fail to resolve — this is acceptable because nothing consumes archived paths as filesystem operations during the implement window (archive is read-only per R11).

### 4.3 Hook latency preservation (AC7)

`reviewer/performance.md` entry 7 mandates total hook wall-clock < 200 ms on a warm cache. Rename is a body-rewrite; no new fork/exec paths enter hot-path code. QA-analyst measures hook latency before and after the rename commit using `time .claude/hooks/session-start.sh < /dev/null` and `time .claude/hooks/stop.sh < /dev/null`; both must remain < 200 ms. Budget delta is reported in 08-validate.md.

### 4.4 Self-dogfood (structural) — AC9/AC10 cross-reference

- `.claude/commands/scaff/request.md` (renamed from `.claude/commands/specflow/request.md`) body must reference the PM agent name `scaff-pm` (AC9).
- `.claude/agents/scaff/pm.md` (renamed from `.claude/agents/specflow/pm.md`) frontmatter must read `name: scaff-pm` (AC10).

These two ACs anchor the structural self-dogfood. The runtime exercise (AC11 / R14) is deferred to the **next** feature archived after this one, per the dogfood paradox pattern. TPM pre-commits the RUNTIME HANDOFF STATUS line in the final wave (see §5 wave hint).

### 4.5 Testing strategy

Structural verification dominates (11 of 15 ACs). The test shape is:

- **t_grep_allowlist.sh** — authored this feature; assertion for AC1.
- **AC2–AC7, AC12–AC15** — direct `grep`/`ls`/`readlink` assertions, one per AC, packaged as small shell scripts in `test/` (TPM decomposes at plan time).
- **AC8** — `git diff --stat -M` scoped to archive subtree; trivially checkable if D1 sequencing holds.
- **AC9, AC10** — one-line grep per file.
- **AC11** — runtime-deferred; no in-feature test.

No new test framework; all tests are bash scripts invoked from `test/smoke.sh` per today's convention.

### 4.6 Security posture

No new security surface. The compat-symlink authoring follows `common/no-force-on-user-paths.md` (no silent clobber), `common/absolute-symlink-targets.md` (absolute targets), and `common/classify-before-mutate.md` (classifier dispatch). No user input crosses a trust boundary; rename runs against the repo's own files only.

---

## 5. Wave decomposition hint (for TPM)

Decomposition is a **TPM-owned** artefact authored in 05-plan.md; this section is a structural hint only. The seven rename-surface classes from §2.1 decompose into four waves. Each wave is a `git mv` + body-rewrite unit; classes within a wave are independent (parallel-safe); waves between are sequential (later depends on earlier).

```
  W1  — File renames (parallel-safe within wave)
         - C1  git mv .claude/commands/specflow → .claude/commands/scaff
         - C2  git mv .claude/agents/specflow   → .claude/agents/scaff
         - C3  git mv bin/specflow-*            → bin/scaff-*  (per binary)
         - C6  git mv .claude/skills/specflow-init → .claude/skills/scaff-init
         - D   git mv .spec-workflow            → .specaffold
         - C7  git mv .claude/specflow.manifest → .claude/scaff.manifest  (+ settings.local.json key update)
       Rationale: all C1–C7 + D renames are filesystem-independent of each other. AC8 (archive byte-identity)
       holds trivially within this wave because no body edits occur.

  W2  — Body rewrites inside renamed files (parallel-safe within wave; depends on W1 paths existing)
         - C1.body  rewrite command-file prose/codeblocks: specflow → scaff, .spec-workflow → .specaffold
         - C2.body  rewrite agent frontmatter name:/description: + body prose
         - C3.body  rewrite bin/scaff-* internal references + path-authoring logic
         - C6.body  rewrite .claude/skills/scaff-init/SKILL.md + init.sh
         - C7.body  rewrite README.md + settings.json (none currently but latent) + any root docs

  W3  — Peripheral body rewrites + new artefacts (parallel-safe within wave; depends on W2 naming stable)
         - C4  .claude/hooks/session-start.sh + stop.sh body rewrite (sed -i '' per D4)
         - C5  .claude/rules/**, .claude/team-memory/** body-prose rewrite (R9/R10)
         - D5  bin/scaff-seed: add ensure_compat_symlink function + install/update wiring (R17)
         - D2  .claude/carryover-allowlist.txt authored
         - R15  docs/rename-migration.md authored (path confirmed by TPM at plan)
         - D4-wiring  test/t_grep_allowlist.sh authored + wired into validate

  W4  — LAST: the dogfood-paradox cutover
         - rename .claude/commands/specflow/validate.md body-updates + finalise the rename so /specflow:validate
           stops existing. NOTE: by this wave, the command file has ALREADY been renamed in W1; W4 is about
           verifying the whole rename is self-consistent and the pre-committed RUNTIME HANDOFF STATUS line
           is in place (per shared/dogfood-paradox-third-occurrence.md ninth-occurrence discipline).
         - RUNTIME HANDOFF STATUS line pre-committed as an explicit TPM-owned task in W4, with wording:
             RUNTIME HANDOFF (for successor feature): opening STATUS Notes line must read
             "YYYY-MM-DD orchestrator — Specaffold rename exercised on this feature's first live session".
             1 runtime AC deferred (AC11); see 03-prd.md §9 AC-R14.
```

**Dogfood-paradox resolution**: this feature's `/specflow:validate <slug>` invocation runs under the **old** command name (the command file was renamed in W1 but the orchestrator's slash-command dispatch in the current dev session is bound to the old name, resolving via the file's W1-renamed location because symlink-based resolution short-circuits the name check at filesystem-read time). This is **intentional**: validate runs structurally against the renamed tree; live exercise of `/scaff:validate` is deferred to the successor feature (AC11). If the orchestrator cannot resolve `/specflow:validate` post-W1 (because the dispatch table rebound to `/scaff:validate`), the escape hatch is manual shell invocation of the assertion scripts from §4 — no harness is strictly required.

---

## 6. Open Questions

None — all PRD-level blockers resolved in §8 (D1–D6). Migration-mechanic decisions resolved in this doc (D1–D6). TPM can proceed to `/specflow:plan` without further clarification.

---

## 7. Non-decisions (deferred)

- **Orphan cleanup as a CLI flag** — D6 chose migration-notes over CLI-flag. A follow-up feature can add `--orphan-cleanup` to `bin/scaff-seed` if user reports pile up.
- **GitHub repo rename** — explicitly out of scope per PRD §3. User-owned operational step.
- **Repo working-tree directory rename on disk** — out of scope per PRD D2. Recovery via `bin/claude-symlink install` post-rename is documented in `common/absolute-symlink-targets.md`.
- **Global install path migration** — D3 / R16 / D6 above; organic migration on next install invocation. Not decided here: whether a future feature should rename the global dirs proactively.

---

## Team memory

- `shared/dogfood-paradox-third-occurrence.md` (ninth-occurrence paragraph) — applied: W4 is the cutover wave; pre-committed RUNTIME HANDOFF STATUS line is an explicit TPM task; AC11 is runtime-deferred per the discipline.
- `architect/classification-before-mutation.md` + `common/classify-before-mutate.md` — applied: the compat-symlink authoring in `bin/scaff-seed` uses the six-state classifier (`missing | ok-ours | foreign-symlink | real-dir | real-file | broken-symlink`) with table dispatch (D5).
- `architect/no-force-by-default.md` + `common/no-force-on-user-paths.md` — applied: compat-symlink authoring report-and-skips on `foreign-symlink` / `real-*` states; no `--force` flag added.
- `architect/shell-portability-readlink.md` + `common/absolute-symlink-targets.md` — applied: compat-symlink target is absolute per rule; no `readlink -f`.
- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` — applied: the D4 grep-allow-list assertion and the D5 `ensure_compat_symlink` function both carry **Wiring task** notes so TPM scopes the wiring-site edit as a distinct task from the function authorship.
- `architect/script-location-convention.md` — applied: all renamed CLIs remain in `bin/` with no extension; skill files stay under `.claude/skills/`.

Proposed new memory (promote at archive only if the pattern holds):
- `architect/self-renaming-harness-last-wave-cutover.md` — features that rename their own command-dispatch surface should place the command-file renames in the last wave or use file-move-without-rename-edit in an earlier wave so the running orchestrator continues to dispatch through the renamed files by filesystem lookup (paths resolve because dispatch reads the file at call time, not a cached name table). Will evaluate at archive whether this generalises beyond the `specflow` → `scaff` case.
