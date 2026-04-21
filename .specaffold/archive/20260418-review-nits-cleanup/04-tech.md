# Tech — review-nits-cleanup

**Slug**: `20260418-review-nits-cleanup`
**Date**: 2026-04-18
**Author**: Architect
**Stage**: tech

---

## 1. Context & Constraints

**Existing stack** (unchanged by this feature): bash 3.2 (macOS `/bin/bash`) + BSD userland as the portability floor; Python 3 for anything beyond bash's reach; markdown for all prompts, agents, rules, memory; git + GitHub CLI for workflow. Tests are pure bash under `test/` (smoke harness `test/smoke.sh`, 38 tests).

**Hard constraints**:
- Zero behavior change. Every change is a text edit, dead-code delete, or verified byte-identical refactor.
- bash 3.2 portability floor (`.claude/rules/bash/bash-32-portability.md` — `must`). Forbids `readlink -f`, `realpath`, `jq`, `mapfile`, `[[ =~ ]]` for portability-critical logic, GNU-only flags.
- `sandbox-home-in-tests` (`.claude/rules/bash/sandbox-home-in-tests.md` — `must`) stays in force but no new tests are added.
- `no-force-on-user-paths` (`.claude/rules/common/no-force-on-user-paths.md` — `must`) — not triggered here; no user-owned files are touched, only repo-shipped files.
- `classify-before-mutate` (`.claude/rules/common/classify-before-mutate.md` — `must`) — applies as a discipline to R4 (find all `reviewer-security/` references before any edit) and R12 (verify zero callers before deleting `to_epoch`).

**Soft preferences**: minimal diff. This is a housekeeping sweep — consume existing patterns, do not invent new ones.

## 2. System Architecture

No architectural change. Fourteen in-place edits across eight files:

```
.claude/
  commands/specflow/
    review.md              ← R1 (add slug validator, Step 1)
    implement.md           ← R6 (pseudocode indent normalize)
  agents/specflow/
    reviewer-security.md   ← R4 (reviewer-security/ → reviewer/)
    reviewer-style.md      ← R5 (team-memory invocation block reshape)
  hooks/
    stop.sh                ← R12 (delete to_epoch, lines ~103-117)
test/
  t26_no_new_command.sh    ← R10 (delete WHAT comment)
  t34_reviewer_verdict_contract.sh  ← R3 (refactor), R7 (pipefail)
  t35_reviewer_rubric_schema.sh     ← R2 (refactor) + R11 (folded in)
  t37_review_oneshot.sh    ← R8 (pipefail)
  t38_hook_skips_reviewer.sh ← R9 (pipefail)
```

No new components. No new dependencies. No data flow changes.

## 3. Technology Decisions

### D1. R1 slug-validation regex dialect

- **Options considered**:
  - A. POSIX `case "$slug" in [a-z0-9][a-z0-9-]*) : ;; *) die "invalid" ;; esac`
  - B. `printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$'` (grep subshell)
  - C. `[[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]` (bash-only regex)
- **Chosen**: **A**.
- **Why**: `bash-32-portability` rule explicitly rejects `[[ =~ ]]` for portability-critical logic (bash 3 vs 4 regex dialect drift). `case` glob is POSIX, zero-fork, bash 3.2 safe, and the natural idiom for a single validator guard. B works but spawns a process and introduces pipefail interaction risk; A is strictly simpler.
- **Tradeoffs accepted**: `case` glob is not a full regex — it enforces the same allowed alphabet (`[a-z0-9-]`) and the leading-char constraint (`[a-z0-9]`), but does not enforce a minimum length beyond 1 char. The PRD regex `^[a-z0-9][a-z0-9-]*$` allows single-character slugs too, so A matches the specified alphabet exactly. Equivalent for the stated requirement.
- **Reversibility**: high — single command-file edit, no downstream coupling.
- **Requirement link**: R1.

### D2. R2/R3 byte-identical output verification

- **Options considered**:
  - A. Developer captures `bash test/t35.sh 2>&1` pre- and post-refactor into a sandbox, runs `diff`, task fails if non-empty.
  - B. Rely on the smoke suite alone (`test/smoke.sh` 38/38).
  - C. Add a new golden-output file to the repo.
- **Chosen**: **A**.
- **Why**: PRD G4 / AC2 / AC3 demand byte-identical output as a hard gate. The smoke suite only validates that each `t*.sh` exits 0; it does not detect output drift. A in-place diff of captured output before and after the refactor is the minimum effective check. C adds maintenance burden for a zero-behavior-change feature and conflicts with the minimal-diff preference.
- **Tradeoffs accepted**: verification is ephemeral (done in sandbox, not committed). Developer must run it inside each refactor task's verify step; TPM will make this the task's acceptance bar.
- **Reversibility**: n/a — verification discipline, not a committed artifact.
- **Requirement link**: R2, R3.

### D3. R4 + R13 grep-before-rename discipline (classify then mutate)

- **Options considered**:
  - A. Edit `reviewer-security.md` in place, then run `grep -rn 'reviewer-security/' .claude/` as a post-check (AC13).
  - B. First enumerate every occurrence across `.claude/` with a single pre-edit grep (produce a list), apply edits, verify list is now empty.
- **Chosen**: **B**.
- **Why**: `classify-before-mutate` rule (`must`) and the architect memory of the same name: enumerate the full set of targets before any write. Pre-edit grep **is** the classifier here — it produces the closed set of locations; the edit phase dispatches. Avoids the bug where an in-file edit misses a reference in another file (e.g., a rule file or team-memory stub) and passes AC4 while failing AC13.
- **Tradeoffs accepted**: one extra grep invocation at task start. Trivial.
- **Reversibility**: high.
- **Requirement link**: R4, R13.

**Pre-check evidence already gathered**: `grep -r 'reviewer-security/' .claude/` currently returns exactly one file — `.claude/agents/specflow/reviewer-security.md` — so R4's in-file edit is sufficient; no other `.claude/` file needs touching. R13 is expected to pass trivially once R4 lands. Developer must re-run the classifier grep during task execution (state may drift between tech-doc time and task time).

### D4. R12 dead-code removal precondition

- **Options considered**:
  - A. Delete `to_epoch` unconditionally.
  - B. Grep the repo for `to_epoch` call sites first; escalate if any found outside the definition itself.
- **Chosen**: **B**.
- **Why**: same classify-before-mutate discipline. Architect memory `qa-analyst/dead-code-orphan-after-simplification.md` and PRD §8 flag this explicitly — if a surviving caller exists, R12 becomes a behavior question, not a housekeeping delete.
- **Tradeoffs accepted**: n/a.
- **Reversibility**: high (git revert).
- **Requirement link**: R12.

**Pre-check evidence already gathered**: `grep -rn 'to_epoch' .` across the repo returns matches in exactly these classes:
1. The definition itself at `.claude/hooks/stop.sh:103-108` (the target of R12).
2. The `bash-32-portability` rule's example block at `.claude/rules/bash/bash-32-portability.md:91-92,105` — **documentation**, not a caller.
3. A comment reference in `test/t32_stop_hook_dedup.sh:7` — **comment**, not a caller.
4. Archived feature docs under `.spec-workflow/archive/20260417-shareable-hooks/` — **historical**, out of scope.
5. The in-flight feature docs under `.spec-workflow/features/20260418-review-nits-cleanup/` — **this PRD itself**.

Zero live call sites. R12 is safe to delete. The rule-file example in (2) is a documentation snippet for bash-32-portability and does not depend on the function existing in `stop.sh`; it stands on its own and stays put.

Developer must re-run `grep -rn 'to_epoch' .` during task execution and abort to TPM/PM if the classifier finds a new caller.

### D5. R11 folded into R2's deliverable

- **Options considered**:
  - A. Sequence R2 (awk-fold refactor of t35.sh) before R11 (delete WHAT comment at line 106); R11 becomes a two-line edit on top.
  - B. R2 includes the comment deletion as part of the refactor's natural restructuring; R11 becomes a verification-only check (`grep -c 'Extract line numbers of each required heading' test/t35.sh` == 0).
- **Chosen**: **B**.
- **Why**: R2's awk-fold restructures the exact region that contains the R11 comment. Writing R11 as a separate edit on the post-R2 file is redundant and creates a spurious second diff. Folding avoids ordering pitfalls and keeps the diff narrative clean (one intent per change).
- **Tradeoffs accepted**: slight conflation of source findings (St7 + P1) in a single diff hunk; traceability preserved because PRD Traceability table still cites both IDs to the same file.
- **Reversibility**: high.
- **Requirement link**: R2, R11.

### D6. R5 team-memory invocation block shape — match the numbered-ls pattern

- **Options considered**:
  - A. Rewrite `reviewer-style.md`'s invocation block to mirror `reviewer-security.md` / `reviewer-performance.md`'s numbered `ls` checklist verbatim (with the correct path swapped in).
  - B. Introduce a third shape that unifies all three.
- **Chosen**: **A**.
- **Why**: `scope-extension-minimal-diff` memory — do not re-cut the taxonomy. Two of three agents already use the numbered-ls shape; align the third to that shape. Don't invent a new unified template just to touch one file.
- **Tradeoffs accepted**: the numbered-ls pattern becomes de facto canonical; any future fourth reviewer will follow it. Fine — that is the point of convention.
- **Reversibility**: high.
- **Requirement link**: R5.

## 4. Cross-cutting Concerns

- **Error handling**: R1's slug validator emits a human-readable error to stderr and exits 2 — same contract as existing command pre-flight failures.
- **Logging / tracing / metrics**: unchanged.
- **Security / authn / authz**: R1 closes the only surface this feature touches — a slug that reaches `cd "$feature_dir"` or `git log -- "$feature_dir"` without validation could traverse out of `.spec-workflow/features/`. `case`-glob guard eliminates this.
- **Testing strategy**: smoke suite (38/38) is the existing regression bar. No new tests added (PRD §3 non-goal). R2/R3 byte-identical-output diffs (D2) are per-task verification, not new committed tests.
- **Performance**: R2 (one awk pass per rubric file, three files) and R3 (one cat-to-variable per agent file, three files) reduce per-file fork/exec count; absolute improvement is small but the pattern aligns with repo convention.

## 5. Open Questions

**None — no blockers.**

All PRD open questions were locked at request stage. Pre-checks for D3 (grep-before-rename) and D4 (dead-code caller search) already ran clean. R11/R2 sequencing resolved as D5. Regex dialect resolved as D1.

## 6. Non-decisions (deferred)

- **Whether to adopt `case`-glob as a repo-wide convention for all future slug/name validators.** Not decided. Trigger: a second feature introduces a similar validator and the pattern repeats — at that point, promote to an architect-memory pattern entry. Today's D1 applies to R1 only.
- **Whether to audit every other `set -u` (without `pipefail`) across the full `test/` tree.** PRD scope caps at R7/R8/R9 (three specific files). Trigger: the next `/specflow:review` run flags additional instances. Not absorbed into this feature per PRD §3.
- **Whether to convert any remaining `[[ =~ ]]` occurrences repo-wide.** Trigger: failing smoke run on a fresh bash 3.2 shell, or a subsequent reviewer-bash finding. Out of scope here.

---

## Architect memory — candidates for archive

Housekeeping sweeps consume patterns; they rarely create them. One genuine candidate if it holds up through implementation:

- **grep-before-rename saved us from a bug** — if the pre-edit classifier grep (D3) catches a `reviewer-security/` reference outside the expected file during task execution, that's a concrete instance of classify-before-mutate paying for itself on a pure text edit (not just a filesystem mutation). Worth a short memory entry if it fires. Today's pre-check shows it won't fire, so flag as "only write if verify stage discovers something."

Otherwise: no new architect memory expected from this feature.
