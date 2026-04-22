/**
 * T13 — sessionStore archive state tests
 *
 * ACs covered:
 *   AC14 — archivedFeatures array populated from list_archived_features on mount
 *   AC15 — archiveExpanded defaults to false (R15: collapsed by default)
 *   AC16 — setArchiveExpanded updates state and writes to settings store
 *
 * Tests are written against the hook's exported surface:
 *   useSessionStore() → { archivedFeatures, archiveExpanded, setArchiveExpanded }
 *
 * Tauri IPC is mocked so tests run outside a Tauri webview.
 * Event listeners are captured so tests can fire synthetic add_repo /
 * remove_repo events and assert that list_archived_features is re-invoked.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks — must be declared before any imports that transitively touch the
// mocked modules (vi.mock is hoisted by vitest).
// ---------------------------------------------------------------------------

// Capture event listener callbacks keyed by event name.
type EventCallback = (event: { payload: unknown }) => void;
const capturedListeners: Record<string, EventCallback[]> = {};
const mockUnlisten = vi.fn().mockReturnValue(undefined);

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn((eventName: string, cb: EventCallback) => {
    if (!capturedListeners[eventName]) {
      capturedListeners[eventName] = [];
    }
    capturedListeners[eventName].push(cb);
    return Promise.resolve(mockUnlisten);
  }),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import { useSessionStore } from "../sessionStore";

const mockInvoke = vi.mocked(invoke);

// ---------------------------------------------------------------------------
// Default mock implementations
// ---------------------------------------------------------------------------

const MOCK_ARCHIVED: { repo: string; slug: string; dir: string }[] = [
  { repo: "/repos/my-repo", slug: "old-feature", dir: "/repos/my-repo/.specaffold/archive/old-feature" },
  { repo: "/repos/my-repo", slug: "another-old", dir: "/repos/my-repo/.specaffold/archive/another-old" },
];

function setupDefaultMocks(
  archivedFeatures: { repo: string; slug: string; dir: string }[] = MOCK_ARCHIVED,
) {
  mockInvoke.mockImplementation((cmd: string) => {
    if (cmd === "list_archived_features") {
      return Promise.resolve(archivedFeatures);
    }
    if (cmd === "update_settings") {
      return Promise.resolve(undefined);
    }
    return Promise.resolve(undefined);
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useSessionStore — archive state defaults", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockUnlisten.mockReset();
    for (const key of Object.keys(capturedListeners)) {
      delete capturedListeners[key];
    }
  });

  it("archiveExpanded defaults to false (R15)", () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());
    expect(result.current.archiveExpanded).toBe(false);
  });

  it("archivedFeatures defaults to empty array before mount resolves", () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());
    // Before the async invoke resolves, archivedFeatures is the initial empty array
    expect(Array.isArray(result.current.archivedFeatures)).toBe(true);
  });
});

describe("useSessionStore — list_archived_features invoked on mount", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockUnlisten.mockReset();
    for (const key of Object.keys(capturedListeners)) {
      delete capturedListeners[key];
    }
  });

  it("invokes list_archived_features on mount and populates archivedFeatures", async () => {
    setupDefaultMocks(MOCK_ARCHIVED);
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    expect(mockInvoke).toHaveBeenCalledWith("list_archived_features");
    expect(result.current.archivedFeatures).toEqual(MOCK_ARCHIVED);
  });

  it("archivedFeatures is empty array when list_archived_features returns empty", async () => {
    setupDefaultMocks([]);
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.archivedFeatures).toEqual([]);
  });

  it("archivedFeatures stays empty when list_archived_features throws", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "list_archived_features") {
        return Promise.reject(new Error("IPC error"));
      }
      return Promise.resolve(undefined);
    });

    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.archivedFeatures).toEqual([]);
  });
});

describe("useSessionStore — setArchiveExpanded", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockUnlisten.mockReset();
    for (const key of Object.keys(capturedListeners)) {
      delete capturedListeners[key];
    }
  });

  it("setArchiveExpanded(true) updates archiveExpanded state", async () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.archiveExpanded).toBe(false);

    await act(async () => {
      result.current.setArchiveExpanded(true);
    });

    expect(result.current.archiveExpanded).toBe(true);
  });

  it("setArchiveExpanded(false) updates archiveExpanded state back to false", async () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      result.current.setArchiveExpanded(true);
    });

    await act(async () => {
      result.current.setArchiveExpanded(false);
    });

    expect(result.current.archiveExpanded).toBe(false);
  });

  it("setArchiveExpanded writes to Tauri settings store (update_settings)", async () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    mockInvoke.mockClear();

    await act(async () => {
      result.current.setArchiveExpanded(true);
    });

    // Should have called update_settings with archive_expanded: true
    expect(mockInvoke).toHaveBeenCalledWith(
      "update_settings",
      expect.objectContaining({ archive_expanded: true }),
    );
  });

  it("setArchiveExpanded(false) persists false to settings store", async () => {
    setupDefaultMocks();
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      result.current.setArchiveExpanded(true);
    });

    mockInvoke.mockClear();

    await act(async () => {
      result.current.setArchiveExpanded(false);
    });

    expect(mockInvoke).toHaveBeenCalledWith(
      "update_settings",
      expect.objectContaining({ archive_expanded: false }),
    );
  });
});

describe("useSessionStore — refresh on archiveExpanded false→true", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockUnlisten.mockReset();
    for (const key of Object.keys(capturedListeners)) {
      delete capturedListeners[key];
    }
  });

  it("flipping archiveExpanded false→true triggers a fresh list_archived_features call (D8)", async () => {
    setupDefaultMocks(MOCK_ARCHIVED);
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    // Count calls after mount
    const callsAfterMount = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;

    // Flip to true — should trigger a refresh
    await act(async () => {
      result.current.setArchiveExpanded(true);
      await Promise.resolve();
    });

    const callsAfterExpand = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;

    expect(callsAfterExpand).toBeGreaterThan(callsAfterMount);
  });

  it("flipping archiveExpanded true→false does NOT trigger list_archived_features (no needless refresh)", async () => {
    setupDefaultMocks(MOCK_ARCHIVED);
    const { result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    // First, expand
    await act(async () => {
      result.current.setArchiveExpanded(true);
      await Promise.resolve();
    });

    const callsBeforeCollapse = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;

    // Now collapse — should NOT trigger another refresh
    await act(async () => {
      result.current.setArchiveExpanded(false);
      await Promise.resolve();
    });

    const callsAfterCollapse = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;

    expect(callsAfterCollapse).toBe(callsBeforeCollapse);
  });
});

describe("useSessionStore — refresh on add_repo / remove_repo events", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockUnlisten.mockReset();
    for (const key of Object.keys(capturedListeners)) {
      delete capturedListeners[key];
    }
  });

  it("add_repo event triggers list_archived_features refresh", async () => {
    setupDefaultMocks(MOCK_ARCHIVED);
    const { result: _addResult } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    const initialCalls = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;
    expect(initialCalls).toBeGreaterThan(0);

    // Fire the add_repo Tauri event
    await act(async () => {
      const listeners = capturedListeners["add_repo"] ?? [];
      for (const listener of listeners) {
        listener({ payload: { path: "/repos/new-repo" } });
      }
      await Promise.resolve();
    });

    const callsAfterEvent = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;
    expect(callsAfterEvent).toBeGreaterThan(initialCalls);
  });

  it("remove_repo event triggers list_archived_features refresh", async () => {
    setupDefaultMocks(MOCK_ARCHIVED);
    const { result: _result } = renderHook(() => useSessionStore());

    await act(async () => {
      await Promise.resolve();
    });

    const initialCalls = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;

    // Fire the remove_repo Tauri event
    await act(async () => {
      const listeners = capturedListeners["remove_repo"] ?? [];
      for (const listener of listeners) {
        listener({ payload: { path: "/repos/my-repo" } });
      }
      await Promise.resolve();
    });

    const callsAfterEvent = mockInvoke.mock.calls.filter(
      (c) => c[0] === "list_archived_features",
    ).length;
    expect(callsAfterEvent).toBeGreaterThan(initialCalls);
  });
});
