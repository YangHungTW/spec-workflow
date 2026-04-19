import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// These imports will fail (red) until the stub files exist.
import MainWindow from "../MainWindow";
import CardDetail from "../CardDetail";
import Settings from "../Settings";
import EmptyState from "../EmptyState";
import CompactPanel from "../CompactPanel";
import { I18nProvider } from "../../i18n";

// Settings is no longer a stub — it uses IPC and i18n; mock for this smoke test.
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue({
    theme: "light",
    locale: "en",
    polling_interval_secs: 3,
    stale_threshold_mins: 10,
    stalled_threshold_mins: 30,
    notifications_enabled: true,
    repositories: [],
  }),
}));

describe("Route stub placeholders", () => {
  it("MainWindow renders placeholder text", () => {
    render(<MainWindow />);
    expect(screen.getByText("MainWindow")).toBeTruthy();
  });

  it("CardDetail renders placeholder text", () => {
    render(<CardDetail />);
    expect(screen.getByText("CardDetail")).toBeTruthy();
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

  it("EmptyState renders placeholder text", () => {
    render(<EmptyState />);
    expect(screen.getByText("EmptyState")).toBeTruthy();
  });

  it("CompactPanel renders placeholder text", () => {
    render(<CompactPanel />);
    expect(screen.getByText("CompactPanel")).toBeTruthy();
  });
});
