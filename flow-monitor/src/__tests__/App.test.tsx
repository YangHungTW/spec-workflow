import { afterEach, describe, it, expect, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "../App";

// Stub Tauri IPC so MainWindow can render without a Tauri webview
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue({ sessions: [], repos: [], polling_interval_secs: 3 }),
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

  it("/settings renders Settings placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/settings"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("Settings")).toBeTruthy();
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
