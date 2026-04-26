# Request

## Source

- type: description
- value: |
  scaff-seed init does not create .specaffold/config.yml or copy .specaffold/preflight.md, so the preflight gate (feature 20260426-scaff-init-preflight) fires REFUSED:PREFLIGHT on freshly-init'd consumer repos — gate sentinel assumes init produces these files but scaff-seed's manifest only ships .specaffold/features/_template/

## Context

The preflight gate feature (`20260426-scaff-init-preflight`, archived at
`.specaffold/archive/20260426-scaff-init-preflight/`) shipped earlier today.
Every `/scaff:<cmd>` slash command now carries a W3 marker block instructing
the assistant to "Run preflight from .specaffold/preflight.md", and the gate
body asserts the existence of `.specaffold/config.yml` as its passthrough
sentinel. The feature was validated structurally (t108 / t110 mocked
config.yml presence in `mktemp -d` sandboxes), but the integration path
"real `bin/scaff-seed init` -> resulting state of `.specaffold/`" was not
exercised.

The bug surfaced today when the user ran `/scaff-init` in
`/Users/yanghungtw/Tools/llm-wiki/`. The install reported success (61 files
plus the `.specaffold/features/_template/` tree, plus the pre-commit hook),
but neither `.specaffold/config.yml` nor `.specaffold/preflight.md` was
created. Any `/scaff:*` invocation in that repo now fails closed with
`REFUSED:PREFLIGHT` — and because `.specaffold/preflight.md` is also
missing, the assistant cannot even read the gate body it is being asked to
run. Severity is high: every consumer repo init'd since the preflight gate
landed today is in this broken state.

The class of error matches the qa-analyst memory
`partial-wiring-trace-every-entry-point` — validation covered the gate
entrypoint but not the wiring path (init manifest) responsible for putting
the gate into a passing state.

## Why now

User-facing breakage on first contact: `/scaff-init` succeeds but the
freshly-installed surface is unusable. A workaround exists (manually copy
`preflight.md` and create `config.yml`) but it is not discoverable from
the failure mode. Ship the fix as a focused bug.

## Out of scope

- Validating `config.yml` schema (deferred to a separate feature).
- Adding more keys to the default `config.yml` beyond `lang.chat: en`.
- Changing the gate body's sentinel choice (still `.specaffold/config.yml`).
- Auto-update mechanism for already-init'd consumer repos (user runs
  `bin/scaff-seed migrate` to backfill).

## UI involved?

No — engine plumbing only (bin/scaff-seed + integration test).
