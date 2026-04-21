import { useState } from "react";
import { useTranslation } from "../i18n";

export interface RepoEntry {
  id: string;
  name: string;
  path: string;
}

export interface RepoSidebarProps {
  repos: RepoEntry[];
  /** Currently selected repo id, or "all" for "All Projects" */
  selectedId: string;
  onSelect: (id: string) => void;
  onAddRepo: () => void;
  /** Called when user clicks Settings item */
  onSettings: () => void;
  /** Called when user clicks the theme toggle */
  onThemeToggle: () => void;
  /** Current theme — determines ☀/☾ label */
  theme: "light" | "dark";
  /**
   * Total stalled count across all repos — shown as red badge on "All Projects".
   * Pass 0 to hide badge.
   */
  stalledCount?: number;
  /**
   * Per-repo session counts — keyed by repo id.
   * Used for the count badge on each sidebar item.
   */
  repoSessionCounts?: Record<string, number>;
}

/**
 * RepoSidebar — left sidebar listing registered repos.
 *
 * Layout (AC2.a, AC2.b, AC8.a, AC12.c, T48):
 *   - Logo block at top (T48.1)
 *   - "Projects" section header (T48.2)
 *   - "All Projects" item with stalled count badge (T48.3)
 *   - One item per registered repo with session count badge (T48.3)
 *   - Ghost "Add repo…" item (AC12.c)
 *   - "Filter" section with "Stalled only" + "Has UI" items (T48.4)
 *   - Bottom block: Settings + theme toggle + polling indicator (T48.5)
 *
 * Pure presentational — no IPC calls; selection state lifted to parent.
 * Filter items are visual-only toggle for T48; functional filtering is B2.
 */
export function RepoSidebar({
  repos,
  selectedId,
  onSelect,
  onAddRepo,
  onSettings,
  onThemeToggle,
  theme,
  stalledCount = 0,
  repoSessionCounts = {},
}: RepoSidebarProps) {
  const { t } = useTranslation();

  // Visual-only filter toggle state (B2 will wire to actual filtering)
  const [stalledOnlyActive, setStalledOnlyActive] = useState(false);
  const [hasUiActive, setHasUiActive] = useState(false);

  return (
    <nav className="repo-sidebar" aria-label={t("sidebar.allProjects")}>
      {/* Logo block — T48.1 */}
      <div className="repo-sidebar__logo">
        <div className="repo-sidebar__logo-icon">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <circle cx="4" cy="7" r="2" fill="white" />
            <circle cx="10" cy="4" r="2" fill="white" opacity="0.6" />
            <circle cx="10" cy="10" r="2" fill="white" opacity="0.4" />
            <line x1="6" y1="7" x2="8" y2="4" stroke="white" strokeWidth="1" />
            <line x1="6" y1="7" x2="8" y2="10" stroke="white" strokeWidth="1" />
          </svg>
        </div>
        <span className="repo-sidebar__logo-text">Flow Monitor</span>
      </div>

      {/* Projects section header — T48.2 */}
      <div className="repo-sidebar__section-label">{t("sidebar.projects")}</div>

      <ul className="repo-sidebar__list" role="listbox">
        {/* All Projects item with stalled count badge */}
        <li
          role="option"
          aria-selected={selectedId === "all"}
          className={`repo-sidebar__item${selectedId === "all" ? " repo-sidebar__item--active" : ""}`}
          onClick={() => onSelect("all")}
          data-testid="sidebar-all-projects"
        >
          <svg width="14" height="14" fill="none" viewBox="0 0 14 14" aria-hidden="true">
            <rect x="1" y="1" width="12" height="12" rx="2" stroke="currentColor" strokeWidth="1.5" />
            <line x1="1" y1="5" x2="13" y2="5" stroke="currentColor" strokeWidth="1.5" />
          </svg>
          <span className="repo-sidebar__item-label">{t("sidebar.allProjects")}</span>
          <span
            className={`repo-sidebar__badge${stalledCount > 0 ? " repo-sidebar__badge--stalled" : " repo-sidebar__badge--count"}`}
            data-testid="badge-all-stalled"
            style={stalledCount === 0 ? { display: "none" } : undefined}
          >
            {stalledCount}
          </span>
        </li>

        {/* One item per registered repo */}
        {repos.map((repo) => (
          <li
            key={repo.id}
            role="option"
            aria-selected={selectedId === repo.id}
            className={`repo-sidebar__item${selectedId === repo.id ? " repo-sidebar__item--active" : ""}`}
            onClick={() => onSelect(repo.id)}
            data-testid={`sidebar-repo-${repo.id}`}
            title={repo.path}
          >
            <svg width="14" height="14" fill="none" viewBox="0 0 14 14" aria-hidden="true">
              <path d="M2 3h10M2 7h6M2 11h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
            <span className="repo-sidebar__item-label">{repo.name}</span>
            <span
              className="repo-sidebar__badge repo-sidebar__badge--count"
              data-testid={`badge-repo-${repo.id}`}
            >
              {repoSessionCounts[repo.id] ?? 0}
            </span>
          </li>
        ))}

        {/* Ghost "Add repo…" item — AC12.c */}
        <li
          role="option"
          aria-selected={false}
          className="repo-sidebar__item repo-sidebar__item--ghost"
          onClick={onAddRepo}
          data-testid="sidebar-add-repo"
        >
          {t("sidebar.addRepo")}
        </li>
      </ul>

      {/* Filter section — T48.4 */}
      <div className="repo-sidebar__section-label repo-sidebar__section-label--spaced">
        {t("sidebar.filter")}
      </div>
      <ul className="repo-sidebar__list" role="listbox">
        <li
          role="option"
          aria-selected={stalledOnlyActive}
          className={`repo-sidebar__item repo-sidebar__filter${stalledOnlyActive ? " repo-sidebar__filter--active" : ""}`}
          onClick={() => setStalledOnlyActive((v) => !v)}
          data-testid="filter-stalled-only"
        >
          <span className="repo-sidebar__filter-dot repo-sidebar__filter-dot--stalled" />
          {t("sidebar.stalledOnly")}
        </li>
        <li
          role="option"
          aria-selected={hasUiActive}
          className={`repo-sidebar__item repo-sidebar__filter${hasUiActive ? " repo-sidebar__filter--active" : ""}`}
          onClick={() => setHasUiActive((v) => !v)}
          data-testid="filter-has-ui"
        >
          <span className="repo-sidebar__filter-dot repo-sidebar__filter-dot--ui" />
          {t("sidebar.hasUi")}
        </li>
      </ul>

      {/* Bottom block — Settings + theme toggle + polling (T48.5) */}
      <div className="repo-sidebar__bottom">
        <button
          type="button"
          className="repo-sidebar__item repo-sidebar__bottom-item"
          onClick={onSettings}
          data-testid="settings-btn"
          aria-label={t("sidebar.settings")}
        >
          <svg width="14" height="14" fill="none" viewBox="0 0 14 14" aria-hidden="true">
            <circle cx="7" cy="7" r="2.5" stroke="currentColor" strokeWidth="1.5" />
            <path
              d="M7 1v1M7 12v1M1 7h1M12 7h1M2.93 2.93l.7.7M10.37 10.37l.7.7M2.93 11.07l.7-.7M10.37 3.63l.7-.7"
              stroke="currentColor"
              strokeWidth="1.2"
              strokeLinecap="round"
            />
          </svg>
          <span className="repo-sidebar__item-label">{t("sidebar.settings")}</span>
        </button>

        <button
          type="button"
          className="repo-sidebar__item repo-sidebar__bottom-item repo-sidebar__bottom-item--muted"
          onClick={onThemeToggle}
          data-testid="sidebar-theme-toggle"
          aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
        >
          <span className="repo-sidebar__theme-icon">{theme === "dark" ? "☀" : "☾"}</span>
          <span className="repo-sidebar__item-label repo-sidebar__theme-label">
            {theme === "dark" ? "Light theme" : "Dark theme"}
          </span>
        </button>
      </div>
    </nav>
  );
}

export default RepoSidebar;
