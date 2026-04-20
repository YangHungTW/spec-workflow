/**
 * Tests for T47: EmptyState wiring in MainWindow
 *
 * When repos.length === 0 (no repos registered), MainWindow must render
 * the full <EmptyState /> component (not a plain text fallback).
 *
 * When repos.length > 0 but sortedSessions.length === 0, MainWindow
 * keeps the minimal "no sessions" message (different state).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";

// Mock i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    locale: "en",
    setLocale: vi.fn(),
  }),
  I18nProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock Tauri IPC
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

// Mock @tauri-apps/api/event
const mockUnlisten = vi.fn();
vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn(() => Promise.resolve(mockUnlisten)),
}));

// Mock themeStore
vi.mock("../../stores/themeStore", () => ({
  useTheme: () => ({
    theme: "light",
    setTheme: vi.fn(),
    toggleTheme: vi.fn(),
  }),
  applyThemeToDocument: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import MainWindow from "../MainWindow";

const mockInvoke = vi.mocked(invoke);

function setupNoRepos() {
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "list_sessions") {
      return Promise.resolve({ sessions: [], polling_interval_secs: 3 });
    }
    if (cmd === "get_settings") {
      return Promise.resolve({
        repos: [],
        polling_interval_secs: 3,
        collapsed_repo_ids: [],
      });
    }
    return Promise.resolve(undefined);
  });
}

function setupWithReposNoSessions() {
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "list_sessions") {
      return Promise.resolve({ sessions: [], polling_interval_secs: 3 });
    }
    if (cmd === "get_settings") {
      return Promise.resolve({
        repos: [{ id: "r1", name: "my-repo", path: "/repos/my-repo" }],
        polling_interval_secs: 3,
        collapsed_repo_ids: [],
      });
    }
    return Promise.resolve(undefined);
  });
}

describe("MainWindow EmptyState wiring (T47)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders <EmptyState /> (empty.cta button) when repos.length === 0", async () => {
    setupNoRepos();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // EmptyState renders a CTA button with t("empty.cta") — key is returned as-is in tests
    const ctaBtn = screen.queryByRole("button", { name: "empty.cta" });
    expect(ctaBtn).toBeTruthy();
  });

  it("renders empty.body text when repos.length === 0", async () => {
    setupNoRepos();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    expect(screen.queryByText("empty.body")).toBeTruthy();
  });

  it("renders notification-prompt when repos.length === 0", async () => {
    setupNoRepos();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    expect(screen.queryByTestId("notification-prompt")).toBeTruthy();
  });

  it("does NOT render empty.body when repos exist but sessions empty", async () => {
    setupWithReposNoSessions();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // EmptyState body should NOT appear — this is the "no sessions" state, not "no repos"
    expect(screen.queryByText("empty.body")).toBeNull();
    // The minimal empty message should be shown instead
    expect(screen.queryByText("empty.title")).toBeTruthy();
  });

  it("sidebar remains visible when repos.length === 0", async () => {
    setupNoRepos();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // Sidebar is always visible — compact-toggle and settings-btn are in sidebar
    expect(screen.queryByTestId("compact-toggle")).toBeTruthy();
    expect(screen.queryByTestId("settings-btn")).toBeTruthy();
  });
});
