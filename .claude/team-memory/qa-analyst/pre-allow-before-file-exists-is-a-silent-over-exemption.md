## Rule

Allow-list entries must name files that exist at allow-list-commit time; if a file is planned but not yet present, defer the allow-list entry to the task that creates the file so the exemption is reviewed together with the file's content.

## Why

An allow-list entry is an exemption — a blanket grant that any content at that path passes the grep-negative assertion. If the path is empty/absent at allow-list authoring time, the exemption is a forward promise: future writes inherit blanket allow-listing silently, and the author of those writes may not realise their content is exempt from scrutiny.

In the rename-to-specaffold feature (2026-04-21), `.claude/carryover-allowlist.txt` line 6 pre-allowed `.specaffold/features/20260421-rename-to-specaffold/RETROSPECTIVE.md` before that file existed (RETROSPECTIVE.md is a post-archive artefact). Any legacy `specflow`/`spec-workflow` strings the retrospective later introduces will silently pass the grep assertion. Whoever writes the RETROSPECTIVE.md won't see a grep failure prompting review; the exemption is invisible.

## How to apply

1. Before committing an allow-list, `ls` every listed path; flag any that do not yet exist as a `should`-severity gap-analysis finding.
2. If a future-file genuinely needs blanket allow-listing (e.g. a template, a doc-authoring task), make that grant part of the task that creates the file — the exemption is then reviewed alongside the file's first content.
3. During gap analysis (qa-analyst axis), cross-check allow-list entries against tree state and flag ghost entries (listed path absent).
4. If a ghost entry is load-bearing for a future task, prefer a comment in the allow-list: `# RETROSPECTIVE.md forward-scoped; review entry together with file body at archive time`.
5. If gap-check finds the same forward-allow pattern for a second consecutive feature, escalate from `should` to `must`-severity. Require either (a) deletion of the ghost entry with the archive task re-adding a specific exemption at retrospective time, or (b) a comment in the allow-list tying the forward-allow to a specific upcoming commit.

## Example

The follow-up `20260421-rename-flow-monitor` feature (archived 2026-04-22) is a second consecutive occurrence: T14 + T16 added `.specaffold/features/20260421-rename-flow-monitor/**` to the carryover allow-list, which forward-allows `RETROSPECTIVE.md` in exactly the same shape as the predecessor. Analyst axis at validate logged this as an advisory finding (mirrors existing pattern). Per rule 5 above, the next occurrence should block at must-severity.
