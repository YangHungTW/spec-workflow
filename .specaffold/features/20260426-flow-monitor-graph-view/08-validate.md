# Validate: 20260426-flow-monitor-graph-view
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: **BLOCK**
Findings: 1 must, 7 should/advisory

## Tester axis

18 of 19 ACs are PASS or PASS-by-static-evidence.

| AC | Verdict | Evidence |
|---|---|---|
| AC1 | PASS | SessionGraph.test.tsx — 6 tests confirm 11 nodes, row layout, bridge edge |
| AC2 | PASS *(per tester axis)* | "every edge has a non-empty label" passed — but test iterates only 2 of 11 edges (see analyst F1) |
| AC3 | PASS | active-state tests (stage=plan, stage=implement, data-state='active') |
| AC4 | PASS | completed/future state at stage=tech |
| AC5 | PASS | brainstorm skipped + bypass arc tests |
| AC6 | PASS | tasks node partial state, "3 / 7" literal |
| AC7 | PASS | no role=button / tabIndex; SVG role='img' |
| AC8 | **PARTIAL** | No automated height assertion (jsdom layout limitation per tech D9 — manual smoke deferred) |
| AC9 | PASS | whisker rendering with mtime offset |
| AC10 | PASS | parseTaskCounts.test.ts — 10 tests including 3-of-7 fixture |
| AC11 | PASS | TaskProgressBar.test.tsx — 7 tests |
| AC12 | PASS | `cargo test --test fs_watcher_latency` — 1 pass, ~200-300ms observed latency |
| AC13 | PASS | `bash flow-monitor/bin/check-no-polling.sh` — exit 0, all patterns absent |
| AC14 | PASS-by-static | measure-latency.sh exists, --help works, sandbox-HOME applied |
| AC15 | PASS | grep returns no numeric interval; "no polling-footer testid" test passes |
| AC16 | PASS | LiveWatchFooter (8 tests) + App.test.tsx (13 tests) cover pip + toast |
| AC17 | PASS-by-static | README confirmation paragraph dated 2026-04-26 |
| AC18 | PASS | SessionCard.graph.test.tsx — 10 tests cover six chrome elements |
| AC19 | PASS | i18n parity test — 3 tests passing |

```
## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    ac: AC8
    message: No automated height assertion for ≤340px card budget; tech D9 explicitly defers AC8 to manual smoke (jsdom has no real layout); CSS max-width token is present but live verification required before release
```

## Analyst axis

### F1 — MISSING / **must** — R2 / AC2 — 8 of 11 edges unlabeled; AC2 test checks only 2 edges

PRD R2: *"each edge with an artifact label per the canonical scaff stage→artifact map"*. PRD AC2: *"assert every directed edge in the DAG has a non-empty artifact-name label"*.

Actual `STAGE_EDGES` in `SessionGraph.tsx:51-60` has labels on only **3 of 11** edges (`design→prd`, `prd→tech`, `plan→tasks`). The remaining 8 carry no `label` field. The `{edge.label && (<text>...)}` guard at line 200 means the empty-label case emits nothing.

D9 AC2 spec says "assert every `[data-stage-edge]` has a `<text>` child with non-empty content" — but `LABELED_EDGES` in `SessionGraph.test.tsx:54` is `["design-prd", "prd-tech"]` (2 entries), and the test only iterates those, not all 11. Test title and assertion are inconsistent.

Notably, PRD's own example specifically calls out `request → brainstorm labelled with 00-request.md` — that edge has no label.

### F2 — DRIFTED / should — D3 / T4 — `lib.rs` canonical `ArtifactChangedPayload` has divergent field names; struct is an orphan

D3 prescribes fields `repo`, `slug`, `artifact`, `path`, `mtime_ms`. Lib.rs (T4) has `repo_path`, `slug`, `kind`, `path`, `mtime_ms` — `repo_path` ≠ `repo`, `kind` ≠ `artifact`. fs_watcher.rs uses its own MERGE-NOTE local struct (matching D3) and never imports the lib.rs canonical, so the lib.rs struct is dead code with the wrong field names. MERGE-NOTE cleanup from T4 was never completed.

### F3 — DRIFTED / should — D3 — `lib.rs WatcherStatusPayload` missing `repo` field

D3 prescribes `state`, `error_kind`, `repo`. Lib.rs has only `state`, `error_kind`. Same orphan pattern as F2.

### F4 — EXTRA / should — unrelated feature files in diff

`bin/scaff-seed`, `bin/scaff-lint` (existing T12/T18 entries are fine), `test/t112_init_seeds_preflight_files.sh`, and `.specaffold/features/20260426-fix-init-missing-preflight-files/*` are in the branch but belong to a separate feature. Not traceable to any T1–T18.

### F5 — DRIFTED / should — D8 — CSS token names diverge from D8 spec

D8 prescribes `--graph-edge-stroke`, `--graph-edge-label-fg`, `--graph-node-active-glow`, `--graph-node-skipped-stroke-dasharray`, `--graph-bypass-arc-stroke`, `--graph-whisker-fg`. Implementation uses `--graph-edge-done`, `--graph-edge-future`, `--graph-edge-label`, `--graph-node-active-shadow`, `--graph-bypass-stroke`, `--graph-whisker`. Runtime works (components reference shipped names), but the D8 spec and code are misaligned for the light-mode follow-up.

### F6 — DRIFTED / should — tech §6 risk 7 — `prev_stalled_set` carry-state not preserved

`emit_sessions_changed` always initialises `prev_stalled_set = HashSet::new()`. `spawn_watcher` carries no stalled-set across STATUS.md events. Stalled-notification dedup guaranteed by `store::diff` is silently bypassed on every FS event. `notify_dedupe_test` continues to pass because it tests `store::diff` in isolation — not the watcher-integrated path. **Tech mitigation claim is unimplemented.**

### F7 — EXTRA / should — `artifactStore.validation.test.ts` not in T14 scope

This test file (added as W1 T2 security-retry fixup) is not in T14's listed scope. Traces to no R-id; was added as a security-review remediation without plan coverage.

```
## Validate verdict
axis: analyst
verdict: BLOCK
findings:
  - severity: must
    rule: missing
    rid_or_did: R2/AC2
    message: 8 of 11 STAGE_EDGES have no label; AC2 test only checks 2 edges (LABELED_EDGES const)
  - severity: should
    rule: drifted
    rid_or_did: D3
    message: lib.rs ArtifactChangedPayload field names diverge from D3 (repo_path vs repo, kind vs artifact); orphan dead code
  - severity: should
    rule: drifted
    rid_or_did: D3
    message: lib.rs WatcherStatusPayload missing repo field; orphan dead code
  - severity: should
    rule: extra
    rid_or_did: (none)
    message: bin/scaff-seed + 20260426-fix-init-missing-preflight-files/* in diff but trace to a different feature
  - severity: should
    rule: drifted
    rid_or_did: D8
    message: CSS token names diverge from D8 spec; runtime works but light-mode follow-up will hit the wrong names
  - severity: should
    rule: drifted
    rid_or_did: tech-§6-risk-7
    message: prev_stalled_set not carried across STATUS.md FS events; dedup bypassed; notify_dedupe_test passes only in isolation
  - severity: should
    rule: extra
    rid_or_did: T14
    message: artifactStore.validation.test.ts not in T14 task scope; added as security retry fixup without plan coverage
```

## Validate verdict
axis: aggregate
verdict: BLOCK
