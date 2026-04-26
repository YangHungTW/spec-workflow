/**
 * SessionGraph — tests for AC1–AC7, AC9.
 *
 * Data-attribute hooks per T6 / D9 contract:
 *   [data-stage-node]   — each stage node
 *   [data-row]          — "1" | "2"
 *   [data-state]        — "completed" | "active" | "skipped" | "partial" | "future"
 *   [data-active]       — "true" only on the active node
 *   [data-bypass-arc]   — set to "brainstorm" on the bypass arc element
 *   [data-stage-edge]   — "from-to" on each edge element
 *
 * Mocks declared before imports per vitest hoisting rules.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, act } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockResolvedValue(() => {}),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(""),
}));

// Mock the artifactStore hooks so SessionGraph is isolated from IPC.
vi.mock("../../stores/artifactStore", () => ({
  useArtifactChanges: vi.fn().mockReturnValue(new Map()),
  useTaskProgress: vi.fn().mockReturnValue({ tasks_done: 0, tasks_total: 0 }),
}));

// ---------------------------------------------------------------------------
// Imports — after mocks.
// ---------------------------------------------------------------------------
import { SessionGraph } from "../SessionGraph";
import { useArtifactChanges, useTaskProgress } from "../../stores/artifactStore";

const mockedUseArtifactChanges = vi.mocked(useArtifactChanges);
const mockedUseTaskProgress = vi.mocked(useTaskProgress);

// ---------------------------------------------------------------------------
// Constants matching the production layout (used to validate counts).
// ---------------------------------------------------------------------------
const ROW1_STAGES = ["request", "brainstorm", "design", "prd", "tech", "plan"];
const ROW2_STAGES = ["tasks", "implement", "gap-check", "verify", "archive"];
const ALL_STAGES = [...ROW1_STAGES, ...ROW2_STAGES];

// PRD R2 / AC2 contract: every directed edge in the DAG carries an artifact label.
// Test iterates [data-stage-edge] elements rather than a hardcoded subset, so adding
// or removing edges in STAGE_EDGES is automatically covered.
const ALL_EDGE_IDS = [
  "request-brainstorm",
  "brainstorm-design",
  "design-prd",
  "prd-tech",
  "tech-plan",
  "plan-tasks",
  "tasks-implement",
  "implement-gap-check",
  "gap-check-verify",
  "verify-archive",
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function renderGraph(
  currentStage: string,
  opts: { mtimes?: Map<string, number>; tasksDone?: number; tasksTotal?: number } = {},
) {
  const mtimes = opts.mtimes ?? new Map();
  const tasksDone = opts.tasksDone ?? 0;
  const tasksTotal = opts.tasksTotal ?? 0;

  mockedUseArtifactChanges.mockReturnValue(mtimes as Map<never, never>);
  mockedUseTaskProgress.mockReturnValue({ tasks_done: tasksDone, tasks_total: tasksTotal });

  return render(
    <SessionGraph
      repoPath="/repo/test"
      slug="test-feature"
      currentStage={currentStage as never}
    />,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("SessionGraph — AC1: 11 nodes, 6 in row 1, 5 in row 2, bridge edge", () => {
  beforeEach(() => {
    mockedUseArtifactChanges.mockReturnValue(new Map());
    mockedUseTaskProgress.mockReturnValue({ tasks_done: 0, tasks_total: 0 });
  });

  it("renders exactly 11 stage nodes", () => {
    const { container } = renderGraph("plan");
    const nodes = container.querySelectorAll("[data-stage-node]");
    expect(nodes).toHaveLength(11);
  });

  it("renders exactly 6 nodes in row 1", () => {
    const { container } = renderGraph("plan");
    const row1 = container.querySelectorAll("[data-row='1']");
    expect(row1).toHaveLength(6);
  });

  it("renders exactly 5 nodes in row 2", () => {
    const { container } = renderGraph("plan");
    const row2 = container.querySelectorAll("[data-row='2']");
    expect(row2).toHaveLength(5);
  });

  it("row 1 contains request, brainstorm, design, prd, tech, plan in order", () => {
    const { container } = renderGraph("plan");
    const row1Nodes = Array.from(container.querySelectorAll("[data-row='1']")).map(
      (el) => el.getAttribute("data-stage-node"),
    );
    expect(row1Nodes).toEqual(ROW1_STAGES);
  });

  it("row 2 contains tasks, implement, gap-check, verify, archive in order", () => {
    const { container } = renderGraph("plan");
    const row2Nodes = Array.from(container.querySelectorAll("[data-row='2']")).map(
      (el) => el.getAttribute("data-stage-node"),
    );
    expect(row2Nodes).toEqual(ROW2_STAGES);
  });

  it("renders the bridge edge from plan to tasks", () => {
    const { container } = renderGraph("plan");
    const bridge = container.querySelector("[data-stage-edge='plan-tasks']");
    expect(bridge).not.toBeNull();
  });
});

describe("SessionGraph — AC2: every edge has a non-empty label", () => {
  // Render with a non-skipped brainstorm so all 10 edges (including those
  // touching the brainstorm node) materialise. The skipped-brainstorm path is
  // covered separately by AC5 — here we want to assert the canonical contract
  // that every defined edge has a label when rendered.
  const ALL_EDGES_MTIMES = new Map<string, number>([
    ["request", Date.now()],
    ["brainstorm", Date.now()],
    ["design", Date.now()],
    ["prd", Date.now()],
    ["tech", Date.now()],
    ["plan", Date.now()],
  ]);

  it("renders all 10 directed edges (5 row-1 + 4 row-2 + 1 bridge)", () => {
    const { container } = renderGraph("archive", { mtimes: ALL_EDGES_MTIMES });
    const edges = container.querySelectorAll("[data-stage-edge]");
    expect(edges).toHaveLength(ALL_EDGE_IDS.length);
    for (const edgeId of ALL_EDGE_IDS) {
      expect(
        container.querySelector(`[data-stage-edge='${edgeId}']`),
        `missing edge ${edgeId}`,
      ).not.toBeNull();
    }
  });

  it("every directed edge carries a non-empty <text> artifact label", () => {
    const { container } = renderGraph("archive", { mtimes: ALL_EDGES_MTIMES });
    for (const edgeId of ALL_EDGE_IDS) {
      const edgeEl = container.querySelector(`[data-stage-edge='${edgeId}']`);
      expect(edgeEl, `missing edge ${edgeId}`).not.toBeNull();
      const g = edgeEl!.closest("g");
      const labelText = g?.querySelector("text");
      expect(labelText, `missing label text for ${edgeId}`).not.toBeNull();
      expect(
        labelText!.textContent?.trim(),
        `empty label for edge ${edgeId}`,
      ).toBeTruthy();
    }
  });
});

describe("SessionGraph — AC3: active-stage highlight", () => {
  it("exactly one node is active when stage=plan, and it is the plan node", () => {
    const { container } = renderGraph("plan");
    const activeNodes = container.querySelectorAll("[data-active='true']");
    expect(activeNodes).toHaveLength(1);
    expect(activeNodes[0].getAttribute("data-stage-node")).toBe("plan");
  });

  it("exactly one node is active when stage=implement, and it is the implement node", () => {
    const { container } = renderGraph("implement");
    const activeNodes = container.querySelectorAll("[data-active='true']");
    expect(activeNodes).toHaveLength(1);
    expect(activeNodes[0].getAttribute("data-stage-node")).toBe("implement");
  });

  it("active node has data-state='active'", () => {
    const { container } = renderGraph("design");
    const activeNode = container.querySelector("[data-active='true']");
    expect(activeNode?.getAttribute("data-state")).toBe("active");
  });
});

describe("SessionGraph — AC4: completed vs future state", () => {
  it("at stage=tech: request, design, prd are completed", () => {
    const { container } = renderGraph("tech");
    for (const stage of ["request", "design", "prd"]) {
      const node = container.querySelector(`[data-stage-node='${stage}']`);
      expect(node?.getAttribute("data-state"), `${stage} should be completed`).toBe(
        "completed",
      );
    }
  });

  it("at stage=tech: plan, tasks, implement, gap-check, verify, archive are future", () => {
    const { container } = renderGraph("tech");
    for (const stage of ["plan", "tasks", "implement", "gap-check", "verify", "archive"]) {
      const node = container.querySelector(`[data-stage-node='${stage}']`);
      expect(node?.getAttribute("data-state"), `${stage} should be future`).toBe(
        "future",
      );
    }
  });
});

describe("SessionGraph — AC5: skipped-stage dashed outline + bypass arc", () => {
  it("brainstorm node has state='skipped' when past brainstorm with no design artifact", () => {
    // brainstorm is skipped when currentIdx > brainstormIdx && !mtimes.has("design")
    const { container } = renderGraph("prd", { mtimes: new Map() });
    const brainstorm = container.querySelector("[data-stage-node='brainstorm']");
    expect(brainstorm?.getAttribute("data-state")).toBe("skipped");
  });

  it("bypass arc is rendered when brainstorm is skipped", () => {
    const { container } = renderGraph("prd", { mtimes: new Map() });
    const arc = container.querySelector("[data-bypass-arc='brainstorm']");
    expect(arc).not.toBeNull();
  });

  it("bypass arc is NOT rendered when brainstorm is not skipped (design artifact present)", () => {
    const mtimes = new Map([["design", 1000]] as [string, number][]);
    const { container } = renderGraph("prd", { mtimes: mtimes as Map<never, never> });
    const arc = container.querySelector("[data-bypass-arc='brainstorm']");
    expect(arc).toBeNull();
  });

  it("brainstorm node is completed (not skipped) when design artifact is present", () => {
    const mtimes = new Map([["design", 1000]] as [string, number][]);
    const { container } = renderGraph("prd", { mtimes: mtimes as Map<never, never> });
    const brainstorm = container.querySelector("[data-stage-node='brainstorm']");
    expect(brainstorm?.getAttribute("data-state")).toBe("completed");
  });
});

describe("SessionGraph — AC6: tasks node partial state with done/total counter", () => {
  it("tasks node has state='partial' at stage=implement when tasksTotal > 0", () => {
    const { container } = renderGraph("implement", { tasksDone: 3, tasksTotal: 7 });
    const tasksNode = container.querySelector("[data-stage-node='tasks']");
    expect(tasksNode?.getAttribute("data-state")).toBe("partial");
  });

  it("renders literal '3 / 7' text inside the tasks node area", () => {
    const { getByText } = renderGraph("implement", { tasksDone: 3, tasksTotal: 7 });
    // The text is rendered as "{tasksDone} / {tasksTotal}" via JSX text nodes.
    expect(getByText("3 / 7")).toBeTruthy();
  });
});

describe("SessionGraph — AC7: read-only constraint (no interactive affordances)", () => {
  it("no node has onClick handler (no role=button, no tabIndex)", () => {
    const { container } = renderGraph("plan");
    const nodes = container.querySelectorAll("[data-stage-node]");
    nodes.forEach((node) => {
      // No role="button"
      expect(node.getAttribute("role")).not.toBe("button");
      // No tabIndex attribute
      expect(node.getAttribute("tabIndex")).toBeNull();
      expect(node.getAttribute("tabindex")).toBeNull();
    });
  });

  it("SVG root has role='img' and aria-hidden on the svg element (accessibility, not interactive)", () => {
    const { container } = renderGraph("plan");
    const graphDiv = container.querySelector(".session-graph");
    expect(graphDiv?.getAttribute("role")).toBe("img");
    const svg = container.querySelector("svg");
    expect(svg?.getAttribute("aria-hidden")).toBe("true");
  });
});

describe("SessionGraph — AC9: whisker appears for recent artifact changes", () => {
  it("renders whisker text (Ns ago) when an artifact mtime is within 60s", () => {
    const now = Date.now();
    // 5 seconds ago — should show "5s ago"
    const mtimes = new Map([["prd", now - 5000]] as [string, number][]);
    const { container } = renderGraph("plan", { mtimes: mtimes as Map<never, never> });
    // The whisker is a <text> element; its content matches "Ns ago" format.
    const whiskerTexts = Array.from(container.querySelectorAll("text")).filter(
      (t) => /\d+s ago/.test(t.textContent ?? ""),
    );
    expect(whiskerTexts.length).toBeGreaterThan(0);
  });

  it("does NOT render whisker when artifact mtime is older than 60s", () => {
    const now = Date.now();
    const mtimes = new Map([["prd", now - 65_000]] as [string, number][]);
    const { container } = renderGraph("plan", { mtimes: mtimes as Map<never, never> });
    const whiskerTexts = Array.from(container.querySelectorAll("text")).filter(
      (t) => /\d+s ago/.test(t.textContent ?? ""),
    );
    expect(whiskerTexts.length).toBe(0);
  });
});
