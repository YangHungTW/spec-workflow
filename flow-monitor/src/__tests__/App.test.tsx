import { afterEach, describe, it, expect, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "../App";

// Stub Tauri IPC — route by command so both MainWindow (list_sessions) and Settings (get_settings) can render
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn((cmd: string) => {
    if (cmd === "list_sessions") {
      return Promise.resolve({ sessions: [], repos: [], polling_interval_secs: 3 });
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

afterEach(() => cleanup());

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

  it("/feature/:repoId/:slug renders CardDetail placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/feature/abc/my-slug"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("CardDetail")).toBeTruthy();
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

  it("/compact renders CompactPanel placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/compact"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("CompactPanel")).toBeTruthy();
  });
});
