---
name: Tech-doc addendum pattern — preserve provenance when mid-flight decision refinement is needed
description: When a mid-implement plan-gap forces a refinement to an existing tech D-id, append an `Addendum (YYYY-MM-DD)` block to the original D-id rather than rewriting the body; the original wording + the refinement together preserve the audit trail.
type: pattern
created: 2026-04-24
updated: 2026-04-24
---

## Rule

When a mid-flight discovery (plan-gap, validate finding, security retry, harvest leak) forces a change to an already-published tech D-id, **append an `Addendum (YYYY-MM-DD)` block** under the original D-id heading rather than rewriting the body. The original wording stays verbatim; the addendum holds the refinement, the trigger event, and the new authoritative wording. Future readers see both the original decision and the path to the current state in one place — no `git blame` archaeology required.

## Why

Three failure modes that the addendum pattern avoids:

1. **Silent overwrite loses the original rationale.** If T8 surfaced a flaw in tech-D7 and the architect just rewrites D7 in place, a future reader sees only the refined version and cannot tell which constraints were original vs which were learned during implement. Provenance is lost; future architects might unknowingly relitigate the same trade-off.
2. **Side-channel notes scatter the audit trail.** Putting the refinement only in STATUS Notes or a commit message means the tech doc itself is internally inconsistent (D7 says X, but actually X' was implemented). The single source of truth fragments across artefacts.
3. **A new D-id (D7.1, D7-prime, D8) signals new scope, not refinement.** Adding D8 to record "what D7 should have said" misleads downstream readers into thinking D8 is a separate decision; the relationship to D7 becomes unobvious.

The addendum block solves all three: original D-id wording stays as the historical record, the addendum carries the refinement with its trigger date and event, and there is exactly one D-id (D7) that owns this decision space.

## How to apply

1. **Don't edit the original D-id body.** Treat published D-id wording as immutable once tech is checked off in STATUS.
2. **Append a level-3 (`###`) addendum block** under the D-id, dated, with three lines of structure:
   - **Trigger:** what surfaced the need to refine (which task, which finding, which validate axis).
   - **Refinement:** the new authoritative wording, marked clearly so reviewers know which version supersedes which.
   - **Original retained because:** one line on why the original wording is kept verbatim (audit trail, future-rationale lookup, blame-free decision history).
3. **Reference the addendum from STATUS Notes** so the audit trail is searchable: `YYYY-MM-DD tech-addendum — D7 refined: <one-line summary> (see 04-tech.md §D7 Addendum)`.
4. **Mirror to PRD only if the addendum changes a value cited in an AC**; otherwise the addendum is internal to tech. (Cross-reference: `tpm/update-plan-must-mirror-to-prd-and-tech-when-touching-acceptance-values.md` — addendums that cross artefact boundaries follow the same mirror discipline.)
5. **Multiple addendums on the same D-id are fine** — date-stamp each. The chronological order tells the story of how the decision evolved under load.

## Example

`20260424-entry-type-split` 04-tech.md §D7 picked up an addendum during W1 after the harvest-leak discovery (see `architect/commands-harvest-scope-forbids-non-command-md.md`):

```markdown
### D7: PRD templates colocated with command files

Templates for `/scaff:request | /scaff:bug | /scaff:chore` PRD output
live under `.claude/commands/scaff/prd-templates/{feature,bug,chore}.md`
so the command file can load them by relative path resolution.

#### Addendum (2026-04-24)

**Trigger:** W1 T3 surfaced a plan-gap — Claude Code session-start hook
auto-harvests every `.md` under `.claude/commands/scaff/` (recursively)
into the slash-command namespace, exposing
`/scaff:prd-templates:{feature,bug,chore}` as user-invocable commands
that return raw template body.

**Refinement:** PRD templates relocate to `.specaffold/prd-templates/`
(outside the harvest scope). Command files reference templates by
absolute path: `TEMPLATE_PATH="$REPO_ROOT/.specaffold/prd-templates/<type>.md"`.
This refinement is the authoritative location for all subsequent
references; original wording (above) is the pre-discovery state.

**Original retained because:** the original wording records that
colocation was the architect's first instinct (one less repo-root
resolution at runtime); the addendum records why that instinct was
wrong on this platform. Future architects considering "tidy" colocation
of templates near consumers should read both.
```

The addendum was paired with a STATUS Notes line:
```
2026-04-24 tech-addendum — D7 refined: prd-templates relocate to .specaffold/prd-templates/ (harvest leak; see 04-tech.md §D7 Addendum)
```

This pattern is distinct from the architect's `scope-extension-minimal-diff` (that one is about enum extension during initial design); the addendum pattern is about evolving an already-checked-off decision under post-publication pressure. The two compose: a scope extension done via addendum (rather than a body rewrite) is the most conservative form of mid-flight refinement.
