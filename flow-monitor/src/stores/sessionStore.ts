/**
 * sessionStore — filter/sort state for the MainWindow session list.
 *
 * Consumed by:
 *   - T17 (MainWindow card grid)
 *   - T18 (CardDetail breadcrumb-back restoration — saves/restores URL search params)
 *   - T14 (RepoSidebar archived section)
 *
 * Design decisions:
 *   - Default sort is LastUpdatedDesc (AC7.b).
 *   - Exactly 4 sort axes (AC7.c): LastUpdatedDesc, Stage, SlugAZ, StalledFirst.
 *   - Collapse state for repo headers is persisted via settings store (AC8.b).
 *   - Sorting is pure in-process — no IPC round-trip per AC7.c.
 *   - selectedRepoId = "all" means "All Projects" (shows collapsible headers if ≥2 repos).
 *   - archivedFeatures is a renderer-side cache populated via list_archived_features IPC
 *     on mount, on add_repo/remove_repo events, and on archiveExpanded false→true (D7, D8).
 *   - archiveExpanded is persisted to the Tauri settings store via update_settings
 *     to survive cross-session remounts (D7).
 */

import { useState, useCallback, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type { StageKey } from "../components/StagePill";
import type { IdleState } from "../components/IdleBadge";

// ---------------------------------------------------------------------------
// Archived feature record — mirrors the Rust ArchivedFeatureRecord struct (D8).
// ---------------------------------------------------------------------------

/** Mirrors the Rust ArchivedFeatureRecord struct emitted by list_archived_features. */
export interface ArchivedFeatureRecord {
  repo: string;
  slug: string;
  dir: string;
}

/**
 * Stage sort order — hoisted to module level so the Record is created once,
 * not reconstructed on every sortSessions("Stage") call (perf: O(1) reuse).
 */
const STAGE_ORDER: Record<string, number> = {
  request: 0,
  brainstorm: 1,
  design: 2,
  prd: 3,
  tech: 4,
  plan: 5,
  tasks: 6,
  implement: 7,
  "gap-check": 8,
  verify: 9,
  archive: 10,
};

/** Exactly 4 sort axes per AC7.c */
export type SortAxis =
  | "LastUpdatedDesc"
  | "Stage"
  | "SlugAZ"
  | "StalledFirst";

export interface SessionState {
  slug: string;
  stage: StageKey;
  idleState: IdleState;
  lastUpdatedMs: number;
  noteExcerpt: string;
  repoPath: string;
  repoId: string;
  /** Whether the session has a UI (02-design folder present) */
  hasUi?: boolean;
}

export interface MainWindowFilterState {
  sortAxis: SortAxis;
  selectedRepoId: string;
  collapsedRepoIds: Set<string>;
}

const DEFAULT_FILTER: MainWindowFilterState = {
  sortAxis: "LastUpdatedDesc",
  selectedRepoId: "all",
  collapsedRepoIds: new Set(),
};

/**
 * Sort sessions according to the selected axis.
 * Pure function — returns a new sorted array, does not mutate input.
 * O(n log n) — no quadratic patterns.
 */
export function sortSessions(
  sessions: SessionState[],
  axis: SortAxis,
): SessionState[] {
  const copy = [...sessions];
  switch (axis) {
    case "LastUpdatedDesc":
      return copy.sort((a, b) => b.lastUpdatedMs - a.lastUpdatedMs);
    case "Stage":
      // Stage order matches STAGE_KEYS enum index; STAGE_ORDER is module-level const
      return copy.sort(
        (a, b) =>
          (STAGE_ORDER[a.stage] ?? 99) - (STAGE_ORDER[b.stage] ?? 99),
      );
    case "SlugAZ":
      return copy.sort((a, b) => a.slug.localeCompare(b.slug));
    case "StalledFirst":
      return copy.sort((a, b) => {
        // stalled first, then stale, then active (none)
        const rank = (s: IdleState) =>
          s === "stalled" ? 0 : s === "stale" ? 1 : 2;
        return rank(a.idleState) - rank(b.idleState);
      });
    default:
      return copy;
  }
}

/**
 * Hook exposing filter/sort state for the MainWindow.
 * T18 reads lastFilterState to restore after back-navigation.
 */
export function useSessionStore() {
  const [sortAxis, setSortAxis] = useState<SortAxis>("LastUpdatedDesc");
  const [selectedRepoId, setSelectedRepoId] = useState<string>("all");
  const [collapsedRepoIds, setCollapsedRepoIds] = useState<Set<string>>(
    new Set(),
  );

  // ---------------------------------------------------------------------------
  // Archived features — renderer-side cache (D7, D8, AC14, AC15, AC16)
  // ---------------------------------------------------------------------------

  const [archivedFeatures, setArchivedFeatures] = useState<
    ArchivedFeatureRecord[]
  >([]);

  /**
   * archiveExpanded — whether the Archived section is open in the sidebar.
   * Default false per R15 ("collapsed by default on first render").
   * Persisted to the Tauri settings store on change (D7).
   */
  const [archiveExpanded, setArchiveExpandedState] = useState<boolean>(false);

  /**
   * Ref tracking the previous value of archiveExpanded so the effect can detect
   * a false→true transition (the only transition that triggers a cache refresh per D8).
   */
  const prevArchiveExpandedRef = useRef<boolean>(false);

  /** Fetch archived features and update the renderer-side cache. */
  const refreshArchivedFeatures = useCallback(() => {
    invoke<ArchivedFeatureRecord[]>("list_archived_features")
      .then((records) => {
        setArchivedFeatures(records);
      })
      .catch(() => {
        // IPC error is non-fatal; keep the current (possibly empty) cache.
      });
  }, []);

  // Populate the cache on mount.
  useEffect(() => {
    refreshArchivedFeatures();
  }, [refreshArchivedFeatures]);

  // Re-populate on add_repo / remove_repo Tauri events (D8: "on repo add/remove").
  useEffect(() => {
    const unlisteners: Array<() => void> = [];

    listen("add_repo", () => {
      refreshArchivedFeatures();
    }).then((fn) => unlisteners.push(fn));

    listen("remove_repo", () => {
      refreshArchivedFeatures();
    }).then((fn) => unlisteners.push(fn));

    return () => {
      for (const fn of unlisteners) fn();
    };
  }, [refreshArchivedFeatures]);

  // Refresh when archiveExpanded flips false→true (D8: "cache refresh on expand").
  useEffect(() => {
    if (!prevArchiveExpandedRef.current && archiveExpanded) {
      refreshArchivedFeatures();
    }
    prevArchiveExpandedRef.current = archiveExpanded;
  }, [archiveExpanded, refreshArchivedFeatures]);

  /**
   * setArchiveExpanded — updates in-memory state and persists to the Tauri
   * settings store via update_settings (D7: "mirrored to the Tauri settings
   * store on change"). The write is fire-and-forget; IPC errors are non-fatal.
   */
  const setArchiveExpanded = useCallback((next: boolean) => {
    setArchiveExpandedState(next);
    invoke("update_settings", { archive_expanded: next }).catch(() => undefined);
  }, []);

  // ---------------------------------------------------------------------------
  // Collapse state for repo group headers
  // ---------------------------------------------------------------------------

  const toggleRepoCollapse = useCallback((repoId: string) => {
    setCollapsedRepoIds((prev) => {
      const next = new Set(prev);
      if (next.has(repoId)) {
        next.delete(repoId);
      } else {
        next.add(repoId);
      }
      return next;
    });
  }, []);

  const filterState: MainWindowFilterState = {
    sortAxis,
    selectedRepoId,
    collapsedRepoIds,
  };

  return {
    filterState,
    sortAxis,
    setSortAxis,
    selectedRepoId,
    setSelectedRepoId,
    collapsedRepoIds,
    toggleRepoCollapse,
    DEFAULT_FILTER,
    archivedFeatures,
    archiveExpanded,
    setArchiveExpanded,
  };
}
