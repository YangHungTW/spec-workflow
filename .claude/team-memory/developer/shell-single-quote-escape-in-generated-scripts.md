---
name: Shell single-quote escape in generated scripts — '\'' idiom
description: When embedding paths or command names inside single-quoted bash strings in generated scripts, apply the '\'' idiom to escape any literal single quotes; reviewer security axis flags unescaped user-data inside single-quoted strings as a must finding.
type: pattern
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Any Rust (or other) code that generates a bash script by embedding
user-supplied or path values inside single-quoted strings must apply
the `'\''` escape idiom to every `'` character in those values.

## Why

A bash single-quoted string `'...'` treats ALL characters as literals
except the single quote itself, which cannot appear inside the string
at all.  A repo path or command name containing `'` (e.g.
`/home/user/o'malley/repo`) will escape the opening quote and allow
injection of arbitrary shell syntax.  The `'\''` idiom closes the
quote, appends a literal `'` via `\'`, then reopens the quote — safe
on all POSIX shells.

## How to apply (Rust)

```rust
/// Escape for embedding inside a bash single-quoted string.
fn shell_single_quote_escape(s: &str) -> String {
    s.replace('\'', "'\\''")
}

// Then in the script template:
let repo_escaped = shell_single_quote_escape(&repo.to_string_lossy());
let cmd_escaped  = shell_single_quote_escape(cmd);
format!("cd '{repo_escaped}'\nspecflow '{cmd_escaped}'\n")
```

Apply to EVERY value that goes inside a `'…'` shell string, including:
- repo paths (can contain `'` in directory names on macOS/Linux)
- command names (may be user-supplied or untrusted)
- clipboard strings built for the user to paste in a terminal

## When security reviewer flags this

The security axis reviewer will flag unescaped user-data inside
single-quoted strings as a `must` finding (injection attack, rule 4
of `reviewer/security.md`).  This applies to both:
- `.command` script bodies written to disk
- clipboard strings built for terminal pasting

## Companion: allow-list check at dispatch() boundary

The `'\''` escape prevents injection even if a bad value slips
through, but you still need an allow-list check at the dispatch
boundary (defence in depth):

```rust
if !cmd_is_in_allow_list(cmd) {
    return Err(InvokeError::UnknownCommand);
}
```

Reviewer finding 3 blocks on missing allow-list enforcement even if
the caller already validates — the executor must be independently safe.

## Source

Feature `20260420-flow-monitor-control-plane`, T93 retry
(`invoke.rs` security BLOCK → 5 findings resolved):
- Finding 1: repo_str single-quote escape in build_script_content
- Finding 2: cmd single-quote escape in build_script_content
- Finding 3: allow-list check at top of dispatch()
- Finding 4: same escaping in dispatch_clipboard
- Finding 5: /dev/urandom entropy in gen_hex16
