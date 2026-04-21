/**
 * Tests for T40: SettingsNotifications — macOS notification permission indicator
 *
 * ACs covered:
 *   AC6.e (permission state surfacing per PRD §6 edge case)
 *   R-5 mitigation: permission status shown; denied state shows System Settings hint
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { SettingsNotifications } from "../SettingsNotifications";
import type { AppSettings } from "../../views/Settings";

// Mock i18n — returns key as value for deterministic assertions
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

// Mock Tauri IPC — controls get_notification_permission_status responses
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

const BASE_SETTINGS: AppSettings = {
  theme: "light",
  locale: "en",
  polling_interval_secs: 3,
  stale_threshold_mins: 10,
  stalled_threshold_mins: 30,
  notifications_enabled: true,
  repositories: [],
};

function renderComponent(
  settingsOverrides: Partial<AppSettings> = {},
  permissionStatus: "granted" | "denied" | "default" = "default",
) {
  const settings = { ...BASE_SETTINGS, ...settingsOverrides };
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "get_notification_permission_status") {
      return Promise.resolve(permissionStatus);
    }
    return Promise.resolve({});
  });
  return render(
    <SettingsNotifications
      settings={settings}
      onSettingsChange={vi.fn()}
    />,
  );
}

describe("SettingsNotifications — permission indicator (T40 / AC6.e)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
  });

  it("fetches get_notification_permission_status on mount", async () => {
    renderComponent({}, "default");
    await act(async () => { await Promise.resolve(); });

    const calls = mockInvoke.mock.calls;
    const permCalls = calls.filter((c) => c[0] === "get_notification_permission_status");
    expect(permCalls.length).toBeGreaterThan(0);
  });

  it("shows 'granted' status label when permission is granted", async () => {
    renderComponent({}, "granted");
    await act(async () => { await Promise.resolve(); });

    // i18n key returned as-is; key = settings.notifications.statusGranted
    expect(screen.getByTestId("notification-permission-status")).toBeTruthy();
    expect(screen.getByTestId("notification-permission-status").textContent).toContain(
      "settings.notifications.statusGranted",
    );
  });

  it("shows 'default' status label when permission is not yet requested", async () => {
    renderComponent({}, "default");
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByTestId("notification-permission-status")).toBeTruthy();
    expect(screen.getByTestId("notification-permission-status").textContent).toContain(
      "settings.notifications.statusDefault",
    );
  });

  it("shows 'denied' status label when permission is denied", async () => {
    renderComponent({}, "denied");
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByTestId("notification-permission-status")).toBeTruthy();
    expect(screen.getByTestId("notification-permission-status").textContent).toContain(
      "settings.notifications.statusDenied",
    );
  });

  it("shows System Settings hint link when permission is denied", async () => {
    renderComponent({}, "denied");
    await act(async () => { await Promise.resolve(); });

    // Denied state must surface the System Settings link (R-5 mitigation)
    const hint = screen.getByTestId("notification-denied-hint");
    expect(hint).toBeTruthy();
  });

  it("does NOT show System Settings hint when permission is granted", async () => {
    renderComponent({}, "granted");
    await act(async () => { await Promise.resolve(); });

    expect(screen.queryByTestId("notification-denied-hint")).toBeNull();
  });

  it("does NOT show System Settings hint when permission is default (not yet requested)", async () => {
    renderComponent({}, "default");
    await act(async () => { await Promise.resolve(); });

    expect(screen.queryByTestId("notification-denied-hint")).toBeNull();
  });

  it("existing notifications toggle is still rendered (AC6.d regression)", async () => {
    renderComponent({ notifications_enabled: true }, "granted");
    await act(async () => { await Promise.resolve(); });

    expect(screen.getByRole("checkbox", { name: /notifications/i })).toBeTruthy();
  });
});
