## Rule

When a reviewer security-axis review returns a `must`-severity finding during
wave review, the orchestrator auto-upgrades the feature's tier
(standard → audited) by calling `set_tier` with all **4** required arguments:

```bash
set_tier <feature_dir> <new_tier> <actor_role> <reason>
```

Missing the 4th `reason` argument causes `set_tier` to silently no-op — no
STATUS note, no tier-field update, no error. Always verify `STATUS.md` shows
the expected `tier upgrade standard→audited` note after the call before
continuing the wave.

## Why

In `20260422-monitor-ui-polish` wave 4 phase 2, T18's reviewer security axis
returned a `must` finding (missing runtime shape guard on
`list_feature_artefacts` IPC response). The aggregator emitted
`suggest-audited-upgrade: security`. The orchestrator invoked `set_tier`,
logged `- 2026-04-22 orchestrator — tier upgrade standard→audited:
security-must finding in T18-security` to STATUS, and continued the wave with
T18's retry. The upgrade did NOT block the wave. The upgrade did NOT require
user confirmation.

The first invocation was `set_tier "$dir" audited "security-must finding"` —
3 arguments. The function printed its usage banner, returned non-zero, and
silently left `tier: standard` in place. Only after re-reading the function
signature did the orchestrator realise the 4th `reason` argument is
mandatory. The correct call was
`set_tier "$dir" audited "orchestrator" "security-must finding in <task>"`.

## How to apply

1. On receiving an aggregated verdict that emits `suggest-audited-upgrade:
   security`, inspect the feature's current tier via `get_tier`. If
   `standard`, call:

   ```bash
   set_tier "$feature_dir" audited orchestrator "security-must finding in ${TASK_ID}"
   ```

2. Confirm `STATUS.md` shows a new `tier upgrade standard→audited` note
   before continuing. If the tier field still reads `standard`, the call
   silently no-op'd — re-verify argument count.
3. Proceed with the wave and the task retry — the upgrade governs gap-check
   intensity and archive merge-check strictness, not wave-merge gating.
4. Never call `set_tier` with only 3 arguments; the 4th (reason) is not
   optional despite the function signature's apparent flexibility at the
   call site.
