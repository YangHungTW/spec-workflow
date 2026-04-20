import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { useTranslation } from "../i18n";
import { RepoSidebar, type RepoEntry } from "../components/RepoSidebar";
import { SortToolbar } from "../components/SortToolbar";
import { PollingFooter } from "../components/PollingFooter";
import { SessionCard } from "../components/SessionCard";
import EmptyState from "./EmptyState";
import { useSessionStore, sortSessions, type SessionState } from "../stores/sessionStore";
import type { SortAxis } from "../stores/sessionStore";
import { useTheme } from "../stores/themeStore";

/**
 * Shape of the list_sessions IPC response.
 * T11 defines the backend command; this is the front-end contract.
 */
/**
 * Actual backend shape from list_sessions IPC (Rust ipc::SessionRecord).
 */
interface BackendSessionRecord {
  repo: string;
  slug: string;
  stage: string;
  last_activity_secs: number;
  has_ui: boolean;
}

/**
 * Actual backend shape from get_settings IPC (Rust ipc::Settings).
 */
interface SettingsResponse {
  repos?: string[];
  polling_interval_secs?: number;
  locale?: string;
}

/**
 * MainWindow — main view: project-switcher sidebar + 2-column card grid +
 * sort toolbar + polling footer.
 *
 * Layout:
 *   - Left sidebar (RepoSidebar): logo, repo list, "All Projects", filter section,
 *     Settings + theme toggle at bottom (T48)
 *   - Top toolbar: page title + subtitle (T48.6), sort dropdown
 *   - Main area: 2-column card grid (≥720px) or 1-column (< 720px)
 *   - Sidebar footer (PollingFooter): "Polling · {interval}s" with green dot
 *
 * Group-by-repo (AC8.a): when "All Projects" is selected and ≥2 repos are
 * registered, sessions are grouped under collapsible repo headers.
 * Single-repo selection renders flat list with no headers (AC8.c).
 *
 * Collapse state is persisted via sessionStore (AC8.b).
 */
function MainWindow() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { theme, toggleTheme } = useTheme();
  const {
    sortAxis,
    setSortAxis,
    selectedRepoId,
    setSelectedRepoId,
    collapsedRepoIds,
    toggleRepoCollapse,
  } = useSessionStore();

  const [sessions, setSessions] = useState<SessionState[]>([]);
  const [repos, setRepos] = useState<RepoEntry[]>([]);
  const [pollingIntervalSecs, setPollingIntervalSecs] = useState<number>(3);
  const [loading, setLoading] = useState(true);
  // Tracks whether the compact panel window is currently open (AC10.a).
  const [compactPanelOpen, setCompactPanelOpen] = useState<boolean>(false);

  // Load sessions and settings on mount — map from actual Rust IPC shapes.
  const loadData = useCallback(() => {
    Promise.all([
      invoke<BackendSessionRecord[]>("list_sessions"),
      invoke<SettingsResponse>("get_settings"),
    ])
      .then(([sessionArray, settingsData]) => {
        const mapped: SessionState[] = (sessionArray ?? []).map((s) => ({
          slug: s.slug,
          stage: (s.stage as SessionState["stage"]) ?? "implement",
          idleState: "none" as SessionState["idleState"],
          lastUpdatedMs: (s.last_activity_secs ?? 0) * 1000,
          noteExcerpt: "",
          repoPath: s.repo,
          repoId: s.repo.split("/").pop() ?? s.repo,
          hasUi: s.has_ui ?? false,
        }));
        setSessions(mapped);
        setPollingIntervalSecs(settingsData.polling_interval_secs ?? 3);
        if (settingsData.repos) {
          setRepos(
            settingsData.repos.map((p) => {
              const name = p.split("/").pop() ?? p;
              return { id: name, name, path: p };
            }),
          );
        }
        setLoading(false);
      })
      .catch(() => {
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Subscribe to sessions_changed events (AC10.c) — both MainWindow and the
  // compact panel share the same poll cycle; when the backend emits a new
  // session snapshot we reload data so cards stay in sync.
  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen("sessions_changed", () => {
      loadData();
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, [loadData]);

  // Toggle the compact panel window via IPC (AC10.a).
  // set_compact_panel_open(true) creates the WebviewWindow; false closes it.
  function handleCompactToggle() {
    const next = !compactPanelOpen;
    invoke("set_compact_panel_open", { open: next }).then(() => {
      setCompactPanelOpen(next);
    }).catch(() => undefined);
  }

  // Filter sessions by selected repo
  const filteredSessions =
    selectedRepoId === "all"
      ? sessions
      : sessions.filter((s) => s.repoId === selectedRepoId);

  // Sort sessions — pure in-process per AC7.c (no IPC round-trip)
  const sortedSessions = sortSessions(filteredSessions, sortAxis);

  // Determine if we should show group-by-repo headers (AC8.a, AC8.c)
  const showGroupHeaders = selectedRepoId === "all" && repos.length >= 2;

  // Compute per-repo session counts for sidebar badges (T48.3)
  const repoSessionCounts: Record<string, number> = {};
  for (const session of sessions) {
    repoSessionCounts[session.repoId] = (repoSessionCounts[session.repoId] ?? 0) + 1;
  }

  // Compute total stalled count for sidebar badge (T48.3)
  const stalledCount = sessions.filter((s) => s.idleState === "stalled").length;

  // Page title — selected repo name or "All Projects"
  const pageTitle =
    selectedRepoId === "all"
      ? t("sidebar.allProjects")
      : (repos.find((r) => r.id === selectedRepoId)?.name ?? t("sidebar.allProjects"));

  function handleSortChange(axis: SortAxis) {
    setSortAxis(axis);
  }

  function handleAddRepo() {
    // T23 implements the folder picker; this handler is a no-op stub for T17
    invoke("pick_repo_folder").catch(() => undefined);
  }

  // Group sessions by repo for the "All Projects" view.
  // repoById is built once before the loop — O(1) per lookup instead of O(n)
  // repos.find() on every session iteration (perf: O(n+m) total, not O(n*m)).
  function groupSessionsByRepo(
    items: SessionState[],
  ): Array<{ repoId: string; repoName: string; sessions: SessionState[] }> {
    const repoById = new Map(repos.map((r) => [r.id, r]));
    const map = new Map<
      string,
      { repoId: string; repoName: string; sessions: SessionState[] }
    >();
    for (const session of items) {
      if (!map.has(session.repoId)) {
        map.set(session.repoId, {
          repoId: session.repoId,
          repoName: repoById.get(session.repoId)?.name ?? session.repoId,
          sessions: [],
        });
      }
      map.get(session.repoId)!.sessions.push(session);
    }
    return Array.from(map.values());
  }

  return (
    <div className="main-window" data-testid="main-window">
      {/* Left sidebar — RepoSidebar now owns logo, section headers, filters,
          Settings + theme toggle at bottom (T48) */}
      <aside className="main-window__sidebar">
        <RepoSidebar
          repos={repos}
          selectedId={selectedRepoId}
          onSelect={setSelectedRepoId}
          onAddRepo={handleAddRepo}
          onSettings={() => navigate("/settings")}
          onThemeToggle={toggleTheme}
          theme={theme}
          stalledCount={stalledCount}
          repoSessionCounts={repoSessionCounts}
        />
        {/* Compact panel toggle button (AC10.a) */}
        <button
          type="button"
          className="main-window__compact-toggle"
          data-testid="compact-toggle"
          aria-pressed={compactPanelOpen}
          onClick={handleCompactToggle}
        >
          {t("btn.compactPanel")}
        </button>
        {/* Polling footer at the bottom of the sidebar (AC4.c) */}
        <PollingFooter intervalSeconds={pollingIntervalSecs} />
      </aside>

      {/* Main content area */}
      <main className="main-window__content">
        {/* When no repos are registered, show the full EmptyState (AC12.a).
            The sort toolbar is hidden — there's nothing to sort. */}
        {!loading && repos.length === 0 ? (
          <EmptyState />
        ) : (
          <>
            {/* Toolbar — page title + subtitle on left, sort controls on right (T48.6) */}
            <div className="main-window__toolbar">
              <div className="main-window__toolbar-title-block">
                <h1 className="main-window__page-title">{pageTitle}</h1>
                <p className="main-window__page-subtitle">
                  {sortedSessions.length} sessions &middot;{" "}
                  {stalledCount} stalled &middot; last refreshed just now
                </p>
              </div>
              <SortToolbar sortAxis={sortAxis} onSortChange={handleSortChange} />
            </div>

            {/* Card grid */}
            <div className="main-window__grid" data-testid="card-grid">
              {loading && (
                <div className="main-window__loading" data-testid="loading-indicator">
                  {t("sort.label")}
                </div>
              )}

              {!loading && sortedSessions.length === 0 && (
                <div className="main-window__empty" data-testid="empty-state">
                  {t("empty.title")}
                </div>
              )}

          {!loading &&
            (showGroupHeaders ? (
              // Group-by-repo view with collapsible headers (AC8.a, AC8.b)
              groupSessionsByRepo(sortedSessions).map(
                ({ repoId, repoName, sessions: repoSessions }) => {
                  const isCollapsed = collapsedRepoIds.has(repoId);
                  return (
                    <section
                      key={repoId}
                      className="main-window__repo-group"
                      data-testid={`repo-group-${repoId}`}
                    >
                      <button
                        type="button"
                        className="main-window__repo-header"
                        aria-expanded={!isCollapsed}
                        onClick={() => toggleRepoCollapse(repoId)}
                        data-testid={`repo-header-${repoId}`}
                      >
                        <span className="main-window__repo-chevron">
                          {isCollapsed ? "▶" : "▼"}
                        </span>
                        <span className="main-window__repo-name">
                          {repoName}
                        </span>
                        <span className="main-window__repo-count">
                          ({repoSessions.length})
                        </span>
                      </button>

                      {!isCollapsed && (
                        <div className="main-window__repo-sessions">
                          {repoSessions.map((session) => (
                            <SessionCard
                              key={`${session.repoId}/${session.slug}`}
                              slug={session.slug}
                              stage={session.stage}
                              idleState={session.idleState}
                              lastUpdatedMs={session.lastUpdatedMs}
                              noteExcerpt={session.noteExcerpt}
                              repoPath={session.repoPath}
                              repoName={repoName}
                              hasUi={session.hasUi ?? false}
                              onClick={() => navigate(`/feature/${encodeURIComponent(session.repoId)}/${encodeURIComponent(session.slug)}`)}
                            />
                          ))}
                        </div>
                      )}
                    </section>
                  );
                },
              )
            ) : (
              // Flat list — single-repo selected or fewer than 2 repos (AC8.c)
              sortedSessions.map((session) => (
                <SessionCard
                  key={`${session.repoId}/${session.slug}`}
                  slug={session.slug}
                  stage={session.stage}
                  idleState={session.idleState}
                  lastUpdatedMs={session.lastUpdatedMs}
                  noteExcerpt={session.noteExcerpt}
                  repoPath={session.repoPath}
                  repoName={repos.find((r) => r.id === session.repoId)?.name}
                  hasUi={session.hasUi ?? false}
                  onClick={() => navigate(`/feature/${encodeURIComponent(session.repoId)}/${encodeURIComponent(session.slug)}`)}
                />
              ))
            ))}
            </div>
          </>
        )}
      </main>
    </div>
  );
}

export default MainWindow;
