# B2 CSS Class → B1 Token Reuse Map

This document is the reviewer's reference during W4 component implementation.
Every new B2 CSS class must resolve to an existing B1 token listed here — no
net-new `--(color|space|font|radius)-` custom property declarations are
permitted in B2 (enforced by T117 grep-assert in W6).

## Mapping table

| B2 CSS class / usage          | B1 token(s) reused                                      | Semantic rationale                                      |
|-------------------------------|---------------------------------------------------------|---------------------------------------------------------|
| ActionStrip primary button    | `--button-primary-bg`, `--button-primary-fg`            | Primary action affordance — same as B1 primary buttons  |
| ActionStrip secondary button  | `--button-secondary-bg`, `--button-secondary-fg`, `--button-secondary-border` (full `--button-secondary-*` family) | Secondary action affordance — matches B1 ghost-style buttons |
| Palette overlay background    | `--overlay-bg`                                          | Full-viewport scrim — reuses B1 modal/dialog overlay    |
| Stalled badge (red)           | `--color-status-stalled`                                | "Danger / blocked" semantic — exact B1 stalled-status   |
| WRITE pill (yellow)           | `--color-status-stale`                                  | "Warn" semantic — B1 stale-status shares the same warn hue |
| DESTROY pill (red)            | `--color-status-stalled`                                | "Danger" semantic — both stalled and destroy are danger  |
| Confirm modal backdrop        | `--overlay-bg`                                          | Same full-viewport scrim token as Palette overlay       |
| Audit panel background        | `--surface-subtle`                                      | Recessed surface — reuses B1 sidebar/panel background   |
| Preflight toast background    | `--surface-raised`                                      | Elevated surface — reuses B1 tooltip/card raised token  |

## Notes

- All tokens in the "B1 token(s) reused" column are defined in
  `flow-monitor/src/styles/theme.css` and are available in every component
  via the global CSS cascade — no per-component import required.
- The `--button-secondary-*` wildcard covers the full family
  (`-bg`, `-fg`, `-border`); use only those three sub-tokens; do not add
  new sub-tokens under this prefix.
- No new token is introduced by B2. If a W4 implementation needs a colour
  not covered by this table, escalate to TPM before authoring a new
  custom property.
