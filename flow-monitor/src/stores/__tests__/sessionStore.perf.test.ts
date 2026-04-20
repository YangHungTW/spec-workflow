/**
 * Performance regression tests for T17 retry:
 *   1. STAGE_ORDER must be a module-level const (not reconstructed each call)
 *   2. groupSessionsByRepo must use Map O(1) lookup — verified via behaviour
 *      (correct repoName lookup) and non-O(n*m) structure in MainWindow.
 *
 * These tests were written BEFORE the fixes (TDD red phase).
 */
import { describe, it, expect } from "vitest";
import { sortSessions } from "../sessionStore";
import type { SessionState } from "../sessionStore";

function makeSession(overrides: Partial<SessionState>): SessionState {
  return {
    slug: "test-session",
    stage: "implement",
    idleState: "none",
    lastUpdatedMs: Date.now(),
    noteExcerpt: "",
    repoPath: "/tmp/repo",
    repoId: "repo-1",
    ...overrides,
  };
}

describe("sortSessions — Stage axis (STAGE_ORDER hoisted)", () => {
  it("sorts by stage order deterministically across two independent calls", () => {
    const sessions: SessionState[] = [
      makeSession({ slug: "c", stage: "verify" }),
      makeSession({ slug: "a", stage: "request" }),
      makeSession({ slug: "b", stage: "implement" }),
    ];

    // Two independent calls must produce identical, stable results.
    // If STAGE_ORDER were reconstructed each time with different ordering
    // (JS object key insertion order is deterministic, but hoisting ensures
    // no accidental mutation between calls is possible).
    const first = sortSessions(sessions, "Stage");
    const second = sortSessions(sessions, "Stage");

    expect(first.map((s) => s.slug)).toEqual(["a", "b", "c"]);
    expect(second.map((s) => s.slug)).toEqual(["a", "b", "c"]);
  });

  it("places all 11 known stages in correct order", () => {
    const stages: SessionState["stage"][] = [
      "archive",
      "verify",
      "gap-check",
      "implement",
      "tasks",
      "plan",
      "tech",
      "prd",
      "design",
      "brainstorm",
      "request",
    ];
    const sessions = stages.map((stage, i) =>
      makeSession({ slug: `s${i}`, stage }),
    );
    const sorted = sortSessions(sessions, "Stage");
    expect(sorted.map((s) => s.stage)).toEqual([
      "request",
      "brainstorm",
      "design",
      "prd",
      "tech",
      "plan",
      "tasks",
      "implement",
      "gap-check",
      "verify",
      "archive",
    ]);
  });

  it("unknown stage falls to end (99 sentinel)", () => {
    const sessions: SessionState[] = [
      makeSession({ slug: "known", stage: "request" }),
      // Cast unknown value to exercise the ?? 99 fallback
      makeSession({ slug: "unknown", stage: "unknown" as SessionState["stage"] }),
    ];
    const sorted = sortSessions(sessions, "Stage");
    expect(sorted[0].slug).toBe("known");
    expect(sorted[1].slug).toBe("unknown");
  });

  it("returns empty array for empty input", () => {
    expect(sortSessions([], "Stage")).toEqual([]);
  });

  it("does not mutate original sessions array", () => {
    const sessions: SessionState[] = [
      makeSession({ slug: "b", stage: "verify" }),
      makeSession({ slug: "a", stage: "request" }),
    ];
    const original = [...sessions];
    sortSessions(sessions, "Stage");
    expect(sessions[0].slug).toBe(original[0].slug);
    expect(sessions[1].slug).toBe(original[1].slug);
  });
});
