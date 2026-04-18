# STATUS

- **slug**: 20260418-per-project-install
- **has-ui**: false
- **stage**: tasks
- **created**: 2026-04-18
- **updated**: 2026-04-18

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] brainstorm    (01-brainstorm.md)           — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM
- [x] tasks         (06-tasks.md)                — TPM
- [ ] implement     (tasks checked off)          — Developer
- [ ] gap-check     (07-gaps.md, verdict PASS)   — QA-analyst
- [ ] verify        (08-verify.md, verdict PASS) — QA-tester
- [ ] archive       (moved to .spec-workflow/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-18 | pm | request intake filed
- 2026-04-18 | pm | brainstorm complete — recommends copy-at-pinned-ref with per-project update, flagged dogfood-paradox (5th occurrence)
- 2026-04-18 | pm | prd complete — R13 requirements, 0 blockers
- 2026-04-18 | architect | tech complete — D12 decisions, 0 blockers
- 2026-04-18 | orchestrator | design skipped (has-ui: false)
- 2026-04-18 | tpm | plan complete — 6 waves (incl W0 skeleton, W6 dogfood-final), 12–13 placeholder tasks, dogfood staging plan explicit (this repo stays on global-symlink through W5; W6 migrates-self as final act; runtime confirmation deferred to next feature after session restart per shared/dogfood-paradox-third-occurrence.md 6th occurrence)
- 2026-04-18 | tpm | tasks decomposed — T1..T21, widest wave 6 parallel (W5) across 7 wave slots (W0 skeleton, W1 library bundle, W2 init+tests, W3 update+tests, W4 migrate+tests, W5 skill+smoke+docs, W6=dogfood-final); D3 manifest schema + D4 classifier pseudocode + D4 dispatcher table quoted verbatim into T2 per tpm/briefing-contradicts-schema.md; AC2.c split into T6 (t41 real-file-conflict); R↔T trace fully populated (every R1–R13 covered; every T1–T21 maps to ≥1 R)
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W0 tasks=T1 axes=security,performance,style
- 2026-04-18 | implement | review result — wave W0 verdict=NITS (style: 5 should-findings re comment-restates-what + emit_summary dead-symbol; security PASS; performance PASS)
- 2026-04-18 | implement | wave W0 done — T1 (--one-wave mode, orchestrator halts for user checkpoint)
- 2026-04-18 | implement | W0 NITS hotfix — 5 style should-findings on bin/specflow-seed cleared via 20260418-per-project-install-T1-hotfix; comment-only changes, T1 Verify re-confirmed green, no re-review run
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W1 tasks=T2 axes=security,performance,style
- 2026-04-18 | implement | review result — wave W1 verdict=BLOCK blocking-tasks=T2(security 2× must path-traversal on classify_copy_target:224 + manifest_read:163); performance PASS; style 9× should (4 dead-symbols, 5 WHAT-comments); worktree+branch 20260418-per-project-install-T2 preserved for retry via /specflow:implement 20260418-per-project-install --task T2
- 2026-04-18 | implement | T2 retry 1/2 — folded fix commit fa8c6dc; traversal guard at manifest_read boundary + defense-in-depth case-guard in classify_copy_target + 4 dead-symbol TODOs + 5 WHAT-comments cleaned; all 9 Verify assertions (7 original + 2 new traversal) pass; 621 LOC
- 2026-04-18 | implement | review result (retry) — wave W1 verdict=NITS (security 1× should on __probe manifest-roundtrip mpath arg, hidden internal verb; performance PASS; style 2× advisory); BLOCK cleared, merged as 7a38ee0
- 2026-04-18 | implement | wave W1 done — T2 (--one-wave mode, orchestrator halts for user checkpoint)
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W2 tasks=T3,T4,T5,T6 axes=security,performance,style (12 reviewer agents parallel)
- 2026-04-18 | implement | review result — wave W2 verdict=NITS; T3 security 2× should (silent .bak clobber in drifted-ours + manifest paths) + performance 1× advisory (per-file python3 batch opportunity) + style 3× should (WHAT-comments); T4 all-PASS; T5 performance 1× advisory (find -exec); T6 style 1× advisory (WHAT-comment); no must findings, all 4 tasks merged
- 2026-04-18 | implement | wave W2 done — T3,T4,T5,T6 (--one-wave mode, orchestrator halts for user checkpoint); 6/21 tasks complete
- 2026-04-18 | implement | W2 post-merge hotfix (c621fef) — 3 bugs + T3 NITS: (1) must — cmd_init swallowed write_atomic failures (dispatcher reported created: without checking pipe exit); (2) should — asdf + sandbox-HOME broke python3 shim in t39/t40/t41; (3) trivial — T6 AC7.d grep too wide (`-f` literal caught legit tempfile+test-operators); (4) source-leak root cause: t40 missing cd $CONSUMER before init (not a cmd_init design bug); (5) idempotent-exit added: cmd_init short-circuits before manifest rewrite+hook wiring when nothing changed, restores AC2.b byte-identity; (6) T3 NITS cleared: .bak timestamp-versioning + 3 WHAT->WHY comments. Developer retry 1 caught: first fix overloaded --to<ref> as path flag (would collide with cmd_update W3), reverted; second fix excluded manifest from hash (symptom-fix), replaced with idempotent-exit. All 3 tests PASS; source repo clean.
- 2026-04-18 | Developer | T7 implement — cmd_update: tri-hash classifier (D4), --to <ref> required (D6), manifest-read baseline, plan_copy update (no team-memory), dispatch arms mirror cmd_init (write_atomic exit-check, .bak versioning), ref-advance gate on MAX_CODE != 0, idempotent-exit short-circuit (no manifest rewrite on zero-mutation run), manifest-check precedes src-resolve so missing-manifest error is unambiguous without --from. 1159 LOC (+255 from W2 hotfix base at 904). All verify assertions PASS.
- 2026-04-18 | implement | review dispatched — wave=W3 tasks=T7,T8,T9,T10 axes=security,performance,style (12 reviewer agents parallel)
- 2026-04-18 | implement | review result — wave W3 verdict=NITS (no must findings); T7 security PASS + performance 1× advisory (~6 forks/relpath, accepted per W2 T3 precedent) + style 3× should (2× WHAT-comments at Step 5/Step 7 banners + Step 3→5 numbering gap vs cmd_init's 1-10); T8 all-PASS; T9 all-PASS; T10 security PASS + performance 1× advisory (uname -s not cached across file_mtime/tm_hash) + style 1× should (LESSON_MTIME dead assignment)
- 2026-04-18 | implement | wave W3 done — T7,T8,T9,T10 merged (commits 4f96088, 48ec452, d4b61d0, 3c02511); 10/21 tasks complete
- 2026-04-18 | implement | T9 post-merge 1-line hotfix (da2a109) — manifest path in t43 was `.spec-workflow/manifest.json` (wrong); corrected to `.claude/specflow.manifest` per D3. Post-hotfix smoke t39-t44: all PASS.
- 2026-04-18 | implement | review dispatched — wave=W4 tasks=T11,T12,T13,T14 axes=security,performance,style (12 reviewer agents parallel)
- 2026-04-18 | implement | review result — wave W4 verdict=NITS (no must findings); T11 sec PASS (D10 abstention confirmed) + perf PASS + style 1× should (step-banner periods) + 2× advisory (WHY-truncations); T12 all-PASS; T13 sec 1× advisory (fixture direct-write, low risk in sandbox) + perf PASS + style PASS; T14 all-PASS.
- 2026-04-18 | implement | wave W4 done — T11,T12,T13,T14 merged (commits 4e15e7c, 06e6cd3, a19db1c, ...); 14/21 tasks complete. Post-merge smoke: all 9 tests (t39-t47) PASS. **No post-merge hotfix needed** (first wave clean-merge since W0).
- 2026-04-18 | implement | review dispatched — wave=W5 tasks=T15,T16,T17,T18,T19,T20 axes=security,performance,style (18 reviewer agents parallel)
- 2026-04-18 | implement | review result — wave W5 verdict=NITS (no must); T15 sec 1× should (SPECFLOW_SRC not asserted absolute); T16 style 2× advisory; T17 all-PASS; T18 style 1× advisory (`pwd` -P convention); T19 all-PASS; T20 style 1× should (explicit `{#anchor}`) + 1× advisory (table padding)
- 2026-04-18 | implement | wave W5 done — T15-T20 merged; 20/21 tasks complete. Post-merge smoke: 49/50 PASS; **t50 dogfood_staging_sentinel FAIL** — `~/.claude/agents/specflow` does not exist on this machine (global install was never run here). W6 gating issue: either run `bin/claude-symlink install` first to establish global state, or skip T21 (dogfood migrate has no global state to migrate from — T21's `migrate --from .` becomes effectively an init).
- 2026-04-18 | implement | T21 dogfood migration (option B variant) — user chose B (skip t50 gate, run T21; no global install to tear down). Removed t50 from test/smoke.sh registration. Ran `bin/specflow-seed migrate --from . --ref $HEAD`. Output: created=0 already=58 replaced=0 skipped=0 exit=0. **Surfaced + fixed idempotent-exit bug**: when source == consumer on a fresh consumer (no prior manifest), the W2-hotfix idempotent-exit fired before manifest-write → NO manifest authored. Root cause: the short-circuit condition only checked counter state, not manifest presence. Fix: added `[ -f "${consumer_root}/.claude/specflow.manifest" ]` to both cmd_init and cmd_migrate idempotent-exit conditions so first-time writes still author the manifest. Re-ran migrate post-fix: `.claude/specflow.manifest` created at ref=94fa3ac, settings.json gained Stop hook entry (.bak produced), managed-subtree hash byte-identical (8f13d7e...). smoke.sh: 49/49 PASS. `~/.claude/` unaffected (D10 holds; no global install state to touch).
- 2026-04-18 | tpm | T21 dogfood migration complete — this repo is now its own per-project consumer; .claude/specflow.manifest created at ref 94fa3ac; settings.json rewired to local hooks (.bak available); global ~/.claude/* symlinks left in place per D10 for any un-migrated consumer on this machine.
