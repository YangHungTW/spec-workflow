/**
 * Tests for T45: MainWindow chrome additions
 *
 * ACs covered:
 *   T45.1 — Settings (⚙) link in toolbar navigates to /settings
 *   T45.2 — Theme toggle button visible in toolbar, toggles via useTheme
 *   T45.3 — Settings page has a back button that navigates to /
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, act, fireEvent } from "@testing-library/react";
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
const mockToggleTheme = vi.fn();
vi.mock("../../stores/themeStore", () => ({
  useTheme: () => ({
    theme: "light",
    setTheme: vi.fn(),
    toggleTheme: mockToggleTheme,
  }),
  applyThemeToDocument: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import MainWindow from "../MainWindow";
import Settings from "../Settings";

const mockInvoke = vi.mocked(invoke);

function setupInvokeMock() {
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "list_sessions") {
      return Promise.resolve({ sessions: [], polling_interval_secs: 3 });
    }
    if (cmd === "get_settings") {
      return Promise.resolve({
        repos: [],
        polling_interval_secs: 3,
        collapsed_repo_ids: [],
        theme: "light",
        locale: "en",
        stale_threshold_mins: 10,
        stalled_threshold_mins: 30,
        notifications_enabled: true,
        repositories: [],
      });
    }
    return Promise.resolve(undefined);
  });
}

describe("MainWindow chrome — Settings button (T45.1)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockToggleTheme.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders a Settings button (btn.settings) in the toolbar", async () => {
    setupInvokeMock();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // btn.settings i18n key — in test env t() returns the key itself
    const settingsBtn = screen.queryByTestId("settings-btn");
    expect(settingsBtn).toBeTruthy();
  });

  it("clicking Settings button navigates to /settings", async () => {
    setupInvokeMock();
    const navigatedPaths: string[] = [];

    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
            <Route
              path="/settings"
              element={<div data-testid="settings-page">Settings</div>}
            />
          </Routes>
        </MemoryRouter>,
      );
    });

    const settingsBtn = screen.getByTestId("settings-btn");
    await act(async () => {
      fireEvent.click(settingsBtn);
    });

    // After navigation, /settings route should render
    expect(screen.queryByTestId("settings-page")).toBeTruthy();
  });
});

describe("MainWindow chrome — Theme toggle button (T45.2 / T48.5)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockToggleTheme.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders a theme toggle button in the sidebar (moved from toolbar in T48)", async () => {
    setupInvokeMock();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // T48 moved theme toggle into RepoSidebar; testid is now sidebar-theme-toggle
    const themeBtn = screen.queryByTestId("sidebar-theme-toggle");
    expect(themeBtn).toBeTruthy();
  });

  it("clicking theme toggle calls toggleTheme", async () => {
    setupInvokeMock();
    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<MainWindow />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // T48 moved theme toggle into RepoSidebar; testid is now sidebar-theme-toggle
    const themeBtn = screen.getByTestId("sidebar-theme-toggle");
    await act(async () => {
      fireEvent.click(themeBtn);
    });

    expect(mockToggleTheme).toHaveBeenCalledTimes(1);
  });
});

describe("Settings page — back button (T45.3)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders a back button on the Settings page", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") return Promise.resolve({
        theme: "light",
        locale: "en",
        polling_interval_secs: 3,
        stale_threshold_mins: 10,
        stalled_threshold_mins: 30,
        notifications_enabled: true,
        repositories: [],
      });
      return Promise.resolve({});
    });

    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/settings"]}>
          <Routes>
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    // btn.back i18n key — in test env t() returns the key itself
    const backBtn = screen.queryByTestId("back-btn");
    expect(backBtn).toBeTruthy();
  });

  it("clicking back button navigates to /", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") return Promise.resolve({
        theme: "light",
        locale: "en",
        polling_interval_secs: 3,
        stale_threshold_mins: 10,
        stalled_threshold_mins: 30,
        notifications_enabled: true,
        repositories: [],
      });
      return Promise.resolve({});
    });

    await act(async () => {
      render(
        <MemoryRouter initialEntries={["/settings"]}>
          <Routes>
            <Route path="/" element={<div data-testid="main-page">Main</div>} />
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </MemoryRouter>,
      );
    });

    const backBtn = screen.getByTestId("back-btn");
    await act(async () => {
      fireEvent.click(backBtn);
    });

    expect(screen.queryByTestId("main-page")).toBeTruthy();
  });
});
