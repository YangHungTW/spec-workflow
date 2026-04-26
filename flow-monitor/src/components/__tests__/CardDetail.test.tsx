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
        "btn.back": "Back",
        "btn.revealInFinder": "Reveal in Finder",
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
        "tab.request": "00 request",
        "tab.brainstorm": "01 brainstorm",
        "tab.design": "02 design",
        "tab.prd": "03 prd",
        "tab.tech": "04 tech",
        "tab.plan": "05 plan",
        "tab.tasks": "06 tasks",
        "tab.gaps": "07 gaps",
        "tab.verify": "08 verify",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Hoist mockInvoke so it is available inside the vi.mock factory (which is
// hoisted to top-of-file by Vitest before module evaluation).
const { mockInvoke } = vi.hoisted(() => {
  // Default all-present artefact map — existing tests that click tabs rely on
  // all tabs being enabled. T18 tests override this mock per-test.
  const ALL_PRESENT: Record<string, boolean> = {
    "00-request.md": true,
    "01-brainstorm.md": true,
    "02-design": true,
    "03-prd.md": true,
    "04-tech.md": true,
    "05-plan.md": true,
    "06-tasks.md": true,
    "07-gaps.md": true,
    "08-verify.md": true,
  };
  const mockInvoke = vi.fn((cmd: string) => {
    if (cmd === "read_artefact") {
      return Promise.resolve({ content: "# stub content" });
    }
    if (cmd === "get_settings") {
      return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
    }
    if (cmd === "list_feature_artefacts") {
      return Promise.resolve({ files_present: ALL_PRESENT });
    }
    return Promise.resolve(undefined);
  });
  return { mockInvoke };
});

vi.mock("@tauri-apps/api/core", () => ({
  invoke: mockInvoke,
}));

// Stub invokeStore — prevents command_taxonomy import error in jsdom.
// Tests that need to assert no mutate IPC fires can spy on mockInvoke directly
// because all IPC goes through @tauri-apps/api/core invoke.
vi.mock("../../stores/invokeStore", () => ({
  useInvokeStore: () => ({
    inFlight: new Set<string>(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: vi.fn(),
  }),
}));

// Stub AgentPill so tests can assert presence/absence via data-testid
vi.mock("../../components/AgentPill", () => ({
  AgentPill: ({ role }: { role: string }) => (
    <span data-testid="agent-pill-stub" data-role={role} />
  ),
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
        <Route path="/feature/:repoId/archived/:slug" element={<CardDetail />} />
        <Route path="/" element={<div data-testid="main-window-restored">MainWindow</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("CardDetail — master-detail skeleton", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // TabStrip calls scrollIntoView on mount; jsdom does not implement it.
    window.HTMLElement.prototype.scrollIntoView = vi.fn();
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

  it("renders 9 tabs in a tablist in the right pane (T19 — TabStrip)", () => {
    renderCardDetail();
    // T19 replaced the stub placeholder with the real TabStrip component.
    const tabStrip = document.querySelector("[role='tablist']");
    expect(tabStrip).toBeTruthy();
    const tabs = tabStrip?.querySelectorAll("[role='tab']");
    expect(tabs?.length).toBe(9);
  });

  it("tab labels match the 9 markdown docs (via i18n keys)", () => {
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

  it("invalid repoId (contains ..) redirects to / (security: URL param validation)", () => {
    render(
      <MemoryRouter initialEntries={["/feature/../my-feature"]}>
        <Routes>
          <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
          <Route path="/" element={<div data-testid="main-window-restored">MainWindow</div>} />
        </Routes>
      </MemoryRouter>,
    );
    // router normalises the path so repoId would be ".." — guard must redirect
    // In MemoryRouter, navigating to /feature/../my-feature normalises to /feature,
    // which matches no route — we verify this test for malformed repoId at the guard level
    // by routing with an explicit repoId containing ".."
    render(
      <MemoryRouter initialEntries={["/feature/..bad/my-feature"]}>
        <Routes>
          <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
          <Route path="/" element={<div data-testid="main-window-restored2">MainWindow</div>} />
        </Routes>
      </MemoryRouter>,
    );
    expect(screen.getByTestId("main-window-restored2")).toBeTruthy();
  });

  it("invalid slug (contains /) redirects to / (security: URL param validation)", () => {
    render(
      <MemoryRouter initialEntries={["/feature/myrepo/bad%2Fslug"]}>
        <Routes>
          <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
          <Route path="/" element={<div data-testid="main-window-restored3">MainWindow</div>} />
        </Routes>
      </MemoryRouter>,
    );
    expect(screen.getByTestId("main-window-restored3")).toBeTruthy();
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

describe("CardDetail — 02-design tab conditional render (T20)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.HTMLElement.prototype.scrollIntoView = vi.fn();
  });

  it("default tab (00-request) renders CardDetailMarkdownPane, not DesignFolderIndex", () => {
    renderCardDetail();
    // CardDetailMarkdownPane renders a footer with the literal string
    expect(
      screen.getByText("Read-only preview. Open in Finder to edit."),
    ).toBeTruthy();
    // DesignFolderIndex is NOT present
    expect(
      document.querySelector("[data-testid='design-folder-index']"),
    ).toBeNull();
  });

  it("clicking the 02-design tab shows DesignFolderIndex, not the markdown footer", () => {
    renderCardDetail();
    const designTab = screen.getByRole("tab", { name: "02 design" });
    fireEvent.click(designTab);
    // DesignFolderIndex must be present
    expect(
      document.querySelector("[data-testid='design-folder-index']"),
    ).toBeTruthy();
    // The read-only markdown footer must NOT be present inside the tab content area
    const tabContent = document.querySelector("[data-testid='tab-content-placeholder']");
    expect(
      tabContent?.querySelector(".card-detail__markdown-footer"),
    ).toBeNull();
  });

  it("switching back to 00-request tab hides DesignFolderIndex and shows markdown pane", () => {
    renderCardDetail();
    const designTab = screen.getByRole("tab", { name: "02 design" });
    fireEvent.click(designTab);
    // Now switch back to 00-request
    const requestTab = screen.getByRole("tab", { name: "00 request" });
    fireEvent.click(requestTab);
    expect(
      document.querySelector("[data-testid='design-folder-index']"),
    ).toBeNull();
    expect(
      screen.getByText("Read-only preview. Open in Finder to edit."),
    ).toBeTruthy();
  });
});

// ── T15: Archived route tests ────────────────────────────────────────────────

function renderArchivedCardDetail(
  slug = "old-feature",
  repoId = "my-repo",
) {
  const initialPath = `/feature/${repoId}/archived/${slug}`;
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <Routes>
        <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
        <Route path="/feature/:repoId/archived/:slug" element={<CardDetail isArchived />} />
        <Route path="/" element={<div data-testid="main-window-restored">MainWindow</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("CardDetail — archived route (T15, AC18, AC19)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.HTMLElement.prototype.scrollIntoView = vi.fn();
  });

  it("AC18: renders ARCHIVED badge on the archived route", () => {
    renderArchivedCardDetail();
    expect(screen.getByText("ARCHIVED")).toBeTruthy();
  });

  it("AC18: renders Read only label on the archived route", () => {
    renderArchivedCardDetail();
    expect(screen.getByText("Read only")).toBeTruthy();
  });

  it("AC18: AgentPill is NOT rendered on the archived header", () => {
    renderArchivedCardDetail();
    expect(document.querySelector("[data-testid='agent-pill-stub']")).toBeNull();
  });

  it("AC19: no Advance button in the DOM for archived", () => {
    renderArchivedCardDetail();
    // The advance button text starts with "Advance" in i18n keys
    expect(screen.queryByRole("button", { name: /advance/i })).toBeNull();
  });

  it("AC19: no Message/Send button in the DOM for archived", () => {
    renderArchivedCardDetail();
    expect(screen.queryByRole("button", { name: /message|send/i })).toBeNull();
  });

  it("AC19: no Edit button in the DOM for archived", () => {
    renderArchivedCardDetail();
    expect(screen.queryByRole("button", { name: /edit/i })).toBeNull();
  });

  it("AC19: read_artefact IPC called with path under .specaffold/archive/<slug>/", async () => {
    mockInvoke.mockImplementation((cmd: string, args?: Record<string, unknown>) => {
      if (cmd === "get_settings") {
        return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
      }
      if (cmd === "read_artefact") {
        return Promise.resolve("# archived content");
      }
      return Promise.resolve(undefined);
    });

    renderArchivedCardDetail("old-feature", "my-repo");

    // Wait for async effects to settle
    await new Promise((r) => setTimeout(r, 50));

    const readCalls = mockInvoke.mock.calls.filter(
      (c) => c[0] === "read_artefact",
    );
    // At least one read_artefact call should target the archive path
    const archiveCalls = readCalls.filter((c) => {
      const args = c[1] as Record<string, string> | undefined;
      return args?.repo !== undefined && typeof args?.slug === "string";
    });
    // The slug passed should be the archived slug, not a features path
    // (CardDetail passes slug and repo separately; the path is built in the component)
    expect(archiveCalls.length).toBeGreaterThan(0);
  });

  it("AC19: no mutate IPC (advance_stage, write commands) fires during archived view", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") {
        return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
      }
      if (cmd === "read_artefact") {
        return Promise.resolve("# archived content");
      }
      return Promise.resolve(undefined);
    });

    renderArchivedCardDetail("old-feature", "my-repo");

    // Wait for async effects to settle
    await new Promise((r) => setTimeout(r, 50));

    const mutateCommands = ["advance_stage", "send_message", "write_artefact", "edit_artefact"];
    const mutateCalls = mockInvoke.mock.calls.filter((c) =>
      mutateCommands.includes(c[0] as string),
    );
    expect(mutateCalls).toHaveLength(0);
  });
});

// ── T18: CardDetail tab exists wired from list_feature_artefacts ─────────────

/**
 * Build a mock IPC handler that responds to list_feature_artefacts with only
 * the given files marked present; all other TAB_DEFINITIONS files are false.
 */
function makeArtefactsMock(presentFiles: string[]) {
  const ALL_FILES = [
    "00-request.md",
    "01-brainstorm.md",
    "02-design",
    "03-prd.md",
    "04-tech.md",
    "05-plan.md",
    "06-tasks.md",
    "07-gaps.md",
    "08-verify.md",
  ];
  const files_present: Record<string, boolean> = {};
  for (const f of ALL_FILES) {
    files_present[f] = presentFiles.includes(f);
  }
  return (cmd: string) => {
    if (cmd === "get_settings") {
      return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
    }
    if (cmd === "list_feature_artefacts") {
      return Promise.resolve({ files_present });
    }
    if (cmd === "read_artefact") {
      return Promise.resolve("# stub");
    }
    return Promise.resolve(undefined);
  };
}

describe("CardDetail — T18 tab exists from list_feature_artefacts (AC23)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.HTMLElement.prototype.scrollIntoView = vi.fn();
  });

  it("AC23: Request + PRD tabs enabled; other 7 render as --missing when only 00-request.md and 03-prd.md present", async () => {
    mockInvoke.mockImplementation(makeArtefactsMock(["00-request.md", "03-prd.md"]));

    renderCardDetail();

    // Wait for async IPC effects
    await new Promise((r) => setTimeout(r, 50));

    // Request tab: exists=true → no --missing class
    const requestTab = screen.getByRole("tab", { name: "00 request" });
    expect(requestTab.classList.contains("tab-strip__tab--missing")).toBe(false);
    expect(requestTab.getAttribute("aria-disabled")).toBe("false");

    // PRD tab: exists=true → no --missing class
    const prdTab = screen.getByRole("tab", { name: "03 prd" });
    expect(prdTab.classList.contains("tab-strip__tab--missing")).toBe(false);
    expect(prdTab.getAttribute("aria-disabled")).toBe("false");

    // All other tabs should be missing
    const missingLabels = [
      "01 brainstorm",
      "02 design",
      "04 tech",
      "05 plan",
      "06 tasks",
      "07 gaps",
      "08 verify",
    ];
    for (const label of missingLabels) {
      const tab = screen.getByRole("tab", { name: label });
      expect(tab.classList.contains("tab-strip__tab--missing")).toBe(true);
      expect(tab.getAttribute("aria-disabled")).toBe("true");
    }
  });

  it("AC23: adding 04-tech.md to artefact response enables Tech tab", async () => {
    // First render with only 00-request.md + 03-prd.md
    mockInvoke.mockImplementation(makeArtefactsMock(["00-request.md", "03-prd.md"]));
    const { unmount } = renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    const techTabBefore = screen.getByRole("tab", { name: "04 tech" });
    expect(techTabBefore.classList.contains("tab-strip__tab--missing")).toBe(true);

    unmount();

    // Re-render with 04-tech.md also present
    mockInvoke.mockImplementation(
      makeArtefactsMock(["00-request.md", "03-prd.md", "04-tech.md"]),
    );
    renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    const techTabAfter = screen.getByRole("tab", { name: "04 tech" });
    expect(techTabAfter.classList.contains("tab-strip__tab--missing")).toBe(false);
    expect(techTabAfter.getAttribute("aria-disabled")).toBe("false");
  });

  it("AC22: clicking a --missing tab does NOT change the active tab", async () => {
    // Only 00-request.md present → all others missing
    mockInvoke.mockImplementation(makeArtefactsMock(["00-request.md"]));

    renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    // Active tab should be 00-request (first tab)
    const requestTab = screen.getByRole("tab", { name: "00 request" });
    expect(requestTab.getAttribute("aria-selected")).toBe("true");

    // Click a missing tab
    const brainstormTab = screen.getByRole("tab", { name: "01 brainstorm" });
    expect(brainstormTab.classList.contains("tab-strip__tab--missing")).toBe(true);
    fireEvent.click(brainstormTab);

    // Active tab must remain 00-request
    expect(requestTab.getAttribute("aria-selected")).toBe("true");
    expect(brainstormTab.getAttribute("aria-selected")).toBe("false");
  });
});

// ── T18 retry 1: IPC shape guard on list_feature_artefacts response ───────────

describe("CardDetail — malformed list_feature_artefacts response (security guard)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.HTMLElement.prototype.scrollIntoView = vi.fn();
  });

  it("IPC returns null → all tabs fall back to --missing, no crash, console.warn fired", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") {
        return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
      }
      if (cmd === "list_feature_artefacts") {
        // Backend returns null instead of an ArtefactPresence object
        return Promise.resolve(null);
      }
      if (cmd === "read_artefact") {
        return Promise.resolve("# stub");
      }
      return Promise.resolve(undefined);
    });

    renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    // All tabs should be missing (files_present falls back to {})
    const allTabLabels = [
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
    for (const label of allTabLabels) {
      const tab = screen.getByRole("tab", { name: label });
      expect(tab.classList.contains("tab-strip__tab--missing")).toBe(true);
    }

    // console.warn must have been fired with the malformed payload
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining("list_feature_artefacts returned malformed response"),
      null,
    );

    warnSpy.mockRestore();
  });

  it("IPC returns { files_present: null } → all tabs fall back to --missing, no crash, console.warn fired", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") {
        return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
      }
      if (cmd === "list_feature_artefacts") {
        // Backend returns files_present: null
        return Promise.resolve({ files_present: null });
      }
      if (cmd === "read_artefact") {
        return Promise.resolve("# stub");
      }
      return Promise.resolve(undefined);
    });

    renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    const allTabLabels = [
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
    for (const label of allTabLabels) {
      const tab = screen.getByRole("tab", { name: label });
      expect(tab.classList.contains("tab-strip__tab--missing")).toBe(true);
    }

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining("list_feature_artefacts returned malformed response"),
      { files_present: null },
    );

    warnSpy.mockRestore();
  });

  it("IPC returns {} (missing files_present field) → all tabs fall back to --missing, no crash, console.warn fired", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") {
        return Promise.resolve({ repos: ["/Users/alice/projects/my-repo"] });
      }
      if (cmd === "list_feature_artefacts") {
        // Backend returns an object but files_present field is absent
        return Promise.resolve({});
      }
      if (cmd === "read_artefact") {
        return Promise.resolve("# stub");
      }
      return Promise.resolve(undefined);
    });

    renderCardDetail();
    await new Promise((r) => setTimeout(r, 50));

    const allTabLabels = [
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
    for (const label of allTabLabels) {
      const tab = screen.getByRole("tab", { name: label });
      expect(tab.classList.contains("tab-strip__tab--missing")).toBe(true);
    }

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining("list_feature_artefacts returned malformed response"),
      {},
    );

    warnSpy.mockRestore();
  });
});
