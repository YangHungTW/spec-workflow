# Validate — tier-model

**Feature**: `20260420-tier-model`
**Stage**: validate
**Shape**: new merged form (tester + analyst axes in one file per PRD R19/D10).
**Author**: QA-tester (tester axis)
**Date**: 2026-04-19

---

## Tester axis

Dynamic walkthrough of each AC against executable checks (tests in `test/`).
Where an AC is marked **[structural only; runtime deferred to B2]** per PRD §9.1,
this axis exercises the structural check and records the B2 handoff explicitly.

---

### AC1 — STATUS schema present [R1, R2] [structural]

**Check**: Template STATUS.md has `tier:` field between `has-ui:` and `stage:`.
B2's STATUS.md has `tier: standard` inserted at the correct position.

**Tests run**:
- `test/t74_specflow_tier.sh` (68 PASS, 0 FAIL): `get_tier` reads all three valid
  enum values, the `missing` state, and the `malformed` state from STATUS fixtures.
- `test/t74_tier_rollout_migrate.sh` (PASS): dry-run and real-run against fixtures;
  backup created; tier line inserted between `has-ui:` and `stage:`; line count is
  original+1; idempotent re-run emits "skipped" and leaves file unchanged.

**Structural verification**:

```
$ awk '/has-ui/ {hu=NR} /tier:/ {ti=NR} /stage:/ {st=NR} END {print "has-ui="hu" tier="ti" stage="st}' \
    .spec-workflow/features/_template/STATUS.md
# → has-ui=4 tier=5 stage=6  ✓

$ awk '/has-ui/ {hu=NR} /tier:/ {ti=NR} /stage:/ {st=NR} END {print "has-ui="hu" tier="ti" stage="st}' \
    .spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md
# → has-ui=4 tier=5 stage=6  ✓
```

**Verdict**: PASS

---

### AC2 — Tier-aware dispatch [R8, R10] [structural covered; runtime deferred to B2]

**Check**: Unit-test table driven off `tier_skips_stage` for every (tier, stage)
pair per the R10 matrix.

**Test run**:
- `test/t74_specflow_tier.sh` Section 4 (30 skips-stage assertions within the
  68 PASS total): every combination from the R10 matrix verified.
- `test/t84_tier_dispatch_matrix.sh` (41 PASS, 0 FAIL): full matrix including
  edge cases (missing, malformed), validate/has-ui variants.
- `test/t81_next_tier_dispatch.sh` (6 PASS, 0 FAIL): `next.md` sources the tier
  helper, calls `tier_skips_stage` and `get_tier`, handles missing and malformed
  states, contains STATUS Notes format token.

**Runtime deferred to B2**: B2's first `/specflow:next` invocation will confirm
the standard-tier column of R10 fires end-to-end.

**Verdict**: PASS (structural)

---

### AC3 — Archive merge-check [R9] [structural covered; runtime deferred to B2]

**Check**: Mock git repo unit test — standard feature on unmerged branch exits
non-zero; `--allow-unmerged "test"` passes and writes reason to STATUS Notes;
`tiny` tier on same unmerged branch archives cleanly.

**Tests run**:
- `test/t82_archive_merge_check.sh` (11 PASS, 0 FAIL): structural grep of
  `archive.md` confirms `merge-base --is-ancestor`, `--allow-unmerged`, tiny-skip,
  missing-tier legacy skip, path-boundary check, atomic STATUS write.
- `test/t85_archive_merge_check.sh` (11 PASS, 0 FAIL): live git mock repo —
  unmerged+standard refuses; `--allow-unmerged` accepts and appends STATUS Notes;
  `--allow-unmerged` without reason exits 2; tiny tier accepts; missing tier accepts.

**Runtime deferred to B2**: B2's archive will run the merge-check on a real branch.

**Verdict**: PASS (structural)

---

### AC4 — Upgrade audit log [R12, R13] [structural covered; runtime deferred to B2]

**Check**: `set_tier standard→audited` appends a STATUS Note in R13 format;
`set_tier standard→tiny` exits non-zero with no STATUS mutation.

**Tests run**:
- `test/t74_specflow_tier.sh` Sections 2–3 (set_tier transition matrix, audit
  line format, validate_tier_transition): all transitions verified.
- `test/t86_upgrade_audit.sh` (10 PASS, 0 FAIL): R13 audit line format, date
  prefix shape (YYYY-MM-DD), STATUS byte-identity on rejected transition, no
  backup on rejected transition, self-transition no-op.

**Verdict**: PASS (structural)

---

### AC5 — B2 migration zero-touch [R2] [structural covered; runtime deferred to B2]

**Check**: W0 migration pass produces STATUS with `tier: standard` between
`has-ui:` and `stage:` and no other diff.

**Tests run**:
- `test/t74_tier_rollout_migrate.sh` (PASS): dry-run + real-run + idempotent
  re-run against fixture; line-count and position assertions pass.

**Structural verification**:

```
$ grep '^\- \*\*tier\*\*:' .spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md
# → - **tier**: standard  ✓
```

**Runtime deferred to B2**: B2's first `/specflow:next` reads `tier: standard`
via `get_tier` and routes to the standard-tier matrix column.

**Verdict**: PASS (structural)

---

### AC6 — Retired commands dispatch [R4] [structural covered; runtime deferred to B2]

**Check**: Each of `brainstorm`, `tasks`, `verify`, `gap-check` either is absent
from registry or has a deprecation notice pointing to the correct successor.

**Test run**:
- `test/t77_deprecation_stubs.sh` (20 PASS, 0 FAIL, 0 skipped): all four stubs
  present; `description:` line has `RETIRED — see /specflow:<successor>` shape;
  successor mapping matches PRD R4; body contains "No STATUS mutation occurs" and
  "Exits non-zero" sentinels.

**Runtime deferred to B2**: user invokes retired commands in B2's session;
expected deprecation notice or command-not-found.

**Verdict**: PASS (structural)

---

### AC7 — Self-bootstrap hybrid dogfood [R19, R20] [structural only; runtime deferred to B2]

**Check**: This feature's directory contains:
- `00-request.md`, `01-brainstorm.md`, `03-prd.md`, `04-tech.md` in old shape ✓
- `05-plan.md` in new merged shape (narrative + task checklist); no `06-tasks.md`
  as a real file
- `08-validate.md` in new merged shape (this file; no `07-gaps.md` or `08-verify.md`)
- STATUS.md stage checklist showing new-shape boxes

**Structural checks**:

```
Old-shape files: 00-request.md ✓, 01-brainstorm.md ✓, 03-prd.md ✓, 04-tech.md ✓
05-plan.md present ✓ (new merged shape with narrative + task checklist)
06-tasks.md: EXISTS AS SYMLINK → 05-plan.md  (bootstrap bridge; noted in STATUS)
07-gaps.md absent ✓
08-validate.md: being authored now ✓
```

**FINDING (should)**: `06-tasks.md` is a symlink to `05-plan.md`, not absent.
PRD R19 says "no `06-tasks.md` present in this feature's directory". The
orchestrator's STATUS Notes document this symlink as a bootstrap bridge
("to be removed at archive when T21 dispatches file-presence"). No test
enforces its removal. This item requires cleanup before archive.

**FINDING (must)**: The feature's own `STATUS.md` stage checklist still contains
old-shape boxes (`gap-check` and `verify`) and lacks the new `validate` box.
PRD R19 explicitly lists "`STATUS.md` stage checklist | **new shape** | Retire
`tasks`, `gap-check`, `verify` boxes; add `validate`". The template was updated
correctly by T35. This feature's own STATUS was not updated. AC7 cannot be
fully satisfied until this STATUS checklist is updated to the new shape.

**Runtime deferred to B2** per R20.

**Verdict**: FAIL — own STATUS.md stage checklist is old-shape (gap-check + verify
boxes present, validate box absent); 06-tasks.md symlink needs removal at archive.

---

### AC8 — Validate aggregator contract [R17, R18] [structural covered; runtime deferred to B2]

**Check**: Parameterised aggregator passes `{PASS,PASS}→PASS`, `{PASS,BLOCK}→BLOCK`,
`{NITS,PASS}→NITS`, `{malformed,PASS}→BLOCK` (malformed counts as BLOCK).

**Tests run**:
- `test/t76_aggregate_verdicts.sh` (18 PASS, 0 FAIL):
  - Three-axis review: PASS/PASS/PASS→PASS; PASS/NITS/PASS→NITS; PASS/BLOCK/PASS→BLOCK
  - Two-axis validate: tester:PASS analyst:PASS→PASS; tester:PASS analyst:BLOCK→BLOCK;
    tester:NITS analyst:PASS→NITS
  - Malformed: missing header→BLOCK; missing verdict key→BLOCK; verdict outside
    closed set→BLOCK
  - Security-must signal: emits `suggest-audited-upgrade:` when `severity: must` on
    `axis: security`; no signal for non-security must findings
- `test/t78_validate_command.sh` (16 PASS, 0 FAIL): `validate.md` exists; references
  both qa-tester and qa-analyst; mentions parallel dispatch; references `08-validate.md`
  artefact; no `## Reviewer verdict` directive; references aggregator binary.
- `test/t79_validate_verdict_header.sh` (10 PASS, 0 FAIL): qa-tester.md and
  qa-analyst.md both have `## Validate verdict`; no `## Reviewer verdict`; correct
  axis names.

**Runtime deferred to B2**: B2's first `/specflow:validate` emits a parseable
`08-validate.md` footer.

**Verdict**: PASS (structural)

---

### AC9 — Auto-upgrade triggers [R14] [structural covered; runtime deferred to B2]

**Check**: Three independent unit tests fire each trigger (diff >200-lines-OR->3-files,
security-must finding, PRD in sensitive path) and observe a STATUS upgrade note.
Diff-trigger covers both sub-conditions.

**Tests run**:
- `test/t87_auto_upgrade_triggers.sh` (15 PASS, 0 FAIL):
  - A: diff-lines trigger — `SPECFLOW_TIER_DIFF_LINES` default 200 present; threshold
    comparison present; WARNING emitted on breach; STATUS pending note appended.
  - B: diff-files trigger — `SPECFLOW_TIER_DIFF_FILES` default 3 present; comparison
    present; OR between the two thresholds.
  - C: security-must auto-upgrade — aggregator exits 0; emits `suggest-audited-upgrade:`;
    `implement.md` step 7c invokes `set_tier` with security-must reason; non-security
    must does not emit signal.
  - D: sensitive-path trigger in `pm.md` — `settings.json`, `auth` keywords present;
    audited keyword section labelled; audited keywords scanned before tiny.

**Note**: the diff-trigger tests verify implement.md prose/code structure, not a live
`git diff` run (per dogfood paradox). Both sub-conditions (250-line single-file and
5-file 100-line) are distinct cases but are covered by the single OR-check assertion.
A future feature could add runtime fixture tests; structural coverage is sufficient
per AC9's structural/runtime split.

**Runtime deferred to B2**.

**Verdict**: PASS (structural)

---

### AC10 — Mid-flight upgrade non-destructive [R15] [structural]

**Check**: After `tiny→standard` upgrade on a mock feature with a one-line PRD,
the PRD file is byte-identical; STATUS has exactly one line added and one field
mutated (`tier:`).

**Test run**:
- `test/t88_mid_flight_upgrade_nondestructive.sh` (9 PASS, 0 FAIL):
  `03-prd.md` byte-identical before and after upgrade; STATUS has 1 audit note added;
  old `tier: tiny` removed; new `tier: standard` present; slug/has-ui/stage fields
  unchanged; no unexpected new files (STATUS.md.bak is expected and confirmed present).

**Verdict**: PASS

---

### AC11 — Tiny inline review default [R16] [structural covered; runtime deferred to B2]

**Check**: `/specflow:implement` dry-run on a `tiny` feature without `--inline-review`
flag indicates inline review is skipped; on a `standard` feature indicates inline
review runs.

**Tests run**:
- `test/t89_inline_review_default.sh` (10 PASS, 0 FAIL):
  - Gate region names `FEATURE_TIER=tiny` as skip-default trigger.
  - Tiny tier defaults to SKIP inline review; R16 cited.
  - Fallback arm confirms standard/audited inline review runs.
  - `--skip-inline-review` and `--inline-review` flags documented.
  - Gate sources `specflow-tier` and calls `get_tier`.

**Runtime deferred to B2** (any tiny-tier follow-up feature).

**Verdict**: PASS (structural)

---

### AC12 — Interactive tier-proposal prompt [R5] [structural covered; runtime deferred to B2]

**Check**: `/specflow:request` without `--tier` produces a PM prompt containing a
proposed tier value and an invitation for confirmation or override; proposal is
deterministic for the same raw ask.

**Tests run**:
- `test/t80_request_tier_flag.sh` (13 PASS, 0 FAIL): `--tier` flag present; enum
  values documented; `I propose tier:` sentinel present; three-tier definitions with
  em-dash separators; `Press Enter to accept` invitation; `has-ui` probe precedes
  propose-and-confirm; propose-and-confirm precedes slug/STATUS step; re-prompt-once
  discipline documented; no silent default (proposes language present).
- `test/t90_tier_proposal_prompt.sh` (21 PASS, 0 FAIL, 0 skipped): `pm.md` prompt
  contract and scan-order determinism; 10 fixture asks produce correct tiers
  (tiny/audited/standard per keyword hit); request.md delegates tier proposal to pm.
- `test/t80_tier_proposal_heuristic.sh` (SKIP): `propose_tier()` function was not
  added to `bin/specflow-tier` (T25 scope creep reverted per STATUS Notes). The
  function-level determinism is instead exercised by t90 via pm.md keyword extraction.
  The SKIP is intentional; t90 provides equivalent determinism coverage at the
  prose/keyword level.

**Runtime deferred to B2**: first post-rollout feature request exercises the
interactive prompt end-to-end.

**Verdict**: PASS (structural; t80_tier_proposal_heuristic SKIP is intentional and
covered by t90)

---

## Summary table

| AC | Description | Structural | Runtime | Tester verdict |
|---|---|---|---|---|
| AC1 | STATUS schema | t74_specflow_tier ✓, t74_tier_rollout_migrate ✓ | — (none needed) | PASS |
| AC2 | Tier-aware dispatch | t74 §4 ✓, t84 ✓, t81 ✓ | Deferred B2 | PASS |
| AC3 | Archive merge-check | t82 ✓, t85 ✓ (real git) | Deferred B2 | PASS |
| AC4 | Upgrade audit log | t74 §2–3 ✓, t86 ✓ | Deferred B2 | PASS |
| AC5 | B2 migration zero-touch | t74_migrate ✓; B2 STATUS verified | Deferred B2 | PASS |
| AC6 | Retired commands | t77 ✓ | Deferred B2 | PASS |
| AC7 | Self-bootstrap hybrid | File presence ✓ except STATUS checklist FAIL | Deferred B2 | **FAIL** |
| AC8 | Validate aggregator | t76 ✓, t78 ✓, t79 ✓ | Deferred B2 | PASS |
| AC9 | Auto-upgrade triggers | t87 ✓ | Deferred B2 | PASS |
| AC10 | Mid-flight non-destructive | t88 ✓ | — (none needed) | PASS |
| AC11 | Tiny inline review default | t89 ✓ | Deferred B2 | PASS |
| AC12 | Tier-proposal prompt | t80_request ✓, t90 ✓; t80_heuristic SKIP (intentional) | Deferred B2 | PASS |

---

## Validate verdict

axis: tester
verdict: BLOCK
findings:
  - severity: must
    file: .spec-workflow/features/20260420-tier-model/STATUS.md
    line: 19-20
    rule: ac7-self-bootstrap-hybrid
    message: Feature's own STATUS.md stage checklist still has old-shape boxes (gap-check + verify unchecked; no validate box). PRD R19 requires this feature's own STATUS to retire tasks/gap-check/verify boxes and add validate. Template was updated by T35 but this feature's own STATUS was not. Must be corrected before archive.
  - severity: should
    file: .spec-workflow/features/20260420-tier-model/06-tasks.md
    line: 1
    rule: ac7-self-bootstrap-hybrid
    message: 06-tasks.md is a symlink to 05-plan.md (bootstrap bridge). PRD R19 says no 06-tasks.md present. STATUS Notes acknowledge this and flag it for removal at archive. Confirm removal happens before or during archive commit.
