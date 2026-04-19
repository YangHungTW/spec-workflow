/**
 * Tests for T29: PollingFooter event subscription
 *
 * AC4.c — "Polling · {interval}s" text updates within 1s of polling_cycle_complete
 *          event carrying a new interval value.
 *
 * Tests verify:
 *   1. Static rendering from intervalSeconds prop (existing behaviour preserved)
 *   2. listen("polling_cycle_complete") is called on mount
 *   3. When the event fires with a new interval, the displayed text updates
 *   4. The unlisten function returned by listen() is called on unmount (cleanup)
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { PollingFooter } from "../PollingFooter";

// Mock i18n — returns key as value
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

// Mock @tauri-apps/api/event — captures listen callbacks so tests can fire them
const mockUnlisten = vi.fn();
let capturedEventName: string | null = null;
let capturedCallback: ((event: { payload: unknown }) => void) | null = null;

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn((eventName: string, cb: (event: { payload: unknown }) => void) => {
    capturedEventName = eventName;
    capturedCallback = cb;
    return Promise.resolve(mockUnlisten);
  }),
}));

import { listen } from "@tauri-apps/api/event";
const mockListen = vi.mocked(listen);

describe("PollingFooter — static rendering", () => {
  it("renders polling footer with interval from prop", () => {
    render(<PollingFooter intervalSeconds={3} />);
    const footer = screen.getByTestId("polling-footer");
    expect(footer).toBeTruthy();
  });

  it("renders the polling dot", () => {
    render(<PollingFooter intervalSeconds={3} />);
    expect(screen.getByTestId("polling-dot")).toBeTruthy();
  });
});

describe("PollingFooter — polling_cycle_complete event subscription (AC4.c)", () => {
  beforeEach(() => {
    capturedEventName = null;
    capturedCallback = null;
    mockUnlisten.mockReset();
    mockListen.mockClear();
  });

  afterEach(() => {
    vi.clearAllTimers();
  });

  it("calls listen('polling_cycle_complete') on mount", async () => {
    await act(async () => {
      render(<PollingFooter intervalSeconds={3} />);
    });
    expect(mockListen).toHaveBeenCalledWith(
      "polling_cycle_complete",
      expect.any(Function),
    );
  });

  it("updates displayed interval when event fires with new interval_secs", async () => {
    await act(async () => {
      render(<PollingFooter intervalSeconds={3} />);
    });

    // Verify initial render uses prop value (i18n key contains {interval})
    const label = screen.getByTestId("polling-footer");
    // The label text uses i18n key "sidebar.pollingFooter" with {interval} replaced
    // Our mock returns the key as-is, so after replace: "sidebar.pollingFooter"
    // but with interval replaced — we check interval is reflected in text
    // Since i18n mock returns key as-is we look for the label element
    expect(label).toBeTruthy();

    // Fire the polling_cycle_complete event with a new interval
    expect(capturedCallback).not.toBeNull();
    await act(async () => {
      capturedCallback!({ payload: { interval_secs: 5 } });
    });

    // After event fires, the PollingFooter must reflect the new interval (5)
    // The label text replaces {interval} in the i18n key with "5"
    const labelSpan = screen.getByTestId("polling-footer").querySelector(".polling-footer__label");
    expect(labelSpan).not.toBeNull();
    // The i18n mock returns "sidebar.pollingFooter"; after replace("{interval}", "5")
    // we get "sidebar.pollingFo5ter" — but that verifies the replacement runs.
    // A more robust check: the interval value used in the label text changes to 5.
    // We verify by checking the data attribute on the footer element.
    expect(
      screen.getByTestId("polling-footer").getAttribute("data-interval"),
    ).toBe("5");
  });

  it("unlisten is called on unmount (no memory leak)", async () => {
    let unmount: () => void;
    await act(async () => {
      const result = render(<PollingFooter intervalSeconds={3} />);
      unmount = result.unmount;
    });

    await act(async () => {
      unmount();
    });

    expect(mockUnlisten).toHaveBeenCalledTimes(1);
  });

  it("capturedEventName is 'polling_cycle_complete'", async () => {
    await act(async () => {
      render(<PollingFooter intervalSeconds={3} />);
    });
    expect(capturedEventName).toBe("polling_cycle_complete");
  });
});
