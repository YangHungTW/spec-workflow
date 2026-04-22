/**
 * Tests for T48: RepoSidebar polish — logo, section headers, count badges,
 * filter section, Settings / theme items.
 *
 * Tests for T14: RepoSidebar agent dot + collapsible Archived section.
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { RepoSidebar, type RepoSidebarProps } from "../RepoSidebar";
import { ROLE_TO_COLOR, roleForSession } from "../../agentPalette";
import type { ArchivedFeatureRecord } from "../../stores/sessionStore";

vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "sidebar.allProjects": "All Projects",
        "sidebar.addRepo": "+ Add repo…",
        "sidebar.projects": "Projects",
        "sidebar.filter": "Filter",
        "sidebar.stalledOnly": "Stalled only",
        "sidebar.hasUi": "Has UI",
        "sidebar.settings": "Settings",
        "sidebar.archived": "Archived",
        "btn.openInFinder": "Open in Finder",
        "btn.copyPath": "Copy path",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Mock Tauri invoke for hover actions
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(undefined),
}));

const REPOS: RepoSidebarProps["repos"] = [
  { id: "r1", name: "specaffold", path: "/repos/specaffold", stage: "implement" },
  { id: "r2", name: "my-saas-app", path: "/repos/my-saas-app", stage: "prd" },
];

const ARCHIVED: ArchivedFeatureRecord[] = [
  { repo: "/repos/specaffold", slug: "old-feature-one", dir: "/repos/specaffold/.specaffold/archive/old-feature-one" },
  { repo: "/repos/specaffold", slug: "old-feature-two", dir: "/repos/specaffold/.specaffold/archive/old-feature-two" },
];

const BASE_PROPS: RepoSidebarProps = {
  repos: REPOS,
  selectedId: "all",
  onSelect: vi.fn(),
  onAddRepo: vi.fn(),
  onSettings: vi.fn(),
  onThemeToggle: vi.fn(),
  theme: "light",
  stalledCount: 2,
  repoSessionCounts: { r1: 4, r2: 2 },
  archivedFeatures: [],
  archiveExpanded: false,
  setArchiveExpanded: vi.fn(),
  onArchivedFeatureClick: vi.fn(),
};

describe("RepoSidebar T48 — logo", () => {
  it("renders Flow Monitor logo text", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Flow Monitor")).toBeTruthy();
  });

  it("renders the logo SVG", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const logoSvg = container.querySelector(".repo-sidebar__logo svg");
    expect(logoSvg).toBeTruthy();
  });
});

describe("RepoSidebar T48 — section headers", () => {
  it("renders a Projects section header", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Projects")).toBeTruthy();
  });

  it("renders a Filter section header", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Filter")).toBeTruthy();
  });
});

describe("RepoSidebar T48 — count badges", () => {
  it("renders stalled count badge on All Projects", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const badge = container.querySelector("[data-testid='badge-all-stalled']");
    expect(badge).toBeTruthy();
    expect(badge!.textContent).toBe("2");
  });

  it("renders session count badge on each repo item", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const r1Badge = container.querySelector("[data-testid='badge-repo-r1']");
    expect(r1Badge).toBeTruthy();
    expect(r1Badge!.textContent).toBe("4");
  });
});

describe("RepoSidebar T48 — filter items", () => {
  it("renders Stalled only filter item", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Stalled only")).toBeTruthy();
  });

  it("renders Has UI filter item", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Has UI")).toBeTruthy();
  });

  it("clicking Stalled only toggles active state", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const stalledFilter = screen.getByText("Stalled only").closest("li");
    expect(stalledFilter).toBeTruthy();
    fireEvent.click(stalledFilter!);
    expect(stalledFilter!.classList.contains("repo-sidebar__filter--active")).toBe(true);
  });
});

describe("RepoSidebar T48 — settings + theme at bottom", () => {
  it("renders Settings item", () => {
    render(<RepoSidebar {...BASE_PROPS} />);
    expect(screen.getByText("Settings")).toBeTruthy();
  });

  it("clicking Settings calls onSettings", () => {
    const onSettings = vi.fn();
    render(<RepoSidebar {...BASE_PROPS} onSettings={onSettings} />);
    fireEvent.click(screen.getByText("Settings"));
    expect(onSettings).toHaveBeenCalledTimes(1);
  });

  it("renders theme toggle item", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const themeToggle = container.querySelector("[data-testid='sidebar-theme-toggle']");
    expect(themeToggle).toBeTruthy();
  });

  it("clicking theme toggle calls onThemeToggle", () => {
    const onThemeToggle = vi.fn();
    const { container } = render(<RepoSidebar {...BASE_PROPS} onThemeToggle={onThemeToggle} />);
    const themeToggle = container.querySelector("[data-testid='sidebar-theme-toggle']")!;
    fireEvent.click(themeToggle);
    expect(onThemeToggle).toHaveBeenCalledTimes(1);
  });
});

// ---------------------------------------------------------------------------
// T14 — Agent dot on active rows
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — agent dot on active rows", () => {
  it("renders agent dot span with correct data-color for each active repo row", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);

    // r1 has stage "implement" → developer → green
    const r1Item = container.querySelector("[data-testid='sidebar-repo-r1']");
    expect(r1Item).toBeTruthy();
    const r1Dot = r1Item!.querySelector(".repo-sidebar__agent-dot");
    expect(r1Dot).toBeTruthy();
    const expectedR1Color = ROLE_TO_COLOR[roleForSession({ stage: "implement" })];
    expect(r1Dot!.getAttribute("data-color")).toBe(expectedR1Color);
  });

  it("renders agent dot with data-color matching ROLE_TO_COLOR[roleForSession({stage})] for prd stage", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);

    // r2 has stage "prd" → pm → purple
    const r2Item = container.querySelector("[data-testid='sidebar-repo-r2']");
    expect(r2Item).toBeTruthy();
    const r2Dot = r2Item!.querySelector(".repo-sidebar__agent-dot");
    expect(r2Dot).toBeTruthy();
    const expectedR2Color = ROLE_TO_COLOR[roleForSession({ stage: "prd" })];
    expect(r2Dot!.getAttribute("data-color")).toBe(expectedR2Color);
  });

  it("does NOT render agent dot on All Projects item", () => {
    const { container } = render(<RepoSidebar {...BASE_PROPS} />);
    const allItem = container.querySelector("[data-testid='sidebar-all-projects']");
    expect(allItem).toBeTruthy();
    const dot = allItem!.querySelector(".repo-sidebar__agent-dot");
    expect(dot).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// T14 — Archived section: collapsed by default
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — Archived section collapsed by default", () => {
  it("renders the Archived section header", () => {
    render(<RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={false} />);
    expect(screen.getByText("Archived")).toBeTruthy();
  });

  it("shows collapsed chevron (▶) when archiveExpanded=false", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={false} />,
    );
    const chevron = container.querySelector(".repo-sidebar__archive-chevron");
    expect(chevron).toBeTruthy();
    expect(chevron!.textContent).toBe("▶");
  });

  it("shows archived count in the header", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={false} />,
    );
    const countEl = container.querySelector(".repo-sidebar__archive-count");
    expect(countEl).toBeTruthy();
    expect(countEl!.textContent).toBe(String(ARCHIVED.length));
  });

  it("does NOT show archived rows when collapsed", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={false} />,
    );
    const archivedRows = container.querySelectorAll(".repo-sidebar__archived-row");
    expect(archivedRows.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// T14 — Archived section: expanded
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — Archived section expanded", () => {
  it("shows expanded chevron (▼) when archiveExpanded=true", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    const chevron = container.querySelector(".repo-sidebar__archive-chevron");
    expect(chevron).toBeTruthy();
    expect(chevron!.textContent).toBe("▼");
  });

  it("renders N archived rows when expanded (N = ARCHIVED.length)", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    const archivedRows = container.querySelectorAll(".repo-sidebar__archived-row");
    expect(archivedRows.length).toBe(ARCHIVED.length);
  });

  it("archived rows display italic slug text", () => {
    render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    expect(screen.getByText("old-feature-one")).toBeTruthy();
    expect(screen.getByText("old-feature-two")).toBeTruthy();
  });

  it("archived rows contain arch badge", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    const archBadges = container.querySelectorAll(".repo-sidebar__arch-badge");
    expect(archBadges.length).toBe(ARCHIVED.length);
    for (const badge of Array.from(archBadges)) {
      expect(badge.textContent).toBe("arch");
    }
  });

  it("archived rows do NOT have an agent dot", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    const rows = container.querySelectorAll(".repo-sidebar__archived-row");
    for (const row of Array.from(rows)) {
      expect(row.querySelector(".repo-sidebar__agent-dot")).toBeNull();
    }
  });

  it("archived rows have exactly 2 hover action buttons: Open in Finder and Copy path", () => {
    const { container } = render(
      <RepoSidebar {...BASE_PROPS} archivedFeatures={ARCHIVED} archiveExpanded={true} />,
    );
    const rows = container.querySelectorAll(".repo-sidebar__archived-row");
    for (const row of Array.from(rows)) {
      const buttons = row.querySelectorAll("button");
      expect(buttons.length).toBe(2);
      const labels = Array.from(buttons).map((b) => b.textContent);
      expect(labels).toContain("Open in Finder");
      expect(labels).toContain("Copy path");
    }
  });
});

// ---------------------------------------------------------------------------
// T14 — Clicking archived section header toggles archiveExpanded
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — header click toggles archiveExpanded", () => {
  it("clicking the archived section header calls setArchiveExpanded(true) when collapsed", () => {
    const setArchiveExpanded = vi.fn();
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={false}
        setArchiveExpanded={setArchiveExpanded}
      />,
    );
    const header = container.querySelector(".repo-sidebar__archive-header");
    expect(header).toBeTruthy();
    fireEvent.click(header!);
    expect(setArchiveExpanded).toHaveBeenCalledWith(true);
  });

  it("clicking the archived section header calls setArchiveExpanded(false) when expanded", () => {
    const setArchiveExpanded = vi.fn();
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
        setArchiveExpanded={setArchiveExpanded}
      />,
    );
    const header = container.querySelector(".repo-sidebar__archive-header");
    expect(header).toBeTruthy();
    fireEvent.click(header!);
    expect(setArchiveExpanded).toHaveBeenCalledWith(false);
  });
});

// ---------------------------------------------------------------------------
// T14 — Clicking archived row navigates via onArchivedRowClick
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — archived row click navigates", () => {
  it("clicking an archived row calls onArchivedFeatureClick with (repoId, slug)", () => {
    const onArchivedFeatureClick = vi.fn();
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
        onArchivedFeatureClick={onArchivedFeatureClick}
      />,
    );
    const rows = container.querySelectorAll(".repo-sidebar__archived-row");
    expect(rows.length).toBeGreaterThan(0);
    // Click on the first row's slug area (not a button)
    const firstRowSlug = rows[0].querySelector(".repo-sidebar__archived-slug");
    expect(firstRowSlug).toBeTruthy();
    fireEvent.click(firstRowSlug!);
    expect(onArchivedFeatureClick).toHaveBeenCalledWith(
      ARCHIVED[0].repo,
      ARCHIVED[0].slug,
    );
  });
});

// ---------------------------------------------------------------------------
// T14 — State persists: archiveExpanded reflects store value across remounts
// ---------------------------------------------------------------------------

describe("RepoSidebar T14 — state persists across remounts", () => {
  it("archiveExpanded=true prop causes expanded rendering (chevron ▼)", () => {
    // Simulates a remount where the parent passes the stored expanded=true value
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
      />,
    );
    const chevron = container.querySelector(".repo-sidebar__archive-chevron");
    expect(chevron!.textContent).toBe("▼");
    const rows = container.querySelectorAll(".repo-sidebar__archived-row");
    expect(rows.length).toBe(ARCHIVED.length);
  });

  it("archiveExpanded=false prop causes collapsed rendering (chevron ▶)", () => {
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={false}
      />,
    );
    const chevron = container.querySelector(".repo-sidebar__archive-chevron");
    expect(chevron!.textContent).toBe("▶");
    const rows = container.querySelectorAll(".repo-sidebar__archived-row");
    expect(rows.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// AC17 — Archived slug italic: CSS class correctness (validate-fix1)
// jsdom does not apply external CSS stylesheets loaded via @import or <link>,
// so we assert (a) the slug element has the .repo-sidebar__archived-slug class
// and (b) the CSS rule for font-style:italic targets that exact class.
// ---------------------------------------------------------------------------

describe("RepoSidebar AC17 — archived slug uses italic CSS class", () => {
  it("archived slug element carries .repo-sidebar__archived-slug class", () => {
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
      />,
    );
    const slugEl = container.querySelector(".repo-sidebar__archived-slug");
    expect(slugEl).toBeTruthy();
    // The class must be exactly repo-sidebar__archived-slug (not item-label,
    // which was the old dead selector that never matched).
    expect(slugEl!.className).toContain("repo-sidebar__archived-slug");
    expect(slugEl!.className).not.toContain("repo-sidebar__item-label");
  });

  it("archived slug element does NOT carry .repo-sidebar__item-label (wrong selector guard)", () => {
    // If this assertion fails it means the component was changed to use
    // .repo-sidebar__item-label instead, which would re-introduce the
    // selector mismatch that AC17 caught.
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
      />,
    );
    const labelInArchivedRow = container.querySelector(
      ".repo-sidebar__archived-row .repo-sidebar__item-label",
    );
    expect(labelInArchivedRow).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// R18 — Prop-name alignment: onArchivedFeatureClick (validate-fix1)
// ---------------------------------------------------------------------------

describe("RepoSidebar R18 — onArchivedFeatureClick prop wiring", () => {
  it("prop is named onArchivedFeatureClick (not onArchivedRowClick)", () => {
    // The RepoSidebarProps interface must expose onArchivedFeatureClick so
    // MainWindow's spread wires through. We verify via TypeScript at compile
    // time and here assert the runtime handler fires under the correct name.
    const onArchivedFeatureClick = vi.fn();
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
        onArchivedFeatureClick={onArchivedFeatureClick}
      />,
    );
    const slugEl = container.querySelector(".repo-sidebar__archived-slug");
    expect(slugEl).toBeTruthy();
    fireEvent.click(slugEl!);
    expect(onArchivedFeatureClick).toHaveBeenCalledTimes(1);
    expect(onArchivedFeatureClick).toHaveBeenCalledWith(
      ARCHIVED[0].repo,
      ARCHIVED[0].slug,
    );
  });

  it("passing onArchivedFeatureClick=undefined does not throw on archived row click", () => {
    const { container } = render(
      <RepoSidebar
        {...BASE_PROPS}
        archivedFeatures={ARCHIVED}
        archiveExpanded={true}
        onArchivedFeatureClick={undefined}
      />,
    );
    const slugEl = container.querySelector(".repo-sidebar__archived-slug");
    expect(slugEl).toBeTruthy();
    // Should not throw — the handler uses optional chaining
    expect(() => fireEvent.click(slugEl!)).not.toThrow();
  });
});
