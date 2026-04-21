/**
 * Tests for T19: TabStrip component
 *
 * AC9.g — tab overflow uses horizontal scroll (NOT wrap, NOT collapse-to-menu)
 * AC9.g — active tab auto-scrolls into view on switch
 * AC9.d — greyed-out tabs where exists: false (not yet generated)
 * ARIA — active tab has aria-selected="true"; clicking tab calls onSelect
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { TabStrip } from "../TabStrip";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "tab.request": "00 request",
        "tab.brainstorm": "01 brainstorm",
        "tab.design": "02 design",
        "tab.prd": "03 prd",
        "tab.tech": "04 tech",
        "tab.plan": "05 plan",
        "tab.tasks": "06 tasks",
        "tab.gaps": "07 gaps",
        "tab.verify": "08 verify",
        "tab.notYetGenerated": "not yet generated",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

const ALL_TABS = [
  { id: "00-request", labelKey: "tab.request" as const, exists: true },
  { id: "01-brainstorm", labelKey: "tab.brainstorm" as const, exists: true },
  { id: "02-design", labelKey: "tab.design" as const, exists: true },
  { id: "03-prd", labelKey: "tab.prd" as const, exists: true },
  { id: "04-tech", labelKey: "tab.tech" as const, exists: true },
  { id: "05-plan", labelKey: "tab.plan" as const, exists: true },
  { id: "06-tasks", labelKey: "tab.tasks" as const, exists: true },
  { id: "07-gaps", labelKey: "tab.gaps" as const, exists: true },
  { id: "08-verify", labelKey: "tab.verify" as const, exists: true },
];

const MIXED_TABS = [
  { id: "00-request", labelKey: "tab.request" as const, exists: true },
  { id: "01-brainstorm", labelKey: "tab.brainstorm" as const, exists: false },
  { id: "02-design", labelKey: "tab.design" as const, exists: true },
  { id: "03-prd", labelKey: "tab.prd" as const, exists: false },
  { id: "04-tech", labelKey: "tab.tech" as const, exists: true },
  { id: "05-plan", labelKey: "tab.plan" as const, exists: false },
  { id: "06-tasks", labelKey: "tab.tasks" as const, exists: true },
  { id: "07-gaps", labelKey: "tab.gaps" as const, exists: false },
  { id: "08-verify", labelKey: "tab.verify" as const, exists: true },
];

describe("TabStrip", () => {
  let scrollIntoViewMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    scrollIntoViewMock = vi.fn();
    // scrollIntoView is not implemented in jsdom; mock it globally
    window.HTMLElement.prototype.scrollIntoView = scrollIntoViewMock;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("renders all 9 tabs", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(9);
  });

  it("active tab has aria-selected='true' (ARIA contract)", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={ALL_TABS} activeId="03-prd" onSelect={onSelect} />,
    );
    const activeTab = screen.getByRole("tab", { name: "03 prd" });
    expect(activeTab.getAttribute("aria-selected")).toBe("true");
  });

  it("non-active tabs have aria-selected='false'", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={ALL_TABS} activeId="03-prd" onSelect={onSelect} />,
    );
    const inactiveTab = screen.getByRole("tab", { name: "00 request" });
    expect(inactiveTab.getAttribute("aria-selected")).toBe("false");
  });

  it("clicking a tab calls onSelect with correct id", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    fireEvent.click(screen.getByRole("tab", { name: "06 tasks" }));
    expect(onSelect).toHaveBeenCalledTimes(1);
    expect(onSelect).toHaveBeenCalledWith("06-tasks");
  });

  it("scrollIntoView is called on mount for active tab", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={ALL_TABS} activeId="06-tasks" onSelect={onSelect} />,
    );
    // scrollIntoView should have been called once on the active tab
    expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
    expect(scrollIntoViewMock).toHaveBeenCalledWith({
      behavior: "smooth",
      block: "nearest",
      inline: "nearest",
    });
  });

  it("scrollIntoView is called when activeId changes", () => {
    const onSelect = vi.fn();
    const { rerender } = render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    // Clear calls from initial mount
    scrollIntoViewMock.mockClear();

    rerender(
      <TabStrip tabs={ALL_TABS} activeId="08-verify" onSelect={onSelect} />,
    );
    expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
    expect(scrollIntoViewMock).toHaveBeenCalledWith({
      behavior: "smooth",
      block: "nearest",
      inline: "nearest",
    });
  });

  it("container has overflow-x style for horizontal scroll (AC9.g)", () => {
    const onSelect = vi.fn();
    const { container } = render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const tabList = container.querySelector("[role='tablist']");
    expect(tabList).toBeTruthy();
    // overflow-x: auto enables horizontal scrolling
    const style = (tabList as HTMLElement).style.overflowX;
    expect(["auto", "scroll"]).toContain(style);
  });

  it("container uses flex-direction: row (no wrap) (AC9.g)", () => {
    const onSelect = vi.fn();
    const { container } = render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const tabList = container.querySelector("[role='tablist']");
    const style = (tabList as HTMLElement).style;
    // Flex layout with row direction — no wrap
    expect(style.display).toBe("flex");
    expect(style.flexDirection).toBe("row");
    expect(style.flexWrap).not.toBe("wrap");
  });

  it("tabs with exists: false have data-exists='false' attribute", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={MIXED_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const brainstormTab = screen.getByRole("tab", { name: "01 brainstorm" });
    expect(brainstormTab.getAttribute("data-exists")).toBe("false");
  });

  it("tabs with exists: true have data-exists='true' attribute", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={MIXED_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const requestTab = screen.getByRole("tab", { name: "00 request" });
    expect(requestTab.getAttribute("data-exists")).toBe("true");
  });

  it("tabs with exists: false have tooltip 'not yet generated'", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={MIXED_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const prdTab = screen.getByRole("tab", { name: "03 prd" });
    expect(prdTab.title).toBe("not yet generated");
  });

  it("tabs with exists: true have no 'not yet generated' tooltip", () => {
    const onSelect = vi.fn();
    render(
      <TabStrip tabs={MIXED_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const requestTab = screen.getByRole("tab", { name: "00 request" });
    expect(requestTab.title).not.toBe("not yet generated");
  });

  it("no flex-wrap on container (no wrap — AC9.g)", () => {
    const onSelect = vi.fn();
    const { container } = render(
      <TabStrip tabs={ALL_TABS} activeId="00-request" onSelect={onSelect} />,
    );
    const tabList = container.querySelector("[role='tablist']");
    const style = (tabList as HTMLElement).style;
    // flexWrap must not be 'wrap' — no wrapping allowed per AC9.g
    expect(style.flexWrap).not.toBe("wrap");
  });
});
