---
description: PM intakes a new feature. Usage: /scaff:request "<one-line ask>" [--tier <tiny|standard|audited>] [slug]
---

<!-- preflight: required -->
# Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
  _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
  SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
  unset _scaff_src_link
fi
[ -d "${SCAFF_SRC:-}" ] || { printf '%s\n' 'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo' >&2; exit 65; }
Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

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
   - If user did not supply one: derive a 2–5 word kebab-case slug capturing the essence (lowercase, hyphens, alphanumeric only, ≤30 chars body). Examples: "unify-auth-middleware", "dark-mode-toggle", "retry-flaky-upload".
   - Always prepend today's date in `YYYYMMDD` form → final slug = `YYYYMMDD-<body>`.
   - If `.specaffold/features/<slug>/` already exists, append `-<HHMM>` to disambiguate.

3. Copy `.specaffold/features/_template/` to `.specaffold/features/<slug>/`. (Template already sets `work-type: feature` per R13; this line is here so future reviewers can grep the command for the work-type setter.)

4. Invoke the **scaff-pm** subagent to fill `00-request.md` and set `has-ui` in STATUS. PM will probe for missing context (why-now, success criteria, out-of-scope, has-ui).

4a. **Propose-and-confirm tier** (runs AFTER the has-ui probe from step 4, BEFORE slug is finalised in step 5):

   - If `USER_TIER` is set (user passed `--tier`): adopt it directly. Write `tier: <USER_TIER>` to STATUS. Append to STATUS Notes: `<date> request — tier <USER_TIER> supplied by user via --tier flag`. Skip the propose-and-confirm prompt.

   - If `USER_TIER` is absent (no `--tier` flag): PM MUST NOT silently default. PM MUST propose a tier using the heuristic from `pm.md` (keyword scan + scope signals from probe answers), then present this exact prompt shape to the user:

     ```
     Based on the ask, I propose tier: <proposed>.
       tiny     — single-file or copy-only change; no review required
       standard — typical feature; full workflow minus brainstorm
       audited  — security-sensitive, auth, secrets, payment, or breaking change
     Press Enter to accept <proposed>, or type tiny|standard|audited to override.
     ```

     Read the user reply:
     - Blank / Enter → adopt `<proposed>`.
     - One of `tiny`, `standard`, `audited` → adopt that value (override).
     - Any other input → re-prompt once with: `Unrecognised input. Please type tiny, standard, or audited (or press Enter to accept <proposed>).` Then read again; if still unrecognised, default to `<proposed>`.

     PM MUST NOT block indefinitely. After at most one re-prompt the chosen tier is finalised.

   Write `- **tier**: <chosen_tier>` to STATUS.md (between `has-ui:` and `stage:` lines).
   Append to STATUS Notes: `<date> request — tier <chosen_tier> proposed (<proposed>) accepted by user` (or `overridden to <chosen_tier>` if the user typed an override).

5. Update STATUS: stage=request, check `[x] request`, set dates, write the final slug.

6. Report: generated slug, path created, has-ui value, tier chosen, and next command (`/scaff:next <slug>`).
