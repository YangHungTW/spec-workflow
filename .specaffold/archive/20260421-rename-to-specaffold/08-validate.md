# Validate: 20260421-rename-to-specaffold
Date: 2026-04-21
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 5 should

## Tester axis

qa-tester walked AC1–AC15 dynamically. Summary:

| AC | Description | Result |
|---|---|---|
| AC1 | grep allow-list clean | PASS |
| AC2 | README heading `# Specaffold` | PASS |
| AC3 | `scaff` in README code block | PASS |
| AC4 | commands/scaff/ present; specflow/ absent | PASS |
| AC5 | All agent names start `scaff-` | PASS |
| AC6 | No `specflow-*` in bin/ | PASS |
| AC7 | Hooks clean; latency (193ms / 4ms) | PASS (advisory: 7ms margin) |
| AC8 | Archive byte-identical | PASS |
| AC9 | request.md references `scaff-pm` | PASS |
| AC10 | pm.md frontmatter `name: scaff-pm` | PASS |
| AC11 | [runtime] /scaff:request live dispatch | DEFERRED (PRD §9 AC-R14) |
| AC12 | Migration notes file with mapping table | PASS |
| AC13 | `scaff` CLI alias invocable + README documented | PARTIAL — no bare `scaff` binary; `scaff-*` siblings per tech D3 |
| AC14 | PRD §8 D1–D6 intact | PASS |
| AC15 | .spec-workflow symlink absolute, archive resolves | PASS |

All ACs PASS or cleanly DEFERRED per PRD §9. AC13 deviation is a deliberate architectural decision (tech D3) superseding the PRD R5 wording.

### Evidence highlights
- `bash test/t_grep_allowlist.sh` → exit 0, `PASS: t_grep_allowlist.sh — tree free of legacy specflow/spec-workflow references (or all hits allow-listed)`
- `head -1 README.md` → `# Specaffold`
- `ls .claude/commands/scaff/` → 19 files; `.claude/commands/specflow/` absent
- All 10 agent files show `name: scaff-*`; zero `specflow-*` agent names
- `bin/` contains scaff-aggregate-verdicts, scaff-install-hook, scaff-lint, scaff-seed, scaff-tier — no `specflow-*` entries
- session-start.sh wall-clock 193ms (within 200ms budget by 7ms); stop.sh 4ms
- `git diff main...HEAD --name-status -- .specaffold/archive/**` shows zero `M` entries (pure renames)
- `readlink .spec-workflow` → `/Users/yanghungtw/Tools/spec-workflow/.specaffold` (absolute)
- `diff -q .spec-workflow/archive/20260419-flow-monitor/03-prd.md .specaffold/archive/20260419-flow-monitor/03-prd.md` → identical

```
## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    ac: AC7
    message: session-start.sh latency 193ms (7ms below 200ms budget); T17 review noted 256ms on a loaded machine — pre-existing, not regressed by this feature, but headroom is thin; recommend TPM note for next hook-modifying feature
  - severity: should
    ac: AC13
    message: no bare `scaff` binary or shell alias exists; `command -v scaff` returns non-zero; tech D3 intentionally chose `scaff-*` sibling topology over a bare wrapper, but PRD R5/AC13 wording ("CLI alias `scaff` is invocable") is unmet as literally written — README documents `bin/scaff-seed` as the entry point, which satisfies the spirit but not the letter
```

## Analyst axis

qa-analyst performed static PRD-vs-tasks-vs-diff gap analysis.

### R-id to task mapping — all 17 R-ids covered

Every R1–R17 maps to at least one task and has direct diff evidence. No missing R-ids.

| R-id | Owning tasks | Diff evidence |
|------|-------------|---------------|
| R1 | T13 | README.md heading `# Specaffold`; `scaff` in 48 lines |
| R2 | T1, T9 | `.claude/commands/scaff/` present; specflow/ absent |
| R3 | T2, T10 | 10 agent files with `name: scaff-*` |
| R4 | T13 | README clean; root *.md clean |
| R5 | T3, T11 | 5 bin/scaff-* binaries present |
| R6 | T22, T23, T24, T21c, T21d | `bash test/t_grep_allowlist.sh` exits 0; 11 allow-list entries |
| R7 | T3, T11 | `ls bin/ \| grep specflow-` = 0 |
| R8 | T17, T18 | Hook files 0 hits; session-start 189–195ms |
| R9 | T19, T20 | Rules prose clean |
| R10 | T21a, T21b, T21d | Team-memory prose clean; filenames preserved |
| R11 | T6 | Rename commit: 110 files at 0 body delta, pure renames |
| R12 | T6, T8 | .specaffold/ present; .spec-workflow is symlink |
| R13 | T9, T10, T16, T30 | scaff-pm anchor pair verified |
| R14 | T29 | RUNTIME HANDOFF line pre-committed |
| R15 | T27 | docs/rename-migration.md exists with mapping table |
| R16 | T27 | Migration notes cover organic global migration |
| R17 | T8, T25, T26 | .spec-workflow absolute symlink; ensure_compat_symlink defined + wired |

### AC coverage — all 15 ACs covered (AC11 runtime-deferred by design)

### Missing: none. Extra: none (flow-monitor handling was the deliberate T28 prerequisite). Drift: 3 should-severity advisories.

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    kind: drift
    r_or_ac: AC7
    message: session-start.sh measures 189-195ms warm — within 200ms budget but <10ms margin; pre-feature STATUS cited 256ms, no formal post-W3 baseline recorded in validate artefacts
  - severity: should
    kind: extra
    r_or_ac: R6
    message: .claude/carryover-allowlist.txt line 6 pre-allows RETROSPECTIVE.md before the file exists; silently covers any future carryover strings the RETROSPECTIVE introduces
  - severity: should
    kind: drift
    r_or_ac: R8
    message: .claude/hooks/stop.sh:95 inline-review NITS spacing finding retained as followup per STATUS — not fixed inline
```

## Validate verdict
axis: aggregate
verdict: NITS
