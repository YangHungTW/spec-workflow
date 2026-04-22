/**
 * Tests for T17: SessionCard component
 *
 * AC7.a — 6 elements per card: slug, stage pill, relative time, idle badge,
 *          note excerpt (≤80 chars), hover actions
 * AC7.d — hover actions are EXACTLY "Open in Finder" + "Copy path" (no others)
 * B2 boundary — NO "Send instruction", "Advance stage", or "Edit" action
 *
 * T106 additions (AC2.b):
 *   - ActionStrip renders when idleState === "stalled" + session + invokeStore
 *   - ActionStrip does NOT render when idleState !== "stalled"
 *   - onAdvance wires to invokeStore.dispatch with correct args
 *   - onMessage wires to onClick (Card Detail navigation)
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SessionCard, type SessionCardProps } from "../SessionCard";
import type { SessionState } from "../../stores/sessionStore";
import type { InvokeStore } from "../../stores/invokeStore";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "btn.openInFinder": "Open in Finder",
        "btn.copyPath": "Copy path",
        "stage.implement": "implement",
        "idle.stale": "Stale",
        "idle.none": "none",
        "idle.stalled": "Stalled",
        // T106: ActionStrip i18n keys (implement → gap-check is the next stage)
        "action.advance_to.gap-check": "Advance to gap-check",
        "action.message": "Message / Choice",
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

const BASE_PROPS: SessionCardProps = {
  slug: "my-feature",
  stage: "implement",
  idleState: "none",
  lastUpdatedMs: Date.now() - 5 * 60 * 1000, // 5 min ago
  noteExcerpt: "First 80 chars of the newest note line goes here for display",
  repoPath: "/Users/alice/projects/my-repo",
};

/** Minimal InvokeStore mock — dispatch is a spy. */
function makeInvokeStore(): InvokeStore {
  return {
    inFlight: new Set(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: vi.fn().mockResolvedValue(undefined),
  };
}

const STALLED_SESSION: SessionState = {
  slug: "my-feature",
  stage: "implement",
  idleState: "stalled",
  lastUpdatedMs: Date.now() - 60 * 60 * 1000,
  noteExcerpt: "Stalled note",
  repoPath: "/Users/alice/projects/my-repo",
  repoId: "my-repo",
};

describe("SessionCard", () => {
  it("renders the slug", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(screen.getByText("my-feature")).toBeTruthy();
  });

  it("renders the stage pill", () => {
    render(<SessionCard {...BASE_PROPS} />);
    // StagePill emits t("stage.implement") = "implement"
    expect(screen.getByText("implement")).toBeTruthy();
  });

  it("renders relative time text", () => {
    render(<SessionCard {...BASE_PROPS} />);
    // Should show something like "5m ago" or similar relative time
    const timeEl = document.querySelector("[data-testid='relative-time']");
    expect(timeEl).toBeTruthy();
  });

  it("renders the idle badge element", () => {
    render(<SessionCard {...BASE_PROPS} idleState="stale" />);
    expect(screen.getByText("Stale")).toBeTruthy();
  });

  it("renders the note excerpt", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(
      screen.getByText(
        "First 80 chars of the newest note line goes here for display",
      ),
    ).toBeTruthy();
  });

  it("truncates note excerpt to ≤80 chars if passed longer text", () => {
    const longNote =
      "This is a very long note that exceeds eighty characters and should be truncated by the component";
    render(<SessionCard {...BASE_PROPS} noteExcerpt={longNote} />);
    const noteEl = document.querySelector("[data-testid='note-excerpt']");
    expect(noteEl).toBeTruthy();
    expect((noteEl as HTMLElement).textContent!.length).toBeLessThanOrEqual(80);
  });

  it("shows hover actions: exactly 2 buttons — Open in Finder + Copy path", () => {
    const { container } = render(<SessionCard {...BASE_PROPS} />);
    // Make the card appear hovered by adding class (or just check rendered buttons)
    // Hover actions should be present in DOM (visibility controlled by CSS)
    const buttons = screen.getAllByRole("button", {
      name: /open in finder|copy path/i,
    });
    expect(buttons).toHaveLength(2);
  });

  it("does NOT render Send instruction, Advance stage, or Edit buttons (B2 boundary)", () => {
    render(<SessionCard {...BASE_PROPS} />);
    expect(
      screen.queryByRole("button", {
        name: /send instruction|advance stage|edit/i,
      }),
    ).toBeNull();
  });

  it("Open in Finder button invokes IPC open_in_finder with repoPath", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    const mockInvoke = vi.mocked(invoke);
    mockInvoke.mockResolvedValue(undefined);

    render(<SessionCard {...BASE_PROPS} />);
    const btn = screen.getByRole("button", { name: /open in finder/i });
    fireEvent.click(btn);

    expect(mockInvoke).toHaveBeenCalledWith("open_in_finder", {
      path: BASE_PROPS.repoPath,
    });
  });

  it("Copy path button writes to clipboard", () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText },
      writable: true,
      configurable: true,
    });

    render(<SessionCard {...BASE_PROPS} />);
    const btn = screen.getByRole("button", { name: /copy path/i });
    fireEvent.click(btn);

    expect(writeText).toHaveBeenCalledWith(BASE_PROPS.repoPath);
  });

  it("all 6 required elements are present", () => {
    render(<SessionCard {...BASE_PROPS} idleState="stale" />);
    // 1. slug
    expect(screen.getByText("my-feature")).toBeTruthy();
    // 2. stage pill
    expect(screen.getByText("implement")).toBeTruthy();
    // 3. relative time
    expect(document.querySelector("[data-testid='relative-time']")).toBeTruthy();
    // 4. idle badge
    expect(screen.getByText("Stale")).toBeTruthy();
    // 5. note excerpt
    expect(
      screen.getByText(
        "First 80 chars of the newest note line goes here for display",
      ),
    ).toBeTruthy();
    // 6. hover actions (2 buttons)
    const buttons = screen.getAllByRole("button", {
      name: /open in finder|copy path/i,
    });
    expect(buttons).toHaveLength(2);
  });
});

describe("SessionCard — T10 AgentPill integration (AC9)", () => {
  it("renders AgentPill with role 'developer' for stage 'implement'", () => {
    const { container } = render(<SessionCard {...BASE_PROPS} stage="implement" />);
    const pill = container.querySelector(".agent-pill") as HTMLElement;
    expect(pill).not.toBeNull();
    expect(pill.getAttribute("data-role")).toBe("developer");
    expect(pill.getAttribute("data-color")).toBe("green");
  });

  it("pre-existing elements remain present alongside AgentPill (AC24 guard)", () => {
    render(<SessionCard {...BASE_PROPS} stage="implement" idleState="stale" hasUi />);
    // stage pill
    expect(screen.getByText("implement")).toBeTruthy();
    // note excerpt
    expect(
      screen.getByText(
        "First 80 chars of the newest note line goes here for display",
      ),
    ).toBeTruthy();
    // UI badge
    expect(document.querySelector("[data-testid='ui-badge']")).toBeTruthy();
  });
});

describe("SessionCard — T106 ActionStrip gate (AC2.b)", () => {
  it("renders ActionStrip when idleState is stalled and session + invokeStore are provided", () => {
    const invokeStore = makeInvokeStore();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="stalled"
        session={STALLED_SESSION}
        invokeStore={invokeStore}
      />,
    );
    // ActionStrip's primary button — implement → gap-check is the next stage
    expect(screen.getByRole("button", { name: /advance to gap-check/i })).toBeTruthy();
  });

  it("does NOT render ActionStrip when idleState is not stalled (AC2.b)", () => {
    const invokeStore = makeInvokeStore();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="none"
        session={{ ...STALLED_SESSION, idleState: "none" }}
        invokeStore={invokeStore}
      />,
    );
    expect(
      screen.queryByRole("button", { name: /advance to/i }),
    ).toBeNull();
  });

  it("does NOT render ActionStrip when idleState is stale (AC2.b)", () => {
    const invokeStore = makeInvokeStore();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="stale"
        session={{ ...STALLED_SESSION, idleState: "stale" }}
        invokeStore={invokeStore}
      />,
    );
    expect(
      screen.queryByRole("button", { name: /advance to/i }),
    ).toBeNull();
  });

  it("onAdvance calls invokeStore.dispatch with nextStage command, slug, repoPath, card-action, terminal", async () => {
    const invokeStore = makeInvokeStore();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="stalled"
        session={STALLED_SESSION}
        invokeStore={invokeStore}
      />,
    );
    // implement → next stage is gap-check
    const advanceBtn = screen.getByRole("button", { name: /advance to gap-check/i });
    fireEvent.click(advanceBtn);
    expect(invokeStore.dispatch).toHaveBeenCalledWith(
      "gap-check",
      STALLED_SESSION.slug,
      STALLED_SESSION.repoPath,
      "card-action",
      "terminal",
    );
  });

  it("onMessage calls onClick (Card Detail navigation)", () => {
    const invokeStore = makeInvokeStore();
    const onClick = vi.fn();
    render(
      <SessionCard
        {...BASE_PROPS}
        idleState="stalled"
        session={STALLED_SESSION}
        invokeStore={invokeStore}
        onClick={onClick}
      />,
    );
    // "Message / Choice" is the ActionStrip secondary button label.
    // Use getAllByRole and filter to the <button> element (not the <article role="button">).
    const messageBtns = screen.getAllByRole("button", { name: /message \/ choice/i });
    const messageBtn = messageBtns.find((el) => el.tagName === "BUTTON");
    expect(messageBtn).toBeTruthy();
    fireEvent.click(messageBtn!);
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("ActionStrip does not render when session prop is absent (no stalled data)", () => {
    render(<SessionCard {...BASE_PROPS} idleState="stalled" />);
    expect(
      screen.queryByRole("button", { name: /advance to/i }),
    ).toBeNull();
  });
});
