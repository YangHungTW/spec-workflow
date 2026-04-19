import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// Stub i18n for stub tests
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    locale: "en",
    setLocale: vi.fn(),
  }),
  I18nProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Stub Tauri event API — MainWindow and PollingFooter call listen() on mount.
vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn(() => Promise.resolve(() => undefined)),
}));

// Stub Tauri IPC — route by command so MainWindow (list_sessions) and Settings (get_settings) both work
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

// MainWindow, CardDetail (T18 master-detail), Settings still have stub/smoke tests here.
// EmptyState and CompactPanel replaced by T24 — full tests in their own files.
import MainWindow from "../MainWindow";
import CardDetail from "../CardDetail";
import Settings from "../Settings";
import { I18nProvider } from "../../i18n";
import { MemoryRouter, Route, Routes } from "react-router-dom";

describe("Route stub placeholders", () => {
  it("MainWindow renders the main window layout (T17 replaced stub)", () => {
    render(<MainWindow />);
    // T17 replaced the stub; verify the layout container renders without crashing
    const main = document.querySelector("[data-testid='main-window']");
    expect(main).toBeTruthy();
  });

  it("CardDetail renders master-detail skeleton (T18 replaced stub)", () => {
    // CardDetail requires Router context (uses useNavigate/useParams)
    render(
      <MemoryRouter initialEntries={["/feature/my-repo/my-feature"]}>
        <Routes>
          <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
        </Routes>
      </MemoryRouter>,
    );
    // T18 replaced the stub; verify the detail container renders
    const detail = document.querySelector("[data-testid='card-detail']");
    expect(detail).toBeTruthy();
  });

  it("Settings renders without crashing (no longer a stub)", () => {
    render(
      <I18nProvider>
        <Settings />
      </I18nProvider>,
    );
    // Settings renders a tablist — verify it mounts without throwing
    expect(document.body).toBeTruthy();
  });
});
