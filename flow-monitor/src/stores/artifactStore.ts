/**
 * artifactStore — hooks for FS-watch artifact events and task progress.
 *
 * Four named exports:
 *   - useArtifactChanges(repoPath, slug): Map<ArtifactKind, number>
 *   - useWatcherStatus(): { state: WatcherState, errorKind?: string }
 *   - useTaskProgress(repoPath, slug): { tasks_done: number, tasks_total: number }
 *   - parseTaskCounts(md: string): { tasks_done: number, tasks_total: number }
 *
 * Design decisions D4, D5 (04-tech.md §2):
 *   - No zustand / redux — uses the existing useState + listen() pattern.
 *   - parseTaskCounts is a pure function so it is unit-testable without React.
 *   - useTaskProgress throttles read_artefact invocations to 1/sec via useRef
 *     timestamp gate (defends against rapid editor saves; debouncer in Rust
 *     covers most coalescing, but the renderer-side gate is a belt-and-braces
 *     guard on the IPC call rate per the performance rule).
 */

import { useState, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

// ---------------------------------------------------------------------------
// Types — local TS equivalents of the Rust enums in lib.rs.
// MERGE-NOTE: keep in sync with lib.rs T4 enums (ArtifactKind, WatcherState).
// ---------------------------------------------------------------------------

/**
 * Closed enum of artifact kinds the Rust watcher classifies per file path.
 * Mirrors the Rust ArtifactKind enum (T4 / fs_watcher.rs).
 */
export type ArtifactKind =
  | "request"
  | "design"
  | "prd"
  | "tech"
  | "plan"
  | "tasks"
  | "status"
  | "other";

/**
 * Two-state watcher health enum.
 * Mirrors the Rust WatcherState enum (T4 / fs_watcher.rs).
 */
export type WatcherState = "running" | "errored";

// ---------------------------------------------------------------------------
// IPC event payload shapes — must stay in sync with Rust structs (D3).
// ---------------------------------------------------------------------------

interface ArtifactChangedPayload {
  repo: string;
  slug: string;
  artifact: ArtifactKind;
  path: string;
  mtime_ms: number;
}

interface WatcherStatusPayload {
  state: WatcherState;
  error_kind?: string;
  repo?: string;
}

// ---------------------------------------------------------------------------
// parseTaskCounts — pure function, exported for unit testing (D5 verbatim).
// ---------------------------------------------------------------------------

/**
 * Count done/total GFM-style task list items in a markdown string.
 *
 * Rules per D5:
 *   - Matches lines with leading whitespace + "- [ ]" or "- [x]" / "- [X]".
 *   - Lines inside a code fence (``` block) are excluded via inFence toggle.
 *   - A line starting with ``` toggles the fence; the toggle line itself is
 *     never a task line (continue after toggle).
 */
export function parseTaskCounts(md: string): {
  tasks_done: number;
  tasks_total: number;
} {
  let inFence = false;
  let done = 0;
  let total = 0;
  for (const line of md.split("\n")) {
    if (line.trimStart().startsWith("```")) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    const m = line.match(/^\s*-\s\[( |x|X)\]\s/);
    if (!m) continue;
    total++;
    if (m[1] !== " ") done++;
  }
  return { tasks_done: done, tasks_total: total };
}

// ---------------------------------------------------------------------------
// useArtifactChanges — subscribes to artifact_changed, filters by (repo, slug).
// ---------------------------------------------------------------------------

/**
 * Hook returning the latest mtime_ms per ArtifactKind for the given session.
 * Each incoming artifact_changed event matching (repoPath, slug) updates the
 * Map entry for that artifact kind.
 *
 * Returns a new Map reference on each update so consumers re-render correctly.
 */
export function useArtifactChanges(
  repoPath: string,
  slug: string,
): Map<ArtifactKind, number> {
  const [mtimes, setMtimes] = useState<Map<ArtifactKind, number>>(new Map());

  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<ArtifactChangedPayload>("artifact_changed", (event) => {
      const p = event.payload;
      if (p.repo !== repoPath || p.slug !== slug) return;
      setMtimes((prev) => {
        const next = new Map(prev);
        next.set(p.artifact, p.mtime_ms);
        return next;
      });
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      unlisten?.();
    };
  }, [repoPath, slug]);

  return mtimes;
}

// ---------------------------------------------------------------------------
// useWatcherStatus — subscribes to watcher_status.
// ---------------------------------------------------------------------------

/**
 * Hook returning the current watcher health state.
 * Defaults to running before the first watcher_status event arrives so the
 * sidebar pip starts green; transitions to errored only on explicit error event.
 */
export function useWatcherStatus(): {
  state: WatcherState;
  errorKind?: string;
} {
  const [state, setState] = useState<WatcherState>("running");
  const [errorKind, setErrorKind] = useState<string | undefined>(undefined);

  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<WatcherStatusPayload>("watcher_status", (event) => {
      const p = event.payload;
      setState(p.state);
      setErrorKind(p.state === "errored" ? p.error_kind : undefined);
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      unlisten?.();
    };
  }, []);

  return { state, errorKind };
}

// ---------------------------------------------------------------------------
// useTaskProgress — driven by artifact_changed (kind: tasks), throttled 1/sec.
// ---------------------------------------------------------------------------

/**
 * Hook returning parsed task counts for the given session.
 * Re-reads and parses tasks.md via read_artefact IPC on each artifact_changed
 * event where artifact === "tasks" and (repo, slug) match.
 *
 * Throttled to one IPC call per second via lastFetchMs ref so rapid editor
 * saves do not flood the Tauri backend (the Rust debouncer at 150ms covers
 * most coalescing; this renderer-side gate is an additional guard per
 * performance rule check 3 — cache expensive operations).
 */
export function useTaskProgress(
  repoPath: string,
  slug: string,
): { tasks_done: number; tasks_total: number } {
  const [progress, setProgress] = useState({ tasks_done: 0, tasks_total: 0 });
  const lastFetchMs = useRef<number>(0);

  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<ArtifactChangedPayload>("artifact_changed", (event) => {
      const p = event.payload;
      if (p.artifact !== "tasks") return;
      if (p.repo !== repoPath || p.slug !== slug) return;

      const now = Date.now();
      if (now - lastFetchMs.current < 1000) return;
      lastFetchMs.current = now;

      invoke<string>("read_artefact", {
        repo: repoPath,
        slug,
        file: "tasks.md",
      })
        .then((md) => {
          setProgress(parseTaskCounts(md));
        })
        .catch(() => {
          // IPC error is non-fatal; keep the current counts.
        });
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      unlisten?.();
    };
  }, [repoPath, slug]);

  return progress;
}
