# Agent Role Color Palette — Option B (Claude Code color names)

Palette source: the 8 predefined `color:` values supported by Claude Code subagent frontmatter.
These are the canonical color names; CSS hex values below are chosen for readability on
the flow-monitor's existing theme (dark sidebar #1E293B, light card #FFFFFF).

## Role-to-color mapping

| Role | Claude Code color name | Proposed CSS hex (monitor bg / fg / dot) | Rationale / notes |
|---|---|---|---|
| pm | `purple` | #F5F3FF / #5B21B6 / #7C3AED | Purple reads as "leadership / orchestration"; distinct from all QA and reviewer hues |
| architect | `cyan` | #CFFAFE / #155E75 / #0891B2 | Cyan = structural / technical; maximally distinct from purple, green, and orange |
| tpm | `yellow` | #FEF9C3 / #713F12 / #CA8A04 | Amber-yellow = planning / scheduling; warm but distinct from orange |
| developer | `green` | #DCFCE7 / #14532D / #16A34A | Green = shipping / building; the clearest "active work" hue |
| designer | `pink` | #FCE7F3 / #9D174D / #DB2777 | Pink = creative / visual craft; stands apart from all other roles |
| qa-analyst | `orange` | #FFF7ED / #7C2D12 / #EA580C | Orange = analysis / scrutiny; adjacent to red but visually distinct at this saturation |
| qa-tester | `blue` | #DBEAFE / #1E3A8A / #2563EB | Blue = verification / precision; contrasts with orange for the two QA roles |
| reviewer-security | `red` | #FEE2E2 / #991B1B / #DC2626 | All 3 reviewers share red; monitor adds axis sub-badge |
| reviewer-performance | `red` | #FEE2E2 / #991B1B / #DC2626 | Shared hue — sub-badge "perf" distinguishes from security/style |
| reviewer-style | `red` | #FEE2E2 / #991B1B / #DC2626 | Shared hue — sub-badge "style" distinguishes from security/perf |

## Reviewer axis handling

### Chosen split (recommended): all 3 reviewers share `red`

With 10 agents and only 8 supported color names, two roles must share a color.
The cleanest grouping is the three reviewer axes (security / performance / style) sharing
a single hue — `red` — because:

1. They are always co-labeled "Reviewer" in the CLI transcript and in the monitor pill.
   The shared hue reinforces this grouping semantically.
2. The monitor adds a small axis sub-badge next to the pill (e.g. `sec`, `perf`, `style`)
   so the specific axis is always readable regardless of the color.
3. No two reviewer agents are ever active simultaneously on the same feature, so there
   is no risk of visual collision within a single session card.

The 7 non-reviewer roles each get a unique color, with no hue duplicates among them.

### Alternative split: reviewer-security gets unique `red`, reviewer-performance + reviewer-style share `blue`

In this variant, security gets an exclusive `red` (danger/blocker semantics are strong
for security findings), while performance and style share `blue` with a sub-badge.
The trade-off: `blue` is already used by `qa-tester` in the recommended split.
To avoid the collision, qa-tester would need to move to a remaining free slot —
but with 8 colors fully allocated, that requires qa-analyst and qa-tester to share `orange`.
The result is two shared pairs (QA roles share orange; perf+style reviewers share blue),
which is harder to scan in the sidebar and the pill row than a single shared group.
This alternative is noted for completeness; the recommended single-group approach is preferred.

## Why these 8 names

Claude Code's `color:` frontmatter field accepts exactly eight predefined values:
`red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, and `cyan`.
Tying the monitor's palette to these names (rather than arbitrary hex values) means
the CLI transcript color-codes each sub-agent with the same hue the monitor displays —
so a developer reading a terminal session sees the same color association as the monitor
card. The CSS hex values in this file are the monitor's rendering of those canonical names;
they are chosen once and live in the monitor's palette map. The `color:` frontmatter
on each scaff agent is the single source of truth for the name; the hex is a rendering detail.

## Sidebar dot variants (on dark bg #1E293B)

The same dot color is used in both the pill and the sidebar. On the dark sidebar,
the dot-only treatment (no pill background) reads clearly because the dot hues
are all sufficiently saturated at the values chosen above.

| Role | Sidebar dot |
|---|---|
| pm | #7C3AED |
| architect | #0891B2 |
| tpm | #CA8A04 |
| developer | #16A34A |
| designer | #DB2777 |
| qa-analyst | #EA580C |
| qa-tester | #2563EB |
| reviewer-security | #DC2626 |
| reviewer-performance | #DC2626 |
| reviewer-style | #DC2626 |

## Design rationale

- Each of the 8 Claude Code color names maps to a hue band chosen to maximize
  perceptual distance between adjacent roles in the pill row and sidebar.
- The two QA roles (orange and blue) are visually opposite in hue, preventing
  confusion despite their similar label prefix.
- Purple (PM) and pink (Designer) are the closest in hue; they are never
  rendered adjacent in the same pill row or session card.
- All bg/fg pairs target at least 4.5:1 contrast against white (#FFFFFF) for WCAG AA.
- The reviewer red is identical across all three reviewer roles because the axis
  sub-badge (not the hue) is the primary discriminator.
