---
description: PM intakes a bug report. Usage: /scaff:bug "<url|ticket-id|description>" [--tier <tiny|standard|audited>] [slug]
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Parse `$ARGUMENTS`. Supported forms:
   - `"<arg>"` — AI generates the slug from the arg (preferred)
   - `"<arg>" <slug>` — user supplies the slug body explicitly
   - `"<arg>" --tier <tiny|standard|audited>` — user supplies explicit tier (skips propose-and-confirm)
   - `"<arg>" --tier <tiny|standard|audited> <slug>` — explicit tier and slug

   Flag parsing rules (bash 3.2 portable — no `getopts`):
   - Scan `$ARGUMENTS` tokens for `--tier`. If found, the next token is the tier value.
   - Validate the tier value is one of `tiny`, `standard`, or `audited`. If invalid, emit an error and stop.
   - Remaining non-flag tokens are: `<arg>` (first), `<slug>` (second, optional).
   - Store: `USER_TIER=<value>` (explicit, skip propose-and-confirm) or `USER_TIER=""` (absent, must run propose-and-confirm).

2. **Classify `<arg>`** (per R14 / D1 — three branches):

   ```bash
   case "$arg" in
     http://*|https://*) type=url; value="$arg" ;;
     *)
       if expr "$arg" : '^[A-Z][A-Z]*-[0-9][0-9]*$' >/dev/null 2>&1; then
         type=ticket-id; value="$arg"
       else
         type=description; value="$arg"
       fi
       ;;
   esac
   ```

   - `url` — a fully-qualified HTTP/HTTPS link to a bug tracker, issue, or reproduction
   - `ticket-id` — a Jira/Linear-style identifier matching `[A-Z]+-[0-9]+` (e.g. `BUG-42`, `PROJ-1234`)
   - `description` — free-text description of the bug (all other input)

   Emit `type: <type>` and `value: <verbatim arg>` into the Source section of `00-request.md` (step 6).

3. **Generate / validate slug**:
   - If user did not supply one: derive a 2–5 word kebab-case slug capturing the essence of the bug (lowercase, hyphens, alphanumeric only, ≤30 chars body). Examples: `null-ptr-on-login`, `race-condition-upload`, `wrong-tax-rounding`.
   - Always prepend today's date and the `-fix-` infix → final slug = `YYYYMMDD-fix-<body>`.
   - If `.specaffold/features/<slug>/` already exists, append `-<HHMM>` to disambiguate.
   - If user supplies an explicit slug: reject with a usage error and `exit 2` if the slug does **not** contain the literal substring `-fix-`. Do not silently correct the slug — per `common/no-force-on-user-paths.md`, non-destructive behaviour is the default.

     ```
     ERROR: user-supplied slug must contain '-fix-' (got: <slug>)
     Usage: /scaff:bug "<arg>" [--tier tiny|standard|audited] [YYYYMMDD-fix-<body>]
     ```

   - **Character allowlist** — apply to BOTH user-supplied and auto-derived slugs BEFORE any filesystem operation:

     ```bash
     # Reject if slug contains any character outside [a-z0-9-]
     case "$slug" in
       *[!a-z0-9-]*)
         printf 'ERROR: slug contains forbidden characters; allowed: lowercase alphanumeric + hyphens only\n  slug: %s\n' "$slug" >&2
         exit 2 ;;
     esac

     # Belt-and-suspenders: reject .. explicitly (path traversal)
     # (the allowlist above already catches '.', but make intent clear)
     case "$slug" in
       *..*) 
         printf 'ERROR: slug contains .. (path traversal)\n  slug: %s\n' "$slug" >&2
         exit 2 ;;
     esac
     ```

4. Copy `.specaffold/features/_template/` to `.specaffold/features/<slug>/`.

5. **Set `work-type: bug`** in STATUS:

   Use the same atomic write discipline as `scaff-tier:set_tier` — cp→tmp→sed→mv — to overwrite the `work-type:` field that the template seeds as `feature`:

   ```bash
   cp .specaffold/features/<slug>/STATUS.md .specaffold/features/<slug>/STATUS.md.bak
   sed 's/^work-type: feature$/work-type: bug/' \
     .specaffold/features/<slug>/STATUS.md > .specaffold/features/<slug>/STATUS.md.tmp
   mv .specaffold/features/<slug>/STATUS.md.tmp .specaffold/features/<slug>/STATUS.md
   ```

   This explicit `work-type: bug` field enables the PM subagent dispatch (D6): when PM reads STATUS it enters the bug-probe branch rather than the feature-probe branch.

6. Write Source section into `00-request.md`:

   ```
   ## Source
   type: <type>
   value: <verbatim arg>
   ```

   `<type>` is one of `url`, `ticket-id`, or `description` (from step 2).
   `<value>` is the unmodified original argument string.

7. Invoke the **scaff-pm** subagent. PM reads `work-type: bug` from STATUS and enters the bug-probe branch (D6), probing for:
   - Steps to reproduce
   - Expected vs actual behaviour
   - Affected version / environment
   - Severity / business impact
   - Known workaround

8. PM writes `03-prd.md` using the `.specaffold/prd-templates/bug.md` template (per R8.1).

9. **Propose-and-confirm tier** (runs AFTER the bug-probe from step 7, BEFORE slug is finalised in step 10):

   - If `USER_TIER` is set (user passed `--tier`): adopt it directly. Write `tier: <USER_TIER>` to STATUS. Append to STATUS Notes: `<date> request — tier <USER_TIER> supplied by user via --tier flag`. Skip the propose-and-confirm prompt.

   - If `USER_TIER` is absent (no `--tier` flag): PM MUST NOT silently default. PM MUST propose a tier using the heuristic from `pm.md` (keyword scan + scope signals from probe answers), then present this exact prompt shape to the user:

     ```
     Based on the bug report, I propose tier: <proposed>.
       tiny     — single-line fix or config change; no review required
       standard — typical bug fix; full workflow minus brainstorm
       audited  — security-sensitive, auth, secrets, payment, or data-loss bug
     Press Enter to accept <proposed>, or type tiny|standard|audited to override.
     ```

     Read the user reply:
     - Blank / Enter → adopt `<proposed>`.
     - One of `tiny`, `standard`, `audited` → adopt that value (override).
     - Any other input → re-prompt once with: `Unrecognised input. Please type tiny, standard, or audited (or press Enter to accept <proposed>).` Then read again; if still unrecognised, default to `<proposed>`.

     PM MUST NOT block indefinitely. After at most one re-prompt the chosen tier is finalised.

   Write `- **tier**: <chosen_tier>` to STATUS.md (between `has-ui:` and `stage:` lines).
   Append to STATUS Notes: `<date> request — tier <chosen_tier> proposed (<proposed>) accepted by user` (or `overridden to <chosen_tier>` if the user typed an override).

10. Update STATUS: stage=request, check `[x] request`, set dates, write the final slug, confirm `work-type: bug`.

11. Report: generated slug, path created, arg type (`url` / `ticket-id` / `description`), tier chosen, and next command (`/scaff:next <slug>`).
