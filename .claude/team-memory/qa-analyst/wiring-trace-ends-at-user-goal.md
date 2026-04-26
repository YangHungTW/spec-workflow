---
name: Wiring-trace must end at user's goal, not at the closest assertable midpoint
description: A wiring-trace gap analysis must terminate at the user's actual end-goal (e.g. "consumer can run /scaff:next"), not at the closest structural midpoint that's easy to assert (e.g. "config.yml byte-matches source"); structural assertions can pass while the user's goal still fails.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When the analyst traces wiring at validate time, the trace must end at the **user's actual end-goal** for the feature, not at the closest assertable structural midpoint. A structural assertion that's easy to write (file exists, byte-cmp matches, exit code 0 in sandbox) is not the same as evidence that the user can accomplish what the feature promised.

Concretely: ask "if I shipped this and a fresh user tried to do X, would X work?" — and trace the path from X back through every dependency. Any dependency the test doesn't exercise is a wiring-trace gap, regardless of how cleanly the structural assertion passes.

## Why

`20260426-fix-init-missing-preflight-files` shipped a fix for the preflight gate's install gap. The validate stage produced a NITS verdict via `t112_init_seeds_preflight_files.sh`:

- A1: both `.specaffold/config.yml` and `.specaffold/preflight.md` exist after `scaff-seed init` — PASS
- A2: `cmp` byte-identical to source — PASS
- A6: extracted SCAFF PREFLIGHT block runs from consumer CWD with exit 0 — PASS
- A7: same for migrate path — PASS

All structural assertions cleanly passed. Validate verdict NITS (only style/perf nits, no functional findings).

Then the user tried `/scaff:next` in a freshly-init'd consumer repo (`llm-wiki`) and it FAILED — because `bin/scaff-tier`, `bin/scaff-stage-matrix`, etc. are NOT in scaff-seed's manifest, and `/scaff:next` sources them via `$REPO_ROOT/bin/...`. The user's actual goal ("init this repo and use scaff in it") was still broken.

The wiring-trace t112 performed terminated at "the two files we shipped exist and are correct". It did NOT terminate at "user can run a `/scaff:*` command end-to-end in the init'd repo". The midpoint was an easy place to stop the trace, but it was not the goal.

This is a distinct lesson from `partial-wiring-trace-every-entry-point.md` (which is about *which entry points the trace covers* — init AND migrate, not just init). This one is about *where the trace terminates* — at the goal, not at the convenient midpoint.

## How to apply

1. **At validate time, before composing 08-validate.md**, write down the user's actual end-goal in plain prose for this feature. What does the user accomplish if it ships? Examples:
   - Bug `20260426-fix-init-missing-preflight-files`: "After `/scaff-init`, the user can run any `/scaff:<cmd>` command in their consumer repo without hitting REFUSED:PREFLIGHT or `command not found: scaff-tier`."
   - Feature `20260418-per-project-install`: "A user with no global scaff install can run `/scaff:request` in any new repo after a single bootstrap step."
   - Refactor: "After this lands, X behaves identically to before from the user's perspective; the diff is invisible at runtime."

2. **For each end-goal, list the dependencies that must hold for it to succeed.** Be exhaustive — every file the user's command path reads, every binary it invokes, every env var it reads. Cross-reference the diff to confirm each dependency is shipped (or is documented as a separate concern).

3. **Compare the dependency list to the test's assertion list.** Any dependency NOT exercised by an assertion is a wiring-trace gap. Severity:
   - **must** if the dependency is fundamental to the goal (e.g. a sourced library like `bin/scaff-tier`).
   - **should** if it's an edge case the test could plausibly miss (e.g. one of N entry points — covered by `partial-wiring-trace-every-entry-point.md`).
   - **advisory** if it's defensive (e.g. malformed input handling).

4. **The terminus check is "does the user's goal succeed end-to-end in a fresh sandbox", not "do the artefacts the developer wrote exist".** When in doubt, write a runtime test that simulates the user's actual workflow from a clean sandbox. The cost is one extra test; the benefit is catching trace-terminus bugs before they ship.

5. **For features that touch a user-facing CLI surface**, the runtime test should be invocable from a sandbox where the assistant is NOT in the loop (no `/scaff:*` or `Task` calls inside the test) — this enforces that the wiring-trace doesn't accidentally rely on assistant-interpreted directives.

## Example

The validate that should have caught the bin/* gap on `20260426-fix-init-missing-preflight-files`:

**End-goal**: "After `bin/scaff-seed init` in a consumer repo, the user can run any `/scaff:<cmd>` without REFUSED:PREFLIGHT or sourced-library errors."

**Dependencies enumerated** (manually, by reading the command markdown of `/scaff:next`):
1. `.specaffold/config.yml` exists in consumer (gate sentinel) ← T112 covered
2. `.specaffold/preflight.md` exists in consumer (gate body file referenced by W3 marker block) ← T112 covered
3. `bin/scaff-tier` exists at the path the command sources from (`$REPO_ROOT/bin/scaff-tier`) ← **NOT COVERED by T112**
4. `bin/scaff-stage-matrix` exists ← **NOT COVERED**
5. `bin/scaff-lint` exists for pre-commit hook ← **NOT COVERED** (hook tests fail in consumer)
6. `bin/scaff-aggregate-verdicts` exists for `/scaff:implement` ← **NOT COVERED**

The dependency list was 6 items; the test covered 2. The trace terminated at items 1+2 because they were easy to assert with `cmp` and `[ -f ]`. Items 3–6 required either copying source's bin/ or sourcing it differently — both architectural decisions that the bug fix didn't make. The trace-terminus discipline would have surfaced "we covered the gate's two files but did not cover the user's actual goal" as a `must`-class finding at validate, not as a runtime discovery in a separate session.

The follow-up bug (`fix-commands-source-bin-from-scaff-src`, B-world architecture) is the actual fix to items 3–6.
