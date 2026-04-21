---
name: Tier auto-upgrade on security-must is a wave-merge-time boundary check
description: Tier auto-upgrade standard→audited on a security-must reviewer finding must fire at wave-verdict-aggregation time; not at plan (too early), not at archive (too late).
type: decision-log
created: 2026-04-21
updated: 2026-04-21
---

## Rule

The tier auto-upgrade from `standard` to `audited` on encountering a security-must reviewer finding MUST fire at wave-verdict-aggregation time — inside the reviewer verdict pipeline, after axis aggregation, before the orchestrator reports wave-verdict=BLOCK to the user. It MUST NOT fire at plan-stage tier selection (too early — the finding doesn't exist yet) and MUST NOT fire at archive (too late — the audited tier's additional checks would be retroactive).

## Why

`20260420-flow-monitor-control-plane` fired this auto-upgrade successfully for the first time observed in production. STATUS 2026-04-21: "Wave verdict triggered auto-upgrade to audited tier per tech §4.3". T109 invoke_command + get_audit_tail path-traversal findings crossed the security-must threshold; T110 null-classify also independently qualified. The orchestrator correctly:

1. Emitted wave=2 verdict=BLOCK with both blocking tasks identified.
2. Updated STATUS header tier=audited (not the feature file tier, which was still captured as `standard` at the top of 05-plan.md — this is a legitimate mismatch: tier upgrade is a wave-local escalation, not a retro-mutation of the plan).
3. Required both tasks to retry with the audited-tier reviewer axis set.

The placement is load-bearing. If the upgrade fired at plan time, the feature would over-invest in audited-tier discipline for features that never surface a security-must. If it fired at archive, the retrospective would find out too late to add the audited-tier axes. Wave-merge-time is the only place the check has both the signal (a security-must exists) and the leverage (the task has not yet merged; retry is free).

## How to apply

1. The tier auto-upgrade check belongs in `bin/scaff-aggregate-verdicts` or its equivalent, immediately after axis reduction. Pseudocode: `if aggregate.severity == must and any(f.axis == security for f in findings): tier_upgrade("audited")`.
2. The upgrade is one-way within a feature: standard→audited. It does NOT downgrade if subsequent waves are clean. The rationale is that the feature has demonstrated security-relevance and the remaining waves should carry that scrutiny.
3. STATUS Notes must record the upgrade as a separate line at the moment of firing — the 2026-04-21 line in this feature is the template: "tier upgrade standard→audited: security-must findings in T109 (…) and T110 (…)".
4. The 05-plan.md header tier field is NOT rewritten on upgrade — it captures the intent at plan time. The STATUS header is the live tier field. Readers should consult STATUS for the enforcement tier, plan.md for the planning intent.

## Example

Full upgrade chain in this feature:
- W0, W1 ran under standard-tier reviewer set.
- W2 pre-merge review surfaced security-must on T109 + T110 → auto-upgraded.
- W2 retry ran under audited-tier reviewer set (added scrutiny per tech §4.3).
- W3–W6 continued under audited-tier — no downgrade attempted, correct by design.

This is the first observed case of the mid-flight upgrade working cleanly in a single feature; memory documents it so future features can expect the behaviour and reviewers can audit the STATUS line for correct recording.
