---
name: Lint-suppression sentinels belong in the lint tool, not in shipped artifacts
description: Embedding `_allow` keys, `<!-- scaff-lint:allow-* -->` comments, or other lint-suppression markers inside i18n bundles, READMEs, or other shipped files leaks the dev tool into product surfaces. Extend the lint tool's allowlist instead.
type: feedback
created: 2026-04-26
updated: 2026-04-26
source: 20260426-flow-monitor-graph-view
---

## Rule

Lint-suppression sentinels (e.g. `_allow` keys in JSON, `<!-- scaff-lint:allow-* -->`
HTML comments, `# noqa` markers in shipped configs) belong in the lint tool's
**exclusion list**, never embedded in the shipped artifact (i18n bundles,
READMEs, generated configs, public docs). The fix template is to extend the
lint tool's `is_out_of_scope` (or equivalent allowlist) with a narrow
path-suffix predicate scoped to exactly the file or directory under review —
never a broad globbed exemption.

## Why

Embedded sentinels ship as dead payload to end users, leak the lint tool's
existence into product surfaces, and pollute downstream parsers that don't
know to ignore them. They also encode a per-file decision in product code
rather than in tooling config, which makes audits ("what's exempt from this
check?") require grepping the entire repo instead of reading one config file.

**How to apply**: surfaced twice in one feature (`20260426-flow-monitor-graph-view`):

- W3 T12 BLOCK — i18n JSON `_allow` key with HTML-comment-shaped value
- W5 T18 BLOCK — README `<!-- scaff-lint:allow-cjk -->` comment

Both fixes followed the same template — extend `bin/scaff-lint` allowlist
with a narrow path-suffix match for the specific shipped file (e.g.
`flow-monitor/src/i18n/*.json`, `flow-monitor/README.md`). Rule of thumb at
task time: if you find yourself adding a marker the lint tool will recognise,
the marker should live in the lint tool's source, not in the artifact being
linted.

## Example

```python
# bin/scaff-lint — is_out_of_scope predicate
def is_out_of_scope(norm: str) -> bool:
    # i18n bundles legitimately contain CJK translation values
    if norm.endswith('.json') and 'flow-monitor/src/i18n/' in norm:
        return True
    # README documents the language-toggle smoke check (legitimate CJK label)
    if norm.endswith('flow-monitor/README.md'):
        return True
    return False
```

The exclusion is narrow (one file or one directory's `.json`), not a broad
`*.md` or `*.json` blanket.
