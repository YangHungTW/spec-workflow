---
name: Auto-classify argv by pattern cascade — URL → ticket-id → fallback description
description: When a CLI entry accepts a polymorphic positional argument (URL, ticket-id, or free-text description), classify with a deterministic pattern cascade — exact-prefix match first, then regex match, then fallback — never ask the user to disambiguate.
type: pattern
created: 2026-04-24
updated: 2026-04-24
---

## Rule

When a CLI or slash-command entry accepts a single positional argument that can take multiple forms (URL, ticket id, free-text description, file path, etc.), classify the argument via a **deterministic pattern cascade** at the entry point: most-specific pattern first, fall through to most-general last. Never ask the user to choose; the cascade IS the dispatch decision. The cascade order, the patterns, and the fallback branch must all be visible in one place — typically the entry-point command file.

## Why

`20260424-entry-type-split` introduced `/scaff:bug "<arg>"` accepting one of three forms:

- `https://github.com/foo/bar/issues/42` (URL)
- `PROJ-123` or `BUG-7` (ticket id)
- `users see 500 on /login when password contains $` (description)

The naive design was to add a `--type {url|ticket|description}` flag and require the user to pick. That approach loses the entire ergonomic benefit — the user already typed the form, having them retype the form's name is busywork. The pattern-cascade design auto-routes:

```bash
arg="$1"
case "$arg" in
  http://*|https://*) classification="url" ;;
  *)
    if expr "$arg" : '^[A-Z][A-Z]*-[0-9][0-9]*$' >/dev/null; then
      classification="ticket-id"
    else
      classification="description"
    fi
    ;;
esac
```

This is a reusable shape because the same cascade structure applies any time argv polymorphism enters a CLI: a slug-vs-ask in `/scaff:request`, a path-vs-name in a file-locator, a URL-vs-keyword in a search command. The pattern is general; the patterns inside the cascade are domain-specific.

Three properties make the cascade safe:

1. **Most-specific first**: a URL also looks like a free-text description, so URL must be tested before description. A ticket-id like `PROJ-123` doesn't look like a URL but DOES match the description fallback, so ticket-id must be tested before description.
2. **Closed-set or explicit fallback**: every input must land in exactly one branch. The fallback (description) is the catch-all; if a future variant appears, it lands in the fallback until a new branch is added — never silently fails.
3. **No interactive disambiguation**: the entry point cannot prompt the user. Once classification is locked, the rest of the command flow runs against a known type.

## How to apply

1. **Order branches by specificity, not by frequency.** Even if 90% of inputs are descriptions, `description` MUST be the last branch because both URL and ticket-id forms also satisfy free-text predicates. Specificity > frequency.
2. **Use `case` for prefix/glob matches, `expr` (POSIX) or `case` for regex-shaped matches.** Avoid `[[ =~ ]]` for portability (bash 3.2 / BSD userland; see `.claude/rules/bash/bash-32-portability.md`). For ticket-id-style patterns, `expr "$arg" : '^[A-Z][A-Z]*-[0-9][0-9]*$' >/dev/null` is portable; `[[ "$arg" =~ ^[A-Z]+-[0-9]+$ ]]` is not.
3. **Echo the classification result before dispatching.** The entry should `printf 'auto-classified: %s\n' "$classification"` so the user can see what the cascade picked. Silent classification surprises the user when their input was on the boundary.
4. **Document the cascade in the command's frontmatter or top comment.** Future maintainers should not have to reverse-engineer the order. List branches in cascade order with one-line descriptions.
5. **Fallback branch must be the most general, never an error.** If the cascade can't classify, fall through to the most-general handler (description / free-text / generic). An entry-point that errors on "unclassifiable" input forces the user back to the disambiguation flag — defeating the cascade's purpose.
6. **Validate AFTER classification, not before.** Once `classification=url`, validate the URL shape; once `classification=ticket-id`, validate the ticket-id shape. Pre-classification validation conflates the two phases.

## Example

`/scaff:bug` entry-point cascade (commit `acdafbb` and successors):

```bash
# .claude/commands/scaff/bug.md — argv classifier
# Cascade order (most-specific → fallback):
#   1. url         — http(s):// prefix
#   2. ticket-id   — ^[A-Z]+-[0-9]+$ (e.g. PROJ-123, BUG-7)
#   3. description — fallback for any other free-text input

arg="$1"
case "$arg" in
  http://*|https://*)
    classification="url"
    ;;
  *)
    if expr "$arg" : '^[A-Z][A-Z]*-[0-9][0-9]*$' >/dev/null; then
      classification="ticket-id"
    else
      classification="description"
    fi
    ;;
esac

printf 'auto-classified: %s\n' "$classification" >&2

# Dispatch on classification (mutation lives below; cascade above is pure)
case "$classification" in
  url)         pm_probe_url "$arg" ;;
  ticket-id)   pm_probe_ticket "$arg" ;;
  description) pm_probe_freeform "$arg" ;;
esac
```

This reuses the `classify-before-mutate` discipline from `.claude/rules/common/classify-before-mutate.md`: the cascade is a pure classifier, the dispatch is a separate phase. The cascade can be unit-tested as a pure function of input → classification string.

For a CLI variant, the same cascade fits an `argv[1]`-as-locator pattern:

```bash
# fictional /scaff:locate <arg> example
case "$arg" in
  /*) kind="absolute-path" ;;
  ./*) kind="relative-path" ;;
  http*://*) kind="url" ;;
  *) if [ -f "$arg" ]; then kind="bare-filename"; else kind="search-keyword"; fi ;;
esac
```

The two examples differ in their patterns but share the cascade structure: most-specific tests first, regex/conditional tests next, free-text fallback last, classification echoed before dispatch.

Source: `20260424-entry-type-split` D1 (PRD §4 decision: auto-classify rather than `--type` flag), implemented in `.claude/commands/scaff/bug.md` (commits `acdafbb`, `9cff64d`). Cross-reference for slug guards layered on top: `.claude/commands/scaff/{bug,chore}.md` lines that reject `..` traversal and forbidden chars after classification but before path use.
