import { afterEach, describe, it, expect, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "../App";

// CompactPanel and EmptyState now use useTranslation (T24 — stubs replaced).
// Mock i18n so App.test.tsx renders without an I18nProvider in the tree.
vi.mock("../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

// CompactPanel invokes focus_main_window IPC; mock the Tauri core.
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

afterEach(() => cleanup());

describe("App routing", () => {
  it("/ renders MainWindow placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("MainWindow")).toBeTruthy();
  });

  it("/repo/:repoId renders MainWindow placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/repo/abc"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("MainWindow")).toBeTruthy();
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
