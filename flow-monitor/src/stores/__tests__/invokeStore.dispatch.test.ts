/**
 * invokeStore — dispatch null-classify guard (T110 retry 1).
 *
 * Covers the security finding: an unknown command (classify() === null) must
 * be rejected at the dispatch boundary before any IPC call reaches the Rust
 * backend. The in-flight guard, optimistic setInFlight, and invoke() must all
 * remain untouched when the classify result is null.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks — factories use only vi.fn() literals (no outer-scope variables)
// because vi.mock is hoisted above all variable declarations.
// ---------------------------------------------------------------------------

// Mock Tauri event bus — listen() returns a Promise<unlisten fn>.
vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockResolvedValue(() => {}),
}));

// Mock Tauri core — invoke() should NOT be called for unknown commands.
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

// Mock command_taxonomy so tests control what classify() returns.
vi.mock("../../generated/command_taxonomy", () => ({
  classify: vi.fn(),
}));

// ---------------------------------------------------------------------------
// Import the mocked modules after mocks are registered, then get typed refs.
// ---------------------------------------------------------------------------
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { classify } from "../../generated/command_taxonomy";
import { useInvokeStore } from "../invokeStore";

const mockInvoke = vi.mocked(invoke);
const mockListen = vi.mocked(listen);
const mockClassify = vi.mocked(classify);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("invokeStore.dispatch — null-classify guard", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // listen always resolves to a no-op unlisten so the hook mounts cleanly.
    mockListen.mockResolvedValue(() => {});
  });

  it("does NOT call invoke() when classify() returns null (unknown command)", async () => {
    mockClassify.mockReturnValue(null);

    const { result } = renderHook(() => useInvokeStore());

    await act(async () => {
      await result.current.dispatch(
        "unknown-cmd",
        "my-slug",
        "/repo/path",
        "card-action",
        "terminal",
      );
    });

    expect(mockInvoke).not.toHaveBeenCalled();
  });

  it("logs console.error with the unknown command string on null classify", async () => {
    mockClassify.mockReturnValue(null);
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    const { result } = renderHook(() => useInvokeStore());

    await act(async () => {
      await result.current.dispatch(
        "unknown-cmd",
        "my-slug",
        "/repo/path",
        "card-action",
        "terminal",
      );
    });

    expect(errorSpy).toHaveBeenCalledWith(
      "[invokeStore] dispatch rejected — unknown command",
      "unknown-cmd",
    );

    errorSpy.mockRestore();
  });

  it("does NOT add a key to inFlight for an unknown command", async () => {
    mockClassify.mockReturnValue(null);

    const { result } = renderHook(() => useInvokeStore());

    await act(async () => {
      await result.current.dispatch(
        "unknown-cmd",
        "my-slug",
        "/repo/path",
        "card-action",
        "terminal",
      );
    });

    // inFlight set must remain empty — no optimistic entry was added.
    expect(result.current.inFlight.size).toBe(0);
  });

  it("calls invoke() normally when classify() returns a known class", async () => {
    mockClassify.mockReturnValue("safe");
    mockInvoke.mockResolvedValue({ outcome: "spawned" });

    const { result } = renderHook(() => useInvokeStore());

    await act(async () => {
      await result.current.dispatch(
        "known-safe-cmd",
        "my-slug",
        "/repo/path",
        "card-action",
        "terminal",
      );
    });

    expect(mockInvoke).toHaveBeenCalledOnce();
  });
});
