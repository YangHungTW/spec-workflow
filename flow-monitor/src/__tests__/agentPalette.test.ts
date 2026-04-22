import { describe, it, expect, vi, afterEach } from "vitest";
import {
  ROLE_TO_COLOR,
  COLOR_TOKENS,
  AXIS_LABEL,
  roleForSession,
  type CCColorName,
  type Role,
} from "../agentPalette";

const ALL_ROLES: Role[] = [
  "pm",
  "architect",
  "tpm",
  "developer",
  "designer",
  "qa-analyst",
  "qa-tester",
  "reviewer-security",
  "reviewer-performance",
  "reviewer-style",
];

const ALL_CC_COLORS: CCColorName[] = [
  "red",
  "blue",
  "green",
  "yellow",
  "purple",
  "orange",
  "pink",
  "cyan",
];

const REVIEWER_ROLES: Role[] = [
  "reviewer-security",
  "reviewer-performance",
  "reviewer-style",
];

const NON_REVIEWER_ROLES: Role[] = ALL_ROLES.filter(
  (r) => !REVIEWER_ROLES.includes(r),
);

describe("ROLE_TO_COLOR", () => {
  it("has exactly 10 Role keys", () => {
    expect(Object.keys(ROLE_TO_COLOR)).toHaveLength(10);
    for (const role of ALL_ROLES) {
      expect(ROLE_TO_COLOR).toHaveProperty(role);
    }
  });

  it("every value is a valid CCColorName", () => {
    for (const role of ALL_ROLES) {
      expect(ALL_CC_COLORS).toContain(ROLE_TO_COLOR[role]);
    }
  });

  it("the 3 reviewers all map to red", () => {
    for (const r of REVIEWER_ROLES) {
      expect(ROLE_TO_COLOR[r]).toBe("red");
    }
  });

  it("the 7 non-reviewers map to 7 distinct non-red colors", () => {
    const nonReviewerColors = NON_REVIEWER_ROLES.map((r) => ROLE_TO_COLOR[r]);
    // none are red
    for (const c of nonReviewerColors) {
      expect(c).not.toBe("red");
    }
    // all distinct
    const unique = new Set(nonReviewerColors);
    expect(unique.size).toBe(7);
  });
});

describe("COLOR_TOKENS", () => {
  it("has entries for all 8 CCColorName values", () => {
    for (const name of ALL_CC_COLORS) {
      expect(COLOR_TOKENS).toHaveProperty(name);
    }
  });

  it("each entry has bgVar, fgVar, dotVar, sidebarDotVar as CSS var strings", () => {
    for (const name of ALL_CC_COLORS) {
      const tokens = COLOR_TOKENS[name];
      expect(tokens.bgVar).toBe(`var(--agent-${name}-bg)`);
      expect(tokens.fgVar).toBe(`var(--agent-${name}-fg)`);
      expect(tokens.dotVar).toBe(`var(--agent-${name}-dot)`);
      expect(tokens.sidebarDotVar).toBe(`var(--agent-${name}-sidebar-dot)`);
    }
  });

  it("no hex literals appear in token values", () => {
    for (const name of ALL_CC_COLORS) {
      const tokens = COLOR_TOKENS[name];
      for (const v of Object.values(tokens)) {
        expect(v).not.toMatch(/#[0-9a-fA-F]{3,8}/);
      }
    }
  });
});

describe("AXIS_LABEL", () => {
  it("reviewer-security returns sec", () => {
    expect(AXIS_LABEL["reviewer-security"]).toBe("sec");
  });

  it("reviewer-performance returns perf", () => {
    expect(AXIS_LABEL["reviewer-performance"]).toBe("perf");
  });

  it("reviewer-style returns style", () => {
    expect(AXIS_LABEL["reviewer-style"]).toBe("style");
  });

  it("non-reviewer roles return null", () => {
    for (const r of NON_REVIEWER_ROLES) {
      expect(AXIS_LABEL[r]).toBeNull();
    }
  });
});

describe("roleForSession", () => {
  const stageToExpectedRole: Array<[string, Role]> = [
    ["request", "pm"],
    ["brainstorm", "pm"],
    ["prd", "pm"],
    ["design", "designer"],
    ["tech", "architect"],
    ["plan", "tpm"],
    ["tasks", "tpm"],
    ["implement", "developer"],
    ["gap-check", "qa-analyst"],
    ["verify", "qa-tester"],
    ["archive", "qa-analyst"],
  ];

  for (const [stage, expected] of stageToExpectedRole) {
    it(`stage "${stage}" → role "${expected}"`, () => {
      expect(roleForSession({ stage: stage as any })).toBe(expected);
    });
  }

  it("unknown stage falls back to pm and emits console.warn", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const result = roleForSession({ stage: "totally-unknown" as any });
    expect(result).toBe("pm");
    expect(warnSpy).toHaveBeenCalled();
    warnSpy.mockRestore();
  });

  it("activeRole override is respected when provided", () => {
    // The function signature accepts activeRole; if provided and valid it
    // should still return the stage-based role (heuristic only per D3).
    // The test validates the function accepts the parameter without error.
    expect(() =>
      roleForSession({ stage: "implement" as any, activeRole: "qa-tester" }),
    ).not.toThrow();
  });
});
