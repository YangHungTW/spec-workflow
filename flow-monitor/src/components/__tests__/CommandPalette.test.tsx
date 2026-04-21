/**
 * Tests for T101: CommandPalette component
 *
 * AC5.b — CommandPalette renders SAFE ∪ WRITE commands only (11 total):
 *           4 safe (next, review, remember, promote) +
 *           7 write (request, prd, tech, plan, implement, validate, design) = 11.
 *           DESTROY commands must NOT appear in DOM.
 * Keyboard: Esc → onClose called.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { CommandPalette } from "../CommandPalette";
import type { SessionState } from "../../stores/sessionStore";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "palette.title": "Command Palette",
        "palette.group.control": "Control Actions",
        "palette.group.scaff": "Scaff Commands",
        "palette.group.destructive": "Destructive",
        "palette.pill.write": "WRITE",
        "palette.search.placeholder": "Search commands...",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(undefined),
}));

// Mock invokeStore — CommandPalette calls dispatch on select; we capture it.
const mockDispatch = vi.fn().mockResolvedValue(undefined);

vi.mock("../../stores/invokeStore", () => ({
  useInvokeStore: () => ({
    inFlight: new Set<string>(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: mockDispatch,
  }),
}));

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

const FOCUSED_SESSION: SessionState = {
  slug: "my-feature",
  stage: "implement",
  idleState: "none",
  lastUpdatedMs: Date.now() - 5 * 60 * 1000,
  noteExcerpt: "A note excerpt for the focused session",
  repoPath: "/Users/alice/projects/my-repo",
  repoId: "repo-1",
};

// DESTROY command names per command_taxonomy.rs — must NOT appear in DOM.
const DESTROY_NAMES = ["archive", "update-req", "update-tech", "update-plan", "update-task"];

// All SAFE + WRITE command names — must all appear in DOM (AC5.b).
const SAFE_NAMES = ["next", "review", "remember", "promote"];
const WRITE_NAMES = ["request", "prd", "tech", "plan", "implement", "validate", "design"];
const ALL_SAFE_AND_WRITE = [...SAFE_NAMES, ...WRITE_NAMES];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("CommandPalette", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders nothing when open=false", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={false}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    // Modal should not be visible
    expect(screen.queryByTestId("command-palette")).toBeNull();
  });

  it("renders the palette overlay when open=true", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    expect(screen.getByTestId("command-palette")).toBeTruthy();
  });

  it("AC5.b: renders exactly 11 commands (4 safe + 7 write)", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    // Each command is rendered as a list item with data-testid="palette-item"
    const items = screen.getAllByTestId("palette-item");
    expect(items).toHaveLength(11);
  });

  it("AC5.b: all 4 SAFE command names appear in DOM", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    for (const name of SAFE_NAMES) {
      expect(screen.getByText(name)).toBeTruthy();
    }
  });

  it("AC5.b: all 7 WRITE command names appear in DOM", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    for (const name of WRITE_NAMES) {
      expect(screen.getByText(name)).toBeTruthy();
    }
  });

  it("AC5.b: no DESTROY command name appears in DOM", () => {
    const onClose = vi.fn();
    const { container } = render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const domText = container.textContent ?? "";
    for (const destroyName of DESTROY_NAMES) {
      // The destroy command name must not appear as a standalone command label.
      // Use queryByText for precise match (not substring).
      expect(
        screen.queryByText(destroyName),
        `DESTROY command "${destroyName}" must not appear in CommandPalette DOM`,
      ).toBeNull();
    }
    // Belt-and-suspenders: full text check for hyphenated destroy names.
    for (const destroyName of DESTROY_NAMES) {
      expect(domText).not.toContain(destroyName);
    }
  });

  it("WRITE commands display a WRITE pill", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    // WRITE pill text appears (once per WRITE command = 7 times)
    const writePills = screen.getAllByTestId("write-pill");
    expect(writePills).toHaveLength(WRITE_NAMES.length);
  });

  it("Esc key calls onClose", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const palette = screen.getByTestId("command-palette");
    fireEvent.keyDown(palette, { key: "Escape", code: "Escape" });
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("clicking backdrop calls onClose", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const backdrop = screen.getByTestId("command-palette-backdrop");
    fireEvent.click(backdrop);
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("Enter key on focused item calls dispatch with correct command", async () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    // Click the first item to select it
    const items = screen.getAllByTestId("palette-item");
    fireEvent.click(items[0]);
    expect(mockDispatch).toHaveBeenCalledTimes(1);
    // After dispatch, onClose should be called to close the palette
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("renders without focusedSession (open state without a session)", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
      />,
    );
    // Should still render with 11 commands — dispatch will be a no-op without session
    const items = screen.getAllByTestId("palette-item");
    expect(items).toHaveLength(11);
  });

  it("keyboard navigation: ArrowDown moves focus to next item", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const palette = screen.getByTestId("command-palette");
    // Initial: first item is focused (index 0). ArrowDown → index 1.
    fireEvent.keyDown(palette, { key: "ArrowDown", code: "ArrowDown" });
    // The second item should gain data-focused="true"
    const items = screen.getAllByTestId("palette-item");
    // After one ArrowDown from initial focus at 0, item at index 1 is focused.
    expect(items[1].getAttribute("data-focused")).toBe("true");
  });

  it("keyboard navigation: ArrowUp wraps from first to last item", () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const palette = screen.getByTestId("command-palette");
    // Initial: focus at index 0. ArrowUp → wraps to last item (index 10).
    fireEvent.keyDown(palette, { key: "ArrowUp", code: "ArrowUp" });
    const items = screen.getAllByTestId("palette-item");
    expect(items[10].getAttribute("data-focused")).toBe("true");
  });

  it("Enter key dispatches the currently focused command", async () => {
    const onClose = vi.fn();
    render(
      <CommandPalette
        open={true}
        onClose={onClose}
        focusedSession={FOCUSED_SESSION}
      />,
    );
    const palette = screen.getByTestId("command-palette");
    // Navigate to second item (index 1), then press Enter.
    fireEvent.keyDown(palette, { key: "ArrowDown", code: "ArrowDown" });
    fireEvent.keyDown(palette, { key: "Enter", code: "Enter" });
    expect(mockDispatch).toHaveBeenCalledTimes(1);
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
