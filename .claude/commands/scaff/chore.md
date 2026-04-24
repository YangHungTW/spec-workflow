---
description: PM intakes a chore (maintenance / cleanup). Usage: /scaff:chore "<ask>" [--tier <tiny|standard|audited>] [slug]
---

1. Parse `$ARGUMENTS`. Supported forms:
   - `"<ask>"` — AI generates the slug from the ask (preferred)
   - `"<ask>" <slug>` — user supplies the slug body explicitly
   - `"<ask>" --tier <tiny|standard|audited>` — user supplies explicit tier (skips propose-and-confirm)
   - `"<ask>" --tier <tiny|standard|audited> <slug>` — explicit tier and slug

   Flag parsing rules (bash 3.2 portable — no `getopts`):
   - Scan `$ARGUMENTS` tokens for `--tier`. If found, the next token is the tier value.
   - Validate the tier value is one of `tiny`, `standard`, or `audited`. If invalid, emit an error and stop.
   - Remaining non-flag tokens are: `<ask>` (first), `<slug>` (second, optional).
   - Store: `USER_TIER=<value>` (explicit, skip propose-and-confirm) or `USER_TIER=""` (absent, must run propose-and-confirm).

2. **Generate slug**:
   - If user did not supply one: derive a 2–5 word kebab-case body capturing the essence of the chore (lowercase, hyphens, alphanumeric only, ≤30 chars body). Examples: "remove-dead-code", "rename-config-keys", "update-readme".
   - Always prepend today's date in `YYYYMMDD` form → final slug = `YYYYMMDD-chore-<body>`.
   - If `.specaffold/features/<slug>/` already exists, append `-<HHMM>` to disambiguate.
   - **If user supplies an explicit slug**, validate it contains the `-chore-` prefix segment. If the supplied slug does NOT contain `-chore-` (i.e. `echo "$slug" | grep -qF -- '-chore-'` fails), emit a usage error to stderr and exit 2:
     ```
     ERROR: explicit slug must contain '-chore-' prefix segment (got: <slug>)
     Usage: /scaff:chore "<ask>" [--tier tiny|standard|audited] [slug]
     ```
     Never silently correct a misnamed slug; the reject-and-report posture is intentional per `.claude/rules/common/no-force-on-user-paths.md`.

3. Copy `.specaffold/features/_template/` to `.specaffold/features/<slug>/`.

4. Set STATUS `work-type: chore` — write the `work-type: chore` line to the newly seeded `STATUS.md` (between the `has-ui:` and `tier:` lines, replacing the template's `work-type: feature` default). Use the atomic-overwrite pattern:
   - Read the seeded STATUS file.
   - Build the updated content with `work-type: chore`.
   - Write to a temp file, then move atomically (`mv tmp STATUS.md`) so there is no partial-write window.

   Note: chores have no has-ui signal by construction — chores are mechanical maintenance and never have a UI component. Leave `has-ui: false` in STATUS (or insert it with `false`); do not probe the user for has-ui.

5. Invoke the **scaff-pm** subagent. PM reads STATUS `work-type: chore` and enters the chore probe branch (see `pm.md` `## When invoked for /scaff:chore`). PM will elicit:
   - Scope (what area of the codebase / config is affected)
   - Reason (why now — tech-debt signal, tooling breakage, dependency requirement)
   - Verify assertion (how to confirm the chore is done; a concrete, grep- or run-able check)

6. PM writes `03-prd.md` using `.specaffold/prd-templates/chore.md` as the template (checklist-shaped per D2 / R8.1). The PRD shape is a checklist: each task item has the form `- [ ] <item> — verify: <assertion>`.

7. **Propose-and-confirm tier** (runs AFTER the PM chore probe, BEFORE slug is finalised):

   - If `USER_TIER` is set (user passed `--tier`): adopt it directly. Write `tier: <USER_TIER>` to STATUS. Append to STATUS Notes: `<date> request — tier <USER_TIER> supplied by user via --tier flag`. Skip the propose-and-confirm prompt.

   - If `USER_TIER` is absent (no `--tier` flag): PM MUST NOT silently default. PM MUST propose a tier using the chore keyword heuristic (see `pm.md` master keyword table — chore rows: tiny keywords = `comment, docstring, readme, rename, cleanup, dead code, formatting, lint`; audited keywords = `bump dep, dependency update, security patch, ci migration, settings.json, migration`; default = standard), then present this exact prompt shape:

     ```
     Based on the ask, I propose tier: <proposed>.
       tiny     — comment/doc/rename/cleanup with no functional risk
       standard — typical chore; normal workflow minus design and brainstorm
       audited  — dependency bump, security patch, migration, or settings change
     Press Enter to accept <proposed>, or type tiny|standard|audited to override.
     ```

     Read the user reply:
     - Blank / Enter → adopt `<proposed>`.
     - One of `tiny`, `standard`, `audited` → adopt that value (override).
     - Any other input → re-prompt once with: `Unrecognised input. Please type tiny, standard, or audited (or press Enter to accept <proposed>).` Then read again; if still unrecognised, default to `<proposed>`.

     PM MUST NOT block indefinitely. After at most one re-prompt the chosen tier is finalised.

   Write `- **tier**: <chosen_tier>` to STATUS.md (between `has-ui:` and `stage:` lines).
   Append to STATUS Notes: `<date> request — tier <chosen_tier> proposed (<proposed>) accepted by user` (or `overridden to <chosen_tier>` if the user typed an override).

8. Update STATUS: stage=request, check `[x] request`, set dates, write the final slug, confirm `work-type: chore`.

9. Report: generated slug, path created, tier chosen, PRD template used (`.specaffold/prd-templates/chore.md`), and next command (`/scaff:next <slug>`).
