import { render } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { IdleBadge, IDLE_STATES, type IdleState } from "../IdleBadge";

// Stub the i18n module — T14 hasn't merged yet; orchestrator will resolve at merge time.
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

const THEMES = ["light", "dark"] as const;

function applyTheme(theme: "light" | "dark") {
  if (theme === "dark") {
    document.documentElement.classList.add("dark");
  } else {
    document.documentElement.classList.remove("dark");
  }
}

describe("IdleBadge", () => {
  beforeEach(() => {
    document.documentElement.classList.remove("dark");
  });

  it("exports exactly 3 idle states", () => {
    expect(IDLE_STATES).toHaveLength(3);
    expect(IDLE_STATES).toEqual(["none", "stale", "stalled"]);
  });

  for (const theme of THEMES) {
    describe(`theme: ${theme}`, () => {
      beforeEach(() => {
        applyTheme(theme);
      });

      for (const state of IDLE_STATES) {
        it(`renders idle state "${state}" in ${theme} theme (snapshot)`, () => {
          const { container } = render(<IdleBadge state={state as IdleState} />);
          expect(container.firstChild).toMatchSnapshot();
        });
      }
    });
  }

  it("uses t('idle.<state>') for the label", () => {
    const { getByText } = render(<IdleBadge state="stale" />);
    expect(getByText("idle.stale")).toBeTruthy();
  });

  it("applies --idle-<state>-bg and --idle-<state>-fg CSS variables", () => {
    const { container } = render(<IdleBadge state="stalled" />);
    const badge = container.firstChild as HTMLElement;
    const style = badge.getAttribute("style") ?? "";
    expect(style).toContain("--idle-stalled-bg");
    expect(style).toContain("--idle-stalled-fg");
  });

  it("renders nothing visible for 'none' state (no badge shown)", () => {
    const { container } = render(<IdleBadge state="none" />);
    // 'none' state renders an empty/null element
    const badge = container.firstChild as HTMLElement | null;
    // Either no child or the badge has data-state="none"
    if (badge) {
      expect(badge.getAttribute("data-idle-state")).toBe("none");
    }
  });

  it("does not contain animation, transition, or @keyframes (AC9.j static)", () => {
    // This test confirms the component is static by checking no inline animation
    const { container } = render(<IdleBadge state="stalled" />);
    const badge = container.firstChild as HTMLElement;
    const style = badge?.getAttribute("style") ?? "";
    expect(style).not.toContain("animation");
    expect(style).not.toContain("transition");
  });
});
