# Validate: 20260426-chore-scaff-plan-chore-aware
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 1 should

## Tester axis

Verifier: scaff-qa-tester. Walked PRD §Checklist C1–C5.

- **C1** — `grep -F 'work-type' .claude/commands/scaff/plan.md` → matches at lines 19 and 22, both inside step 1 input-validation block. The conditional gate is implemented (line 18: "Always require `03-prd.md` exists"; lines 22–24 extract `work_type` via `grep -m1 '^\- \*\*work-type\*\*:'` with default `feature`; line 26: "Require `04-tech.md` exists ONLY when `work_type` is not `chore`"). **PASS**

- **C2a** — `grep -F 'chore-tiny short-circuit' .claude/agents/scaff/tpm.md` → 2 matches (lines 45, 56) both in `## When invoked for /scaff:plan` section. **PASS**

- **C2b** — `grep -F '§1.3' .claude/agents/scaff/tpm.md` → 2 matches (lines 38, 43). **PASS**

- **C2 spot check** — the `### Chore-tiny short-circuit` subsection at tpm.md lines 27–58 contains the canonical §1.3 verbatim text per PRD §Decisions (c) and explicitly forbids dispatching to the full-narrative authoring path while in chore-tiny short-circuit mode. **PASS**

- **C3** — `grep -F 'hand-written' .claude/commands/scaff/next.md` and `grep -F 'hand-write' .claude/commands/scaff/next.md` both return no matches. The matrix-skip arm dispatches `/scaff:plan` like any other tier; no orchestrator stub-writing logic remains. **PASS**

- **C4** — `grep -F 'plumbing fix landed' .claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` → 1 match at line 35. Frontmatter `updated: 2026-04-26` confirmed. §How-to-apply step 1 marked `[LEGACY]`; step 2 `[CURRENT]` points at the Option A fix; step 3 `[ARCHIVED]` preserves the original Option A/B rationale. **PASS**

- **C5** — Forward-only per PRD definition; not testable on this feature's own diff. **DEFERRED — runs on next chore × tiny shipped.**

## Validate verdict
axis: tester
verdict: PASS
findings: []

## Analyst axis

Verifier: scaff-qa-analyst. Static gap analysis comparing PRD R-ids vs tasks vs diff (BASE = e3abeec).

Diff scope: 7 files touched. Four match PRD §Scope verbatim (`plan.md`, `tpm.md`, `next.md`, `chore-tiny-plan-short-circuit-plumbing-gap.md`); `tpm/index.md` is a T2-declared piggyback (plan §1.5); `STATUS.md` and `05-plan.md` are orchestrator bookkeeping. No undeclared edits, no cross-feature leakage, no Out-of-scope violations (Option B not implemented; archived features untouched; chore PRD template untouched; memory retained; `scaff-stage-matrix` untouched; `/scaff:implement` untouched; no new test files).

PRD §Checklist C1–C4 → tasks T1/T2 mapping is correct (T1 → C1+C2; T2 → C3+C4 + §1.5 piggyback; C5 forward-only).

PRD §Decisions (a)–(f) all realised:
- (a) Option A — `/scaff:implement` not touched.
- (b) Template embedded in tpm.md, no separate prd-templates file.
- (c) Canonical §1.3 paragraph emitted verbatim at tpm.md lines 45–48.
- (d) Memory updated, not retired (file present at 8404 bytes).
- (e) STATUS reading mirrors `next.md` line 49 verbatim in both `plan.md` (line 22) and `tpm.md` (line 32).
- (f) Plan stub shape names §1.1/§1.2/§1.3/§1.4, §2, §3, §4 and all task-block fields.

R10.1 byte-identity preserved: when `work_type` is absent, gate defaults to `feature` and still requires `04-tech.md`.

### Findings

One advisory drift:

- **next.md line 63** — The `After:` example still hardcodes the tier name `standard` (changed from `tiny` by T2's edit) rather than using the `<tier>` placeholder that the active instruction line 59 properly generalised to. An orchestrator reading the example as normative could emit the wrong suffix on chore × tiny or chore × audited. The instruction controls behaviour, so no runtime regression exists today, but the example diverges from the instruction's generality.

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    type: drifted
    r-id: §1.5 piggyback (T2 Scope / T2 Verify)
    file: .claude/commands/scaff/next.md
    line: 63
    rule: minimal-diff / drifted-example
    message: "After: example still hardcodes tier name 'standard' (changed from 'tiny') rather than using the '<tier>' placeholder that the active instruction line 59 generalised to; future chore × tiny or chore × audited orchestrators may read the example as normative and emit the wrong suffix."

## Validate verdict
axis: aggregate
verdict: NITS
