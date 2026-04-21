/**
 * T38 — Theme-switch timing observation harness (AC15.a)
 *
 * AC15.a: theme toggles apply "within one frame" (<100ms target).
 *
 * Synthetic vs runtime split (dogfood-paradox-third-occurrence):
 *   This harness verifies the STRUCTURAL guarantee: setTheme/toggleTheme are
 *   synchronous within act() — the DOM mutation completes inside the same
 *   microtask batch. The wall-clock delta (performance.now()) demonstrates the
 *   absence of async defers or setTimeout delays.
 *
 *   Real-browser frame budget confirmation (16.7ms at 60 Hz) is a manual
 *   smoke step deferred to T42, per the dogfood-paradox pattern: the jsdom
 *   environment has no rAF scheduler and no true paint cadence, so a
 *   "within one frame" assertion here is necessarily synthetic.
 *
 * Limitation: vi.useFakeTimers() + rAF polyfill let us control the tick
 * sequence, but cannot model GPU compositing or actual frame boundaries.
 * The 100ms budget asserted here is generous relative to the 16.7ms real
 * target, ensuring the test is a pure latency smoke-check rather than a
 * false frame-budget guarantee.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useTheme, applyThemeToDocument } from "../themeStore";

// Mock @tauri-apps/api/core so tests run outside a Tauri webview
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

/**
 * Minimal requestAnimationFrame polyfill for jsdom.
 * jsdom does not implement rAF; this stub fires callbacks synchronously
 * so timing assertions are deterministic (no real scheduling involved).
 * Synthetic limitation documented above.
 */
function installRafPolyfill(): () => void {
  let handle = 0;
  const pending = new Map<number, FrameRequestCallback>();

  const originalRaf = globalThis.requestAnimationFrame;
  const originalCaf = globalThis.cancelAnimationFrame;

  globalThis.requestAnimationFrame = (cb: FrameRequestCallback): number => {
    handle += 1;
    pending.set(handle, cb);
    return handle;
  };

  globalThis.cancelAnimationFrame = (id: number): void => {
    pending.delete(id);
  };

  // Expose flush so tests can advance one synthetic frame explicitly
  (globalThis as unknown as Record<string, unknown>).__flushRaf = (): void => {
    const entries = [...pending.entries()];
    pending.clear();
    for (const [, cb] of entries) {
      cb(performance.now());
    }
  };

  return () => {
    globalThis.requestAnimationFrame = originalRaf;
    globalThis.cancelAnimationFrame = originalCaf;
    delete (globalThis as unknown as Record<string, unknown>).__flushRaf;
  };
}

describe("Theme-switch timing harness (AC15.a — synthetic)", () => {
  let removeRafPolyfill: () => void;

  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
    // useFakeTimers first so our polyfill overrides vitest's fake rAF last
    vi.useFakeTimers();
    removeRafPolyfill = installRafPolyfill();
  });

  afterEach(() => {
    vi.useRealTimers();
    removeRafPolyfill();
    document.documentElement.className = "";
  });

  it("setTheme('dark') applies html.dark synchronously within act() — no async defer", async () => {
    // Start with light theme
    mockInvoke.mockResolvedValueOnce({ theme: "light" });
    // Second invoke = save_settings after setTheme; best-effort, ignore result
    mockInvoke.mockResolvedValue({});

    const { result } = renderHook(() => useTheme());

    // Wait for the IPC load on mount to settle
    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.theme).toBe("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);

    // Measure wall-clock for the theme switch
    const t0 = performance.now();

    act(() => {
      result.current.setTheme("dark");
    });

    const elapsed = performance.now() - t0;

    // DOM mutation must be visible BEFORE any rAF fires — synchronous guarantee
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(result.current.theme).toBe("dark");

    // Wall-clock assertion: generous 100ms budget (jsdom is fast; real target is <16.7ms)
    // Asserts no setTimeout/async defer was introduced on the theme-switch path.
    expect(elapsed).toBeLessThan(100);
  });

  it("toggleTheme() applies html.dark synchronously within act() — no async defer", async () => {
    mockInvoke.mockResolvedValueOnce({ theme: "light" });
    mockInvoke.mockResolvedValue({});

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    const t0 = performance.now();

    act(() => {
      result.current.toggleTheme();
    });

    const elapsed = performance.now() - t0;

    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(result.current.theme).toBe("dark");
    expect(elapsed).toBeLessThan(100);
  });

  it("setTheme('light') removes html.dark synchronously — round-trip within budget", async () => {
    mockInvoke.mockResolvedValueOnce({ theme: "dark" });
    mockInvoke.mockResolvedValue({});

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.theme).toBe("dark");

    const t0 = performance.now();

    act(() => {
      result.current.setTheme("light");
    });

    const elapsed = performance.now() - t0;

    expect(document.documentElement.classList.contains("dark")).toBe(false);
    expect(result.current.theme).toBe("light");
    expect(elapsed).toBeLessThan(100);
  });

  it("applyThemeToDocument is synchronous — no rAF or setTimeout required", () => {
    // Verify the underlying DOM helper itself is purely synchronous.
    // This is the structural assertion that the hook builds upon.

    const t0 = performance.now();
    applyThemeToDocument("dark");
    const elapsed = performance.now() - t0;

    expect(document.documentElement.classList.contains("dark")).toBe(true);

    // applyThemeToDocument must complete well within 1ms (DOM classList is
    // synchronous; anything close to 100ms would indicate accidental async).
    expect(elapsed).toBeLessThan(100);
  });

  it("html.dark class is present BEFORE the next synthetic rAF fires", async () => {
    // Structural assertion: the class must already be set before any
    // requestAnimationFrame callback runs. This mirrors the real-browser
    // requirement: "theme toggle applies within one frame" means the class
    // must be set in the same JS task, not queued to the next paint callback.

    mockInvoke.mockResolvedValueOnce({ theme: "light" });
    mockInvoke.mockResolvedValue({});

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    // Queue a synthetic rAF to capture the class state at "next frame"
    let classAtNextFrame: boolean | undefined;
    globalThis.requestAnimationFrame(() => {
      classAtNextFrame = document.documentElement.classList.contains("dark");
    });

    act(() => {
      result.current.setTheme("dark");
    });

    // Class must be set immediately (before flushing the rAF queue)
    expect(document.documentElement.classList.contains("dark")).toBe(true);

    // Flush the synthetic rAF — class must still be dark
    (globalThis as unknown as Record<string, () => void>).__flushRaf();
    expect(classAtNextFrame).toBe(true);
  });
});
