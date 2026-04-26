# Validate: 20260426-fix-init-missing-preflight-files
Date: 2026-04-26 13:21
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 1 should, 2 advisory

## Note (post-validate architectural finding)

Discovered during validate: this fix only addresses .specaffold/{config.yml,preflight.md}.
A subsequent runtime exploration (user attempted /scaff:next in a freshly-init'd
consumer repo) revealed that bin/scaff-tier, bin/scaff-stage-matrix, and the broader
bin/* surface are ALSO not in scaff-seed's manifest — so /scaff:* commands still
fail in consumer repos. User decision: instead of expanding this bug to copy bin/
too (option A: self-contained consumer), shift architecture to thin consumer
(option B): command preambles source from $SCAFF_SRC, not $REPO_ROOT. The B-world
fix lands in a follow-up bug. This bug's emit_default_config_yml helper is keep-
worthy (config.yml still lives in consumer); the plan_copy preflight.md entry will
become redundant in B-world but is harmless until cleaned up.

## Tester axis

# QA-Tester Validate Report
# Feature: 20260426-fix-init-missing-preflight-files
# Axis: tester
# Date: 2026-04-26

## Team memory

Applied entries:
- `qa-tester/index.md` — validate artefact is 08-validate.md (not 08-verify.md); orchestrator writes it.
- `qa-tester/index.md` — PRD AC wording superseded by tech D-id → PARTIAL+D-id; not silent-PASS.
- `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds.md` applies: t112 is
  an end-to-end integration test (full scaff-seed init run in sandbox), not a unit mock.

No other entries apply: no UI (has-ui: false), no rename, no CSS.

---

## Test execution — t112 exit code and output

Command: bash test/t112_init_seeds_preflight_files.sh
Exit code: 0

Output:
=== A1: AC1 — both files created by init ===
PASS: A1 — both .specaffold/config.yml and .specaffold/preflight.md created

=== A2: AC2 — preflight.md byte-identical to source ===
PASS: A2 — .specaffold/preflight.md is byte-identical to source

=== A3: AC3 — config.yml has lang.chat keys ===
PASS: A3 — config.yml has lang: chat: en

=== A4: AC4 — idempotency on second init ===
PASS: A4 — second init reports already: for both files; content unchanged

=== A5: AC5 — no-force on foreign config.yml ===
PASS: A5 — init skipped user-edited config.yml; content byte-identical

=== A6: AC6 — preflight passthrough on init'd consumer ===
PASS: A6 — preflight exits 0 with empty output on init'd consumer

=== A7: AC7 — migrate path parity (partial-wiring-trace gap closer) ===
PASS: A7 — migrate produces same files as init; partial-wiring-trace gap covered

PASS: t112

---

## AC mapping — PRD AC1–AC7 vs test A1–A7

AC1: files exist after init                      → A1 ([ -f config.yml ], [ -f preflight.md ])       PASS
AC2: preflight.md byte-identical to source       → A2 (cmp exits 0)                                   PASS
AC3: config.yml has lang:/chat: en               → A3 (3× grep -E/F)                                  PASS
AC4: second init idempotent, already: tokens     → A4 (grep already: + shasum-before==after)           PASS
AC5: user-edited config.yml not clobbered        → A5 (skipped:user-modified token + shasum check)     PASS
AC6: preflight gate passthrough on init'd repo   → A6 (awk extract + bash run, exit 0, empty stdout)   PASS
AC7: integration test covers full path           → A7 (migrate-path mirror: fresh consumer, both files present, byte-identical to init) PASS

All 7 ACs covered; A7 covers AC7's "integration test exercises full path" requirement via the migrate path, per the plan's D7 decision.

---

## Production spot-checks

### emit_default_config_yml occurrences in bin/scaff-seed

Command: grep -nE "emit_default_config_yml|plan_copy.*preflight" bin/scaff-seed | head -20
Result:
  382: # emit_default_config_yml <consumer_root>
  387: emit_default_config_yml() {                 ← definition
  816:   emit_default_config_yml "$consumer_root"  ← cmd_init call (Step 8c)
  1403: emit_default_config_yml "$consumer_root"   ← cmd_migrate call (Step 8c mirror)

D5 compliance (byte-identical call sites, single helper): confirmed — both call sites are the same
single-argument invocation; no inlined heredoc at either call site. Content lives exclusively
inside the helper.

### plan_copy preflight.md entry

Command: grep -n "preflight.md" bin/scaff-seed
Result:
  440: if [ -f "${src_root}/.specaffold/preflight.md" ]; then
  441:   printf '.specaffold/preflight.md\n'

D6 (sibling block, not prefix-list entry) confirmed.

### wc -l unique emit_default_config_yml lines

Command: grep -F "emit_default_config_yml" bin/scaff-seed | sort -u | wc -l
Result: 4
(definition comment line, function header, comment line at cmd_init, call at cmd_init —
the cmd_migrate comment and call are byte-identical to cmd_init's pair, so sort -u collapses
them to the same 4 unique text lines. Both call sites ARE present; uniqueness just means they
are textually identical, which is exactly the D5 requirement.)

---

## Advisory note: `already:` format inconsistency in scaff-seed

The post-merge fixup (commit b1a6d40) corrected A4/A5 grep-targets in t112 after the
tester discovered two different `already:` formats emitted by scaff-seed for different code paths:

- `already:.specaffold/config.yml`   (no space — helper emit_default_config_yml, bin/scaff-seed line 400)
- `already: .specaffold/preflight.md` (with space — plan_copy dispatcher, bin/scaff-seed line 728)

This is an existing inconsistency within scaff-seed itself (the pre-commit shim also uses
`already:.git/hooks/pre-commit` at line 804, no space). The inconsistency is not introduced by
this feature — both patterns existed before — and it does not break any functional requirement.
However, consumers grepping `already:` for tooling will see mixed formats. This is an advisory
finding; not a blocker.

---

## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: advisory
    ac: AC4
    message: >
      `already:` token format inconsistency in scaff-seed: helper path emits
      `already:.specaffold/config.yml` (no space); plan_copy dispatcher emits
      `already: .specaffold/preflight.md` (with space). Not introduced by this
      fix — pre-existing in scaff-seed. Noted for future cleanup; does not block.


## Analyst axis

# QA-analyst gap analysis — 20260426-fix-init-missing-preflight-files

## Team memory

Applied entries:
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — directly drives
  checklist item 5 (was the A7 migrate-path test closure gap honored?);
  used to verify that both cmd_init and cmd_migrate call sites are covered
  by test assertions.
- `shared/partial-wiring-trace-every-entry-point.md` — dir not present at
  local path; the qa-analyst copy was authoritative.

---

## 1. R-id / AC coverage matrix

| ID    | Trace target                                               | Code change?                    | Test assertion?              | Verdict     |
|-------|------------------------------------------------------------|---------------------------------|------------------------------|-------------|
| R1    | init + migrate create config.yml; no overwrite existing   | bin/scaff-seed +emit_default_config_yml (+2 call sites) | A1, A4, A5, A7 | COVERED |
| R2    | init + migrate copy preflight.md verbatim; no overwrite   | bin/scaff-seed plan_copy sibling block | A1, A2, A4, A7 | COVERED |
| R3    | manifest discoverable/explicit; fits pattern              | D6 sibling block adds one if-block; helper function is named, single source of truth | A7 (parity check) | COVERED |
| R4    | after init: scaff-lint preflight-coverage exit 0; no REFUSED:PREFLIGHT | config.yml + preflight.md now seeded → sentinel present; scaff-lint exists unchanged | A6 (gate passthrough) | COVERED |
| R5    | regression integration test t112 covering full path       | test/t112_init_seeds_preflight_files.sh (new, 245 lines) | All A1-A7 | COVERED |
| AC1   | both files exist after init                                | emit_default_config_yml + plan_copy sibling block | A1 | COVERED |
| AC2   | preflight.md byte-identical to source                      | plan_copy copies verbatim; classifier uses sha256 | A2, A7 | COVERED |
| AC3   | config.yml has lang: + chat: sub-key with default 'en'    | printf 'lang:\n  chat: en\n' in helper | A3 | COVERED |
| AC4   | second init idempotent; already: tokens; content unchanged | classify_default_config_yml → ok → already:; plan_copy → ok | A4 | COVERED |
| AC5   | pre-existing user-edited config.yml not clobbered          | classify_default_config_yml → user-modified → skipped:user-modified: | A5 | COVERED |
| AC6   | gate body passthrough exit 0 + empty stdout on init'd repo | config.yml sentinel present after fix | A6 | COVERED |
| AC7   | integration test covers mktemp → init → assert both files + preflight exit 0 | t112 A1+A6 | A1, A6; A7 also covers migrate | COVERED |

All 5 R-ids and all 7 ACs have at least one code change and at least one
test assertion. No gaps.

---

## 2. D-id coverage

| D-id | Prescription                                              | Code evidence                                            | Test coverage |
|------|-----------------------------------------------------------|----------------------------------------------------------|---------------|
| D1   | Helper emits 2-line heredoc for config.yml (lang:chat:en) | emit_default_config_yml printf 'lang:\n  chat: en\n'    | A3, A7 |
| D2   | preflight.md via plan_copy (explicit single-path entry)   | plan_copy if [ -f "${src_root}/.specaffold/preflight.md" ] | A1, A2 |
| D3   | Reuse existing classifier states missing/ok/user-modified | classify_default_config_yml emits exactly those 3 states | A4, A5 |
| D4   | cmd_migrate parity                                        | emit_default_config_yml called from cmd_migrate (~line 1405) | A7 |
| D5   | Byte-identical helper — no inlined heredoc duplication    | grep -F "emit_default_config_yml" scaff-seed \| grep -v '#\|classify\|^emit' \| sort -u yields exactly one line: `emit_default_config_yml "$consumer_root"` appearing at two distinct line numbers | A7 (sha parity init vs migrate) |
| D6   | Sibling block in plan_copy, not prefix-list refactor      | diff shows an isolated if/fi block added AFTER the prefix loop, BEFORE team-memory case; prefix list itself is unchanged | A2 |
| D7   | New t112 standalone test (not extension of t108)          | test/t112_init_seeds_preflight_files.sh created new (100755) | — |

D5 confirmed: `grep -F "emit_default_config_yml" bin/scaff-seed | grep -v '#\|classify\|^emit' | sort -u` returns exactly one unique call form (`emit_default_config_yml "$consumer_root"`), appearing at lines 818 and 1405 — byte-identical invocations.

D6 confirmed: diff context shows the sibling block inserted after the closing `done` of the for-loop (line 121 of diff) and before the `# Team-memory skeleton` case block. The prefix list (`for prefix in ... ".specaffold/features/_template"`) is untouched.

---

## 3. Drift analysis

### 3.1 Output-token inconsistency: emit_default_config_yml vs plan_copy dispatcher — advisory/should

The post-merge fixup commit (b1a6d40) changed t112 A4 grep from
`'already: .specaffold/config.yml'` (with space) to
`'already:.specaffold/config.yml'` (no space), because the actual
implementation at bin/scaff-seed line 400 emits:

    echo "already:.specaffold/config.yml"

whereas the plan_copy dispatcher (line 728) and the copy-loop dispatcher
both emit:

    echo "already: ${relpath}"     # note: space after colon

The 04-tech.md D3 implementation note pseudo-code ALSO shows the
with-space form (`echo "already: .specaffold/config.yml"`), making 04-tech
inaccurate relative to the shipped code.

The same split applies to `skipped:user-modified`:
- emit_default_config_yml:  `skipped:user-modified:.specaffold/config.yml`  (no space)
- plan_copy dispatcher:     `skipped:user-modified: ${relpath}`             (with space)
- 05-plan T2 A5 spec says: `'skipped:user-modified: .specaffold/config.yml'` (with space)
- t112 A5 (actual): `grep -F 'skipped:user-modified:.specaffold/config.yml'` (no space — matches reality)

Result: the t112 test assertions are internally consistent with the
IMPLEMENTATION (the fixup corrected the test-to-code mismatch). But the
04-tech.md D3 note and 05-plan.md T2 A4/A5 spec still describe the
with-space form. These are doc-drift artifacts. More importantly, the
underlying `bin/scaff-seed` itself has two different token conventions:
`already:<path>` (no space, from the helper) vs `already: <path>` (space,
from the copy-loop dispatcher). This is a style/consistency finding on the
binary that any consumer of scaff-seed stdout (e.g. future tests, log
parsers) will need to know about.

Classification: `should` (not must) — the runtime works; no regression
risk today; the inconsistency is in log output tokens, not in user data or
gate logic. A cleanup to make `emit_default_config_yml` output match the
copy-loop convention (`already: .specaffold/config.yml`) would unify the
convention but requires re-aligning t112 A4 again.

### 3.2 04-tech.md D3 pseudo-code drift vs implementation

The 04-tech.md D3 implementation note shows:
    echo "created: .specaffold/config.yml"   (with space)
    echo "already: .specaffold/config.yml"   (with space)
    echo "skipped:user-modified: .specaffold/config.yml"  (with space after last colon)

Actual implementation (bin/scaff-seed lines 396/400/404):
    echo "created:.specaffold/config.yml"          (no space)
    echo "already:.specaffold/config.yml"          (no space)
    echo "skipped:user-modified:.specaffold/config.yml"   (no space)

04-tech.md is an archive input and is advisory-only at this point, but
it represents a documentation-vs-implementation gap.

Classification: `advisory` — tech doc pseudo-code is a reference, not a
test fixture; the implementation and the test are aligned; the tech doc
is not the source of truth for token format.

---

## 4. Out-of-scope verification

- **config.yml schema validation**: not present in the diff. No `scaff-lint config-yml`
  or equivalent validation logic added to bin/scaff-seed or bin/scaff-lint.
  PRD §Out-of-scope is honored. PASS.

- **Extra keys beyond lang.chat**: diff shows only
  `printf 'lang:\n  chat: en\n'` in the helper and the classifier comparison.
  No `lang.code`, `tier.default`, or other keys added. PRD D1 ("no other keys")
  is honored. PASS.

---

## 5. Bug fix verification (reason from diff)

**Was the underlying bug fixed?**

Before this diff: `plan_copy` enumerated `.specaffold/features/_template/`
but not `config.yml` or `preflight.md`. The new:
- sibling block in plan_copy emits `.specaffold/preflight.md` if present in source
- `emit_default_config_yml` is called from both `cmd_init` (line 818) and
  `cmd_migrate` (line 1405)

In a fresh sandbox post-init:
1. `plan_copy` now enumerates `.specaffold/preflight.md` → copy-loop creates
   `$CONSUMER/.specaffold/preflight.md` (state=missing → write_atomic).
2. `emit_default_config_yml` is called → `classify_default_config_yml` returns
   `missing` (file does not exist) → `printf 'lang:\n  chat: en\n' | write_atomic`
   creates `$CONSUMER/.specaffold/config.yml`.
3. `bin/scaff-lint preflight-coverage` reads `.specaffold/config.yml` as the
   sentinel — now present → passes.
4. Any `/scaff:*` invocation finds config.yml → preflight gate passthrough.

The bug is fixed by construction. A6 in t112 exercises the exact passthrough
path end-to-end.

**Partial-wiring-trace closure (team memory discipline)**:
The lesson from `qa-analyst/partial-wiring-trace-every-entry-point.md`
is honored: A7 in t112 explicitly exercises the `cmd_migrate` path and
asserts both files are present with expected content, closing the mirror
coverage gap that was the root cause of the sibling feature's regression.

---

## 6. Summary of findings

1. **should** — `bin/scaff-seed`: `emit_default_config_yml` emits
   `already:.specaffold/config.yml` (no space) while the plan_copy
   dispatcher emits `already: ${relpath}` (space). The token convention
   is inconsistent within the same binary. Future log parsers or tests
   targeting scaff-seed stdout must handle two conventions. Recommend
   aligning to the copy-loop convention in a follow-up.

2. **advisory** — `04-tech.md` D3 pseudo-code shows `already: .specaffold/config.yml`
   (with space) but the shipped implementation uses `already:.specaffold/config.yml`
   (no space). Tech doc is stale; no runtime impact. No action required
   before archive, but worth noting for post-archive retro.

No must-severity gaps found.

---

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: bin/scaff-seed
    line: 400
    rule: style-naming-convention
    message: emit_default_config_yml emits 'already:.specaffold/config.yml' (no space) while
      plan_copy dispatcher at line 728 emits 'already: ${relpath}' (with space); inconsistent
      token convention in the same binary — log parsers and future tests must handle both forms.
  - severity: advisory
    file: .specaffold/features/20260426-fix-init-missing-preflight-files/04-tech.md
    line: 312
    rule: doc-drift
    message: D3 pseudo-code shows 'already: .specaffold/config.yml' (with space) but shipped
      implementation uses 'already:.specaffold/config.yml' (no space); tech doc is stale
      relative to implementation; no runtime impact.


## Validate verdict
axis: aggregate
verdict: NITS
