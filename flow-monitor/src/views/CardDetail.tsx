import { useState } from "react";
import { useParams, useNavigate, useSearchParams, Navigate } from "react-router-dom";
import { CardDetailHeader } from "../components/CardDetailHeader";
import { StageChecklist } from "../components/StageChecklist";
import { TabStrip } from "../components/TabStrip";
import type { StageKey } from "../components/StagePill";
import type { IdleState } from "../components/IdleBadge";

/** Validates URL path segment — allows only alphanumeric, hyphen, underscore. */
const SAFE_ID = /^[A-Za-z0-9_-]+$/;
function isSafeId(s: string | undefined): s is string {
  return typeof s === "string" && SAFE_ID.test(s);
}

/**
 * The 9 markdown document tabs shown in CardDetail.
 * T22 will wrap content with MarkdownPane + read-only footer.
 * exists: true for all tabs until IPC list_artefact_files wiring lands in T20.
 */
const TAB_DEFINITIONS = [
  { id: "00-request", labelKey: "tab.request" as const, exists: true },
  { id: "01-brainstorm", labelKey: "tab.brainstorm" as const, exists: true },
  { id: "02-design", labelKey: "tab.design" as const, exists: true },
  { id: "03-prd", labelKey: "tab.prd" as const, exists: true },
  { id: "04-tech", labelKey: "tab.tech" as const, exists: true },
  { id: "05-plan", labelKey: "tab.plan" as const, exists: true },
  { id: "06-tasks", labelKey: "tab.tasks" as const, exists: true },
  { id: "07-gaps", labelKey: "tab.gaps" as const, exists: true },
  { id: "08-verify", labelKey: "tab.verify" as const, exists: true },
];

/**
 * CardDetail — master-detail view for a single specflow feature session.
 *
 * Layout (AC9.a — master-detail, same-window nav, not a modal or drawer):
 *   - CardDetailHeader: breadcrumb back + repo/slug title + stage pill +
 *     idle badge + 2 action buttons
 *   - Left rail: StageChecklist (display-only) + Notes placeholder (T21)
 *   - Right pane: tab-strip placeholder (9 stubs, T19 adds scroll) +
 *     content area (T19/T22 wire content)
 *
 * Breadcrumb back (AC9.f): restores MainWindow filter/sort/repo by reading
 * the ?sort=<axis>&repo=<id> search params stored in the URL before navigation.
 * The MainWindow stores these in the URL so they survive a full React remount.
 *
 * B2 boundary: NO edit affordance, NO save button, NO command-trigger (AC9.e).
 */
function CardDetail() {
  const { repoId, slug } = useParams<{
    repoId: string;
    slug: string;
  }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [activeTabId, setActiveTabId] = useState<string>(TAB_DEFINITIONS[0].id);

  /** Guard: reject invalid URL path segments before any path construction. */
  if (!isSafeId(repoId) || !isSafeId(slug)) {
    return <Navigate to="/" replace />;
  }

  /**
   * Reconstruct the MainWindow URL with restored filter state from search params.
   * MainWindow saves sort= and repo= before navigating into detail (AC9.f).
   */
  function buildBackUrl(): string {
    const sort = searchParams.get("sort");
    const repo = searchParams.get("repo");
    const params = new URLSearchParams();
    if (sort) params.set("sort", sort);
    if (repo) params.set("repo", repo);
    const qs = params.toString();
    return qs ? `/?${qs}` : "/";
  }

  function handleBack() {
    navigate(buildBackUrl());
  }

  /**
   * Feature directory path — derived from repoId and slug.
   * In production this would come from IPC list_sessions or read_artefact.
   * T18 skeleton uses a synthesised path; real path wiring lands in T19/T20.
   */
  const featurePath = `/${repoId}/.spec-workflow/features/${slug}`;

  /**
   * Stage and idleState — in production loaded via IPC get_session or
   * derived from the sessions list in sessionStore. T18 skeleton defaults
   * so the header and checklist render; T17/T19 wire real data.
   */
  const stage: StageKey = "implement";
  const idleState: IdleState = "none";

  return (
    <div className="card-detail" data-testid="card-detail">
      <CardDetailHeader
        repoId={repoId}
        slug={slug}
        stage={stage}
        idleState={idleState}
        featurePath={featurePath}
        onBack={handleBack}
      />

      <div className="card-detail__body">
        {/* Left rail: stage checklist + notes timeline placeholder (T21) */}
        <aside
          className="card-detail__left-rail"
          data-testid="card-detail-left-rail"
        >
          <StageChecklist currentStage={stage} />

          {/* Notes timeline — rendered by T21 (NotesTimeline component) */}
          <div
            className="card-detail__notes-placeholder"
            data-testid="notes-timeline-placeholder"
          />
        </aside>

        {/* Right pane: tab strip + content area */}
        <main
          className="card-detail__right-pane"
          data-testid="card-detail-right-pane"
        >
          {/*
           * Tab strip — horizontal scroll, active-tab auto-scroll-into-view (AC9.g).
           * NO overflow menu, NO wrap per AC9.g constraint.
           */}
          <TabStrip
            tabs={TAB_DEFINITIONS}
            activeId={activeTabId}
            onSelect={setActiveTabId}
          />

          {/* Tab content area — T19/T20/T22 wire real content */}
          <div
            className="card-detail__tab-content"
            data-testid="tab-content-placeholder"
          />
        </main>
      </div>
    </div>
  );
}

export default CardDetail;
