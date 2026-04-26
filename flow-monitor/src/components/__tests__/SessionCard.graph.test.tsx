/**
 * SessionCard.graph.test.tsx — AC18 chrome-preservation test.
 *
 * AC18: The six SessionCard chrome elements defined by the AC7.a contract remain
 * present and unchanged after the graph view was mounted (T10):
 *   1. slug
 *   2. StagePill
 *   3. relative-time element
 *   4. IdleBadge (or Active badge)
 *   5. note excerpt
 *   6. hover actions — EXACTLY "Open in Finder" + "Copy path" (no third action)
 *
 * Also asserts that ActionStrip continues to mount ONLY on stalled cards.
 *
 * Mocks declared before imports per vitest hoisting rules.
 */

import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "btn.openInFinder": "Open in Finder",
        "btn.copyPath": "Copy path",
        "stage.implement": "implement",
        "stage.plan": "plan",
        "idle.stale": "Stale",
        "idle.none": "none",
        "idle.stalled": "Stalled",
        "card.active": "Active",
        "action.advance_to.gap-check": "Advance to gap-check",
        "action.message": "Message / Choice",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(undefined),
}));

// Mock artifactStore so SessionGraph and SessionCard's useTaskProgress don't
// attempt real IPC (they are rendered as part of SessionCard).
vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockResolvedValue(() => {}),
}));

vi.mock("../../stores/artifactStore", () => ({
  useArtifactChanges: vi.fn().mockReturnValue(new Map()),
  useTaskProgress: vi.fn().mockReturnValue({ tasks_done: 0, tasks_total: 0 }),
  useWatcherStatus: vi.fn().mockReturnValue({ state: "running" }),
}));

// ---------------------------------------------------------------------------
// Imports — after mocks.
// ---------------------------------------------------------------------------
import { SessionCard, type SessionCardProps } from "../SessionCard";
import type { SessionState } from "../../stores/sessionStore";
import type { InvokeStore } from "../../stores/invokeStore";

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const BASE_PROPS: SessionCardProps = {
  slug: "graph-test-feature",
  stage: "implement",
  idleState: "none",
  lastUpdatedMs: Date.now() - 3 * 60 * 1000,
  noteExcerpt: "Note excerpt for the graph view test — sixty characters",
  repoPath: "/Users/alice/projects/graph-test-repo",
};

const STALLED_SESSION: SessionState = {
  slug: "graph-test-feature",
  stage: "implement",
  idleState: "stalled",
  lastUpdatedMs: Date.now() - 60 * 60 * 1000,
  noteExcerpt: "Stalled note",
  repoPath: "/Users/alice/projects/graph-test-repo",
  repoId: "graph-test-repo",
};

function makeInvokeStore(): InvokeStore {
  return {
    inFlight: new Set(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: vi.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Tests — AC18
// ---------------------------------------------------------------------------

describe("SessionCard.graph — AC18: six chrome elements remain present", () => {
  it("1. slug is visible", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(screen.getByText("graph-test-feature")).toBeTruthy();
  });

  it("2. StagePill is rendered", () => {
    const { container } = render(<SessionCard {...BASE_PROPS} />);
    // StagePill renders a span with role="status"; multiple text nodes for
    // "implement" may exist (stage pill + SVG node label). Look for role="status".
    expect(container.querySelector("[role='status']")).not.toBeNull();
  });

  it("3. relative-time element is present", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(document.querySelector("[data-testid='relative-time']")).not.toBeNull();
  });

  it("4. idle badge / active badge is rendered", () => {
    render(<SessionCard {...BASE_PROPS} idleState="stale" />);
    expect(screen.getByText("Stale")).toBeTruthy();
  });

  it("5. note excerpt is visible", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(
      screen.getByText("Note excerpt for the graph view test — sixty characters"),
    ).toBeTruthy();
  });

  it("6a. exactly 2 hover-action buttons: Open in Finder + Copy path", () => {
    render(<SessionCard {...BASE_PROPS} />);
    const buttons = screen.getAllByRole("button", {
      name: /open in finder|copy path/i,
    });
    expect(buttons).toHaveLength(2);
  });

  it("6b. no third hover action is present (B2 boundary)", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(
      screen.queryByRole("button", {
        name: /send instruction|advance stage|edit/i,
      }),
    ).toBeNull();
  });

  it("all six chrome elements are present simultaneously (omnibus AC18)", () => {
    render(<SessionCard {...BASE_PROPS} idleState="stale" />);
    // 1. slug
    expect(screen.getByText("graph-test-feature")).toBeTruthy();
    // 2. stage pill (role=status)
    expect(document.querySelector("[role='status']")).not.toBeNull();
    // 3. relative time
    expect(document.querySelector("[data-testid='relative-time']")).not.toBeNull();
    // 4. idle badge
    expect(screen.getByText("Stale")).toBeTruthy();
    // 5. note excerpt
    expect(
      screen.getByText("Note excerpt for the graph view test — sixty characters"),
    ).toBeTruthy();
    // 6. exactly 2 hover buttons
    const buttons = screen.getAllByRole("button", {
      name: /open in finder|copy path/i,
    });
    expect(buttons).toHaveLength(2);
  });

  it("ActionStrip mounts only when idleState is stalled (guard)", () => {
    const invokeStore = makeInvokeStore();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="stalled"
        session={STALLED_SESSION}
        invokeStore={invokeStore}
      />,
    );
    expect(screen.getByRole("button", { name: /advance to gap-check/i })).toBeTruthy();
  });

  it("ActionStrip does NOT mount when idleState is none", () => {
    render(<SessionCard {...BASE_PROPS} idleState="none" />);
    expect(
      screen.queryByRole("button", { name: /advance to/i }),
    ).toBeNull();
  });
});
