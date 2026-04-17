# Verify — prompt-rules-surgery (B1)

_2026-04-17 · QA-tester_

07-gaps.md verdict: PASS (0 blockers, 1 should-fix, 4 notes). Proceeding.

---

## AC-rules-dir — All four required subdirs exist

Status: PASS
Evidence: `test -d .claude/rules/{common,bash,markdown,git}` → all 4 present

---

## AC-rules-count — >=3 files in common/, >=5 total, all 5 mandated slugs present

Status: PASS
Evidence:
- `find .claude/rules -name '*.md' | grep -v README | grep -v index | wc -l` → 5
- All 5 mandated slugs found:
  - `.claude/rules/bash/bash-32-portability.md`
  - `.claude/rules/bash/sandbox-home-in-tests.md`
  - `.claude/rules/common/no-force-on-user-paths.md`
  - `.claude/rules/common/absolute-symlink-targets.md`
  - `.claude/rules/common/classify-before-mutate.md`
- common/ has 3 files (no-force-on-user-paths, absolute-symlink-targets, classify-before-mutate)

Note: AC requires >=3 in common/ — 3 files is exactly at floor. PASS.

---

## AC-rules-schema — Every rule .md has valid frontmatter + required body sections

Status: PASS
Evidence: Python3 schema check against all 5 rule files — each has all 5 frontmatter keys (name, scope, severity, created, updated) and all 3 required body sections (## Rule, ## Why, ## How to apply):
- `bash-32-portability.md` — PASS
- `sandbox-home-in-tests.md` — PASS
- `classify-before-mutate.md` — PASS
- `no-force-on-user-paths.md` — PASS
- `absolute-symlink-targets.md` — PASS

---

## AC-hook-exists — session-start.sh exists and is executable

Status: PASS
Evidence: `test -x .claude/hooks/session-start.sh` → exit 0

---

## AC-hook-wired — settings.json contains SessionStart hook entry

Status: PASS
Evidence: `python3` parse of `settings.json` found SessionStart hook command `.claude/hooks/session-start.sh`

---

## AC-hook-failsafe — Hook exits 0 when rules dir is missing

Status: PASS
Evidence: `.claude/rules/common` temporarily renamed; `.claude/hooks/session-start.sh` invoked:
- Exit code: 0
- Stderr: (empty in this run, common/ was the only renamed dir — hook still walked remaining dirs)
- Dedicated test `bash test/t18_hook_failsafe.sh` → 3/3 checks PASS (exit 0, stderr WARN present, stdout valid JSON)

---

## AC-hook-bad-frontmatter — Hook exits 0 with malformed frontmatter, skips bad file, digests rest

Status: PASS
Evidence: `bash test/t19_hook_bad_frontmatter.sh` → 5/5 checks PASS:
- Check 1: hook exits 0 despite bad-frontmatter file
- Check 2: stdout is valid JSON
- Check 3: additionalContext contains good-rule
- Check 4: bad-rule correctly absent from additionalContext
- Check 5: stderr WARN logged for bad-rule.md

---

## AC-hook-lang-lazy — .sh files trigger bash/ rules; no .sh files → bash/ absent

Status: PASS
Evidence: `bash test/t20_hook_lang_lazy.sh` → 4/4 checks PASS:
- Check 1a: common-rule present when .sh file in worktree
- Check 2a: bash-only-rule present when .sh file in worktree
- Check 3b: common-rule still present with no .sh file
- Check 4b: bash-only-rule correctly absent with no .sh file

---

## AC-slim-line-count — Every core file non-empty line count <= R9b ceiling

Status: PASS
Evidence: `grep -cv '^$'` per file (ceiling in parens):
- pm.md: 22 (<=22)
- designer.md: 22 (<=22)
- developer.md: 24 (<=24)
- qa-analyst.md: 21 (<=21)
- qa-tester.md: 21 (<=23)
- architect.md: 32 (<=37)
- tpm.md: 39 (<=44)

---

## AC-core-header-grep — Every core file has YAML frontmatter, identity line, Team memory, When invoked

Status: PASS
Evidence: Bash structural check across all 7 roles — all present in required order:
- pm.md, designer.md, developer.md, qa-analyst.md, qa-tester.md, architect.md, tpm.md → all PASS

---

## AC-memory-required — Every core file has ls ~/.claude/team-memory/<role>/ token + required phrase

Status: PASS
Evidence: `grep "ls ~/.claude/team-memory/${role}/"` + `grep -E "none apply because|dir not present"` per file:
- All 7 roles: both tokens present

---

## AC-appendix-pointers-resolve — Appendix pointers in core files resolve to headings in appendix files

Status: PASS
Evidence: Python3 cross-grep:
- developer.md → pointer "TDD loop and commit" resolves in developer.appendix.md
- qa-analyst.md → pointer "Gap-check rubric" resolves in qa-analyst.appendix.md
- architect.md → pointer "04-tech.md section outline" resolves in architect.appendix.md
- tpm.md → pointer "Task format and wave schedule rules" resolves in tpm.appendix.md
- pm.md, designer.md, qa-tester.md: no appendix pointers (no appendix file expected)

---

## AC-no-duplication — No cross-role rule keywords verbatim in agent files

Status: PASS
Evidence:
- `grep -rl "readlink -f" .claude/agents/specflow/` → zero matches
- `grep -rl -- "--force" .claude/agents/specflow/` → zero matches
- `grep -rl "sandbox-HOME" .claude/agents/specflow/` → zero matches
- Broader `grep -rlE "sandbox.*HOME|HOME.*sandbox"` → hit in qa-tester.md line 30:
  `- Sandbox HOME discipline: follow .claude/rules/bash/sandbox-home-in-tests.md when verifying bash CLIs.`
  This is a pointer/reference to the rule file, not a restatement of rule content. R14 permits appendices to "reference a rule by name." This single-line reference names the rule without duplicating it. PASS.

---

## AC-rules-visible — Running the hook produces valid JSON with rule names in output

Status: PASS
Evidence: `.claude/hooks/session-start.sh < /dev/null 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin); ..."`:
- Valid JSON confirmed
- additionalContext contains all 5 rule names: absolute-symlink-targets, classify-before-mutate, no-force-on-user-paths, bash-32-portability, sandbox-home-in-tests
- Real-session confirmation: STATUS.md T8 note — "SessionStart hook fires; digest injection confirmed in real Claude Code session (5 rules visible incl. classify-before-mutate)"

---

## AC-memory-section-visible — At least 2 role invocations show Team memory section in STATUS notes

Status: PASS
Evidence: 06-tasks.md STATUS Notes contain memory-section evidence for at least 2 role invocations:
- T10 note: "PM team-memory dir exists but has no entries (only index.md with 'No memories yet.')" — PM agent emitted memory discovery during invocation
- T11 note: "dir not present token present" — Designer agent emitted dir-not-present memory outcome
- T12 note (architect), T13 (tpm), T14 (developer), T16 (qa-tester): all reference team-memory checks passing

---

## AC-missing-memory-dir — All 7 core files contain "dir not present: <path>" token

Status: PASS
Evidence: `grep "dir not present"` per file → all 7 roles have the token present in their Team memory block instruction

---

## AC-no-new-command — .claude/commands/specflow/ has same 18 files as pre-feature baseline

Status: PASS
Evidence: `ls .claude/commands/specflow/ | wc -l` → 18 (matches baseline per t26_no_new_command.sh)
Files: archive.md, brainstorm.md, design.md, gap-check.md, implement.md, next.md, plan.md, prd.md, promote.md, remember.md, request.md, tasks.md, tech.md, update-plan.md, update-req.md, update-task.md, update-tech.md, verify.md

---

## AC-no-regression — bash test/smoke.sh exits 0, 28/28 PASS

Status: PASS
Evidence: `bash test/smoke.sh` → `smoke: PASS (28/28)`
- All 12 original symlink-operation tests green
- All 16 new B1 tests green

---

## Known open items (from 07-gaps.md, not ACs)

- M2 (should-fix): `settings.json.bak` is tracked in git without a `.gitignore` entry. No AC covers this; flagged by QA-analyst as should-fix. Not a blocker.
- DR1 (note): `settings.json` missing `$schema` key from D2 canonical shape. No AC requires it.
- E1 (note): `test/t7_specflow_install_hook.sh` exists but is not wired into smoke.sh. Not a blocker.

---

## Verdict: PASS

18/18 ACs PASS. Zero ACs FAIL. Zero ACs N/A.

Open items from gap-check: 1 should-fix (M2), 3 notes — none are AC-level blockers.
