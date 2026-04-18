# Request

**Raw ask**: 清這13個 nits — clean up the 13 nits surfaced by the first `/specflow:review` meta-demo on feature `20260418-review-capability` (B2.b).

**Context**: Housekeeping sweep of 13 nits from the first `/specflow:review` exercise on B2.b. All findings are `should` / `advisory` severity — no regressions, no blockers, just quality polish (1 security input-validation, 2 performance micro-wins, 8 style/convention drifts, 2 comment hygiene). Aggregate verdict on the source review was NITS (exit 0), so this feature is a deliberate opt-in sweep rather than a blocker fix. Third time we've had post-ship nit candidates (B1 had some, B2.a had some) — this is the first time we open a dedicated feature for them, which also doubles as a real exercise of whether the grouped-cleanup workflow carries its weight. Source report: `.spec-workflow/archive/20260418-review-capability/review-2026-04-18-1450.md`.

**Success looks like**: each of the 13 findings is either (a) resolved in code with a cross-reference from the fix back to the finding ID (S1, P1, P2, St1–St8), or (b) explicitly deferred with written rationale in the PRD / plan. A follow-up `/specflow:review` run against this feature returns PASS or a strictly smaller / different NITS set (no regression of the 13 addressed here).

**Out of scope**:
- Any behavioral change to `/specflow:review` itself (only slug-input validation for S1; no rubric / verdict / contract changes).
- Schema changes (rubric frontmatter, verdict contract, agent frontmatter — untouched).
- New features, new commands, new agents.
- Any finding NOT in the 14-item list (13 review nits + B2.a to_epoch carryover). Scope is tight by construction; discovered nits during the sweep get logged for a future feature, not absorbed here.

**UI involved?**: no

**Resolved decisions (2026-04-18, user-confirmed)**:
1. **Team-memory path = shared `~/.claude/team-memory/reviewer/`** (option a). All 3 reviewer agents align on one directory per role-family. St1 fix converges `reviewer-security/` → `reviewer/` (the other two already use it). R-ids in PRD cite `reviewer/` as the single target.
2. **Scope extension — `to_epoch()` dead code INCLUDED**. `.claude/hooks/stop.sh:108-117` dead function (B2.a gap-check N3) folded into this sweep. Scope becomes **13 review nits + 1 B2.a carryover = 14 items**. Feature slug unchanged; PRD scope notes the carryover.
3. **WHAT-comments = drop** (don't rewrite to WHY). St6 (`test/t26_no_new_command.sh:57`) and St7 (`test/t35_reviewer_rubric_schema.sh:106`): delete the comment line. Shortest correct fix; code is self-evident.
