/**
 * Tests for CardDetailHeader component
 *
 * T18 (original):
 *   AC9.a — header shows <repo>/<slug> title
 *   AC9.j — static stalled badge in header (no animation)
 *
 * T107 additions:
 *   AC3.a — Advance + Message buttons hidden when nextStage(stage) === null
 *            (session at "archive" — no valid next stage)
 *   AC3.b — Advance click triggers invokeStore.dispatch with next stage
 *   AC3.c — Message / Choice click toggles inline SendPanel visibility
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { CardDetailHeader } from "../CardDetailHeader";
import type { InvokeStore } from "../../stores/invokeStore";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "btn.openInFinder": "Open in Finder",
        "btn.copyPath": "Copy path",
        "btn.back": "Back",
        "action.advance_to.gap-check": "Advance to gap-check",
        "action.message": "Message / Choice",
        "stage.implement": "implement",
        "stage.gap-check": "gap-check",
        "stage.archive": "archive",
        "idle.stalled": "Stalled",
        "idle.stale": "Stale",
        "idle.none": "none",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Stub Tauri IPC
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(undefined),
}));

// Stub SendPanel so it renders a predictable test ID
vi.mock("../SendPanel", () => ({
  SendPanel: () => <div data-testid="send-panel-stub" />,
}));

function makeInvokeStore(overrides?: Partial<InvokeStore>): InvokeStore {
  return {
    inFlight: new Set<string>(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

const BASE_PROPS = {
  repoId: "my-repo",
  slug: "my-feature",
  stage: "implement" as const,
  idleState: "none" as const,
  featurePath: "/Users/alice/projects/my-repo/.specaffold/features/my-feature",
  onBack: vi.fn(),
  invokeStore: makeInvokeStore(),
};

describe("CardDetailHeader", () => {
  it("renders repo/slug title (AC9.a)", () => {
    render(<CardDetailHeader {...BASE_PROPS} />);
    expect(screen.getByText("my-repo/my-feature")).toBeTruthy();
  });

  it("renders the stage pill", () => {
    render(<CardDetailHeader {...BASE_PROPS} />);
    expect(screen.getByText("implement")).toBeTruthy();
  });

  it("Open in Finder invokes IPC open_in_finder with featurePath", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    const mockInvoke = vi.mocked(invoke);
    mockInvoke.mockResolvedValue(undefined);

    render(<CardDetailHeader {...BASE_PROPS} />);
    const btn = screen.getByRole("button", { name: /open in finder/i });
    fireEvent.click(btn);

    expect(mockInvoke).toHaveBeenCalledWith("open_in_finder", {
      path: BASE_PROPS.featurePath,
    });
  });

  it("Copy path writes featurePath to clipboard", () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText },
      writable: true,
      configurable: true,
    });

    render(<CardDetailHeader {...BASE_PROPS} />);
    const btn = screen.getByRole("button", { name: /copy path/i });
    fireEvent.click(btn);

    expect(writeText).toHaveBeenCalledWith(BASE_PROPS.featurePath);
  });

  it("back button calls onBack", () => {
    const onBack = vi.fn();
    render(<CardDetailHeader {...BASE_PROPS} onBack={onBack} />);
    const backBtn = screen.getByRole("button", { name: /back/i });
    fireEvent.click(backBtn);
    expect(onBack).toHaveBeenCalledOnce();
  });

  it("back button aria-label uses t(btn.back) — i18n (style fix)", () => {
    render(<CardDetailHeader {...BASE_PROPS} />);
    const backBtn = screen.getByRole("button", { name: "Back" });
    expect(backBtn).toBeTruthy();
    expect(backBtn.getAttribute("aria-label")).toBe("Back");
  });

  it("renders idle badge when idleState is stalled (AC9.j)", () => {
    render(<CardDetailHeader {...BASE_PROPS} idleState="stalled" />);
    expect(screen.getByText("Stalled")).toBeTruthy();
  });

  it("stalled badge has no animation or transition style (AC9.j static check)", () => {
    render(<CardDetailHeader {...BASE_PROPS} idleState="stalled" />);
    const badge = document.querySelector(".idle-badge");
    if (badge) {
      const style = (badge as HTMLElement).style;
      // Static badge — no inline animation or transition set
      expect(style.animation).toBeFalsy();
      expect(style.transition).toBeFalsy();
    }
  });

  // --- T107: Advance + Message buttons ---

  describe("Advance and Message / Choice buttons", () => {
    it("(AC3.a) both buttons hidden when nextStage returns null — stage is archive", () => {
      render(<CardDetailHeader {...BASE_PROPS} stage="archive" />);
      // When stage is archive, no advance_to.* or action.message button should render.
      expect(
        screen.queryByRole("button", { name: /advance to|message \/ choice/i }),
      ).toBeNull();
    });

    it("both buttons visible when nextStage is non-null — stage is implement", () => {
      render(<CardDetailHeader {...BASE_PROPS} stage="implement" />);
      // action.advance_to.gap-check → "Advance to gap-check" via mock
      expect(
        screen.getByRole("button", { name: /advance to gap-check/i }),
      ).toBeTruthy();
      // action.message → "Message / Choice" via mock
      expect(
        screen.getByRole("button", { name: /message \/ choice/i }),
      ).toBeTruthy();
    });

    it("(AC3.b) Advance click calls invokeStore.dispatch with next stage, slug, repoId, card-detail, terminal", () => {
      const invokeStore = makeInvokeStore();
      render(<CardDetailHeader {...BASE_PROPS} stage="implement" invokeStore={invokeStore} />);
      const btn = screen.getByRole("button", { name: /advance to gap-check/i });
      fireEvent.click(btn);
      // implement → gap-check is the next stage
      expect(invokeStore.dispatch).toHaveBeenCalledWith(
        "gap-check",
        "my-feature",
        "my-repo",
        "card-detail",
        "terminal",
      );
    });

    it("(AC3.c) Message / Choice click shows SendPanel", () => {
      render(<CardDetailHeader {...BASE_PROPS} stage="implement" />);
      expect(screen.queryByTestId("send-panel-stub")).toBeNull();
      const btn = screen.getByRole("button", { name: /message \/ choice/i });
      fireEvent.click(btn);
      expect(screen.getByTestId("send-panel-stub")).toBeTruthy();
    });

    it("(AC3.c) second Message / Choice click hides SendPanel", () => {
      render(<CardDetailHeader {...BASE_PROPS} stage="implement" />);
      const btn = screen.getByRole("button", { name: /message \/ choice/i });
      fireEvent.click(btn);
      expect(screen.getByTestId("send-panel-stub")).toBeTruthy();
      fireEvent.click(btn);
      expect(screen.queryByTestId("send-panel-stub")).toBeNull();
    });
  });
});
