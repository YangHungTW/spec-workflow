/**
 * sessionStore — filter/sort state for the MainWindow session list.
 *
 * Consumed by:
 *   - T17 (MainWindow card grid)
 *   - T18 (CardDetail breadcrumb-back restoration — saves/restores URL search params)
 *
 * Design decisions:
 *   - Default sort is LastUpdatedDesc (AC7.b).
 *   - Exactly 4 sort axes (AC7.c): LastUpdatedDesc, Stage, SlugAZ, StalledFirst.
 *   - Collapse state for repo headers is persisted via settings store (AC8.b).
 *   - Sorting is pure in-process — no IPC round-trip per AC7.c.
 *   - selectedRepoId = "all" means "All Projects" (shows collapsible headers if ≥2 repos).
 */

import { useState, useCallback } from "react";
import type { StageKey } from "../components/StagePill";
import type { IdleState } from "../components/IdleBadge";

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
  };
}
