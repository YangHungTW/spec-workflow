/**
 * Tests for T103: PreflightToast component
 *
 * AC5.c — informational toast, not cancelable (command already dispatched)
 * Auto-dismisses after 3000ms via setTimeout.
 * Click-to-dismiss also calls onDismiss immediately.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, fireEvent } from "@testing-library/react";
import { PreflightToast } from "../PreflightToast";

// Mock i18n — toast.preflight key lands in W5 T112a/b; stub here so the
// component test does not depend on i18n parity.
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      if (key === "toast.preflight") {
        return "Running {command} on {slug}…";
      }
      return key;
    },
  }),
}));

describe("PreflightToast", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renders the body text with {command} and {slug} substituted", () => {
    const onDismiss = vi.fn();
    const { getByText } = render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    expect(getByText("Running advance on my-feature…")).toBeTruthy();
  });

  it("schedules setTimeout at exactly 3000ms on mount", () => {
    const setTimeoutSpy = vi.spyOn(globalThis, "setTimeout");
    const onDismiss = vi.fn();
    render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    // At least one call to setTimeout with delay === 3000
    const calls = setTimeoutSpy.mock.calls;
    const has3000 = calls.some((args) => args[1] === 3000);
    expect(has3000).toBe(true);
  });

  it("calls onDismiss after 3000ms (timer advances)", () => {
    const onDismiss = vi.fn();
    render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    expect(onDismiss).not.toHaveBeenCalled();
    vi.advanceTimersByTime(3000);
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it("does not call onDismiss before 3000ms", () => {
    const onDismiss = vi.fn();
    render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    vi.advanceTimersByTime(2999);
    expect(onDismiss).not.toHaveBeenCalled();
  });

  it("calls onDismiss immediately when the toast body is clicked", () => {
    const onDismiss = vi.fn();
    const { getByRole } = render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    fireEvent.click(getByRole("status"));
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it("clears the timer when the component unmounts (no stale call)", () => {
    const onDismiss = vi.fn();
    const { unmount } = render(
      <PreflightToast command="advance" slug="my-feature" onDismiss={onDismiss} />,
    );
    unmount();
    vi.advanceTimersByTime(3000);
    // After unmount the timer is cleared — onDismiss must not be called
    expect(onDismiss).not.toHaveBeenCalled();
  });
});
