# .claude/rules — contributor guide

Rules are **hard**, session-global guardrails injected into every Claude Code
session in this repo via the SessionStart hook
(`.claude/hooks/session-start.sh`). They are distinct from team-memory entries,
which are soft, per-role craft advisories consulted only at task start.

## Rules vs team-memory: layer contract

| Dimension | `.claude/rules/` | `.claude/team-memory/` |
|---|---|---|
| Enforcement | **hard** (must / should / avoid) | **soft** (craft advisory) |
| Load time | session start (via hook) | task start (agent reads index) |
| Scope | all sessions matching scope (`common` or `<lang>`) | one role (or `shared/`) |
| Source of truth | yes — rule file is authoritative | yes — memory file is authoritative |
| Duplication with prompts | forbidden after this feature lands (R14) | tolerated where context demands |
| Versioning | not versioned; edits apply per-session | not versioned; edits apply per-read |

## Rule frontmatter schema

Each rule file **must** begin with a YAML frontmatter block between `---` fences
containing exactly these five keys (in any order):

```yaml
---
name: <kebab-case slug, matches filename stem>
scope: common | bash | markdown | git | <lang>
severity: must | should | avoid
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Severity semantics

| Value | Meaning |
|---|---|
| `must` | Blocker if violated; agent must refuse or escalate. |
| `should` | Strong default; deviation requires explicit justification. |
| `avoid` | Known anti-pattern; agent must not produce this unless user overrides. |

## Body sections (required order)

1. `## Rule` — one-sentence imperative statement.
2. `## Why` — 1–3 sentences explaining the rationale.
3. `## How to apply` — checklist or template for the agent.
4. `## Example` — optional but strongly preferred; concrete code or prose.

## Directory layout

```
.claude/rules/
  README.md          ← this file
  index.md           ← flat list of all rules (one row per rule)
  common/            ← scope: common — applies every session
  bash/              ← scope: bash — loaded when bash/shell files are in scope
  markdown/          ← scope: markdown — loaded when .md files are in scope
  git/               ← scope: git — loaded when git files / operations are in scope
```

## Authoring checklist

Before committing a new rule file:

- [ ] Filename stem matches `name:` in frontmatter.
- [ ] `scope:` is one of the four established dirs (or a new dir created to match).
- [ ] `severity:` is exactly `must`, `should`, or `avoid`.
- [ ] All five frontmatter keys present.
- [ ] Body has `## Rule`, `## Why`, `## How to apply` in that order.
- [ ] Rule added to `index.md` as a new table row.
- [ ] Cross-role rule content removed from any agent core file that duplicated it (R14).
