/**
 * Tests for T17: SessionCard component
 *
 * AC7.a — 6 elements per card: slug, stage pill, relative time, idle badge,
 *          note excerpt (≤80 chars), hover actions
 * AC7.d — hover actions are EXACTLY "Open in Finder" + "Copy path" (no others)
 * B2 boundary — NO "Send instruction", "Advance stage", or "Edit" action
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SessionCard, type SessionCardProps } from "../SessionCard";

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
