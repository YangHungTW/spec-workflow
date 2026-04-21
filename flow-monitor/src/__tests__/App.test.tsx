import type { ReactNode } from "react";
import { afterEach, describe, it, expect, vi } from "vitest";
import { cleanup, render, screen, fireEvent, act } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "../App";

// Mock i18n so components using useTranslation render without an I18nProvider in the tree
vi.mock("../i18n", () => ({
  useTranslation: () => ({ t: (key: string) => key, locale: "en", setLocale: () => undefined }),
  I18nProvider: ({ children }: { children: ReactNode }) => children,
}));

// Stub CommandPalette so T111 tests can assert mount/open state without needing
// the generated command_taxonomy that is not available in the jsdom environment.
vi.mock("../components/CommandPalette", () => ({
  CommandPalette: ({ open, onClose }: { open: boolean; onClose: () => void }) =>
    open ? (
      <div data-testid="command-palette" role="dialog">
        <button onClick={onClose}>close</button>
      </div>
    ) : null,
}));

// Stub PreflightToast for the same reason — real implementation imports i18n.
vi.mock("../components/PreflightToast", () => ({
  PreflightToast: ({ command, slug, onDismiss }: { command: string; slug: string; onDismiss: () => void }) => (
    <div data-testid="preflight-toast" role="status" onClick={onDismiss}>
      {command}/{slug}
    </div>
  ),
}));

// Stub invokeStore — replace with controlled state so tests can drive
// preflightCommand without triggering real Tauri IPC.
let _mockPreflightCommand: string | null = null;
let _mockPreflightSlug: string | null = null;
vi.mock("../stores/invokeStore", () => ({
  useInvokeStore: () => ({
    inFlight: new Set<string>(),
    preflightCommand: _mockPreflightCommand,
    preflightSlug: _mockPreflightSlug,
    dispatch: vi.fn(),
  }),
}));

// Stub Tauri event API — MainWindow and PollingFooter call listen() on mount;
// without this mock the test environment throws because the Tauri IPC bridge
// (window.__TAURI_INTERNALS__) is not present in jsdom.
vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn(() => Promise.resolve(() => undefined)),
}));

// Stub Tauri IPC — route by command so MainWindow (list_sessions), Settings (get_settings), and CompactPanel (focus_main_window) all work
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn((cmd: string) => {
    if (cmd === "list_sessions") {
      return Promise.resolve({ sessions: [], repos: [], polling_interval_secs: 3 });
    }
    if (cmd === "focus_main_window") {
      return Promise.resolve();
    }
    return Promise.resolve({
      theme: "light",
      locale: "en",
      polling_interval_secs: 3,
      stale_threshold_mins: 10,
      stalled_threshold_mins: 30,
      notifications_enabled: true,
      repositories: [],
    });
  }),
}));

afterEach(() => {
  cleanup();
  // Reset mock preflight state between tests.
  _mockPreflightCommand = null;
  _mockPreflightSlug = null;
});

describe("App T111 — CommandPalette + PreflightToast overlays + ⌘K keybinding", () => {
  it("CommandPalette is not visible by default", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    expect(document.querySelector("[data-testid='command-palette']")).toBeNull();
  });

  it("⌘K opens the CommandPalette", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    act(() => {
      fireEvent.keyDown(document, { key: "k", metaKey: true });
    });
    expect(document.querySelector("[data-testid='command-palette']")).toBeTruthy();
  });

  it("Ctrl+K opens the CommandPalette", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    act(() => {
      fireEvent.keyDown(document, { key: "k", ctrlKey: true });
    });
    expect(document.querySelector("[data-testid='command-palette']")).toBeTruthy();
  });

  it("Esc closes CommandPalette after it was opened", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    act(() => {
      fireEvent.keyDown(document, { key: "k", metaKey: true });
    });
    expect(document.querySelector("[data-testid='command-palette']")).toBeTruthy();
    act(() => {
      fireEvent.keyDown(document, { key: "Escape" });
    });
    expect(document.querySelector("[data-testid='command-palette']")).toBeNull();
  });

  it("PreflightToast is not visible when preflightCommand is null", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    expect(document.querySelector("[data-testid='preflight-toast']")).toBeNull();
  });
});

describe("App routing", () => {
  it("/ renders MainWindow layout (T17 full view)", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    // T17 replaced the stub; data-testid is the stable selector
    expect(document.querySelector("[data-testid='main-window']")).toBeTruthy();
  });

  it("/repo/:repoId renders MainWindow layout (T17 full view)", () => {
    render(
      <MemoryRouter initialEntries={["/repo/abc"]}>
        <App />
      </MemoryRouter>,
    );
    expect(document.querySelector("[data-testid='main-window']")).toBeTruthy();
  });

  it("/feature/:repoId/:slug renders CardDetail master-detail skeleton (T18)", () => {
    render(
      <MemoryRouter initialEntries={["/feature/abc/my-slug"]}>
        <App />
      </MemoryRouter>,
    );
    // T18 replaced the stub with the full master-detail skeleton
    expect(document.querySelector("[data-testid='card-detail']")).toBeTruthy();
  });

  it("/settings renders Settings view with tablist", () => {
    render(
      <MemoryRouter initialEntries={["/settings"]}>
        <App />
      </MemoryRouter>,
    );
    // Settings is no longer a placeholder — it renders a real tablist
    expect(screen.getByRole("tablist")).toBeTruthy();
  });

  it("/compact renders CompactPanel (T24: stub replaced)", () => {
    // CompactPanel renders an "Open main" button (i18n key returned as-is by mock).
    render(
      <MemoryRouter initialEntries={["/compact"]}>
        <App />
      </MemoryRouter>,
    );
    // The "Open main" button is always rendered regardless of session count.
    expect(screen.getByRole("button", { name: "btn.openMain" })).toBeTruthy();
  });
});
