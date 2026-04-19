import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// Stub i18n for stub tests
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Stub Tauri IPC for stub tests
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue({ sessions: [], repos: [], polling_interval_secs: 3 }),
}));

// These imports will fail (red) until the stub files exist.
import MainWindow from "../MainWindow";
import CardDetail from "../CardDetail";
import Settings from "../Settings";
import EmptyState from "../EmptyState";
import CompactPanel from "../CompactPanel";

describe("Route stub placeholders", () => {
  it("MainWindow renders the main window layout (T17 replaced stub)", () => {
    render(<MainWindow />);
    // T17 replaced the stub; verify the layout container renders without crashing
    const main = document.querySelector("[data-testid='main-window']");
    expect(main).toBeTruthy();
  });

  it("CardDetail renders placeholder text", () => {
    render(<CardDetail />);
    expect(screen.getByText("CardDetail")).toBeTruthy();
  });

  it("Settings renders placeholder text", () => {
    render(<Settings />);
    expect(screen.getByText("Settings")).toBeTruthy();
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
