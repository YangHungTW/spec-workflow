/**
 * artifactStore — hook behaviour tests (R10, R14, R15, R16).
 *
 * Covers:
 *   - useArtifactChanges filters events by (repo, slug): only matching events
 *     update the Map; non-matching events are ignored.
 *   - useWatcherStatus defaults to "running" before first event (R15 pip starts
 *     green; AC15 implicit: hook initialises in running state).
 *   - useWatcherStatus transitions to "errored" on watcher_status event (R16/AC16).
 *   - useWatcherStatus transitions back to "running" on recovery event.
 *   - useTaskProgress returns 0/0 initially; updates after artifact_changed event
 *     triggers invoke("read_artefact", ...) and parses the returned markdown (R10).
 *
 * Security boundary: assertSafeArgs validation is covered exhaustively in the
 * sibling file artifactStore.validation.test.ts (12 tests). This file does not
 * repeat those cases.
 *
 * Mocks declared before imports per vitest hoisting rules.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { act, renderHook } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks — hoisted above imports.
// ---------------------------------------------------------------------------

// Capture registered handlers so tests can fire them directly.
type EventHandler = (event: { payload: unknown }) => void;
const _handlers: Record<string, EventHandler[]> = {};

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockImplementation(
    (eventName: string, handler: EventHandler) => {
      if (!_handlers[eventName]) _handlers[eventName] = [];
      _handlers[eventName].push(handler);
      return Promise.resolve(() => {
        _handlers[eventName] = (_handlers[eventName] ?? []).filter(
          (h) => h !== handler,
        );
      });
    },
  ),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue("- [x] t1\n- [ ] t2\n"),
}));

// ---------------------------------------------------------------------------
// Imports — after mocks.
// ---------------------------------------------------------------------------
import {
  useArtifactChanges,
  useWatcherStatus,
  useTaskProgress,
} from "../artifactStore";
import { invoke } from "@tauri-apps/api/core";

// ---------------------------------------------------------------------------
// Helper — fire a registered event handler.
// ---------------------------------------------------------------------------
function fireEvent(name: string, payload: unknown) {
  const handlers = _handlers[name] ?? [];
  handlers.forEach((h) => h({ payload }));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useArtifactChanges — filtering by (repo, slug)", () => {
  beforeEach(() => {
    Object.keys(_handlers).forEach((k) => {
      _handlers[k] = [];
    });
  });

  it("starts with an empty Map (no artifact events yet)", () => {
    const { result } = renderHook(() =>
      useArtifactChanges("/repo/a", "feature-x"),
    );
    expect(result.current.size).toBe(0);
  });

  it("updates the Map when a matching artifact_changed event fires", async () => {
    const { result } = renderHook(() =>
      useArtifactChanges("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "feature-x",
        artifact: "prd",
        path: "/repo/a/.specaffold/features/feature-x/03-prd.md",
        mtime_ms: 1_700_000_000_000,
      });
    });

    expect(result.current.size).toBe(1);
    expect(result.current.get("prd")).toBe(1_700_000_000_000);
  });

  it("ignores events for a different repo (non-matching repo filtered out)", async () => {
    const { result } = renderHook(() =>
      useArtifactChanges("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/OTHER",
        slug: "feature-x",
        artifact: "prd",
        path: "/repo/OTHER/.specaffold/features/feature-x/03-prd.md",
        mtime_ms: 9_999_999_999_999,
      });
    });

    expect(result.current.size).toBe(0);
  });

  it("ignores events for a different slug (non-matching slug filtered out)", async () => {
    const { result } = renderHook(() =>
      useArtifactChanges("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "OTHER-slug",
        artifact: "tech",
        path: "/repo/a/.specaffold/features/OTHER-slug/04-tech.md",
        mtime_ms: 9_999_999_999_999,
      });
    });

    expect(result.current.size).toBe(0);
  });

  it("accumulates multiple artifact kinds in the same Map", async () => {
    const { result } = renderHook(() =>
      useArtifactChanges("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "feature-x",
        artifact: "prd",
        path: "/p",
        mtime_ms: 1000,
      });
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "feature-x",
        artifact: "tasks",
        path: "/t",
        mtime_ms: 2000,
      });
    });

    expect(result.current.size).toBe(2);
    expect(result.current.get("prd")).toBe(1000);
    expect(result.current.get("tasks")).toBe(2000);
  });
});

describe("useWatcherStatus — state transitions (R15, R16)", () => {
  beforeEach(() => {
    Object.keys(_handlers).forEach((k) => {
      _handlers[k] = [];
    });
  });

  it("defaults to 'running' before first watcher_status event (pip starts green)", () => {
    const { result } = renderHook(() => useWatcherStatus());
    expect(result.current.state).toBe("running");
    expect(result.current.errorKind).toBeUndefined();
  });

  it("transitions to 'errored' on watcher_status errored event (R16/AC16)", async () => {
    const { result } = renderHook(() => useWatcherStatus());

    await act(async () => {
      fireEvent("watcher_status", {
        state: "errored",
        error_kind: "kqueue_exhausted",
        repo: "/repo/a",
      });
    });

    expect(result.current.state).toBe("errored");
    expect(result.current.errorKind).toBe("kqueue_exhausted");
  });

  it("clears errorKind when recovering back to 'running'", async () => {
    const { result } = renderHook(() => useWatcherStatus());

    await act(async () => {
      fireEvent("watcher_status", {
        state: "errored",
        error_kind: "init_failure",
        repo: "/repo/a",
      });
    });

    await act(async () => {
      fireEvent("watcher_status", {
        state: "running",
        repo: "/repo/a",
      });
    });

    expect(result.current.state).toBe("running");
    expect(result.current.errorKind).toBeUndefined();
  });
});

describe("useTaskProgress — invoke and parse (R10)", () => {
  const mockedInvoke = vi.mocked(invoke);

  beforeEach(() => {
    Object.keys(_handlers).forEach((k) => {
      _handlers[k] = [];
    });
    mockedInvoke.mockReset();
    mockedInvoke.mockResolvedValue("- [x] t1\n- [x] t2\n- [ ] t3\n");
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("starts with { tasks_done: 0, tasks_total: 0 } before any event", () => {
    const { result } = renderHook(() =>
      useTaskProgress("/repo/a", "feature-x"),
    );
    expect(result.current).toEqual({ tasks_done: 0, tasks_total: 0 });
  });

  it("invokes read_artefact and updates counts on matching tasks artifact_changed event", async () => {
    mockedInvoke.mockResolvedValue("- [x] done1\n- [x] done2\n- [ ] undone1\n");

    const { result } = renderHook(() =>
      useTaskProgress("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "feature-x",
        artifact: "tasks",
        path: "/repo/a/.specaffold/features/feature-x/tasks.md",
        mtime_ms: 1000,
      });
      // Allow microtask queue to flush the invoke promise.
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(mockedInvoke).toHaveBeenCalledWith("read_artefact", {
      repo: "/repo/a",
      slug: "feature-x",
      file: "tasks.md",
    });
    expect(result.current).toEqual({ tasks_done: 2, tasks_total: 3 });
  });

  it("ignores artifact_changed events with artifact !== 'tasks'", async () => {
    const { result } = renderHook(() =>
      useTaskProgress("/repo/a", "feature-x"),
    );

    await act(async () => {
      fireEvent("artifact_changed", {
        repo: "/repo/a",
        slug: "feature-x",
        artifact: "prd",
        path: "/p",
        mtime_ms: 1000,
      });
    });

    expect(mockedInvoke).not.toHaveBeenCalled();
    expect(result.current).toEqual({ tasks_done: 0, tasks_total: 0 });
  });
});
