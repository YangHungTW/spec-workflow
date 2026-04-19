/**
 * T39 — WCAG AA contrast assertion for AC15.f
 *
 * Verifies that every theme token pair meets WCAG AA minimum contrast ratios:
 *   - Body text on page background: >= 4.5:1 (AA normal text)
 *   - Stage pill label on pill background: >= 4.5:1
 *     (Pills are small text / normal text size; using the stricter 4.5:1
 *      rather than the UI-component floor of 3:1 to match token pairs
 *      sourced from 02-design/notes.md "Theming" table.)
 *   - Idle badge label on badge background: >= 4.5:1
 *
 * Authoritative token pairings sourced from 02-design/notes.md "Theming"
 * table. Token values are inlined from theme.css so the test is
 * self-contained and does not require a DOM / CSS parser.
 *
 * Both light (default) and dark (html.dark) themes are asserted.
 * All 8 stage pills × 2 themes + 1 body pair × 2 themes + 3 badge states
 * × 2 themes = 26 assertions total.
 */
import { describe, it, expect } from "vitest";

// ── WCAG relative luminance helpers ──────────────────────────────────────────

/**
 * Convert an 8-bit sRGB channel value (0–255) to linear light.
 * Formula: IEC 61966-2-1 (sRGB).
 */
function toLinear(c: number): number {
  const sRGB = c / 255;
  return sRGB <= 0.04045 ? sRGB / 12.92 : ((sRGB + 0.055) / 1.055) ** 2.4;
}

/**
 * Compute WCAG 2.1 relative luminance for a 6-digit hex colour (e.g. "#1E293B").
 * Returns a value in [0, 1].
 */
function relativeLuminance(hex: string): number {
  const h = hex.replace("#", "");
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

/**
 * Compute WCAG 2.1 contrast ratio between two hex colours.
 * The ratio is always >= 1 (lighter / darker).
 */
export function contrastRatio(fg: string, bg: string): number {
  const l1 = relativeLuminance(fg);
  const l2 = relativeLuminance(bg);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

// ── Token pairs inlined from theme.css ───────────────────────────────────────
// Source: flow-monitor/src/styles/theme.css
// Authoritative pairing table: 02-design/notes.md "Theming" section.

interface TokenPair {
  name: string;
  fg: string;
  bg: string;
}

const LIGHT_PAIRS: TokenPair[] = [
  // Body text on page background (AA normal text: >= 4.5:1)
  { name: "body text on page-bg (light)", fg: "#1E293B", bg: "#F1F5F9" },

  // Stage pill label on pill background (light)
  { name: "pill-brainstorm (light)", fg: "#1D4ED8", bg: "#EFF6FF" },
  { name: "pill-design (light)",     fg: "#7C3AED", bg: "#F5F3FF" },
  { name: "pill-prd (light)",        fg: "#B45309", bg: "#FFFBEB" },
  { name: "pill-tech (light)",       fg: "#15803D", bg: "#F0FDF4" },
  { name: "pill-plan (light)",       fg: "#BE185D", bg: "#FFF0F6" },
  { name: "pill-implement (light)",  fg: "#166534", bg: "#F0FDF4" },
  { name: "pill-gap-check (light)",  fg: "#B91C1C", bg: "#FEF2F2" },
  { name: "pill-verify (light)",     fg: "#1E40AF", bg: "#EFF6FF" },

  // Idle badge label on badge background (light)
  { name: "badge-active (light)",    fg: "#166534", bg: "#DCFCE7" },
  { name: "badge-stale (light)",     fg: "#854D0E", bg: "#FEF9C3" },
  { name: "badge-stalled (light)",   fg: "#991B1B", bg: "#FEE2E2" },
];

const DARK_PAIRS: TokenPair[] = [
  // Body text on page background (AA normal text: >= 4.5:1)
  { name: "body text on page-bg (dark)", fg: "#E8F0EB", bg: "#0F1411" },

  // Stage pill label on pill background (dark)
  { name: "pill-brainstorm (dark)", fg: "#93C5FD", bg: "#1E2A3D" },
  { name: "pill-design (dark)",     fg: "#C4B5FD", bg: "#261D3A" },
  { name: "pill-prd (dark)",        fg: "#FCD34D", bg: "#2A230D" },
  { name: "pill-tech (dark)",       fg: "#6EE7B7", bg: "#122A1A" },
  { name: "pill-plan (dark)",       fg: "#F9A8D4", bg: "#2A1220" },
  { name: "pill-implement (dark)",  fg: "#86EFAC", bg: "#0D2114" },
  { name: "pill-gap-check (dark)",  fg: "#FCA5A5", bg: "#2A1212" },
  { name: "pill-verify (dark)",     fg: "#BAE6FD", bg: "#1A2540" },

  // Idle badge label on badge background (dark)
  { name: "badge-active (dark)",    fg: "#6EE7B7", bg: "#0F2C1A" },
  { name: "badge-stale (dark)",     fg: "#FCD34D", bg: "#2C220A" },
  { name: "badge-stalled (dark)",   fg: "#FCA5A5", bg: "#2A1010" },
];

// WCAG AA threshold for normal text (and pill/badge labels which are small text)
const AA_NORMAL_TEXT = 4.5;

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("contrastRatio helper", () => {
  it("returns 21:1 for black on white", () => {
    expect(contrastRatio("#000000", "#FFFFFF")).toBeCloseTo(21, 1);
  });

  it("returns 1:1 for identical colours", () => {
    expect(contrastRatio("#808080", "#808080")).toBeCloseTo(1, 5);
  });

  it("is symmetric — fg/bg order does not change the ratio", () => {
    const ab = contrastRatio("#1D4ED8", "#EFF6FF");
    const ba = contrastRatio("#EFF6FF", "#1D4ED8");
    expect(ab).toBeCloseTo(ba, 10);
  });
});

describe("WCAG AA contrast — light theme (>= 4.5:1 for all pairs)", () => {
  for (const { name, fg, bg } of LIGHT_PAIRS) {
    it(`${name}: ratio >= ${AA_NORMAL_TEXT}:1`, () => {
      const ratio = contrastRatio(fg, bg);
      expect(ratio).toBeGreaterThanOrEqual(AA_NORMAL_TEXT);
    });
  }
});

describe("WCAG AA contrast — dark theme (>= 4.5:1 for all pairs)", () => {
  for (const { name, fg, bg } of DARK_PAIRS) {
    it(`${name}: ratio >= ${AA_NORMAL_TEXT}:1`, () => {
      const ratio = contrastRatio(fg, bg);
      expect(ratio).toBeGreaterThanOrEqual(AA_NORMAL_TEXT);
    });
  }
});
