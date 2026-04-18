---
name: ac-must-verify-existing-baseline
role: pm
type: feedback
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Before writing an AC that asserts parity with a sibling (`match X and
Y`), verify X and Y are themselves aligned.

## Why

ACs that say "match existing X and Y" quietly assume X and Y are
consistent. If they're not, the AC silently scopes to one of them,
and "parity" becomes an illusion — the spec looks rigorous but is
actually under-specified. Gap-check may catch this (as N-notes), but
by then the PRD is locked and downstream stages have to carry the
ambiguity.

## How to apply

1. During PRD drafting, when an AC references cross-file parity, read
   the cited files first.
2. If the cited files diverge, EITHER narrow the AC to a specific
   source ("match reviewer-performance.md's shape") OR add a parent R
   to first align the cited files before asserting parity.
3. Never use vague group language ("match siblings", "align with the
   other reviewers") without anchoring to one concrete file.
4. When in doubt, cite a single file as the canonical shape reference
   in the AC; make "align everyone else" a separate R.

## Example

AC5 in feature `20260418-review-nits-cleanup` said `reviewer-style.md`
should match both `reviewer-security.md` AND `reviewer-performance.md`.
Gap-check N1 caught that reviewer-security.md was in prose shape while
reviewer-performance.md was in numbered-list shape — the three
reviewer agents were never aligned. AC5 thus scoped silently (and
correctly for the dominant sibling) to reviewer-performance.md, but
the PRD text did not say so. Fix: cite one file as canonical, or add
an R that aligns the cited files first.
