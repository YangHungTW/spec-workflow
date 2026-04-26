# Request

## Verbatim ask

> extend test/t108_precommit_preflight_wiring.sh with an A5 case asserting bin/scaff-seed migrate produces a hook containing both scan-staged and preflight-coverage invocations (cmd_migrate path, parallel to existing cmd_init A2)

## Context

Parent feature `20260426-scaff-init-preflight` (now under `.specaffold/archive/`) shipped a pre-commit shim emitter in `bin/scaff-seed`. T4 only updated `cmd_init` (~line 733); a W2 reviewer-security observation surfaced the parallel `cmd_migrate` heredoc (~line 1314), which an orchestrator fixup mirrored byte-for-byte. The existing `test/t108_precommit_preflight_wiring.sh` exercises only `cmd_init` (section A2); qa-analyst flagged the missing migrate-path assertion as a `should`-class wiring-trace gap. This chore closes that gap by adding an A5 section parallel to A2.

Source classification: description (free-text from user).
