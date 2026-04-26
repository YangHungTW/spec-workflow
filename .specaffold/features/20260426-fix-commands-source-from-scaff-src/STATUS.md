# STATUS

- **slug**: 20260426-fix-commands-source-from-scaff-src
- **has-ui**: false
- **work-type**: bug
- **tier**: standard
- **stage**: archive
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] prd           (03-prd.md)                  — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [x] implement     (05-plan.md tasks checked off) — Developer
- [x] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — seeded 00-request.md (Source: description; Context section references parent bug 20260426-fix-init-missing-preflight-files at .specaffold/archive/) and 03-prd.md from bug template; tier standard set via --tier flag (no propose-and-confirm); 7 R-clauses, 8 ACs, 4 D-placeholders for architect, 0 open questions.
- 2026-04-26 orchestrator — fixed STATUS.md placeholders left by PM (slug, work-type, dates) and reordered prd/design checklist to match bug-tier intake convention (request+prd both done at intake).
- 2026-04-26 next — design skipped (has-ui: false; stage_status bug/standard/design = optional → skip)
- 2026-04-26 Architect — wrote 04-tech.md; resolved D1–D4 (PM placeholders) and added D5–D7 (lint reuse, plan_copy cleanup, t113 sandbox test); 0 blockers; applied by-construction-coverage + commands-harvest-scope memory entries.
- 2026-04-26 TPM — wrote 05-plan.md (2 waves, 4 tasks; W1 parallel T1/T2/T3 file-disjoint, W2 single bulk T4 marker sweep across 18 files; dogfood-paradox 12th occurrence; --no-verify enumerated for T1 dev commit + every W1 merge + W1 bookkeeping per no-verify-bookkeeping memory; t113 pre-declared; cross-surface byte-identity check across lint canonical block + 2 scaff-seed heredocs + 18 marker blocks per partial-wiring-trace lesson).
- 2026-04-26 review dispatched — slug=20260426-fix-commands-source-from-scaff-src wave=1 tasks=T1,T2,T3 axes=security,performance,style
- 2026-04-26 review result — wave 1 verdict=NITS (T1-perf advisory: 2 extra forks; T1-style advisory: WHAT-style awk comments; T2-style 3 should: dead run_resolver + orphan resolver_exit + WHAT-comment)
- 2026-04-26 implement — fixup W1: t113 dropped dead run_resolver helper + orphan resolver_exit (T2-style NITS resolved); --no-verify used (lint now fails on un-swept markers per dogfood-paradox sequencing)
- 2026-04-26 implement wave 1 done — T1, T2, T3 (W1 commits + bookkeeping ALL use --no-verify per plan §1.4 — lint extension landed before satisfier)
- 2026-04-26 implement — skip-inline-review USED for wave 2 (reason: W2 fast-merge — T4 dogfood-paradox satisfier; skip noted in merge commit body 6f6e800; reviewers can re-verify post-merge if needed)
- 2026-04-26 implement wave 2 done — T4 (clean dev-commit path per plan §1.4 — no --no-verify needed; lint preflight-coverage passes 18/18 ok)
- 2026-04-26 next — W2 bookkeeping: checked T4 in 05-plan.md and [x] implement in stage checklist; advanced stage field tech → validate. Note: bash test/t113_scaff_src_resolver.sh exits 2 on bash 3.2 due to `printf '--- ...'` lines (printf treats leading `--` as option flag); pre-existing T2 deliverable bug not caught by W1 NITS review. Will surface at validate stage.
- 2026-04-26 validate — slug=20260426-fix-commands-source-from-scaff-src verdict=BLOCK (1 must: t113 printf '--- ...' bash-32-portability bug at lines 95/124/154 — both axes flagged independently; 5 should: AC2 PRD overclaim, t113 A4 sandbox/asdf interaction, W2 skip-inline-review process gap, T3 helper-vs-plan-verify drift, t113 missing A7 assertion). 08-validate.md written. Implementation is functionally correct — AC1/AC3/AC5/AC6/AC7 PASS via subprocess; AC2 first clause PASS; AC4 structural PASS; AC8 evidence gated by the same printf bug. Fix is 3-line edit in test/t113_scaff_src_resolver.sh: printf '--- ...\n' → printf '%s\n' '--- ...'
- 2026-04-26 fixup — commit 2392322: t113 lines 95/124/154 switched to argv-form printf '%s\n' '--- ...' (resolves F1 must); PATH=/usr/bin:/bin:$PATH pinned for A4 scaff-seed init + hook-run sub-shells (resolves F3 should — asdf-shim python3 lookup); rm -f config.yml inserted before A5a so A4's successful seed doesn't break A5a's "no config.yml" precondition. bash test/t113_scaff_src_resolver.sh exits 0 with all A1/A4/A5/A8 assertions passing.
- 2026-04-26 validate (re-run) — slug=20260426-fix-commands-source-from-scaff-src verdict=NITS (advisory findings in 08-validate.md). Resolved: F1 (must — printf bash-32 bug) and F3 (should — t113 A4 sandbox/asdf). Carried forward as advisory: F2 (PRD AC2 "18 paths" overclaim — implementation correct, PRD wording wrong), F4 (W2 skip-inline-review process gap — historical), F5 (T3 plan Verify drift — single helper vs prescribed dual heredocs), F6 (t113 missing A7 assertion). [x] validate checked; stage advanced to archive.
