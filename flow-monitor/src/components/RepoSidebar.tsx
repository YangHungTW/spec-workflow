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
}

/**
 * RepoSidebar — left sidebar listing registered repos.
 *
 * Layout (AC2.a, AC2.b, AC8.a, AC12.c):
 *   - "All Projects" item at the top
 *   - One item per registered repo
 *   - Ghost "Add repo…" item at the bottom (AC12.c)
 *
 * Pure presentational — no IPC calls; selection state lifted to parent.
 */
export function RepoSidebar({
  repos,
  selectedId,
  onSelect,
  onAddRepo,
}: RepoSidebarProps) {
  const { t } = useTranslation();

  return (
    <nav className="repo-sidebar" aria-label={t("sidebar.allProjects")}>
      <ul className="repo-sidebar__list" role="listbox">
        {/* All Projects item */}
        <li
          role="option"
          aria-selected={selectedId === "all"}
          className={`repo-sidebar__item${selectedId === "all" ? " repo-sidebar__item--active" : ""}`}
          onClick={() => onSelect("all")}
          data-testid="sidebar-all-projects"
        >
          {t("sidebar.allProjects")}
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
            {repo.name}
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
    </nav>
  );
}

export default RepoSidebar;
