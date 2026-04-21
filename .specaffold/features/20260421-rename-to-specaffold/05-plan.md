# Plan — rename-to-specaffold

**Feature**: `20260421-rename-to-specaffold`
**Stage**: plan
**Author**: TPM
**Date**: 2026-04-21
**Tier**: standard (merged plan + task checklist — new-shape per `/specflow:plan`)

PRD: `03-prd.md` (R1–R17, AC1–AC15, §8 D1–D6 user-pinned).
Tech: `04-tech.md` (§3 D1–D6 migration-mechanic decisions, §5 wave hint).

---

## 1. Approach

This is a **rename-only** pass — no functional changes, no new surfaces. Every user-visible mention of `specflow` / `spec-workflow` is replaced with the `Specaffold` / `scaff` pair; archived artefacts are preserved byte-identical and resolved through a backwards-compat symlink.

The architect's four-wave strategy is preserved:

- **W1 — filesystem moves via `git mv` + compat symlink** — all directory / file renames in one parallel-safe wave. The `.spec-workflow → .specaffold` compat symlink is authored immediately after the dir rename in the same wave (not deferred to W3) so the transient path-resolution gap never opens (see §4 resolution of architect flag #2). W1 preserves AC8 byte-identity trivially: `git mv` + no body edits within this wave.
- **W2 — body rewrites inside renamed files** — cross-class references (command bodies cite agent names, bin scripts cite paths, agent frontmatter `name:` fields) are updated in parallel-safe tasks, one class per task.
- **W3 — peripheral body rewrites + new artefacts** — hooks (`sed -i ''` mechanical), rules/memory prose, the formal `ensure_compat_symlink` function in `bin/scaff-seed`, the allow-list file, the grep-assertion script and its wiring, and the migration notes document.
- **W4 — cutover + RUNTIME HANDOFF** — final self-consistency grep assertion green; RUNTIME HANDOFF STATUS line pre-committed (ninth-occurrence dogfood-paradox discipline from `shared/dogfood-paradox-third-occurrence.md`); structural self-dogfood re-check.

The running harness operates under the **old** names right up to merge. After merge + session restart, the first `/scaff:*` dispatch on the next feature is the runtime exercise of AC11 / R14 (deferred per the dogfood paradox).

---

## 2. Wave schedule

| Wave | Purpose | Task IDs | Parallelisation notes |
|------|---------|----------|-----------------------|
| **W1** | `git mv` filesystem moves + compat symlink authoring | T1–T8 | T1–T7 write to disjoint paths (parallel-safe). T8 (compat symlink) runs at end of W1 after T6 (`.spec-workflow → .specaffold` dir rename) completes; T8 serial-within-wave. |
| **W2** | Body rewrites inside renamed files | T9–T16 | All tasks write to disjoint file classes (command-files, agent-files, bin-files, etc.); parallel-safe. |
| **W3** | Peripheral rewrites + new artefacts | T17–T27 (incl. T21a/T21b/T21c split) + T21d (closeout) [CHANGED 2026-04-21] | T17–T24 edit disjoint surfaces (hooks, rules, memories) — parallel-safe. T21 is split into T21a (`shared/` subtree) + T21b (per-role subtrees) for finer parallel-safety. T21c (new; body rewrite in `test/**/*.sh`) writes only to `test/` — parallel-safe with all other W3 tasks except T24 (both edit `test/smoke.sh`); T24 depends on T21c. T21d (new; T28 closeout) is a serial post-wave closeout depending on every other W3 task; not parallel-safe with any W3 peer. [CHANGED 2026-04-21] T25 (`ensure_compat_symlink` function) and T26 (call-site wiring in `scaff-seed install`/`update`) are sequential within W3: T26 depends on T25. T27 (migration notes) is standalone. |
| **W4** | Cutover + final assertion + RUNTIME HANDOFF | T28–T31 | T28 (grep-allow-list green) gates T29–T31. T29 (RUNTIME HANDOFF STATUS line pre-commit) + T30 (final self-consistency check on AC9/AC10) + T31 (AC15 symlink verify) are parallel-safe among themselves. |

**Wave count**: 4. **Task count**: 34 total (T1–T31 with T21 split into T21a + T21b + T21c + T21d). **Per-wave counts**: W1 = 8 · W2 = 8 · W3 = 14 · W4 = 4. [CHANGED 2026-04-21]

### Parallel-safety analysis per wave

**W1** — All `git mv` tasks touch non-overlapping path namespaces. T1 (`.claude/commands/specflow → scaff`) and T2 (`.claude/agents/specflow → scaff`) operate on sibling directories. T6 (`.spec-workflow → .specaffold`) touches the repo root but at a disjoint path; does not collide with T1–T5. T7 (`.claude/specflow.manifest → .claude/scaff.manifest` + `settings.local.json` key update) is the only W1 task that edits file *bodies* — but `settings.local.json` is not touched by any other W1 task. T8 (compat symlink `.spec-workflow → .specaffold`) must run after T6 completes (depends on T6) but before W2 starts; treat as serial-within-W1.

**W2** — Each task edits a distinct class of files under already-renamed paths. T9 edits `.claude/commands/scaff/**`, T10 edits `.claude/agents/scaff/**`, T11 edits `bin/scaff-*`, T12 edits `.claude/skills/scaff-init/**`, T13 edits `README.md` + root docs, T14 edits `.claude/settings.local.json` (if any residual string refs remain post-T7), T15 edits the `.claude/scaff.manifest` body if paths inside it changed, T16 is a cross-class consistency check (read-only, so always parallel-safe).

**W3** — T17 (session-start.sh) + T18 (stop.sh) write to different hook files. T19 (rule-prose rewrite in `.claude/rules/common/absolute-symlink-targets.md` + `language-preferences.md`) touches different files than T20 (rule-prose in `.claude/rules/bash/*` + `reviewer/*`). T21 (team-memory prose pass — split into T21a for `.claude/team-memory/shared/` + T21b for per-role dirs; both edit disjoint subtrees). T21c (new, body rewrite in `test/**/*.sh`) writes only to the `test/` subtree — disjoint from every other W3 surface (hooks, rules, memories, `.claude/carryover-allowlist.txt`, `docs/`, `bin/scaff-seed`); the one same-file collision is `test/smoke.sh` which T24 also edits, so **sequential-within-W3** against T24 — T24 depends on T21c (T24 appends one registration line after T21c's mechanical body rewrite lands). [CHANGED 2026-04-21] T22 authors `.claude/carryover-allowlist.txt` (new file — no collision). T23 authors `test/t_grep_allowlist.sh` (new file — no collision with T21c which rewrites existing files). T24 wires the assertion into `test/smoke.sh` (write to shared file, so **sequential-within-W3** against T23 and T21c — T24 depends on both). [CHANGED 2026-04-21] T25 (adds `ensure_compat_symlink` function to `bin/scaff-seed`) is sequential against T26 (wires the function into `install`/`update` subcommands) — T26 depends on T25, both edit `bin/scaff-seed`. T27 (`docs/rename-migration.md` new file) is standalone. T21d (new; T28 closeout) is a **serial post-wave closeout** — it depends on every other W3 task (T17–T27) and is not parallel-safe with any W3 peer; it runs after the rest of W3 lands to sweep the residual files surfaced by the t_grep_allowlist.sh dry-run (8 non-flow-monitor files + flow-monitor subtree allow-list entry + build-artefact .gitignore coverage). [CHANGED 2026-04-21]

**W4** — T28 (run grep-allow-list assertion green) is the gating task. T29 (RUNTIME HANDOFF STATUS line) writes to `STATUS.md` only. T30 (AC9/AC10 cross-ref check) and T31 (AC15 symlink verify) are read-only structural checks; parallel-safe among themselves and with T29 (T29 writes a different file).

---

## 3. Risks

1. **Dogfood paradox (ninth+ occurrence)** — This feature renames its own orchestration surface. The running session continues to dispatch through the old `/specflow:*` command names even after W1 renames the command files, because Claude Code slash-command dispatch reads the command file at call time by filesystem lookup (not via a cached name table). Mitigation: structural AC gates archive; AC11 is explicitly runtime-deferred; T29 pre-commits the RUNTIME HANDOFF STATUS line in W4. Cross-reference: `shared/dogfood-paradox-third-occurrence.md` ninth-occurrence paragraph.

2. **Transient W1-to-W3 path-resolution gap** — Between `.spec-workflow → .specaffold` dir-rename and compat-symlink authoring, archived artefacts' internal `.spec-workflow/…` path references fail to resolve as filesystem operations. **Mitigated by moving symlink authoring into W1** (T8 immediately after T6); see §4 flag #2 resolution. The formal `ensure_compat_symlink` function in `bin/scaff-seed` still lands in W3 (T25/T26) for idempotent install-time behaviour on fresh clones; W1's T8 is the one-shot authoring for this feature's merge.

3. **Hook latency regression** — R8 / AC7 caps hook wall-clock at 200ms. W3 body rewrites in `session-start.sh` / `stop.sh` must be purely mechanical (no new fork/exec). Mitigation: T17/T18 are `sed -i ''` substitutions only; QA-analyst measures `time .claude/hooks/*.sh < /dev/null` before/after and records the delta in `08-validate.md` per tech §4.3.

4. **Archive byte-identity (AC8)** — W1 T6 uses `git mv .spec-workflow .specaffold` with zero body edits in that commit. Verification: `git diff --stat -M HEAD~1 -- .specaffold/archive/` must list only rename entries with `(100%)` similarity.

5. **Self-directory-rename dogfood** — The active feature dir `/.spec-workflow/features/20260421-rename-to-specaffold/` is itself moved by W1 T6. The plan file the orchestrator is reading moves with it. Mitigation: the orchestrator re-resolves the feature dir path from STATUS at each stage invocation (no cached path); T8's compat symlink additionally makes the old path resolvable. All agent invocations after W1 reference the feature dir via the canonical new path `.specaffold/features/20260421-rename-to-specaffold/`. See §4 discussion.

6. **Validate-command self-reference at archive** — After W1 renames `.claude/commands/specflow/validate.md` → `.claude/commands/scaff/validate.md`, a same-session re-invocation of `/specflow:validate` may fail to resolve because the file no longer exists at the old path. **Resolved by confirming filesystem-lookup invariant** (see §4 flag #1 resolution); escape hatch added as T23's assertion script being independently shell-invocable.

7. **Carryover allow-list drift** — If future plan iterations add new migration notes or rename artefacts, the R6 allow-list must grow to match. Mitigation: the list lives in `.claude/carryover-allowlist.txt` (authored by T22); the T23 assertion script reads it, making any addition a reviewable diff.

8. **Pre-checked checkboxes anti-pattern** — Per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`, every `- [ ]` below stays unchecked; TPM never writes `- [x]` at plan time. The orchestrator's per-wave bookkeeping commit is the sole `[x]` writer.

---

## 4. Non-blocking architect-flag resolutions

### Flag #1 — Validate-command self-reference at archive

**Resolution**: verify-invariant + belt-and-braces escape hatch.

- **Verified invariant**: Claude Code slash-command dispatch is filesystem-lookup-at-call-time — the orchestrator reads `.claude/commands/<ns>/<name>.md` at each invocation; there is no cached name table. Confirmed by inspecting `.claude/commands/specflow/validate.md` (no indirect dispatch; the file is read as-is at each call). After W1 renames the command files, a re-invocation of `/specflow:validate` in the same session will fail to resolve the old path — but this is acceptable because validate only needs to run **once** per feature, and that invocation happens **before** W1 merges (W1 is the first wave of implement; validate runs after implement).
- **Escape hatch**: T23 authors `test/t_grep_allowlist.sh` as a standalone bash script invokable by direct shell execution (`bash test/t_grep_allowlist.sh`). If the slash-command dispatch breaks for any reason mid-feature, the validate stage's structural work can still be exercised by shelling out to the assertion script directly. T28 (W4) runs this assertion green as the gate for archive advance. This preserves structural validate capability even if `/specflow:validate` cannot resolve.

### Flag #2 — Transient W1-to-W3 path-resolution gap

**Resolution**: move-symlink-forward.

- W1's T8 authors the compat symlink `.spec-workflow → .specaffold` immediately after T6's dir-rename completes. The symlink is absolute-target per `common/absolute-symlink-targets.md`. No transient gap exists.
- The formal `ensure_compat_symlink` function in `bin/scaff-seed` (T25/T26 in W3) remains for idempotent install-time behaviour on fresh clones and on `update` runs — but W1 does not depend on the function; T8 uses a direct `ln -s "$PWD/.specaffold" .spec-workflow` after confirming the target is absent (classify-before-mutate: missing → create; any other state → fail loud). This one-shot is redundant with T25/T26 on a fresh clone that never ran this feature's implement, but correct for the one-time merge event.
- Consequence: T6 and T8 are both in W1 but T8 depends on T6. T1–T5 / T7 are parallel-safe with T6 (different paths) but not with T8 (T8 depends on the post-T6 state). Wave-internal ordering: T1–T7 in the first parallel batch, T8 serial after all seven complete.

---

## 5. Self-directory-rename dogfood handling

The active feature directory is `.spec-workflow/features/20260421-rename-to-specaffold/`. W1 T6 renames `.spec-workflow → .specaffold`, moving this plan file along with it. Approach:

1. **Orchestrator path re-resolution contract**: every stage-dispatch in `/specflow:next` re-reads `STATUS.md` at the *current canonical path* and derives the feature dir from slug. After T6, the canonical path is `.specaffold/features/20260421-rename-to-specaffold/`. The compat symlink (T8) additionally keeps the old path (`.spec-workflow/features/20260421-rename-to-specaffold/`) resolvable, so any agent invocation that still references the old path via absolute or repo-relative path will not break.
2. **Wave bookkeeping**: post-W1, the orchestrator's bookkeeping commit must log `STATUS.md` updates using the new canonical path. This is an orchestrator discipline, not a TPM task — flag in the Notes line.
3. **Agent briefings authored in W2 onward**: must cite files using the new canonical prefix `.specaffold/features/20260421-rename-to-specaffold/` (e.g. `$FEATURE_DIR/05-plan.md` where `FEATURE_DIR=.specaffold/features/20260421-rename-to-specaffold`).
4. **No atomic rename-and-handoff task** (alternative design considered and rejected): packaging "dir rename + handoff" as a single final task would push T6 to W4, which breaks W2/W3 (they need `.specaffold/` to exist to rewrite bodies inside it). The correct sequencing is dir-rename in W1 + orchestrator re-resolves feature-dir path on every subsequent stage.

---

## 6. Sequencing rationale

- **Why 4 waves, not 1?** Architect §3 D1 rejected the one-commit-per-wave option for reviewability. A single merge with ~120 file changes is unreviewable; four waves produce four review-able commit boundaries.
- **Why not 6 waves?** The rename-surface taxonomy (tech §2.1) has seven classes, but five of them (C1/C2/C3/C6/C7 plus D) are purely filesystem-rename operations that share no body-rewrite dependencies — they parallelise cleanly into one wave (W1). Splitting them across 2–3 waves adds review overhead with no mitigation benefit. Similarly W2's body rewrites have no intra-wave dependencies (each class edits disjoint files). Four waves is the minimum that preserves the critical constraint "file moves before body rewrites; peripheral rewrites and new artefacts after core renames; RUNTIME HANDOFF + final assertion in a dedicated wave".
- **Why `git mv`, not manual rename + delete?** AC8 byte-identity verification depends on `git diff --stat -M` recognising rename entries with `(100%)` similarity. Manual add-delete pairs produce `delete file.md + add file.md` diff entries and defeat `git log --follow`. Architect §1.3 soft preference pins `git mv`.
- **Why compat symlink in W1, not W3?** Architect flagged this as non-blocking but left the decision to TPM. Moving it to W1 closes the transient path-resolution gap (risk 2) at negligible cost; the dedicated W3 function (`ensure_compat_symlink` in `scaff-seed`) still serves fresh-clone installs going forward.

---

## 7. Review posture

Standard tier per `04-tech.md`: inline reviewers run per wave merge on security + performance + style axes. Relevant axis hits anticipated:

- **Performance** — W3 hook-latency check (AC7); `sed -i ''` in-place vs `awk | mv` choice is already D4-pinned; no fork/exec regressions expected.
- **Security** — W1/W3 compat-symlink authoring follows `common/no-force-on-user-paths.md` + `common/classify-before-mutate.md` + `common/absolute-symlink-targets.md`. T8 (W1) uses classify-before-mutate: create only if target absent; no `--force`. T25/T26 (W3) expands to the full six-state classifier.
- **Style** — bash 3.2 portability (`reviewer/style.md` rule 5): T23's assertion script uses `while IFS= read -r` (no `mapfile`), `case`-glob matching (no `[[ =~ ]]`), no `readlink -f`. Tests use the `sandbox-HOME` discipline from `reviewer/style.md` rule 6.

Aggregated verdict = PASS or NITS gates the wave merge. The dogfood paradox means reviewers for this feature's own validate stage run under the **old** `/specflow:review` dispatch (per `04-tech.md` §1.2).

---

## 8. Task list

Each task below has `**what**`, `**why-AC**` (cites R/AC), `**files**`, `**dep**` (task IDs or `none`), `**wave**` (W1–W4), `**acceptance**` (runnable command or structural check).

### W1 — Filesystem moves via `git mv` + compat symlink

- [x] T1. `git mv` slash-command directory `.claude/commands/specflow/` → `.claude/commands/scaff/`
  - **what**: move all 20 command files from `specflow/` to `scaff/` via `git mv` (preserves rename ancestry).
  - **why-AC**: R2, AC4.
  - **files**: `.claude/commands/specflow/` (source) → `.claude/commands/scaff/` (target); all 20 child `.md` files follow the dir.
  - **dep**: none.
  - **wave**: W1.
  - **acceptance**: `test -d .claude/commands/scaff && ! test -d .claude/commands/specflow` returns 0; `git diff --stat -M HEAD~1 -- .claude/commands/` shows all entries as renames `(100%)`.

- [x] T2. `git mv` agent directory `.claude/agents/specflow/` → `.claude/agents/scaff/`
  - **what**: move all 14 agent files (7 roles + 3 reviewers + 4 appendices) from `specflow/` to `scaff/`.
  - **why-AC**: R3, AC5.
  - **files**: `.claude/agents/specflow/` → `.claude/agents/scaff/`.
  - **dep**: none.
  - **wave**: W1.
  - **acceptance**: `test -d .claude/agents/scaff && ! test -d .claude/agents/specflow` returns 0; `git diff --stat -M HEAD~1 -- .claude/agents/` shows all renames `(100%)`.

- [x] T3. `git mv` each `bin/specflow-*` binary to `bin/scaff-*`
  - **what**: rename `bin/specflow-aggregate-verdicts`, `bin/specflow-install-hook`, `bin/specflow-lint`, `bin/specflow-seed`, `bin/specflow-tier` — one `git mv` per file (5 total). `bin/claude-symlink` is NOT renamed (never carried the prefix; per tech §D3).
  - **why-AC**: R7, AC6.
  - **files**: 5 `bin/specflow-*` source paths → 5 `bin/scaff-*` target paths.
  - **dep**: none.
  - **wave**: W1.
  - **acceptance**: `ls bin/ | grep -E '^specflow-' | wc -l` returns 0; `ls bin/scaff-* | wc -l` returns 5.

- [x] T4. `git mv` skill directory `.claude/skills/specflow-init/` → `.claude/skills/scaff-init/`
  - **what**: rename the skill dir. Body rewrites inside `SKILL.md` and `init.sh` land in W2 T12.
  - **why-AC**: R4 (skill is under `.claude/` not root docs, but the dir name is user-visible in the skill surface).
  - **files**: `.claude/skills/specflow-init/` → `.claude/skills/scaff-init/`.
  - **dep**: none.
  - **wave**: W1.
  - **acceptance**: `test -d .claude/skills/scaff-init && ! test -d .claude/skills/specflow-init` returns 0.

- [x] T5. `git mv` manifest file `.claude/specflow.manifest` → `.claude/scaff.manifest`
  - **what**: rename the per-project install manifest. Body contents (which reference old-prefix paths inside) are rewritten in W2 T15 — T5 only moves the filename.
  - **why-AC**: R6 (the manifest filename is in scope), R7.
  - **files**: `.claude/specflow.manifest` → `.claude/scaff.manifest`.
  - **dep**: none.
  - **wave**: W1.
  - **acceptance**: `test -f .claude/scaff.manifest && ! test -f .claude/specflow.manifest` returns 0.

- [x] T6. `git mv` workflow root directory `.spec-workflow/` → `.specaffold/`
  - **what**: rename the root workflow dir — moves the entire subtree including this active feature's `05-plan.md`, archived features under `archive/`, drafts, and `config.yml`. CRITICAL: zero body edits in this commit (AC8 byte-identity guarantee).
  - **why-AC**: R11, R12, AC8.
  - **files**: `.spec-workflow/` → `.specaffold/` (subtree move).
  - **dep**: none (T7 edits `settings.local.json` independently; T1–T5 touch disjoint paths).
  - **wave**: W1.
  - **acceptance**: `test -d .specaffold && ! test -d .spec-workflow` (before T8) returns 0; `git diff --stat -M HEAD~1 -- .specaffold/archive/ | awk '$NF!~/^R[0-9]+/{print}' | wc -l` returns 0 (no non-rename entries in the archive subtree).

- [x] T7. Update `.claude/settings.local.json` to reference the renamed manifest path
  - **what**: two keys currently reference `.claude/specflow.manifest` (permission entries). Rewrite these to `.claude/scaff.manifest`. Per `common/no-force-on-user-paths.md`: read → back up → write-temp → atomic rename.
  - **why-AC**: R6 (grep zero-hits requires settings.local.json to carry no old-prefix strings outside the R6 allow-list; this file is NOT in the allow-list).
  - **files**: `.claude/settings.local.json` (edit two string values referencing the manifest path).
  - **dep**: none (T5 renames the file; T7 updates the referent. T5 and T7 both write to disjoint surfaces — T5 is a git mv, T7 is a body edit inside settings.local.json. Parallel-safe.).
  - **wave**: W1.
  - **acceptance**: `grep -c "specflow.manifest" .claude/settings.local.json` returns 0; `grep -c "scaff.manifest" .claude/settings.local.json` returns 2.

- [x] T8. Author backwards-compat symlink `.spec-workflow → .specaffold` (absolute target, classify-before-mutate)
  - **what**: at repo root, create a symlink `.spec-workflow` pointing at an absolute path `$PWD/.specaffold` (absolute per `common/absolute-symlink-targets.md`). Classify-before-mutate: if target is already a symlink pointing at `.specaffold`, no-op; if target is absent, create; any other state (real dir, real file, foreign symlink, broken symlink), warn and fail loud (no `--force`). This one-shot authoring is redundant with T25/T26 but correct for the one-time merge event; T25/T26 handles the idempotent install-time case going forward.
  - **why-AC**: R17, AC15; closes risk 2 (transient path-resolution gap).
  - **files**: `.spec-workflow` (new symlink at repo root).
  - **dep**: T6 (target must exist before symlink points at it).
  - **wave**: W1.
  - **acceptance**: `[ -L .spec-workflow ] && readlink .spec-workflow | grep -q '^/.*/.specaffold$'` returns 0; `test -f .spec-workflow/archive/20260419-flow-monitor/03-prd.md` resolves via the symlink and returns 0.

### W2 — Body rewrites inside renamed files

- [x] T9. Body rewrite in `.claude/commands/scaff/**/*.md`
  - **what**: inside each of the 20 command files, rewrite prose and codefence references: `specflow` → `scaff` (slash-command namespace references in prose, dispatch examples); `spec-workflow` → `specaffold` where the dir is mentioned; `.spec-workflow/` → `.specaffold/` in path references. Preserve YAML frontmatter `description:` where it references the product name as "Specaffold" (product-name prose) vs. `scaff` (CLI/command prose).
  - **why-AC**: R2, AC9 (specifically `.claude/commands/scaff/request.md` must reference the PM agent name `scaff-pm`).
  - **files**: all 20 `.md` files under `.claude/commands/scaff/`.
  - **dep**: T1.
  - **wave**: W2.
  - **acceptance**: `grep -rE "specflow|spec-workflow" .claude/commands/scaff/ | wc -l` returns 0; `grep -q '\bscaff-pm\b' .claude/commands/scaff/request.md` returns 0.

- [x] T10. Body rewrite in `.claude/agents/scaff/**/*.md` — frontmatter `name:` + `description:` + body prose
  - **what**: for each agent file, rewrite the frontmatter `name:` field from `specflow-<role>` to `scaff-<role>` (e.g. `scaff-pm`, `scaff-architect`); rewrite `description:` to say "Specaffold" where the product is named; rewrite body prose `specflow` → `scaff` where command/agent references appear. The 14 files are: pm, architect, tpm, designer, developer, qa-analyst, qa-tester, reviewer-security, reviewer-performance, reviewer-style, + architect.appendix, developer.appendix, qa-analyst.appendix, tpm.appendix. Constraint from `.claude/rules/README.md`: filename stem matches `name:` in frontmatter — so `pm.md` has `name: scaff-pm`, `architect.md` has `name: scaff-architect`, etc.
  - **why-AC**: R3, R10, AC5, AC10 (specifically `.claude/agents/scaff/pm.md` frontmatter must read `name: scaff-pm`).
  - **files**: all 14 `.md` files under `.claude/agents/scaff/`.
  - **dep**: T2.
  - **wave**: W2.
  - **acceptance**: `grep -rE '^name: specflow-' .claude/agents/scaff/ | wc -l` returns 0; `grep -rE '^name: scaff-' .claude/agents/scaff/ | wc -l` returns ≥ 10 (seven roles + three reviewers minimum); `grep -E '^name: scaff-pm$' .claude/agents/scaff/pm.md` returns exactly one match.

- [x] T11. Body rewrite in `bin/scaff-*` — internal references + path-authoring logic
  - **what**: inside each of the 5 renamed binaries, rewrite string literals, comments, and variables that reference `specflow`, `spec-workflow`, or `.spec-workflow/`. Hit counts per tech §1.1: `scaff-seed` (63), `scaff-lint` (25), `scaff-aggregate-verdicts` (11), `scaff-install-hook` (5), `scaff-tier` (3); plus `bin/claude-symlink` (15) — NOT renamed, but its body must be rewritten too.
  - **why-AC**: R7, R6 (grep zero-hits).
  - **files**: 6 binaries total — `bin/scaff-seed`, `bin/scaff-lint`, `bin/scaff-aggregate-verdicts`, `bin/scaff-install-hook`, `bin/scaff-tier`, `bin/claude-symlink`.
  - **dep**: T3.
  - **wave**: W2.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" bin/ | awk -F: '$2>0 {print}' | wc -l` returns 0.

- [x] T12. Body rewrite in `.claude/skills/scaff-init/**`
  - **what**: rewrite `SKILL.md` and `init.sh` contents — replace `specflow-init` skill-name references with `scaff-init`; replace `.spec-workflow/` path references with `.specaffold/`; any slash-command example `/specflow-init` → `/scaff-init` (the skill slash-command gets the new name via filename, so this is just a prose alignment).
  - **why-AC**: R4, R6.
  - **files**: `.claude/skills/scaff-init/SKILL.md`, `.claude/skills/scaff-init/init.sh`.
  - **dep**: T4.
  - **wave**: W2.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" .claude/skills/scaff-init/` returns 0 per file.

- [x] T13. Body rewrite in `README.md` + any root-level `*.md` docs
  - **what**: top-line heading `# spec-workflow` → `# Specaffold`; tagline and prose references to old product name → Specaffold; install-example blocks update `bin/specflow-seed` → `bin/scaff-seed`, `cp -R .claude/skills/specflow-init` → `cp -R .claude/skills/scaff-init`, `/specflow-init` → `/scaff-init`, and add at least one `scaff` reference in an install example (AC3).
  - **why-AC**: R1, R4, AC2, AC3.
  - **files**: `README.md` (plus any root-level `*.md` discovered; none currently exist besides README).
  - **dep**: none (T13 edits `README.md`; T1–T7 all edit disjoint paths).
  - **wave**: W2.
  - **acceptance**: `head -1 README.md` reads exactly `# Specaffold`; `grep -c '\bscaff\b' README.md` returns ≥ 1; `grep -Ec "specflow|spec-workflow" README.md` returns 0 (or only hits inside the R6 allow-list, which README is not part of).

- [x] T14. Residual pass over `.claude/settings.local.json` for non-manifest strings
  - **what**: after T7 handled the two manifest-path keys, grep `.claude/settings.local.json` for any remaining `specflow` / `spec-workflow` strings (e.g. command strings like `/specflow:next` in permission entries, if any exist). Rewrite each to the new prefix.
  - **why-AC**: R6.
  - **files**: `.claude/settings.local.json`.
  - **dep**: T7.
  - **wave**: W2.
  - **acceptance**: `grep -Ec "specflow|spec-workflow" .claude/settings.local.json` returns 0.

- [x] T15. Body rewrite in `.claude/scaff.manifest`
  - **what**: the manifest's `files:` keys are path strings like `.claude/agents/specflow/pm.md`. Rewrite each to `.claude/agents/scaff/pm.md` to match the W1 dir renames. Preserve the sha hashes verbatim — they are content hashes of file bodies, not paths; re-hashing is out of scope (hashes get refreshed on the next `scaff-seed init` cycle organically).
  - **why-AC**: R6, R7.
  - **files**: `.claude/scaff.manifest`.
  - **dep**: T5.
  - **wave**: W2.
  - **acceptance**: `grep -Ec "specflow|spec-workflow" .claude/scaff.manifest` returns 0.

- [x] T16. W2 cross-class consistency check (read-only)
  - **what**: structural read-only check that the AC9 ↔ AC10 anchor pair is consistent — `.claude/commands/scaff/request.md` references the string `scaff-pm`, and `.claude/agents/scaff/pm.md` frontmatter has `name: scaff-pm`. Both strings must match verbatim. No file edits; this is a gate task.
  - **why-AC**: AC9, AC10.
  - **files**: read-only: `.claude/commands/scaff/request.md`, `.claude/agents/scaff/pm.md`.
  - **dep**: T9, T10.
  - **wave**: W2.
  - **acceptance**: `grep -q '\bscaff-pm\b' .claude/commands/scaff/request.md && grep -qE '^name: scaff-pm$' .claude/agents/scaff/pm.md` returns 0.

### W3 — Peripheral body rewrites + new artefacts

- [x] T17. Body rewrite in `.claude/hooks/session-start.sh`
  - **what**: 6 `specflow|spec-workflow` hits per tech §1.1. Use `sed -i '' -e 's/specflow/scaff/g' -e 's#\.spec-workflow/#\.specaffold/#g' .claude/hooks/session-start.sh` (BSD two-arg form per `bash-32-portability`). Preserve logic; no new fork/exec.
  - **why-AC**: R8, AC7.
  - **files**: `.claude/hooks/session-start.sh`.
  - **dep**: none (hooks edit files renamed in W1 but hook filenames themselves do not change; W2 did not touch hooks).
  - **wave**: W3.
  - **acceptance**: `grep -Ec "specflow|spec-workflow" .claude/hooks/session-start.sh` returns 0; `time bash .claude/hooks/session-start.sh < /dev/null` reports wall-clock < 200ms (measured by QA-analyst in validate).

- [x] T18. Body rewrite in `.claude/hooks/stop.sh`
  - **what**: 7 hits per tech §1.1 (including the language-config-candidate list `$XDG_CONFIG_HOME/specflow/`, `$HOME/.config/specflow/` which rewrites to `scaff/`). Use `sed -i ''` with BSD two-arg form.
  - **why-AC**: R8, AC7.
  - **files**: `.claude/hooks/stop.sh`.
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `grep -Ec "specflow|spec-workflow" .claude/hooks/stop.sh` returns 0; `time bash .claude/hooks/stop.sh < /dev/null` reports wall-clock < 200ms.

- [x] T19. Rule prose rewrite — `.claude/rules/common/*.md` + `.claude/rules/README.md` + `.claude/rules/index.md`
  - **what**: per tech §1.1, 5 rule files have hits; rewrite prose in `absolute-symlink-targets.md` (5 hits), `language-preferences.md` (5), `no-force-on-user-paths.md` (1), `classify-before-mutate.md` (0 but check), plus `README.md` (0) and `index.md` (0). Preserve rule examples that cite archived-feature slugs (those remain as historical references in prose).
  - **why-AC**: R9, R6.
  - **files**: all common/ rule files + README.md + index.md.
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" .claude/rules/common/ .claude/rules/README.md .claude/rules/index.md | awk -F: '$2>0 {print}'` returns empty (zero unlisted hits).

- [x] T20. Rule prose rewrite — `.claude/rules/bash/*.md` + `.claude/rules/reviewer/*.md`
  - **what**: `reviewer/performance.md` (1 hit — cross-ref to `shareable-hooks` feature which is archived; check whether the reference is in allow-list-compatible prose), `reviewer/security.md` (1 hit — likely a path example), `bash/bash-32-portability.md` (0 hits currently but verify post-merge), `bash/sandbox-home-in-tests.md` (0 hits). Focus on reviewer prose references.
  - **why-AC**: R9, R6.
  - **files**: `.claude/rules/bash/*.md`, `.claude/rules/reviewer/*.md`.
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" .claude/rules/bash/ .claude/rules/reviewer/ | awk -F: '$2>0 {print}'` returns empty.

- [x] T21a. Team-memory prose rewrite — `.claude/team-memory/shared/`
  - **what**: per tech §1.1, 83 hits across 31 memory files repo-wide. The `shared/` subtree contains ~5–10 memories (index, dogfood-paradox, status-notes rule, etc.). Rewrite body prose `specflow` → `scaff` / `Specaffold` context-appropriately. Filename slugs are R10-frozen (no rename). Dogfood-paradox memory contains multi-occurrence historical references to archived features — preserve archived-slug citations verbatim (those are historical record).
  - **why-AC**: R10, R6.
  - **files**: `.claude/team-memory/shared/**/*.md`.
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" .claude/team-memory/shared/ | awk -F: '$2>0 {print}'` returns empty.

- [x] T21b. Team-memory prose rewrite — per-role dirs under `.claude/team-memory/`
  - **what**: subtrees `tpm/`, `pm/`, `architect/`, `developer/`, `qa-analyst/`, `qa-tester/`, `designer/`. Same discipline as T21a.
  - **why-AC**: R10, R6.
  - **files**: `.claude/team-memory/{tpm,pm,architect,developer,qa-analyst,qa-tester,designer}/**/*.md`.
  - **dep**: none (disjoint from T21a's subtree).
  - **wave**: W3.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" .claude/team-memory/tpm/ .claude/team-memory/pm/ .claude/team-memory/architect/ .claude/team-memory/developer/ .claude/team-memory/qa-analyst/ .claude/team-memory/qa-tester/ .claude/team-memory/designer/ | awk -F: '$2>0 {print}'` returns empty.

- [x] T21c. Body rewrite in `test/**/*.sh` — mechanical carryover sweep [CHANGED 2026-04-21]
  - **what**: mechanical body rewrite across all 88 `test/*.sh` files that currently contain `specflow` / `spec-workflow` references (path refs, comments, error strings, awk-sniff patterns). Replacements (apply in this exact order per BSD two-arg `sed -i ''` form to avoid order-sensitive overlap): `.claude/agents/specflow/` → `.claude/agents/scaff/`; `.claude/commands/specflow/` → `.claude/commands/scaff/`; `bin/specflow-` → `bin/scaff-`; `.claude/specflow.manifest` → `.claude/scaff.manifest`; `/specflow:` → `/scaff:`; `/specflow-` → `/scaff-`; `.spec-workflow/` → `.specaffold/`; `spec-workflow` → `specaffold`; `specflow` → `scaff`. Per `.claude/rules/bash/bash-32-portability.md` use the BSD two-arg form `sed -i '' -e '...'` (never GNU `sed -i ...`). Preserve test assertion semantics — do not change test logic, do not rename any `tNN_*.sh` file, do not alter control flow. Run `bash -n <file>` against every modified file as a syntax check before declaring the task complete. Edge cases: (a) `test/t39_init_fresh_sandbox.sh` and `test/t42_update_no_conflict.sh` already had narrow edits in T15 retry for the `scaff_ref` awk-sniff key and the `scaff.manifest` path — T21c must re-apply the mechanical sweep against their *remaining* non-T15 carryover refs (T15 retry fixed two specific lines only); (b) `test/smoke.sh` is in the sweep, and T24 subsequently appends a single registration line against the post-T21c body (T24 now depends on T21c — see §2 W3 row and T24 block); (c) no test file is excluded from the sweep — the 88-file count is the full set per `grep -lE "specflow|spec-workflow" test/*.sh | wc -l` at the time of authoring.
  - **why-AC**: R6, AC1 (gates T28; without T21c, T28's grep-allow-list assertion fails because `test/` is not in the R6 allow-list per tech §D2 — tests are the active verification surface for the rename and must carry the new names).
  - **files**: all 88 `*.sh` files under `test/` that match `grep -lE "specflow|spec-workflow" test/*.sh` at time of task start (includes `test/smoke.sh`; excludes `test/t_grep_allowlist.sh` which T23 authors fresh in the new taxonomy).
  - **dep**: T3 (binaries renamed to `bin/scaff-*`), T5 (manifest renamed to `.claude/scaff.manifest`), T11 (bin bodies rewritten), T15 (manifest body + two consumer test files' narrow T15 retry landed). Dep chain binds to core renames so path refs rewrite against the post-rename state rather than stale pre-rename paths.
  - **wave**: W3.
  - **acceptance**: `grep -rEc "specflow|spec-workflow" test/ | awk -F: '$2>0 {print}' | wc -l` returns 0 (no test file carries any old-prefix reference); every edited file passes `bash -n` syntax check.

- [x] T22. Author `.claude/carryover-allowlist.txt`
  - **what**: create the allow-list file per tech §D2 with the initial 6 patterns listed there:
    ```
    .git/**
    .specaffold/archive/**
    .spec-workflow
    .claude/carryover-allowlist.txt
    docs/rename-migration.md
    .specaffold/features/20260421-rename-to-specaffold/RETROSPECTIVE.md
    ```
    plus a leading comment block (per tech §D2 tradeoff: reasons live in comments at top).
  - **why-AC**: R6, AC1.
  - **files**: `.claude/carryover-allowlist.txt` (new file).
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `test -f .claude/carryover-allowlist.txt && [ "$(grep -cvE '^(#|$)' .claude/carryover-allowlist.txt)" -ge 6 ]` returns 0.

- [x] T23. Author `test/t_grep_allowlist.sh` (bash 3.2 portable, standalone)
  - **what**: implement the assertion script per tech §4.1 verbatim. Bash 3.2 portable: `while IFS= read -r`, no `mapfile`; `case`-glob pattern matching, no `[[ =~ ]]`. Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (though this script doesn't read or write `$HOME`, per reviewer/style rule 6 the discipline is uniform). Script must be invokable directly via `bash test/t_grep_allowlist.sh` (escape-hatch for architect flag #1).
  - **why-AC**: R6, AC1; closes architect flag #1.
  - **files**: `test/t_grep_allowlist.sh` (new file, exec bit).
  - **dep**: T22 (the script reads `.claude/carryover-allowlist.txt`).
  - **wave**: W3.
  - **acceptance**: `bash test/t_grep_allowlist.sh` exits 0 when run against the current tree state (all waves W1+W2+W3 merged); script passes bash 3.2 portability grep (`grep -En 'readlink -f|realpath|jq|mapfile|\[\[.*=~' test/t_grep_allowlist.sh` returns 0).

- [x] T24. Wire `t_grep_allowlist.sh` into `test/smoke.sh`
  - **what**: add a registration line for the new test script in `test/smoke.sh` so it runs as part of the smoke suite. Registration format follows existing `tNN_*.sh` convention in the file. [CHANGED 2026-04-21] Runs after T21c's mechanical body rewrite of `test/smoke.sh` has landed, so T24 only appends the registration line against the already-rewritten file body.
  - **why-AC**: R6, AC1; cross-reference `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` (wiring is a distinct task from authorship).
  - **files**: `test/smoke.sh`.
  - **dep**: T23, T21c. [CHANGED 2026-04-21]
  - **wave**: W3.
  - **acceptance**: `grep -q 't_grep_allowlist.sh' test/smoke.sh` returns 0; `bash test/smoke.sh` runs the new test without error.

- [x] T25. Author `ensure_compat_symlink` function in `bin/scaff-seed`
  - **what**: add a bash function implementing the six-state classifier per tech §D5: classifier input is `<repo_root>/.spec-workflow`; enum output is `missing | ok-ours | foreign-symlink | real-dir | real-file | broken-symlink`; dispatch table handles each state (missing → create with absolute target; ok-ours → no-op; foreign-symlink/real-dir/real-file → warn-skip; broken-symlink → warn-skip). Function is pure classifier + dispatch, no side effects in classifier. Absolute target per `common/absolute-symlink-targets.md`. No `--force` per `common/no-force-on-user-paths.md`.
  - **why-AC**: R17, AC15.
  - **files**: `bin/scaff-seed` (add function; no call-site wiring yet).
  - **dep**: T11 (T11 does the body rewrite in scaff-seed; T25 adds new function. Serial-within-W3).
  - **wave**: W3.
  - **acceptance**: `bash -n bin/scaff-seed` returns 0 (syntax check); `grep -q 'ensure_compat_symlink()' bin/scaff-seed` returns 0.

- [x] T26. Wire `ensure_compat_symlink` into `bin/scaff-seed install` and `bin/scaff-seed update` subcommands
  - **what**: add a call to `ensure_compat_symlink` inside the `cmd_install` and `cmd_update` dispatcher arms of `bin/scaff-seed`. Positioned after the main install/update work completes (so the symlink is authored only when `.specaffold/` exists). Cross-reference `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` — wiring is an explicit task separate from function-authorship.
  - **why-AC**: R17, AC15.
  - **files**: `bin/scaff-seed` (edit install/update dispatcher arms).
  - **dep**: T25.
  - **wave**: W3.
  - **acceptance**: `grep -c 'ensure_compat_symlink' bin/scaff-seed` returns ≥ 3 (one definition + two call sites); an integration smoke test invoking `bin/scaff-seed install --dry-run` reaches the call-site without error (acceptance measured by running the existing `test/t39_init_fresh_sandbox.sh` or equivalent, post-migration).

- [x] T27. Author migration notes document `docs/rename-migration.md`
  - **what**: create the migration notes file per R15. Content: (a) old-prefix → new-prefix mapping table (`/specflow:request` → `/scaff:request`; `bin/specflow-seed` → `bin/scaff-seed`; `.spec-workflow/` → `.specaffold/`; `specflow-pm` → `scaff-pm`; etc.); (b) hard-cutover rationale (D1 no alias window); (c) `claude-symlink install` recovery step for stale global installs (D3); (d) one-line orphan cleanup command `rm -rf ~/.claude/agents/specflow ~/.claude/commands/specflow` (D6); (e) note about repo-dir on-disk rename being out of scope (D2). This file is allowed to mention old names; it's in the R6 allow-list (T22).
  - **why-AC**: R15, AC12.
  - **files**: `docs/rename-migration.md` (new file).
  - **dep**: none.
  - **wave**: W3.
  - **acceptance**: `test -f docs/rename-migration.md && [ "$(wc -l < docs/rename-migration.md)" -ge 20 ]` returns 0 (non-empty with real content); `grep -q '/scaff:' docs/rename-migration.md` returns 0 (new-prefix table present); `grep -q 'claude-symlink install' docs/rename-migration.md` returns 0 (recovery step present).

- [ ] T21d. T28 closeout — rewrite files missed by W1–W3 scope + extend allow-list + flow-monitor subtree handling [CHANGED 2026-04-21]
  - **what**: three-concern closeout combining (A) mechanical body rewrites of 6 files surfaced by the `t_grep_allowlist.sh` dry-run that were not covered by any prior task's scope, (B) two allow-list additions for self-reference carve-outs, and (C) `flow-monitor/` subtree handling as a co-located independent Tauri sub-project. All three concerns share the single goal "make T28 green" so they land in one task.
    - **(A) Body rewrites** — apply the mechanical `sed -i ''` sweep (BSD two-arg form per `.claude/rules/bash/bash-32-portability.md`) in this exact substitution order (same order as T21c to avoid overlap): `.claude/agents/specflow/` → `.claude/agents/scaff/`; `.claude/commands/specflow/` → `.claude/commands/scaff/`; `bin/specflow-` → `bin/scaff-`; `.claude/specflow.manifest` → `.claude/scaff.manifest`; `/specflow:` → `/scaff:`; `/specflow-` → `/scaff-`; `.spec-workflow/` → `.specaffold/`; `spec-workflow` → `specaffold`; `specflow` → `scaff`. Target files (6): `.gitignore` (no prior task touched it — has `.spec-workflow/features/*/STATUS.md.bak` and `.spec-workflow/features/*/.stop-hook-last-epoch`); `.claude/team-memory/README.md` (T21a covered `shared/`, T21b covered per-role subtrees, neither covered the top-level README); `scripts/tier-rollout-migrate.sh` (T11 covered `bin/` only; `scripts/` was out of scope); `bin/scaff-seed` residual sweep (T11 did the initial rewrite, but T25 added `ensure_compat_symlink` which may have reintroduced legacy strings — re-run the sweep against the current post-T25/T26 state); `test/t_T25_ensure_compat_symlink.sh` (T25 authored this test file as scope-creep after T21c's 88-file sweep enumerated its inputs — so it was not in T21c's file list); `.specaffold/features/_template/STATUS.md` (feature template; not in any T21* scope). Run `bash -n` on every modified `.sh` file after rewrite.
    - **(B) Allow-list extension** — edit `.claude/carryover-allowlist.txt` and append two new entries with leading `#` comments explaining each:
      - `test/t_grep_allowlist.sh` — the assertion script's own implementation contains `specflow` / `spec-workflow` as literal search-pattern strings; cannot be rewritten without breaking the script's function. Self-reference carve-out.
      - `.specaffold/features/20260421-rename-to-specaffold/**` — this feature's own PRD, tech, plan, STATUS, request, and RETROSPECTIVE artefacts inherently reference the old names because the feature is the rename itself. Keeping them verbatim preserves the audit trail per AC8-adjacent discipline.
    - **(C) flow-monitor/ subtree** — the `flow-monitor/` subtree is a co-located independent Tauri sub-project that originated from feature `20260419-flow-monitor`; its rename is out of scope for this feature. Three sub-steps:
      1. Append to `.gitignore` (via the same task's `.gitignore` edit in step A): `flow-monitor/src-tauri/target/` (Rust build artefacts — 3500+ of the t_grep_allowlist.sh dry-run hits come from here; these build artefacts should never have been scannable in-tree) and `flow-monitor/dist/` (frontend build artefacts).
      2. Run `git rm --cached -r flow-monitor/src-tauri/target flow-monitor/dist` to untrack any already-committed build artefacts. **Edge case noted at plan time**: a `git ls-files flow-monitor/src-tauri/target` and `git ls-files flow-monitor/dist` check at plan-authoring time returned 0 tracked entries — the artefacts exist on disk but were never committed. In that case the `git rm --cached -r` will emit "did not match any files" and exit non-zero; the developer should treat an already-untracked state as success (no-op) and proceed. Guard with `git rm --cached -r flow-monitor/src-tauri/target flow-monitor/dist 2>/dev/null || true` or equivalent.
      3. Append to `.claude/carryover-allowlist.txt` a third new entry: `flow-monitor/**` — whole subtree allow-listed because rename of that independent sub-project is out of scope for this feature. Leading comment explains the rationale.
  - **why-AC**: R6, AC1. Gates T28; closes the T28 gap surfaced at 2026-04-21 after W3 merge (see STATUS notes line `implement — PLAN GAP surfaced by t_grep_allowlist.sh dry-run`).
  - **files**: edited (rewrite): `.gitignore`, `.claude/team-memory/README.md`, `scripts/tier-rollout-migrate.sh`, `bin/scaff-seed`, `test/t_T25_ensure_compat_symlink.sh`, `.specaffold/features/_template/STATUS.md`; edited (append entries): `.claude/carryover-allowlist.txt`, `.gitignore` (for the two flow-monitor build-artefact patterns); git-index mutation: `git rm --cached -r flow-monitor/src-tauri/target flow-monitor/dist` (no on-disk change; may be a no-op if not tracked).
  - **dep**: T17, T18, T19, T20, T21a, T21b, T21c, T22, T23, T24, T25, T26, T27 (every other W3 task — serial post-wave closeout). All were merged in `e3a8a0b` per STATUS notes, so the dep chain is satisfied.
  - **wave**: W3.
  - **acceptance**: `bash test/t_grep_allowlist.sh` exits 0 against the post-closeout tree state (the definitive T28 prerequisite); `bash -n .gitignore || true` trivially passes (non-script); `bash -n bin/scaff-seed && bash -n scripts/tier-rollout-migrate.sh && bash -n test/t_T25_ensure_compat_symlink.sh` returns 0 for every modified shell script; `grep -c 'flow-monitor/' .claude/carryover-allowlist.txt` returns ≥ 1; `grep -Eq '^flow-monitor/src-tauri/target/?$' .gitignore && grep -Eq '^flow-monitor/dist/?$' .gitignore` returns 0.

### W4 — Cutover + final assertion + RUNTIME HANDOFF

- [ ] T28. Run grep-allow-list assertion across full tree — must PASS
  - **what**: run `bash test/t_grep_allowlist.sh` against the tree state after W1+W2+W3 merges. All hits must be allow-listed; any unlisted hit is a BLOCK on archive advance. This is the primary AC1 gate. Script was authored in T23 and wired in T24.
  - **why-AC**: AC1 (the primary grep assertion).
  - **files**: none edited; runs `test/t_grep_allowlist.sh`.
  - **dep**: T23, T24, and all W1+W2+W3 tasks complete.
  - **wave**: W4.
  - **acceptance**: `bash test/t_grep_allowlist.sh` exits 0 and prints `PASS: all carryover hits allow-listed`.

- [ ] T29. Pre-commit RUNTIME HANDOFF STATUS line (dogfood-paradox discipline)
  - **what**: append to `STATUS.md` Notes section the exact line specified by `shared/dogfood-paradox-third-occurrence.md` ninth-occurrence paragraph and PRD §6 Dogfood paradox. Verbatim wording:
    ```
    RUNTIME HANDOFF (for successor feature): opening STATUS Notes line must read
    "YYYY-MM-DD orchestrator — Specaffold rename exercised on this feature's first live session".
    1 runtime AC deferred (AC11); see 03-prd.md §9 AC-R14.
    ```
    Plus a regular STATUS notes line logging the handoff-note addition: `YYYY-MM-DD TPM — pre-committed RUNTIME HANDOFF STATUS line per dogfood-paradox ninth-occurrence discipline`.
  - **why-AC**: R14 (runtime handoff), ninth-occurrence sub-pattern: "pre-commit the RUNTIME HANDOFF line as a TPM-owned task in the final wave".
  - **files**: `.specaffold/features/20260421-rename-to-specaffold/STATUS.md`.
  - **dep**: none within W4 (parallel-safe with T28, T30, T31 — different files).
  - **wave**: W4.
  - **acceptance**: `grep -q 'RUNTIME HANDOFF (for successor feature):' .specaffold/features/20260421-rename-to-specaffold/STATUS.md` returns 0; `grep -q 'Specaffold rename exercised on this feature.s first live session' .specaffold/features/20260421-rename-to-specaffold/STATUS.md` returns 0.

- [ ] T30. AC9/AC10 final self-consistency check (structural self-dogfood)
  - **what**: re-run the T16 check against the post-W3 tree — confirm `.claude/commands/scaff/request.md` references `scaff-pm` and `.claude/agents/scaff/pm.md` frontmatter reads `name: scaff-pm`. This is the structural half of self-dogfood; the runtime half (AC11) defers to the successor feature.
  - **why-AC**: AC9, AC10.
  - **files**: read-only: `.claude/commands/scaff/request.md`, `.claude/agents/scaff/pm.md`.
  - **dep**: T9, T10 (but these are W2; W4 re-verification is a gate).
  - **wave**: W4.
  - **acceptance**: `grep -q '\bscaff-pm\b' .claude/commands/scaff/request.md && grep -qE '^name: scaff-pm$' .claude/agents/scaff/pm.md` returns 0.

- [ ] T31. AC15 backwards-compat symlink verification
  - **what**: verify the compat symlink `.spec-workflow` exists at repo root, is a symlink (not a regular dir), and its target is an absolute path ending in `/.specaffold`. Also verify representative archived path resolves: `.spec-workflow/archive/20260419-flow-monitor/03-prd.md` must resolve to the same file as `.specaffold/archive/20260419-flow-monitor/03-prd.md` (same-inode check or diff-content check).
  - **why-AC**: R17, AC15.
  - **files**: read-only: `.spec-workflow` (symlink), `.specaffold/archive/20260419-flow-monitor/03-prd.md`.
  - **dep**: T8.
  - **wave**: W4.
  - **acceptance**: `[ -L .spec-workflow ]` returns 0; `readlink .spec-workflow | grep -Eq '^/.+/\.specaffold$'` returns 0; `diff -q .spec-workflow/archive/20260419-flow-monitor/03-prd.md .specaffold/archive/20260419-flow-monitor/03-prd.md` returns 0 (identical content via symlink resolution).

---

## 9. STATUS notes convention

Every task completion appends one line in STATUS.md:

```
- YYYY-MM-DD <Role> — T<n> done: <brief summary>
```

Blocked tasks:

```
- YYYY-MM-DD <Role> — T<n> blocked: <observed behavior or missing info>
```

The orchestrator checks off `[x]` in task entries via per-wave bookkeeping commits after wave merge — NEVER inside a Developer's per-task worktree commit (prevents parallel-merge checkbox loss per `tpm/checkbox-lost-in-parallel-merge.md`) and NEVER at plan-authoring time (per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`).

---

## Team memory

- `shared/dogfood-paradox-third-occurrence.md` — applied: W4 T29 pre-commits the RUNTIME HANDOFF STATUS line per the ninth-occurrence "sub-pattern promoted to discipline" paragraph; AC11 explicitly marked runtime-deferred in PRD and plan.
- `tpm/parallel-safe-requires-different-files.md` — applied: every task's `Parallel-safe-with` evaluation checks file-level disjointness, not just logical independence; W3 T25/T26 are serialised (both edit `bin/scaff-seed`) rather than marked parallel-safe.
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` — applied: every `- [ ]` box above stays unchecked at authoring time; §9 codifies orchestrator-only `[x]` writes.
- `tpm/briefing-contradicts-schema.md` — applied: T10 briefing quotes the frontmatter-name constraint verbatim from `.claude/rules/README.md` ("Filename stem matches `name:` in frontmatter") rather than paraphrasing.
- `tpm/tasks-doc-format-migration.md` — not applicable: this is a fresh plan, not a mid-stream format migration.
