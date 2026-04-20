/**
 * Tests for T48: RepoSidebar polish — logo, section headers, count badges,
 * filter section, Settings / theme items.
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { RepoSidebar, type RepoSidebarProps } from "../RepoSidebar";

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
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

const REPOS: RepoSidebarProps["repos"] = [
  { id: "r1", name: "spec-workflow", path: "/repos/spec-workflow" },
  { id: "r2", name: "my-saas-app", path: "/repos/my-saas-app" },
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
