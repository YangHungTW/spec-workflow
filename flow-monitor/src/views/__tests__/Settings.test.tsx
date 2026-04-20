/**
 * Tests for T23: Settings view — General + Notifications + Repositories tabs
 *
 * ACs covered:
 *   AC4.b  — polling interval slider clamps to [2, 5]
 *   AC5.d  — stalled threshold must be >= stale threshold (validation at input)
 *   AC6.d  — notifications on/off toggle
 *   AC11.a — language radio EN / zh-TW (not auto-detect)
 *   AC14.a — all settings round-trip to storage via IPC
 *   AC15.a — theme toggle Light/Dark, applies html.dark within one frame
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, act, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import Settings from "../Settings";
import { I18nProvider } from "../../i18n";

// Mock Tauri IPC — tests run outside a Tauri webview
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

// Default settings payload returned by get_settings
const DEFAULT_SETTINGS = {
  theme: "light",
  locale: "en",
  polling_interval_secs: 3,
  stale_threshold_mins: 10,
  stalled_threshold_mins: 30,
  notifications_enabled: true,
  repositories: [],
};

function renderSettings(overrides: Partial<typeof DEFAULT_SETTINGS> = {}) {
  const settings = { ...DEFAULT_SETTINGS, ...overrides };
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "get_settings") return Promise.resolve(settings);
    return Promise.resolve({});
  });
  return render(
    <MemoryRouter>
      <I18nProvider>
        <Settings />
      </I18nProvider>
    </MemoryRouter>,
  );
}

describe("Settings view — tab navigation", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders exactly 3 tabs: General, Notifications, Repositories", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByRole("tab", { name: /general/i })).toBeTruthy();
    expect(screen.getByRole("tab", { name: /notifications/i })).toBeTruthy();
    expect(screen.getByRole("tab", { name: /repositories/i })).toBeTruthy();
    expect(screen.queryAllByRole("tab")).toHaveLength(3);
  });

  it("does NOT have a Control Plane or Commands tab (B2 boundary)", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const tabs = screen.queryAllByRole("tab");
    const tabNames = tabs.map((t) => t.textContent ?? "");
    expect(tabNames.join(" ")).not.toMatch(/control/i);
    expect(tabNames.join(" ")).not.toMatch(/commands/i);
  });

  it("General tab is shown by default", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const generalTab = screen.getByRole("tab", { name: /general/i });
    expect(generalTab.getAttribute("aria-selected")).toBe("true");
  });

  it("clicking Notifications tab shows the notifications panel", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const notifTab = screen.getByRole("tab", { name: /notifications/i });
    fireEvent.click(notifTab);
    expect(notifTab.getAttribute("aria-selected")).toBe("true");
  });

  it("clicking Repositories tab shows the repositories panel", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /repositories/i }));
    expect(screen.getByRole("tab", { name: /repositories/i }).getAttribute("aria-selected")).toBe("true");
  });
});

describe("Settings — General tab: polling interval (AC4.b)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("shows default polling interval of 3 seconds", async () => {
    renderSettings({ polling_interval_secs: 3 });
    await act(async () => { await Promise.resolve(); });

    const slider = screen.getByRole("slider", { name: /polling/i });
    expect(slider).toBeTruthy();
    expect((slider as HTMLInputElement).value).toBe("3");
  });

  it("slider has min=2 and max=5 (AC4.b range)", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const slider = screen.getByRole("slider", { name: /polling/i });
    expect((slider as HTMLInputElement).min).toBe("2");
    expect((slider as HTMLInputElement).max).toBe("5");
  });

  it("slider clamps value: attempting value 1 stays at min 2", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const slider = screen.getByRole("slider", { name: /polling/i });
    fireEvent.change(slider, { target: { value: "1" } });
    expect(Number((slider as HTMLInputElement).value)).toBeGreaterThanOrEqual(2);
  });

  it("slider clamps value: attempting value 10 stays at max 5", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    const slider = screen.getByRole("slider", { name: /polling/i });
    fireEvent.change(slider, { target: { value: "10" } });
    expect(Number((slider as HTMLInputElement).value)).toBeLessThanOrEqual(5);
  });

  it("changing slider calls update_settings IPC with new polling_interval_secs", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    mockInvoke.mockResolvedValueOnce({});
    const slider = screen.getByRole("slider", { name: /polling/i });
    fireEvent.change(slider, { target: { value: "4" } });

    await waitFor(() => {
      const calls = mockInvoke.mock.calls;
      const updateCall = calls.find((c) => c[0] === "update_settings");
      expect(updateCall).toBeTruthy();
      expect((updateCall?.[1] as Record<string, unknown>)["polling_interval_secs"]).toBe(4);
    });
  });
});

describe("Settings — General tab: idle thresholds (AC5.d)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("shows stale and stalled threshold inputs", async () => {
    renderSettings({ stale_threshold_mins: 10, stalled_threshold_mins: 30 });
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByRole("spinbutton", { name: /stale/i })).toBeTruthy();
    expect(screen.getByRole("spinbutton", { name: /stalled/i })).toBeTruthy();
  });

  it("shows validation error when stalled threshold is set below stale threshold (AC5.d)", async () => {
    renderSettings({ stale_threshold_mins: 10, stalled_threshold_mins: 30 });
    await act(async () => { await Promise.resolve(); });

    const stalledInput = screen.getByRole("spinbutton", { name: /stalled/i });
    fireEvent.change(stalledInput, { target: { value: "5" } });

    await waitFor(() => {
      const errorEl = screen.queryByRole("alert");
      expect(errorEl).toBeTruthy();
      expect(errorEl?.textContent).toMatch(/stalled.*stale|threshold/i);
    });
  });

  it("does NOT call update_settings IPC when threshold validation fails", async () => {
    renderSettings({ stale_threshold_mins: 10, stalled_threshold_mins: 30 });
    await act(async () => { await Promise.resolve(); });

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue({});

    const stalledInput = screen.getByRole("spinbutton", { name: /stalled/i });
    fireEvent.change(stalledInput, { target: { value: "5" } });

    await act(async () => { await Promise.resolve(); });

    const updateCalls = mockInvoke.mock.calls.filter((c) => c[0] === "update_settings");
    expect(updateCalls).toHaveLength(0);
  });

  it("accepts valid stalled threshold >= stale and calls IPC", async () => {
    renderSettings({ stale_threshold_mins: 10, stalled_threshold_mins: 30 });
    await act(async () => { await Promise.resolve(); });

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue({});

    const stalledInput = screen.getByRole("spinbutton", { name: /stalled/i });
    fireEvent.change(stalledInput, { target: { value: "20" } });

    await waitFor(() => {
      const updateCalls = mockInvoke.mock.calls.filter((c) => c[0] === "update_settings");
      expect(updateCalls.length).toBeGreaterThan(0);
    });
  });
});

describe("Settings — General tab: theme section removed (T46 dedup)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("does NOT render Light/Dark theme radio buttons in Settings General tab (toolbar is single source of truth)", async () => {
    renderSettings({ theme: "light" });
    await act(async () => { await Promise.resolve(); });

    // Theme radios must be absent — toolbar is the only theme toggle
    expect(screen.queryByRole("radio", { name: /^light$/i })).toBeNull();
    expect(screen.queryByRole("radio", { name: /^dark$/i })).toBeNull();
  });
});

describe("Settings — General tab: language selector (AC11.a)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("renders English and 繁體中文 language radio buttons (not auto-detect)", async () => {
    renderSettings({ locale: "en" });
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByRole("radio", { name: /english/i })).toBeTruthy();
    expect(screen.getByRole("radio", { name: /繁體中文/i })).toBeTruthy();
  });

  it("no auto-detect option is present (AC11.a)", async () => {
    renderSettings();
    await act(async () => { await Promise.resolve(); });

    expect(screen.queryByRole("radio", { name: /auto/i })).toBeNull();
  });

  it("English is selected when locale = en", async () => {
    renderSettings({ locale: "en" });
    await act(async () => { await Promise.resolve(); });

    const enRadio = screen.getByRole("radio", { name: /english/i });
    expect((enRadio as HTMLInputElement).checked).toBe(true);
  });

  it("switching to 繁體中文 calls update_settings IPC with locale zh-TW (AC14.a)", async () => {
    renderSettings({ locale: "en" });
    await act(async () => { await Promise.resolve(); });

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue({});

    fireEvent.click(screen.getByRole("radio", { name: /繁體中文/i }));

    await waitFor(() => {
      const updateCalls = mockInvoke.mock.calls.filter((c) => c[0] === "update_settings");
      expect(updateCalls.length).toBeGreaterThan(0);
      const payload = updateCalls[0]?.[1] as Record<string, unknown>;
      expect(payload["locale"]).toBe("zh-TW");
    });
  });
});

describe("Settings — Notifications tab (AC6.d)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("shows a notifications toggle", async () => {
    renderSettings({ notifications_enabled: true });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /notifications/i }));

    const toggle = screen.getByRole("checkbox", { name: /notifications/i });
    expect(toggle).toBeTruthy();
  });

  it("notifications toggle is checked when notifications_enabled = true", async () => {
    renderSettings({ notifications_enabled: true });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /notifications/i }));

    const toggle = screen.getByRole("checkbox", { name: /notifications/i });
    expect((toggle as HTMLInputElement).checked).toBe(true);
  });

  it("toggling notifications calls update_settings IPC (AC14.a)", async () => {
    renderSettings({ notifications_enabled: true });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /notifications/i }));

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue({});

    const toggle = screen.getByRole("checkbox", { name: /notifications/i });
    fireEvent.click(toggle);

    await waitFor(() => {
      const updateCalls = mockInvoke.mock.calls.filter((c) => c[0] === "update_settings");
      expect(updateCalls.length).toBeGreaterThan(0);
      const payload = updateCalls[0]?.[1] as Record<string, unknown>;
      expect(payload["notifications_enabled"]).toBe(false);
    });
  });
});

describe("Settings — Repositories tab (AC2.a/b/c)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("shows Add repository button", async () => {
    renderSettings({ repositories: [] });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /repositories/i }));

    expect(screen.getByRole("button", { name: /add repo/i })).toBeTruthy();
  });

  it("lists registered repositories with a remove button each", async () => {
    renderSettings({
      repositories: ["/Users/alice/project-a", "/Users/alice/project-b"],
    });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /repositories/i }));

    expect(screen.getByText("/Users/alice/project-a")).toBeTruthy();
    expect(screen.getByText("/Users/alice/project-b")).toBeTruthy();
    const removeButtons = screen.getAllByRole("button", { name: /remove/i });
    expect(removeButtons).toHaveLength(2);
  });

  it("clicking Remove calls remove_repo IPC with path (AC2.b, AC14.a)", async () => {
    renderSettings({
      repositories: ["/Users/alice/project-a"],
    });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /repositories/i }));

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue({});

    fireEvent.click(screen.getByRole("button", { name: /remove/i }));

    await waitFor(() => {
      const removeCalls = mockInvoke.mock.calls.filter((c) => c[0] === "remove_repo");
      expect(removeCalls.length).toBeGreaterThan(0);
      const payload = removeCalls[0]?.[1] as Record<string, unknown>;
      expect(payload["path"]).toBe("/Users/alice/project-a");
    });
  });

  it("shows inline error when picked path lacks .spec-workflow/ (AC2.c)", async () => {
    renderSettings({ repositories: [] });
    await act(async () => { await Promise.resolve(); });

    fireEvent.click(screen.getByRole("tab", { name: /repositories/i }));

    // Simulate the component receiving a picked path that has no .spec-workflow/
    // The component exposes a testable validateRepo function via data-testid
    const addBtn = screen.getByRole("button", { name: /add repo/i });

    // Mock open dialog to return a path without .spec-workflow/
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "pick_folder") return Promise.resolve("/Users/alice/not-a-specflow-repo");
      if (cmd === "path_exists") return Promise.resolve(false);
      return Promise.resolve({});
    });

    fireEvent.click(addBtn);

    await waitFor(() => {
      const alertEl = screen.queryByRole("alert");
      expect(alertEl).toBeTruthy();
      expect(alertEl?.textContent).toMatch(/not a specflow/i);
    });
  });
});

describe("Settings — round-trip IPC (AC14.a–c)", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("loads settings from get_settings IPC on mount", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "get_settings") {
        return Promise.resolve({
          ...DEFAULT_SETTINGS,
          polling_interval_secs: 5,
        });
      }
      return Promise.resolve({});
    });

    render(
      <MemoryRouter>
        <I18nProvider>
          <Settings />
        </I18nProvider>
      </MemoryRouter>,
    );

    await act(async () => { await Promise.resolve(); });

    const slider = screen.getByRole("slider", { name: /polling/i });
    expect((slider as HTMLInputElement).value).toBe("5");
  });
});
