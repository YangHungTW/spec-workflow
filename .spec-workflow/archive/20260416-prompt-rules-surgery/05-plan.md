# Plan — prompt-rules-surgery (B1)

_2026-04-16 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` — directly load-bearing for the wave-schedule hints in §5. Prompt-slimming edits and memory-invocation edits target the SAME 7 agent files; the lesson says "logical independence is necessary but not sufficient — same-file is a hazard." Recommendation fuses the two passes per role.
- `tpm/tasks-doc-format-migration.md` — not applicable (no downstream task-doc format migration this round).
- `shared/` (both tiers) — empty; nothing to pull.

## 1. Scope summary

This plan delivers the three B1 self-upgrades against the PRD (R-count=16, AC-count=18) and tech doc (D-count=12, including D12 added 2026-04-16 for safe `settings.json` read-merge-write):
- **(1) Progressive disclosure** — each of 7 agent core files slims ≥30% (R9b), with content off-loaded to per-role appendices or the rules layer.
- **(2) Rules layer + SessionStart hook** — `.claude/rules/{common,bash,markdown,git}/` tree, pure-bash hook at `.claude/hooks/session-start.sh`, wired via a new repo-root `settings.json` using the D12 read-merge-write install path.
- **(3) Mandatory memory invocation** — every agent core file gains a machine-visible `## Team memory` block (R10/R11), with grep-verifiable shape.

Items (4)(5)(6) are out of plan (deferred to B2).

## 2. Milestones

### M1 — Rules layer scaffolding
- **Output**: `.claude/rules/{README.md, common/, bash/, markdown/, git/}` directory tree; one exemplar rule file under `common/` (pick `classify-before-mutate`) validates the D3 frontmatter shape end-to-end.
- **Requirements covered**: R1, R2, R6.
- **Decisions honored**: D3 (5-key YAML frontmatter + 4 body sections), D4 (rules-vs-memory contrast table goes into `.claude/rules/README.md`).
- **Verification signal**: `test -d` on each subdir passes; the exemplar rule parses through the classifier that lands in M3.

### M2 — Migrate the 5 mandated rules
- **Output**: the remaining 4 rule files land under their correct scope subdirs, each extracted from the source cited in PRD R3's migration table.
  - `bash-32-portability.md` (bash/must)
  - `sandbox-home-in-tests.md` (bash/must)
  - `no-force-on-user-paths.md` (common/must)
  - `absolute-symlink-targets.md` (common/should)
  - (+ the M1 exemplar `classify-before-mutate.md` — common/must)
- **Requirements covered**: R3, R14 (nothing duplicates back into prompts yet — the delete happens in M6/M7).
- **Decisions honored**: D3 (schema), D11 (refactor not rewrite — team-memory source entries remain; rule files are new homes).
- **Verification signal**: `find .claude/rules -name '*.md' | wc -l` ≥ 5; each of the 5 R3 slug filenames present; D3 schema check passes per file.

### M3 — SessionStart hook script
- **Output**: `.claude/hooks/session-start.sh` — pure bash 3.2, exec bit set. Implements the classifier (D5), language heuristic (D8), JSON emission with dual-key output (D7), and the fail-safe envelope (§4 error handling: `set +e`, `trap … ERR INT TERM`, unconditional `exit 0`).
- **Requirements covered**: R4, R5 (all 4 items), R6.
- **Decisions honored**: D1, D5, D7, D8; error-handling strategy in §4.
- **Verification signal**: running the script with `< /dev/null` from a clean checkout emits valid JSON on stdout and `exit 0`; t17 / t18 / t19 / t20 pass (tests land in M9).

### M4 — Safe settings.json mutation helper (D12)
- **Output**: a Python 3 `add_hook` / `remove_hook` snippet — exact shape from tech doc D12 — either inlined into the install task's script or pulled into a small helper (TPM-neutral; implementation choice falls to Developer). The helper is idempotent, atomic (`.tmp` + `os.replace`), single-slot backup (`settings.json.bak`), fails loud if `python3` absent.
- **Requirements covered**: R4 (wiring mechanism).
- **Decisions honored**: D12 (normative rule: never overwrite; always read-merge-write).
- **Verification signal**: t27 (preserves keys) and t28 (idempotent) pass. These tests land in M9; the helper is gated by them.

### M5 — Wire SessionStart entry into repo-root settings.json
- **Output**: repo-root `settings.json` created (did not exist pre-feature) with the `hooks.SessionStart[].hooks[].command = ".claude/hooks/session-start.sh"` entry, using the M4 helper (NOT a heredoc, NOT `cat >`). Verifies the D12 round-trip on a real file.
- **Requirements covered**: R4.
- **Decisions honored**: D2 (one-script-per-event wiring), D12 (install path).
- **Verification signal**: t13 (settings.json references the hook path) passes; `settings.json.bak` exists post-install; running the install a second time is a no-op (M4 idempotence check).

### M6 + M7 — Agent core surgery (fused per role, 7 roles)
- **Output**: for each of the 7 roles (`pm`, `designer`, `architect`, `tpm`, `developer`, `qa-analyst`, `qa-tester`), a single pass rewrites `.claude/agents/specflow/<role>.md` to the D10 fixed six-block template:
  1. YAML frontmatter (preserved).
  2. Identity line.
  3. `## Team memory` block (R10 wording, with the `ls ~/.claude/team-memory/<role>/` + `none apply because <reason>` phrases).
  4. `## When invoked for /specflow:<cmd>` sections.
  5. `## Output contract`.
  6. `## Rules` (role-specific only — cross-role rules removed).
  Long-form content lifted to `.claude/agents/specflow/<role>.appendix.md` where needed, referenced with D9 literal pointer phrase.
- **Requirements covered**: R7, R8, R9, R9b, R10, R11, R12, R14.
- **Decisions honored**: D10 (template), D11 (diff-traceability: every removed non-empty line traces to rule/appendix/memory), D9 (appendix pointer phrase).
- **Verification signal**: t21 (line-count ceilings per role), t22 (header order grep), t23 (memory block present), t24 (appendix pointers resolve), t25 (no cross-role duplication). Diff-traceability audit at gap-check stage.

**Fusion rationale (from team memory):** PRD §4 splits item (1) slimming from item (3) memory-invocation across R7–R9b vs R10–R13. Those two concerns edit the same 7 files. Per `tpm/parallel-safe-requires-different-files.md`, pairing them as separate parallel waves would collide. Fuse to one "agent surgery" task per role — the 7 per-role tasks are then parallel-safe WITH EACH OTHER (different files).

### M8 — Dedup audit
- **Output**: audit pass — grep the 5 rule slug keywords against `.claude/agents/specflow/*.md`; any remaining hits are fixed in-place (remove from prompt, keep in rule). Gap-check stage verifies.
- **Requirements covered**: R14, enforced by AC-no-duplication.
- **Decisions honored**: D4 (single source of truth for each rule), D11 (traceability).
- **Verification signal**: t25 passes with zero hits across all 7 agent files.

### M9 — Test harness (up to 16 new tests from tech-doc §4)
- **Output**: 16 new `test/t13_*.sh` … `test/t28_*.sh` files per the tech-doc testing table:
  - t13 settings.json presence/reference; t14 rules dir structure; t15 rules schema; t16 hook exec bit; t17 hook happy path; t18 hook failsafe; t19 hook bad frontmatter; t20 hook lang-lazy; t21 agent line count; t22 header grep; t23 memory required; t24 appendix pointers; t25 no duplication; t26 no new command; t27 settings.json preserves keys; t28 settings.json idempotent.
- **Requirements covered**: R1–R16 (every AC has a test).
- **Decisions honored**: D6 (tests live under `test/`), sandbox-HOME discipline per cross-cutting §3.
- **Verification signal**: each `test/tNN_*.sh` exits 0 when run standalone; all pass when driven via `smoke.sh`.

### M10 — Smoke test integration
- **Output**: `test/smoke.sh` grows to register t13–t28; old 12 tests (from symlink-operation feature) still pass unchanged. Final `bash test/smoke.sh` exits 0 with 28/28 (or count == 12 + however many land).
- **Requirements covered**: R16, AC-no-regression.
- **Decisions honored**: D6 (smoke.sh as the CI gate).
- **Verification signal**: `bash test/smoke.sh` → `PASS 28/28` (or whatever the final count is).

### M11 — Docs update
- **Output**: `.claude/rules/README.md` includes the D4 contrast table; `.claude/team-memory/README.md` gains a short "Rules vs team-memory: see `.claude/rules/README.md`" pointer; top-level `README.md` gets a one-paragraph note that a SessionStart hook now injects rules.
- **Requirements covered**: R1, R2, R14 (discoverability of the new layer).
- **Decisions honored**: D4 (table lives in a canonical README).
- **Verification signal**: manual read of each README; grep for "rules vs team-memory" in both READMEs resolves.

**Milestone count: 11** (M6+M7 counted once since they are fused per-role).

## 3. Cross-cutting concerns

- **Sandbox HOME discipline** — every test in M9 that touches `~/.claude/` or creates memory dirs MUST root its filesystem ops in a `mktemp -d` sandbox and `HOME`-override for the test duration (per qa-tester memory `sandbox-home-preflight-pattern.md`, to be applied by Developer at test-write time). Any test that forgets this is a flake candidate.
- **Prompt-diff review (M6+M7)** — the highest-risk refactor. D11 mandates diff-traceability: every non-empty line removed from a core file traces to (i) a rule file, (ii) an appendix section, or (iii) an explicit "already covered by memory entry X" justification. Gap-check explicitly audits this diff; QA-analyst owns the audit rubric.
- **settings.json safety** — M4 + M5 must honor D12 without exception. If Developer is tempted to heredoc the file into place because "we're creating it fresh", stop — t27 seeds `permissions` + `env` keys against a clean-sandbox `settings.json` before the install step and asserts preservation. The "we're creating it fresh" case is NOT the only case the installer must handle; it is one branch of the same read-merge-write code path.
- **Dogfood ordering** — M1 (rules scaffolding) + M2 (migrate 5 rules) MUST land before M6+M7 (agent surgery). Otherwise M6+M7 removes content from prompts that has no landing home, violating D11 traceability and potentially losing directives. The dep graph in §4 makes this hard-wired.
- **Hook fail-safe discipline** — the M3 hook script is read-only. No filesystem mutation, no network, no sudo. `set +e` + `trap … ERR INT TERM` + unconditional `exit 0`. Tech-doc §4 is normative here.
- **Memory block shape is grep-anchored** — R11 requires a `## Team memory` heading; AC-memory-required greps for both `ls ~/.claude/team-memory/<role>/` and the `none apply because` phrase. M6+M7 tasks MUST include both tokens verbatim per D10 template — not paraphrased.

## 4. Dependencies & sequencing

```
M1 (rules scaffolding)
  → M2 (migrate 5 rules)
       → M6+M7 (agent surgery, 7 roles)
            → M8 (dedup audit)

M1 (rules scaffolding)
  → M3 (hook script)
       → M5 (wire settings.json)  [also depends on M4]
M4 (settings.json helper, D12)
  → M5 (wire settings.json)

M9 (tests) builds in parallel with M3–M7 — tests can be red-first
  → M10 (smoke.sh integration, runs after all green)

M11 (docs) — last, after M10 green
```

**Key edges:**
- **M2 before M6+M7** — rules must exist as extraction targets before any prompt line is removed.
- **M4 before M5** — the helper is the ONLY legal way to write `settings.json`.
- **M3 parallel-safe with M4** — different files, different languages (bash hook vs Python installer snippet). They can proceed simultaneously.
- **M8 after M6+M7** — dedup check only makes sense after the slim+memory pass has landed on all 7 files.
- **M10 after all impl** — smoke.sh registers tests only once they exist and pass individually.

## 5. Wave schedule hints for TPM task-breakdown stage

This is advisory input for `/specflow:tasks`; actual wave schedule is set then. Profiles per milestone:

- **M1** — single task (scaffold dirs + exemplar rule). Standalone.
- **M2** — 4 tasks, each editing a DIFFERENT new file (one per remaining R3 rule slug). **Parallel-safe with each other.** Strong wave candidate; may be combined with M1 if M1 is a prereq sibling (M1 must complete first OR M1's exemplar-rule addition is its own parallel-safe sibling).
- **M3** — one task (hook script). Parallel-safe with M4 (different files).
- **M4** — one task (installer helper / script). Parallel-safe with M3.
- **M5** — one task. Depends on M4 completing. Serial after M4.
- **M6+M7 FUSED** — **7 tasks**, one per role, each editing `.claude/agents/specflow/<role>.md` (+ optional `<role>.appendix.md`). Tasks are parallel-safe WITH EACH OTHER (different files per role). Each task does BOTH the slimming AND the memory-block insertion in one pass — do NOT split slim vs memory-block across tasks for the same role (per `tpm/parallel-safe-requires-different-files.md`).
- **M8** — one task (audit + fix). Serial after M6+M7 complete.
- **M9** — 16 tasks, one per `test/tNN_*.sh`. Each is its own file → **fully parallel-safe across all 16**. Great wide wave. Some tests (t17–t20) depend on M3 hook existing; t21–t25 depend on M6+M7 agent files; t27–t28 depend on M4 helper. Plan wave starts for M9 tasks against their prereq milestones.
- **M10** — one task. Edits `test/smoke.sh`. Serial after M9 (needs every `tNN_*.sh` present).
- **M11** — 2–3 tasks (one per README). Edits different README files; parallel-safe across the set. Serial after M10 (wait for green before finalizing docs).

**Recommended shape at `/specflow:tasks` time:**
- Wave 1: M1.
- Wave 2: M2 (4 parallel) + M3 (1) + M4 (1). 6 parallel.
- Wave 3: M5 + half of M9 that only depends on M3/M4 (hook tests, settings tests).
- Wave 4: M6+M7 (7 parallel, one per role).
- Wave 5: M8 (serial) + remaining M9 tests that depend on agent files (parallel).
- Wave 6: M10 (serial).
- Wave 7: M11 (parallel docs).

Exact wave breakdown is TPM's call at the tasks stage; above is the shape.

## 6. Risks / watch-items

- **Load-bearing directive lost during M6+M7** — top risk (brainstorm §4 flagged, D11 mitigates). Mitigation: gap-check runs the diff-traceability audit; every removed line must trace home.
- **SessionStart hook spec drift** — tech-doc D2/D7 noted the Claude Code hook config format may have evolved. Mitigation: dual-key JSON output (D7), plus t17 (happy path) is the canary — run it against a real Claude Code session early, NOT just against the CLI harness.
- **`python3` missing on target machine** — D12 says fail loud. Watch item: confirm the t27 / t28 test scripts probe for `python3` at the top and `skip` (not fail) if absent — this prevents harmless CI env gaps from masking as regressions while still letting the install step fail loud when it matters.
- **28 tests is a lot for 1-hour task budgets** — some tests (t15 rules-schema, t27 settings-json, t18 hook-failsafe) are genuinely integration-weight. Watch item: TPM should size those tasks at the upper bound (~1h) and preserve wave width by keeping the cheap unit tests (t13, t14, t16, t21–t26) small.
- **M5 idempotence trap** — if a developer re-runs the install-step while t27 fixtures are still seeded, they may conflate "install is idempotent" with "install works on a fresh file". Mitigation: t27 and t28 use sandbox `HOME` + `mktemp -d` so test state doesn't leak.
- **Agent files reordered during fusion could break Claude Code discovery** — preserving the frontmatter block shape (`name`, `model`, `description`, `tools`) is non-negotiable per R7. Watch item: t22 asserts frontmatter is first block; any task that reformats frontmatter fails fast.

## 7. Out of plan

- Items (4) per-task reviewer, (5) Stop hook, (6) `/specflow:review` — deferred to B2 (separate PRD, opens after this feature archives). TPM will not touch.
- Automated "performative none apply" linter (PRD R13 defers).
- Rule versioning / re-run-on-edit (PRD non-goal).
- Plugin-marketplace format migration, cross-harness adapters.

---

## Summary

- **Milestone count**: 11 (M1–M11; M6+M7 fused per role).
- **Key sequencing calls**:
  - M2 before M6+M7 (rules must exist as extraction targets).
  - M4 before M5 (installer helper is the only legal path to `settings.json`).
  - Fuse slim + memory-block edits per role (do NOT pair them across parallel tasks on the same agent file).
- **Open risks to flag now** (not archive-time):
  - Hook spec uncertainty — run t17 against real Claude Code early, before the full test harness lands.
  - `python3` availability on target — confirm install-env assumption now.
  - Diff-traceability audit (M6+M7) is the highest-leverage gap-check step; QA-analyst should be briefed.
