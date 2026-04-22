/**
 * Agent palette SSOT — single source of truth for role→colour mapping.
 *
 * Rules:
 * - No hex literals here. All hex lives in styles/agent-palette.css.
 * - Consumers reference colours via CSS custom-property names from COLOR_TOKENS.
 * - roleForSession() is a pure stage→role heuristic (D3); no IPC.
 */

import type { StageKey } from "./components/StagePill";

/** The 8 Claude Code colour names (R2, D1.1). */
export type CCColorName =
  | "red"
  | "blue"
  | "green"
  | "yellow"
  | "purple"
  | "orange"
  | "pink"
  | "cyan";

/** The 10 scaff agent roles (R1, D1.2). */
export type Role =
  | "pm"
  | "architect"
  | "tpm"
  | "developer"
  | "designer"
  | "qa-analyst"
  | "qa-tester"
  | "reviewer-security"
  | "reviewer-performance"
  | "reviewer-style";

/**
 * Authoritative role→colour map (D1.3).
 * Values copied verbatim from 02-design/notes.md §"Scaff agent files
 * that will receive `color:` frontmatter additions".
 */
export const ROLE_TO_COLOR: Record<Role, CCColorName> = {
  pm: "purple",
  architect: "cyan",
  tpm: "yellow",
  developer: "green",
  designer: "pink",
  "qa-analyst": "orange",
  "qa-tester": "blue",
  "reviewer-security": "red",
  "reviewer-performance": "red",
  "reviewer-style": "red",
};

/**
 * Maps each colour name to its 4 CSS custom-property names (no hex) (D1.4).
 * Consumers use `var(--agent-<name>-<slot>)` to resolve the actual hex
 * at runtime from agent-palette.css.
 */
export const COLOR_TOKENS: Record<
  CCColorName,
  { bgVar: string; fgVar: string; dotVar: string; sidebarDotVar: string }
> = {
  red: {
    bgVar: "var(--agent-red-bg)",
    fgVar: "var(--agent-red-fg)",
    dotVar: "var(--agent-red-dot)",
    sidebarDotVar: "var(--agent-red-sidebar-dot)",
  },
  blue: {
    bgVar: "var(--agent-blue-bg)",
    fgVar: "var(--agent-blue-fg)",
    dotVar: "var(--agent-blue-dot)",
    sidebarDotVar: "var(--agent-blue-sidebar-dot)",
  },
  green: {
    bgVar: "var(--agent-green-bg)",
    fgVar: "var(--agent-green-fg)",
    dotVar: "var(--agent-green-dot)",
    sidebarDotVar: "var(--agent-green-sidebar-dot)",
  },
  yellow: {
    bgVar: "var(--agent-yellow-bg)",
    fgVar: "var(--agent-yellow-fg)",
    dotVar: "var(--agent-yellow-dot)",
    sidebarDotVar: "var(--agent-yellow-sidebar-dot)",
  },
  purple: {
    bgVar: "var(--agent-purple-bg)",
    fgVar: "var(--agent-purple-fg)",
    dotVar: "var(--agent-purple-dot)",
    sidebarDotVar: "var(--agent-purple-sidebar-dot)",
  },
  orange: {
    bgVar: "var(--agent-orange-bg)",
    fgVar: "var(--agent-orange-fg)",
    dotVar: "var(--agent-orange-dot)",
    sidebarDotVar: "var(--agent-orange-sidebar-dot)",
  },
  pink: {
    bgVar: "var(--agent-pink-bg)",
    fgVar: "var(--agent-pink-fg)",
    dotVar: "var(--agent-pink-dot)",
    sidebarDotVar: "var(--agent-pink-sidebar-dot)",
  },
  cyan: {
    bgVar: "var(--agent-cyan-bg)",
    fgVar: "var(--agent-cyan-fg)",
    dotVar: "var(--agent-cyan-dot)",
    sidebarDotVar: "var(--agent-cyan-sidebar-dot)",
  },
};

/**
 * Axis sub-badge text per reviewer role (R7, R8, D1.5).
 * Non-reviewer roles return null; no badge rendered.
 */
export const AXIS_LABEL: Record<Role, "sec" | "perf" | "style" | null> = {
  pm: null,
  architect: null,
  tpm: null,
  developer: null,
  designer: null,
  "qa-analyst": null,
  "qa-tester": null,
  "reviewer-security": "sec",
  "reviewer-performance": "perf",
  "reviewer-style": "style",
};

/** Stage→role heuristic table (D3). */
const STAGE_TO_ROLE: Partial<Record<StageKey, Role>> = {
  request: "pm",
  brainstorm: "pm",
  prd: "pm",
  design: "designer",
  tech: "architect",
  plan: "tpm",
  tasks: "tpm",
  implement: "developer",
  "gap-check": "qa-analyst",
  verify: "qa-tester",
  archive: "qa-analyst",
};

/**
 * Resolve the default role for a session based on its current stage (D3).
 *
 * Reviewer roles are NOT produced by this heuristic — no single stage maps
 * to a reviewer. Unknown stages fall back to "pm" with a console.warn
 * (fail-loud, non-fatal — matches invokeStore.ts shape-guard posture).
 */
export function roleForSession(input: {
  stage: StageKey | string;
  activeRole?: Role | null;
}): Role {
  const role = STAGE_TO_ROLE[input.stage as StageKey];
  if (role !== undefined) {
    return role;
  }
  console.warn(
    `[agentPalette] roleForSession: unknown stage "${input.stage}", falling back to "pm"`,
  );
  return "pm";
}
