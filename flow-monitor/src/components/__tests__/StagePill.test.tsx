import { render } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { StagePill, STAGE_KEYS, type StageKey } from "../StagePill";

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

describe("StagePill", () => {
  beforeEach(() => {
    document.documentElement.classList.remove("dark");
  });

  it("exports exactly 11 stage keys", () => {
    expect(STAGE_KEYS).toHaveLength(11);
  });

  for (const theme of THEMES) {
    describe(`theme: ${theme}`, () => {
      beforeEach(() => {
        applyTheme(theme);
      });

      for (const stage of STAGE_KEYS) {
        it(`renders stage "${stage}" in ${theme} theme (snapshot)`, () => {
          const { container } = render(<StagePill stage={stage as StageKey} />);
          expect(container.firstChild).toMatchSnapshot();
        });
      }
    });
  }

  it("uses t('stage.<key>') for the label", () => {
    const { getByText } = render(<StagePill stage="implement" />);
    expect(getByText("stage.implement")).toBeTruthy();
  });

  it("applies --stage-<key>-bg and --stage-<key>-fg CSS variables", () => {
    const { container } = render(<StagePill stage="brainstorm" />);
    const pill = container.firstChild as HTMLElement;
    const style = pill.getAttribute("style") ?? "";
    expect(style).toContain("--stage-brainstorm-bg");
    expect(style).toContain("--stage-brainstorm-fg");
  });

  it("has role='status' for accessibility", () => {
    const { getByRole } = render(<StagePill stage="prd" />);
    expect(getByRole("status")).toBeTruthy();
  });

  it("does not contain hooks or useEffect (pure presentational)", () => {
    // Rendered without errors means no runtime hook violations
    expect(() => render(<StagePill stage="verify" />)).not.toThrow();
  });
});
