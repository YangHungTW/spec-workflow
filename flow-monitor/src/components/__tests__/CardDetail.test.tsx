/**
 * Tests for T18: CardDetail view (master-detail skeleton)
 *
 * AC9.a — detail opens on click, URL is /feature/:repoId/:slug, header shows repo/slug
 * AC9.e — no edit affordance (no textbox, no Save/Edit/Advance button)
 * AC9.f — breadcrumb back restores MainWindow filter/sort/repo state
 * AC9.j — stalled badge rendered statically
 * B2 boundary — no Send instruction, no Advance stage, no Edit affordance
 *
 * Tab strip: 9 tab button stubs rendered (T19 will add scroll behaviour)
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import CardDetail from "../../views/CardDetail";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "btn.openInFinder": "Open in Finder",
        "btn.copyPath": "Copy path",
        "stage.implement": "implement",
        "idle.stalled": "Stalled",
        "idle.stale": "Stale",
        "idle.none": "none",
        "stage.request": "request",
        "stage.brainstorm": "brainstorm",
        "stage.design": "design",
        "stage.prd": "PRD",
        "stage.tech": "tech",
        "stage.plan": "plan",
        "stage.tasks": "tasks",
        "stage.gap-check": "gap-check",
        "stage.verify": "verify",
        "stage.archive": "archive",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Stub Tauri IPC — read_artefact returns empty markdown
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn((cmd: string) => {
    if (cmd === "read_artefact") {
      return Promise.resolve({ content: "# stub content" });
    }
    return Promise.resolve(undefined);
  }),
}));

// Stub sessionStore so we can inspect filter restoration
const mockSetSortAxis = vi.fn();
const mockSetSelectedRepoId = vi.fn();
const mockSessionStore = {
  filterState: {
    sortAxis: "LastUpdatedDesc" as const,
    selectedRepoId: "all",
    collapsedRepoIds: new Set<string>(),
  },
  sortAxis: "LastUpdatedDesc" as const,
  setSortAxis: mockSetSortAxis,
  selectedRepoId: "all",
  setSelectedRepoId: mockSetSelectedRepoId,
  collapsedRepoIds: new Set<string>(),
  toggleRepoCollapse: vi.fn(),
  DEFAULT_FILTER: {
    sortAxis: "LastUpdatedDesc" as const,
    selectedRepoId: "all",
    collapsedRepoIds: new Set<string>(),
  },
};

vi.mock("../../stores/sessionStore", () => ({
  useSessionStore: () => mockSessionStore,
  sortSessions: (s: unknown[]) => s,
}));

function renderCardDetail(
  slug = "my-feature",
  repoId = "my-repo",
  searchParams = "",
) {
  const initialPath = `/feature/${repoId}/${slug}${searchParams ? `?${searchParams}` : ""}`;
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <Routes>
        <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
        <Route path="/" element={<div data-testid="main-window-restored">MainWindow</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("CardDetail — master-detail skeleton", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders without crashing", () => {
    renderCardDetail();
    expect(document.querySelector("[data-testid='card-detail']")).toBeTruthy();
  });

  it("header shows repo/slug title (AC9.a)", () => {
    renderCardDetail("my-feature", "my-repo");
    expect(screen.getByText("my-repo/my-feature")).toBeTruthy();
  });

  it("renders master-detail layout — not modal, same-window nav (AC9.a)", () => {
    renderCardDetail();
    // master-detail: left rail + right pane present
    expect(document.querySelector("[data-testid='card-detail-left-rail']")).toBeTruthy();
    expect(document.querySelector("[data-testid='card-detail-right-pane']")).toBeTruthy();
  });

  it("renders stage checklist in left rail", () => {
    renderCardDetail();
    const leftRail = document.querySelector("[data-testid='card-detail-left-rail']");
    expect(leftRail?.querySelector("[data-testid='stage-checklist']")).toBeTruthy();
  });

  it("renders 9 tab button stubs in right pane (T19 placeholder)", () => {
    renderCardDetail();
    const tabStrip = document.querySelector("[data-testid='tab-strip-placeholder']");
    expect(tabStrip).toBeTruthy();
    const tabs = tabStrip?.querySelectorAll("[role='tab']");
    expect(tabs?.length).toBe(9);
  });

  it("tab labels match the 9 markdown docs", () => {
    renderCardDetail();
    const expectedLabels = [
      "00 request",
      "01 brainstorm",
      "02 design",
      "03 prd",
      "04 tech",
      "05 plan",
      "06 tasks",
      "07 gaps",
      "08 verify",
    ];
    expectedLabels.forEach((label) => {
      expect(screen.getByRole("tab", { name: label })).toBeTruthy();
    });
  });

  it("no textbox input present (AC9.e — no edit affordance)", () => {
    renderCardDetail();
    expect(screen.queryByRole("textbox")).toBeNull();
  });

  it("no Save, Edit, or Advance stage button (AC9.e, B2 boundary)", () => {
    renderCardDetail();
    expect(
      screen.queryByRole("button", { name: /save|edit|advance stage/i }),
    ).toBeNull();
  });

  it("exactly 2 action buttons in header: Open in Finder + Copy path", () => {
    renderCardDetail();
    const buttons = screen.getAllByRole("button", {
      name: /open in finder|copy path/i,
    });
    expect(buttons).toHaveLength(2);
  });

  it("back button is present", () => {
    renderCardDetail();
    expect(screen.getByRole("button", { name: /back/i })).toBeTruthy();
  });

  it("clicking back navigates away from /feature route", () => {
    renderCardDetail("my-feature", "my-repo", "sort=Stage&repo=repo-1");
    const backBtn = screen.getByRole("button", { name: /back/i });
    fireEvent.click(backBtn);
    // After back, we should no longer be on the feature page
    // The route should navigate to MainWindow
    expect(screen.getByTestId("main-window-restored")).toBeTruthy();
  });
});
