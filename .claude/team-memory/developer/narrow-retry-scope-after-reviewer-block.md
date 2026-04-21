## Rule

When a reviewer BLOCK finding implicates files outside the task's declared `Scope:`, the retry fixes only what *this task's diff* directly introduced or broke; escalate the broader gap as a plan gap via a STATUS note, do not expand scope silently.

## Why

In the rename-to-specaffold feature (2026-04-21), T15's style reviewer BLOCK flagged stale `specflow_ref` awk-sniff lines in two consumer test files — a real consumer-breakage caused by T15's `specflow_ref → scaff_ref` JSON-key rename. A naive read would have bundled all 88 `test/**/*.sh` rewrites into the T15 retry. The developer instead:

1. Fixed exactly the 10 lines in the 2 consumer files that referenced the key T15 itself renamed.
2. Emitted a STATUS note: "PLAN GAP surfaced by T15 review: 88 test/**/*.sh files contain specflow|spec-workflow references; no W2/W3 task covers test/ body rewrites".
3. Let the orchestrator add T21c via `/scaff:update-plan`.

Result: T15 scope stayed reviewable (narrow), the reviewer re-verified cleanly, and the broader gap was addressed via the proper channel (TPM-owned plan mutation, not developer-owned silent expansion).

## How to apply

1. Identify which file-set the reviewer finding is a *direct* consequence of the task's own edits.
2. Fix that set only; run the reviewer-specified verification.
3. For any other files the finding's root cause touches that fall outside the task's declared scope: emit a STATUS line describing the broader gap explicitly, and stop.
4. Let orchestrator decide whether to `/scaff:update-plan` for a new task or `/scaff:update-task` to grow the existing one.
5. Do NOT bundle a "while I'm here" fix into a retry commit; reviewer re-runs against a narrow diff are faster and clearer.
