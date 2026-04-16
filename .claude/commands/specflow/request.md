---
description: PM intakes a new feature. Usage: /specflow:request "<one-line ask>" [slug]
---

1. Parse `$ARGUMENTS`. Two forms:
   - `"<ask>"` — AI generates the slug from the ask (preferred)
   - `"<ask>" <slug>` — user supplies the slug body explicitly
2. **Generate slug**:
   - If user did not supply one: derive a 2–5 word kebab-case slug capturing the essence (lowercase, hyphens, alphanumeric only, ≤30 chars body). Examples: "unify-auth-middleware", "dark-mode-toggle", "retry-flaky-upload".
   - Always prepend today's date in `YYYYMMDD` form → final slug = `YYYYMMDD-<body>`.
   - If `.spec-workflow/features/<slug>/` already exists, append `-<HHMM>` to disambiguate.
3. Copy `.spec-workflow/features/_template/` to `.spec-workflow/features/<slug>/`.
4. Invoke the **specflow-pm** subagent to fill `00-request.md` and set `has-ui` in STATUS. PM will probe for missing context.
5. Update STATUS: stage=request, check `[x] request`, set dates, write the final slug.
6. Report: generated slug, path created, has-ui value, and next command (`/specflow:next <slug>` or `/specflow:brainstorm <slug>`).
