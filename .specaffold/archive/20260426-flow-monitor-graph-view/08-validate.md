# Validate: 20260426-flow-monitor-graph-view
Date: 2026-04-26 (re-validate after fix `e46700f`)
Axes: tester, analyst

## Consolidated verdict
Aggregate: **NITS** (advisory findings only)
Findings: 0 must, 7 should/advisory

Prior run (pre-fix): BLOCK on analyst F1 (R2/AC2 — 8 of 11 edges unlabeled). Fix
commit `e46700f` labelled all 10 directed edges in `STAGE_EDGES`, wrapped the
bridge edge in `<g>` with a `<text>` child, and rewrote the AC2 test to iterate
all 10 edges (was 2). qa-tester confirms AC2 PASS; qa-analyst confirms F1 resolved.

## Tester axis (verdict: NITS)

19 of 19 ACs PASS or PASS-by-static. AC8 (≤340px card height) is the only NITS:
no automated height assertion exists because jsdom has no real layout engine;
tech D9 explicitly defers AC8 to manual smoke. CSS `max-width` token is present.
Live verification required before release.

```
## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    ac: AC8
    message: No automated height assertion for ≤340px card budget; tech D9 defers to manual smoke
```

## Analyst axis (verdict: NITS)

F1 (must) **resolved** by `e46700f`. 6 should-level findings persist:

- **F2** (`should/extra`) — `lib.rs` canonical payload structs (`ArtifactKind`,
  `WatcherState`, `ArtifactChangedPayload`, `WatcherStatusPayload`) are dead-code
  orphans only referenced from `cfg(test)`; production code uses the MERGE-NOTE
  local copies in `fs_watcher.rs`. The MERGE-NOTE consolidation was never executed.

- **F3** (`should/drifted`) — `lib.rs ArtifactChangedPayload` uses field names
  `repo_path`/`kind` diverging from D3 spec (`repo`/`artifact`); fs_watcher.rs
  copy that actually serialises matches D3. Naive consolidation would break the
  IPC wire format.

- **F4** (`should/extra`) — Branch contains commits/files from a separate feature
  (`20260426-fix-init-missing-preflight-files`): `bin/scaff-seed`,
  `test/t112_init_seeds_preflight_files.sh`, etc. Inflates blast radius of this
  branch's eventual merge.

- **F5** (`should/drifted`) — D8 specifies six token names
  (`--graph-edge-stroke`, `--graph-edge-label-fg`, `--graph-node-active-glow`,
  `--graph-node-skipped-stroke-dasharray`, `--graph-bypass-arc-stroke`,
  `--graph-whisker-fg`); implementation uses different names. Runtime works;
  light-mode follow-up will need the D8/code mismatch resolved first.

- **F6** (`should/missing`) — `prev_stalled_set` carry-state (tech §6 risk 7) is
  never threaded through `spawn_watcher`. `emit_sessions_changed` always resets
  to empty `HashSet`, re-firing stalled notifications on every STATUS.md FS event
  for already-stalled sessions. `notify_dedupe_test` passes only in isolation.

- **F7** (`should/extra`) — `artifactStore.validation.test.ts` (added by W1 T2
  security retry) not listed in T14 plan scope; beneficial content but unplanned.

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    rule: extra
    rid_or_did: D3 / T4
    message: lib.rs canonical payload structs are dead-code orphans (only cfg(test)); fs_watcher.rs uses MERGE-NOTE local copies
  - severity: should
    rule: drifted
    rid_or_did: D3
    message: lib.rs ArtifactChangedPayload field names (repo_path, kind) diverge from D3 spec (repo, artifact)
  - severity: should
    rule: extra
    rid_or_did: (none)
    message: 20260426-fix-init-missing-preflight-files commits/files in this branch trace to a different feature
  - severity: should
    rule: drifted
    rid_or_did: D8
    message: 6 D8 token names not present in shipped theme.css; implementation uses different names; light-mode follow-up impact
  - severity: should
    rule: missing
    rid_or_did: tech-§6-risk-7
    message: prev_stalled_set carry-state never threaded through spawn_watcher; stalled-notification dedup bypassed on FS events
  - severity: should
    rule: extra
    rid_or_did: T14
    message: artifactStore.validation.test.ts not listed in T14 plan scope; beneficial but unplanned deliverable
```

## Validate verdict
axis: aggregate
verdict: NITS
