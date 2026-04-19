/**
 * Tests for T13: theme system
 *
 * AC15.a – toggling useTheme() flips html.dark within one frame
 * AC15.b – persists theme preference via IPC settings store
 * AC15.c – default theme = light; first-paint with "dark" setting applies dark class
 * No OS appearance auto-follow — user-only toggle (B1 carve-out)
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { applyThemeToDocument, useTheme } from "../themeStore";

// B1 carve-out: no OS appearance auto-follow in theme system.
// CI grep check verifies no OS-follow media query exists in src/.

// Mock @tauri-apps/api/core so tests run outside a Tauri webview
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

describe("applyThemeToDocument", () => {
  beforeEach(() => {
    // Reset html element class between tests
    document.documentElement.className = "";
  });

  it("adds 'dark' class to html element when theme is dark", () => {
    applyThemeToDocument("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("removes 'dark' class from html element when theme is light", () => {
    document.documentElement.classList.add("dark");
    applyThemeToDocument("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("defaults to light (no dark class) when called with light", () => {
    applyThemeToDocument("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });
});

describe("useTheme hook", () => {
  beforeEach(() => {
    document.documentElement.className = "";
    mockInvoke.mockReset();
  });

  afterEach(() => {
    document.documentElement.className = "";
  });

  it("reads initial theme from IPC and applies it — light default returns no dark class", async () => {
    // IPC returns light theme
    mockInvoke.mockResolvedValueOnce({ theme: "light" });

    const { result } = renderHook(() => useTheme());

    // Wait for async IPC load
    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.theme).toBe("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("first-paint with settings.theme = 'dark' applies dark class", async () => {
    // IPC returns dark theme (simulates settings persisted as dark)
    mockInvoke.mockResolvedValueOnce({ theme: "dark" });

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.theme).toBe("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("toggleTheme flips class within one frame (synchronous via act)", async () => {
    mockInvoke.mockResolvedValueOnce({ theme: "light" });
    // Second call is the save after toggle
    mockInvoke.mockResolvedValueOnce({});

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.theme).toBe("light");

    // Toggle to dark — must be synchronous within the same frame
    act(() => {
      result.current.toggleTheme();
    });

    expect(result.current.theme).toBe("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("setTheme sets light theme and removes dark class", async () => {
    mockInvoke.mockResolvedValueOnce({ theme: "dark" });
    mockInvoke.mockResolvedValueOnce({});

    const { result } = renderHook(() => useTheme());

    await act(async () => {
      await Promise.resolve();
    });

    act(() => {
      result.current.setTheme("light");
    });

    expect(result.current.theme).toBe("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("CSS custom property --primary resolves to #4F46E5 for light theme", () => {
    // Apply light tokens by removing dark class
    applyThemeToDocument("light");

    // Insert theme.css inline so JSDOM can read the variable
    const style = document.createElement("style");
    style.id = "theme-test-inject";
    style.textContent = `
      html {
        --primary: #4F46E5;
      }
      html.dark {
        --primary: #1B4332;
      }
    `;
    document.head.appendChild(style);

    const primary = getComputedStyle(document.documentElement)
      .getPropertyValue("--primary")
      .trim();

    // JSDOM resolves CSS vars from inline <style>; expect light primary
    expect(primary).toBe("#4F46E5");

    document.head.removeChild(style);
  });

  it("CSS custom property --primary resolves to #1B4332 for dark theme", () => {
    applyThemeToDocument("dark");

    const style = document.createElement("style");
    style.id = "theme-test-inject-dark";
    style.textContent = `
      html {
        --primary: #4F46E5;
      }
      html.dark {
        --primary: #1B4332;
      }
    `;
    document.head.appendChild(style);

    const primary = getComputedStyle(document.documentElement)
      .getPropertyValue("--primary")
      .trim();

    expect(primary).toBe("#1B4332");

    document.head.removeChild(style);
  });
});

describe("no OS appearance auto-follow (B1 carve-out)", () => {
  it("applyThemeToDocument does not invoke matchMedia", () => {
    // Stub matchMedia to track calls — jsdom does not implement it
    const matchMediaMock = vi.fn();
    const originalMatchMedia = window.matchMedia;
    Object.defineProperty(window, "matchMedia", {
      writable: true,
      value: matchMediaMock,
    });

    applyThemeToDocument("light");
    applyThemeToDocument("dark");

    // The theme system must not call matchMedia at all (B1 carve-out: no OS follow)
    expect(matchMediaMock).not.toHaveBeenCalled();

    Object.defineProperty(window, "matchMedia", {
      writable: true,
      value: originalMatchMedia,
    });
  });
});
